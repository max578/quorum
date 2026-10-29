# Read a simulation ensemble from a file

Reads a saved `fb_ensemble` (or a `list(params, outputs, ...)`) from an
`.rds` file and returns a verified `fb_ensemble`. The file path's
provenance is recorded. (Delimited / `.fst` readers can be added as the
methods work needs them; `.rds` is the lossless round-trip used now.)

## Usage

``` r
read_fb_ensemble(path, ...)
```

## Arguments

- path:

  A single `.rds` file path.

- ...:

  Unused; for generic compatibility.

## Value

An `fb_ensemble`.
