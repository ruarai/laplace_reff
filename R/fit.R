#' Fit a Stan model by nested Laplace approximation
#'
#' Optimises the outer parameters with `nlminb()` and integrates the others
#' out with a Laplace approximation at the inner mode. All values are on
#' Stan's unconstrained scale, with Jacobian adjustments included.
#'
#' Hessians during the fit come from finite differences of Stan's gradients,
#' which is much faster than autodiff for large models. `H` and `logml` use
#' one autodiff Hessian at the optimum.
#'
#' Design models so that the unconstrained posterior standard deviations of the
#' outer parameters are close to 1. `nlminb()` is not unit-free: its first step
#' assumes this scale, and with much smaller standard deviations it can stop
#' short of the optimum. Check `converged` after every fit.
#'
#' @param stan_file Path to a `.stan` file.
#' @param data Named list, JSON string or path to a `.json` file. Wrap
#'   length-one arrays in `I()` so they stay arrays in the JSON.
#' @param outer Names of the outer parameters. A container name selects all
#'   of its unconstrained elements, and `"z.1"` selects one.
#' @param inner_control List of solver settings. `tol` (default `1e-8`) stops
#'   the Newton solver when the distance to the mode, `sqrt(g' H^-1 g)`, falls
#'   below it, and `maxit` (default `100`) limits its iterations.
#'   `hessian_step` (`1e-5`), `gradient_step` (`0.01`) and `outer_step` (`1e-3`)
#'   are the finite-difference steps for the inner Hessian, the gradient of `L`
#'   and `outer_hessian`. All of these except `maxit` are in approximate
#'   posterior standard deviations on the unconstrained scale, so they do not
#'   need changing when parameters are rescaled.
#' @param outer_control Passed to `nlminb()` as `control`.
#' @param seed Seed for the model and for generated quantities.
#' @return A list of class `laml_fit`: `outer` and `inner` estimates, the full
#'   unconstrained `theta`, `estimate` (a one-row `posterior::draws_df` of the
#'   constrained parameters, transformed parameters and generated quantities
#'   at the optimum; `_rng` quantities are a single random draw),
#'   `logml` (L at the optimum, without constants), `gradient` (dL/domega at
#'   the optimum), `H`, `outer_hessian` (-d2L/domega2),
#'   `outer_vcov` and `outer_se` (all `NA`, with a warning, if `outer_hessian`
#'   is not positive definite), `converged` (`TRUE` if `sqrt(g' V g)` is below
#'   `1e-3`, with `g` the `gradient` and `V` the `outer_vcov`, so the optimum is
#'   within about `1e-3` standard deviations; otherwise `FALSE`, with a warning,
#'   including when `outer_vcov` is not available), `counts` (inner solves, failed
#'   solves and approximate gradient evaluations), the `nlminb` result as
#'   `opt`, and the
#'   `model` and `inner_control` used.
#'   Use [laml_draws()] for inference.
#' @export
laml_fit <- function(stan_file, data, outer,
                     inner_control = list(), outer_control = list(),
                     seed = 1L) {
  model <- laml_model(stan_file, data, seed)
  fit_model(model, outer, inner_control, outer_control, seed)
}

