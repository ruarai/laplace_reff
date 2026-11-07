# Brief: validate lapland on one posteriordb posterior

You validate `lapland::laml_fit`, a nested Laplace approximation, on one posterior.
It optimises the *outer* parameters and integrates out the *inner* ones with a
Laplace approximation at the inner mode. Your posterior is named in your task.
Work from the repository root, `/pvol/source/lapland`. Read `R/fit.R` for the API.

## Rules

- Write only inside `validations/results/<posterior>/`. Do not edit `R/`, the
  harness, the Stan model or the data, and do not commit.
- Do not open `reference_posteriors` in posteriordb, by any route, before your
  final attempt has finished. Do not read other posteriors' results.
- Do not fit, optimise or sample outside `run_attempt.sh`, and do not use Stan's
  samplers at all. Reading the model and data and reasoning about them is the
  way to choose outer parameters.
- Never delete or rewrite a finished attempt. Report failures plainly: a failure
  is a useful finding, and working around it is not your job.
- If the harness itself seems broken, stop and say so in your final message.

## Steps

1. Run `validations/prepare.sh <posterior>`. It compiles the model and prints the
   Stan file path and the unconstrained parameter names. The data is in
   `validations/build/data/`.
2. Read the Stan model and choose `outer`:
   - Prefer parameters given which the rest is close to Gaussian. Typical choices
     are scale parameters, hyperparameters and length scales.
   - Keep `outer` small, since each gradient evaluation costs more with more outer
     parameters. At least one parameter must stay inner.
   - Outer parameters should have posterior SDs near 1 on the unconstrained scale,
     and `laml_fit` starts every parameter at zero. Judge both from the priors and
     data, and name the risks you see.
   - `outer` entries are names from `prepare.sh`; a container name such as `beta`
     selects all of its elements.
3. Write `validations/results/<posterior>/attempt-<n>/config.json`:
   ```json
   {
     "outer": ["sigma"],
     "inner_control": {},
     "outer_control": {},
     "rationale": "Why this outer set, and what you expect to go wrong."
   }
   ```
4. Start the attempt, detached, then wait for it:
   ```bash
   nohup validations/run_attempt.sh <posterior> <n> \
     > validations/results/<posterior>/attempt-<n>/run.log 2>&1 &
   ```
   ```bash
   validations/wait_attempt.sh <posterior> <n>
   ```
   Repeat the wait command while it prints `RUNNING`. An attempt can take over 40
   minutes. The limits are 10 minutes for `laml_fit` and 30 minutes for draws, and
   compilation is outside both. A refusal for an invalid config does not use up the
   attempt: fix the config and start again.
5. Read `outcome` in `status.json`:
   - `converged`: stop, even if agreement turns out to be poor.
   - `fit_timeout`, `fit_error` or `not_converged`: you may make another attempt,
     up to 3 in total, with a different `outer` or controls. Say what you changed
     and why. Read `fit_summary.json` and `fit.log` first.
   - `compile_error`: stop, as another attempt cannot help.
6. Write `validations/results/<posterior>/report.md`, using these headings:
   - **Result**: final outcome, attempts used, the labels for corrected draws, and
     the prediction from `validations/manifest.csv`.
   - **Attempts**: for each one, the outer set, reasoning, outcome and fit time.
   - **Agreement**: from `metrics.json`, the worst variables for corrected draws
     and how they differ from the reference (location, width, tails). Uncorrected
     draws hold outer at its optimum, so outer variables score poor by
     construction; say only what is informative about them.
   - **Findings**: anything suggesting a package problem or limitation, with the
     evidence. Include warnings and suspicious `converged` values. Do not propose
     code changes unless the cause is clear.

## Final message

Give the posterior name, outcome, attempts, corrected labels and worst metrics, and
any finding in two or three sentences. State anything you could not do.
