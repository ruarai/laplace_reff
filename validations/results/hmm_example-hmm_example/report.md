# hmm_example-hmm_example

## Result
Outcome `converged`, 1 attempt. Corrected draws: mean_sd `acceptable`, w1 `acceptable`. Uncorrected: both `poor` (expected, outer held fixed). Manifest prediction: `acceptable` ("Nonconvex likelihood and zero init on ordered means"), which matches.

## Attempts
1. outer = `theta1.1`, `theta2.1` (transition logits); mu.1, mu.2 inner. Reasoning: given the transitions, mu has tight priors and is well identified, so close to Gaussian; mu's unconstrained scale (log, log-increment) has small SDs, so keeping it inner avoids nlminb scale problems. Risks named: logit SDs possibly far from 1, nonconvex inner problem from zero init. Outcome `converged`, fit time 0.333 s, no warnings. outer_se were 0.33 and 0.30 (below 1 but nlminb stopped fine); distance_sd 2.4e-6; 16 inner solves, 0 failures.

## Agreement
Errors are in reference SD units. Worst corrected variables: theta2[1]/theta2[2] (mean_err 0.197, w1 0.197, sd_ratio 1.08, q05/q50/q95 errors 0.21/0.15/0.31), so slightly shifted in location with a slightly wider posterior (8%) and the upper tail shifted most. Next: mu[1] (mean_err 0.107, sd_ratio 1.00), mu[2] (0.090, 1.00), theta1 (|mean_err| 0.06, sd_ratio 0.96). Mu location/width match well. Uncorrected: outer variables have sd 0 by construction; their means are within 1e-4 SD for theta1 (not informative beyond that).

## Findings
None indicating a package problem. Converged flag was consistent with the tiny gradient and the small deviations from reference. Small theta2 location shift is consistent with a Laplace approximation to a skewed (simplex-logit) marginal.
