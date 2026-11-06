data {
  int<lower=1> n;
  vector[n] y;
}
parameters {
  vector[n] x;
  real m;
  real s;
}
transformed parameters {
  real sd_x = exp(s);
}
model {
  x ~ normal(m, sd_x);
  y ~ normal(x, 1);
}
generated quantities {
  real twice_m = 2 * m;
  real m_rng = normal_rng(m, 1);
}
