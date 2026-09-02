# =============================================================================
# test-refusals.R -- one test per abstention reason the package can produce.
#
# Every decline quorum issues is a `quorum_abstention()` carrying the
# `orchestra_refusal` marker the fleet's decline predicate dispatches on
# (abstention.R). This file triggers each reason string defined in R/ for
# real where that is cheap -- no koine battery, no tmbstan sampling, at most a
# fast glmmTMB fit attempt that itself fails -- and records the shared
# contract every one of them must satisfy: `inherits(., "orchestra_refusal")`,
# `abstained == TRUE`, a `reason` and a `scope`.
#
# Two reasons (engine_missing, and two more found while grounding this file:
# draws_malformed, sampling_failed) cannot be triggered live in THIS
# environment, because glmmTMB, tmbstan and koine are all installed here (the
# condition each guards against does not hold) or because the engine that
# would need to fail does not fail the way that would produce the reason. Each
# is documented at its own test below rather than silently skipped.
# =============================================================================

# ---- shared assertion helper -------------------------------------------------

# The contract every quorum_abstention() must satisfy, whatever produced it.
.expect_refusal <- function(x, reason = NULL, scope = NULL) {
  expect_true(is_quorum_abstention(x))
  expect_true(inherits(x, "orchestra_refusal"))
  expect_true(isTRUE(x$abstained))
  expect_type(x$reason, "character")
  expect_type(x$scope, "character")
  if (!is.null(reason)) expect_identical(x$reason, reason)
  if (!is.null(scope)) expect_identical(x$scope, scope)
}

.shares_of <- function(tag) {
  c(sampler = paste0("s_", tag), objective = paste0("o_", tag),
    priors = paste0("p_", tag), data_prep = paste0("d_", tag))
}

# ---- no_quorum (quorum.R) ----------------------------------------------------

test_that("no_quorum: fewer lenses contribute than the policy requires", {
  d <- quorum_draws(list(a = rnorm(30L)), source = "refusal_test")
  one <- lens_from_draws(d, name = "one", member = "m",
                         shares = .shares_of("a"))
  v <- quorum(list(one), policy = quorum_policy("one", min_lenses = 2L))
  .expect_refusal(v@abstention, reason = "no_quorum", scope = "resolution")
  expect_identical(v@status, "no_quorum")
})

# ---- out_of_scope (lens_tmb.R) -----------------------------------------------

test_that("out_of_scope: a random slope fails the TMB shape gate", {
  out <- lens_tmb()@scope(y ~ x + (1 + x | g))
  .expect_refusal(out, reason = "out_of_scope", scope = "lens")
})

# ---- engine_missing (lens_builtin.R, lens_tmb.R) -- source-grounded only -----

test_that("engine_missing: source-grounded (all Suggests installed here)", {
  # lens_koine()'s fit() guards on `requireNamespace("koine", quietly = TRUE)`
  # (R/lens_builtin.R) and lens_tmb()'s fit() guards on `requireNamespace()`
  # over both "glmmTMB" and "tmbstan" (R/lens_tmb.R, .TMB_ENGINES). Neither
  # branch offers an option-based hook to force "not installed" the way
  # `quorum.koine_activated` gates activation, and testthat's
  # local_mocked_bindings() cannot shadow requireNamespace() from inside
  # quorum's own namespace -- it is a base function quorum never imports a
  # rebindable copy of, so local_mocked_bindings(.package = "quorum") reports
  # "Can't find binding for `requireNamespace`" (confirmed while writing this
  # test). All three Suggests engines are installed in this environment, so
  # the branch cannot be reached live without uninstalling a package, which
  # this suite must not do. What is checked instead: the exact shape the
  # branch returns, taken verbatim from its source.
  koine_shape <- quorum_abstention(
    "engine_missing", "package 'koine' (>= 0.2.0) is not installed.",
    scope = "lens"
  )
  .expect_refusal(koine_shape, reason = "engine_missing", scope = "lens")

  tmb_shape <- quorum_abstention(
    "engine_missing",
    "the TMB lens needs glmmTMB and tmbstan; missing: glmmTMB, tmbstan.",
    scope = "lens"
  )
  .expect_refusal(tmb_shape, reason = "engine_missing", scope = "lens")
})

# ---- grid_mismatch (lens_builtin.R) ------------------------------------------

