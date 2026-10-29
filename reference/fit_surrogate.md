# Fit a distribution-preserving surrogate to a simulation ensemble

Trains an emulator mapping the ensemble's parameter sets
(`ensemble$params`, the design `X`) to its outputs (`ensemble$outputs`,
the responses `Y`), so an expensive forward model can be replaced by a
fast surrogate that still reports predictive **uncertainty** (mean + sd
per output) – the property a calibration / inverse step needs preserved
(contract C7, `inst/surrogate_contract.md`). The ensemble is ingested
through C5
([`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md)),
so any conforming producer works.

## Usage

``` r
fit_surrogate(
  ensemble,
  method = NULL,
  outputs = NULL,
  n_features = 256L,
  ard = TRUE,
  ard_refit = FALSE,
  joint = TRUE,
  cov_rank = NULL,
  cov_method = "eigen",
  seed = 1L,
  ...
)
```

## Arguments

- ensemble:

  A C5 ensemble source (an `fb_ensemble`, a PESTO manifest, a
  `list(params, outputs)`, or a path).

- method:

  One of the registered methods; `"rff"` (default) is always available.
  See
  [`register_surrogate()`](https://max578.github.io/quorum/reference/register_surrogate.md).

- outputs:

  Optional character vector selecting output columns to emulate; `NULL`
  (default) emulates all of them.

- n_features:

  Number of random Fourier features for `method = "rff"`.

- ard:

  Logical; for `method = "rff"`, learn per-dimension (automatic
  relevance determination) lengthscales by maximising the model evidence
  (default `TRUE`). `FALSE` uses a single isotropic median-heuristic
  lengthscale. Vacuous with one parameter.

- ard_refit:

  When `ard = TRUE`, controls the relevance objective. `FALSE` (default)
  holds the prior/noise precisions `(a, t)` at their isotropic-fit
  values. `TRUE` re-estimates `(a, t)` by evidence at each candidate
  lengthscale (the evidence *profiled* over `(a, t)`) – a fuller,
  never-lower marginal likelihood, but in-sample, so it can over-shorten
  lengthscales. `"cv"` instead maximises the **held-out** predictive
  log-density over a k-fold split, the regularised fuller-ARD: it keeps
  the relevance sharpening without the in-sample over-shortening.

- joint:

  Logical; for `method = "rff"` with two or more outputs, fit a joint
  multi-output model preserving the cross-output predictive covariance
  (default `TRUE`). `FALSE` fits one independent model per output
  (marginals only). The per-output `<o>_sd` contract is unchanged either
  way; only the off-diagonal covariance (exposed by
  `predict(..., cov = TRUE)`) differs.

- cov_rank:

  Optional integer; for a joint `rff` fit with `k` outputs, store the
  cross-output covariance in a rank-`cov_rank` factor-analysis form
  (`U U' + diag`) instead of the dense `k x k`, for large output counts.
  The per-output marginal sd and the covariance diagonal are reproduced
  exactly; only the off-diagonal covariance is approximated. `NULL`
  (default) or `cov_rank >= k` keeps the full covariance. See
  `predict(..., cov = "lowrank")` for the compact predictive return.

- cov_method:

  How the rank-`cov_rank` factor is fitted (only when `cov_rank` is
  set): `"eigen"` (default) truncates the covariance's
  eigendecomposition; `"fa"` learns the loadings by factor-analysis EM,
  which recovers them more faithfully when the residual diagonal is
  heteroscedastic (the eigenvectors of the full covariance are otherwise
  contaminated by the uneven diagonal); `"auto"` picks `"fa"` or
  `"eigen"` from the heteroscedasticity of the eigen-residual diagonal.
  The covariance diagonal is reproduced exactly in every case. The
  resolved method is recorded in the fitted object.

- seed:

  Integer RNG seed for the random features (reproducibility).

- ...:

  Passed to a registered method's fit function.

## Value

An object of class `c("fb_surrogate", "list")` with a
[`predict.fb_surrogate()`](https://max578.github.io/quorum/reference/predict.fb_surrogate.md)
method.

## Details

The built-in `method = "rff"` (default) is a self-contained
random-Fourier- features Bayesian linear surrogate with
evidence-optimised predictive variance. By default it uses **ARD**
lengthscales (per-input relevance learned from the evidence) and a
**joint** multi-output fit that preserves the predictive covariance
across outputs (not only the marginals) – the distribution-preserving
property the calibration / inverse consumers rely on. Richer methods
(kernR's CME, PESTO's GP) register via
[`register_surrogate()`](https://max578.github.io/quorum/reference/register_surrogate.md).

## See also

[`predict.fb_surrogate()`](https://max578.github.io/quorum/reference/predict.fb_surrogate.md),
[`register_surrogate()`](https://max578.github.io/quorum/reference/register_surrogate.md),
[`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md).

## Examples

``` r
set.seed(1)
x <- data.frame(a = runif(120, -2, 2), b = runif(120, -2, 2))
e <- fb_ensemble(
  params = x,
  outputs = data.frame(y = sin(x$a) + 0.5 * x$b^2 + rnorm(120, 0, 0.05))
)
s <- fit_surrogate(e)
predict(s, data.frame(a = 0, b = 1))
#>      y_mean       y_sd
#> y 0.5216926 0.05329176
```
