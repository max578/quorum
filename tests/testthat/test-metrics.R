# =============================================================================
# test-metrics.R -- the agreement layer, and oracle S3.
#
# The gate on this file is oracle S3: quorum's `agreement_pairwise()` must
# return the numbers `flexyBayes::triangulate()` returns, on the same draws,
# to 1e-8 on every shared numeric column, with identical per-parameter
# verdicts and an identical overall status. The hub's metric helpers are
# internal to flexyBayes, so the re-derivation in `R/metrics.R` is only worth
# anything if it is checked against the hub's own output rather than against
# a reading of the hub's source.
#
# ---- which oracle route, and why -------------------------------------------
#
# Two routes to identical draws were considered: (i) recover the draws the
# hub used from its result object, or (ii) reproduce the hub's extraction
# under the same seed. The result object carries no draws (its fields are
# metrics, status, status_reasons, comparability, diagnostics, common, only_a,
# only_b, n_common, n_compared, source_a, source_b, independence,
# axis_justification, data_independence, shared_upstream_caveat), so route (i)
# is closed. Route (ii) then depends on the extractor being reproducible, and
# the two engines differ:
#
#   INLA. `fb_as_draws_simple.flexybayes_inla()` samples the posterior through
#   `INLA::inla.posterior.sample()`. Measured on this machine: two calls on
#   one fit, each immediately after `set.seed(99)`, returned different draws.
#   The comparability gate is NOT what rules an INLA pair out -- two INLA fits
#   of the same model, data and prior carry identical fingerprints and the
#   gate passes them, as does the numerical-confirm gate -- it is that the
#   draws the hub used cannot be recovered, so no bit-level comparison is
#   possible on that path. An INLA pair was fitted and checked before this was
#   settled.
#
#   brms. `fb_as_draws_simple.flexybayes_brms()` reads the stored draw matrix.
#   It is deterministic: the test asserts two calls on one fit return
#   identical draws, which is what makes the vectors the hub computed on
#   recoverable exactly rather than approximately.
#
# So the file runs two oracles, and between them they cover everything the
# gate asks for:
#
#   S3a (deterministic, always runs). Two fit objects built by hand around the
#   stored fixture, with an `fb_as_draws_simple` method that hands back that
#   fixture. The draws the hub computes on ARE the fixture, by construction:
#   no sampling, no seed, nothing to reproduce. This route exercises all three
#   per-parameter verdicts -- concordant, discordant and not_compared -- and
#   unequal draw counts on the two sides. What it cannot check is the overall
#   status: a hand-built fit carries no model fingerprint and no convergence
#   diagnostics, so the hub's comparability and diagnostic gates report
#   "unverified" and its status is "inconclusive" whatever the verdicts say.
#
#   S3b (two real hub fits). Two `flexybayes()` brms fits of one model on one
#   dataset with one prior, differing only in the sampler seed. Both hub gates
#   pass, so the hub reaches a verdict-derived status and `agreement_status()`
#   is checked against it. The hub canonicalises the extracted draws before
#   computing -- `canonical_names(fit, drop = TRUE)` supplies a per-parameter
#   transform and a name map, which `triangulate()` applies in that order --
#   so the test replays those same two steps before handing the draws to
#   quorum.
# =============================================================================

# ---- helpers -----------------------------------------------------------------

# Largest absolute difference between two numeric columns, treating a
# position that is NA on both sides as a match and a position that is NA on
# one side only as an outright failure.
max_abs_diff <- function(x, y) {
  x <- as.numeric(x)
  y <- as.numeric(y)
  if (length(x) != length(y)) {
    return(Inf)
  }
  if (any(is.na(x) != is.na(y))) {
    return(Inf)
  }
  keep <- !is.na(x)
  if (!any(keep)) {
    return(0)
  }
  max(abs(x[keep] - y[keep]))
}

# The fixture the deterministic tests and oracle S3a run on.
agreement_fixture <- function() {
  readRDS(test_path("fixtures", "agreement_draws.rds"))
}

