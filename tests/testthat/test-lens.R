# test-lens.R -- the lens contract, the registry, and the draws wrapper.

# ---- quorum_draws ------------------------------------------------------------

test_that("quorum_draws accepts a named list of equal-length numerics", {
  d <- quorum_draws(list(a = rnorm(30L), b = rnorm(30L)), source = "toy")
  expect_equal(S7::prop(d, "kind"), "parameters")
  expect_equal(S7::prop(d, "n"), 30L)
  expect_equal(S7::prop(d, "source"), "toy")
  expect_null(S7::prop(d, "grid"))
  expect_equal(names(S7::prop(d, "draws")), c("a", "b"))
})

test_that("quorum_draws refuses malformed parameter draws", {
  expect_error(quorum_draws(list(rnorm(5L))), "named list")
  expect_error(quorum_draws(list()), "named list")
  expect_error(quorum_draws(list(a = letters)), "named list")
  expect_error(quorum_draws(list(a = rnorm(5L), b = rnorm(6L))),
               "same length")
})

test_that("quorum_draws validates a response curve against its grid", {
  m <- matrix(rnorm(12L), nrow = 3L, ncol = 4L)
  d <- quorum_draws(m, kind = "response_curve", grid = c(0, 50, 100, 150))
  expect_equal(S7::prop(d, "kind"), "response_curve")
  expect_equal(S7::prop(d, "n"), 3L)
  expect_equal(S7::prop(d, "grid"), c(0, 50, 100, 150))

  expect_error(quorum_draws(list(a = rnorm(4L)), kind = "response_curve",
                            grid = 1:4),
               "numeric matrix")
  expect_error(quorum_draws(m, kind = "response_curve"), "one entry per")
  expect_error(quorum_draws(m, kind = "response_curve", grid = c(0, 50)),
               "one entry per")
})

test_that("quorum_draws refuses an unknown kind", {
  expect_error(quorum_draws(list(a = rnorm(3L)), kind = "curve"))
})

# ---- quorum_lens -------------------------------------------------------------

.shares_ok <- c(sampler = "nuts", objective = "brms", priors = "hub",
                data_prep = "hub")

test_that("quorum_lens keeps the declarations it is given", {
  l <- quorum_lens(name = "brms", member = "flexyBayes",
                   fit = function(spec, data, ...) NULL,
                   shares = .shares_ok, expresses = c("linear", "linear"))
  expect_equal(S7::prop(l, "name"), "brms")
  expect_equal(S7::prop(l, "member"), "flexyBayes")
  expect_equal(S7::prop(l, "kind"), "parameters")
  expect_equal(S7::prop(l, "expresses"), "linear")
  expect_true(S7::prop(l, "scope")(NULL))
})

test_that("quorum_lens orders shares into the ledger's component order", {
  scrambled <- c(priors = "hub", data_prep = "hub", objective = "brms",
                 sampler = "nuts", extra = "ignored")
  l <- quorum_lens(name = "s", member = "m",
                   fit = function(spec, data, ...) NULL, shares = scrambled)
  expect_equal(names(S7::prop(l, "shares")),
               c("sampler", "objective", "priors", "data_prep"))
  expect_equal(unname(S7::prop(l, "shares")[["sampler"]]), "nuts")
})

test_that("quorum_lens refuses an incomplete declaration", {
  f <- function(spec, data, ...) NULL
  expect_error(quorum_lens(name = "", member = "m", fit = f,
                           shares = .shares_ok), "non-empty string")
  expect_error(quorum_lens(name = "s", member = c("a", "b"), fit = f,
                           shares = .shares_ok), "non-empty string")
  expect_error(quorum_lens(name = "s", member = "m", fit = "not a function",
                           shares = .shares_ok), "must be a function")
  expect_error(quorum_lens(name = "s", member = "m", fit = f,
                           shares = c("nuts", "brms", "hub", "hub")),
               "named character vector")
  expect_error(quorum_lens(name = "s", member = "m", fit = f,
                           shares = .shares_ok[1:3]),
               "named character vector")
  expect_error(quorum_lens(name = "s", member = "m", fit = f,
                           shares = .shares_ok, expresses = "sigmoid"),
               "must be a subset")
  expect_error(quorum_lens(name = "s", member = "m", fit = f,
                           shares = .shares_ok, scope = "always"),
               "must be a function")
})

test_that("quorum_lens allows a lens that expresses no shape", {
  l <- quorum_lens(name = "constant", member = "quorum",
                   fit = function(spec, data, ...) NULL,
                   shares = .shares_ok, expresses = character(0))
  expect_equal(S7::prop(l, "expresses"), character(0))
})

