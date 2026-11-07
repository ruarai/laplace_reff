# arma-arma11

## Result
Outcome `converged` after 1 attempt (fit 0.35 s, draws ok). Corrected labels: mean_sd `acceptable`, w1 `good`. Manifest prediction: `acceptable` ("phi and theta are nonlinear in the likelihood and strongly correlated"), so the result matches it.

## Attempts
1. outer = {phi, theta}; inner = {mu, sigma}. Reasoning: phi/theta are the nonlinear, correlated pair; mu and log sigma should be near Gaussian given them. Expected risks: outer SDs far below 1 (about 0.02-0.06 turned out true) so nlminb's first step from 0 could stop short, and a ridge in phi/theta. Outcome: converged (distance_sd 1.1e-5, no warnings, nlminb relative convergence, 13 iterations, 25 solves, 0 failures). Fit time 0.348 s.

## Agreement
Corrected draws: worst abs mean error 0.133 reference SDs (sigma), worst SD ratio 0.946 (phi), worst W1 0.134 (sigma).
- Location: all means within 0.13 SD; sigma and theta are slightly low (-0.13, -0.10), phi slightly high (+0.04).
- Width: SD ratios 0.95 (mu), 0.95 (phi), 0.98 (theta), 0.99 (sigma); slightly too narrow.
- Tails: q05/q95 errors up to 0.23 SD (theta q95, sigma q95 -0.17); small, no gross tail failure.
Uncorrected draws: outer fixed at optimum, so phi/theta have SD 0 and score poor by construction. Inner mu and sigma are fine (SD ratio 0.996 and 0.988, mean error 0.04 and 0.17), which is the only informative part.

## Findings
No package problem seen. Despite outer SDs about 0.02-0.06 (far from 1), nlminb converged cleanly and the gradient check passed. The small narrowing of phi (0.95) is plausible Laplace error from the skew of phi near the stationarity boundary (phi about 0.96). Not investigated further.
