# test-lens-tmb.R -- oracles for the TMB lens.
#
# The independent oracle is the hub itself: the same random-intercept model
# fitted by flexyBayes on INLA, read back through the hub's own canonical-name
# map, is compared with the lens's NUTS draws over glmmTMB's TMB objective.
# Nothing in the comparison is produced by the lens. The second oracle is
# internal but equally mechanical: the same objective sampled with the random
# effects integrated out by the Laplace approximation and sampled jointly must
# agree on the fixed effects.
#
# The toys are deliberately small (n = 60, six groups) so the whole file stays
# inside a few seconds of sampling; every engine is reached through
# skip_if_not_installed(), so a machine without glmmTMB, tmbstan or INLA skips
# rather than fails.

# ---- fixtures ----------------------------------------------------------------

tmb_toy_gaussian <- function() {
  set.seed(20260902)
  n <- 60L
  n_groups <- 6L
  g <- factor(rep(seq_len(n_groups), each = n / n_groups))
  u <- stats::rnorm(n_groups, 0, 0.8)
  y <- 2 + u[as.integer(g)] + stats::rnorm(n, 0, 1)
  data.frame(y = y, g = g)
}

tmb_toy_poisson <- function() {
  set.seed(20260902)
  n <- 60L
  n_groups <- 6L
  g <- factor(rep(seq_len(n_groups), each = n / n_groups))
  x <- stats::rnorm(n)
  u <- stats::rnorm(n_groups, 0, 0.5)
  eta <- 1 + 0.4 * x + u[as.integer(g)]
  data.frame(count = stats::rpois(n, exp(eta)), x = x, g = g)
}

# Sampling is the expensive part of this file, so each fitted object is built
# once and reused across the tests that read it.
tmb_cache <- new.env(parent = emptyenv())

tmb_memo <- function(key, value) {
  if (is.null(tmb_cache[[key]])) {
    assign(key, value, envir = tmb_cache)
  }
  tmb_cache[[key]]
}

tmb_skip_engines <- function(hub = FALSE) {
  testthat::skip_if_not_installed("glmmTMB")
  testthat::skip_if_not_installed("tmbstan")
  if (hub) {
    testthat::skip_if_not_installed("INLA")
    testthat::skip_if_not_installed("withr")
  }
}

# The hub's INLA draws on the hub's own canonical names: the value transforms
# key on the backend-native names and run before any rename, which is the
# order triangulate() uses, so a precision draw is never renamed to an SD
# without being converted first.
tmb_hub_draws <- function(data, n_samples = 2000L) {
  withr::local_options(list(flexyBayes.silence_default_prior_note = TRUE))
  fit <- flexyBayes::flexybayes(
    y ~ 1 + (1 | g),
    data = data, backend = "inla", verbose = FALSE, seed = 1L
  )
  set.seed(11)
  raw <- flexyBayes::fb_as_draws_simple(fit, n_samples = n_samples)
  canonical <- flexyBayes::canonical_names(fit, drop = TRUE)
  for (native in names(canonical$transform)) {
    if (!is.null(raw[[native]])) {
      raw[[native]] <- canonical$transform[[native]](raw[[native]])
    }
  }
  out <- list()
  for (native in names(raw)) {
    if (native %in% names(canonical$map)) {
      out[[as.character(canonical$map[[native]])]] <- raw[[native]]
    }
  }
  attr(out, "summary") <- flexyBayes::tidy(fit)
  out
}

tmb_gaussian_draws <- function(laplace) {
  tmb_memo(
    paste0("gaussian_laplace_", laplace),
    lens_tmb(laplace = laplace, chains = 2L, iter = 2000L)@fit(
      y ~ 1 + (1 | g), tmb_toy_gaussian()
    )
  )
}

# ---- construction ------------------------------------------------------------

test_that("lens_tmb() constructs without either engine present", {
  lens <- lens_tmb()
  expect_true(S7::S7_inherits(lens, quorum_lens))
  expect_identical(lens@name, "tmb")
  expect_identical(lens@member, "glmmTMB")
  expect_identical(lens@kind, "parameters")
  expect_identical(lens@expresses, "linear")
  expect_identical(
    lens@shares,
    c(
      sampler = "stan_nuts", objective = "tmb", priors = "hub_matched",
      data_prep = "quorum"
    )
  )
  expect_identical(lens_tmb(priors = "flat")@shares[["priors"]], "flat")
  expect_identical(lens_tmb(name = "tmb_nuts")@name, "tmb_nuts")
})

