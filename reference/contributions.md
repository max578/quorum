# Bind lens contributions into one table

Row-binds the rows produced by
[`lens_contribution()`](https://max578.github.io/quorum/reference/lens_contribution.md)
into the contributions table a resolution reads. Parts may carry extra
columns beyond the seven of the seam – a `cell` identifier when the
table spans many decision cells, or the per-cell facts a comparison
policy needs – and columns absent from one part are filled with `NA`
rather than dropped, so lenses that declare different extras still bind.

## Usage

``` r
contributions(...)
```

## Arguments

- ...:

  Data frames of contributions, each with at least the columns
  [`lens_contribution()`](https://max578.github.io/quorum/reference/lens_contribution.md)
  produces.

## Value

One data frame holding every row, with the union of the columns.

## See also

[`lens_contribution()`](https://max578.github.io/quorum/reference/lens_contribution.md),
[`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md).

## Examples

``` r
contributions(
  lens_contribution("mechanism", TRUE, FALSE, action = 120),
  lens_contribution("statistical", TRUE, TRUE, reason = "insufficient")
)
#>          lens grounded abstained action       reason grounding decisive
#> 1   mechanism     TRUE     FALSE    120         <NA>      <NA>     TRUE
#> 2 statistical     TRUE      TRUE     NA insufficient      <NA>    FALSE
```