# The fit itself, on a loaded model. Tests call this directly with mock models.
fit_model <- function(model, outer, inner_control = list(),
                      outer_control = list(), seed = 1L) {
  names_unc <- model$param_unc_names()

  # TODO: handle init with constrained inputs, ala cmdstanr
  init <- numeric(length(names_unc))

  outer_idx <- get_outer_param_indices(model, outer)

  objective <- make_objective(model, init, outer_idx, inner_control)

  if (!is.finite(objective$fn(init[outer_idx]))) {
    stop("Inner solve failed at `init`: ", objective$solve(init[outer_idx])$message)
  }

  opt <- stats::nlminb(
    init[outer_idx],
    function(omega) -objective$fn(omega),
    function(omega) -objective$gr(omega),
    control = outer_control
  )

  inner_sol <- objective$solve(opt$par)

  if (!inner_sol$converged) {
    stop("Inner solve failed at the outer optimum: ", inner_sol$message)
  }
  
  theta <- stats::setNames(inner_sol$theta, names_unc)
  outer_names <- names_unc[outer_idx]
  
  inner_idx <- seq_along(names_unc)[-outer_idx]
  inner_sol_exact <- exact_mode(model, inner_sol, inner_idx)

  gradient <- stats::setNames(objective$gr(opt$par), outer_names)
  uncertainty <- outer_uncertainty(
    objective$gr, opt$par, outer_names,
    outer_steps(inner_sol_exact, inner_idx, outer_idx,
                inner_settings(inner_control)$outer_step)
  )

  # nlminb's own code is unreliable here: it reports success when it stops short
  # of the optimum and false convergence when values are correct.
  distance <- sqrt(sum(gradient * (uncertainty$vcov %*% gradient)))
  converged <- is.finite(distance) && distance < 1e-3
  if (!converged) {
    warning("The outer optimiser stopped away from the optimum, or this could ",
            "not be checked (nlminb: ", opt$message, "). Consider rescaling the ",
            "outer parameters so that their unconstrained posterior standard ",
            "deviations are close to 1.", call. = FALSE)
  }

  structure(
    list(
      outer = theta[outer_idx],
      inner = theta[-outer_idx],
      theta = theta,
      estimate = constrained_draws(model, matrix(inner_sol_exact$theta, nrow = 1),
                                   model$new_rng(seed)),
      logml = laml_value(inner_sol_exact),
      gradient = gradient,
      H = inner_sol_exact$H,
      outer_hessian = uncertainty$hessian,
      outer_vcov = uncertainty$vcov,
      outer_se = sqrt(diag(uncertainty$vcov)),
      converged = converged,
      counts = objective$counts(),
      opt = opt,
      model = model,
      inner_control = inner_control
    ),
    class = "laml_fit"
  )
}

# Coordinate changes for outer_uncertainty(): `outer_step` standard deviations
# of omega, from the Schur complement of the joint Hessian. This leaves out the
# curvature of log|H|, but only sets a scale. It is not positive if the outer
# block is missing, as it is when exact_mode() falls back to differences, and
# those parameters then use a fixed step.
outer_steps <- function(sol, inner, outer_idx, outer_step) {
  cross <- backsolve(sol$R, sol$hessian[inner, outer_idx, drop = FALSE],
                     transpose = TRUE)
  precision <- -diag(sol$hessian)[outer_idx] - colSums(cross^2)
  usable <- is.finite(precision) & precision > 0
  steps <- rep(1e-3, length(outer_idx))
  steps[usable] <- outer_step / sqrt(precision[usable])
  steps
}

# -d2L/domega2 by central differences of the gradient, and its inverse. The fit
# is still usable without these, so a failure here is a warning. `h` is the
# coordinate change, one per outer parameter or a single value for all of them.
outer_uncertainty <- function(gr, omega, names, h = 1e-3) {
  q <- length(omega)
  h <- rep_len(h, q)
  dimnames <- list(names, names)
  hessian <- tryCatch({
    A <- vapply(seq_len(q), function(j) {
      e <- replace(numeric(q), j, h[j])
      (gr(omega + e) - gr(omega - e)) / (2 * h[j])
    }, numeric(q))
    A <- matrix(A, q, q)
    -(A + t(A)) / 2
  }, error = function(e) matrix(NA_real_, q, q))
  dimnames(hessian) <- dimnames

  R <- chol_or_null(hessian)
  if (is.null(R)) {
    warning("Outer Hessian is not positive definite, so outer standard errors ",
            "are not available.", call. = FALSE)
    return(list(hessian = hessian, vcov = matrix(NA_real_, q, q, dimnames = dimnames)))
  }
  vcov <- chol2inv(R)
  dimnames(vcov) <- dimnames
  list(hessian = hessian, vcov = vcov)
}

