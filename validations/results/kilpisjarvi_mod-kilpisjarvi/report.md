# kilpisjarvi_mod-kilpisjarvi

## Result
Outcome: `converged` on attempt 1 (1 of 3 attempts used). Corrected draws: mean_sd `good`, w1 `good`. Uncorrected draws: `poor` / `poor` (expected, as outer is fixed). Manifest prediction: `acceptable` ("Uncentred year covariate: extreme alpha-beta correlation and scale"). The result was better than predicted.

## Attempts
1. outer = `sigma` (unconstrained log sigma). Given sigma, alpha and beta are exactly Gaussian, so the inner Laplace is exact. Expected risks: log-sigma SD about 0.09, far below 1; uncentred x (about 4000) gives a badly conditioned alpha-beta block. Outcome `converged`, fit time 0.41 s, 14 inner solves, 0 failures, no warnings. Optimum log sigma = 0.1109, SE 0.092, gradient -4e-8, distance 3.9e-9 sd. nlminb message "relative convergence (4)".

## Agreement
Corrected draws (worst first):
- sigma: mean error -0.079 SD (ref 1.132 vs 1.123), sd ratio 0.955, w1 0.079. q95 error -0.33 SD, so the upper tail is lighter than the reference. This is the skew of sigma, which a Gaussian on log sigma only partly captures.
- alpha, beta: mean errors under 0.01 SD, sd ratio 0.956, w1 about 0.04. The width is about 4% narrow.

Uncorrected draws: alpha and beta are close (sd ratio 0.99, w1 0.035). sigma has sd ratio 0 by construction (a point value).

## Findings
No package problem seen. The small-SD outer parameter (0.09) did not cause a false stop: the convergence check passed with distance 4e-9, and starting at 0 was fine. The 4% narrow widths come from the Gaussian approximation of the outer log-sigma, which is expected with N=62. The alpha-beta correlation and scale (about 4000x) caused no inner solver trouble.
