# Register an ensemble-source coercer for a producer class

Extends
[`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md)
so a new producer of simulation ensembles becomes ingestible without
modifying quorum. The coercer takes a producer object and returns an
`fb_ensemble`. This is the constellation extensibility seam for contract
C5: a member registers its coercer rather than quorum hard-coding the
member.

## Usage

``` r
register_ensemble_source(producer_class, coercer)
```

## Arguments

- producer_class:

  A single string – the S3 class of the producer object.

- coercer:

  A function `function(x, ...) -> fb_ensemble`.

## Value

Invisibly `NULL`.