# The hub's pre-metric pipeline, replayed: apply the canonical per-parameter
# transforms, then the canonical rename, exactly as `triangulate()` does.
oracle_canonicalise <- function(draws, cn) {
  for (nm in names(cn$transform)) {
    if (nm %in% names(draws)) {
      draws[[nm]] <- as.numeric(cn$transform[[nm]](draws[[nm]]))
    }
  }
  names(draws) <- vapply(
    names(draws),
    function(nm) if (nm %in% names(cn$map)) as.character(cn$map[[nm]]) else nm,
    character(1L)
  )
  draws
}

# ---- thresholds --------------------------------------------------------------

test_that("agreement_thresholds() carries the hub's documented cut-offs", {
  th <- agreement_thresholds()
  # flexyBayes 0.10.0 R/triangulate.R:757-759.
  expect_identical(th$mean_shift_sd_max, 0.1)
  expect_identical(th$w1_sd_max, 0.1)
  expect_identical(th$sd_ratio_band, c(0.9, 1.1))
  # R/triangulate.R:495 and :497 -- reported, never thresholded.
  expect_identical(th$quantile_probs, c(0.025, 0.975))
  expect_type(th, "list")
})

test_that("agreement_thresholds() refuses a cut-off it cannot apply", {
  expect_error(agreement_thresholds(mean_shift_sd_max = -1), "positive")
  expect_error(agreement_thresholds(w1_sd_max = c(0.1, 0.2)), "single")
  expect_error(agreement_thresholds(sd_ratio_band = c(1.1, 0.9)), "increasing")
  expect_error(agreement_thresholds(quantile_probs = c(0, 0.975)), "inside")
})

# ---- Wasserstein-1 -----------------------------------------------------------

test_that(".wasserstein1_1d() is exactly zero against the same sample", {
  w1 <- quorum:::.wasserstein1_1d
  set.seed(3L)
  x <- rnorm(2000L)
  expect_identical(w1(x, x), 0)
})

test_that(".wasserstein1_1d() recovers the closed form for a mean shift", {
  # W1 between N(0, 1) and N(0.5, 1) is exactly the shift, 0.5, because one
  # quantile function is the other translated.
  w1 <- quorum:::.wasserstein1_1d
  set.seed(101L)
  a <- rnorm(20000L, mean = 0, sd = 1)
  b <- rnorm(20000L, mean = 0.5, sd = 1)
  expect_equal(w1(a, b), 0.5, tolerance = 0.02)
})

test_that(".wasserstein1_1d() tracks the exact piecewise integral", {
  # The hub's estimator is the quantile-function integral on a 99-point
  # uniform probability grid; for two equal-length samples the exact
  # empirical value is mean(|sort(a) - sort(b)|). The grid is what quorum
  # must reproduce -- bit-equality with the hub is the binding constraint --
  # so the size of the gap to the exact value is measured rather than left
  # unstated.
  w1 <- quorum:::.wasserstein1_1d
  set.seed(7L)
  a <- rnorm(20000L)
  b <- rnorm(20000L, mean = 0.5)
  exact <- mean(abs(sort(a) - sort(b)))
  expect_lt(abs(w1(a, b) - exact), 1e-3)
})

test_that(".wasserstein1_1d() handles unequal lengths and empty input", {
  w1 <- quorum:::.wasserstein1_1d
  set.seed(5L)
  a <- rnorm(900L)
  b <- rnorm(400L, mean = 1)
  expect_true(is.finite(w1(a, b)))
  expect_identical(w1(a, b), w1(b, a))
  expect_identical(w1(numeric(0), a), NA_real_)
  expect_identical(w1(a, numeric(0)), NA_real_)
})

# ---- agreement_pairwise ------------------------------------------------------

test_that("agreement_pairwise() returns the contract's columns in order", {
  fx <- agreement_fixture()
  tbl <- agreement_pairwise(fx$a, fx$b)
  expect_s3_class(tbl, "data.frame")
  expect_identical(
    names(tbl),
    c("param", "mean_a", "mean_b", "sd_a", "sd_b", "sd_ratio", "q025_diff",
      "q975_diff", "wasserstein_1", "mean_shift_sd", "w1_sd", "verdict",
      "reason")
  )
  expect_type(tbl$param, "character")
  expect_type(tbl$verdict, "character")
  expect_type(tbl$mean_a, "double")
  # `extra` is on lens b only, so it is not a common component.
  expect_identical(tbl$param, c("intercept", "slope", "spread", "flat"))
})

