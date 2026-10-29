# Posterior-predictive check of a surrogate against held-out outputs

Tests whether a surrogate's predictive *distribution* matches the
simulator's at held-out parameter sets, using kernR's
maximum-mean-discrepancy posterior-predictive check
([`kernR::mmd_ppc()`](https://max578.github.io/kernR/reference/mmd_ppc.html)).
The surrogate's predictive distribution at `newdata` is sampled into a
predictive ensemble, which is compared against `observed` – the true
simulator outputs at those parameter sets. A rejection means the
emulator distorted the output distribution (typically by being over- or
under-dispersed, or by getting the cross-output correlation wrong), not
merely that its mean is off.

## Usage

``` r
fb_surrogate_ppc(
  surrogate,
  newdata,
  observed,
  n_draws = 1L,
  joint = TRUE,
  project = FALSE,
  whiten = FALSE,
  aggregate = FALSE,
  agg_weights = "uniform",
  seed = NULL,
  ...
)
```

## Arguments

- surrogate:

  An `fb_surrogate` from
  [`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md).

- newdata:

  A `data.frame` of held-out parameter sets (must contain the
  surrogate's parameter columns).

- observed:

  A matrix or `data.frame` of the true simulator outputs at held-out
  parameter sets, with columns named for the emulated outputs.

- n_draws:

  Predictive draws per row of `newdata` (default `1`); the predictive
  ensemble has `n_draws * nrow(newdata)` rows.

- joint:

  Logical; sample from the joint cross-output covariance (default
  `TRUE`) rather than independently per output. Has no effect for a
  single output, or for a surrogate that reports only marginals (its
  covariance is diagonal). When the surrogate stores a low-rank
  covariance (`cov_rank`), the joint draws are sampled from the factored
  form directly, so the `k x k` slice is never formed (the native
  low-rank PPC consumer).

- project:

  Logical; for a surrogate that stores a low-rank covariance
  (`cov_rank`), project both the predictive draws and `observed` onto
  the surrogate's `q` factor directions before the MMD (default
  `FALSE`). It then runs in `q` dimensions, not `k` – cheaper and
  higher-powered on the correlated cross-output structure for a large
  output count (the MMD loses power as the dimension grows). It is,
  deliberately, **blind to distortions orthogonal to the factor space**
  (purely idiosyncratic per-output errors, which the marginal `<o>_sd`
  and a `joint = FALSE` check cover), so it complements rather than
  replaces the full-space check.

- whiten:

  Logical; Mahalanobis-whiten both the predictive draws and `observed`
  by their **pooled covariance** before the MMD (default `FALSE`). This
  puts the outputs on a common footing, removing the cross-output scale
  heterogeneity that makes a single median bandwidth too coarse to
  resolve a distortion living in a low-variance direction. The map
  depends only on the pooled cloud (not the draws-vs-observed labels),
  so the permutation test stays valid; the same map is applied to both
  clouds, so a relative scale, shape, or mean difference between them is
  preserved. Empirically it lifts power substantially on localised /
  heterogeneous-scale distortions a raw-output check misses, with no
  blind spot found across a mean / variance / shape battery. A graduated
  relative ridge guards a near-singular pooled covariance (highly
  collinear outputs); it remains opt-in for that numerical reason.
  Composes with `project` (the projected coordinates are whitened) and
  `aggregate`.

- aggregate:

  Logical; run an **aggregated multi-kernel** MMD instead of a
  single-kernel (default `FALSE`). An MMDAgg test (Schrab et al. 2023)
  over an RBF bandwidth grid around the median heuristic, sharing the
  permutations across bandwidths and aggregating by the
  weighted-quantile statistic `min_g p_g / w_g` – it removes the
  bandwidth choice and is robust when the median heuristic is
  mis-scaled, at a valid level. Composes with `project`. Reads
  `n_permutations` and `alpha` from `...`.

- agg_weights:

  Kernel weights for `aggregate = TRUE`: a scheme (`"uniform"` default,
  or `"increasing"` / `"decreasing"` / `"centred"`, ordered
  smallest-to-largest bandwidth) or a numeric vector over the bandwidth
  grid. A larger weight loosens that kernel's threshold, so up-weighting
  the scale a distortion is expected to live at recovers power;
  `"uniform"` is the safe default (it recovers the min p-value
  aggregation).

- seed:

  Optional integer RNG seed (the caller's stream is restored).

- ...:

  Passed to
  [`kernR::mmd_ppc()`](https://max578.github.io/kernR/reference/mmd_ppc.html)
  (e.g. `n_permutations`); for `aggregate = TRUE`, `n_permutations` and
  `alpha` are read from here.

## Value

For the single-kernel, the
[`kernR::mmd_ppc`](https://max578.github.io/kernR/reference/mmd_ppc.html)
object (`$statistic`, `$p_value`, `$reject`, `$surprise_bits`); for
`aggregate = TRUE` an `fb_mmd_agg` object (`$p_value`, `$reject`,
`$statistic`, `$bandwidths`, `$p_per_bandwidth`).

## Details

This is the distribution-preserving counterpart to a mean-only accuracy
check: it exercises the predictive uncertainty it reports, not just the
mean. With `joint = TRUE` (default) the draws are sampled from the
**full cross-output predictive covariance**
([`predict.fb_surrogate()`](https://max578.github.io/quorum/reference/predict.fb_surrogate.md)
with `cov = TRUE`), so the emulator's cross-output correlation is
tested; this is the second consumer of the joint covariance after
[`fb_surrogate_ies()`](https://max578.github.io/quorum/reference/fb_surrogate_ies.md).
With `joint = FALSE` each output is sampled independently from its
`<o>_sd`. On a simulator whose outputs are correlated, marginal draws
discard that correlation, so the joint path is the faithful check (a
marginals-only surrogate yields a diagonal covariance, and the two paths
then coincide).

## See also

[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md),
[`predict.fb_surrogate()`](https://max578.github.io/quorum/reference/predict.fb_surrogate.md),
[`fb_surrogate_ies()`](https://max578.github.io/quorum/reference/fb_surrogate_ies.md).

## Examples

``` r
g <- rbind(c(1.5, -0.8), c(0.4, 1.1))
theta <- cbind(p1 = runif(80, -2, 2), p2 = runif(80, -2, 2))
y <- theta %*% t(g) + matrix(rnorm(160, 0, 0.1), 80, 2L)
colnames(y) <- c("o1", "o2")
ens <- fb_ensemble(as.data.frame(theta), as.data.frame(y),
                    provenance = list(source = "raw"))
sur <- fit_surrogate(ens)

held <- data.frame(p1 = runif(30, -2, 2), p2 = runif(30, -2, 2))
truth_held <- held$p1 %o% g[, 1] + held$p2 %o% g[, 2] +
  matrix(rnorm(60, 0, 0.1), 30, 2L)
colnames(truth_held) <- c("o1", "o2")
check <- fb_surrogate_ppc(sur, held, as.data.frame(truth_held),
                           n_draws = 3L, seed = 1L, n_permutations = 99L)
check$p_value
#> [1] 0.94
```
