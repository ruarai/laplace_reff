y <- c(0, 1, 2, 4, 7, 12)
n <- length(y)
inner_scales <- 10^c(-6, -4, -2, 2, 4, 6)
outer_scales <- 10^c(-4, -2, 2, 4)

rescale_inner <- function(scale) {
  rescaled_model(poisson_mock(y), c(rep(scale, n), 1, 1))
}
rescale_outer <- function(scale) {
  rescaled_model(poisson_mock(y), c(rep(1, n), scale, scale))
}
fit_quietly <- function(model) suppressWarnings(fit_model(model, c("m", "s")))

# Records every theta at which `model` is asked for a gradient.
recording <- function(model) {
  seen <- list()
  gradient <- model$log_density_gradient
  model$log_density_gradient <- function(theta, propto, jacobian) {
    seen[[length(seen) + 1]] <<- theta
    gradient(theta, propto, jacobian)
  }
  model$seen <- function() seen
  model$forget <- function() seen <<- list()
  model
}

test_that("the gradient does not depend on the inner units", {
  omega <- c(1, -0.5)
  reference <- central_diff(exact_laml(poisson_mock(y)), omega)
  for (scale in inner_scales) {
    obj <- make_objective(rescale_inner(scale), numeric(n + 2), n + 1:2)
    expect_equal(obj$gr(omega), reference, tolerance = 1e-7)
  }
})

test_that("fits do not depend on the inner units", {
  reference <- fit_quietly(poisson_mock(y))
  for (scale in inner_scales) {
    fit <- fit_quietly(rescale_inner(scale))
    expect_true(fit$converged)
    expect_equal(fit$outer, reference$outer, tolerance = 1e-5)
    expect_equal(fit$outer_se, reference$outer_se, tolerance = 1e-4)
  }
})

test_that("outer standard errors do not depend on the outer units", {
  reference <- fit_quietly(poisson_mock(y))
  for (scale in outer_scales) {
    fit <- fit_quietly(rescale_outer(scale))
    expect_equal(fit$outer * scale, reference$outer, tolerance = 1e-3)
    expect_equal(fit$outer_se * scale, reference$outer_se, tolerance = 1e-3)
  }
})

test_that("the Newton stop is the distance to the mode", {
  # Gradients here are tiny, so max(abs(g)) < tol would stop far from the mode.
  scale <- 1e-6
  model <- rescale_inner(scale)
  theta <- c(numeric(n), 1, -0.5)
  sol <- inner_newton(model, theta, 1:n)
  mode <- inner_newton(poisson_mock(y), theta, 1:n, tol = 1e-10)
  expect_equal(sol$theta[1:n] * scale, mode$theta[1:n], tolerance = 1e-7)
})

test_that("Hessian steps carry over to the next solve", {
  model <- rescale_inner(1e6)
  obj <- make_objective(model, numeric(n + 2), n + 1:2)
  omega <- c(1, -0.5)
  first <- obj$solve(omega)
  expect_equal(first$steps, 1e-5 / sqrt(diag(first$H)))

  # Starts at the mode, so this converges on its first Hessian.
  again <- obj$solve(omega)
  expect_equal(again$iter, 1)
  exact <- model$log_density_hessian(again$theta)$hessian[1:n, 1:n]
  expect_equal(again$H, -exact, tolerance = 1e-7)
})

test_that("a Hessian without a positive diagonal keeps the previous steps", {
  # The density is convex at x = 3, so the first Hessian gives no scale.
  model <- recording(cauchy_mock())
  sol <- inner_newton(model, c(3, 0), 1, steps = 1e-6)
  expect_true(sol$converged)
  expect_equal(abs(model$seen()[[2]][1] - 3), 1e-6)
})

test_that("a failed solve leaves the Hessian steps alone", {
  model <- rescale_inner(1e6)
  good <- make_objective(model, numeric(n + 2), n + 1:2)$solve(c(1, -0.5))
  recorder <- recording(model)
  capped <- make_objective(recorder, good$theta, n + 1:2, list(maxit = 1))
  expect_false(capped$solve(c(0.5, 0))$converged)
  recorder$forget()
  capped$solve(c(0.5, 0))
  expect_equal(abs(recorder$seen()[[2]][1] - good$theta[1]), 1e-7)
})

test_that("outer steps come from the Schur complement of the Hessian", {
  model <- poisson_mock(y)
  sol <- exact_mode(model, inner_newton(model, c(numeric(n), 1, -0.5), 1:n),
                    1:n)
  h <- sol$hessian
  schur <- h[7:8, 7:8] - h[7:8, 1:n] %*% solve(h[1:n, 1:n], h[1:n, 7:8])
  expect_equal(outer_steps(sol, 1:n, 7:8, 0.1), 0.1 / sqrt(-diag(schur)))
})

test_that("outer steps are fixed without usable curvature", {
  model <- poisson_mock(y)
  sol <- inner_newton(model, c(numeric(n), 1, -0.5), 1:n)
  # A finite-difference solve has no outer block.
  expect_equal(outer_steps(sol, 1:n, 7:8, 0.1), c(1e-3, 1e-3))

  sol$hessian[7, 7] <- NaN
  sol$hessian[8, 8] <- -1e6
  steps <- outer_steps(sol, 1:n, 7:8, 0.1)
  expect_equal(steps[1], 1e-3)
  expect_lt(steps[2], 1e-3)
})

test_that("inner_control settings reach each step", {
  omega <- c(1, -0.5)
  largest_move <- function(model, theta) {
    max(vapply(model$seen(), function(p) max(abs(p - theta)), numeric(1)))
  }

  model <- recording(poisson_mock(y))
  obj <- make_objective(model, numeric(n + 2), n + 1:2,
                        list(gradient_step = 0.1))
  sol <- obj$solve(omega)
  model$forget()
  obj$gr(omega)
  V <- backsolve(sol$R, diag(n))
  expect_equal(largest_move(model, sol$theta), 0.2 * max(abs(V)))

  model <- recording(poisson_mock(y))
  obj <- make_objective(model, numeric(n + 2), n + 1:2,
                        list(hessian_step = 1e-4, tol = 1e-9, maxit = 50))
  sol <- obj$solve(omega)
  model$forget()
  again <- obj$solve(omega)
  expect_equal(largest_move(model, again$theta), max(1e-4 / sqrt(diag(sol$H))))

  coarse <- fit_quietly(poisson_mock(y))
  fine <- suppressWarnings(fit_model(poisson_mock(y), c("m", "s"),
                                     list(outer_step = 0.5)))
  expect_false(isTRUE(all.equal(coarse$outer_hessian, fine$outer_hessian,
                                tolerance = 1e-6)))
})

test_that("an unknown inner_control entry is an error", {
  expect_error(make_objective(poisson_mock(y), numeric(n + 2), n + 1:2,
                              list(stepsize = 1)),
               "stepsize")
})
