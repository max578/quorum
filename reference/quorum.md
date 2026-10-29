# Compare a quorum of lenses and resolve them into one verdict

The front door. Each lens is gated on its own declared scope, then asked
to fit; a lens that declines either is recorded as having declined and
contributes no number. The lenses that returned draws are compared with
the agreement semantics, weighed by the independence ledger, and
resolved through the declared policy, and the whole comparison is
emitted as a manifest the rest of the orchestra can read.

## Usage

``` r
quorum(
  lenses,
  spec = NULL,
  data = NULL,
  policy,
  grid = NULL,
  decide = NULL,
  data_independence = NA
)
```

## Arguments

- lenses:

  A
  [`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md),
  a list of them, or their registered names.

- spec:

  The estimand specification each lens's `scope` and `fit` receive.

- data:

  The data each lens's `fit` receives.

- policy:

  A
  [`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md)
  declaring the fallback order and quorum.

- grid:

  The candidate grid a decision is taken over, or `NULL`.

- decide:

  An optional function `(draws, grid)` returning a list with `action`,
  `abstained`, `reason` and `grounding`, supplied by the caller – a
  decision layer's wrapper, for instance. Without one, a contributing
  lens is decisive and its action is `NA`: `quorum` compares lenses and
  never prices a decision itself.

- data_independence:

  Single logical: do the lenses read independent upstream data? `FALSE`
  blocks the manifest's grounded token, `NA` records that it was not
  declared.

## Value

A
[`quorum_verdict()`](https://max578.github.io/quorum/reference/quorum_verdict.md).

## Details

A disagreement between two lenses that cannot express the same response
shapes is recorded as a finding rather than counted as discordance: the
more expressive lens seeing a plateau the other cannot represent is
information about the pair, not evidence that either is wrong.

The status is `"no_quorum"` when fewer lenses contribute than the policy
requires, `"not_computed"` when there is nothing to compare or the
metric layer is unavailable, `"concordant"` when every counted pair
agrees, and `"discordant"` otherwise. A pair the metric layer could not
compare is not concordant, so it makes the status `"discordant"`; the
agreement matrix names it as inconclusive rather than as disagreement.

No quorum means no number. When fewer lenses contribute than the policy
requires, the resolution abstains whatever the contributing lenses said,
and the verdict carries the typed decline that says so.

## See also

[`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md),
[`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md),
[`quorum_manifest()`](https://max578.github.io/quorum/reference/quorum_manifest.md).

## Examples

``` r
fit_fn <- function(spec, data, ...) {
  quorum_draws(list(`(Intercept)` = stats::rnorm(200L)),
               source = "example")
}
one <- quorum_lens("one", "example", fit_fn,
                   c(sampler = "a", objective = "b", priors = "c",
                     data_prep = "d"))
two <- quorum_lens("two", "example", fit_fn,
                   c(sampler = "w", objective = "x", priors = "y",
                     data_prep = "z"))
quorum(list(one, two), policy = quorum_policy(c("one", "two")))
#> <quorum verdict> status: concordant
#>   lenses: 2 (2 contributing, 0 abstained)
#>   carried: one (decide) -> no number issued
#>   findings: 0
#>   independence: Agreement between lenses fitted to the same data is agreement, not corroboration of a shared data fact.
```
