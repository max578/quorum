# The draws every lens returns

A `quorum_draws` object is the one shape a lens hands to the comparison.
For `kind = "parameters"` the draws are a named list of numeric vectors,
one per estimand component, named with the hub's canonical parameter
names. For `kind = "response_curve"` the draws are a numeric matrix with
one row per draw and one column per grid point, and `grid` carries the
candidate grid (for example nitrogen rates).

## Usage

``` r
quorum_draws(
  draws,
  kind = "parameters",
  grid = NULL,
  source = "unknown",
  diagnostics = list()
)
```

## Arguments

- draws:

  Named list of numeric vectors, or a numeric matrix.

- kind:

  One of `"parameters"` or `"response_curve"`.

- grid:

  Numeric grid for a response curve, else `NULL`.

- source:

  Single string naming where the draws came from.

- diagnostics:

  List of the producing lens's own diagnostics.

## Value

A `quorum_draws` S7 object.
