# low_dim_gauss_mix-low_dim_gauss_mix

## Result
Outcome `converged` in 1 attempt. Corrected draws: mean_sd `good`, w1 `good`. Uncorrected: both `poor` (by construction). Manifest prediction: `acceptable` ("Zero init places both ordered means together"), so the result was better than predicted.

## Attempts
1. outer = sigma.1, sigma.2 (inner: mu, theta). Chosen because, given the scales, the means and weight are near Gaussian with N=1000. Expected risks: outer SDs on the log scale are about 0.03-0.04, far below 1, so nlminb might stop short; zero init (mu=(0,1), sigma=1) against data bimodal near -3 and 3 might give a poor inner mode. Outcome `converged`, fit time 0.455 s, distance_sd 4e-8, 7 nlminb iterations, no failed inner solves, no warnings.

## Agreement
Corrected draws, worst variables: sigma[2] (mean_err -0.058 reference SD, sd_ratio 0.972, w1 0.059, q95_err -0.12, so a slightly light upper tail) and mu[2] (sd_ratio 0.968, q05/median errors of 0.08/-0.06 SD). Other variables show errors at or below 0.03 SD, with sd ratios 0.988-0.998. Location, width and tails all agree closely; the posterior is close to Gaussian. Uncorrected draws hold sigma at the optimum (sd_ratio 0, w1 up to 0.80); they say nothing useful about the outer variables, and mean errors for the inner variables stayed small (max 0.064).

## Findings
No package problem seen. Despite the small outer SDs (~0.03) the first nlminb step did not stop short, and `converged` agrees with agreement against the reference. The manifest worry about zero init did not materialise for this outer set.