test_that("grid_mismatch: the mechanism ensemble does not cover the grid", {
  ens <- fb_ensemble(params = data.frame(k = c(0.1, 0.2)),
                     outputs = data.frame(a = c(4, 5), b = c(5, 6)))
  out <- lens_mechanism(ens, grid = c(0, 50, 100))
  .expect_refusal(out, reason = "grid_mismatch", scope = "lens")
})

# ---- unsupported_fit (lens_builtin.R) ----------------------------------------

test_that("unsupported_fit: no adapter covers the fit's class", {
  out <- lens_from_fit(structure(list(), class = "lm"))
  .expect_refusal(out, reason = "unsupported_fit", scope = "lens")
})

# ---- lens_abstained (lens_builtin.R, via a real koine capability-gate decline)

test_that("lens_abstained: koine declines a model outside its corner", {
  # A genuinely valid fb_terms, format-wise -- but with three random-term
  # groupings, one more than koine's corner (.KOINE_MAX_GROUPINGS = 2L in
  # R/koine_genomic.R's sibling gate, R/emit_koine.R). emit_koine()'s
  # capability gate returns before any koine:: call, so this is real (koine
  # IS installed and IS reached) but costs nothing.
  fb_too_wide <- structure(
    list(
      response = "y", family = "gaussian", link = "identity",
      intercept = TRUE, fixed_terms = list(),
      random_terms = list(
        list(type = "simple", var = "g1"),
        list(type = "simple", var = "g2"),
        list(type = "simple", var = "g3")
      )
    ),
    class = "fb_terms"
  )
  out <- lens_koine()@fit(fb_too_wide, data.frame(y = 1))
  .expect_refusal(out, reason = "lens_abstained", scope = "lens")
  expect_identical(out$nested_reason, "feature_unsupported")
})

# ---- spec_missing (lens_builtin.R) -------------------------------------------

test_that("spec_missing: the fitted model carries no fb_terms", {
  out <- lens_koine()@fit(list(fb = NULL, extras = list()), data.frame(y = 1))
  .expect_refusal(out, reason = "spec_missing", scope = "lens")
})

# ---- family_unsupported (lens_tmb.R) -----------------------------------------

test_that("family_unsupported: the TMB lens fields four families only", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("tmbstan")
  data <- data.frame(y = rnorm(12L), g = factor(rep(1:3, 4L)))
  out <- lens_tmb(family = "gamma")@fit(y ~ 1 + (1 | g), data)
  .expect_refusal(out, reason = "family_unsupported", scope = "lens")
})

# ---- draws_unavailable (lens_builtin.R) --------------------------------------

test_that("draws_unavailable: the hub backend hands over no usable draws", {
  broken <- structure(list(inla = NULL),
                      class = c("flexybayes_inla", "flexybayes", "list"))
  out <- lens_from_fit(broken, n_samples = 10L)
  .expect_refusal(out, reason = "draws_unavailable", scope = "lens")
})

# ---- not_grounded (quorum.R) -------------------------------------------------

test_that("not_grounded: every lens declines and no status quo is set", {
  d <- quorum_draws(list(a = rnorm(30L)), source = "refusal_test")
  one <- lens_from_draws(d, name = "one", member = "m",
                         shares = .shares_of("a"))
  two <- lens_from_draws(d, name = "two", member = "m",
                         shares = .shares_of("b"))
  decide_fn <- function(draws, grid) {
    list(action = NA_real_, abstained = TRUE, reason = "insufficient_evidence",
        grounding = orchestraManifest::GROUNDING_GROUNDED)
  }
  # No status_quo on the policy: a resolution with nothing grounded left
  # abstains rather than defaulting.
  v <- quorum(list(one, two), policy = quorum_policy(c("one", "two")),
             decide = decide_fn)
  expect_identical(v@resolution$verdict, "abstain")
  .expect_refusal(v@abstention, reason = "not_grounded", scope = "resolution")
})

# ---- bonus reasons, triggered for free (metrics.R) ---------------------------
# The four metrics-layer reasons below are not on the required list, but each
# is a single validating call with no fixture cost, so they are exercised
# here rather than left implicit.

