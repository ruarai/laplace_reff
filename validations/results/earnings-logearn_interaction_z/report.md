# earnings-logearn_interaction_z

## Result
Outcome: converged, 1 attempt. Corrected draws: mean_sd good, w1 good. Manifest prediction: linear, good ("Conditionally Gaussian given sigma; standardised predictors"), which matches.

## Attempts
1. outer = sigma. The model is linear-Gaussian in beta given sigma, so the inner Laplace is exact. Predicted risk: the SD of log sigma is about 0.02, well below 1, so nlminb could stop short. Outcome: converged, fit time 0.43 s, no warnings. Outer log sigma = -0.126 (SE 0.0205), gradient 6e-8, distance 1.3e-9 SD. nlminb said "relative convergence (4)" after 5 iterations.

## Agreement
Corrected draws: worst abs mean error 0.036 reference SD (sigma), worst SD ratio 1.058 (sigma), worst W1 0.057 (sigma). All beta have SD ratio 1.00-1.03 and mean error at most 0.025 SD. Sigma is slightly narrow in the reference (LAML SD 0.0190 vs 0.0179, a ratio of 1.06), and the q05 error of -0.08 SD and q95 error of +0.04 SD suggest a mild skew or tail difference from the Laplace approximation in log sigma. Uncorrected draws (outer held at optimum) score poor by construction (sigma SD ratio 0); the beta variables there have mean error up to 0.024 SD.

## Findings
No package problem seen. The small SD of the outer parameter (0.02) did not cause early stopping here; convergence was confirmed by the distance check.