test_that("lens() is the quorum_lens constructor under another name", {
  l <- lens(name = "alias", member = "m",
            fit = function(spec, data, ...) NULL, shares = .shares_ok)
  expect_true(S7::S7_inherits(l, quorum_lens))
  expect_equal(S7::prop(l, "name"), "alias")
})

# ---- lens_from_draws ---------------------------------------------------------

test_that("lens_from_draws takes its kind from the draws and returns them", {
  m <- matrix(rnorm(10L), nrow = 2L, ncol = 5L)
  d <- quorum_draws(m, kind = "response_curve", grid = seq(0, 200, by = 50))
  l <- lens_from_draws(d, name = "curve", member = "quorum",
                       shares = .shares_ok, expresses = "plateau")
  expect_equal(S7::prop(l, "kind"), "response_curve")
  expect_identical(S7::prop(l, "fit")(NULL, NULL), d)
  expect_identical(S7::prop(l, "fit")(list(spec = 1), data.frame(y = 1)), d)
  expect_true(S7::prop(l, "scope")(NULL))
})

test_that("lens_from_draws refuses anything that is not quorum_draws", {
  expect_error(lens_from_draws(list(a = rnorm(3L)), name = "n", member = "m",
                               shares = .shares_ok),
               "must be a quorum_draws")
})

test_that("lens_from_draws carries a caller-supplied scope", {
  d <- quorum_draws(list(a = rnorm(4L)))
  out_of_scope <- function(spec) {
    quorum_abstention("out_of_scope", "binomial only", scope = "lens")
  }
  l <- lens_from_draws(d, name = "narrow", member = "m",
                       shares = .shares_ok, scope = out_of_scope)
  expect_true(is_quorum_abstention(S7::prop(l, "scope")(NULL)))
})

# ---- the registry ------------------------------------------------------------

.demo_lens <- function(name = "demo", member = "quorum") {
  lens_from_draws(quorum_draws(list(beta = rnorm(10L))), name = name,
                  member = member, shares = .shares_ok)
}

test_that("an empty registry lists zero lenses with the full column set", {
  clear_lenses()
  out <- list_lenses()
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
  expect_equal(names(out),
               c("name", "member", "kind", "expresses", "sampler",
                 "objective", "priors", "data_prep"))
  expect_null(get_lens("nothing_here"))
})

test_that("a registered lens round-trips through the registry", {
  clear_lenses()
  l <- .demo_lens()
  expect_invisible(register_lens(l))
  expect_identical(get_lens("demo"), l)
  out <- list_lenses()
  expect_equal(nrow(out), 1L)
  expect_equal(out$name, "demo")
  expect_equal(out$member, "quorum")
  expect_equal(out$kind, "parameters")
  expect_equal(out$expresses, "linear")
  expect_equal(out$sampler, "nuts")
  expect_equal(out$objective, "brms")
  expect_equal(out$priors, "hub")
  expect_equal(out$data_prep, "hub")
  clear_lenses()
})

test_that("registering under an existing name replaces rather than adds", {
  clear_lenses()
  register_lens(.demo_lens(member = "first"))
  register_lens(.demo_lens(member = "second"))
  out <- list_lenses()
  expect_equal(nrow(out), 1L)
  expect_equal(out$member, "second")
  expect_equal(S7::prop(get_lens("demo"), "member"), "second")
  clear_lenses()
})

test_that("list_lenses orders by name and collapses the declared shapes", {
  clear_lenses()
  register_lens(.demo_lens(name = "zulu"))
  register_lens(.demo_lens(name = "alpha"))
  register_lens(lens_status_quo(1, grid = c(0, 10), name = "mike"))
  out <- list_lenses()
  expect_equal(out$name, c("alpha", "mike", "zulu"))
  expect_equal(out$expresses[out$name == "mike"], "")
  expect_equal(out$sampler[out$name == "mike"], "none")
  clear_lenses()
})

test_that("the registry refuses a non-lens and a malformed name", {
  clear_lenses()
  expect_error(register_lens(list(name = "fake")), "must be a quorum_lens")
  expect_error(register_lens(quorum_draws(list(a = 1))),
               "must be a quorum_lens")
  expect_error(get_lens(c("a", "b")), "non-empty string")
  expect_error(get_lens(""), "non-empty string")
})

test_that("clear_lenses empties the registry and returns invisibly", {
  clear_lenses()
  register_lens(.demo_lens())
  expect_equal(nrow(list_lenses()), 1L)
  expect_invisible(clear_lenses())
  expect_equal(nrow(list_lenses()), 0L)
})
