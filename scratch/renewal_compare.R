
devtools::load_all()

# Simulate ----------------------------------------------------------------

set.seed(1)

n <- 365 * 2
g <- 4
d <- 8
seed_infections <- 5
phi_true <- 20

gen <- dgamma(1:g, 3, 0.6)
gen <- gen / sum(gen)
delay <- dgamma(0:(d - 1) + 0.5, 3, 0.8)
delay <- delay / sum(delay)

R_true <- 1.0 + 0.2 * sin((1:n) / 10) + (1:n) * 0.00002

plot(R_true)

s <- max(g, d)
inf <- rep(seed_infections, s + n)
cases <- numeric(n)
for (t in 1:n) {
  inf[s + t] <- R_true[t] * sum(rev(gen) * inf[(s + t - g):(s + t - 1)])
  cases[t] <- sum(rev(delay) * inf[(s + t - d + 1):(s + t)])
}
y <- rnbinom(n, mu = cases, size = phi_true)

plot(y, type = "l")

data <- list(n = n, y = y, g = g, d = d, gen = gen, delay = delay,
             m = round(n / 20), c = 1.25)

# Fit ---------------------------------------------------------------------

laml_time <- system.time({
  fit <- laml_fit("inst/model_renewal.stan", data,
                  outer = c("alpha", "rho", "log_phi"))
})

conditional <- laml_draws(fit, 2000)
# corrected <- laml_draws(fit, 150, corrected = TRUE)


conditional |> 
  tidybayes::spread_draws(cases[t]) |> 
  
  ggplot(aes(x = t, y = cases)) +
  fastribbon::stat_fastribbon(geom = "ribbon") +
  
  geom_line(data = tibble(t = 1:length(y), cases = y),
            alpha = 0.3) +
  
  scale_fill_brewer() +
  
  theme_bw()

conditional |> 
  tidybayes::spread_draws(log_R[t]) |> 
  
  ggplot(aes(x = t, y = log_R)) +
  fastribbon::stat_fastribbon(geom = "ribbon") +
  
  geom_line(data = tibble(t = 1:length(y), log_R = log(R_true))) +
  
  scale_fill_brewer() +
  
  theme_bw()


stan <- cmdstanr::cmdstan_model("inst/model_renewal.stan", dir = tempdir())
hmc_time <- system.time({
  hmc <- stan$sample(data = data, chains = 4, parallel_chains = 4,
                     iter_warmup = 1000, iter_sampling = 1000, seed = 1,
                     adapt_delta = 0.95, refresh = 50)
})
hmc$diagnostic_summary()

cat("Time: LAML", laml_time[["elapsed"]], "s, HMC", hmc_time[["elapsed"]], "s\n")
print(fit$counts)

# Compare -----------------------------------------------------------------

hmc_draws <- posterior::as_draws_df(hmc$draws())

# Outer parameters on the scale they were optimised on.
outer_scale <- function(draws) {
  cbind(log_alpha = log(draws$alpha), log_rho = log(draws$rho),
        log_phi = draws$log_phi)
}
hmc_outer <- outer_scale(hmc_draws)
print(round(rbind(
  laml_mean = fit$outer, hmc_mean = colMeans(hmc_outer),
  laml_mode_gap = fit$outer - apply(hmc_outer, 2, median),
  laml_se = fit$outer_se, hmc_sd = apply(hmc_outer, 2, sd)
), 3))

variables <- c(paste0("log_R[", 1:n, "]"), paste0("cases[", 1:n, "]"))
limits <- function(draws, v) quantile(draws[[v]], c(0.05, 0.5, 0.95))

compare <- function(draws, label) {
  rows <- vapply(variables, function(v) {
    a <- limits(draws, v)
    b <- limits(hmc_draws, v)
    c(width_ratio = (a[[3]] - a[[1]]) / (b[[3]] - b[[1]]),
      centre_shift = (a[[2]] - b[[2]]) / (b[[3]] - b[[1]]),
      hmc_inside = mean(hmc_draws[[v]] >= a[[1]] & hmc_draws[[v]] <= a[[3]]))
  }, numeric(3))
  group <- ifelse(startsWith(variables, "log_R"), "log_R", "cases")
  summary <- sapply(split(seq_along(group), group), function(i) {
    c(apply(rows[, i], 1, mean),
      min_inside = min(rows["hmc_inside", i]),
      max_abs_shift = max(abs(rows["centre_shift", i])))
  })
  cat("\n", label, "(90% intervals against HMC)\n")
  print(round(summary, 3))
}

compare(conditional, "Conditional")
compare(corrected, "Corrected")
