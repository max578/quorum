# =============================================================================
# test-koine-slot.R -- the koine fourth-opinion backend (R/koine_slot.R +
# R/emit_koine.R).
#
# koine is the synthesised fourth opinion on the orthogonal lens axis. The
# 0.7.0 lean-core split moved it out of flexyBayes core to this companion;
# activation (2026-06-08) ports koine's real emit + registers S3 methods on
# core's exported `fb_as_draws_simple` / `canonical_names` generics, so core's
# generic `triangulate()` consumes a `flexybayes_koine` fit as its fourth
# column with no core edit. These tests pin: the activated status shape, the
# option-gated dormancy fallback, a contributed emit on koine's (1 | g) corner,
# an honest abstention out of corner, and the triangulate seam.
# =============================================================================

# ---------------------------------------------------------------- #
# (1) koine_status() reports the activated shape                    #
# ---------------------------------------------------------------- #

test_that("koine_status() reports the activated shape when koine is installed", {
  skip_if_not_installed("koine")
  ks <- koine_status()
  expect_type(ks, "list")
  expect_named(
    ks,
    c("activated", "koine_installed", "builder_confirmed",
      "dormancy_reason", "activation_procedure")
  )
  expect_true(ks$koine_installed)
  expect_true(ks$builder_confirmed)
  expect_true(ks$activated)
  expect_identical(ks$dormancy_reason, "koine_dispatch_eligible")
  expect_type(ks$activation_procedure, "character")
  expect_true(length(ks$activation_procedure) >= 1L)
})


# ---------------------------------------------------------------- #
# (2) the activation option gates the slot dormant on demand        #
# ---------------------------------------------------------------- #

test_that("setting the activation option FALSE holds the slot dormant", {
  skip_if_not_installed("koine")
  withr::local_options(quorum.koine_activated = FALSE)
  expect_identical(
    .koine_dormancy_reason(),
    "slot_provisioned_not_activated"
  )
  expect_false(koine_status()$activated)
})

test_that("the version floor is the 0.2.0 poisson-corner gate", {
  expect_identical(.KOINE_VERSION_FLOOR, "0.2.0")
})


# ---------------------------------------------------------------- #
# (3) emit_koine() contributes on koine's (1 | g) corner            #
# ---------------------------------------------------------------- #

# A gaussian GLMM with a single random intercept, koine's home corner.
.koine_test_fb <- function() {
  structure(list(
    response = "y", family = "gaussian", link = "identity", intercept = TRUE,
    fixed_terms = list(list(type = "continuous", var = "x")),
    random_terms = list(list(type = "simple", var = "g"))
  ), class = "fb_terms")
}

.koine_test_data <- function(seed = 7L) {
  set.seed(seed)
  ng <- 12L
  m <- 8L
  n <- ng * m
  g <- factor(rep(seq_len(ng), each = m))
  x <- stats::rnorm(n)
  b <- stats::rnorm(ng, 0, 0.8)
  eta <- 0.4 + 0.6 * x + b[as.integer(g)]
  data.frame(y = eta + stats::rnorm(n, 0, 0.7), x = x, g = g)
}

test_that("emit_koine() contributes a self-naming opinion on the (1|g) corner", {
  skip_if_not_installed("koine")
  skip_if_not_installed("posterior")
  d <- .koine_test_data()
  fk <- emit_koine(.koine_test_fb(), d, n_samples = 800L, seed = 4L)
  expect_s3_class(fk, "flexybayes_koine")
  expect_identical(fk$status, "contributed")

  draws <- flexyBayes::fb_as_draws_simple(fk)
  expect_type(draws, "list")
  # self-naming: koine's b_<col> tokens are canonicalised; no b_ prefix remains.
  expect_false(any(grepl("^b_", names(draws))))
  expect_true("x" %in% names(draws))

  cn <- flexyBayes::canonical_names(fk)
  expect_identical(cn$source, "self_naming")
  expect_identical(cn$map, character(0))
})


# ---------------------------------------------------------------- #
# (4) emit_koine() abstains honestly outside the corner             #
# ---------------------------------------------------------------- #

test_that("emit_koine() abstains on a random slope (out of corner)", {
  skip_if_not_installed("koine")
  fb_slope <- structure(list(
    response = "y", family = "gaussian", link = "identity", intercept = TRUE,
    fixed_terms = list(list(type = "continuous", var = "x")),
    random_terms = list(list(type = "slope_uncor", var = "g", slope_var = "x"))
  ), class = "fb_terms")
  fk <- emit_koine(fb_slope, .koine_test_data())
  expect_identical(fk$status, "abstained")
  expect_error(flexyBayes::fb_as_draws_simple(fk), "abstained")
})


# ---------------------------------------------------------------- #
# (5) triangulate() consumes the koine fourth opinion (the seam)    #
# ---------------------------------------------------------------- #

