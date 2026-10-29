# Derive an informative flexyBayes prior from a simulation ensemble

Constructs an `fb_prior` from a calibrated parameter ensemble – the
"generalise" step that carries a process-model calibration forward into
a flexyBayes fit. The ensemble is ingested through the C5 contract
([`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md)),
so any conforming producer works (a PESTO manifest, a raw `apsimx`
ensemble, a file).

## Usage

``` r
fb_prior_from_ensemble(
  ensemble,
  method = c("moments", "pesto", "kde"),
  parameters = NULL
)
```

## Arguments

- ensemble:

  A C5 ensemble source: an `fb_ensemble`, a PESTO
  `pesto_ensemble_manifest`, a `list(params, outputs, ...)`, or a file
  path.

- method:

  One of `"moments"` (default), `"pesto"`, `"kde"`.

- parameters:

  Optional character vector selecting a subset of the ensemble's
  parameter columns. `NULL` (default) uses all of them.

## Value

An `fb_prior` object (see
[`fb_prior()`](https://aagi-aus.github.io/flexyBayes/reference/fb_prior.html)),
ready to pass to `flexybayes(..., prior = )`.

## Details

The `"moments"` method (the default, self-contained) fits an independent
`normal(mean, sd)` prior to each parameter from its ensemble marginal
mean and standard deviation, emitted as
`b("<param>") ~ normal(mean, sd)` fixed-effect priors. **Cross-parameter
correlation is discarded** – the moment-only path keeps the marginals,
not the joint. The richer joint method (`"pesto"`, the PESTO-native
prior preserving covariance + positive-orthant structure) and the
kernel-density method (`"kde"`, via kernR) are specified but not yet
wired; they raise a structured error naming their gate and the available
fallback.

## See also

[`fb_pesto()`](https://max578.github.io/quorum/reference/fb_pesto.md),
[`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md),
[`fb_prior()`](https://aagi-aus.github.io/flexyBayes/reference/fb_prior.html).

## Examples

``` r
e <- fb_ensemble(
  params = data.frame(k = stats::rnorm(50, 2, 0.3),
                      r = stats::rnorm(50, 0.5, 0.1)),
  outputs = data.frame(yield = stats::rnorm(50))
)
p <- fb_prior_from_ensemble(e)
p
#> <fb_prior> 2 specifications
#>   b("k") ~ normal(mean = 1.9888, sd = 0.3417627)
#>   b("r") ~ normal(mean = 0.5005054, sd = 0.1030884)
```
