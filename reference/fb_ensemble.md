# Construct a canonical simulation-ensemble object

Builds an `fb_ensemble` – quorum's canonical container for a
parameter-to-output simulation ensemble (contract C5,
`inst/ensemble_source_contract.md`). `params` and `outputs` are the
`(X, Y)` an emulator or surrogate trains on; `output_dims` and
`observed` add the calibration framing when present. quorum never
executes the simulator (APSIM is run upstream by `apsimx`); this is the
ingest floor the methods-intense consumers share.

## Usage

``` r
fb_ensemble(
  params,
  outputs,
  observed = NULL,
  output_dims = NULL,
  provenance = list()
)
```

## Arguments

- params:

  A `data.frame`, one row per parameter set, columns the simulator's
  input parameters. Row order is the ensemble key.

- outputs:

  A `data.frame` row-aligned to `params`
  (`nrow(outputs) == nrow(params)`), columns the output dimensions.

- observed:

  Optional named numeric of target observations; names a subset of
  `colnames(outputs)`. `NULL` for a pure forward ensemble.

- output_dims:

  Optional `data.frame`, one row per `outputs` column, labelling it
  (e.g. `site`, `season`, `day`, `variable`). `NULL` when outputs are
  unlabelled.

- provenance:

  A named list of provenance fields; `source` is filled with `"raw"`
  when absent.

## Value

An object of class `c("fb_ensemble", "list")`.

## See also

[`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md),
[`verify_fb_ensemble()`](https://max578.github.io/quorum/reference/verify_fb_ensemble.md),
[`read_fb_ensemble()`](https://max578.github.io/quorum/reference/read_fb_ensemble.md).

## Examples

``` r
e <- fb_ensemble(
  params = data.frame(k = c(0.1, 0.2, 0.3)),
  outputs = data.frame(yield = c(4.1, 4.6, 5.0))
)
verify_fb_ensemble(e)$ok
#> [1] TRUE
```