test_that("flexyBayes::triangulate() aligns on a koine fit via the generics", {
  skip_if_not_installed("koine")
  skip_if_not_installed("posterior")
  skip_if_not_installed("flexyBayes")
  d <- .koine_test_data()
  fb <- .koine_test_fb()
  ka <- emit_koine(fb, d, n_samples = 800L, seed = 4L)
  kb <- emit_koine(fb, d, n_samples = 800L, seed = 5L)
  skip_if(ka$status != "contributed" || kb$status != "contributed")
  tri <- flexyBayes::triangulate(ka, kb, n_samples = 500L)
  expect_true(is.list(tri))
  expect_true(!is.null(tri$n_common) && tri$n_common >= 2L)
})


# ---------------------------------------------------------------- #
# (6) the legacy dormant mapper stub still returns its sentinel     #
# ---------------------------------------------------------------- #

test_that("the legacy koine mapper stub returns the scaffold sentinel", {
  out <- .mapper_koine_stub(fit = NULL, fb_terms = NULL)
  expect_identical(out$source, "scaffold_dormant")
  expect_identical(out$map, character(0))
})


# ---------------------------------------------------------------- #
# (7) FBO-06: the MET (two-grouping) corner reaches koine 0.3.0     #
# ---------------------------------------------------------------- #

# The breeder-standard multi-environment trial: a fixed covariate plus two
# crossed random intercepts, (1 | variety) + (1 | trial). This is the model the
# study series' statistical lens is built from, and the shape emit_koine() used
# to refuse at the capability gate before any koine call.
.koine_met_fb <- function() {
  structure(list(
    response = "y", family = "gaussian", link = "identity", intercept = TRUE,
    fixed_terms = list(list(type = "continuous", var = "x")),
    random_terms = list(
      list(type = "simple", var = "variety"),
      list(type = "simple", var = "trial")
    )
  ), class = "fb_terms")
}

.koine_met_data <- function(seed = 1L, nv = 5L, nt = 4L, nr = 2L) {
  set.seed(seed)
  d <- expand.grid(
    variety = factor(seq_len(nv)),
    trial = factor(seq_len(nt)),
    rep = seq_len(nr)
  )
  d$x <- stats::rnorm(nrow(d))
  bv <- stats::rnorm(nv, 0, 0.8)
  bt <- stats::rnorm(nt, 0, 0.5)
  d$y <- 0.5 + 0.7 * d$x + bv[as.integer(d$variety)] +
    bt[as.integer(d$trial)] + stats::rnorm(nrow(d), 0, 0.6)
  d
}

# ORACLE: koine 0.3.0's OWN formula entry, koine_pass(y ~ x + (1 | variety) +
# (1 | trial), ...) -- an entry point authored by koine, not by this package,
# that fits the same MET directly and independently of the design-array route
# emit_koine() drives. The expected values are koine's, never this package's.
# Tolerance: the two routes drive the same battery from the same seed but keep
# separate RNG streams for the synthesised opinion draws, so posterior means
# agree only up to Monte-Carlo noise; the observed worst gap over the five
# parameters was 0.026 (2026-08-25), and 0.15 is set as a ceiling that is an
# order of magnitude below the parameter scale but well clear of that noise.
test_that("emit_koine() fits a MET and matches koine's own formula entry", {
  skip_if_not_installed("koine")
  skip_if_not_installed("posterior")
  # deliberately NOT skip_on_cran(): this is the gate that keeps the fourth
  # opinion available on a MET, and it must run wherever the suite runs. It
  # costs roughly 40 s (two koine batteries), the price of a real oracle.
  d <- .koine_met_data()
  fk <- emit_koine(.koine_met_fb(), d, n_samples = 800L, seed = 3L)

  # the capability gate must no longer refuse a MET before koine is called,
  # and the model must be recorded as having been routed through the MET entry
  expect_false(identical(fk$extras$reason, "feature_unsupported"))
  expect_identical(fk$extras$model_info$re_structure, "met")
  expect_identical(fk$extras$model_info$groupings, c("variety", "trial"))

  # the oracle, fitted independently through koine's own formula entry
  pass <- koine::koine_pass(
    y ~ x + (1 | variety) + (1 | trial), d, stats::gaussian(), seed = 3L
  )
  res <- koine::synthesise(pass, keep_fits = TRUE)

  if (koine::is_abstention(res)) {
    # koine's own battery declined this MET in this environment (its PSIS
    # reliability gate needs two surviving lenses). The companion must then
    # decline it the same way -- never manufacture a fourth opinion the oracle
    # itself will not stand behind.
    expect_identical(fk$status, "abstained")
    expect_identical(fk$extras$reason, res$reason)
    return(invisible(NULL))
  }

  expect_identical(fk$status, "contributed")
  got <- coef(fk)
  # self-naming: koine's tau_<grouping> tokens become flexyBayes's sd_<grouping>
  expect_setequal(
    names(got),
    c("(Intercept)", "x", "sigma", "sd_variety", "sd_trial")
  )
  ref <- colMeans(as.matrix(posterior::as_draws_matrix(
    koine::koine_opinion_draws(res, n_draws = 800L)
  )))
  expect_equal(unname(got[["(Intercept)"]]), unname(ref[["b_(Intercept)"]]),
               tolerance = 0.15)
  expect_equal(unname(got[["x"]]), unname(ref[["b_x"]]), tolerance = 0.15)
  expect_equal(unname(got[["sigma"]]), unname(ref[["sigma"]]),
               tolerance = 0.15)
  expect_equal(unname(got[["sd_variety"]]), unname(ref[["tau_variety"]]),
               tolerance = 0.15)
  expect_equal(unname(got[["sd_trial"]]), unname(ref[["tau_trial"]]),
               tolerance = 0.15)
})


