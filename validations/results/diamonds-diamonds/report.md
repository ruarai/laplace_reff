# diamonds-diamonds

## Result
Outcome: converged, 1 attempt. Corrected draws: mean_sd good, w1 good. Manifest prediction: linear / acceptable ("26 strongly correlated parameters, ill-conditioned inner Hessian").

## Attempts
1. outer = sigma. Model is linear-Gaussian, so given sigma the b and Intercept block is exactly Gaussian. Expected risks: SD of log sigma about 1/sqrt(2N) = 0.01, far below 1 (nlminb stopping short), start at 0 far from optimum (log sigma = -2.10), and an ill-conditioned inner Hessian. Outcome converged, fit time 0.79 s, 9 nlminb iterations, 19 inner solves, 0 failures, no warnings, distance_sd 1.3e-5.

## Agreement
Corrected: worst abs mean error 0.071 ref-SD (b[18]), worst SD ratio 1.046 (b[21]; lowest 0.958, b[6]), worst W1 0.075 (b[18]). These are all within the reference's Monte Carlo noise scale; no tail or width issues seen. Uncorrected: sigma scores poor by construction (point value, SD ratio 0, W1 0.80); its mean matches the reference (0.123 vs 0.123). The b variables are unchanged in quality (W1 at most 0.057).

## Findings
None. No warnings; convergence held despite the outer SD (0.0101) being 100x smaller than the assumed scale of 1, and despite the ill-conditioned design. Note that I read metrics.json only after the attempt finished.
