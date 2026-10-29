# A simulation ensemble as a mechanism lens

Reads a simulation ensemble as a lens on the response over a candidate
grid: one row of the ensemble's outputs per ensemble member, one column
per grid point. The simulator is the most independent witness the
orchestra has – it shares no sampler, no objective, no priors and no
data preparation with any statistical lens – and it is the only lens
that can express a plateau, a threshold or a non-monotone response
without being told to look for one, so it declares all four shapes.

## Usage

``` r
lens_mechanism(ensemble, grid, output = NULL, name = "mechanism")
```

## Arguments

- ensemble:

  A simulation ensemble: an
  [`fb_ensemble()`](https://max578.github.io/quorum/reference/fb_ensemble.md),
  a PESTO calibration manifest, a saved `.rds` path, or a list carrying
  `params` and `outputs`. It reaches the canonical shape through
  [`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md),
  so an object no coercer covers is a programmer error rather than a
  decline.

- grid:

  Non-empty numeric vector of candidate values the response is read
  over.

- output:

  Which output columns carry the response, when the ensemble holds more
  than one output set: a character vector of column names, or a single
  string naming a value of the ensemble's `output_dims$variable`. `NULL`
  (the default) takes every output column, which is right for a
  single-output ensemble.

- name:

  Single non-empty string naming the lens.

## Value

A
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
of kind `response_curve` whose `fit()` returns a
[`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
matrix with one row per ensemble member and one column per grid point,
or a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
with reason `grid_mismatch` (the selected outputs do not cover the grid)
or `outputs_not_numeric` (the selected columns do not hold a numeric
response).

## Details

quorum never runs the simulator. The ensemble is produced upstream and
reaches this function through the C5 ingest contract, so a
`pesto_ensemble_manifest`, a saved ensemble and a bare list carrying
`params` and `outputs` are all accepted on the same terms.

The grid check is the substance of this adapter. An ensemble whose
outputs do not cover the grid – the wrong number of columns, or
numerically-named columns naming different values from the grid – is a
mismatch between two descriptions of the same axis, and reading it
anyway would silently attach the simulator's response to the wrong
candidates. It returns a typed `grid_mismatch` decline instead.

## See also

[`fb_ensemble()`](https://max578.github.io/quorum/reference/fb_ensemble.md)
and
[`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md)
for the ingest contract.

## Examples

``` r
ens <- fb_ensemble(
  params = data.frame(k = c(0.1, 0.2, 0.3)),
  outputs = data.frame(a = c(4.1, 4.6, 5.0), b = c(5.2, 5.9, 6.1))
)
l <- lens_mechanism(ens, grid = c(0, 50))
dim(S7::prop(S7::prop(l, "fit")(NULL, NULL), "draws"))
#> [1] 3 2

# A grid the outputs do not cover is declined, not stretched to fit.
is_quorum_abstention(lens_mechanism(ens, grid = c(0, 50, 100)))
#> [1] TRUE
```
