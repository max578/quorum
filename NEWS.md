# flexyBayesOrchestra (development version)

* **`%||%` defined locally (FBO-03).** The infix was used nine times across
  `R/` but defined nowhere in the package and imported from nowhere, so it
  resolved only via `base::%||%` -- absent below R 4.4.0, against a declared
  floor of R (>= 4.1.0). Added a package-local `%||%` in `R/utils.R`.
* **Aggregated multi-kernel MMD PPC re-calibrated (FBO-07).** `.mmd_agg()`'s
  per-permutation p-values (`pj`) ranked each permutation replicate against
  its own bandwidth's null including itself, while the observed statistic's
  p-value (`p_obs`) was ranked against the same null excluding it -- an
  asymmetric comparison that miscalibrates the aggregated test's level.
  Both are now ranked against the pooled set of the observed statistic and
  its B permutation replicates together, per bandwidth.

# flexyBayesOrchestra 0.0.0.9000

* **koine genomic fourth opinion (`koine_genomic_lens()`).** The koine
  fourth opinion, specialised for genomics: it runs the established REML
  genomic BLUP (via \pkg{sommer}) on the same data and emits a genomic
  *lens* that `flexyBayes::triangulate_genomic()` (>= 0.8.0) consumes as a
  fourth column. In genomics the orchestra's value is not replacing the
  decades of established REML / field-standard tools but catching
  divergence -- "our Bayesian GEBVs disagree with sommer's REML --
  investigate." The lens contract keeps flexyBayes core lean: core never
  depends on the field tools; the companion produces the lens and core
  compares it. `sommer` is a Suggests-only oracle (never on a fit path).
  GEMMA / rrBLUP (GWAS) and BGLR (Bayesian marker) lenses are the same
  pattern, planned.
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
