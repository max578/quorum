# Wrap draws a member has already produced as a lens

The shortest path from a posterior to a lens. When a member has already
produced its draws – a saved posterior, an ensemble read from disk, a
constant a practitioner is defending – there is nothing left to fit, so
the lens's `fit()` ignores the specification and the data and hands back
the draws it was built from. Every built-in lens whose estimate is
settled at construction time is built this way.

## Usage

``` r
lens_from_draws(
  draws,
  name,
  member,
  shares,
  expresses = "linear",
  scope = function(spec) TRUE
)
```

## Arguments

- draws:

  A
  [`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
  object the lens returns unchanged.

- name:

  Single non-empty string, unique within a quorum.

- member:

  Single non-empty string naming the package the estimate comes from.

- shares:

  Named character vector over `sampler`, `objective`, `priors` and
  `data_prep`, the four components the independence ledger counts.

- expresses:

  Character subset of `linear`, `plateau`, `threshold` and
  `nonmonotone`; `character(0)` for a lens that expresses no shape at
  all, such as a constant.

- scope:

  A function `(spec)` returning `TRUE` inside the lens's scope and a
  [`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
  outside it. The default accepts everything, which is right for draws
  that are already in hand.

## Value

A
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
whose `fit()` returns `draws`.

## Details

The `kind` is taken from the draws rather than declared again, because a
lens that disagreed with its own draws about whether they are parameters
or a response curve would be caught only at the comparison.

## Examples

``` r
d <- quorum_draws(list(beta = rnorm(100L)), source = "saved")
l <- lens_from_draws(
  d, name = "saved", member = "quorum",
  shares = c(sampler = "none", objective = "saved", priors = "none",
             data_prep = "none")
)
identical(S7::prop(l, "fit")(NULL, NULL), d)
#> [1] TRUE
```
