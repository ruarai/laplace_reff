# Solver settings, from `inner_control`. The three steps are in approximate
# posterior standard deviations on the unconstrained scale, so they do not depend
# on linear rescaling of the parameters.
inner_settings <- function(inner_control = list()) {
  settings <- list(tol = 1e-8, maxit = 100, hessian_step = 1e-5,
                   gradient_step = 0.01, outer_step = 1e-3)
  unknown <- setdiff(names(inner_control), names(settings))
  if (length(unknown) > 0) {
    stop("Unknown `inner_control` entries: ", paste(unknown, collapse = ", "),
         call. = FALSE)
  }
  settings[names(inner_control)] <- inner_control
  settings
}

# All densities are on the unconstrained scale with Jacobian adjustments.
density_value <- function(model, theta) {
  tryCatch(model$log_density(theta, propto = TRUE, jacobian = TRUE),
           error = function(e) -Inf)
}

density_gradient <- function(model, theta) {
  tryCatch(model$log_density_gradient(theta, propto = TRUE, jacobian = TRUE),
           error = function(e) NULL)
}

density_hessian <- function(model, theta) {
  tryCatch(model$log_density_hessian(theta, propto = TRUE, jacobian = TRUE),
           error = function(e) NULL)
}

# Hessian by central differences of Stan's reverse-mode gradient, in the same
# form as density_hessian() except that the outer-outer block is left at zero.
# Only inner coordinates move, so outer values next to an invalid region still
# work. This costs 2 gradients per inner parameter, which is far cheaper than
# autodiff Hessians when forward mode through the model is slow (35x at 645
# parameters in the renewal model), and is accurate enough for Newton steps and
# for L during optimisation. `h` is the coordinate change, one per inner parameter
# or a single value for all of them.
gradient_hessian <- function(model, theta, inner, h = 1e-7) {
  ev <- density_gradient(model, theta)
  if (is.null(ev)) return(NULL)
  N <- length(theta)
  A <- matrix(0, N, N)
  h <- rep_len(h, length(inner))
  for (i in seq_along(inner)) {
    j <- inner[i]
    e <- replace(numeric(N), j, h[i])
    above <- density_gradient(model, theta + e)
    below <- density_gradient(model, theta - e)
    if (is.null(above) || is.null(below)) return(NULL)
    A[, j] <- (above$gradient - below$gradient) / (2 * h[i])
  }
  outer <- setdiff(seq_len(N), inner)
  A[inner, inner] <- (A[inner, inner] + t(A[inner, inner])) / 2
  A[inner, outer] <- t(A[outer, inner])
  list(val = ev$val, gradient = ev$gradient, hessian = A)
}

chol_or_null <- function(H) tryCatch(chol(H), error = function(e) NULL)

# Cholesky factor of H + tau I for the smallest tau tried that is positive
# definite. Used for step directions only.
damped_chol <- function(H) {
  tau <- 1e-6 * max(1, abs(diag(H)))
  for (i in 1:40) {
    R <- chol_or_null(H + diag(tau, nrow(H)))
    if (!is.null(R)) return(R)
    tau <- tau * 10
  }
  NULL
}

inner_failure <- function(theta, iter, message) {
  list(theta = theta, converged = FALSE, iter = iter, message = message)
}

# Damped Newton on the inner coordinates of `theta`, holding the rest fixed.
# Converges on the Newton decrement sqrt(g' H^-1 g), the distance to the mode
# under N(x_hat, H^-1), and only at a point where H is positive definite.
#
# `steps` are the differences for the first Hessian. Later ones use
# hessian_step / sqrt(diag(H)) from the Hessian before. These are returned, so
# that the next solve can start from them.
#
# Possible speed-up: each solve takes about 5 iterations, and only the last
# Hessian is needed for log|H|. Starting from x_hat + J * (change in omega), with
# J = H^-1 l_xomega, and reusing the previous Cholesky factor for the steps
# (directly, or as a CG preconditioner) could get this down to about 1 Hessian
# per solve, with only gradients until convergence.
inner_newton <- function(model, theta, inner, tol = 1e-8, maxit = 100,
                         hessian_step = 1e-5, steps = 1e-7) {
  for (iter in seq_len(maxit)) {
    ev <- gradient_hessian(model, theta, inner, steps)
    if (is.null(ev) || !is.finite(ev$val)) {
      return(inner_failure(theta, iter, "log density could not be evaluated"))
    }
    g <- ev$gradient[inner]
    H <- -ev$hessian[inner, inner, drop = FALSE]
    if (!all(is.finite(g), is.finite(H))) {
      return(inner_failure(theta, iter, "non-finite gradient or Hessian"))
    }

    if (all(diag(H) > 0)) steps <- hessian_step / sqrt(diag(H))

    R <- chol_or_null(H)
    distance <- if (is.null(R)) {
      max(abs(g))
    } else {
      sqrt(sum(backsolve(R, g, transpose = TRUE)^2))
    }
    if (distance < tol) {
      if (is.null(R)) {
        return(inner_failure(theta, iter,
                             "H is not positive definite at a stationary point"))
      }
      return(list(theta = theta, val = ev$val, gradient = ev$gradient,
                  hessian = ev$hessian, H = H, R = R, steps = steps,
                  converged = TRUE, iter = iter, message = "converged"))
    }

    if (is.null(R)) R <- damped_chol(H)
    if (is.null(R)) {
      return(inner_failure(theta, iter, "could not damp H to positive definite"))
    }
    step <- backsolve(R, backsolve(R, g, transpose = TRUE))

    # Backtracking with slack for rounding error in the density close to the
    # mode, where the expected gain is below its resolution.
    slope <- sum(g * step)
    slack <- 1e-12 * (1 + abs(ev$val))
    a <- 1
    accepted <- FALSE
    for (i in 1:40) {
      candidate <- theta
      candidate[inner] <- theta[inner] + a * step
      if (density_value(model, candidate) >= ev$val + 1e-4 * a * slope - slack) {
        accepted <- TRUE
        break
      }
      a <- a / 2
    }
    if (!accepted) return(inner_failure(theta, iter, "line search failed"))
    theta <- candidate
  }
  inner_failure(theta, maxit, "iteration limit reached")
}

