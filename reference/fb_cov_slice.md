# Reconstruct a per-row covariance slice from a surrogate prediction

Returns the `k x k` cross-output predictive covariance at one row of the
`newdata` passed to
[`predict.fb_surrogate()`](https://max578.github.io/quorum/reference/predict.fb_surrogate.md),
from either the dense (`cov = TRUE`) or the compact factored
(`cov = "lowrank"`) form – so a consumer can work slice-by-slice without
materialising the full dense array for a large output count.

## Usage

``` r
fb_cov_slice(prediction, i = 1L)
```

## Arguments

- prediction:

  An `fb_surrogate_prediction` from
  `predict(<fb_surrogate>, newdata, cov = TRUE)` or `cov = "lowrank"`.

- i:

  Integer row index (a row of `newdata`; default `1`).

## Value

The `k x k` cross-output predictive covariance at row `i`, with output
names on both dimensions.

## See also

[`predict.fb_surrogate()`](https://max578.github.io/quorum/reference/predict.fb_surrogate.md).
