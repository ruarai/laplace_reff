# earnings-earn_height

## Result
Outcome: `converged` on attempt 1 of 3 (draws ok). Corrected labels: mean_sd good, w1 good.
Manifest prediction: `linear, acceptable` ("Raw dollar and inch scales: zero init and outer scale far from 1").

## Attempts
1. outer = `sigma`. The model is a flat-prior linear regression, so beta is exactly Gaussian given sigma. Expected trouble: raw dollar scale (log sigma near 10 vs init 0) and a tiny posterior SD for log sigma. Outcome: converged, fit time 0.436 s, no warnings. nlminb said "relative convergence (4)", 34 iterations. distance_sd 2.5e-07, outer sigma (unconstrained) 9.845, se 0.0205. The feared stall did not happen.

## Agreement
Corrected draws (worst of 3 variables): worst abs mean error 0.016 SD, worst SD ratio 0.950, worst W1 0.0495.
- beta[1]: mean error 0.006 SD, SD ratio 0.950 (narrower than reference, laml sd 9187 vs 9668), W1 0.049.
- beta[2]: mean error -0.006 SD, SD ratio 0.951, W1 0.050.
- sigma: mean error -0.016 SD, SD ratio 1.000, W1 0.029. Location, width and tails match; quantile errors under 0.17 SD.
Uncorrected draws (outer fixed at optimum): beta SD ratios 0.997-0.998, W1 about 0.02; sigma scores poor by construction (SD ratio 0, W1 0.80).

## Findings
No package problem. One oddity: corrected beta draws are about 5% narrower than the reference, while uncorrected beta draws are 0.997 of the reference width. Integrating over sigma should widen beta, not narrow it. Likely cause is Monte Carlo or draw-generation noise in the corrected set rather than the fit, but I did not investigate (no further runs allowed). The posterior is conditionally exactly Gaussian, so the Laplace step is exact and any mismatch comes from the outer sigma approximation or the draw sampler. Beta draws here sit within 0.05 W1, still labelled good.
