# =============================================================================
# test-conformance.R -- the lens conformance battery + the "every export is
# exercised" sweep.
#
# Two independent gates. (1) Every built-in lens constructor is checked
# against the lens contract itself (lens.R): a quorum_lens object, all four
# `shares` components declared, `expresses` a subset of the four response
# shapes, and `scope()` / `fit()` answering only in the two shapes the
# contract allows -- a quorum_draws or a classed, typed abstention, never a
# bare value and never a crash. (2) Every exported name in NAMESPACE is swept
# with input chosen to be clearly invalid, and is required to decline visibly
# (an error, or a classed abstention) rather than returning silently or
# crashing R. Neither gate fits a real model: koine, glmmTMB and tmbstan
# fitting/sampling are exercised elsewhere (test-lens-tmb.R,
# test-koine-slot.R, test-koine-genomic.R); this file stays in the seconds
# range throughout.
# =============================================================================

# ---- shared assertion helpers ------------------------------------------------

.CONF_SHARES <- c("sampler", "objective", "priors", "data_prep")
.CONF_SHAPES <- c("linear", "plateau", "threshold", "nonmonotone")

# Invariants (i)-(iv) of the lens conformance contract: a quorum_lens object,
# every shares component declared, expresses a subset of the four shapes, and
# scope() answering TRUE or a classed abstention on `spec`.
.expect_lens_contract <- function(one, spec = NULL) {
  expect_true(S7::S7_inherits(one, quorum_lens))
  expect_setequal(names(S7::prop(one, "shares")), .CONF_SHARES)
  expect_true(all(S7::prop(one, "expresses") %in% .CONF_SHAPES))
  scoped <- S7::prop(one, "scope")(spec)
  expect_true(isTRUE(scoped) || is_quorum_abstention(scoped))
}

# Invariant (v): fit() (or, for the two lenses whose grid/format check is a
# construction-time gate, the constructor itself) returns either a
# quorum_draws or a classed, typed abstention -- never anything else.
.expect_fit_contract <- function(result) {
  ok <- S7::S7_inherits(result, quorum_draws) ||
    (is_quorum_abstention(result) && inherits(result, "orchestra_refusal"))
  expect_true(ok)
}

# ---- lens_from_draws ---------------------------------------------------------

test_that("lens_from_draws satisfies the lens conformance contract", {
  d <- quorum_draws(list(a = rnorm(20L), b = rnorm(20L)), source = "conf")
  one <- lens_from_draws(
    d, name = "conf_draws", member = "quorum",
    shares = c(sampler = "s", objective = "o", priors = "p", data_prep = "dp")
  )
  .expect_lens_contract(one, spec = NULL)
  .expect_fit_contract(S7::prop(one, "fit")(NULL, NULL))
  # The draws are already in hand at construction; there is no scope-time or
  # fit-time decline path of its own to demonstrate an out-of-scope input for.
})

# ---- lens_status_quo ---------------------------------------------------------

test_that("lens_status_quo satisfies the lens conformance contract", {
  one <- lens_status_quo(value = 3.2, grid = c(0, 40, 80, 120))
  .expect_lens_contract(one, spec = NULL)
  .expect_fit_contract(S7::prop(one, "fit")(NULL, NULL))
  # A constant over a validated grid; value/grid are checked at construction
  # (test-lens-builtin.R), so there is no scope-time or fit-time decline path.
})

# ---- lens_mechanism ----------------------------------------------------------

test_that("lens_mechanism satisfies the lens conformance contract", {
  ens <- fb_ensemble(
    params = data.frame(k = c(0.1, 0.2, 0.3)),
    outputs = data.frame(a = c(4, 5, 6), b = c(5, 6, 7))
  )
  in_scope <- lens_mechanism(ens, grid = c(0, 50))
  .expect_lens_contract(in_scope, spec = NULL)
  .expect_fit_contract(S7::prop(in_scope, "fit")(NULL, NULL))

  # Out of scope: a grid the outputs do not cover. lens_mechanism()'s grid
  # check IS its scope gate, evaluated eagerly at construction rather than
  # lazily at scope()/fit() time, so the constructor itself returns the typed
  # decline rather than a lens whose fit() would decline.
  out_of_scope <- lens_mechanism(ens, grid = c(0, 50, 100))
  .expect_fit_contract(out_of_scope)
  expect_identical(out_of_scope$reason, "grid_mismatch")
})

