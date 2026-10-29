# One lens's contribution to a resolution

Builds the single row a lens adds to a contributions table: which lens
it is, whether its estimate is grounded, whether it declined, the action
it stands behind, and the reason and grounding token it declared. The
row is the whole of what
[`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md)
reads, so a lens that has abstained cannot smuggle a number into a
resolution.

## Usage

``` r
lens_contribution(
  lens,
  grounded,
  abstained,
  action = NA_real_,
  reason = NA_character_,
  grounding = NA_character_,
  decisive = !abstained
)
```

## Arguments

- lens:

  Single string naming the lens.

- grounded:

  Single logical: is the lens's estimate grounded?

- abstained:

  Single logical: did the lens decline to stand behind a number?

- action:

  The action the lens stands behind, as a single number, or `NA_real_`
  when it offers none.

- reason:

  Single string naming why the lens declined, or `NA_character_`.

- grounding:

  The grounding token the lens declared, conventionally one of
  [`orchestraManifest::GROUNDING_GROUNDED`](https://rdrr.io/pkg/orchestraManifest/man/GROUNDING_GROUNDED.html)
  or its unverified complement, or `NA_character_`.

- decisive:

  Single logical: is this lens's answer usable as the carried answer?
  Defaults to `!abstained`.

## Value

A one-row data frame with the seven columns named above.

## Details

`decisive` defaults to the complement of `abstained` and is separate
from it because the two can come apart: a lens may fit, decline to
abstain, and still have no action to offer, and a caller that knows this
records `decisive = FALSE` rather than overloading the abstention flag.

## See also

[`contributions()`](https://max578.github.io/quorum/reference/contributions.md)
to bind rows into a table,
[`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md)
to resolve one.

## Examples

``` r
lens_contribution("mechanism", grounded = TRUE, abstained = FALSE,
                  action = 120, grounding = "grounded")
#>        lens grounded abstained action reason grounding decisive
#> 1 mechanism     TRUE     FALSE    120   <NA>  grounded     TRUE
```
