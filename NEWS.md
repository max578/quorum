# quorum 0.1.0

* **Renamed from `flexyBayesOrchestra` and re-dedicated as the orchestra's
  consensus layer** (plan approved 2026-09-02). quorum compares lenses and
  never fits a model of its own: every lens is a member's fitter behind an
  adapter with declared independence, expressiveness and scope. A quorum of independent lenses must agree before an
  answer is carried; no quorum means abstain. The previous capabilities stay as
  the on-ramps by which non-hub estimates become lenses (ensemble ingestion,
  surrogates, the koine backend); their function names are unchanged.
* New: `quorum_abstention()` / `is_quorum_abstention()`, the package's typed
  decline (classed `quorum_abstention` / `orchestra_refusal`).
* `Imports:` gains `orchestraManifest` and `S7`.
* The `flexyBayesOrchestra_abstention` class stamp is now `quorum_abstention`;
  the `flexyBayesOrchestra.koine_activated` option is now
  `quorum.koine_activated`.
* **The lens contract and registry** (`lens()`, `lens_from_draws()`,
  `lens_from_fit()`, `lens_koine()`, `lens_status_quo()`, `lens_mechanism()`,
  and the roster `register_lens()`/`get_lens()`/`list_lenses()`/
  `clear_lenses()`) declare a member's estimate as a `quorum_lens`, with its
  shared components, its expressible response shapes and its scope, so any
  producer can register an adapter without a code change here.
* **The TMB lens** (`lens_tmb()`) fits glmmTMB's Laplace-approximated
  marginal likelihood and samples the very TMB objective that fit produced
  with tmbstan's NUTS sampler, contributing a second Laplace implementation
  and one objective sampled two ways, with the hub's default priors matched
  as far as glmmTMB's syntax allows and declared when they are not.
* **The independence ledger** (`quorum_independence()`) counts what every
  pair of lenses shares across sampler, objective, priors and data
  preparation and converts the count into the evidential weight a quorum
  reads before treating agreement as corroboration.
* **The agreement layer** (`agreement_thresholds()`, `agreement_pairwise()`,
  `agreement_status()`, `agreement_matrix()`) re-derives the hub's
  `triangulate()` comparison semantics over lens draws component by
  component, proven bit-identical to the hub's own output on the same draws.
* **Policy and resolution** (`quorum_policy()`, `policy_committed()`,
  `lens_contribution()`, `quorum_resolve()`, `quorum_compare_policies()`)
  generalise Study A0's hand-written two-lens cascade into a declared
  fallback order over any number of lenses, with the two committed
  conventions the cascade replaced kept as priceable policy objects.
* **The front door** (`quorum()`) gates each lens on its own scope, asks it
  to fit, compares what came back, weighs the comparison by declared
  independence, and resolves it through the policy into a `quorum_verdict`:
  `concordant`, `discordant`, `no_quorum` (abstain) or `not_computed`.
* **The manifest** (`quorum_manifest()`) emits a verdict as an
  `orchestra_manifest` with `inferential_target = "consensus"`, stamped
  grounded only when a contributing lens is grounded and the lenses did not
  read the same upstream data fact.
* **The Study A0 cascade is reproduced bit-identically from the package** on
  the shipped fixture: 200 decision cells resolve to the recorded tiers and
  rates, mechanism carrying 150, statistical 48 and the status quo 2.

## The quorum -> decideR seam

* **A concordant verdict now carries the carried lens's posterior into its
  manifest**, in `outputs`, hashed with the contributions table and the summary.
  Before this the lenses' draws were discarded once agreement had been computed,
  so a consensus manifest left the package with nothing a decision layer could
  read: `decideR::decide_from_manifest()` found no draws and failed on the shape.
  The seam between the orchestra's consensus layer and its decision layer was
  open, on the exact target the consensus layer exists to produce.

* **A verdict that issued no number carries no draws.** Only a `concordant`
  status over a single resolved cell releases the posterior. A `no_quorum`,
  `discordant` or `not_computed` verdict emits `outputs = NULL`, so nothing
  downstream can price a number the quorum declined to issue.

* The draws are read through the lens object's own property rather than coerced.
  `quorum_draws` holds a named list of numeric vectors for the `parameters`
  kind, and coercing the object directly would have produced a one-column
  list-matrix without failing, which is the quiet kind of wrong.

