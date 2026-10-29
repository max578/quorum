# Pairwise agreement across a quorum of lenses

Run
[`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md)
over every unordered pair of a quorum's lenses and collect the results:
a square matrix of pairwise statuses, and the long table of every
component comparison behind it.

## Usage

``` r
agreement_matrix(draws, thresholds = agreement_thresholds())
```

## Arguments

- draws:

  A named list of
  [`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
  objects of kind `"parameters"`, or of named lists of numeric vectors,
  one per lens. Names are the lens names and label the matrix and the
  table.

- thresholds:

  A list from
  [`agreement_thresholds()`](https://max578.github.io/quorum/reference/agreement_thresholds.md).

## Value

A list of class `quorum_agreement` with elements `status` (an `N` by `N`
character matrix of pairwise statuses, diagonal `NA`), `table` (the long
data.frame: `lens_a`, `lens_b`, then the columns of
[`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md))
and `thresholds` (the cut-offs used); or a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
of scope `"comparison"` when fewer than two lenses were given.

## Details

A pair that shares no component is not a disagreement. Its status is
`"inconclusive"` and it enters the long table as a single row whose
reason is `no_common_parameters`, so the matrix and the table always
tell the same story and no pair goes missing from either.

The matrix is symmetric and its diagonal is `NA`: a lens is not compared
with itself, and a diagonal of `"concordant"` would inflate any count
taken over the matrix.

## See also

[`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md),
[`agreement_status()`](https://max578.github.io/quorum/reference/agreement_status.md).

## Examples

``` r
set.seed(2)
lenses <- list(
  inla = list(mu = rnorm(400L)),
  brms = list(mu = rnorm(400L)),
  koine = list(mu = rnorm(400L, 3))
)
agreement_matrix(lenses)$status
#>       inla         brms         koine       
#> inla  NA           "concordant" "discordant"
#> brms  "concordant" NA           "discordant"
#> koine "discordant" "discordant" NA          
```
