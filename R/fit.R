#' Fit a Stan model by nested Laplace approximation
#'
#' Optimises the outer parameters with Nelder-Mead and integrates the others
#' out with a Laplace approximation at the inner mode. All values are on
#' Stan's unconstrained scale, with Jacobian adjustments included.
#'
#' @param model Path to a `.stan` file, or a model from [laml_model()].
#' @param data Data for `laml_model()`. Used only when `model` is a path.
#' @param outer Names of the outer parameters. A container name selects all
#'   of its unconstrained elements, and `"z.1"` selects one.
#' @param init Unconstrained starting vector. Defaults to zeros.
#' @param inner_control List with `tol` (on the maximum absolute gradient) and
#'   `maxit` for the Newton solver.
#' @param outer_control Passed to `optim()` as `control`.
#' @param seed Seed for the model and for generated quantities.
#' @return A list of class `laml_fit`: `outer` and `inner` estimates, the full
#'   unconstrained `theta`, `estimate` (a one-row `posterior::draws_df` of the
#'   constrained parameters, transformed parameters and generated quantities
#'   at the optimum; `_rng` quantities are a single random draw),
#'   `logml` (L at the optimum, without constants), `H`, `converged`, `counts`,
#'   and the `optim` result.
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

  outer_control$fnscale <- -1
  opt <- stats::optim(init[outer_idx], objective$fn, method = "Nelder-Mead",
                      control = outer_control)

  sol <- objective$solve(opt$par)
  if (!sol$converged) {
    stop("Inner solve failed at the outer optimum: ", sol$message)
  }
  converged <- opt$convergence == 0
  if (!converged) warning("Outer optimiser did not converge: code ", opt$convergence)

  theta <- stats::setNames(sol$theta, names_unc)
  structure(
    list(
      outer = theta[outer_idx],
      inner = theta[-outer_idx],
      theta = theta,
      estimate = estimate_draws(
        model$param_constrain(sol$theta, include_tp = TRUE, include_gq = TRUE,
                              rng = model$new_rng(seed)),
        model$param_names(include_tp = TRUE, include_gq = TRUE)
      ),
      logml = laml_value(sol),
      H = sol$H,
      converged = converged,
      counts = objective$counts(),
      optim = opt
    ),
    class = "laml_fit"
  )
}

# BridgeStan writes "a.1.2" where posterior expects "a[1,2]".
stan_variable_names <- function(names) {
  has_index <- grepl(".", names, fixed = TRUE)
  stem <- sub("\\..*$", "", names[has_index])
  index <- gsub(".", ",", sub("^[^.]*\\.", "", names[has_index]), fixed = TRUE)
  names[has_index] <- paste0(stem, "[", index, "]")
  names
}

estimate_draws <- function(values, names) {
  posterior::as_draws_df(
    matrix(values, nrow = 1, dimnames = list(NULL, stan_variable_names(names)))
  )
}
