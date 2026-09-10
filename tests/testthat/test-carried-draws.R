# test-carried-draws.R -- the quorum -> decideR seam.
#
# A consensus verdict used to leave the package with no payload a decision
# layer could read: the contributions table went out as `params` and the
# lenses' posteriors were discarded once agreement had been computed. Any
# consumer asking the manifest for draws got nothing, and decideR's reader
# failed on the shape rather than declining. The carried lens's posterior now
# rides in `outputs`, hashed with the rest, and only when the quorum actually
# issued a number.

.shares_of2 <- function(tag) {
  c(sampler = paste0("s_", tag), objective = paste0("o_", tag),
    priors = paste0("p_", tag), data_prep = paste0("d_", tag))
}

.fixed_lens2 <- function(name, draws, tag = name) {
  force(draws)
  quorum_lens(name = name, member = "test",
              fit = function(spec, data, ...) draws,
              shares = .shares_of2(tag), expresses = "linear",
              kind = S7::prop(draws, "kind"))
}

.par_draws2 <- function(mu = 0, n = 400L, seed = 1L) {
  set.seed(seed)
  quorum_draws(list(`(Intercept)` = stats::rnorm(n, mu),
                    sigma = stats::rgamma(n, 9, 3)),
               source = "test")
}

test_that("a concordant verdict carries the carried lens's draws", {
  d_local <- .par_draws2()
  v <- quorum(list(.fixed_lens2("one", d_local), .fixed_lens2("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  expect_identical(v@status, "concordant")
  expect_identical(v@resolution$carried_lens, "one")

  m <- v@carried_draws
  expect_true(is.matrix(m))
  expect_true(is.numeric(m))
  expect_identical(nrow(m), 400L)
  expect_identical(ncol(m), 2L)
  # the column names prove the named list was read, not blindly coerced
  expect_identical(colnames(m), c("(Intercept)", "sigma"))
  expect_identical(m[, "sigma"], S7::prop(d_local, "draws")$sigma)
})

test_that("the manifest emits those draws in outputs, and hashes them", {
  d_local <- .par_draws2()
  v <- quorum(list(.fixed_lens2("one", d_local), .fixed_lens2("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  m <- v@manifest
  expect_identical(m@inferential_target, "consensus")
  expect_true(is.matrix(m@outputs))
  expect_identical(dim(m@outputs), dim(v@carried_draws))

  # tamper with the payload: the hash must move
  tampered <- m@outputs
  tampered[1L, 1L] <- tampered[1L, 1L] + 1
  h_before <- m@data_hash
  h_after <- orchestraManifest::manifest_data_hash(
    m@params, tampered, NULL, NULL, NA_integer_, m@summary
  )
  expect_false(identical(h_before, h_after))
})

test_that("a verdict that issued no number carries no draws", {
  # one lens against a policy demanding two: no quorum, so no number and,
  # therefore, nothing downstream may price
  d_local <- .par_draws2()
  v <- quorum(list(.fixed_lens2("one", d_local)),
              policy = quorum_policy(c("one", "two"), min_lenses = 2L))
  expect_identical(v@status, "no_quorum")
  expect_null(v@carried_draws)
  expect_null(v@manifest@outputs)
})

test_that("the draws extractor refuses shapes it cannot reduce", {
  f <- get(".draws_matrix", envir = asNamespace("quorum"))
  expect_null(f(NULL))
  expect_null(f(list()))
  expect_null(f(list(a = "not numeric")))
  expect_null(f(matrix(numeric(0L), nrow = 0L, ncol = 0L)))
  expect_true(is.matrix(f(list(a = 1:3, b = 4:6))))
})
