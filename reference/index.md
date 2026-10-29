# Package index

## Consensus

The front door, the declared policy, and the typed verdict a comparison
resolves into.

- [`quorum()`](https://max578.github.io/quorum/reference/quorum.md) :
  Compare a quorum of lenses and resolve them into one verdict
- [`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md)
  : A resolution policy
- [`quorum_policy_committed()`](https://max578.github.io/quorum/reference/quorum_policy_committed.md)
  [`policy_committed()`](https://max578.github.io/quorum/reference/quorum_policy_committed.md)
  : The committed convention the cascade replaced
- [`lens_contribution()`](https://max578.github.io/quorum/reference/lens_contribution.md)
  : One lens's contribution to a resolution
- [`contributions()`](https://max578.github.io/quorum/reference/contributions.md)
  : Bind lens contributions into one table
- [`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md)
  : Resolve a comparison into one carried answer
- [`quorum_compare_policies()`](https://max578.github.io/quorum/reference/quorum_compare_policies.md)
  : Price several fallback conventions in one table
- [`quorum_manifest()`](https://max578.github.io/quorum/reference/quorum_manifest.md)
  : Emit a verdict as an orchestra manifest
- [`quorum_verdict()`](https://max578.github.io/quorum/reference/quorum_verdict.md)
  : The verdict a quorum returns
- [`print(`*`<quorum::quorum_verdict>`*`)`](https://max578.github.io/quorum/reference/print.quorum-quorum_verdict.md)
  : Print a quorum verdict

## Lenses

The lens contract, the built-in adapters, the registry, and the
independence ledger a comparison is weighed by.

- [`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
  [`lens()`](https://max578.github.io/quorum/reference/quorum_lens.md) :
  A lens: a member's estimate of a shared estimand, with its
  declarations
- [`quorum_draws()`](https://max578.github.io/quorum/reference/quorum_draws.md)
  : The draws every lens returns
- [`lens_from_draws()`](https://max578.github.io/quorum/reference/lens_from_draws.md)
  : Wrap draws a member has already produced as a lens
- [`lens_from_fit()`](https://max578.github.io/quorum/reference/lens_from_fit.md)
  : Wrap a fitted hub or koine model as a lens
- [`lens_koine()`](https://max578.github.io/quorum/reference/lens_koine.md)
  : The koine fourth opinion as a lens
- [`lens_status_quo()`](https://max578.github.io/quorum/reference/lens_status_quo.md)
  : The status quo as a lens
- [`lens_mechanism()`](https://max578.github.io/quorum/reference/lens_mechanism.md)
  : A simulation ensemble as a mechanism lens
- [`lens_tmb()`](https://max578.github.io/quorum/reference/lens_tmb.md)
  : The TMB lens: a second Laplace implementation, sampled with NUTS
- [`register_lens()`](https://max578.github.io/quorum/reference/register_lens.md)
  [`get_lens()`](https://max578.github.io/quorum/reference/register_lens.md)
  [`list_lenses()`](https://max578.github.io/quorum/reference/register_lens.md)
  [`clear_lenses()`](https://max578.github.io/quorum/reference/register_lens.md)
  : Register, retrieve, list and clear lenses
- [`quorum_independence()`](https://max578.github.io/quorum/reference/quorum_independence.md)
  : The independence ledger over a set of lenses
- [`print(`*`<quorum_independence>`*`)`](https://max578.github.io/quorum/reference/print.quorum_independence.md)
  : Print an independence ledger

## Agreement

The hub’s `triangulate()` comparison semantics, re-derived over lens
draws.

- [`agreement_thresholds()`](https://max578.github.io/quorum/reference/agreement_thresholds.md)
  : The hub's agreement cut-offs
- [`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md)
  : Per-component agreement between two lenses
- [`agreement_status()`](https://max578.github.io/quorum/reference/agreement_status.md)
  : The overall status of an agreement table
- [`agreement_matrix()`](https://max578.github.io/quorum/reference/agreement_matrix.md)
  : Pairwise agreement across a quorum of lenses

## On-ramps

The seams by which a non-hub estimate becomes a lens: ensemble ingestion
(contract C5) and surrogate emulation (contract C7).

- [`fb_ensemble()`](https://max578.github.io/quorum/reference/fb_ensemble.md)
  : Construct a canonical simulation-ensemble object

- [`as_fb_ensemble()`](https://max578.github.io/quorum/reference/as_fb_ensemble.md)
  :

  Coerce a conforming producer to a canonical `fb_ensemble`

- [`read_fb_ensemble()`](https://max578.github.io/quorum/reference/read_fb_ensemble.md)
  : Read a simulation ensemble from a file

- [`verify_fb_ensemble()`](https://max578.github.io/quorum/reference/verify_fb_ensemble.md)
  : Verify a simulation ensemble against the C5 contract

- [`register_ensemble_source()`](https://max578.github.io/quorum/reference/register_ensemble_source.md)
  : Register an ensemble-source coercer for a producer class

- [`fb_prior_from_ensemble()`](https://max578.github.io/quorum/reference/fb_prior_from_ensemble.md)
  : Derive an informative flexyBayes prior from a simulation ensemble

- [`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md)
  : Fit a distribution-preserving surrogate to a simulation ensemble

- [`predict(`*`<fb_surrogate>`*`)`](https://max578.github.io/quorum/reference/predict.fb_surrogate.md)
  : Predict from a quorum surrogate (mean + sd per output)

- [`fb_surrogate_ies()`](https://max578.github.io/quorum/reference/fb_surrogate_ies.md)
  : Surrogate-accelerated ensemble inversion (ES-MDA)

- [`fb_surrogate_ppc()`](https://max578.github.io/quorum/reference/fb_surrogate_ppc.md)
  : Posterior-predictive check of a surrogate against held-out outputs

- [`register_surrogate()`](https://max578.github.io/quorum/reference/register_surrogate.md)
  : Register a surrogate-fitting method

- [`register_pesto_surrogates()`](https://max578.github.io/quorum/reference/register_pesto_surrogates.md)
  : Register PESTO's GP surrogate as a flexyBayes C7 conformer

- [`register_kernr_surrogates()`](https://max578.github.io/quorum/reference/register_kernr_surrogates.md)
  : Register kernR's conditional mean embedding as a flexyBayes C7
  conformer

- [`fb_cov_slice()`](https://max578.github.io/quorum/reference/fb_cov_slice.md)
  : Reconstruct a per-row covariance slice from a surrogate prediction

- [`fb_pesto()`](https://max578.github.io/quorum/reference/fb_pesto.md)
  : Carry a PESTO calibration into flexyBayes

## Fourth opinion

The koine backend (contract C3): an independently-derived REML opinion
alongside the hub’s own engines.

- [`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
  : Emit a koine fourth-opinion fit
- [`koine_genomic_lens()`](https://max578.github.io/quorum/reference/koine_genomic_lens.md)
  : Koine genomic fourth opinion (REML lens via sommer)
- [`koine_status()`](https://max578.github.io/quorum/reference/koine_status.md)
  : Introspect the koine backend slot
- [`print(`*`<flexybayes_koine>`*`)`](https://max578.github.io/quorum/reference/print.flexybayes_koine.md)
  : Print a koine fourth-opinion fit
- [`coef(`*`<flexybayes_koine>`*`)`](https://max578.github.io/quorum/reference/coef.flexybayes_koine.md)
  : Posterior-mean coefficients for a koine fit
- [`canonical_names(`*`<flexybayes_koine>`*`)`](https://max578.github.io/quorum/reference/canonical_names.flexybayes_koine.md)
  : Canonical names for a koine fit (self-naming)
- [`fb_as_draws_simple(`*`<flexybayes_koine>`*`)`](https://max578.github.io/quorum/reference/fb_as_draws_simple.flexybayes_koine.md)
  : Extract simple draws from a koine fit

## Declines

The package’s one typed decline, issued wherever a lens, a comparison or
a resolution has nothing to carry.

- [`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
  [`is_quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
  : Construct a typed quorum abstention