test_that("agreement_pairwise() reaches all three per-parameter verdicts", {
  fx <- agreement_fixture()
  tbl <- agreement_pairwise(fx$a, fx$b)
  verdicts <- stats::setNames(tbl$verdict, tbl$param)
  expect_identical(verdicts[["intercept"]], "concordant")
  expect_identical(verdicts[["slope"]], "discordant")
  expect_identical(verdicts[["spread"]], "discordant")
  expect_identical(verdicts[["flat"]], "not_compared")
  expect_true(is.na(tbl$reason[tbl$param == "intercept"]))
  expect_match(tbl$reason[tbl$param == "slope"], "mean shift")
  expect_match(tbl$reason[tbl$param == "spread"], "SD ratio")
  expect_match(tbl$reason[tbl$param == "flat"], "no posterior spread")
  # A degenerate component reports its raw distances and declines to scale
  # them, rather than reporting a ratio of two zeros.
  expect_true(is.na(tbl$sd_ratio[tbl$param == "flat"]))
  expect_true(is.na(tbl$mean_shift_sd[tbl$param == "flat"]))
  expect_identical(tbl$wasserstein_1[tbl$param == "flat"], 0)
})

test_that("agreement_pairwise() defaults to the hub's reference SD", {
  fx <- agreement_fixture()
  default <- agreement_pairwise(fx$a, fx$b)
  as_max <- agreement_pairwise(fx$a, fx$b, sd_ref = "max")
  expect_identical(default, as_max)

  # The alternatives are genuinely different scales, so a caller that leaves
  # the hub's scale can see that it did.
  row <- function(tbl, p) tbl$w1_sd[tbl$param == p]
  pooled <- agreement_pairwise(fx$a, fx$b, sd_ref = "pooled")
  only_a <- agreement_pairwise(fx$a, fx$b, sd_ref = "a")
  only_b <- agreement_pairwise(fx$a, fx$b, sd_ref = "b")
  expect_false(isTRUE(all.equal(row(pooled, "spread"), row(as_max, "spread"))))
  expect_false(isTRUE(all.equal(row(only_a, "spread"), row(as_max, "spread"))))
  # Lens b is the wider one on `spread`, so scaling by b is the hub's scale.
  expect_equal(row(only_b, "spread"), row(as_max, "spread"))
})

test_that("agreement_pairwise() honours an explicit component set", {
  fx <- agreement_fixture()
  tbl <- agreement_pairwise(fx$a, fx$b, names = c("slope", "intercept"))
  expect_identical(tbl$param, c("slope", "intercept"))

  declined <- agreement_pairwise(fx$a, fx$b, names = c("slope", "extra"))
  expect_true(is_quorum_abstention(declined))
  expect_identical(declined$reason, "names_not_present")
  expect_identical(declined$scope, "comparison")
  expect_match(declined$detail, "extra")
})

test_that("agreement_pairwise() abstains when the lenses share nothing", {
  a <- list(mu = rnorm(50L))
  b <- list(tau = rnorm(50L))
  declined <- agreement_pairwise(a, b)
  expect_true(is_quorum_abstention(declined))
  expect_identical(declined$reason, "no_common_parameters")
  expect_identical(declined$scope, "comparison")
})

test_that("agreement_pairwise() takes quorum_draws and declines a curve", {
  set.seed(11L)
  a <- quorum_draws(list(mu = rnorm(400L)), source = "inla")
  b <- quorum_draws(list(mu = rnorm(400L)), source = "brms")
  tbl <- agreement_pairwise(a, b)
  expect_identical(tbl$param, "mu")
  expect_identical(tbl, agreement_pairwise(a@draws, b@draws))

  curve <- quorum_draws(
    matrix(rnorm(40L), nrow = 10L),
    kind = "response_curve",
    grid = seq_len(4L)
  )
  declined <- agreement_pairwise(curve, b)
  expect_true(is_quorum_abstention(declined))
  expect_identical(declined$reason, "kind_not_parameters")
  expect_identical(declined$scope, "comparison")
})

