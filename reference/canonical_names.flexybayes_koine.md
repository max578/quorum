# Canonical names for a koine fit (self-naming)

S3 method on flexyBayes's exported `canonical_names()` generic. koine is
self-naming –
[`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
canonicalises the draws – so no relabel map is needed; a comparison
aligns on the already-canonical names.

## Usage

``` r
# S3 method for class 'flexybayes_koine'
canonical_names(fit, drop = FALSE, ...)
```

## Arguments

- fit:

  A `flexybayes_koine` object.

- drop:

  Unused; kept for generic signature compatibility.

- ...:

  Unused.

## Value

A list with an empty `map`, empty `transform`, and
`source = "self_naming"`.
