# radon_all-radon_pooled

## Result
Outcome `converged` after 1 attempt. Corrected draws: mean_sd `good`, w1 `good`. Uncorrected: `poor` / `poor` (expected, as sigma_y is held fixed). Manifest prediction: linear, good ("N=12573: tests speed only"). Prediction matched.

## Attempts
1. outer = `sigma_y`; inner = alpha, beta. Given sigma_y the posterior of alpha and beta is exactly Gaussian (linear mean, Gaussian likelihood), so the inner Laplace is exact. I expected the unconstrained SD of log(sigma_y) to be about 0.006 at N=12573, far below the assumed 1, so nlminb could stop short. Outcome `converged`, fit time 0.519 s (12 inner solves, no failures, nlminb "relative convergence (4)", 5 iterations). `converged` TRUE, distance_sd 4.1e-5, no warnings. outer_se of sigma_y on the unconstrained scale is 0.0063.

## Agreement
Corrected draws: worst abs mean error 0.025 (beta, in reference-SD units as reported), worst sd_ratio 0.950 (alpha; beta 0.952; sigma_y 1.003), worst W1 0.057 (alpha). Means, medians and quantiles agree well (|q err| <= 0.13 SD, worst at sigma_y q95). Alpha and beta are about 5% narrower than the reference; sigma_y width matches. Uncorrected draws: alpha and beta are close (sd_ratio about 1.01 and 1.00). sigma_y has SD 0 by construction (W1 0.80), and its mean (1.0587) matches the reference mean (1.0588), so the optimum is accurate.

## Findings
No package problem seen. The scale warning did not bite: nlminb reached the optimum despite the posterior SD of about 0.006 on the outer parameter, and the gradient check passed. Note one minor point: corrected alpha and beta are about 5% narrower than the reference. The cause is unclear. It could be reference Monte Carlo noise, or the correction ignoring the t-like tail from uncertainty in sigma_y, though at this N that effect should be far smaller than 5%. I did not investigate further.
