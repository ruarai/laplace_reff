# Stand-ins for the BridgeStan methods lapland uses.
mock_model <- function(names_unc, val, grad, hess) {
  list(
    param_unc_names = function() names_unc,
    param_names = function(include_tp = FALSE, include_gq = FALSE) names_unc,
    log_density = function(theta, propto, jacobian) val(theta),
    log_density_gradient = function(theta, propto, jacobian) {
      list(val = val(theta), gradient = grad(theta))
    },
    log_density_hessian = function(theta, propto, jacobian) {
      list(val = val(theta), gradient = grad(theta), hessian = hess(theta))
    },
    new_rng = function(seed) NULL,
    param_constrain = function(theta, include_tp = FALSE, include_gq = FALSE,
                               rng) theta
  )
}

# x_i ~ N(m, exp(2 s)), y_i ~ N(x_i, 1), with flat priors on m and s. The
# integrand is Gaussian in x, so the Laplace approximation is exact.
gaussian_mock <- function(y) {
  n <- length(y)
  inner <- seq_len(n)
  mock_model(
    c(paste0("x.", inner), "m", "s"),
    val = function(p) {
      x <- p[inner]; m <- p[n + 1]; s <- p[n + 2]
      sum(dnorm(y, x, 1, log = TRUE)) + sum(dnorm(x, m, exp(s), log = TRUE))
    },
    grad = function(p) {
      x <- p[inner]; m <- p[n + 1]; s <- p[n + 2]
      c(y - x - (x - m) * exp(-2 * s),
        sum(x - m) * exp(-2 * s),
        sum((x - m)^2) * exp(-2 * s) - n)
    },
    hess = function(p) {
      x <- p[inner]; m <- p[n + 1]; s <- p[n + 2]
      w <- exp(-2 * s)
      h <- matrix(0, n + 2, n + 2)
      diag(h)[inner] <- -1 - w
      h[inner, n + 1] <- h[n + 1, inner] <- w
      h[inner, n + 2] <- h[n + 2, inner] <- 2 * (x - m) * w
      h[n + 1, n + 1] <- -n * w
      h[n + 1, n + 2] <- h[n + 2, n + 1] <- -2 * sum(x - m) * w
      h[n + 2, n + 2] <- -2 * sum((x - m)^2) * w
      h
    }
  )
}

# Marginal log likelihood of gaussian_mock, integrating out x analytically.
gaussian_marginal <- function(y, m, s) {
  sum(dnorm(y, m, sqrt(exp(2 * s) + 1), log = TRUE))
}

# x_i ~ N(m, exp(2 s)), y_i ~ Poisson(exp(x_i)). H depends on x as well as s, so
# the gradient needs the inner tangent, and the Laplace approximation is inexact.
poisson_mock <- function(y) {
  n <- length(y)
  inner <- seq_len(n)
  mock_model(
    c(paste0("x.", inner), "m", "s"),
    val = function(p) {
      x <- p[inner]; m <- p[n + 1]; s <- p[n + 2]
      sum(y * x - exp(x)) + sum(dnorm(x, m, exp(s), log = TRUE))
    },
    grad = function(p) {
      x <- p[inner]; m <- p[n + 1]; s <- p[n + 2]
      c(y - exp(x) - (x - m) * exp(-2 * s),
        sum(x - m) * exp(-2 * s),
        sum((x - m)^2) * exp(-2 * s) - n)
    },
    hess = function(p) {
      x <- p[inner]; m <- p[n + 1]; s <- p[n + 2]
      w <- exp(-2 * s)
      h <- matrix(0, n + 2, n + 2)
      diag(h)[inner] <- -exp(x) - w
      h[inner, n + 1] <- h[n + 1, inner] <- w
      h[inner, n + 2] <- h[n + 2, inner] <- 2 * (x - m) * w
      h[n + 1, n + 1] <- -n * w
      h[n + 1, n + 2] <- h[n + 2, n + 1] <- -2 * sum(x - m) * w
      h[n + 2, n + 2] <- -2 * sum((x - m)^2) * w
      h
    }
  )
}

# x_i ~ N(m, 1), y_i ~ N(x_i, 1), with a flat prior on m. The joint posterior of
# (x, m) is Gaussian, with precision -hess.
linear_mock <- function(y) {
  n <- length(y)
  inner <- seq_len(n)
  hess <- rbind(cbind(diag(-2, n), 1), c(rep(1, n), -n))
  mock_model(
    c(paste0("x.", inner), "m"),
    val = function(p) {
      x <- p[inner]
      sum(dnorm(y, x, 1, log = TRUE)) + sum(dnorm(x, p[n + 1], 1, log = TRUE))
    },
    grad = function(p) {
      x <- p[inner]
      c(y - x - (x - p[n + 1]), sum(x - p[n + 1]))
    },
    hess = function(p) hess
  )
}

# Non-centred scale: x_i ~ N(0, 1), y_i ~ N(exp(s) x_i, 0.1), s ~ N(0, 1). The
# data pin down exp(s) x_i, so the mode of x is curved in s.
scale_mock <- function(y) {
  n <- length(y)
  inner <- seq_len(n)
  w <- 100
  mock_model(
    c(paste0("x.", inner), "s"),
    val = function(p) {
      x <- p[inner]; s <- p[n + 1]
      sum(dnorm(y, exp(s) * x, 0.1, log = TRUE)) + sum(dnorm(x, log = TRUE)) +
        dnorm(s, log = TRUE)
    },
    grad = function(p) {
      x <- p[inner]; s <- p[n + 1]; e <- exp(s); r <- y - e * x
      c(w * e * r - x, w * e * sum(x * r) - s)
    },
    hess = function(p) {
      x <- p[inner]; s <- p[n + 1]; e <- exp(s); r <- y - e * x
      h <- matrix(0, n + 1, n + 1)
      diag(h)[inner] <- -w * e^2 - 1
      h[inner, n + 1] <- h[n + 1, inner] <- w * e * r - w * e^2 * x
      h[n + 1, n + 1] <- w * e * sum(x * r) - w * e^2 * sum(x^2) - 1
      h
    }
  )
}

# One Cauchy-shaped inner coordinate: the mode is 0, and H < 0 for |x| > 1.
cauchy_mock <- function() {
  mock_model(
    c("x", "w"),
    val = function(p) -log1p(p[1]^2) - p[2]^2,
    grad = function(p) c(-2 * p[1] / (1 + p[1]^2), -2 * p[2]),
    hess = function(p) {
      diag(c(-2 * (1 - p[1]^2) / (1 + p[1]^2)^2, -2))
    }
  )
}
