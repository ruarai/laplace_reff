# Validation against posteriordb

Compares `laml_fit` with reference posteriors from
[posteriordb](https://github.com/stan-dev/posteriordb). No Stan sampling is run.

## Setup

Expects a posteriordb clone at `../posteriordb`, or set `POSTERIORDB`. Pilot and
results used commit `91027f9`.

```bash
validations/setup.sh [commit]   # install lapland from a fixed commit into build/lib
```

## Files

- `manifest.csv`: the posteriors, with suitability predicted before any fit.
- `bands.json`: agreement bands, fixed before any fit.
- `SUBAGENT_BRIEF.md`: instructions for the agent handling each posterior.
- `prepare.sh`, `run_attempt.sh`, `wait_attempt.sh`: entry points. `scripts/` holds
  the R behind them.
- `results/<posterior>/`: configs, attempt logs, metrics and reports. `build/` is
  ignored by git and holds the package, compiled models, fits and draws.

## Method

Each posterior gets up to 3 attempts. Only a timeout, an error or `converged =
FALSE` allows a retry. Models run verbatim, and only `outer`, `inner_control` and
`outer_control` vary.

`laml_fit` has 10 minutes, excluding compilation. Draws have a further 30: 4000
uncorrected and 1000 corrected. Thread counts are left at their defaults.

Each variable in the reference file is compared on the constrained scale, using
mean error, quantile errors and Wasserstein-1 distance in reference SDs, and the
SD ratio. A posterior takes the label of its worst variable, and corrected draws
are the headline. Uncorrected draws hold outer parameters fixed, so they score
poor by construction on any outer variable.

| Label | Mean/SD | W1 |
|---|---|---|
| Good | error < 0.1 and ratio in [0.9, 1.1] | < 0.15 |
| Acceptable | error < 0.25 and ratio in [0.75, 1.33] | < 0.4 |
| Poor | otherwise | otherwise |

`scripts/calibrate_bands.R` gives the labels under exact agreement, where only
Monte Carlo noise differs. W1 stays good. The mean/SD band misses good about 8.5%
of the time at 26 variables and 17-23% at 66, so read a near-threshold "acceptable"
on a large posterior as noise.

Attempts load a verified library from `build/verified/` and never run `make`; see
the run notes in `REPORT.md`. `VALIDATION_FIT_LIMIT` overrides the 600-second fit
limit, and `VALIDATION_RESULTS` the results folder, for testing the harness.

Run `Rscript validations/scripts/summarise.R` to write `results/summary.csv`.
