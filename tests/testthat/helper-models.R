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

# Two rotated Cauchy-shaped inner coordinates: the mode is 0, and H is not
# positive definite far from it. The rotation gives H off-diagonal terms.
cauchy_pair_mock <- function() {
  Q <- qr.Q(qr(matrix(c(1, 2, 3, -1), 2)))
  rotate <- function(p) drop(Q %*% p[1:2])
  mock_model(
    c("a", "b", "w"),
    val = function(p) -sum(log1p(rotate(p)^2)) - p[3]^2,
    grad = function(p) {
      x <- rotate(p)
      c(drop(crossprod(Q, -2 * x / (1 + x^2))), -2 * p[3])
    },
    hess = function(p) {
      x <- rotate(p)
      h <- matrix(0, 3, 3)
      h[1:2, 1:2] <- crossprod(Q, Q * (-2 * (1 - x^2) / (1 + x^2)^2))
      h[3, 3] <- -2
      h
    }
  )
}

central_diff <- function(fn, omega, h = 1e-4) {
  vapply(seq_along(omega), function(j) {
    e <- replace(numeric(length(omega)), j, h)
    (fn(omega + e) - fn(omega - e)) / (2 * h)
  }, numeric(1))
}

# L(omega) as a function of the outer parameters, which come last in theta. Uses
# exact curvature, so unlike make_objective() it has no finite-difference noise
# and can serve as a reference for the gradient.
exact_laml <- function(model) {
  N <- length(model$param_unc_names())
  function(omega) {
    inner <- seq_len(N - length(omega))
    theta <- c(numeric(length(inner)), omega)
    for (i in 1:100) {
      ev <- model$log_density_hessian(theta)
      H <- -ev$hessian[inner, inner, drop = FALSE]
      theta[inner] <- theta[inner] + solve(H, ev$gradient[inner])
    }
    ev <- model$log_density_hessian(theta)
    H <- -ev$hessian[inner, inner, drop = FALSE]
    ev$val - 0.5 * as.numeric(determinant(H)$modulus)
  }
}

# `model` in coordinates z, where the original parameters are d * z. Fitted
# values are unchanged in the original units, and L moves by a constant.
rescaled_model <- function(model, d) {
  mock_model(
    model$param_unc_names(),
    val = function(p) model$log_density(p * d),
    grad = function(p) model$log_density_gradient(p * d)$gradient * d,
    hess = function(p) model$log_density_hessian(p * d)$hessian * outer(d, d)
  )
}
