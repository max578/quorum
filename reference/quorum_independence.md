# The independence ledger over a set of lenses

Counts what every pair of lenses shares and converts it into the
evidential weight the quorum rule reads. Two lenses declare four
components – `sampler`, `objective`, `priors` and `data_prep` – and the
weight for a pair is `1 - shared / 4`, so a pair sharing nothing carries
full weight, a pair sharing all four carries none, and a pair sharing
one component carries three quarters.

## Usage

``` r
quorum_independence(lenses, data_independence = NA)
```

## Arguments

- lenses:

  A list of
  [`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
  objects. An empty list is allowed and yields empty matrices; anything
  in the list that is not a lens is a programmer error.

- data_independence:

  Single logical. `TRUE` when the lenses were fitted to
  independently-collected data, `FALSE` when they share one dataset, and
  `NA` (the default) when the caller has not established which. Anything
  other than `TRUE` attaches the caveat.

## Value

A list of class `quorum_independence` with `components` (the four
component names), `shared` (an integer matrix of the number of
components each pair holds in common, `NA` on the diagonal), `weight`
(the numeric matrix `1 - shared / 4`, `NA` on the diagonal, rows and
columns named for the lenses), `data_independence` as supplied, and
`caveat` (the sentence to carry alongside the weights, or `""`).

## Details

The declarations are the lenses' own. The ledger does not inspect an
engine to discover what it shares with another, because the point of the
declaration is that a member states its own dependencies where a reader
can see and dispute them.

Data independence is a separate question the declarations cannot answer,
so the caller supplies it. Left at `NA` – or set to `FALSE` – the result
carries a caveat saying what agreement between lenses on one dataset
does and does not establish. The caveat is empty only when the caller
has positively established that the lenses saw independently-collected
data.

## See also

[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
for the declarations the ledger reads.

## Examples

``` r
d <- quorum_draws(list(beta = rnorm(20L)))
mk <- function(nm, shares) {
  lens_from_draws(d, name = nm, member = "quorum", shares = shares)
}
a <- mk("a", c(sampler = "nuts", objective = "brms", priors = "hub",
               data_prep = "hub"))
b <- mk("b", c(sampler = "ies", objective = "simulator",
               priors = "ensemble", data_prep = "pesto"))
quorum_independence(list(a, b))
#> <quorum independence ledger>
#>   components: sampler, objective, priors, data_prep
#>   evidential weight (1 = shares nothing, 0 = shares everything)
#>    a  b
#> a NA  1
#> b  1 NA
#>   data independence: NA
#>   Agreement between lenses fitted to the same data is agreement, not corroboration of a shared data fact.
```
