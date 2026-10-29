# Print a quorum verdict

Shows the status, how many lenses contributed and how many declined, the
lens whose answer is carried and the number it carries, the count of
shape findings, the independence caveat when there is one, and the typed
decline when the verdict carries no number.

## Usage

``` r
# S3 method for class '`quorum::quorum_verdict`'
print(x, ...)
```

## Arguments

- x:

  A
  [`quorum_verdict()`](https://max578.github.io/quorum/reference/quorum_verdict.md).

- ...:

  Unused.

## Value

`x`, invisibly.

## Details

The method is registered against the package-qualified `S7` class name,
which is what `S7` puts in the class vector.
