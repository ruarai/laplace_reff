omegas <- list(c(0, 0), c(1, -0.5), c(1.5, 0.4), c(-0.5, 0.7))
tight <- list(tol = 1e-10)

test_that("the gradient matches a finite difference of L for a Gaussian", {
  y <- c(-1, 0.5, 2, 3.5)
  model <- gaussian_mock(y)
  obj <- make_objective(model, numeric(6), 5:6, tight)
  for (omega in omegas) {
    expect_equal(obj$gr(omega), central_diff(exact_laml(model), omega), tolerance = 1e-6)
  }
})

test_that("the gradient matches a finite difference of L when H depends on x", {
  y <- c(0, 1, 2, 4, 7, 12)
  model <- poisson_mock(y)
  obj <- make_objective(model, numeric(8), 7:8, tight)
  for (omega in omegas) {
    expect_equal(obj$gr(omega), central_diff(exact_laml(model), omega), tolerance = 1e-6)
  }
})

test_that("grad_tr_inverse_hessian matches the analytic Poisson result", {
  y <- c(0, 1, 2, 4, 7, 12)
  sol <- inner_newton(poisson_mock(y), c(numeric(6), 1, -0.5), 1:6, tol = 1e-10)
  x <- sol$theta[1:6]
  w <- exp(2 * 0.5)
  H <- exp(x) + w
  expect_equal(grad_tr_inverse_hessian(poisson_mock(y), sol, 1:6),
               c(-exp(x) / H, 0, 2 * w * sum(1 / H)), tolerance = 1e-6)
})

test_that("the gradient is stable across step sizes", {
  y <- c(0, 1, 2, 4, 7, 12)
  model <- poisson_mock(y)
  sol <- inner_newton(model, c(numeric(6), 1, -0.5), 1:6, tol = 1e-10)
  grads <- sapply(c(1e-2, 1e-3, 3e-4), function(h) {
    laml_gradient(model, sol, 1:6, 7:8, h = h)
  })
  expect_equal(grads[, 1], grads[, 3], tolerance = 1e-5)
})

test_that("the gradient does not depend on the number of outer parameters", {
  y <- c(0, 1, 2, 4, 7, 12)
  obj <- make_objective(poisson_mock(y), numeric(8), 7:8, tight)
  obj$fn(c(1, -0.5))
  before <- obj$counts()[["gradients"]]
  obj$gr(c(1, -0.5))
  expect_equal(obj$counts()[["gradients"]] - before, 4 * 6)
})

test_that("a failed gradient next to the mode is an error", {
  model <- poisson_mock(c(0, 1, 2))
  sol <- inner_newton(model, c(numeric(3), 1, -0.5), 1:3)
  broken <- model
  broken$log_density_gradient <- function(theta, propto, jacobian) stop("rejected")
  expect_error(laml_gradient(broken, sol, 1:3, 4:5), "next to the inner mode")
})

test_that("the gradient reuses the mode from the objective at the same omega", {
  obj <- make_objective(gaussian_mock(1:3), numeric(5), 4:5)
  obj$fn(c(0.3, 0.2))
  obj$gr(c(0.3, 0.2))
  expect_equal(obj$counts()[["solves"]], 1)
  obj$gr(c(0.4, 0.2))
  expect_equal(obj$counts()[["solves"]], 2)
})

test_that("a gradient at a failed solve is an error", {
  model <- mock_model(
    c("x", "w"),
    val = function(p) if (p[2] > 0) stop("rejected") else -(p[1] - 2)^2,
    grad = function(p) c(-2 * (p[1] - 2), 0),
    hess = function(p) diag(c(-2, -1))
  )
  obj <- make_objective(model, c(0, 0), 2)
  expect_error(obj$gr(1), "Inner solve failed")
})

test_that("nlminb needs fewer solves than Nelder-Mead for the same optimum", {
  y <- c(0, 1, 2, 4, 7, 12)
  model <- poisson_mock(y)

  nm <- make_objective(model, numeric(8), 7:8)
  opt <- optim(c(0, 0), nm$fn, method = "Nelder-Mead",
               control = list(fnscale = -1, reltol = 1e-10))

  fit <- fit_model(model, outer = c("m", "s"))
  expect_true(fit$converged)
  expect_lt(fit$counts[["solves"]], nm$counts()[["solves"]])
  expect_equal(unname(fit$outer), opt$par, tolerance = 1e-3)
  expect_lt(max(abs(fit$gradient)), 1e-4)
})
