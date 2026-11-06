test_that("Newton finds the known Gaussian mode with the outer block held fixed", {
  y <- c(-1, 0.5, 2)
  theta <- c(0, 0, 0, 0.3, 0.2)
  sol <- inner_newton(gaussian_mock(y), theta, 1:3)
  w <- exp(-2 * 0.2)
  expect_true(sol$converged)
  expect_equal(sol$theta[1:3], (y + w * 0.3) / (1 + w))
  expect_equal(sol$theta[4:5], c(0.3, 0.2))
})

test_that("Newton recovers from a Hessian that is not positive definite", {
  sol <- inner_newton(cauchy_mock(), c(3, 0), 1)
  expect_true(sol$converged)
  expect_equal(sol$theta[1], 0, tolerance = 1e-7)
})

test_that("a failed density evaluation shortens the step", {
  # The Hessian understates the curvature at the start, so the first full
  # Newton step overshoots into a region where the density errors.
  model <- mock_model(
    c("x", "w"),
    val = function(p) if (p[1] > 1.5) stop("rejected") else -(p[1] - 1)^2,
    grad = function(p) c(-2 * (p[1] - 1), 0),
    hess = function(p) diag(c(if (p[1] < 0) -0.5 else -2, -1))
  )
  sol <- inner_newton(model, c(-5, 0), 1)
  expect_true(sol$converged)
  expect_equal(sol$theta[1], 1)
})

test_that("failures are reported rather than treated as a mode", {
  saddle <- mock_model(c("x", "w"),
                       val = function(p) p[1]^2,
                       grad = function(p) c(2 * p[1], 0),
                       hess = function(p) diag(c(2, -1)))
  sol <- inner_newton(saddle, c(0, 0), 1)
  expect_false(sol$converged)
  expect_match(sol$message, "not positive definite")

  broken <- mock_model(c("x", "w"),
                       val = function(p) NaN,
                       grad = function(p) c(0, 0),
                       hess = function(p) diag(2))
  expect_false(inner_newton(broken, c(0, 0), 1)$converged)

  slow <- inner_newton(cauchy_mock(), c(3, 0), 1, maxit = 1)
  expect_false(slow$converged)
  expect_match(slow$message, "iteration limit")
})

test_that("the objective warm-starts from the last converged mode", {
  y <- c(-1, 0.5, 2)
  obj <- make_objective(gaussian_mock(y), numeric(5), 4:5)
  obj$solve(c(0.3, 0.2))
  expect_equal(obj$solve(c(0.3, 0.2))$iter, 1)
})

test_that("a failed solve returns -Inf and keeps the warm start", {
  # Inner density errors whenever the outer coordinate is positive.
  model <- mock_model(
    c("x", "w"),
    val = function(p) if (p[2] > 0) stop("rejected") else -(p[1] - 2)^2,
    grad = function(p) c(-2 * (p[1] - 2), 0),
    hess = function(p) diag(c(-2, -1))
  )
  obj <- make_objective(model, c(0, 0), 2)
  obj$solve(0)
  expect_equal(obj$fn(1), -Inf)
  expect_equal(obj$counts()[["failures"]], 1)
  expect_equal(obj$solve(0)$iter, 1)
})

test_that("L matches the analytic marginal when the integrand is Gaussian", {
  y <- c(-1, 0.5, 2, 3.5)
  obj <- make_objective(gaussian_mock(y), numeric(6), 5:6)
  omegas <- list(c(0, 0), c(1, -0.5), c(-0.5, 0.7))
  L <- vapply(omegas, obj$fn, numeric(1))
  exact <- vapply(omegas, function(o) gaussian_marginal(y, o[1], o[2]), numeric(1))
  # The two differ by the constant dropped from L.
  expect_equal(L - L[1], exact - exact[1], tolerance = 1e-7)
})