test_that("kind_not_parameters: a response curve in a parameter comparison", {
  curve <- quorum_draws(matrix(rnorm(8L), 2L, 4L), kind = "response_curve",
                        grid = c(0, 1, 2, 3))
  params <- quorum_draws(list(a = rnorm(10L)))
  out <- agreement_pairwise(curve, params)
  .expect_refusal(out, reason = "kind_not_parameters", scope = "comparison")
})

test_that("names_not_present: a requested component absent from both lenses", {
  a <- quorum_draws(list(x = rnorm(10L)))
  b <- quorum_draws(list(x = rnorm(10L)))
  out <- agreement_pairwise(a, b, names = "nonexistent")
  .expect_refusal(out, reason = "names_not_present", scope = "comparison")
})

test_that("no_common_parameters: two lenses share no component name", {
  a <- quorum_draws(list(x = rnorm(10L)))
  b <- quorum_draws(list(z = rnorm(10L)))
  out <- agreement_pairwise(a, b)
  .expect_refusal(out, reason = "no_common_parameters", scope = "comparison")
})

test_that("too_few_lenses: an agreement matrix needs at least two lenses", {
  out <- agreement_matrix(list(one = list(x = rnorm(10L))))
  .expect_refusal(out, reason = "too_few_lenses", scope = "comparison")
})

# ---- bonus: fit_failed, triggered for real (lens_tmb.R) ----------------------

test_that("fit_failed: glmmTMB rejects a binomial fit on non-binary y", {
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("tmbstan")
  data <- data.frame(y = c(2, 5, 9, 1, 4, 8, 3, 6, 10, 0, 7, 2),
                     g = factor(rep(1:3, 4L)))
  out <- lens_tmb(family = "binomial")@fit(y ~ 1 + (1 | g), data)
  .expect_refusal(out, reason = "fit_failed", scope = "lens")
})

# ---- bonus: target_unavailable, triggered via a scoped mock (manifest.R) -----

test_that("target_unavailable: the contract carries no consensus target", {
  d <- quorum_draws(list(a = rnorm(30L)), source = "refusal_test")
  one <- lens_from_draws(d, name = "one", member = "m",
                         shares = .shares_of("a"))
  two <- lens_from_draws(d, name = "two", member = "m",
                         shares = .shares_of("b"))
  v <- quorum(list(one, two), policy = quorum_policy(c("one", "two")))

  # inferential_targets() is orchestraManifest's own exported, namespaced
  # binding (unlike base::requireNamespace above), so testthat can shadow it
  # for the scope of this test without touching the installed package.
  local_mocked_bindings(
    inferential_targets = function(...) character(0),
    .package = "orchestraManifest"
  )
  out <- quorum_manifest(v)
  .expect_refusal(out, reason = "target_unavailable", scope = "manifest")
})

# ---- reasons defined in R/ that this file could not trigger ------------------
#
# draws_malformed (R/lens_builtin.R, `.hub_draws()`): reached only when
# `flexyBayes::fb_as_draws_simple()` returns well-formed named draws that
# still fail `quorum_draws()`'s own equal-length check (for example, two
# canonical parameters with a different draw count after the backend's name
# map is applied). Producing that from outside flexyBayes needs either a
# corrupted real INLA/brms fit, or shadowing the S3 methods flexyBayes and
# quorum already register for `flexybayes_inla` / `flexybayes_brms` /
# `flexybayes_koine` -- attempted for a hand-rolled test class during
# grounding and confirmed NOT to dispatch ahead of the package's own
# registered method, so it cannot be forced from a caller's test file. Left
# undemonstrated; `quorum_draws()`'s own unequal-length error is covered
# directly in test-lens.R.
#
# sampling_failed (R/lens_tmb.R, `.tmb_fit()`): reached only when
# `tmbstan::tmbstan()` itself raises an R error. Tried during grounding with
# `warmup >= iter` (rstan's own documented invalid-configuration case): rstan
# prints "parameter 'warmup' should be an integer less than 'iter'" but
# returns an empty stanfit rather than raising a condition `tryCatch(error =)`
# catches, so the lens instead declines with `draws_unavailable` once the
# empty result carries no `beta` / `theta` columns. A genuine sampler error
# would need a TMB objective that fails mid-HMC (a non-finite gradient), which
# is not reproducible from a valid glmmTMB fit without deliberately forcing
# numerical blow-up -- too fragile to pin the fixture to. Left undemonstrated.
