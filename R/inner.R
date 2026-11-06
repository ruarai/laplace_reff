# All densities are on the unconstrained scale with Jacobian adjustments.
density_value <- function(model, theta) {
  tryCatch(model$log_density(theta, propto = TRUE, jacobian = TRUE),
           error = function(e) -Inf)
}

density_hessian <- function(model, theta) {
  tryCatch(model$log_density_hessian(theta, propto = TRUE, jacobian = TRUE),
           error = function(e) NULL)
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
# Converges on the gradient, and only at a point where H is positive definite.
inner_newton <- function(model, theta, inner, tol = 1e-8, maxit = 100) {
  for (iter in seq_len(maxit)) {
    ev <- density_hessian(model, theta)
    if (is.null(ev) || !is.finite(ev$val)) {
      return(inner_failure(theta, iter, "log density could not be evaluated"))
    }
    g <- ev$gradient[inner]
    H <- -ev$hessian[inner, inner, drop = FALSE]
    if (!all(is.finite(g), is.finite(H))) {
      return(inner_failure(theta, iter, "non-finite gradient or Hessian"))
    }

    R <- chol_or_null(H)
    if (max(abs(g)) < tol) {
      if (is.null(R)) {
        return(inner_failure(theta, iter,
                             "H is not positive definite at a stationary point"))
      }
      return(list(theta = theta, val = ev$val, gradient = ev$gradient,
                  hessian = ev$hessian, H = H, R = R,
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

# J = dx_hat/domega = H^-1 l_xomega, one column per outer parameter.
mode_tangent <- function(sol, inner, outer_idx) {
  chol2inv(sol$R) %*% sol$hessian[inner, outer_idx, drop = FALSE]
}

# dL/domega at a converged solve. With t_j = (dx_hat/domega_j, e_j), the
# gradient is l_omega_j - 0.5 D_j, where D_j = d log|H| along t_j. D_j is taken
# as tr(H^-1 dH), so H need not stay positive definite at the two Hessians
# either side of the mode. `h` is the largest coordinate change of a step.
laml_gradient <- function(model, sol, inner, outer_idx, h = 1e-5) {
  H_inv <- chol2inv(sol$R)
  dx <- mode_tangent(sol, inner, outer_idx)

  H_at <- function(theta) {
    ev <- density_hessian(model, theta)
    if (is.null(ev)) stop("Hessian failed next to the inner mode.", call. = FALSE)
    -ev$hessian[inner, inner, drop = FALSE]
  }

  D <- vapply(seq_along(outer_idx), function(j) {
    tangent <- numeric(length(sol$theta))
    tangent[inner] <- dx[, j]
    tangent[outer_idx[j]] <- 1
    step <- h / max(abs(tangent)) * tangent
    sum(H_inv * (H_at(sol$theta + step) - H_at(sol$theta - step))) /
      (2 * h / max(abs(tangent)))
  }, numeric(1))

  sol$gradient[outer_idx] - 0.5 * D
}

# Objective with a warm start: each solve begins at the last converged mode.
# A failed solve returns -Inf and leaves the warm start untouched.
make_objective <- function(model, theta, outer_idx, inner_control = list()) {
  inner <- setdiff(seq_along(theta), outer_idx)
  solves <- 0L
  failures <- 0L
  hessians <- 0L
  last <- NULL

  solve_at <- function(omega) {
    start <- theta
    start[outer_idx] <- omega
    solves <<- solves + 1L
    sol <- do.call(inner_newton,
                   c(list(model, start, inner), inner_control))
    hessians <<- hessians + sol$iter
    if (sol$converged) theta <<- sol$theta else failures <<- failures + 1L
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
      hessians <<- hessians + 2L * length(outer_idx)
      laml_gradient(model, sol, inner, outer_idx)
    },
    counts = function() c(solves = solves, failures = failures, hessians = hessians)
  )
}
