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
#' @param model Path to a `.stan` file, or a model from [laml_model()].
#' @param data Data for `laml_model()`. Used only when `model` is a path.
#' @param outer Names of the outer parameters. A container name selects all
#'   of its unconstrained elements, and `"z.1"` selects one.
#' @param init Unconstrained starting vector. Defaults to zeros.
#' @param inner_control List with `tol` (on the maximum absolute gradient) and
#'   `maxit` for the Newton solver.
#' @param outer_control Passed to `nlminb()` as `control`.
#' @param seed Seed for the model and for generated quantities.
#' @return A list of class `laml_fit`: `outer` and `inner` estimates, the full
#'   unconstrained `theta`, `estimate` (a one-row `posterior::draws_df` of the
#'   constrained parameters, transformed parameters and generated quantities
#'   at the optimum; `_rng` quantities are a single random draw),
#'   `logml` (L at the optimum, without constants), `gradient` (dL/domega at
#'   the optimum), `H`, `outer_hessian` (-d2L/domega2),
#'   `outer_vcov` and `outer_se` (all `NA`, with a warning, if `outer_hessian`
#'   is not positive definite), `converged`, `counts` (inner solves, failed
#'   solves and approximate gradient evaluations), the `nlminb` result as
#'   `opt`, and the
#'   `model` and `inner_control` used.
#'   Use [laml_draws()] for inference.
#' @export
laml_fit <- function(model, data = NULL, outer, init = NULL,
                     inner_control = list(), outer_control = list(),
                     seed = 1L) {
  if (is.character(model)) model <- laml_model(model, data, seed)

  names_unc <- model$param_unc_names()
  if (is.null(init)) init <- numeric(length(names_unc))
  if (length(init) != length(names_unc)) {
    stop("`init` must have length ", length(names_unc), ".")
  }
  outer_idx <- outer_index(model, outer)

  objective <- make_objective(model, init, outer_idx, inner_control)
  if (!is.finite(objective$fn(init[outer_idx]))) {
    stop("Inner solve failed at `init`: ",
         objective$solve(init[outer_idx])$message)
  }

  opt <- stats::nlminb(init[outer_idx],
                       function(omega) -objective$fn(omega),
                       function(omega) -objective$gr(omega),
                       control = outer_control)

  sol <- objective$solve(opt$par)
  if (!sol$converged) {
    stop("Inner solve failed at the outer optimum: ", sol$message)
  }
  converged <- opt$convergence == 0
  if (!converged) warning("Outer optimiser did not converge: ", opt$message)

  theta <- stats::setNames(sol$theta, names_unc)
  outer_names <- names_unc[outer_idx]
  gradient <- stats::setNames(objective$gr(opt$par), outer_names)
  uncertainty <- outer_uncertainty(objective$gr, opt$par, outer_names)
  sol <- exact_mode(model, sol, seq_along(names_unc)[-outer_idx])

  structure(
    list(
      outer = theta[outer_idx],
      inner = theta[-outer_idx],
      theta = theta,
      estimate = constrained_draws(model, matrix(sol$theta, nrow = 1),
                                   model$new_rng(seed)),
      logml = laml_value(sol),
      gradient = gradient,
      H = sol$H,
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

# -d2L/domega2 by central differences of the gradient, and its inverse. The fit
# is still usable without these, so a failure here is a warning.
outer_uncertainty <- function(gr, omega, names, h = 1e-3) {
  q <- length(omega)
  dimnames <- list(names, names)
  hessian <- tryCatch({
    A <- vapply(seq_len(q), function(j) {
      e <- replace(numeric(q), j, h)
      (gr(omega + e) - gr(omega - e)) / (2 * h)
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
stan_variable_names <- function(names) {
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
                   dimnames = list(NULL, stan_variable_names(names)))
  posterior::as_draws_df(values)
}
