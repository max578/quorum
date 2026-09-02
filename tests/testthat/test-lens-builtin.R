# test-lens-builtin.R -- the lenses quorum ships.

# ---- lens_status_quo ---------------------------------------------------------

test_that("lens_status_quo is one constant row across the whole grid", {
  grid <- c(0, 40, 80, 120)
  l <- lens_status_quo(value = 3.2, grid = grid)
  expect_true(S7::S7_inherits(l, quorum_lens))
  expect_equal(S7::prop(l, "name"), "status_quo")
  expect_equal(S7::prop(l, "member"), "quorum")
  expect_equal(S7::prop(l, "kind"), "response_curve")
  expect_equal(S7::prop(l, "expresses"), character(0))
  expect_equal(unname(S7::prop(l, "shares")), rep("none", 4L))
  expect_true(S7::prop(l, "scope")(list(anything = TRUE)))

  d <- S7::prop(l, "fit")(NULL, NULL)
  expect_equal(S7::prop(d, "kind"), "response_curve")
  expect_equal(dim(S7::prop(d, "draws")), c(1L, length(grid)))
  expect_equal(as.numeric(S7::prop(d, "draws")), rep(3.2, length(grid)))
  expect_equal(S7::prop(d, "grid"), grid)
  expect_equal(S7::prop(d, "n"), 1L)
  expect_equal(S7::prop(d, "source"), "status_quo")
})

test_that("lens_status_quo refuses a non-scalar value or an empty grid", {
  expect_error(lens_status_quo(c(1, 2), grid = c(0, 1)), "single finite")
  expect_error(lens_status_quo(NA_real_, grid = c(0, 1)), "single finite")
  expect_error(lens_status_quo("high", grid = c(0, 1)), "single finite")
  expect_error(lens_status_quo(1, grid = numeric(0)), "non-empty numeric")
  expect_error(lens_status_quo(1, grid = letters[1:3]), "non-empty numeric")
})

# ---- lens_mechanism ----------------------------------------------------------

.toy_ensemble <- function(n_members = 8L, n_out = 6L, prefix = "y",
                          dims = NULL) {
  set.seed(7L)
  outputs <- as.data.frame(matrix(
    rnorm(n_members * n_out, mean = 4, sd = 0.5), nrow = n_members,
    dimnames = list(NULL, paste0(prefix, seq_len(n_out)))
  ))
  fb_ensemble(
    params = data.frame(k = runif(n_members), m = runif(n_members)),
    outputs = outputs,
    output_dims = dims,
    provenance = list(source = "pesto")
  )
}

test_that("lens_mechanism reads the ensemble as curves over the grid", {
  ens <- .toy_ensemble()
  grid <- seq(0, 250, length.out = 6L)
  l <- lens_mechanism(ens, grid = grid)
  expect_true(S7::S7_inherits(l, quorum_lens))
  expect_equal(S7::prop(l, "name"), "mechanism")
  expect_equal(S7::prop(l, "member"), "PESTO")
  expect_equal(S7::prop(l, "kind"), "response_curve")
  expect_equal(S7::prop(l, "expresses"),
               c("linear", "plateau", "threshold", "nonmonotone"))
  expect_equal(S7::prop(l, "shares"),
               c(sampler = "ies", objective = "simulator",
                 priors = "ensemble", data_prep = "pesto"))

  d <- S7::prop(l, "fit")(NULL, NULL)
  expect_equal(dim(S7::prop(d, "draws")), c(8L, 6L))
  expect_equal(S7::prop(d, "n"), 8L)
  expect_equal(S7::prop(d, "grid"), grid)
  expect_equal(S7::prop(d, "source"), "pesto")
  expect_equal(S7::prop(d, "diagnostics")$n_members, 8L)
  expect_equal(S7::prop(d, "draws")[, 1L],
               as.numeric(ens$outputs[["y1"]]))
})

test_that("lens_mechanism names its member from the ensemble provenance", {
  ens <- fb_ensemble(params = data.frame(k = c(0.1, 0.2)),
                     outputs = data.frame(a = c(4, 5), b = c(5, 6)))
  l <- lens_mechanism(ens, grid = c(0, 50))
  expect_equal(S7::prop(l, "member"), "raw")
})

