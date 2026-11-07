# kidiq-kidscore_interaction

## Result
Outcome: `converged` on attempt 1 (1 of 3 attempts used). Corrected draws: mean_sd `good`, w1 `good`. Manifest prediction: linear, `good` ("Conditionally Gaussian given sigma; unscaled covariates may slow the optimiser"). The prediction held.

## Attempts
1. outer = `sigma` (inner = beta[1..4]). Rationale: the model is linear-Gaussian in beta given sigma. Risks named in advance: the unconstrained SD of log sigma is about 0.034, far below 1, and the start at 0 is far from the optimum near log(18)=2.9. Outcome: converged, fit time 0.417 s, 13 nlminb iterations, 19 inner solves, no failures, no warnings. Optimum log sigma = 2.888 (SE 0.034), `distance_sd` 7.7e-07.

## Agreement
Corrected draws, all variables are close to the reference:
- Worst mean error 0.062 SD (sigma), worst SD ratio 1.045 (sigma), worst W1 0.069 (sigma).
- Location: all mean errors are under 0.07 SD, with sigma slightly low (17.94 vs 17.98).
- Width: laml SDs are 2 to 4.5% too wide for every variable (beta SD ratios 1.02 to 1.03, sigma 1.045).
- Tails: 5%, 50% and 95% quantile errors are all under 0.13 SD, with no sign of tail problems.

Uncorrected draws hold sigma at its optimum, so sigma gets SD ratio 0 and the set is labelled poor by construction. The beta variables in that set have means within 0.05 SD, but their widths are conditional on sigma, which is not informative about the posterior.

## Findings
No package problem seen. The small SD of the outer parameter (0.034 vs the recommended near 1) and the start at zero did not stop `nlminb`, which reached the optimum. The consistent 2 to 4% overestimate of SD may come from the Laplace approximation of the marginal over sigma or from Monte Carlo error in the reference. I cannot tell which from these results, and I did not investigate it.
