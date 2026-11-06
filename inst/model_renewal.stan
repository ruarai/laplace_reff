// Renewal model with log R(t) = mu + HSGP (Matern 3/2).

functions {
  // Expected reported cases: deterministic renewal, then delay convolution.
  // gen_rev / delay_rev are pmfs in reverse order. Seed infections are flat.
  vector expected_cases(vector log_R, real log_i0, vector gen_rev, vector delay_rev) {
    int n = rows(log_R);
    int g = rows(gen_rev);
    int d = rows(delay_rev);
    int s = max(g, d);
    vector[n] R = exp(log_R);
    vector[s + n] inf = rep_vector(exp(log_i0), s + n);
    vector[n] cases;
    for (t in 1:n) {
      inf[s + t] = R[t] * dot_product(gen_rev, inf[(s + t - g):(s + t - 1)]);
      cases[t] = dot_product(delay_rev, inf[(s + t - d + 1):(s + t)]);
    }
    return cases;
  }

  // Square root of the Matern 3/2 spectral density at sqrt(eigenvalues)
  vector sqrt_spd(vector w, real alpha, real rho) {
    real a = sqrt(3) / rho;
    return 2 * alpha * pow(a, 1.5) ./ (square(a) + square(w));
  }
}
data {
  int<lower=7> n;
  array[n] int<lower=0> y;
  int<lower=1> g;
  int<lower=1> d;
  simplex[g] gen;    // generation interval pmf, lags 1..g
  simplex[d] delay;  // infection-to-report pmf, lags 0..d-1
  int<lower=1> m;    // HSGP basis functions
  real<lower=1> c;   // HSGP boundary factor
}
transformed data {
  vector[g] gen_rev = reverse(gen);
  vector[d] delay_rev = reverse(delay);
  real L = c * (n - 1) / 2.0;
  vector[m] w;
  matrix[n, m] Phi;
  for (j in 1:m) {
    w[j] = j * pi() / (2 * L);
    for (t in 1:n) {
      Phi[t, j] = sqrt(1 / L) * sin(w[j] * (t - (n + 1) / 2.0 + L));
    }
  }
}
parameters {
  vector[m] z;          // whitened HSGP weights
  real mu;              // mean log R
  real log_i0;          // log seed infections
  real log_phi;         // log negative binomial dispersion
  real<lower=0> alpha;  // GP marginal sd
  real<lower=0> rho;    // GP lengthscale (days)
}
transformed parameters {
  vector[n] log_R = mu + Phi * (sqrt_spd(w, alpha, rho) .* z);
}
model {
  real inv_sqrt_phi = exp(-0.5 * log_phi);
  z ~ std_normal();
  mu ~ normal(0, 0.5);
  log_i0 ~ normal(log(mean(to_vector(y[1:7])) + 1), 2);
  alpha ~ normal(0, 0.5);
  rho ~ lognormal(log(21), 0.5);
  inv_sqrt_phi ~ normal(0, 1);
  target += -0.5 * log_phi;  // Jacobian for the prior on inv_sqrt_phi
  y ~ neg_binomial_2(expected_cases(log_R, log_i0, gen_rev, delay_rev), exp(log_phi));
}
generated quantities {
  vector[n] R = exp(log_R);
  vector[n] cases = expected_cases(log_R, log_i0, gen_rev, delay_rev);
}