test_that("lens_mechanism declines a grid the outputs do not cover", {
  ens <- .toy_ensemble()
  short <- lens_mechanism(ens, grid = c(0, 50, 100))
  expect_true(is_quorum_abstention(short))
  expect_equal(short$reason, "grid_mismatch")
  expect_equal(short$scope, "lens")
  expect_match(short$detail, "6 column\\(s\\) for a grid of 3")

  long <- lens_mechanism(ens, grid = seq(0, 350, length.out = 8L))
  expect_true(is_quorum_abstention(long))
  expect_equal(long$reason, "grid_mismatch")
})

test_that("lens_mechanism declines outputs labelled with a different grid", {
  set.seed(11L)
  outputs <- as.data.frame(matrix(rnorm(6L), nrow = 2L,
                                  dimnames = list(NULL, c("0", "50", "100"))))
  ens <- fb_ensemble(params = data.frame(k = c(0.1, 0.2)), outputs = outputs)
  ok <- lens_mechanism(ens, grid = c(0, 50, 100))
  expect_true(S7::S7_inherits(ok, quorum_lens))

  wrong <- lens_mechanism(ens, grid = c(0, 60, 120))
  expect_true(is_quorum_abstention(wrong))
  expect_equal(wrong$reason, "grid_mismatch")
  expect_match(wrong$detail, "differ from the grid")
})

test_that("lens_mechanism selects one output set out of several", {
  dims <- data.frame(
    variable = rep(c("yield", "protein"), each = 6L),
    stringsAsFactors = FALSE
  )
  ens <- .toy_ensemble(n_out = 12L, dims = dims)
  yield_cols <- paste0("yield_", seq_len(6L))
  protein_cols <- paste0("protein_", seq_len(6L))
  colnames(ens$outputs) <- c(yield_cols, protein_cols)
  grid <- seq(0, 250, length.out = 6L)

  by_variable <- lens_mechanism(ens, grid = grid, output = "yield")
  expect_true(S7::S7_inherits(by_variable, quorum_lens))
  d <- S7::prop(by_variable, "fit")(NULL, NULL)
  expect_equal(dim(S7::prop(d, "draws")), c(8L, 6L))
  expect_equal(S7::prop(d, "diagnostics")$outputs, yield_cols)

  by_column <- lens_mechanism(ens, grid = grid, output = protein_cols)
  expect_equal(S7::prop(S7::prop(by_column, "fit")(NULL, NULL),
                        "diagnostics")$outputs, protein_cols)

  # With both sets present and no selection, the grid check catches it rather
  # than the two variables being pooled into one curve.
  pooled <- lens_mechanism(ens, grid = grid)
  expect_true(is_quorum_abstention(pooled))
  expect_equal(pooled$reason, "grid_mismatch")

  unmatched <- lens_mechanism(ens, grid = grid, output = "biomass")
  expect_true(is_quorum_abstention(unmatched))
  expect_equal(unmatched$reason, "grid_mismatch")
})

test_that("lens_mechanism declines a non-numeric response", {
  ens <- fb_ensemble(
    params = data.frame(k = c(0.1, 0.2)),
    outputs = data.frame(a = c(4, 5), b = c("low", "high"),
                         stringsAsFactors = FALSE)
  )
  out <- lens_mechanism(ens, grid = c(0, 50))
  expect_true(is_quorum_abstention(out))
  expect_equal(out$reason, "outputs_not_numeric")
})

test_that("lens_mechanism treats a malformed call as a programmer error", {
  ens <- .toy_ensemble()
  expect_error(lens_mechanism(ens, grid = numeric(0)), "non-empty numeric")
  expect_error(lens_mechanism(ens, grid = c(0, 1), output = 3),
               "NULL or a character vector")
  expect_error(lens_mechanism(structure(list(), class = "nothing"),
                              grid = c(0, 1)),
               "no coercer")
})

# ---- lens_from_fit -----------------------------------------------------------

