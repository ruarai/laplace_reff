# gp_pois_regr-gp_regr

## Result
Outcome `converged`, 1 attempt. Corrected draws: mean_sd good, w1 good. Manifest prediction: small / acceptable ("N=11: heavy-tailed hyperparameters"). Result matches or beats the prediction.

## Attempts
1. outer = alpha, sigma (rho inner). rho has a gamma(25,4) prior, with SD about 0.2 on the log scale, far below 1, so it was left inner. alpha and sigma have weak half-normal priors. Risks named: heavy tails and skew with N=11, and weak alpha/sigma identification. Outcome converged, fit time 0.345 s, no warnings, gradient about 1e-8, distance_sd 2.8e-9, outer SEs 0.33 (alpha) and 0.28 (sigma) on the unconstrained scale.

## Agreement
Corrected draws: rho mean err +0.085 (ref SD 1.27), SD ratio 1.00, W1 0.086 (worst). alpha mean err -0.013, SD ratio 1.08 (worst, slightly wide), W1 0.061; q50 err -0.044, q95 err +0.058. sigma mean err +0.047, SD ratio 1.04, W1 0.050. Locations are within 0.1 reference SD for all variables. Widths are slightly too large (up to 8%), and the tails are fine. Uncorrected draws score poor by construction (alpha and sigma are fixed at the optimum, SD ratio 0); rho there is still close (mean err 0.083, SD ratio 1.06).

## Findings
None. No warnings, `converged` is true with a tiny gradient, and the fit is fast. Note the outer SEs (about 0.3) are below the suggested scale of 1, but this caused no problem.
