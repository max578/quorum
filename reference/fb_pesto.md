# Carry a PESTO calibration into flexyBayes

Ingests a calibrated simulation ensemble (a PESTO
`pesto_ensemble_manifest`, or any C5-conforming source via
[`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md))
and returns the flexyBayes-ready artefacts for the "generalise" step of
the calibration -\> validation -\> generalisation pipeline: the
canonical
[`fb_ensemble()`](https://max578.github.io/quorum/reference/fb_ensemble.md),
an informative prior derived from the calibrated parameters
([`fb_prior_from_ensemble()`](https://max578.github.io/quorum/reference/fb_prior_from_ensemble.md)),
and the per-parameter moment summary. The resulting `$prior` is passed
straight to `flexybayes(..., prior = )`.

## Usage

``` r
fb_pesto(x, method = c("moments", "pesto", "kde"), parameters = NULL)
```

## Arguments

- x:

  A C5 ensemble source (PESTO manifest, `fb_ensemble`, list, or path).

- method:

  Prior-construction method passed to
  [`fb_prior_from_ensemble()`](https://max578.github.io/quorum/reference/fb_prior_from_ensemble.md);
  `"moments"` (default), `"pesto"`, `"kde"`.

- parameters:

  Optional subset of parameter columns for the prior.

## Value

An object of class `c("fb_pesto", "list")` with components `ensemble`
(the
[`fb_ensemble()`](https://max578.github.io/quorum/reference/fb_ensemble.md)),
`prior` (the derived
[`fb_prior()`](https://aagi-aus.github.io/flexyBayes/reference/fb_prior.html)),
`moments` (a `data.frame` of `parameter`, `mean`, `sd`), `method`, and
`provenance`.

## Details

quorum never executes the simulator (APSIM is run upstream by `apsimx`);
this verb consumes the calibration result through the contract.

## See also

[`fb_prior_from_ensemble()`](https://max578.github.io/quorum/reference/fb_prior_from_ensemble.md),
[`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md).

## Examples

``` r
e <- fb_ensemble(
  params = data.frame(k = stats::rnorm(50, 2, 0.3)),
  outputs = data.frame(yield = stats::rnorm(50))
)
res <- fb_pesto(e)
res$prior
#> <fb_prior> 1 specification
#>   b("k") ~ normal(mean = 1.974134, sd = 0.3413884)
```
