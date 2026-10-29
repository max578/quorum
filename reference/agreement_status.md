# The overall status of an agreement table

Reduce a pairwise agreement table to one of the hub's three statuses. A
table with at least one discordant component is `"discordant"`; a table
whose compared components are all concordant is `"concordant"`; a table
in which nothing was compared – every row `not_compared`, or no rows at
all – is `"inconclusive"`.

## Usage

``` r
agreement_status(table, thresholds = agreement_thresholds())
```

## Arguments

- table:

  A data.frame from
  [`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md),
  or a
  [`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md),
  which is returned unchanged so a declined comparison propagates
  instead of being scored.

- thresholds:

  A list from
  [`agreement_thresholds()`](https://max578.github.io/quorum/reference/agreement_thresholds.md).
  The status rule reads verdicts only – the cut-offs were already
  applied, per component, when the table was built – and the argument is
  validated and carried so one thresholds object passes unchanged
  through every verb of this layer.

## Value

A single string, one of `"concordant"`, `"discordant"` or
`"inconclusive"`; or the abstention it was given.

## Details

This is the verdict-derived half of the hub's rule
(`.triangulate_status`, `flexyBayes` 0.10.0 `R/triangulate.R:910-927`).
The other half of that rule turns a failed comparability check or a
fit's own failed diagnostics into `"inconclusive"` before the verdicts
are read at all. Those two gates take a model fingerprint and a
sampler's diagnostics, which a lens does not carry, so in quorum they
sit with the lens contract and the policy rather than here: a caller
that has gate findings of its own reports `"inconclusive"` without
consulting this function.

## See also

[`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md).

## Examples

``` r
tbl <- data.frame(
  param = c("a", "b"),
  verdict = c("concordant", "discordant"),
  stringsAsFactors = FALSE
)
agreement_status(tbl)
#> [1] "discordant"
```
