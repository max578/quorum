# A resolution policy

Declares how a comparison is resolved into one carried answer: the
fallback priority of the lenses, how many must contribute before a
verdict is issued, the agreement thresholds to compare them with, the
evidential weight below which a pair is not counted, and what a cell
falls back to when no lens stands behind a number.

## Usage

``` r
quorum_policy(
  order,
  min_lenses = 2L,
  thresholds = NULL,
  independence_min = 0,
  status_quo = NULL,
  safe_action = NULL
)
```

## Arguments

- order:

  Character vector of lens names in fallback priority: the first name
  that is present, grounded and decisive is the one carried.

- min_lenses:

  Single whole number: how many lenses must contribute before a
  comparison is a quorum at all.

- thresholds:

  A list of agreement thresholds, or `NULL` to read
  [`agreement_thresholds()`](https://max578.github.io/quorum/reference/agreement_thresholds.md)
  at the point of use.

- independence_min:

  Single number: the evidential weight at or above which a pair counts
  towards concordance.

- status_quo:

  A single number to fall back on, or `NULL` to abstain instead of
  defaulting.

- safe_action:

  The action a single lens falls back to inside its own decision. It is
  carried for the caller and is what `policy_committed(fixed = "zero")`
  resolves an abstention to; the cascade never mints a rate from it.

## Value

A `quorum_policy` S7 object.

## Details

`status_quo` is the whole of the difference between a cell that defaults
and a cell that abstains. Left `NULL`, a resolution with no decisive
lens abstains and issues no number at all; set to a value, that value is
carried and the cell is marked as having defaulted rather than decided.

`thresholds` left `NULL` means the agreement thresholds in force at the
time of use, read from
[`agreement_thresholds()`](https://max578.github.io/quorum/reference/agreement_thresholds.md)
when the metric layer is present, so a policy written today does not pin
yesterday's cut-offs.

## See also

[`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md),
[`policy_committed()`](https://max578.github.io/quorum/reference/quorum_policy_committed.md).

## Examples

``` r
quorum_policy(order = c("mechanism", "statistical"), status_quo = 60)
#> <quorum::quorum_policy>
#>  @ order           : chr [1:2] "mechanism" "statistical"
#>  @ min_lenses      : int 2
#>  @ thresholds      : NULL
#>  @ independence_min: num 0
#>  @ status_quo      : num 60
#>  @ safe_action     : NULL
```
