# Fit the renewal model to simulated data with a known R(t).
# Run from the project root.

devtools::load_all()

set.seed(1)

# Simulate ----------------------------------------------------------------

n <- 60
g <- 4  # generation interval length
d <- 8   # reporting delay length
seed_infections <- 30
phi_true <- 20

gen <- dgamma(1:g, 3, 0.6)
gen <- gen / sum(gen)
delay <- dgamma(0:(d - 1) + 0.5, 3, 0.8)
delay <- delay / sum(delay)

R_true <- 1.3 - 0.5 * plogis((1:n - 30) / 5)

s <- max(g, d)
inf <- rep(seed_infections, s + n)
cases <- numeric(n)
for (t in 1:n) {
  inf[s + t] <- R_true[t] * sum(rev(gen) * inf[(s + t - g):(s + t - 1)])
  cases[t] <- sum(rev(delay) * inf[(s + t - d + 1):(s + t)])
}
y <- rnbinom(n, mu = cases, size = phi_true)

plot(y)

data <- list(
  n = n, y = y, g = g, d = d, gen = gen, delay = delay,
  m = 20,  # HSGP basis functions
  c = 3.0  # HSGP boundary factor
)

# Fit ---------------------------------------------------------------------

model <- laml_model("inst/model_renewal.stan", data)

fit <- laml_fit(model, outer = c("alpha", "rho", "log_phi"))

library(tidyverse)

fit$estimate |> 
  tidybayes::spread_draws(log_R[t]) |> 
  
  ggplot() +
  geom_line(aes(x = t, y = log_R, colour = "Estimate")) +
  
  geom_line(aes(x = t, y = log_R, colour = "True"),
            tibble(t = 1:length(R_true), log_R = log(R_true)))

