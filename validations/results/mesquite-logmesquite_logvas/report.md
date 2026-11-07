# mesquite-logmesquite_logvas

## Result
Outcome `converged`, 1 attempt used. Corrected draws: mean_sd `acceptable`, w1 `good`. Uncorrected: mean_sd `poor`, w1 `poor` (expected, as sigma is held fixed). Manifest prediction: `acceptable` ("N=46 with 7 coefficients: skewed sigma marginal").

## Attempts
1. outer = `sigma`. Flat priors and a linear-Gaussian likelihood make beta exactly Gaussian given sigma, so only sigma needs optimising. Expected risks: unconstrained log-sigma SD of about 0.11 (below the assumed 1) and a start at sigma = 1 far from the mode. Outcome `converged`, fit time 0.42 s. nlminb: relative convergence, 5 iterations. Optimum log sigma = -1.097, SE 0.115, gradient -2.5e-7, distance_sd 2.9e-8. No warnings. The small SD did not stop nlminb short.

## Agreement
Corrected draws (worst_abs_mean_err 0.113 SD, worst_sd_ratio 0.965, worst_w1 0.113):
- Worst variable is sigma: mean error -0.113 SD, sd_ratio 0.975, w1 0.113. Quantile errors are all negative (q05 -0.15, q50 -0.065, q95 -0.19 SD), so the draws are slightly low and shifted left. The reference is right-skewed, so the right tail is a little too light.
- beta[4]: mean error -0.083 SD, sd_ratio 0.965 (narrowest). beta[5]: mean error +0.072 SD, q05 error 0.21 SD.
- Other betas have mean errors under 0.05 SD and sd_ratio 0.97 to 1.03. Location and width are good; the deviations are mostly in the tails and in sigma's skew.

Uncorrected draws: sigma has sd 0 by construction. beta[7] is still close (mean error 0.02 SD, sd_ratio 0.98), as expected since beta given sigma is nearly Gaussian and the sigma uncertainty has a small effect.

## Findings
No package problems seen. `converged` was TRUE with a tiny gradient and no warnings, despite the outer SD (about 0.11) being well below 1 and the start being far from the mode. The residual disagreement is consistent with the skewed sigma marginal, which a Gaussian outer approximation cannot capture. Nothing else suspicious. The reference draws became visible to me only through `metrics.json`, after the final attempt.