test_that("lens_from_fit declines a class no adapter covers", {
  out <- lens_from_fit(structure(list(), class = "lm"))
  expect_true(is_quorum_abstention(out))
  expect_equal(out$reason, "unsupported_fit")
  expect_equal(out$scope, "lens")
  expect_match(out$detail, "no lens adapter")
})

test_that("lens_from_fit carries a koine decline through as a lens decline", {
  abstained <- structure(
    list(status = "abstained", draws = NULL,
         extras = list(status = "abstained", reason = "feature_unsupported",
                       detail = "three random terms, not all intercepts")),
    class = c("quorum_abstention", "orchestra_refusal", "flexybayes_koine",
              "list")
  )
  out <- lens_from_fit(abstained)
  expect_true(is_quorum_abstention(out))
  expect_equal(out$reason, "lens_abstained")
  expect_equal(out$nested_reason, "feature_unsupported")
  expect_match(out$nested_detail, "three random terms")
})

test_that("lens_from_fit treats a malformed draw count as a caller error", {
  expect_error(lens_from_fit(structure(list(), class = "lm"), n_samples = 0L),
               "positive number of draws")
  expect_error(lens_from_fit(structure(list(), class = "lm"),
                             n_samples = c(10L, 20L)),
               "positive number of draws")
})

test_that("lens_from_fit declines a fit whose engine hands over no draws", {
  broken <- structure(list(inla = NULL),
                      class = c("flexybayes_inla", "flexybayes", "list"))
  out <- lens_from_fit(broken, n_samples = 10L)
  expect_true(is_quorum_abstention(out))
  expect_true(out$reason %in% c("draws_unavailable", "draws_malformed"))
})

# A Gaussian random-intercept model small enough to fit in seconds: 60 rows,
# six groups, one covariate, a known residual SD of 1 and a known group SD of
# 0.8. It is the shared fixture for the two tests that need a real hub fit.
.toy_gaussian <- function() {
  set.seed(42L)
  n <- 60L
  g <- factor(rep(seq_len(6L), each = 10L))
  u <- rnorm(6L, mean = 0, sd = 0.8)
  x <- rnorm(n)
  y <- 1.5 + 0.7 * x + u[as.integer(g)] + rnorm(n, mean = 0, sd = 1)
  data.frame(y = y, x = x, g = g)
}

.toy_inla_fit <- function(toy) {
  suppressMessages(flexyBayes::flexybayes(
    y ~ x + (1 | g), data = toy, family = "gaussian", backend = "inla",
    verbose = FALSE
  ))
}

test_that("lens_from_fit canonicalises a real INLA fit's draw names", {
  skip_if_not_installed("INLA")
  toy <- .toy_gaussian()
  fit <- .toy_inla_fit(toy)
  expect_s3_class(fit, "flexybayes_inla")

  l <- lens_from_fit(fit, n_samples = 100L)
  expect_false(is_quorum_abstention(l))
  expect_true(S7::S7_inherits(l, quorum_lens))
  expect_equal(S7::prop(l, "name"), "inla")
  expect_equal(S7::prop(l, "member"), "flexyBayes")
  expect_equal(S7::prop(l, "kind"), "parameters")
  expect_equal(unname(S7::prop(l, "shares")[["objective"]]), "inla")
  expect_equal(unname(S7::prop(l, "shares")[["sampler"]]), "laplace")
  expect_equal(unname(S7::prop(l, "shares")[["priors"]]), "koine_scaled")
  expect_equal(unname(S7::prop(l, "shares")[["data_prep"]]), "hub")

  d <- S7::prop(l, "fit")(NULL, NULL)
  draws <- S7::prop(d, "draws")
  expect_type(draws, "list")
  expect_setequal(names(draws), c("(Intercept)", "x", "sigma", "sd_g"))
  expect_true(all(vapply(draws, is.numeric, logical(1L))))
  expect_equal(unique(vapply(draws, length, integer(1L))), 100L)
  expect_equal(S7::prop(d, "n"), 100L)
  expect_equal(S7::prop(d, "source"), "inla")

  # The backend's own nuisance nodes and its precision parameterisation are
  # both gone: the SD-scale tokens are what a second lens can be compared to.
  expect_false(any(grepl("^Predictor", names(draws))))
  expect_false(any(grepl("^Precision", names(draws))))
  expect_true(all(draws[["sigma"]] > 0))
  expect_true(all(draws[["sd_g"]] > 0))
  expect_gt(mean(draws[["x"]]), 0.3)
  expect_lt(mean(draws[["x"]]), 1.1)
})

