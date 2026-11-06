test_that("laml_fit recovers the analytic marginal maximum", {
  y <- c(-3, -1, 0.5, 2, 3.5, 6)
  fit <- laml_fit(gaussian_mock(y), outer = c("m", "s"))
  v <- mean((y - mean(y))^2)

  expect_true(fit$converged)
  expect_equal(fit$outer[["m"]], mean(y), tolerance = 1e-3)
  expect_equal(fit$outer[["s"]], 0.5 * log(v - 1), tolerance = 1e-3)

  # Inner estimates are the conditional means at the optimum.
  w <- exp(-2 * fit$outer[["s"]])
  expect_equal(unname(fit$inner), (y + w * fit$outer[["m"]]) / (1 + w),
               tolerance = 1e-6)
  expect_equal(unname(diag(fit$H)), rep(1 + w, length(y)), tolerance = 1e-6)
  expect_named(fit$theta, c(paste0("x.", 1:6), "m", "s"))
})

test_that("H and logml use the autodiff Hessian at the optimum", {
  model <- poisson_mock(c(0, 1, 2, 4, 7, 12))
  fit <- laml_fit(model, outer = c("m", "s"))
  exact <- model$log_density_hessian(unname(fit$theta))
  H <- -exact$hessian[1:6, 1:6]
  expect_identical(fit$H, H)
  expect_identical(fit$logml, exact$val - sum(log(diag(chol(H)))))

  # Also check the fallback, with a Hessian that errors at the optimum.
  broken <- model
  broken$log_density_hessian <- function(theta, propto, jacobian) stop("rejected")
  expect_warning(fallback <- laml_fit(broken, outer = c("m", "s")),
                 "finite-difference Hessian")
  expect_equal(fallback$H, H, tolerance = 1e-6)
})

test_that("the estimate is a one-row draws_df with Stan variable names", {
  fit <- laml_fit(gaussian_mock(c(-3, -1, 0.5, 2, 3.5, 6)), outer = c("m", "s"))
  expect_s3_class(fit$estimate, c("draws_df", "tbl_df"))
  expect_equal(posterior::ndraws(fit$estimate), 1)
  expect_equal(posterior::variables(fit$estimate),
               c(paste0("x[", 1:6, "]"), "m", "s"))
  expect_equal(fit$estimate[["m"]], fit$outer[["m"]], ignore_attr = TRUE)
})

test_that("BridgeStan names become posterior names", {
  expect_equal(clean_variable_names(c("mu", "z.1", "a.2.3")),
               c("mu", "z[1]", "a[2,3]"))
})

test_that("laml_fit validates init and reports a failure at init", {
  model <- gaussian_mock(1:3)
  expect_error(laml_fit(model, outer = "m", init = 1), "must have length")

  bad <- mock_model(c("x", "w"),
                    val = function(p) NaN,
                    grad = function(p) c(0, 0),
                    hess = function(p) diag(2))
  expect_error(laml_fit(bad, outer = "w"), "Inner solve failed at `init`")
})