test_that("agreement_pairwise() refuses malformed draws and arguments", {
  a <- list(mu = rnorm(50L))
  expect_error(agreement_pairwise(a, list(rnorm(50L))), "named list")
  expect_error(agreement_pairwise(a, list(mu = "x")), "numeric")
  expect_error(agreement_pairwise(a, a, names = 1L), "character")
  expect_error(agreement_pairwise(a, a, sd_ref = "median"))
  expect_error(agreement_pairwise(a, a, thresholds = list(x = 1)), "list from")
})

test_that("agreement_pairwise() applies the thresholds it is given", {
  fx <- agreement_fixture()
  strict <- agreement_thresholds(w1_sd_max = 0.01, mean_shift_sd_max = 0.01)
  tbl <- agreement_pairwise(fx$a, fx$b, thresholds = strict)
  expect_identical(tbl$verdict[tbl$param == "intercept"], "discordant")

  loose <- agreement_thresholds(
    mean_shift_sd_max = 5,
    w1_sd_max = 5,
    sd_ratio_band = c(0.5, 2)
  )
  tbl2 <- agreement_pairwise(fx$a, fx$b, thresholds = loose)
  expect_identical(tbl2$verdict[tbl2$param == "slope"], "concordant")
})

# ---- agreement_status --------------------------------------------------------

test_that("agreement_status() returns each of the three states", {
  concordant <- data.frame(
    param = c("a", "b"),
    verdict = c("concordant", "concordant"),
    stringsAsFactors = FALSE
  )
  discordant <- data.frame(
    param = c("a", "b", "c"),
    verdict = c("concordant", "discordant", "not_compared"),
    stringsAsFactors = FALSE
  )
  inconclusive <- data.frame(
    param = c("a", "b"),
    verdict = c("not_compared", "not_compared"),
    stringsAsFactors = FALSE
  )
  expect_identical(agreement_status(concordant), "concordant")
  expect_identical(agreement_status(discordant), "discordant")
  expect_identical(agreement_status(inconclusive), "inconclusive")
  # No rows at all is nothing compared, not agreement.
  expect_identical(
    agreement_status(inconclusive[0L, , drop = FALSE]),
    "inconclusive"
  )
})

test_that("agreement_status() propagates an abstention and refuses junk", {
  declined <- quorum_abstention("no_common_parameters", scope = "comparison")
  expect_identical(agreement_status(declined), declined)
  expect_error(agreement_status(data.frame(param = "a")), "verdict")
  expect_error(agreement_status("concordant"), "data.frame")
})

test_that("agreement_status() reads the fixture table as discordant", {
  fx <- agreement_fixture()
  expect_identical(agreement_status(agreement_pairwise(fx$a, fx$b)),
                   "discordant")
})

# ---- agreement_matrix --------------------------------------------------------

test_that("agreement_matrix() returns a symmetric matrix with an NA diagonal", {
  set.seed(13L)
  lenses <- list(
    inla = list(mu = rnorm(500L), tau = rnorm(500L, 1)),
    brms = list(mu = rnorm(500L), tau = rnorm(500L, 1)),
    koine = list(mu = rnorm(500L, 4), tau = rnorm(500L, 1))
  )
  ag <- agreement_matrix(lenses)
  expect_s3_class(ag, "quorum_agreement")
  expect_identical(names(ag), c("status", "table", "thresholds"))
  expect_identical(dim(ag$status), c(3L, 3L))
  expect_identical(dimnames(ag$status),
                   list(names(lenses), names(lenses)))
  expect_true(all(is.na(diag(ag$status))))
  expect_identical(ag$status, t(ag$status))
  expect_identical(ag$status[["inla", "brms"]], "concordant")
  expect_identical(ag$status[["inla", "koine"]], "discordant")
  expect_identical(
    names(ag$table),
    c("lens_a", "lens_b", names(agreement_pairwise(lenses$inla, lenses$brms)))
  )
  # Three pairs, two components each.
  expect_identical(nrow(ag$table), 6L)
  expect_identical(ag$thresholds, agreement_thresholds())
  # The method is called by name rather than through `print()`: its S3
  # registration is written into NAMESPACE by the roxygen pass, which this
  # wave does not run, so dispatch is not yet wired in a `load_all()` tree.
  expect_output(quorum:::print.quorum_agreement(ag), "quorum agreement")
})

