# Local Review: Local Review

Generated: 2026-11-06T04:31:16.169Z
Repository Root: /pvol/source/laplace_reff
Branch: master
HEAD: 46d1b914e7034920bca4531355bbcf14cc3d1990

## R/fit.R

### R-006

Location: R/fit.R:32
Status: open

As discussed in model.R, make model path + data the only entry-point.

```
model, data = NULL
```


## R/model.R

### R-002

Location: R/model.R:9
Status: open

Lets delete this as an exported function.

Instead, we can have laml_fit(stan_file, data, ...) be the default entry-way.

The model.R file can stay, just not exported.

```
laml_model <- function(stan_file, data, seed = 1L) {
```

### R-007

Location: R/model.R:37
Status: open

Rename to "get_outer_param_indices"

```
outer_index
```

### R-003

Location: R/model.R:129
Status: open

Can we use a function that returns a string here instead? Then we don't need to deal with a temporary file.

```
jsonlite::write_json
```