# ---- lens_koine --------------------------------------------------------------

test_that("lens_koine declares the fourth opinion without fitting it", {
  l <- lens_koine()
  expect_true(S7::S7_inherits(l, quorum_lens))
  expect_equal(S7::prop(l, "name"), "koine")
  expect_equal(S7::prop(l, "member"), "koine")
  expect_equal(S7::prop(l, "kind"), "parameters")
  expect_equal(S7::prop(l, "expresses"), "linear")
  expect_equal(S7::prop(l, "shares"),
               c(sampler = "koine_stack", objective = "koine",
                 priors = "koine_scaled", data_prep = "quorum"))
  expect_equal(S7::prop(lens_koine(name = "fourth"), "name"), "fourth")
})

test_that("the parsed model is found wherever the hub fit carries it", {
  ir <- structure(list(response = "y"), class = "fb_terms")
  expect_identical(.resolve_fb_terms(ir), ir)
  expect_identical(.resolve_fb_terms(list(fb = ir, extras = list())), ir)
  expect_identical(
    .resolve_fb_terms(list(fb = NULL, extras = list(fb_terms = ir))), ir)
  expect_identical(
    .resolve_fb_terms(list(fb = ir, extras = list(fb_terms = "wrong"))), ir)
  expect_null(.resolve_fb_terms(list(fb = NULL, extras = list())))
  expect_null(.resolve_fb_terms(list(not = "fb_terms")))
  expect_error(.resolve_fb_terms("a formula"), "must be an fb_terms")
  expect_error(.resolve_fb_terms(42), "must be an fb_terms")
})

test_that("lens_koine declines a fit that carries no parsed model", {
  skip_if_not_installed("koine")
  l <- lens_koine()
  out <- S7::prop(l, "fit")(list(fb = NULL, extras = list()),
                            data.frame(y = 1))
  expect_true(is_quorum_abstention(out))
  expect_equal(out$reason, "spec_missing")
  expect_equal(out$scope, "lens")
  expect_error(S7::prop(l, "fit")("y ~ x", data.frame(y = 1)),
               "must be an fb_terms")
})

test_that("lens_koine speaks the same parameter tokens as a hub lens", {
  skip_if_not_installed("INLA")
  skip_if_not_installed("koine")
  skip_if_not_installed("posterior")
  # koine synthesises a whole battery of fits before it has an opinion, which
  # costs about two minutes on the smallest model it will accept -- an order of
  # magnitude more than every other test in this file put together. It is
  # opt-in rather than dropped, because the token agreement it checks is the
  # whole point of the canonicalisation.
  skip_if(!nzchar(Sys.getenv("QUORUM_SLOW_TESTS")),
          "set QUORUM_SLOW_TESTS to run the koine battery")
  toy <- .toy_gaussian()
  fit <- .toy_inla_fit(toy)

  hub <- lens_from_fit(fit, n_samples = 100L)
  expect_false(is_quorum_abstention(hub))

  l <- lens_koine(n_samples = 500L, seed = 1L)
  d <- S7::prop(l, "fit")(fit, toy)
  expect_false(is_quorum_abstention(d))
  expect_equal(S7::prop(d, "kind"), "parameters")
  expect_equal(S7::prop(d, "source"), "koine")
  expect_equal(S7::prop(d, "n"), 500L)

  # The point of the canonicalisation: two lenses on different axes hand the
  # comparison the same component names, so they can be compared by name.
  expect_setequal(names(S7::prop(d, "draws")),
                  names(S7::prop(S7::prop(hub, "fit")(NULL, NULL), "draws")))
  expect_setequal(names(S7::prop(d, "draws")),
                  c("(Intercept)", "x", "sigma", "sd_g"))
  expect_true(all(S7::prop(d, "draws")[["sigma"]] > 0))
})
