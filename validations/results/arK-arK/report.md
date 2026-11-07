# arK-arK

## Result
Outcome `converged` on attempt 1 of 3 (1 used). Corrected draws: mean_sd good, w1 good. Manifest prediction: linear, good ("Conditionally Gaussian given sigma"). The prediction held.

## Attempts
1. outer = sigma. The model is linear-Gaussian in alpha and beta given sigma, so integrating them out should be near exact. Expected risk: the unconstrained SD of log sigma is small, so nlminb could stop short from the start at 0. Outcome converged, fit time 0.43 s, 9 nlminb iterations, 18 inner solves, 0 failures, no warnings. Optimum log sigma = -1.898, outer_se 0.052, distance_sd 2e-8.

## Agreement
Corrected: worst sd_ratio 1.044 (alpha, 0.972 for sigma), worst abs mean error 0.070 reference SDs (sigma), worst w1 0.070 (sigma). The beta variables have sd_ratio 1.00 to 1.02 and w1 below 0.07. Quantile errors are small. Sigma is slightly narrower (0.97), plausibly from Laplace on log sigma, but the difference is small.
Uncorrected: outer variable sigma has sd_ratio 0 and w1 0.80 by construction. The inner variables are barely worse (beta[5] w1 0.030 against 0.028 corrected), since their conditional means barely depend on sigma.

## Findings
No package problem seen. One observation: outer_se is 0.052, far below the documented target of about 1, yet the fit converged with a tiny gradient (4e-7) and agreement was good. The small scale did not cause early stopping here, though the start at log sigma = 0 is about 1.9 away from the optimum, which is about 37 SDs.
