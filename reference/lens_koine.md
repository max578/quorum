# The koine fourth opinion as a lens

Declares koine's synthesised opinion as a lens without fitting anything
yet. The lens's `fit()` calls
[`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
on the specification and data it is handed and canonicalises the result.
The specification is the hub's `fb_terms` intermediate representation; a
fitted hub model is accepted in its place and the representation is
taken from it, because different hub fits carry it at `$fb` and at
`$extras$fb_terms` and a lens that read only one of the two would
decline half the hub's fits for a reason that has nothing to do with
koine. koine is already self-naming, so the canonicalisation is a
pass-through there; it is the same code path a hub fit takes, which is
what keeps the two lenses' parameter tokens identical by construction
rather than by coincidence.

## Usage

``` r
lens_koine(name = "koine", ...)
```

## Arguments

- name:

  Single non-empty string naming the lens.

- ...:

  Further arguments passed to
  [`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
  at fit time, such as `n_samples` (the count of opinion draws to
  synthesise) and `seed`.

## Value

A
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
of kind `parameters` whose `fit(spec, data)` returns a
[`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
over the canonical parameters, or a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
with reason `engine_missing` (koine is not installed), `spec_missing`
(the fitted model handed in carries no parsed model), `lens_abstained`
(koine stood down on this model, with the nested reason attached) or
`draws_unavailable`.

## Details

koine is the independent witness on the methodological axis: a stacked
battery of independent lenses synthesised into one opinion, not another
sampler over the hub's objective. Its corner is a population GLM with at
most two crossed or nested random intercepts, and outside that corner –
or whenever koine's own convergence gate fires – it stands down. The
lens re-types that as a `lens_abstained` decline carrying koine's own
reason, so an abstaining lens contributes no number to the quorum and
the reader still learns why.

## See also

[`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
for the opinion itself,
[`lens_from_fit()`](https://max578.github.io/quorum/reference/lens_from_fit.md)
to wrap a koine fit already in hand.

## Examples

``` r
l <- lens_koine()
S7::prop(l, "shares")
#>        sampler      objective         priors      data_prep 
#>  "koine_stack"        "koine" "koine_scaled"       "quorum" 
```
