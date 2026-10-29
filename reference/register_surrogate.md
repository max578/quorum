# Register a surrogate-fitting method

Extends
[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md)
with a new conforming surrogate (contract C7,
`inst/surrogate_contract.md`) without modifying quorum. The fit function
takes the standardised design `x` (parameter sets), the response matrix
`y` (outputs), and `...`, and returns an object with a
[`predict()`](https://rdrr.io/r/stats/predict.html) method yielding a
per-output predictive mean and sd. This is how kernR's CME /
dist_regression and PESTO's GP surrogates plug in.

## Usage

``` r
register_surrogate(method, fit_fn)
```

## Arguments

- method:

  A single string naming the method.

- fit_fn:

  A function `function(x, y, ...) -> <surrogate model>`.

## Value

Invisibly `NULL`.
