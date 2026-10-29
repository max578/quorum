# Per-component agreement between two lenses

Compare two lenses' parameter draws component by component, on the hub's
terms. For every component the two lenses share, the table reports each
lens's posterior mean and SD, the ratio of the SDs, the drift at the two
reported quantiles, the Wasserstein-1 distance between the two
marginals, the mean shift and the Wasserstein-1 distance expressed in
reference-SD units, and the verdict those three scaled quantities imply.

## Usage

``` r
agreement_pairwise(
  a,
  b,
  names = NULL,
  thresholds = agreement_thresholds(),
  sd_ref = c("max", "pooled", "a", "b")
)
```

## Arguments

- a, b:

  A
  [`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
  of kind `"parameters"`, or a named list of numeric vectors in that
  shape.

- names:

  Optional character vector naming the components to compare. The
  default compares every component the two lenses share, in `a`'s order.
  Every name asked for must be present on both sides.

- thresholds:

  A list from
  [`agreement_thresholds()`](https://max578.github.io/quorum/reference/agreement_thresholds.md).

- sd_ref:

  The reference SD the mean shift and the Wasserstein-1 distance are
  scaled by: `"max"` (the hub's larger-of-the-two, the default),
  `"pooled"` (the root-mean-square of the two), `"a"` or `"b"`.

## Value

A data.frame with one row per compared component and the columns
`param`, `mean_a`, `mean_b`, `sd_a`, `sd_b`, `sd_ratio`, `q025_diff`,
`q975_diff`, `wasserstein_1`, `mean_shift_sd`, `w1_sd`, `verdict` and
`reason`; or a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
of scope `"comparison"` when the two lenses share no component, when a
requested component is absent, or when either input is a response-curve
rather than a parameter lens.

## Details

The reference SD is the larger of the two posterior SDs, which is the
scale the hub uses (`.triangulate_verdicts`, `flexyBayes` 0.10.0
`R/triangulate.R:809`:
`s_ref <- max(metrics$sd_a[[i]], metrics$sd_b[[i]], na.rm = TRUE)`), and
it is the default here so that a quorum comparison returns the same
numbers the hub's comparison returned on the same draws. `sd_ref` offers
the pooled and the one-sided scales for callers who want the comparison
read against a fixed lens instead, at the cost of leaving the hub's
scale.

A component with no posterior spread on either side cannot be scaled
against anything, so it is reported with its raw distances, a
`not_compared` verdict and the hub's reason string rather than a verdict
the scale cannot support.

Agreement is not validation. Two lenses that share a sampler, an
objective, a prior or a data-preparation step can agree because they
share it; the independence ledger, not this table, is what says whether
their agreement carries evidential weight.

## See also

[`agreement_status()`](https://max578.github.io/quorum/reference/agreement_status.md)
for the overall verdict,
[`agreement_matrix()`](https://max578.github.io/quorum/reference/agreement_matrix.md)
for a quorum of more than two lenses.

## Examples

``` r
set.seed(1)
a <- list(intercept = rnorm(500L, 1, 0.5), slope = rnorm(500L, 2, 0.3))
b <- list(intercept = rnorm(500L, 1, 0.5), slope = rnorm(500L, 2.9, 0.3))
agreement_pairwise(a, b)[, c("param", "w1_sd", "verdict")]
#>       param      w1_sd    verdict
#> 1 intercept 0.05585061 concordant
#> 2     slope 2.81566274 discordant
```
