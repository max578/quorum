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
* **Contract ownership corrected in the shipped documentation (FBO-04).**
  `inst/surrogate_contract.md`, `inst/ensemble_source_contract.md`, both
  vignettes, and the roxygen for `fit_surrogate()`, `predict.fb_surrogate()`,
  `register_surrogate()`, `fb_ensemble()`, `as_fb_ensemble()`,
  `register_ensemble_source()`, and `fb_pesto()` attributed contracts C5
  (`fb_ensemble`) and C7 (`fb_surrogate`) to `flexyBayes`; `flexyBayes` 0.9.2
  exports neither verb. Ownership is now attributed to
  `flexyBayesOrchestra` throughout, which is where both contracts are
  actually implemented; a reader following the shipped contract no longer
  calls a function that does not exist.
* **`getting-started` vignette replaced (FBO-08).** The shipped vignette was
  a self-declared build-clean stub (`library()` and nothing else). It now
  walks the three composition seams (ingest an ensemble, emulate it,
  triangulate with koine), including the governing predictive-distribution
  equation for the reference `rff` surrogate with its citation.
* **`surrogate-workflow` vignette gains three captioned, interpreted
  figures (FBO-09).** A predictive band against truth across and beyond the
  design (the picture that would have shown an emulator reporting
  in-design-sized uncertainty off-design), the dense cross-output covariance
  beside its rank-1 reconstruction, and the ES-MDA inversion misfit trace.
  Grammar and false-attribution issues in its prose fixed alongside.
* **Governing mathematics added to `predict.fb_surrogate()` (FBO-15).** The
  reference surrogate's predictive mean/variance, previously stated only in
  `#` comments, is now a `\deqn` block with a citation (Bishop, 2006).
  `@examples` added to `predict.fb_surrogate()`, `fb_surrogate_ppc()`, and
  `as_fb_ensemble()` -- the three headline consumers that previously shipped
  with none.
* **`koine_status()` documentation corrected (FBO-12).** Its `@description`
  still read "provisioned but dormant until koine ships a programmatic,
  re-entrant model builder"; the slot has been active by default since
  2026-06-08. Rewritten to describe the activated state.
* **README refreshed (FBO-16).** Dropped the stale "dormant koine slot" and
  unimplemented "gretaR engine, registered against the backend registry"
  bullets (this package registers no gretaR anything); added a minimal
  runnable ingest-emulate-predict example.
* Non-ASCII arrow in `as_fb_ensemble()` roxygen replaced with `->` (FBO-19;
  `tools::checkRd()` flagged it as non-ASCII content without a declared
  encoding).

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
