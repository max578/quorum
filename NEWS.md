# flexyBayesOrchestra 0.0.0.9000

* **koine fourth-opinion backend activated (2026-06-08).** `emit_koine()` ports
  koine's real opinion synthesis (`koine::koine_pass_from_design()` ->
  `koine::synthesise()` -> `koine::koine_opinion_draws()`) and returns a
  self-naming `flexybayes_koine` fit. S3 methods registered on flexyBayes
  core's exported `fb_as_draws_simple()` and `canonical_names()` generics let
  core's generic `triangulate()` consume the koine fit as its fourth column
  with **no flexyBayes core edit** (the lean-0.7.0 boundary holds). koine fields
  a population GLM + a single random intercept `(1 | g)` for gaussian /
  binomial / poisson; it abstains honestly out of corner. The slot
  (`koine_status()`) is now live: activation floor `koine (>= 0.2.0)`, gated by
  `options(flexyBayesOrchestra.koine_activated = TRUE)` (the default). koine
  moved to `Suggests`; `posterior` added to `Suggests`.
* Initial development version. flexyBayesOrchestra is the orchestra-composition
  companion to flexyBayes, created by the flexyBayes lean-core split: it carries
  the surrogate emulators (`fit_surrogate()`, `fb_surrogate_ies()`,
  `fb_surrogate_ppc()`), ensemble sources (`fb_ensemble()`, `as_fb_ensemble()`,
  `read_fb_ensemble()`, `verify_fb_ensemble()`, `register_ensemble_source()`),
  the PESTO ensemble-derived priors (`fb_pesto()`, `fb_prior_from_ensemble()`),
  and the dormant koine fourth-opinion slot (`koine_status()`) that previously
  lived in flexyBayes core.
* `.onLoad()` registers the PESTO / kernR surrogate conformers when those member
  packages are installed, so `fit_surrogate(method = "gp" / "cme")` is
  discoverable -- restoring the behaviour that lived in flexyBayes before the
  split.
