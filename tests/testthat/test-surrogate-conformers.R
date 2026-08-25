# =============================================================================
# test-surrogate-conformers.R -- C7 conformers from constellation siblings.
#
# Pins that PESTO's GP and kernR's CME register through the C7 surrogate
# registry, predict on the standardised design (the predict.fb_surrogate fix),
# recover a known surface, and honour the distribution-preserving `<o>_sd`
# contract. Gated on the sibling member being installed.
# =============================================================================

.mk_conformer_train <- function(n = 150L, noise = 0.05) {
  set.seed(20260602L)
  a <- stats::runif(n, -2, 2)
  b <- stats::runif(n, -2, 2)
  fb_ensemble(
    params = data.frame(a = a, b = b),
    outputs = data.frame(y = sin(a) + 0.5 * b^2 + stats::rnorm(n, 0, noise)),
    provenance = list(source = "raw")
  )
}

.conformer_truth <- function(a, b) sin(a) + 0.5 * b^2

# ---- PESTO GP ---------------------------------------------------------------

test_that("register_pesto_surrogates() makes method = 'gp' available", {
  skip_if_not_installed("PESTO")
  expect_identical(register_pesto_surrogates(), "gp")
  expect_true("gp" %in% flexyBayesOrchestra:::.surrogate_methods())
})

test_that("the PESTO GP conformer recovers a surface with per-output mean+sd", {
  skip_if_not_installed("PESTO")
  register_pesto_surrogates()
  e <- .mk_conformer_train()
  s <- fit_surrogate(e, method = "gp")
  expect_s3_class(s, "fb_surrogate")
  expect_identical(s$method, "gp")

  set.seed(5L)
  grid <- data.frame(
    a = stats::runif(120, -1.6, 1.6),
    b = stats::runif(120, -1.6, 1.6)
  )
  pr <- predict(s, grid)
  expect_true(all(c("y_mean", "y_sd") %in% colnames(pr)))
  expect_identical(nrow(pr), 120L)
  expect_true(all(pr$y_sd > 0))
  truth <- .conformer_truth(grid$a, grid$b)
  expect_lt(sqrt(mean((pr$y_mean - truth)^2)), 0.30)
})

# ---- kernR CME --------------------------------------------------------------

test_that("register_kernr_surrogates() makes method = 'cme' available", {
  skip_if_not_installed("kernR")
  expect_identical(register_kernr_surrogates(), "cme")
  expect_true("cme" %in% flexyBayesOrchestra:::.surrogate_methods())
})

test_that("the kernR CME conformer recovers a surface with honest sd", {
  skip_if_not_installed("kernR")
  register_kernr_surrogates()
  e <- .mk_conformer_train(noise = 0.10)
  # fixed ridge keeps fit_cme() fast + deterministic (no LOO-CV per call)
  s <- fit_surrogate(e, method = "cme", lambda = 1e-2)
  expect_s3_class(s, "fb_surrogate")
  expect_identical(s$method, "cme")

  set.seed(6L)
  grid <- data.frame(
    a = stats::runif(150, -1.6, 1.6),
    b = stats::runif(150, -1.6, 1.6)
  )
  pr <- predict(s, grid)
  expect_true(all(c("y_mean", "y_sd") %in% colnames(pr)))
  expect_true(all(is.finite(pr$y_sd)))
  expect_true(all(pr$y_sd > 0))
  truth <- .conformer_truth(grid$a, grid$b)
  expect_lt(sqrt(mean((pr$y_mean - truth)^2)), 0.35)
  # the smoother predictive interval covers a healthy majority of held-out pts
  z <- (truth - pr$y_mean) / pr$y_sd
  expect_gt(mean(abs(z) < 1.96), 0.5)
})

test_that("the CME conformer emulates multiple outputs independently", {
  skip_if_not_installed("kernR")
  register_kernr_surrogates()
  set.seed(3L)
  n <- 150L
  a <- stats::runif(n, -2, 2)
  b <- stats::runif(n, -2, 2)
  e <- fb_ensemble(
    params = data.frame(a = a, b = b),
    outputs = data.frame(
      y1 = sin(a) + stats::rnorm(n, 0, 0.05),
      y2 = b^2 + stats::rnorm(n, 0, 0.05)
    ),
    provenance = list(source = "raw")
  )
  s <- fit_surrogate(e, method = "cme", lambda = 1e-2)
  expect_identical(s$output_names, c("y1", "y2"))
  pr <- predict(s, data.frame(a = 1.0, b = 1.2))
  expect_true(all(
    c("y1_mean", "y1_sd", "y2_mean", "y2_sd") %in% colnames(pr)
  ))
  expect_equal(pr$y1_mean, sin(1.0), tolerance = 0.2)
  expect_equal(pr$y2_mean, 1.2^2, tolerance = 0.3)
})

