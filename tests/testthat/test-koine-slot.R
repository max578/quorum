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
  withr::local_options(flexyBayesOrchestra.koine_activated = FALSE)
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