# ---- lens_koine (abstention paths only -- no koine battery is fit) -----------

test_that("lens_koine satisfies the lens conformance contract", {
  one <- lens_koine()
  .expect_lens_contract(one, spec = NULL)

  # In-scope input FORMAT (a real fb_terms) that still declines: more
  # groupings than koine's corner fields. emit_koine()'s capability gate
  # returns before any koine:: call, so this costs nothing.
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
  declined <- S7::prop(one, "fit")(fb_too_wide, data.frame(y = 1))
  .expect_fit_contract(declined)
  expect_identical(declined$reason, "lens_abstained")

  # Out of scope: not an fb_terms object and no fitted model carries one.
  out_of_scope <- S7::prop(one, "fit")(list(fb = NULL, extras = list()),
                                       data.frame(y = 1))
  .expect_fit_contract(out_of_scope)
  expect_identical(out_of_scope$reason, "spec_missing")
})

# ---- lens_tmb (abstention paths only -- no tmbstan sampling here) ------------

test_that("lens_tmb satisfies the lens conformance contract", {
  one <- lens_tmb()
  .expect_lens_contract(one, spec = y ~ 1 + (1 | g))

  # Out of scope, at the scope() gate itself: a random slope. No engine is
  # needed -- .tmb_shape() is pure formula parsing.
  out_of_scope_spec <- y ~ x + (1 + x | g)
  scope_decline <- S7::prop(one, "scope")(out_of_scope_spec)
  expect_true(is_quorum_abstention(scope_decline))
  expect_identical(scope_decline$reason, "out_of_scope")

  # fit()'s own shape/family gates run after an engine-presence check, so the
  # remaining two assertions need glmmTMB + tmbstan installed to be reached at
  # all -- neither is ever asked to fit or sample here.
  skip_if_not_installed("glmmTMB")
  skip_if_not_installed("tmbstan")
  data <- data.frame(y = rnorm(12L), g = factor(rep(1:3, 4L)))

  # In-scope shape, fit-time decline: an unsupported family.
  in_scope_declines <- lens_tmb(family = "gamma")@fit(y ~ 1 + (1 | g), data)
  .expect_fit_contract(in_scope_declines)
  expect_identical(in_scope_declines$reason, "family_unsupported")

  # Out of scope, reached through fit() directly rather than scope().
  data$x <- rnorm(12L)
  fit_decline <- one@fit(out_of_scope_spec, data)
  .expect_fit_contract(fit_decline)
  expect_identical(fit_decline$reason, "out_of_scope")
})

# ---- lens_from_fit -----------------------------------------------------------

test_that("lens_from_fit satisfies the lens conformance contract", {
  # In scope: a hand-made koine-profile fit, dispatched through quorum's own
  # registered fb_as_draws_simple.flexybayes_koine() / canonical_names
  # methods -- no engine, no real koine fit, just synthetic draws.
  skip_if_not_installed("posterior")
  draws_mat <- matrix(rnorm(200L), ncol = 2L,
                      dimnames = list(NULL, c("(Intercept)", "sd_g")))
  synthetic_fit <- structure(
    list(status = "contributed", draws = draws_mat, fb = NULL, data = NULL,
        extras = list()),
    class = c("flexybayes_koine", "list")
  )
  wrapped <- lens_from_fit(synthetic_fit, n_samples = 100L)
  .expect_lens_contract(wrapped, spec = NULL)
  .expect_fit_contract(S7::prop(wrapped, "fit")(NULL, NULL))

  # Out of scope: an unknown object class, no adapter. lens_from_fit()'s
  # class check IS its scope gate, evaluated eagerly at construction, so the
  # decline comes back directly rather than from a lens's fit().
  unknown <- lens_from_fit(structure(list(), class = "lm"))
  .expect_fit_contract(unknown)
  expect_identical(unknown$reason, "unsupported_fit")
})

# ---- every export is exercised -----------------------------------------------

