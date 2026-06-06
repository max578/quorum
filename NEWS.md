# flexyBayesOrchestra 0.0.0.9000

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
