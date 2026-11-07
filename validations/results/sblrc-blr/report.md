# sblrc-blr

## Result
Outcome `converged` in 1 of 3 attempts. Corrected draws: mean_sd `good`, w1 `good`. Prediction in manifest.csv: `good` (linear; "Conditionally Gaussian given sigma; correlated design"). The prediction held.

## Attempts
1. outer = `sigma`. Given sigma the betas are exactly Gaussian, so the inner Laplace is exact. Expected risks: the SD of log sigma is about 0.07 rather than 1, the start at sigma=1 is far from the data scale, and the unscaled X could badly scale the inner problem. Outcome `converged`, fit time 0.459 s (13 inner solves, 8 function and 5 gradient evaluations, no warnings). nlminb reported code 5, "both X-convergence and relative convergence", with convergence 0. distance_sd was 9.6e-10 and the gradient -1.3e-8.

## Agreement
Corrected draws: worst abs mean error 0.055 reference SDs (beta[1]), worst SD ratio 0.960 (beta[3]), worst W1 0.063 (beta[1]). sigma has mean error -0.055 SD, SD ratio 1.005, and 5% and 95% quantile errors of -0.14 and -0.12 SD, so its location and tails are slightly off but well within tolerance. The betas match in location, width and tails.

Uncorrected draws score `poor`, as expected, because sigma is fixed at its optimum (SD ratio 0, W1 0.79 for sigma). The betas are still close (W1 at most 0.035, SD ratios 0.98 to 0.99): conditioning on sigma at its mode loses only about 1 to 2% of their width.

## Findings
No package problem found. The outer SD (outer_se 0.073) is far below the recommended 1, but the fit still reached the optimum, so the scale warning in the docs did not bite here. Starting log sigma at 0 against data of order 100 caused no trouble.
