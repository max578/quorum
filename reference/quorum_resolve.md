# Resolve a comparison into one carried answer

Walks the policy's declared order and carries the first lens that is
present, grounded and decisive for that cell. When no lens is, but at
least one is present and grounded and simply would not stand behind a
number, the policy's `status_quo` is carried and the cell is recorded as
having defaulted. When nothing grounded remains, the cell abstains and
carries no number at all.

## Usage

``` r
quorum_resolve(contrib, policy)
```

## Arguments

- contrib:

  A contributions data frame from
  [`contributions()`](https://max578.github.io/quorum/reference/contributions.md).
  A `cell` column makes the resolution per cell; without one the whole
  table is treated as a single cell.

- policy:

  A
  [`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md)
  or a
  [`policy_committed()`](https://max578.github.io/quorum/reference/quorum_policy_committed.md).

## Value

A data frame with one row per cell: `cell` (when the input had one), a
`tier_<lens>` logical for each lens in the policy's order,
`tier_status_quo`, `tier_abstain`, `carried_lens`, `verdict`
(`"decide"`, `"default"` or `"abstain"`) and `action`.

## Details

The three outcomes are deliberately distinct. A defaulting cell has a
grounded lens that declined; an abstaining cell has none, and the
difference is the whole reason an abstention is not simply resolved to a
fixed rate. A lens that abstained never contributes its number to
either.

Handed a
[`policy_committed()`](https://max578.github.io/quorum/reference/quorum_policy_committed.md),
the function applies that convention instead of the cascade and returns
the same columns, so the two are comparable cell by cell.

Only lenses named in `policy@order` take part: a contribution from a
lens the policy did not declare is carried in the table but not in the
resolution.

## See also

[`contributions()`](https://max578.github.io/quorum/reference/contributions.md),
[`quorum_compare_policies()`](https://max578.github.io/quorum/reference/quorum_compare_policies.md),
[`quorum()`](https://max578.github.io/quorum/reference/quorum.md).

## Examples

``` r
contrib <- contributions(
  lens_contribution("mechanism", grounded = TRUE, abstained = TRUE),
  lens_contribution("statistical", grounded = TRUE, abstained = FALSE,
                    action = 30)
)
quorum_resolve(contrib, quorum_policy(c("mechanism", "statistical"),
                                      status_quo = 60))
#>   tier_mechanism tier_statistical tier_status_quo tier_abstain carried_lens
#> 1          FALSE             TRUE           FALSE        FALSE  statistical
#>   verdict action
#> 1  decide     30
```