test_that("lens_tmb() refuses malformed constructor arguments", {
  expect_error(lens_tmb(laplace = NA), "must be TRUE or FALSE")
  expect_error(lens_tmb(chains = 0L), "positive integer")
  expect_error(lens_tmb(n_draws = "many"), "positive integer")
  expect_error(lens_tmb(seed = c(1L, 2L)), "single finite number")
  expect_error(lens_tmb(name = ""), "non-empty string")
  expect_error(lens_tmb(priors = "vague"), "should be one of")
})

# ---- scope and typed declines ------------------------------------------------

test_that("the scope gate accepts one random intercept and declines the rest", {
  lens <- lens_tmb()
  expect_true(lens@scope(y ~ 1 + (1 | g)))
  expect_true(lens@scope(y ~ x + (1 | g)))

  slope <- lens@scope(y ~ x + (1 + x | g))
  expect_true(is_quorum_abstention(slope))
  expect_identical(slope$reason, "out_of_scope")
  expect_identical(slope$scope, "lens")

  two_groups <- lens@scope(y ~ x + (1 | g) + (1 | h))
  expect_true(is_quorum_abstention(two_groups))
  expect_identical(two_groups$reason, "out_of_scope")

  no_group <- lens@scope(y ~ x)
  expect_true(is_quorum_abstention(no_group))
  expect_identical(no_group$reason, "out_of_scope")

  not_a_spec <- lens@scope("y ~ 1 + (1 | g)")
  expect_true(is_quorum_abstention(not_a_spec))
  expect_identical(not_a_spec$reason, "out_of_scope")
})

test_that("an unsupported family and a random slope abstain at fit time", {
  tmb_skip_engines()
  data <- tmb_toy_gaussian()

  unsupported <- lens_tmb(family = "gamma")@fit(y ~ 1 + (1 | g), data)
  expect_true(is_quorum_abstention(unsupported))
  expect_identical(unsupported$reason, "family_unsupported")
  expect_identical(unsupported$scope, "lens")
  expect_match(unsupported$detail, "nbinom2")

  data$x <- stats::rnorm(nrow(data))
  slope <- lens_tmb()@fit(y ~ x + (1 + x | g), data)
  expect_true(is_quorum_abstention(slope))
  expect_identical(slope$reason, "out_of_scope")

  no_frame <- lens_tmb()@fit(y ~ 1 + (1 | g), as.list(data))
  expect_true(is_quorum_abstention(no_frame))
  expect_identical(no_frame$reason, "out_of_scope")
})

# ---- oracle (a): the hub's INLA fit on the same model ------------------------

test_that("the lens agrees with the hub's INLA fit on the same model", {
  tmb_skip_engines(hub = TRUE)
  data <- tmb_toy_gaussian()
  lens_draws <- tmb_gaussian_draws(TRUE)
  expect_true(S7::S7_inherits(lens_draws, quorum_draws))

  hub <- tmb_hub_draws(data)
  expect_true(all(c("(Intercept)", "sd_g") %in% names(hub)))
  # The lens is self-naming on the hub's canonical tokens: every component it
  # reports is a component the hub reports, under the same name.
  expect_true(all(names(lens_draws@draws) %in% names(hub)))
  expect_identical(names(lens_draws@draws), c("(Intercept)", "sd_g"))

  # Compared with the hub's fit summary, not its draws: INLA's posterior
  # sampling ignores R's seed, so a mean of draws differs from run to run.
  hub_fixed <- attr(hub, "summary")
  hub_fixed <- hub_fixed[hub_fixed$term == "(Intercept)", ]
  lens_intercept <- lens_draws@draws[["(Intercept)"]]
  expect_lt(
    abs(mean(lens_intercept) - hub_fixed$estimate),
    0.1 * hub_fixed$std.error
  )

  hub_sd <- stats::median(hub[["sd_g"]])
  lens_sd <- stats::median(lens_draws@draws[["sd_g"]])
  expect_lt(abs(lens_sd - hub_sd) / hub_sd, 0.25)

  expect_identical(lens_draws@source, "glmmTMB+tmbstan")
  expect_identical(lens_draws@n, 2000L)
  expect_true(lens_draws@diagnostics$rhat < 1.05)
  expect_identical(lens_draws@diagnostics$n_divergent, 0L)
  expect_true(lens_draws@diagnostics$laplace)
})

