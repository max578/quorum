# Surrogate-accelerated ensemble inversion (ES-MDA)

Calibrates a parameter ensemble against observed data using a
distribution-preserving surrogate (contract C7) in place of the forward
model. Runs Ensemble Smoother with Multiple Data Assimilation (ES-MDA;
Emerick and Reynolds, 2013): each of `n_iter` iterations applies a
Kalman update with the data covariance inflated by `n_iter`, so the
combined update equals a single tempered assimilation. No simulator is
run – every forward evaluation is a surrogate
[`predict()`](https://rdrr.io/r/stats/predict.html).

## Usage

``` r
fb_surrogate_ies(
  surrogate,
  observed,
  obs_sd,
  prior,
  n_iter = 4L,
  use_surrogate_sd = TRUE,
  use_surrogate_cov = TRUE,
  seed = NULL
)
```

## Arguments

- surrogate:

  An `fb_surrogate` from
  [`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md).

- observed:

  A named numeric vector of target observations; names must be a subset
  of the surrogate's emulated outputs.

- obs_sd:

  Observation-error standard deviation: a single number (shared) or a
  named numeric vector aligned with `observed`.

- prior:

  A `data.frame` (or matrix) of the prior parameter ensemble – one row
  per realisation; must contain the surrogate's parameter columns.

- n_iter:

  Number of ES-MDA iterations (equal inflation `alpha = n_iter`).

- use_surrogate_sd:

  Add the surrogate's mean predictive uncertainty to the data covariance
  (default `TRUE`).

- use_surrogate_cov:

  When the surrogate is joint, fold its full cross-output predictive
  covariance (not just the per-output variance) into the data covariance
  (default `TRUE`). Ignored when `use_surrogate_sd` is `FALSE` or the
  surrogate reports only marginals (the covariance is then diagonal and
  the two paths coincide).

- seed:

  Optional integer RNG seed for the observation perturbations
  (reproducibility); the caller's RNG stream is restored on exit.

## Value

An object of class `c("fb_surrogate_ies", "list")` with components
`posterior` (the updated ensemble `data.frame`), `prior`, `observed`,
`misfit` (mean data-misfit before each iteration and after the last),
`n_iter`, `use_surrogate_sd`, `surrogate_method`, `param_names`, and
`output_names`.

## Details

When `use_surrogate_sd = TRUE` (default) the surrogate's predictive
uncertainty is added to the observation-error covariance, so emulator
uncertainty inflates the assimilation noise – the inversion trusts the
surrogate less where it is less certain. This is the consumer that the
distribution-preserving surrogate exists to serve. When the surrogate is
joint (its `predict(cov = TRUE)` yields a cross-output covariance) and
`use_surrogate_cov = TRUE` (default), the **full** mean predictive
covariance enters the data covariance, so correlated emulator errors are
assimilated coherently rather than as independent per-output noise;
otherwise only the per-output predictive variance (the diagonal) is
used.

## References

Emerick, A. A. and Reynolds, A. C. (2013). Ensemble smoother with
multiple data assimilation. *Computers & Geosciences*, 55, 3-15.

## See also

[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md),
[`fb_surrogate_ppc()`](https://max578.github.io/quorum/reference/fb_surrogate_ppc.md).

## Examples

``` r
set.seed(1)
# forward model y = G theta; build a training ensemble and an emulator
g <- c(1.5, -0.8)
tr <- data.frame(p1 = runif(150, -1, 3), p2 = runif(150, -2, 2))
e <- fb_ensemble(
  params = tr,
  outputs = data.frame(y = g[1] * tr$p1 + g[2] * tr$p2)
)
s <- fit_surrogate(e)
prior <- data.frame(p1 = rnorm(200, 1, 1), p2 = rnorm(200, 0, 1))
fit <- fb_surrogate_ies(s, c(y = 2.3), obs_sd = 0.1, prior = prior)
colMeans(fit$posterior)
#>         p1         p2 
#>  1.3982422 -0.2452033 
```
