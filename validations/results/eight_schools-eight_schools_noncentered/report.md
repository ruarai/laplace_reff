# eight_schools-eight_schools_noncentered

## Result
Outcome `converged`, 1 attempt used. Corrected draws: mean_sd `poor`, w1 `poor`. Uncorrected: mean_sd `poor`, w1 `poor`. Manifest prediction: `latent`, `poor` ("Funnel in tau: strongly non-Gaussian log tau, possible mode at the boundary"). The result matches the prediction.

## Attempts
1. outer = `tau` (log tau on the unconstrained scale). Given tau, theta_trans and mu are exactly Gaussian, so only log tau is non-Gaussian. I expected a skewed log tau with a long left tail. Outcome `converged`, fit time 0.447 s. The optimum is tau = 1.33 with outer_se 0.82 (on the tau scale as reported), gradient 2e-9 and distance_sd 1.8e-9. No warnings, and 15 inner solves with no failures.

## Agreement
Corrected draws, worst first (reference mean / sd against laml):
- tau: 3.60 / 3.20 against 5.32 / 5.47. Mean error 0.54, sd ratio 1.71, w1 0.54. The median is too high by 0.30 and the 95% quantile by 1.56. The width and upper tail are too heavy.
- theta[1]: 6.15 / 5.62 against 7.50 / 7.58. sd ratio 1.35, w1 0.25, q95 error 0.79. Other thetas have sd ratios of 1.1 to 1.25 and w1 of about 0.12 to 0.18. They are too wide because they inherit the tau error.
- mu is fine: sd ratio 1.06, w1 0.10.

Uncorrected draws hold tau fixed at 3.78, so tau has sd 0 by construction. The informative part is that mu is accurate (w1 0.04) and the thetas are somewhat narrow (theta[1] sd ratio 0.86, w1 0.11), as expected when tau uncertainty is ignored.

## Findings
No package problem. `converged` is genuine (gradient about 1e-9, no warnings). The poor corrected agreement is a limitation of the method here. The marginal posterior of log tau is skewed and heavy-tailed, so a Gaussian draw around its mode, followed by exponentiation, overstates tau's mean and spread. The corrected draws therefore put too much mass at large tau.
