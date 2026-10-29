# Extract simple draws from a koine fit

S3 method on flexyBayes's exported `fb_as_draws_simple()` generic.
Returns a named list of numeric draw vectors over the canonical
parameters, the shape
[`lens_from_fit()`](https://max578.github.io/quorum/reference/lens_from_fit.md)
reads.

## Usage

``` r
# S3 method for class 'flexybayes_koine'
fb_as_draws_simple(fit, n_samples = 1000L, ...)
```

## Arguments

- fit:

  A `flexybayes_koine` object.

- n_samples:

  Unused (koine draws are pre-synthesised); kept for generic signature
  compatibility.

- ...:

  Unused.

## Value

A named list of numeric vectors, one per canonical parameter.
