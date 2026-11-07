# gp_pois_regr-gp_pois_regr

## Result
Outcome `converged` on attempt 1 of 3 (1 used). Corrected draws: mean_sd `acceptable`, w1 `acceptable`. Uncorrected: both `poor`. Manifest prediction: group `latent`, predicted `acceptable` (risk: "N=11: skewed rho and alpha marginals"). The result matches the prediction.

## Attempts
1. outer = {rho, alpha}; inner = f_tilde (11). Given the hyperparameters, f_tilde has a N(0,1) prior and a Poisson-log likelihood with sizeable counts, so it is near Gaussian. Risks named in advance: the gamma(25,4) prior makes log rho SD about 0.2 (well under 1), the start at rho=1 is about 1.8 log units from the prior mode, and alpha is likely skewed. The 1e-10 jitter could cause ill-conditioning at small rho. Outcome `converged`, fit time 0.49 s, 8 nlminb iterations, 19 inner solves, 0 failures, no warnings, distance_sd 1.1e-6, gradients about 1e-5 or smaller. Optimum rho=1.74, alpha=1.01 (constrained scale).

## Agreement
Corrected draws (worst_abs_mean_err 0.171, worst_sd_ratio 0.958, worst_w1 0.172):
- The worst variables are f[7] and f[8]: means off by about 0.17 SD (f[7] mean 1.97 vs 1.93 reference, f[8] 3.20 vs 3.18). Their SD ratios are about 1.00. This is a small location shift.
- Most f's show a small positive mean shift of 0.07-0.17 reference SDs, with SD ratios of 0.97-1.01. q05_err is larger than the mean error for some (f[6] 0.25, f[7] 0.28), so the lower tail is slightly off.
- rho: mean 5.72 vs 5.67, sd ratio 1.01, w1 0.08. alpha: mean 2.82 vs 2.92 (err -0.13 SD), sd ratio 0.96, w1 0.13. The laml alpha is slightly narrow and low, consistent with the skew noted in the manifest, but the effect is small.
Uncorrected draws hold rho and alpha at the optimum, so they have zero SD and score poor by construction. The f's there are close in location (worst mean error 0.22 SD).

## Findings
No package problem seen. There were no warnings, convergence was clean, and the fit took under a second. The start at log rho = 0 was far from the mode (rho 1 vs about 5.7) given the tight prior, but the optimiser handled it. One oddity: `counts.gradients` is 2916 against 9 nlminb gradient evaluations, which is probably an inner-level count (not investigated). Leftover bias is small and plausibly from the Laplace approximation and the skewed hyperparameter marginals.
