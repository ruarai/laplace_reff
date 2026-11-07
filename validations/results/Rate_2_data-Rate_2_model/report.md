# Rate_2_data-Rate_2_model

## Result
Outcome `converged`, 1 attempt. Corrected labels: mean_sd `acceptable`, w1 `good`. Uncorrected: both `poor` (expected, outer held fixed). Manifest prediction: small, acceptable ("Bounded rates with small counts").

## Attempts
1. outer = `theta1`, theta2 inner. Two independent rates (k=5/10, 7/10), so either choice is arbitrary. Logit-scale SDs about 0.6-0.7, start at 0 sits at theta1's mode. Expected risk: Laplace on a skewed Beta(8,4) inner posterior with N=10. Outcome converged, fit time 0.405 s, no warnings, distance_sd 0.

## Agreement
Corrected: theta1 mean error 0.021, sd ratio 0.94, W1 0.050; q05 error +0.176 and q95 error -0.084 (in the metric's units), so slightly narrow tails. Worst is theta2: mean error -0.142 (laml 0.646 vs reference 0.665), sd ratio 1.00, W1 0.142; quantile errors are all about -0.11 to -0.17, a pure location shift low. Cause is the Laplace approximation on the logit scale for the skewed Beta(8,4), whose mode is below its mean. Uncorrected theta2 is similar (mean error -0.080). Uncorrected theta1 is a point mass at 0.5, so it only tells us the optimum is the logit-scale mode (theta1 = 0.5).

## Findings
No package problem. The warning list is empty, converged is true with a zero gradient. nlminb took 1 iteration because the start is already the optimum by symmetry, so this fit does not exercise the optimiser. The theta2 bias is the inherent limitation of a Laplace approximation on a skewed, small-count inner posterior.
