# The TMB lens: a second Laplace implementation, sampled with NUTS

Registers glmmTMB's Laplace-approximated marginal likelihood as a lens,
and samples the very TMB objective that fit produced with `tmbstan`'s
NUTS. The lens therefore contributes two things the hub's own engines do
not: a Laplace implementation written independently of INLA's, and one
objective sampled two ways, so a disagreement between the Laplace point
and the Hamiltonian posterior is attributable to the approximation
rather than to a difference of model.

## Usage

``` r
lens_tmb(
  family = "gaussian",
  laplace = TRUE,
  n_draws = 2000L,
  chains = 2L,
  iter = NULL,
  warmup = NULL,
  seed = 1L,
  priors = c("hub", "flat"),
  name = NULL
)
```

## Arguments

- family:

  One of `"gaussian"`, `"poisson"`, `"binomial"` or `"nbinom2"`, used
  when the spec is a formula. Any other family returns a
  `family_unsupported` abstention at fit time.

- laplace:

  Logical: when `TRUE` (the default) the random effects stay integrated
  out by the Laplace approximation and NUTS samples the remaining
  parameters; when `FALSE` NUTS samples the joint vector.

- n_draws:

  Target number of post-warmup draws in total across chains; sets the
  default `iter` when `iter` is `NULL`.

- chains:

  Number of NUTS chains.

- iter:

  Iterations per chain, warmup included. `NULL` derives it from
  `n_draws` and `chains` with a half-warmup split.

- warmup:

  Warmup iterations per chain. `NULL` uses half of `iter`.

- seed:

  Integer RNG seed passed to the sampler.

- priors:

  `"hub"` to match the hub's default priors as far as glmmTMB's prior
  syntax allows, or `"flat"` to fit under glmmTMB's own defaults. See
  the Priors section.

- name:

  Lens name; defaults to `"tmb"`.

## Value

A
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
with member `"glmmTMB"` and kind `"parameters"`. Its
`fit(spec, data, ...)` returns a
[`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
whose components are named with the hub's canonical parameters –
`"(Intercept)"`, the model-matrix column names, and `sd_<grouping>` –
and whose `diagnostics` carry `laplace_point` (the glmmTMB point
estimates on those same names), `rhat` (the worst-case R-hat),
`n_divergent`, the `laplace` flag, and the prior plan actually used.
Further arguments in `...` reach
[`tmbstan::tmbstan()`](https://rdrr.io/pkg/tmbstan/man/tmbstan.html).
Where glmmTMB or tmbstan is not installed, the model is outside the
lens's shape, or the family is unsupported, `fit()` returns a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
and never a number.

## Details

The `fit` function accepts the model either as an lme4-style formula or
as the hub's `fb_terms` intermediate representation, from which the
formula is rebuilt the way
[`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
rebuilds it. The lens fields a plain random intercept on one grouping
variable; a random slope, a correlated structure, a nested or
interaction grouping, or a second grouping term returns an
`out_of_scope` abstention. When the spec is an `fb_terms` object its own
family and link are authoritative, so a hub fit and this lens are never
compared across two different likelihoods; a formula spec takes the
`family` argument instead.

## Priors

The hub's default is `uniform(0, U)` on every standard deviation, with
`U = 5 * sd(y)` on an identity link, `3` on a log link and `5` on a
logit link. glmmTMB parameterises the random-effect SD by its logarithm,
so fitting with no prior at all is flat on `log(SD)` and thus
proportional to `1/SD` on the SD scale, which is not integrable at zero:
for a weakly identified variance component the posterior is improper and
the sampler does not settle. With `priors = "hub"` (the default) the
lens writes a shape-2 gamma prior on the random-intercept SD. glmmTMB
adds a gamma row to the negative log density as
`-log dgamma(exp(theta), shape, scale)` with no Jacobian term, so the
implied density on the SD scale is proportional to `SD^(shape - 2)`, and
shape 2 is flat; the scale is set far above the hub's bound so it stays
flat across the whole interval the hub's uniform prior covers. Two parts
of the hub's default have no counterpart in glmmTMB's prior syntax – the
hard upper bound itself, and the uniform prior on the residual SD, since
the dispersion parameter admits only log-scale families – and both are
named in the fitted object's `diagnostics$priors$unmatched` rather than
assumed away. `shares["priors"]` reads `"hub_matched"` when every hub
prior on a component the lens reports (the fixed effects, which the hub
leaves to the engine by default, and the random-intercept SD) was
carried. With `priors = "flat"` the fit runs under glmmTMB's own
defaults and the lens declares `"flat"`.

## See also

[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
for the contract,
[`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
for the formula construction and the canonical naming this lens follows.

## Examples

``` r
lens <- lens_tmb()
lens@shares
#>       sampler     objective        priors     data_prep 
#>   "stan_nuts"         "tmb" "hub_matched"      "quorum" 
# Outside the lens's shape, the scope gate declines rather than fits.
is_quorum_abstention(lens@scope(y ~ x + (1 + x | g)))
#> [1] TRUE
```