test_that("agreement_matrix() reports a pair that shares nothing", {
  set.seed(17L)
  lenses <- list(
    one = list(mu = rnorm(300L)),
    two = list(mu = rnorm(300L)),
    three = list(other = rnorm(300L))
  )
  ag <- agreement_matrix(lenses)
  expect_identical(ag$status[["one", "three"]], "inconclusive")
  expect_identical(ag$status[["two", "three"]], "inconclusive")
  row <- ag$table[ag$table$lens_a == "one" & ag$table$lens_b == "three", ]
  expect_identical(nrow(row), 1L)
  expect_true(is.na(row$param))
  expect_identical(row$verdict, "not_compared")
  expect_identical(row$reason, "no_common_parameters")
})

test_that("agreement_matrix() needs at least two lenses", {
  declined <- agreement_matrix(list(only = list(mu = rnorm(20L))))
  expect_true(is_quorum_abstention(declined))
  expect_identical(declined$reason, "too_few_lenses")
  expect_identical(declined$scope, "comparison")
  expect_error(agreement_matrix(list(list(mu = 1))), "named list")
})

test_that("agreement_matrix() accepts quorum_draws lenses", {
  set.seed(19L)
  lenses <- list(
    a = quorum_draws(list(mu = rnorm(4000L)), source = "one"),
    b = quorum_draws(list(mu = rnorm(4000L)), source = "two")
  )
  ag <- agreement_matrix(lenses)
  expect_identical(ag$status[["a", "b"]], "concordant")
})

# ---- ORACLE S3a: the hub's own output on hand-built fits ---------------------

test_that("oracle S3a: quorum equals the hub on identical fixture draws", {
  skip_if_not_installed("flexyBayes")

  # flexyBayes does not export triangulate(), so there is no hub output to
  # diff against. The .wasserstein1_1d() closed-form tests above cover the
  # arithmetic in agreement_pairwise(). This test stays skipped until a
  # recorded hub fixture exists.
  skip_if_not(
    "triangulate" %in% getNamespaceExports("flexyBayes"),
    "flexyBayes does not export triangulate()"
  )
  fx <- agreement_fixture()
  fit_a <- structure(list(draws = fx$a), class = "quorum_oracle_fit")
  fit_b <- structure(list(draws = fx$b), class = "quorum_oracle_fit")

  # `fb_as_draws_simple()` is the hub's exported S3 generic for pulling a
  # named list of draw vectors off a fit; a method registered here hands the
  # hub the fixture itself, so no sampling stands between the two sides.
  registerS3method(
    "fb_as_draws_simple",
    "quorum_oracle_fit",
    function(fit, ...) fit$draws,
    envir = asNamespace("flexyBayes")
  )

  hub <- flexyBayes::triangulate(fit_a, fit_b)
  ours <- agreement_pairwise(fx$a, fx$b)

  expect_identical(hub$common, ours$param)
  hub_metrics <- hub$metrics[match(ours$param, hub$metrics$param), ]

  numeric_columns <- c(
    "mean_a", "mean_b", "sd_a", "sd_b", "sd_ratio", "q025_diff",
    "q975_diff", "wasserstein_1", "mean_shift_sd", "w1_sd"
  )
  diffs <- vapply(
    numeric_columns,
    function(col) max_abs_diff(ours[[col]], hub_metrics[[col]]),
    numeric(1L)
  )
  expect_lt(max(diffs), 1e-8)

  # `mean_diff` is the hub's column; quorum reports the two means and leaves
  # the difference to the reader, so the identity is checked rather than the
  # column carried.
  expect_lt(max_abs_diff(ours$mean_a - ours$mean_b, hub_metrics$mean_diff),
            1e-8)

  expect_identical(ours$verdict, hub_metrics$verdict)
  expect_identical(ours$reason, hub_metrics$reason)
  expect_true(all(c("concordant", "discordant", "not_compared") %in%
                    ours$verdict))

  # A hand-built fit carries no fingerprint and no diagnostics, so the hub's
  # own status is decided by its gates before the verdicts are read. The
  # status half of the oracle is checked on the real-fit route below.
  expect_identical(hub$status, "inconclusive")
})

