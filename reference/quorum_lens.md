# A lens: a member's estimate of a shared estimand, with its declarations

A lens: a member's estimate of a shared estimand, with its declarations

## Usage

``` r
quorum_lens(
  name,
  member,
  fit,
  shares,
  expresses = "linear",
  kind = "parameters",
  scope = function(spec) TRUE
)

lens(...)
```

## Arguments

- name:

  Single string, unique within a quorum.

- member:

  Single string naming the package the estimate comes from.

- fit:

  A function `(spec, data, ...)` returning a
  [`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
  or a
  [`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md).

- shares:

  Named character vector over the components `sampler`, `objective`,
  `priors` and `data_prep`; two lenses that name the same value for a
  component share it, and the independence ledger counts it.

- expresses:

  Character subset of `linear`, `plateau`, `threshold`, `nonmonotone`:
  the response shapes the lens can express.

- kind:

  One of `"parameters"` or `"response_curve"`.

- scope:

  A function `(spec)` returning `TRUE` inside the lens's scope and a
  [`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
  outside it.

- ...:

  Passed to the `quorum_lens` constructor.

## Value

A `quorum_lens` S7 object.
