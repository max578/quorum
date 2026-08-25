
<!-- README.md is generated from README.Rmd. Edit the .Rmd, not the .md. -->

# flexyBayesOrchestra

`flexyBayesOrchestra` is the orchestra-composition layer for
[`flexyBayes`](https://github.com/max578/flexyBayes). The core
`flexyBayes` package is a self-contained Bayesian mixed-model engine
(ASReml / lme4 / brms grammar routed to greta, INLA, or brms, with
cross-engine triangulation). `flexyBayesOrchestra` adds the pieces that
only make sense inside the wider analytics constellation:

- **Surrogate emulators** — cheap stand-ins for expensive fits
  (`fit_surrogate()`, random-feature / Bayesian-linear emulators).
- **Ensemble sources** — ingest, verify, and represent external
  posterior ensembles (`fb_ensemble()`, `as_fb_ensemble()`,
  `verify_fb_ensemble()`).
- **Ensemble-derived priors** — turn an ensemble into a `flexyBayes`
  prior (`fb_prior_from_ensemble()`, `fb_pesto()`).
- **Surrogate posterior predictive checks** — MMD-based checks
  (`fb_surrogate_ppc()`, `fb_surrogate_ies()`).
- **koine fourth-opinion slot** — the synthesised orthogonal-lens
  opinion `flexyBayes::triangulate()` consumes, active by default on a
  compatible koine install (`koine_status()`).

If you only need Bayesian mixed models, install `flexyBayes` alone.
Install this package when you are composing `flexyBayes` with PESTO /
kernR / the rest of the orchestra.

## Installation

``` r
# installs flexyBayes (the core) and the orchestra optionals as needed;
# needs read access to the private max578/flexyBayes and max578/koine repos
pak::pak("max578/flexyBayesOrchestra")
```

## Minimal example

``` r
library(flexyBayesOrchestra)

# a small parameter -> output ensemble, as if from a simulator
theta <- cbind(p1 = runif(80, -2, 2), p2 = runif(80, -2, 2))
y <- theta %*% rbind(c(1.5, -0.8), c(0.4, 1.1)) + rnorm(160, 0, 0.1)
ens <- fb_ensemble(as.data.frame(theta), as.data.frame(y), provenance = list(source = "raw"))

# fit a distribution-preserving surrogate and read its predictive sd
sur <- fit_surrogate(ens)
predict(sur, data.frame(p1 = 1, p2 = -1))
```

## Relationship to flexyBayes

    flexyBayes            (core: mixed models + triangulation; CRAN / rOpenSci)
       ^
       | Imports
       |
    flexyBayesOrchestra   (this package: surrogates, ensembles, derived priors;
                           r-universe / orchestra-internal)

## License

GPL (\>= 3) — matching the `flexyBayes` core it imports.