# Exports whose entire purpose is fitting a real model. Excluded from the
# invalid-input sweep below on principle, not merely because today's
# validation order happens to fail fast: a future refactor that reordered
# checks in front of the fitting call could otherwise turn "invalid input"
# into a real (Suggests-engine) fit inside this file.
.EXERCISE_EXCLUDED <- c(
  fit_surrogate = paste(
    "trains a real emulator (rff / gp / cme) on the ensemble"
  ),
  fb_surrogate_ies = paste(
    "runs the real iterative ensemble smoother (multiple fit iterations,",
    "Emerick & Reynolds 2013)"
  ),
  emit_koine = paste(
    "synthesises a real koine stacking battery (koine::synthesise) once",
    "past its capability gate"
  ),
  koine_genomic_lens = paste(
    "fits a real REML genomic BLUP via sommer::mmer()"
  )
)

# Exports that are total by design -- they answer a question about their
# input rather than acting on it -- and so do not naturally fit the
# error/abstention contract the sweep below checks. Each is asserted directly
# in its own test instead.
.EXERCISE_SPECIAL <- c("is_quorum_abstention", "verify_fb_ensemble")

# One deliberately invalid call per exercised export, chosen by reading
# R/*.R so each fails at the export's OWN first validation line -- before any
# fitting, sampling or ensemble parsing -- so the sweep stays in the seconds
# range even though several of these exports are expensive on valid input.
# Where an export's first-referenced argument is enough to trigger the
# decline, later required arguments are left unsupplied on purpose: R's lazy
# evaluation means they are never forced, so the call needs no valid stand-in
# for them either.
.exercise_calls <- list(
  agreement_matrix = function() agreement_matrix(list(1, 2)),
  agreement_pairwise = function() agreement_pairwise("nope", "nope2"),
  agreement_status = function() agreement_status("not a table"),
  agreement_thresholds = function() {
    agreement_thresholds(mean_shift_sd_max = -1)
  },
  as_fb_ensemble = function() {
    as_fb_ensemble(structure(list(), class = "nothing"))
  },
  clear_lenses = function() clear_lenses(bogus = 1),
  contributions = function() contributions("not a data frame"),
  fb_cov_slice = function() fb_cov_slice(prediction = "invalid"),
  fb_ensemble = function() {
    fb_ensemble(params = data.frame(a = 1), outputs = data.frame(b = 1:5))
  },
  fb_pesto = function() fb_pesto(method = "bogus"),
  fb_prior_from_ensemble = function() fb_prior_from_ensemble(method = "bogus"),
  fb_surrogate_ppc = function() fb_surrogate_ppc(surrogate = "not a surrogate"),
  get_lens = function() get_lens(c("a", "b")),
  koine_status = function() koine_status(bogus = 1),
  lens = function() lens(),
  lens_contribution = function() {
    lens_contribution(lens = 123, grounded = TRUE, abstained = FALSE)
  },
  lens_from_draws = function() {
    lens_from_draws(
      draws = "nope", name = "n", member = "m",
      shares = c(sampler = "a", objective = "b", priors = "c", data_prep = "d")
    )
  },
  lens_from_fit = function() lens_from_fit(structure(list(), class = "lm")),
  lens_koine = function() lens_koine(name = 123),
  lens_mechanism = function() {
    lens_mechanism(ensemble = NULL, grid = numeric(0))
  },
  lens_status_quo = function() {
    lens_status_quo(value = NA_real_, grid = c(0, 1))
  },
  lens_tmb = function() lens_tmb(chains = 0L),
  list_lenses = function() list_lenses(bogus = 1),
  policy_committed = function() policy_committed(fixed = "bogus"),
  quorum = function() quorum(policy = "not a policy"),
  quorum_abstention = function() quorum_abstention(reason = ""),
  quorum_compare_policies = function() {
    quorum_compare_policies(contrib = "not a df")
  },
  quorum_draws = function() quorum_draws(draws = list()),
  quorum_independence = function() quorum_independence(lenses = "not a list"),
  quorum_lens = function() quorum_lens(name = ""),
  quorum_manifest = function() quorum_manifest(verdict = "not a verdict"),
  quorum_policy = function() quorum_policy(order = character(0)),
  quorum_policy_committed = function() {
    quorum_policy_committed(fixed = "bogus")
  },
  quorum_resolve = function() quorum_resolve(contrib = "not a df"),
  quorum_verdict = function() quorum_verdict(lenses = 123),
  read_fb_ensemble = function() {
    read_fb_ensemble(path = "/nonexistent/path.rds")
  },
  register_ensemble_source = function() {
    register_ensemble_source(producer_class = 123)
  },
  register_kernr_surrogates = function() register_kernr_surrogates(bogus = 1),
  register_lens = function() register_lens(lens = list(name = "fake")),
  register_pesto_surrogates = function() register_pesto_surrogates(bogus = 1),
  register_surrogate = function() register_surrogate(method = 123)
)

