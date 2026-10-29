# Coerce a conforming producer to a canonical `fb_ensemble`

The single ingest entry point for contract C5. Dispatches on the
producer: an `fb_ensemble` is returned unchanged; a
`pesto_ensemble_manifest` (PESTO's S7 calibration manifest) is mapped
via the C2 -\> C5 bridge; a `list` carrying `params` / `outputs` is
wrapped; a length-1 character path is read from disk. Any other class is
looked up in the producer registry
([`register_ensemble_source()`](https://max578.github.io/quorum/reference/register_ensemble_source.md))
before erroring.

## Usage

``` r
as_fb_ensemble(x, ...)
```

## Arguments

- x:

  A conforming producer object (see Details / the contract).

- ...:

  Passed to the matched coercer.

## Value

An `fb_ensemble`.

## See also

`inst/ensemble_source_contract.md`.

## Examples

``` r
# an fb_ensemble round-trips unchanged
ens <- fb_ensemble(
  params = data.frame(p1 = runif(10)),
  outputs = data.frame(o1 = runif(10)),
  provenance = list(source = "raw")
)
identical(as_fb_ensemble(ens), ens)
#> [1] TRUE

# a bare list carrying params / outputs is wrapped the same way
as_fb_ensemble(list(params = data.frame(p1 = runif(5)),
                     outputs = data.frame(o1 = runif(5))))
#> -- fb_ensemble (simulation ensemble, contract C5) ----------
#>   source : raw
#>   sets   : 5
#>   params : 1 (p1)
#>   outputs: 1
#>   labelled: FALSE | observed: FALSE
#> ------------------------------------------------------------
```
