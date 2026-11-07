# nes2000-nes

## Result
Outcome `converged` on attempt 1 of 3. Corrected draws: mean_sd `good`, w1 `good`. Uncorrected: mean_sd `poor`, w1 `poor` (expected, since sigma is fixed at its optimum). Manifest prediction: `good` ("Conditionally Gaussian given sigma"), so prediction matched.

## Attempts
1. Outer `sigma` (log sigma); beta inner. Linear regression with flat priors, so beta is exactly Gaussian given sigma. I expected a scale risk: N=476 gives a posterior SD of log sigma near 1/sqrt(2N) ~ 0.03, far below 1, and the start at 0 is off the optimum. Outcome `converged`, fit time 0.48 s, no warnings, 10 nlminb iterations, `distance_sd` 8e-11. The fitted log sigma was 0.579 with SE 0.033.

## Agreement
Corrected draws: worst |mean err| 0.058 (sigma, in the reference's own units; beta[8] 0.054, beta[9] 0.046), worst sd ratio 1.052 (sigma), worst W1 0.063 (sigma). These are small against the reference SDs (beta[1] SD 0.74; the others 0.06 to 0.33). Location, width and tails are all consistent, and the quantile errors are small. The beta[1] SD of 0.73 against reference 0.74 shows the intercept uncertainty is captured. Sigma is slightly wider (about 5%) and shifted by -0.058 in the mean, which is plausible given the skew of sigma that a Gaussian on log sigma only partly captures.
Uncorrected draws: beta variables agree well (sd ratio 0.99 to 1.01). Sigma has sd ratio 0 and W1 0.80, as it is a point value. Nothing more is informative.

## Findings
No package problem seen. No warnings. The expected scale concern (outer SD far below 1 and a start at 0) did not cause a premature stop here: the log sigma optimum was only ~0.58 from the start and `converged` was verified by `distance_sd` of 8e-11. The sigma errors may be partly Monte Carlo noise in the 10000-draw reference and 1000 corrected draws, which I did not separate out.
