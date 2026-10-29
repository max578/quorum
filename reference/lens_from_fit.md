# Wrap a fitted hub or koine model as a lens

Turns a model somebody has already fitted into a lens the comparison can
read. The draws are taken once, at wrap time, and canonicalised: the
fit's native parameter names become the hub's canonical tokens –
`(Intercept)`, one per fixed-effect term, `sigma`, and `sd_<group>` for
each random-effect group – with the variance components on the
standard-deviation scale whatever the engine stored. That is what lets
an INLA lens, a brms lens and the koine lens be compared component by
component instead of by position.

## Usage

``` r
lens_from_fit(fit, name = NULL, n_samples = 1000L, expresses = "linear")
```

## Arguments

- fit:

  A fitted model: a `flexybayes_inla` fit, a `flexybayes_brms` fit, or
  the `flexybayes_koine` wrapper
  [`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
  returns.

- name:

  Single non-empty string naming the lens, or `NULL` (the default) to
  name it after the objective – `"inla"`, `"brms"` or `"koine"`.

- n_samples:

  Number of posterior draws to take. It reaches the engine's sampler on
  the INLA path, where the draws are generated on demand, and is ignored
  by backends that already carry every draw they kept.

- expresses:

  Character subset of `linear`, `plateau`, `threshold` and `nonmonotone`
  naming the response shapes this parameterisation can express. The
  default is `linear` because a fit's expressiveness is a property of
  the model formula, which this function does not read.

## Value

A
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
whose `fit()` returns the canonicalised draws, or a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
with reason `unsupported_fit` (no adapter for the class),
`lens_abstained` (koine stood down, with the nested reason attached),
`draws_unavailable` (the engine could not hand over draws) or
`draws_malformed` (the draws did not form a posterior).

## Details

The independence declaration is read off the fit's class rather than
asked for, because the caller holding a fitted object cannot be expected
to restate what the engine that produced it already determines. An INLA
fit declares the Laplace sampler and the INLA objective, a brms fit
declares Stan's NUTS sampler and the brms objective, and the koine
wrapper declares koine's stacked battery and koine's own objective; all
three declare the hub's formula interlingua and the hub's data
preparation, which they genuinely do share.

A class no adapter covers, an engine that cannot hand over its draws,
and a koine wrapper that already stood down all return a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
rather than a lens. None of the three is a programmer error: they are
facts about the fit, and a comparison that receives them can carry on
with the lenses it does have.

## See also

[`lens_koine()`](https://max578.github.io/quorum/reference/lens_koine.md)
to fit koine rather than wrap an existing fit,
[`lens_from_draws()`](https://max578.github.io/quorum/reference/lens_from_draws.md)
for draws that need no adapter at all.

## Examples

``` r
# An object no adapter covers is declined by name, never guessed at.
a <- lens_from_fit(structure(list(), class = "lm"))
is_quorum_abstention(a)
#> [1] TRUE
a$reason
#> [1] "unsupported_fit"
```
