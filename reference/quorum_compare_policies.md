# Price several fallback conventions in one table

Resolves the same contributions under every policy handed in and returns
one table carrying each policy's verdict and action side by side, so the
cost of a fallback convention is read off a column rather than argued.

## Usage

``` r
quorum_compare_policies(contrib, policies)
```

## Arguments

- contrib:

  A contributions data frame from
  [`contributions()`](https://max578.github.io/quorum/reference/contributions.md).

- policies:

  A named list of
  [`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md)
  and
  [`policy_committed()`](https://max578.github.io/quorum/reference/quorum_policy_committed.md)
  objects. The names become the column suffixes.

## Value

A data frame with one row per cell: `cell` (when the input had one),
then `verdict_<name>` and `action_<name>` for each policy.

## See also

[`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md).

## Examples

``` r
contrib <- contributions(
  lens_contribution(
    "mechanism", grounded = FALSE, abstained = TRUE,
    reason = "input_ungrounded",
    grounding = orchestraManifest::GROUNDING_UNVERIFIED
  ),
  lens_contribution("statistical", grounded = TRUE, abstained = FALSE,
                    action = 30)
)
quorum_compare_policies(contrib, list(
  cascade = quorum_policy(c("mechanism", "statistical"), status_quo = 60),
  committed = policy_committed("zero", status_quo = 60, safe_action = 0)
))
#>   verdict_cascade action_cascade verdict_committed action_committed
#> 1          decide             30           abstain                0
```
