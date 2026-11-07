# dogs-dogs

## Result
Outcome `converged` after 1 attempt (draws ok). Corrected labels: mean_sd `good`, w1 `good`. Uncorrected: both `poor`. Manifest prediction: `good` ("Logistic regression with informative data"), which matches.

## Attempts
1. outer = `beta.1` (intercept); inner = `beta.2`, `beta.3`. Default controls. No natural hyperparameter exists (3 coefficients, normal(0,100) prior), so I picked the intercept. Expected risks: posterior SD below 1 so nlminb might stop short, and strong correlation between outer and inner giving little separation. Outcome converged; fit time 0.467 s, 12 inner solves, 0 failures, no warnings, distance_sd 2e-9, outer SE 0.229.

## Agreement
Corrected draws (worst by w1 / mean error):
- beta[2]: ref mean -0.358, sd 0.0374; laml mean -0.355, sd 0.0359. Mean error 0.089 ref-SD, sd ratio 0.96 (slightly narrow), q05 error 0.22 SD, q95 0.15 SD, w1 0.090. Small location shift towards zero plus slightly narrow width.
- beta[3]: mean error -0.004 SD, sd ratio 0.965, w1 0.036; q05/q95 errors 0.09/-0.18 SD (slightly narrow tails).
- beta[1] (outer): mean error -0.023 SD, sd ratio 0.987, w1 0.034; q95 error -0.17 SD.
Uncorrected draws: beta[1] has SD 0 by construction; the inner variables are close to the corrected ones (beta[2] mean error 0.072 SD, sd ratio 1.007). The outer mean (1.795) is close to the reference (1.803).

## Findings
No package problem seen. No warnings, and `converged` is credible (gradient 9e-9, tiny distance_sd). The outer SD (0.23) is well below 1, yet nlminb reached the optimum, so the scale risk did not bite here. The remaining error is the small Gaussian-approximation narrowing (about 4%) of a mildly skewed logistic posterior.
