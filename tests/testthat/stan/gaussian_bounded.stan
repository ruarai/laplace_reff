data {
  int<lower=1> n;
  vector[n] y;
}
parameters {
  vector[n] x;
  real m;
  real<lower=0> sigma;
}
model {
  x ~ normal(m, sigma);
  y ~ normal(x, 1);
}
