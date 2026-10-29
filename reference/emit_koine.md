# Emit a koine fourth-opinion fit

Activates the koine lens-axis backend from the companion. Given a
flexyBayes `fb_terms` intermediate representation (the `$fb` element of
any core fit) and the model frame, `emit_koine()` synthesises koine's
fourth opinion and returns a `flexybayes_koine` object.
[`lens_from_fit()`](https://max578.github.io/quorum/reference/lens_from_fit.md)
turns it into a lens that
[`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md)
and [`quorum()`](https://max578.github.io/quorum/reference/quorum.md)
compare with an engine-axis fit (greta / INLA / brms / gretaR).

## Usage

``` r
emit_koine(
  fb,
  data,
  n_samples = 4000L,
  seed = 1L,
  the_call = NULL,
  standardise = TRUE,
  ...
)
```

## Arguments

- fb:

  An `fb_terms` object (the `$fb` element of a core flexyBayes fit).

- data:

  The model frame the fit was built on.

- n_samples:

  Integer count of opinion draws to synthesise.

- seed:

  Integer RNG seed, pinned for reproducibility regardless of caller RNG
  state.

- the_call:

  Optional originating call, carried into the fit's extras.

- standardise:

  Logical. koine's random-effects lenses carry a fixed N(0, 5) prior on
  every coefficient and lognormal(0, 2) priors on the residual and group
  SDs, which the pass-level prior does not reach. On a response measured
  in the hundreds that prior dominates the opinion: the intercept is
  pulled toward zero and the group SD absorbs the offset. With
  `standardise = TRUE` (the default) the Gaussian response is centred
  and scaled and every non-intercept covariate is scaled to unit SD
  before koine fits, and the draws are mapped back to the original scale
  afterwards, so the same prior becomes a scale-aware weakly-informative
  one; the fit declares `prior = "koine_scaled"` in its extras. With
  `FALSE` koine fits the data as given and declares `"koine_default"`.

- ...:

  Reserved for future use.

## Value

A `flexybayes_koine` object: a list with `status` (`"contributed"` or
`"abstained"`), the canonicalised `draws`, the koine `koine` result, the
`fb` IR, and an `extras` record (stacking weights, stacked ELPD,
independence and diagnostics on the contributed path; the refusal reason
and detail on the abstained path). On the abstained path the object's
class additionally carries `"quorum_abstention"` and
`"orchestra_refusal"` prepended ahead of `"flexybayes_koine"`, so a
producer-agnostic decline predicate (any class ending in `_refusal` /
`_abstention`, or the `orchestra_refusal` marker) recognises the outer
object without inspecting `$koine`; `inherits(x, "flexybayes_koine")`
and every `*.flexybayes_koine` method still dispatch unchanged.

## Details

koine's corner is a population GLM for the gaussian, binomial, and
poisson families, with either a single random intercept `(1 | g)` or –
from koine 0.3.0 – the breeder-standard multi-environment-trial
structure of two crossed or nested random intercepts,
`(1 | variety) + (1 | trial)`. A single grouping is routed through
`koine_pass_from_design(group = )`; two groupings are routed through
`koine_pass_from_design(groups = )`, koine's crossed / nested entry, and
whether they are crossed or nested is resolved by koine from the data.
Outside that corner – more than two groupings, a random slope, a
correlated random structure, koine below 0.3.0 on a two-grouping model –
or whenever koine's own convergence gate fires, the returned object
carries `status = "abstained"`, the typed fourth column. The synthesised
opinion is a stacking mixture over koine's battery, an independent
witness on the orthogonal lens axis, never a pool across the engine-axis
backends.

Activation is gated by
[`koine_status()`](https://max578.github.io/quorum/reference/koine_status.md):
koine installed at or above `0.2.0` and
`options(quorum.koine_activated = TRUE)` (the default). The draws are
canonicalised to flexyBayes's parameter tokens, so the fit is
self-naming and needs no `name_map` when it is compared: the group SDs
koine reports as `tau` / `tau_<grouping>` become `sd_<grouping>`.

## See also

[`koine_status()`](https://max578.github.io/quorum/reference/koine_status.md)
for the activation state;
[`lens_from_fit()`](https://max578.github.io/quorum/reference/lens_from_fit.md)
and
[`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md)
for comparing the result with another fit.