## Documentation

* Help pages no longer point to the `triangulate()` functions removed from
  flexyBayes in 0.14.0; `emit_koine()` now names `lens_from_fit()` and
  `agreement_pairwise()` as the way to compare a koine fit with another fit.

## Carried from flexyBayesOrchestra

* Relicensed from GPL (>= 3) to MIT (orchestra-wide licence unification, 2026-09-02). No code change.

* **`emit_koine()`'s abstained exit now stamps the outer wrapper as a
  dispatchable orchestra decline.** The returned `flexybayes_koine` object
  already carried a real, correctly-typed nested `koine_abstention` at
  `$koine` whenever koine's corner or convergence gate declined a model, but
  the OUTER object -- what a caller (and the orchestra's refusal-contract
  gate, `is_orchestra_decline()`) actually holds -- was always plain
  `c("flexybayes_koine", "list")`, invisible to any predicate keyed on a
  `_refusal` / `_abstention` class suffix or the `orchestra_refusal` marker.
  The abstained exit now prepends `c("quorum_abstention",
  "orchestra_refusal")` to that class vector; a contributed fit is unchanged.
  Existing consumers are unaffected: `inherits(x, "flexybayes_koine")`,
  `is.list(x)`, and every `*.flexybayes_koine` S3 method still dispatch, since
  S3 method lookup scans the whole class vector and `"flexybayes_koine"` is
  still present, just no longer first. WHAT is refused is unchanged -- only
  HOW the abstained case is signalled to a class-based predicate.
* **`emit_koine()` now fits a multi-environment trial instead of abstaining on
  every one (FBO-06).** The capability gate refused any model with more than one
  random term, which matched the single `group` argument the companion drove --
  so koine's fourth column was empty on exactly the crossed
  `(1 | variety) + (1 | trial)` structure the study series' statistical lens is
  built from. koine 0.3.0 fields that structure through the `groups` argument of
  `koine_pass_from_design()` (read from the installed namespace, not assumed),
  and the MET case is now routed there: the gate admits two plain random
  intercepts, the group SDs koine reports as `tau_<grouping>` canonicalise to
  `sd_<grouping>`, and `extras$model_info` records the resolved
  `re_structure`. Below koine 0.3.0 a two-grouping model returns a typed
  abstention naming the version floor, and more than two groupings (or any
  non-intercept random term) still abstains before any koine call. `Suggests:`
  raised to `koine (>= 0.3.0)`; the slot-activation floor stays at 0.2.0, which
  is still the floor for the single-intercept corner.
* **The kernR `cme` conformer no longer extrapolates confidently (FBO-01).**
  The conditional-mean smoother's weights decay to zero as a prediction point
  leaves the design, which drove the mean to zero *and* the reported
  `sigma^2 (1 + ||w||^2)` sd down to its in-design floor -- on the reference
  design the conformer returned `y_mean = 0.000000, y_sd = 0.298104` at
  `(a, b) = (12, 12)` against a true `71.463427`, the same sd it reports in the
  middle of the design. The conformer now records the smoother's weight mass
  across the training design at fit time and raises a classed
  `fb_surrogate_cme_abstention` condition (the `_abstention` suffix the
  constellation's shared decline predicate keys on) wherever the mass falls
  below `weight_mass_frac` (default 0.5) times the least-supported design
  point's mass, naming the reference `rff` surrogate as the extrapolation
  fallback. The floor is tunable at fit time (`weight_mass_frac`,
  `weight_mass_floor`) and per call (`weight_mass_floor`), and setting it to 0
  restores the ungated behaviour deliberately.
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
  `quorum` throughout, which is where both contracts are
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
* `quorum_resolve()` treats both `"ungrounded"` (orchestraManifest 0.2.0)
  and the older `"[unverified]"` as an ungrounded input.

# quorum 0.0.0.9000

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
  binomial / poisson; it abstains outside its corner. The slot
  (`koine_status()`) is now live: activation floor `koine (>= 0.2.0)`, gated by
  `options(quorum.koine_activated = TRUE)` (the default). koine
  moved to `Suggests`; `posterior` added to `Suggests`.
* Initial development version. quorum is the orchestra-composition
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