# ---- error surfaces ---------------------------------------------------------

test_that("registration is idempotent and conformer predict is deterministic", {
  skip_if_not_installed("PESTO")
  register_pesto_surrogates()
  register_pesto_surrogates() # second call must not error
  e <- .mk_conformer_train()
  s1 <- fit_surrogate(e, method = "gp")
  s2 <- fit_surrogate(e, method = "gp")
  nd <- data.frame(a = c(0, 0.5), b = c(-0.5, 1.0))
  expect_equal(predict(s1, nd), predict(s2, nd))
})

# ---- FBO-01: the CME conformer must not be confident off-design -------------
#
# ORACLE (independent of the code under test, two sources):
#   (a) the closed-form generating surface `.conformer_truth()` -- the analytic
#       value the emulator would have to reproduce at the probe point;
#   (b) the analytic limit of a kernel linear smoother: with a bounded, decaying
#       kernel every k(x*, x_i) -> 0 as x* leaves the design, so the weights
#       w(x*) -> 0, the mean w(x*)'y -> 0, and ||w(x*)||^2 -> 0, which drives
#       sigma^2 (1 + ||w||^2) DOWN to its in-design floor sigma^2. The reported
#       sd therefore shrinks toward its in-design size exactly where the mean is
#       worthless (Wasserman, "All of Nonparametric Statistics", 2006, ch. 5,
#       linear smoothers; Hastie, Tibshirani & Friedman, ESL 2nd ed., sec 5.4).
# Neither expected value is read off this package's output.

test_that("the CME conformer declines off-design instead of guessing", {
  skip_if_not_installed("kernR")
  register_kernr_surrogates()
  e <- .mk_conformer_train(noise = 0.05)
  s <- fit_surrogate(e, method = "cme", lambda = 1e-2)

  # A point six design half-widths outside the [-2, 2]^2 design.
  far <- data.frame(a = 12, b = 12)
  expect_gt(abs(.conformer_truth(12, 12)), 50) # the truth is nowhere near 0
  cnd <- tryCatch(predict(s, far), condition = function(cnd) cnd)
  expect_s3_class(cnd, "fb_surrogate_cme_abstention")
  # the constellation's shared decline predicate keys on this suffix
  expect_true(any(grepl("_abstention$", class(cnd))))
  expect_lt(cnd$weight_mass, cnd$weight_mass_floor)
  expect_true(all(is.finite(cnd$mass_design_range)))
})

test_that("the CME gate leaves in-design prediction untouched", {
  skip_if_not_installed("kernR")
  register_kernr_surrogates()
  e <- .mk_conformer_train(noise = 0.05)
  s <- fit_surrogate(e, method = "cme", lambda = 1e-2)
  set.seed(11L)
  grid <- data.frame(
    a = stats::runif(120, -1.6, 1.6),
    b = stats::runif(120, -1.6, 1.6)
  )
  pr <- predict(s, grid)
  expect_identical(nrow(pr), 120L)
  expect_true(all(is.finite(pr$y_sd)))
  truth <- .conformer_truth(grid$a, grid$b)
  expect_lt(sqrt(mean((pr$y_mean - truth)^2)), 0.35)
})

test_that("the CME out-of-support floor is tunable and can be disabled", {
  skip_if_not_installed("kernR")
  register_kernr_surrogates()
  e <- .mk_conformer_train(noise = 0.05)
  far <- data.frame(a = 12, b = 12)

  # floor 0 disables the gate: the ungated answer is recoverable, and it is the
  # fabrication the gate exists to stop -- a near-zero mean against a truth
  # above 50, carried at an in-design-sized sd.
  open_s <- fit_surrogate(e, method = "cme", lambda = 1e-2, weight_mass_frac = 0)
  pr <- predict(open_s, far)
  expect_lt(abs(pr$y_mean), 1e-3)
  expect_gt(abs(.conformer_truth(12, 12) - pr$y_mean), 50)

  # a per-call floor override reinstates the refusal on that same fit
  expect_error(
    predict(open_s, far, weight_mass_floor = 0.1),
    class = "fb_surrogate_cme_abstention"
  )
})
