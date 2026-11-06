parameters {
  vector[3] x;
  real m;
}
model {
  m ~ normal(1, 2);
  x ~ normal(m, 1);
}
