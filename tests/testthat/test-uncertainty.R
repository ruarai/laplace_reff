y <- c(-3, -1, 0.5, 2, 3.5, 6)

test_that("outer standard errors match the analytic marginal curvature", {
  fit <- laml_fit(gaussian_mock(y), outer = c("m", "s"))
  n <- length(y)
  v <- mean((y - mean(y))^2)
  expected <- diag(c(n / v, 2 * n * (v - 1)^2 / v^2))
  expect_equal(unname(fit$outer_hessian), expected, tolerance = 1e-5)
  expect_equal(fit$outer_se[["m"]], sqrt(v / n), tolerance = 1e-5)
  expect_named(fit$outer_se, c("m", "s"))
})

test_that("conditional draws hold the outer parameters at their estimates", {
  fit <- laml_fit(gaussian_mock(y), outer = c("m", "s"))
  set.seed(1)
  draws <- laml_draws(fit, 20000)
  expect_equal(posterior::ndraws(draws), 20000)
  expect_equal(unique(draws$m), fit$outer[["m"]], ignore_attr = TRUE)
  expect_equal(mean(draws[["x[2]"]]), fit$inner[[2]], tolerance = 0.01)
  expect_equal(var(draws[["x[2]"]]), solve(fit$H)[2, 2], tolerance = 0.03)
})

test_that("corrected draws recover a joint Gaussian posterior", {
  fit <- laml_fit(linear_mock(y), outer = "m")
  full <- solve(-linear_mock(y)$log_density_hessian(unname(fit$theta))$hessian)
  set.seed(1)
  draws <- laml_draws(fit, 20000, corrected = TRUE)
  m <- as.matrix(posterior::as_draws_matrix(draws))
  expect_equal(unname(cov(m)), full, tolerance = 0.03)
  expect_equal(unname(colMeans(m)), unname(fit$theta), tolerance = 0.01)
})

test_that("corrected draws follow a mode that is curved in omega", {
  y_scale <- c(-2, -1, 0.5, 1.5, 3)
  fit <- laml_fit(scale_mock(y_scale), outer = "s")
  expect_gt(fit$outer_se[["s"]], 0.2)

  set.seed(1)
  draws <- laml_draws(fit, 2000, corrected = TRUE)
  expect_gt(sd(draws$s), 0.2)
  # exp(s) x is pinned by the data however s moves, up to the 0.1 noise.
  fitted <- exp(draws$s) * draws[["x[5]"]]
  expect_lt(sd(fitted), 0.15)
  expect_equal(mean(fitted), 3, tolerance = 0.02)
})

test_that("an outer draw whose solve fails is drawn again", {
  # The density errors above w = 0.5, inside the outer distribution.
  model <- mock_model(c("x", "w"),
                      val = function(p) {
                        if (p[2] > 0.5) stop("rejected")
                        -p[1]^2 - p[2]^2
                      },
                      grad = function(p) c(-2 * p[1], -2 * p[2]),
                      hess = function(p) diag(c(-2, -2)))
  fit <- laml_fit(model, outer = "w")
  set.seed(1)
  expect_warning(draws <- laml_draws(fit, 500, corrected = TRUE), "drawn again")
  expect_equal(posterior::ndraws(draws), 500)
  expect_lte(max(draws$w), 0.5)
})

test_that("draws follow set.seed", {
  fit <- laml_fit(gaussian_mock(y), outer = c("m", "s"))
  set.seed(2); a <- laml_draws(fit, 5, corrected = TRUE)
  set.seed(2); b <- laml_draws(fit, 5, corrected = TRUE)
  expect_equal(a, b)
})

test_that("a flat outer direction warns and blocks corrected draws", {
  # L is flat in w, so the outer Hessian is zero.
  flat <- mock_model(c("x", "w"),
                     val = function(p) -p[1]^2,
                     grad = function(p) c(-2 * p[1], 0),
                     hess = function(p) diag(c(-2, 0)))
  expect_warning(fit <- laml_fit(flat, outer = "w"), "not positive definite")
  expect_true(is.na(fit$outer_se[["w"]]))
  expect_equal(posterior::ndraws(laml_draws(fit, 3)), 3)
  expect_error(laml_draws(fit, 3, corrected = TRUE), "needs `outer_vcov`")
})

test_that("a failed gradient during the outer Hessian keeps the fit", {
  # The density errors just above the optimum at w = 0.
  model <- mock_model(c("x", "w"),
                      val = function(p) {
                        if (p[2] > 5e-4) stop("rejected")
                        -p[1]^2 - p[2]^2
                      },
                      grad = function(p) c(-2 * p[1], -2 * p[2]),
                      hess = function(p) diag(c(-2, -2)))
  expect_warning(fit <- laml_fit(model, outer = "w"), "not positive definite")
  expect_equal(fit$outer[["w"]], 0, tolerance = 1e-6)
})