test_that("the hub's fb_terms IR routes to the same model as the formula", {
  tmb_skip_engines(hub = TRUE)
  withr::local_options(list(flexyBayes.silence_default_prior_note = TRUE))
  data <- tmb_toy_gaussian()
  hub_fit <- flexyBayes::flexybayes(
    y ~ 1 + (1 | g),
    data = data, backend = "inla", verbose = FALSE, seed = 1L
  )
  ir <- if (is.null(hub_fit$fb)) hub_fit$extras$fb_terms else hub_fit$fb
  expect_s3_class(ir, "fb_terms")
  from_ir <- lens_tmb(chains = 2L, iter = 600L)@fit(ir, data)
  expect_true(S7::S7_inherits(from_ir, quorum_draws))
  expect_identical(names(from_ir@draws), c("(Intercept)", "sd_g"))
  expect_identical(
    deparse(from_ir@diagnostics$formula),
    deparse(y ~ (1 | g))
  )
  expect_identical(from_ir@diagnostics$family, "gaussian")
  expect_identical(from_ir@diagnostics$group, "g")
})

# ---- oracle (b): the same objective sampled two ways -------------------------

test_that("laplace = TRUE and laplace = FALSE agree on the fixed effects", {
  tmb_skip_engines()
  marginal <- tmb_gaussian_draws(TRUE)@draws[["(Intercept)"]]
  joint <- tmb_gaussian_draws(FALSE)@draws[["(Intercept)"]]
  expect_lt(
    abs(mean(marginal) - mean(joint)),
    0.1 * min(stats::sd(marginal), stats::sd(joint))
  )
  expect_false(tmb_gaussian_draws(FALSE)@diagnostics$laplace)
})

# ---- oracle (c): a count family ----------------------------------------------

test_that("the Poisson family fits and names its draws canonically", {
  tmb_skip_engines()
  data <- tmb_toy_poisson()
  lens <- lens_tmb(family = "poisson", chains = 2L, iter = 2000L)
  draws <- lens@fit(count ~ x + (1 | g), data)
  expect_true(S7::S7_inherits(draws, quorum_draws))
  expect_identical(names(draws@draws), c("(Intercept)", "x", "sd_g"))
  expect_identical(draws@n, 2000L)
  expect_true(all(vapply(draws@draws, function(d) all(is.finite(d)),
                         logical(1L))))
  expect_true(all(draws@draws[["sd_g"]] > 0))
  # The log-link branch of the hub's uniform bound is 3, not 5 * sd(y).
  expect_identical(draws@diagnostics$priors$hub_bound, 3)
  expect_identical(draws@diagnostics$family, "poisson")
})

# ---- oracle (e): the Laplace point in the diagnostics ------------------------

test_that("the diagnostics carry glmmTMB's own point estimates", {
  tmb_skip_engines()
  data <- tmb_toy_gaussian()
  lens_draws <- tmb_gaussian_draws(TRUE)
  point <- lens_draws@diagnostics$laplace_point

  refit <- glmmTMB::glmmTMB(
    lens_draws@diagnostics$formula,
    data = data, family = stats::gaussian(),
    priors = lens_draws@diagnostics$priors$rows
  )
  expected <- glmmTMB::fixef(refit)$cond
  expect_equal(point[names(expected)], expected, tolerance = 1e-8)
  expect_equal(
    unname(point[["sd_g"]]),
    as.numeric(attr(glmmTMB::VarCorr(refit)$cond$g, "stddev")),
    tolerance = 1e-8
  )
  expect_identical(names(point), names(lens_draws@draws))
})

# ---- the prior plan ----------------------------------------------------------

test_that("the hub prior is carried on the SD scale and the gaps are named", {
  tmb_skip_engines()
  data <- tmb_toy_gaussian()
  plan <- tmb_gaussian_draws(TRUE)@diagnostics$priors
  expect_identical(plan$mode, "hub")
  expect_identical(plan$declared, "hub_matched")
  expect_identical(plan$rows$class, "ranef_sd")
  expect_identical(plan$rows$coef, "g")
  # Shape 2 is the flat-on-SD gamma; the bound is the hub's 5 * sd(y).
  expect_match(plan$rows$prior, ", 2\\)$")
  expect_equal(plan$hub_bound, 5 * stats::sd(data$y), tolerance = 1e-10)
  expect_true(any(grepl("residual SD", plan$unmatched)))
  expect_true(any(grepl("upper bound", plan$unmatched)))
})

test_that("priors = \"flat\" fits under glmmTMB's defaults and says so", {
  tmb_skip_engines()
  flat <- lens_tmb(
    family = "poisson", priors = "flat", chains = 2L, iter = 1000L
  )@fit(count ~ x + (1 | g), tmb_toy_poisson())
  expect_true(S7::S7_inherits(flat, quorum_draws))
  expect_identical(flat@diagnostics$priors$declared, "flat")
  expect_null(flat@diagnostics$priors$rows)
  expect_true(is.na(flat@diagnostics$priors$hub_bound))
  expect_identical(names(flat@draws), c("(Intercept)", "x", "sd_g"))
})
