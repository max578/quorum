
<!-- README.md is generated from README.Rmd. Edit the .Rmd, not the .md. -->

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

## Installation

`quorum` is not on CRAN. Install the local build from a clone of the
package tree:

``` r
# from the top of the cloned package tree
devtools::install_local(".")
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
| Consensus | `quorum()`, `quorum_policy()`, `policy_committed()`, `lens_contribution()`, `contributions()`, `quorum_resolve()`, `quorum_compare_policies()`, `quorum_manifest()` |
| Lenses | `lens()`, `lens_from_draws()`, `lens_from_fit()`, `lens_koine()`, `lens_status_quo()`, `lens_mechanism()`, `lens_tmb()`, `register_lens()` / `get_lens()` / `list_lenses()` / `clear_lenses()`, `quorum_independence()` |
| Metrics | `agreement_thresholds()`, `agreement_pairwise()`, `agreement_status()`, `agreement_matrix()` |
| On-ramps (C5 / C7) | `fb_ensemble()`, `as_fb_ensemble()`, `verify_fb_ensemble()`, `fit_surrogate()`, `fb_surrogate_ies()`, `fb_surrogate_ppc()`, `register_surrogate()` |
| koine backend | `emit_koine()`, `koine_status()`, `koine_genomic_lens()` |

## Learn more

`vignette("quorum-on-study-a0")` walks a quorum of lenses across Study
A0’s 200 decision cells on the shipped fixture;
`vignette("adding-a-lens")` builds a lens from the contract up, worked
through a TMB adapter.