# L(omega) = l(x_hat, omega) - 0.5 log|H|
laml_value <- function(sol) sol$val - sum(log(diag(sol$R)))

# grad tr(H^-1 l_xx) over all of theta at a converged solve, holding H^-1 fixed.
# Writing H^-1 = V V', this sums the second derivative of the gradient along each
# column of V. That is a five-point stencil of gradients, so this costs 4 gradients
# per inner parameter. `h` is the step along each column of V, in standard
# deviations of N(x_hat, H^-1), so rescaling the parameters leaves it unchanged. It
# is much larger than the step in gradient_hessian() because rounding error is
# divided by h^2 here.
#
# Stan's stan::model::grad_tr_mat_times_hessian() computes the same thing by
# autodiff, with M = H^-1 on the inner block and zero elsewhere. BridgeStan does
# not expose it, and it uses forward mode through the model.
grad_tr_inverse_hessian <- function(model, sol, inner, h = 0.01) {
  grad_at <- function(theta) {
    ev <- density_gradient(model, theta)
    if (is.null(ev) || !all(is.finite(ev$gradient))) {
      stop("Gradient failed next to the inner mode.", call. = FALSE)
    }
    ev$gradient
  }

  V <- backsolve(sol$R, diag(length(inner)))
  g <- numeric(length(sol$theta))
  for (i in seq_along(inner)) {
    v <- numeric(length(sol$theta))
    v[inner] <- V[, i]
    near <- grad_at(sol$theta + h * v) + grad_at(sol$theta - h * v)
    far <- grad_at(sol$theta + 2 * h * v) + grad_at(sol$theta - 2 * h * v)
    g <- g + (16 * near - far - 30 * sol$gradient) / (12 * h^2)
  }
  g
}

# dL/domega at a converged solve. With t_j = (J_j, e_j), where J = dx_hat/domega =
# H^-1 l_xomega, the gradient is l_omega_j - 0.5 D_j, where D_j = d log|H| along
# t_j. Then D_j = tr(H^-1 dH/dt_j) = -g . t_j, with g from
# grad_tr_inverse_hessian(), so one g serves every outer parameter. Solving
# H a = g_x first gives g_x' J = a' l_xomega without forming J.
laml_gradient <- function(model, sol, inner, outer_idx, h = 0.01) {
  g <- grad_tr_inverse_hessian(model, sol, inner, h)
  adjoint <- backsolve(sol$R, backsolve(sol$R, g[inner], transpose = TRUE))
  cross <- sol$hessian[inner, outer_idx, drop = FALSE]
  sol$gradient[outer_idx] + 0.5 * (g[outer_idx] + drop(crossprod(cross, adjoint)))
}

# Replaces the finite-difference Hessian of a converged solve with Stan's
# autodiff Hessian, so that values reported to the user do not depend on the
# difference step. The solve is kept, with a warning, if that fails.
exact_mode <- function(model, sol, inner) {
  ev <- density_hessian(model, sol$theta)
  R <- NULL
  if (!is.null(ev)) {
    H <- -ev$hessian[inner, inner, drop = FALSE]
    if (all(is.finite(H))) R <- chol_or_null(H)
  }
  if (is.null(R)) {
    warning("Autodiff Hessian failed at the mode, so `H` and `logml` use a ",
            "finite-difference Hessian.", call. = FALSE)
    return(sol)
  }
  sol[c("val", "gradient", "hessian", "H", "R")] <-
    list(ev$val, ev$gradient, ev$hessian, H, R)
  sol
}

# Objective with a warm start: each solve begins at the last converged mode.
# A failed solve returns -Inf and leaves the warm start untouched.
make_objective <- function(model, theta, outer_idx, inner_control = list()) {
  inner <- setdiff(seq_along(theta), outer_idx)
  settings <- inner_settings(inner_control)
  steps <- 1e-7
  solves <- 0L
  failures <- 0L
  gradients <- 0L
  last <- NULL

  solve_at <- function(omega) {
    start <- theta
    start[outer_idx] <- omega
    solves <<- solves + 1L
    sol <- inner_newton(model, start, inner, settings$tol, settings$maxit,
                        settings$hessian_step, steps)
    gradients <<- gradients + sol$iter * (2L * length(inner) + 1L)
    if (sol$converged) {
      theta <<- sol$theta
      steps <<- sol$steps
    } else {
      failures <<- failures + 1L
    }
    last <<- sol
    sol
  }

  list(
    solve = solve_at,
    fn = function(omega) {
      sol <- solve_at(omega)
      if (sol$converged) laml_value(sol) else -Inf
    },
    # Reuses the mode from `fn` when called at the same omega. The omega is
    # read from the solve because nlminb may overwrite the vector it passes.
    gr = function(omega) {
      same <- identical(last$theta[outer_idx], as.numeric(omega))
      sol <- if (same) last else solve_at(omega)
      if (!sol$converged) {
        stop("Inner solve failed in the gradient: ", sol$message, call. = FALSE)
      }
      gradients <<- gradients + 4L * length(inner)
      laml_gradient(model, sol, inner, outer_idx, settings$gradient_step)
    },
    counts = function() c(solves = solves, failures = failures, gradients = gradients)
  )
}
