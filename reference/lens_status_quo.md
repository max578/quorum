# The status quo as a lens

A constant over the candidate grid: the rate a grower already applies,
the variety already sown, the decision the analysis is being asked to
improve on. It is the lens every comparison needs and no member emits,
and it is the fallback a resolution policy carries when no quorum forms.

## Usage

``` r
lens_status_quo(value, grid, name = "status_quo")
```

## Arguments

- value:

  Single finite number, the status-quo response held across the whole
  grid.

- grid:

  Non-empty numeric vector of candidate values – nitrogen rates, sowing
  dates, whatever the decision ranges over.

- name:

  Single non-empty string naming the lens.

## Value

A
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
of kind `response_curve` whose `fit()` returns a one-row
[`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
matrix of `value` over `grid`.

## Details

It declares `"none"` for all four independence components, so it shares
nothing with any lens that came from an engine and the ledger gives
every such pair the full evidential weight. It expresses no response
shape at all, which is the point: a constant cannot show a plateau or a
threshold, so the shape-finding rule must never read one into it.

## Examples

``` r
l <- lens_status_quo(value = 3.2, grid = c(0, 40, 80, 120))
d <- S7::prop(l, "fit")(NULL, NULL)
dim(S7::prop(d, "draws"))
#> [1] 1 4
```
