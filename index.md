# quorum

`quorum` is the Crop Analytics Orchestra’s consensus layer. It never
fits a model of its own: every estimate reaches it as a *lens* – a
member’s fitter behind an adapter that declares what it shares with the
other lenses (sampler, objective, priors, data preparation), the
response shapes it can express, and its scope. A quorum of lenses that
are independent enough of one another, and that agree, is what carries
an answer; short of a quorum, `quorum` abstains rather than guessing.
The three on-ramps by which a non-hub estimate becomes a lens stay in
the package: simulation-ensemble ingestion, a distribution-preserving
surrogate for an expensive simulator, and the koine fourth-opinion
backend.

> **Rule in one line.** A quorum of independent lenses must agree before
> an answer is carried; no quorum means abstain.

## Related packages

- [MuMIn](https://CRAN.R-project.org/package=MuMIn) selects and averages
  models, weighting their parameters and predictions by information
  criteria or custom weights.
- [loo](https://CRAN.R-project.org/package=loo) compares Bayesian models
  by approximate leave-one-out cross-validation and can average their
  predictive distributions by stacking.
- [metafor](https://CRAN.R-project.org/package=metafor) pools effect
  sizes from several studies with fixed-, random- and mixed-effects
  meta-analysis models.

These combine estimates into one weighted answer. quorum instead asks
whether enough independent estimates of the same quantity agree, after
declaring what each one shares with the others, and abstains when they
do not.

## Installation

`quorum` is not on CRAN. Install the development version from GitHub:

``` r

remotes::install_github("max578/quorum")
```

## Minimal example

Two lenses, built from draws already in hand, compared and resolved
through a declared policy:

``` r

library(quorum)

set.seed(1)
draws_a <- quorum_draws(list(`(Intercept)` = rnorm(500, 10, 1)),
                        source = "engine_a")
draws_b <- quorum_draws(list(`(Intercept)` = rnorm(500, 10.05, 1.02)),
                        source = "engine_b")

a <- lens_from_draws(draws_a, name = "a", member = "engine_a",
                     shares = c(sampler = "nuts", objective = "stan_a",
                               priors = "hub", data_prep = "hub"))
b <- lens_from_draws(draws_b, name = "b", member = "engine_b",
                     shares = c(sampler = "laplace", objective = "tmb",
                               priors = "hub", data_prep = "hub"))

verdict <- quorum(list(a, b),
                  policy = quorum_policy(order = c("a", "b"), min_lenses = 2L))
print(verdict)
#> <quorum verdict> status: concordant
#>   lenses: 2 (2 contributing, 0 abstained)
#>   carried: a (decide) -> no number issued
#>   findings: 0
#>   independence: Agreement between lenses fitted to the same data is agreement, not corroboration of a shared data fact.
```

## What lives here

| Group | Verbs |
|----|----|
| Consensus | [`quorum()`](https://max578.github.io/quorum/reference/quorum.md), [`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md), [`policy_committed()`](https://max578.github.io/quorum/reference/quorum_policy_committed.md), [`lens_contribution()`](https://max578.github.io/quorum/reference/lens_contribution.md), [`contributions()`](https://max578.github.io/quorum/reference/contributions.md), [`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md), [`quorum_compare_policies()`](https://max578.github.io/quorum/reference/quorum_compare_policies.md), [`quorum_manifest()`](https://max578.github.io/quorum/reference/quorum_manifest.md) |
| Lenses | [`lens()`](https://max578.github.io/quorum/reference/quorum_lens.md), [`lens_from_draws()`](https://max578.github.io/quorum/reference/lens_from_draws.md), [`lens_from_fit()`](https://max578.github.io/quorum/reference/lens_from_fit.md), [`lens_koine()`](https://max578.github.io/quorum/reference/lens_koine.md), [`lens_status_quo()`](https://max578.github.io/quorum/reference/lens_status_quo.md), [`lens_mechanism()`](https://max578.github.io/quorum/reference/lens_mechanism.md), [`lens_tmb()`](https://max578.github.io/quorum/reference/lens_tmb.md), [`register_lens()`](https://max578.github.io/quorum/reference/register_lens.md) / [`get_lens()`](https://max578.github.io/quorum/reference/register_lens.md) / [`list_lenses()`](https://max578.github.io/quorum/reference/register_lens.md) / [`clear_lenses()`](https://max578.github.io/quorum/reference/register_lens.md), [`quorum_independence()`](https://max578.github.io/quorum/reference/quorum_independence.md) |
| Metrics | [`agreement_thresholds()`](https://max578.github.io/quorum/reference/agreement_thresholds.md), [`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md), [`agreement_status()`](https://max578.github.io/quorum/reference/agreement_status.md), [`agreement_matrix()`](https://max578.github.io/quorum/reference/agreement_matrix.md) |
| On-ramps (C5 / C7) | [`fb_ensemble()`](https://max578.github.io/quorum/reference/fb_ensemble.md), [`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md), [`verify_fb_ensemble()`](https://max578.github.io/quorum/reference/verify_fb_ensemble.md), [`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md), [`fb_surrogate_ies()`](https://max578.github.io/quorum/reference/fb_surrogate_ies.md), [`fb_surrogate_ppc()`](https://max578.github.io/quorum/reference/fb_surrogate_ppc.md), [`register_surrogate()`](https://max578.github.io/quorum/reference/register_surrogate.md) |
| koine backend | [`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md), [`koine_status()`](https://max578.github.io/quorum/reference/koine_status.md), [`koine_genomic_lens()`](https://max578.github.io/quorum/reference/koine_genomic_lens.md) |

## Learn more

[`vignette("quorum-on-study-a0")`](https://max578.github.io/quorum/articles/quorum-on-study-a0.md)
walks a quorum of lenses across Study A0’s 200 decision cells on the
shipped fixture;
[`vignette("adding-a-lens")`](https://max578.github.io/quorum/articles/adding-a-lens.md)
builds a lens from the contract up, worked through a TMB adapter.

## Contributing

Bug reports and suggestions are welcome through the [issue
tracker](https://github.com/max578/quorum/issues). See `CONTRIBUTING.md`
for how to propose a change.

## Citation

``` r

citation("quorum")
```

## Licence

MIT + file LICENSE. See
[LICENSE](https://max578.github.io/quorum/LICENSE).