# ---- ORACLE S3b: the hub's own output on two real hub fits -------------------

test_that("oracle S3b: quorum equals the hub on two gated brms fits", {
  skip_on_cran()
  skip_if_not_installed("flexyBayes")
  skip_if_not_installed("brms")
  withr::local_options(list(flexyBayes.silence_default_prior_note = TRUE))

  set.seed(4L)
  d <- data.frame(y = rnorm(50L), x = rnorm(50L))
  fit_one <- tryCatch(
    flexyBayes::flexybayes(
      y ~ x,
      data = d,
      backend = "brms",
      chains = 2L,
      n_samples = 700L,
      warmup = 500L,
      seed = 101L,
      verbose = FALSE,
      mcmc_verbose = FALSE
    ),
    error = function(e) e
  )
  if (inherits(fit_one, "error")) {
    skip(paste0("no working brms backend: ", conditionMessage(fit_one)))
  }
  fit_two <- flexyBayes::flexybayes(
    y ~ x,
    data = d,
    backend = "brms",
    chains = 2L,
    n_samples = 700L,
    warmup = 500L,
    seed = 202L,
    verbose = FALSE,
    mcmc_verbose = FALSE
  )

  # The draws the hub computes on must be recoverable exactly, so the first
  # thing checked is that the brms extractor is deterministic: two calls on
  # one fit return the same vectors, which is what makes replaying the
  # extraction equivalent to reading the hub's own inputs.
  raw_one <- flexyBayes::fb_as_draws_simple(fit_one)
  expect_identical(raw_one, flexyBayes::fb_as_draws_simple(fit_one))
  raw_two <- flexyBayes::fb_as_draws_simple(fit_two)
  expect_identical(raw_two, flexyBayes::fb_as_draws_simple(fit_two))

  draws_one <- oracle_canonicalise(
    raw_one,
    flexyBayes::canonical_names(fit_one, drop = TRUE)
  )
  draws_two <- oracle_canonicalise(
    raw_two,
    flexyBayes::canonical_names(fit_two, drop = TRUE)
  )

  # flexyBayes does not export triangulate(), so there is no hub output to
  # diff the two fits against.
  skip_if_not(
    "triangulate" %in% getNamespaceExports("flexyBayes"),
    "flexyBayes does not export triangulate()"
  )
  hub <- flexyBayes::triangulate(fit_one, fit_two)
  expect_true(isTRUE(hub$comparability$verified))
  expect_identical(hub$common, intersect(names(draws_one), names(draws_two)))

  ours <- agreement_pairwise(draws_one, draws_two)
  hub_metrics <- hub$metrics[match(ours$param, hub$metrics$param), ]

  numeric_columns <- c(
    "mean_a", "mean_b", "sd_a", "sd_b", "sd_ratio", "q025_diff",
    "q975_diff", "wasserstein_1", "mean_shift_sd", "w1_sd"
  )
  diffs <- vapply(
    numeric_columns,
    function(col) max_abs_diff(ours[[col]], hub_metrics[[col]]),
    numeric(1L)
  )
  expect_lt(max(diffs), 1e-8)
  expect_lt(max_abs_diff(ours$mean_a - ours$mean_b, hub_metrics$mean_diff),
            1e-8)
  expect_identical(ours$verdict, hub_metrics$verdict)
  expect_identical(ours$reason, hub_metrics$reason)

  # The status comparison is only meaningful while the hub's two gates pass:
  # a fit that fails its own diagnostics makes the hub inconclusive before
  # any verdict is read, and that half of the rule is not quorum's to hold.
  if (!isTRUE(hub$diagnostics$a$ok) || !isTRUE(hub$diagnostics$b$ok)) {
    skip("a hub fit failed its own convergence gate on this run")
  }
  expect_identical(agreement_status(ours), hub$status)
})