#' Draw from the Laplace approximation to the posterior
#'
#' By default the outer parameters stay at their estimates and the inner
#' parameters are drawn from `N(x_hat, H^-1)`. With `corrected = TRUE` the draws
#' also carry outer uncertainty: each one draws
#' `omega ~ N(omega_hat, outer_vcov)`, solves for the inner mode and `H` at that
#' `omega`, and draws `x ~ N(x_hat(omega), H(omega)^-1)`. This costs one inner
#' solve per draw. An `omega` where the solve fails is drawn again, with a
#' warning, which truncates the outer distribution to where `L` is defined.
#' `H` at these `omega` comes from finite differences of Stan's gradients.
#'
#' Draws use R's random number generator, so `set.seed()` makes them
#' reproducible, `_rng` generated quantities included.
#'
#' @param fit A `laml_fit`.
#' @param n Number of draws.
#' @param corrected Include outer uncertainty?
#' @return A `posterior::draws_df` of the constrained parameters, transformed
#'   parameters and generated quantities.
#' @export
laml_draws <- function(fit, n = 1000, corrected = FALSE) {
  theta_hat <- unname(fit$theta)
  outer_idx <- match(names(fit$outer), names(fit$theta))
  inner_idx <- match(names(fit$inner), names(fit$theta))

  at_optimum <- list(theta = theta_hat, R = chol(fit$H))
  next_mode <- function() at_optimum
  failures <- function() 0

  if (corrected) {
    if (anyNA(fit$outer_vcov)) {
      stop("`corrected = TRUE` needs `outer_vcov`, which this fit does not have.")
    }
    U <- chol(fit$outer_vcov)
    objective <- make_objective(fit$model, theta_hat, outer_idx, fit$inner_control)
    failures <- function() objective$counts()[["failures"]]
    next_mode <- function() {
      repeat {
        omega <- theta_hat[outer_idx] + drop(stats::rnorm(nrow(U)) %*% U)
        sol <- objective$solve(omega)
        if (sol$converged) return(sol)
        if (failures() > n) {
          stop("Too many inner solves failed: ", sol$message, call. = FALSE)
        }
      }
    }
  }

  theta <- vapply(seq_len(n), function(i) {
    mode <- next_mode()
    # H = R'R, so R^-1 z has covariance H^-1.
    z <- stats::rnorm(length(inner_idx))
    mode$theta[inner_idx] <- mode$theta[inner_idx] + backsolve(mode$R, z)
    mode$theta
  }, theta_hat)

  if (failures() > 0) {
    warning("Inner solve failed for ", failures(), " outer draw(s), which were ",
            "drawn again.", call. = FALSE)
  }

  rng <- fit$model$new_rng(sample.int(.Machine$integer.max, 1))
  constrained_draws(fit$model, t(theta), rng)
}

# BridgeStan writes "a.1.2" where posterior expects "a[1,2]".
clean_variable_indices <- function(names) {
  has_index <- grepl(".", names, fixed = TRUE)
  stem <- sub("\\..*$", "", names[has_index])
  index <- gsub(".", ",", sub("^[^.]*\\.", "", names[has_index]), fixed = TRUE)
  names[has_index] <- paste0(stem, "[", index, "]")
  names
}

# One draw per row of `theta`, an unconstrained matrix.
constrained_draws <- function(model, theta, rng) {
  values <- apply(theta, 1, function(row) {
    model$param_constrain(row, include_tp = TRUE, include_gq = TRUE, rng = rng)
  })
  names <- model$param_names(include_tp = TRUE, include_gq = TRUE)
  values <- matrix(values, nrow(theta), length(names), byrow = TRUE,
                   dimnames = list(NULL, clean_variable_indices(names)))
  posterior::as_draws_df(values)
}
