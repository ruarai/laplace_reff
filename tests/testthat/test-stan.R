# End-to-end through compiled Stan. Skipped without the BridgeStan C++ source.
skip_without_bridgestan <- function() {
  path <- tryCatch(bridgestan:::get_bridgestan_path(download = FALSE),
                   error = function(e) "")
  skip_if(!nzchar(path) || !dir.exists(path), "BridgeStan source not found")
}

stan_copy <- function(file) {
  dir <- tempfile("lapland")
  dir.create(dir)
  path <- file.path(dir, file)
  file.copy(test_path("stan", file), path)
  path
}

test_that("a compiled Gaussian model matches the analytic answer", {
  skip_without_bridgestan()
  y <- c(-3, -1, 0.5, 2, 3.5, 6)
  fit <- laml_fit(stan_copy("gaussian.stan"), list(n = length(y), y = y),
                  outer = c("m", "s"))
  v <- mean((y - mean(y))^2)
  expect_equal(fit$outer[["m"]], mean(y), tolerance = 1e-3)
  expect_equal(fit$outer[["s"]], 0.5 * log(v - 1), tolerance = 1e-3)
  expect_equal(posterior::variables(fit$estimate),
               c(paste0("x[", 1:6, "]"), "m", "s", "sd_x", "twice_m", "m_rng"))
  expect_equal(fit$estimate[["twice_m"]], 2 * fit$estimate[["m"]])
})

test_that("the seed makes random generated quantities reproducible", {
  skip_without_bridgestan()
  y <- c(-3, -1, 0.5, 2, 3.5, 6)
  model <- laml_model(stan_copy("gaussian.stan"), list(n = length(y), y = y))
  m_rng <- function(seed) {
    laml_fit(model, outer = c("m", "s"), seed = seed)$estimate[["m_rng"]]
  }
  expect_equal(m_rng(1L), m_rng(1L))
  expect_false(m_rng(1L) == m_rng(2L))
})

test_that("constrained outer parameters are optimised on the log scale", {
  skip_without_bridgestan()
  y <- c(-3, -1, 0.5, 2, 3.5, 6)
  model <- laml_model(stan_copy("gaussian_bounded.stan"),
                      list(n = length(y), y = y))
  fit <- laml_fit(model, outer = c("m", "sigma"))
  # The Jacobian comes from Stan: flat on sigma gives a density in log sigma
  # of p(y | sigma) * sigma, and the mode shifts accordingly.
  profile <- function(ls) {
    sum(dnorm(y, mean(y), sqrt(exp(2 * ls) + 1), log = TRUE)) + ls
  }
  best <- optimize(profile, c(-3, 5), maximum = TRUE)$maximum
  expect_equal(fit$outer[["sigma"]], best, tolerance = 1e-3)
  expect_equal(fit$estimate[["sigma"]], exp(best), tolerance = 1e-3)
})

test_that("draws keep Stan's constraints and generated quantities", {
  skip_without_bridgestan()
  y <- c(-3, -1, 0.5, 2, 3.5, 6)
  model <- laml_model(stan_copy("gaussian.stan"), list(n = length(y), y = y))
  fit <- laml_fit(model, outer = c("m", "s"))
  draws <- laml_draws(fit, 50, corrected = TRUE)
  expect_equal(draws$sd_x, exp(draws$s))
  expect_equal(draws$twice_m, 2 * draws$m)
  expect_gt(sd(draws$m_rng - draws$m), 0)
})