test_that("emit_koine() still abstains beyond koine's two-grouping corner", {
  skip_if_not_installed("koine")
  fb3 <- structure(list(
    response = "y", family = "gaussian", link = "identity", intercept = TRUE,
    fixed_terms = list(list(type = "continuous", var = "x")),
    random_terms = list(
      list(type = "simple", var = "variety"),
      list(type = "simple", var = "trial"),
      list(type = "simple", var = "block")
    )
  ), class = "fb_terms")
  d <- .koine_met_data()
  d$block <- factor(rep_len(seq_len(4L), nrow(d)))
  fk <- emit_koine(fb3, d)
  expect_identical(fk$status, "abstained")
  expect_identical(fk$extras$reason, "feature_unsupported")
  expect_true(koine::is_abstention(fk$koine))
})


# ---------------------------------------------------------------- #
# (8) the outer wrapper is itself dispatchable as an orchestra      #
#     decline when koine abstained inside it (fleet refusal-contract #
#     closeout, ORCHESTRA_dev integration/refusal_contract.R)       #
# ---------------------------------------------------------------- #

# ORCHESTRA_dev's fleet gate (integration/test_refusal_contract.R) calls
# emit_koine() on a 3-random-term fb_terms and feeds the RETURNED object --
# what a caller actually holds -- to a producer-agnostic predicate that
# recognises a class ending in `_refusal` / `_abstention`, or the explicit
# `orchestra_refusal` marker (integration/refusal_contract.R:99,
# `is_orchestra_decline()`). Before this fix `emit_koine()`'s abstained exit
# always returned class `c("flexybayes_koine", "list")` -- the fact that
# `fk$koine` is itself a real, correctly-typed `koine_abstention` was invisible
# to that predicate because it only inspects the OUTER class. Re-implemented
# here (not imported from ORCHESTRA_dev) so this package's own test suite does
# not depend on a workspace outside it.
.is_orchestra_decline <- function(x) {
  cls <- class(x)
  any(cls == "orchestra_refusal") || any(grepl("_(refusal|abstention)$", cls))
}

test_that("an abstained emit_koine() result is a dispatchable orchestra decline", {
  skip_if_not_installed("koine")
  fb3 <- structure(list(
    response = "y", family = "gaussian", link = "identity", intercept = TRUE,
    fixed_terms = list(list(type = "continuous", var = "x")),
    random_terms = list(
      list(type = "simple", var = "variety"),
      list(type = "simple", var = "trial"),
      list(type = "simple", var = "block")
    )
  ), class = "fb_terms")
  d <- .koine_met_data()
  d$block <- factor(rep_len(seq_len(4L), nrow(d)))
  fk <- emit_koine(fb3, d)
  expect_identical(fk$status, "abstained")

  # the outer wrapper now carries the stamp, prepended ahead of the original
  # class (so existing `inherits(fk, "flexybayes_koine")` / `class(fk)[2] ==
  # "list"` consumers are unaffected)
  expect_identical(
    class(fk),
    c("quorum_abstention", "orchestra_refusal",
      "flexybayes_koine", "list")
  )
  expect_true(inherits(fk, "flexybayes_koine"))
  expect_true(is.list(fk))
  expect_true(.is_orchestra_decline(fk))
})

test_that("a contributed emit_koine() result carries no abstention stamp", {
  skip_if_not_installed("koine")
  skip_if_not_installed("posterior")
  d <- .koine_test_data()
  fb <- .koine_test_fb()
  fk <- emit_koine(fb, d, n_samples = 200L, seed = 7L)
  skip_if(fk$status != "contributed")
  expect_identical(class(fk), c("flexybayes_koine", "list"))
  expect_false(.is_orchestra_decline(fk))
})
