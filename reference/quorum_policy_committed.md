# The committed convention the cascade replaced

Builds the policy Study A0 committed to before the cascade: one decision
lens decides, a declared disagreement between the lenses demotes the
cell to the status quo, a decision declined for insufficient evidence
does the same, and an ungrounded input or an abstaining producer
resolves to a fixed rate. It is kept as an object rather than as prose
so that
[`quorum_compare_policies()`](https://max578.github.io/quorum/reference/quorum_compare_policies.md)
can price it against the cascade in one table.

## Usage

``` r
quorum_policy_committed(
  fixed = c("zero", "status_quo"),
  lens = "mechanism",
  status_quo = NULL,
  safe_action = NULL
)

policy_committed(...)
```

## Arguments

- fixed:

  Which fixed rate an abstention resolves to: `"zero"` for
  `safe_action`, `"status_quo"` for `status_quo`.

- lens:

  Single string naming the deciding lens whose contribution rows the
  convention reads.

- status_quo:

  A single number: the rate a demoted cell holds, or `NULL` to leave it
  unstated (the action is then `NA`).

- safe_action:

  A single number: the no-input floor, or `NULL`.

- ...:

  Passed to the `quorum_policy_committed` constructor.

## Value

A `quorum_policy_committed` S7 object, which is a
[`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md)
carrying the two extra declarations.

## Details

The convention's defining property is that an abstention still mints a
number. `fixed = "zero"` resolves it to `safe_action`, the no-input
floor; `fixed = "status_quo"` resolves it to `status_quo`. Withholding a
rate is not among its outcomes, which is precisely what the cascade
changed.

## See also

[`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md),
[`quorum_compare_policies()`](https://max578.github.io/quorum/reference/quorum_compare_policies.md).

## Examples

``` r
policy_committed("zero", lens = "mechanism", status_quo = 60,
                 safe_action = 0)
#> <quorum::quorum_policy_committed>
#>  @ order           : chr "mechanism"
#>  @ min_lenses      : int 1
#>  @ thresholds      : NULL
#>  @ independence_min: num 0
#>  @ status_quo      : num 60
#>  @ safe_action     : num 0
#>  @ fixed           : chr "zero"
#>  @ decision_lens   : chr "mechanism"
```
