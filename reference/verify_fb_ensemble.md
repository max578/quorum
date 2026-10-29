# Verify a simulation ensemble against the C5 contract

Checks that `e` honours the ensemble-source contract
(`inst/ensemble_source_contract.md`): row-aligned positive-length
`params` / `outputs`, any `observed` names a subset of the outputs, any
`output_dims` one row per output column, and a `provenance$source`.
Returns a verdict rather than erroring, so callers can branch (the
[`fb_ensemble()`](https://max578.github.io/quorum/reference/fb_ensemble.md)
constructor turns a failure into an error; an interactive check can
inspect the message).

## Usage

``` r
verify_fb_ensemble(e)
```

## Arguments

- e:

  An object to check (an `fb_ensemble`, or any list with the same
  components).

## Value

A list `list(ok = <logical>, message = <character>)`. `ok = TRUE` and an
empty message on conformance; `ok = FALSE` and the first violation
otherwise.
