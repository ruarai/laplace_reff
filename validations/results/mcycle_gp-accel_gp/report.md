# mcycle_gp-accel_gp

## Result
Outcome `converged` at attempt 1 of 3 (1 used). Corrected draws: mean_sd `poor`, w1 `poor`. Uncorrected: both `poor`. Manifest prediction: `latent`, `acceptable` ("66 parameters, two GP layers, weakly identified length scales").

## Attempts
**Attempt 1.** outer = sdgp_1, lscale_1, sdgp_sigma_1, lscale_sigma_1 (log-scale GP hyperparameters of the mean and sigma GPs); intercepts and the 60 zgp weights inner. Rationale: given the hyperparameters the non-centred weights are near Gaussian. Expected risks: starting at 0 (sd 1, lscale 1) is far from the optimum; lscale posteriors possibly wide. Outcome `converged`, fit time 2.07 s, no warnings, distance_sd 1.2e-4, nlminb "relative convergence (4)", 25 iterations, 47 inner solves, 0 failures. Optimum (unconstrained): sdgp_1 3.70 (se 0.24), lscale_1 -2.46 (se 0.14), sdgp_sigma_1 1.03 (se 0.49), lscale_sigma_1 -4.49 (se 0.82).

## Agreement
Corrected draws, worst by W1 (errors in reference SDs):
- lscale_1: mean err +0.42, sd ratio 0.83, q05 err +0.93, q95 err +0.46 (location shift, narrower).
- lscale_sigma_1: mean err -0.40, sd ratio 0.51, q05 err -0.04, q95 err -1.79 (upper tail too short: reference is right-skewed, Gaussian on log scale misses it; also much too narrow).
- zgp_sigma_1[5] +0.35, Intercept_sigma -0.31 (sd ratio 0.86), zgp_sigma_1[6] -0.26: inner variables with modest location shifts, widths near 1.
- sdgp_1: mean err -0.11, sd ratio 0.90; Intercept: -0.03, 0.95.
Uncorrected draws hold outer at the optimum, so outer variables have sd ratio 0 by construction; the inner variables are similar to the corrected ones (worst zgp_sigma_1[5] 0.33), so the outer uncertainty adds little for them. Worst metrics are all in the length scales, the weakly identified part.

## Findings
No package problem seen: no warnings, clean convergence, fast fit. The poor label comes from the Laplace approximation of the outer marginal (skewed, wide lscale_sigma_1 posterior, se 0.82 on log scale) rather than a failure to optimise; this matches the manifest note on weakly identified length scales. Not a reflection of a bug; limitation of a Gaussian approximation for outer draws. Metrics are for a single outer set; I did not try alternatives since the outcome was `converged`.