test_that("every export is a function (S7 class generators included)", {
  exports_vec <- getNamespaceExports("quorum")
  s1 <- length(exports_vec)
  for (i1 in seq_len(s1)) {
    obj <- get(exports_vec[i1], envir = asNamespace("quorum"))
    expect_true(is.function(obj), label = exports_vec[i1])
  } # ends i1, over every exported name
})

test_that("the exercise table accounts for every export exactly once", {
  exports_vec <- sort(getNamespaceExports("quorum"))
  covered_vec <- sort(c(names(.exercise_calls), names(.EXERCISE_EXCLUDED),
                        .EXERCISE_SPECIAL))
  expect_identical(covered_vec, exports_vec)
})

test_that("every exercised export declines invalid input, never silently", {
  nms <- names(.exercise_calls)
  s1 <- length(.exercise_calls)
  for (i1 in seq_len(s1)) {
    result <- tryCatch(.exercise_calls[[i1]](), error = function(e) e)
    expect_false(is.null(result), label = nms[i1])
    ok <- inherits(result, "error") ||
      (is_quorum_abstention(result) && inherits(result, "orchestra_refusal"))
    expect_true(ok, label = nms[i1])
  } # ends i1, over the exercised exports
})

test_that("the excluded exports are still functions, just never invoked here", {
  nms <- names(.EXERCISE_EXCLUDED)
  s1 <- length(.EXERCISE_EXCLUDED)
  for (i1 in seq_len(s1)) {
    obj <- get(nms[i1], envir = asNamespace("quorum"))
    expect_true(is.function(obj), label = nms[i1])
  } # ends i1, over the excluded exports
})

test_that("verify_fb_ensemble is total: a verdict list, not an error", {
  out <- verify_fb_ensemble("not a list")
  expect_type(out, "list")
  expect_false(out$ok)
  expect_true(nzchar(out$message))

  out_ok <- verify_fb_ensemble(fb_ensemble(
    params = data.frame(k = c(0.1, 0.2)), outputs = data.frame(a = c(1, 2))
  ))
  expect_true(out_ok$ok)
})

test_that("is_quorum_abstention is total: FALSE unless truly an abstention", {
  expect_false(is_quorum_abstention(NULL))
  expect_false(is_quorum_abstention(42))
  expect_false(is_quorum_abstention(list(reason = "looks like one")))
  expect_true(is_quorum_abstention(quorum_abstention("x")))
})

# ---- print() methods produce output ------------------------------------------

test_that("print() shows an abstention, a ledger, a table and a verdict", {
  abstention_out <- utils::capture.output(print(quorum_abstention("x")))
  expect_true(length(abstention_out) > 0L)

  d <- quorum_draws(list(a = rnorm(20L)), source = "print_test")
  one <- lens_from_draws(
    d, name = "one", member = "m",
    shares = c(sampler = "s1", objective = "o1", priors = "p1",
              data_prep = "dp1")
  )
  two <- lens_from_draws(
    d, name = "two", member = "m",
    shares = c(sampler = "s2", objective = "o2", priors = "p2",
              data_prep = "dp2")
  )

  independence_out <- utils::capture.output(
    print(quorum_independence(list(one, two)))
  )
  expect_true(length(independence_out) > 0L)

  agr <- agreement_matrix(list(one = list(a = rnorm(50L)),
                               two = list(a = rnorm(50L))))
  agreement_out <- utils::capture.output(print(agr))
  expect_true(length(agreement_out) > 0L)

  v <- quorum(list(one, two), policy = quorum_policy(c("one", "two")))
  verdict_print <- get("print.quorum::quorum_verdict",
                       envir = asNamespace("quorum"))
  verdict_out <- utils::capture.output(verdict_print(v))
  expect_true(length(verdict_out) > 0L)
})
