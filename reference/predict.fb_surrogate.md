# Predict from a quorum surrogate (mean + sd per output)

Returns the surrogate's predictive distribution at new parameter sets.
By default a `data.frame` carrying, for each emulated output `<o>`, a
`<o>_mean` and a `<o>_sd` column. Reporting the predictive sd – not only
the mean – is the contract-C7 distribution-preserving requirement.

## Usage

``` r
# S3 method for class 'fb_surrogate'
predict(object, newdata, cov = FALSE, ...)
```

## Arguments

- object:

  An `fb_surrogate` from
  [`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md).

- newdata:

  A `data.frame` of new parameter sets; must contain the surrogate's
  `param_names` columns.

- cov:

  `FALSE` (default) for the marginal `data.frame`; `TRUE` for an
  `fb_surrogate_prediction` with the dense per-row cross-output
  covariance array; `"lowrank"` for the compact factored covariance (a
  joint `rff` fit only).

- ...:

  Unused.

## Value

With `cov = FALSE` (default) a `data.frame` with `<output>_mean` and
`<output>_sd` columns, one row per row of `newdata`. With `cov = TRUE`
an `fb_surrogate_prediction` (`mean`, `cov`, `output_names`). With
`cov = "lowrank"` an `fb_surrogate_prediction` (`mean`, `cov_lowrank`,
`output_names`).

## Details

With `cov = TRUE` it returns the **joint** predictive distribution: an
`fb_surrogate_prediction` carrying the predictive mean matrix and a
per-row cross-output covariance array (contract C7 clause 4). A joint
`rff` surrogate supplies the full covariance; a marginals-only surrogate
(independent `rff`, or a conformer reporting only `<o>_sd`) returns a
diagonal covariance built from the marginal sds, so the call always
states its basis.

With `cov = "lowrank"` a joint `rff` surrogate returns the same joint
predictive in a **compact factored** form for large output counts: an
`fb_surrogate_prediction` carrying `cov_lowrank = list(u, d, infl)` such
that per-row covariance is `infl[i] * (u u' + diag(d))` – `O(k q + n)`
storage instead of the dense `O(k^2 n)` array. The factor `u` has the
surrogate's `cov_rank` columns (the full `k` if it was fit without
`cov_rank`). Reconstruct a slice with
[`fb_cov_slice()`](https://max578.github.io/quorum/reference/fb_cov_slice.md).
The diagonal still equals `<o>_sd^2` exactly.

For the reference `rff` method, writing \\\phi(x)\\ for the random
Fourier feature map of a new parameter set \\x\\, the reported mean and
variance are the Bayesian-linear-regression predictive moments \$\$ E\[y
\mid x\] = \phi(x)^\top \mu_N, \qquad Var\[y \mid x\] = 1/t +
\phi(x)^\top S_N \phi(x), \$\$ with posterior weight mean \\\mu_N\\,
posterior weight covariance \\S_N\\, and noise precision \\t\\ set by
MacKay evidence maximisation at fit time (Bishop, 2006, sec. 3.3, 3.5).

## References

Bishop, C. M. (2006). *Pattern Recognition and Machine Learning*.
Springer, secs. 3.3 and 3.5.

## Examples

``` r
theta <- cbind(p1 = runif(60, -2, 2), p2 = runif(60, -2, 2))
y <- theta %*% rbind(c(1.5, -0.8), c(0.4, 1.1)) + rnorm(120, 0, 0.1)
ens <- fb_ensemble(as.data.frame(theta), as.data.frame(y),
                    provenance = list(source = "raw"))
sur <- fit_surrogate(ens)
predict(sur, data.frame(p1 = 1, p2 = -1))
#>     V1_mean     V1_sd   V2_mean     V2_sd
#> V1 1.052805 0.1818922 -1.768903 0.1992059
```
