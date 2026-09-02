# test-independence.R -- the evidential-weight ledger.

.CAVEAT <- paste0(
  "Agreement between lenses fitted to the same data is agreement, not ",
  "corroboration of a shared data fact."
)

.mk_lens <- function(name, shares) {
  lens_from_draws(quorum_draws(list(beta = rnorm(8L))), name = name,
                  member = "quorum", shares = shares)
}

.hub_like <- c(sampler = "nuts", objective = "brms", priors = "hub",
               data_prep = "hub")
.simulator <- c(sampler = "ies", objective = "simulator",
                priors = "ensemble", data_prep = "pesto")

# ---- the three weight identities ---------------------------------------------

test_that("two lenses declaring the same four components carry no weight", {
  led <- quorum_independence(list(.mk_lens("a", .hub_like),
                                  .mk_lens("b", .hub_like)))
  expect_equal(led$shared[1L, 2L], 4L)
  expect_equal(led$shared[2L, 1L], 4L)
  expect_equal(led$weight[1L, 2L], 0)
  expect_equal(led$weight[2L, 1L], 0)
})

test_that("two lenses sharing nothing carry the full weight", {
  led <- quorum_independence(list(.mk_lens("a", .hub_like),
                                  .mk_lens("b", .simulator)))
  expect_equal(led$shared[1L, 2L], 0L)
  expect_equal(led$weight[1L, 2L], 1)
})

test_that("one shared component costs a quarter of the weight", {
  shares_one <- c(sampler = "nuts", objective = "inla", priors = "flat",
                  data_prep = "manual")
  led <- quorum_independence(list(.mk_lens("a", .hub_like),
                                  .mk_lens("b", shares_one)))
  expect_equal(led$shared[1L, 2L], 1L)
  expect_equal(led$weight[1L, 2L], 0.75)

  shares_two <- c(sampler = "nuts", objective = "brms", priors = "flat",
                  data_prep = "manual")
  led2 <- quorum_independence(list(.mk_lens("a", .hub_like),
                                   .mk_lens("b", shares_two)))
  expect_equal(led2$shared[1L, 2L], 2L)
  expect_equal(led2$weight[1L, 2L], 0.5)
})

test_that("two lenses declaring none share it with each other", {
  led <- quorum_independence(list(lens_status_quo(1, grid = c(0, 10),
                                                  name = "sq_a"),
                                  lens_status_quo(2, grid = c(0, 10),
                                                  name = "sq_b")))
  expect_equal(led$shared[1L, 2L], 4L)
  expect_equal(led$weight[1L, 2L], 0)

  # "none" is a value like any other: it never matches a named component.
  mixed <- quorum_independence(list(lens_status_quo(1, grid = c(0, 10)),
                                    .mk_lens("hub", .hub_like)))
  expect_equal(mixed$shared[1L, 2L], 0L)
  expect_equal(mixed$weight[1L, 2L], 1)
})

# ---- the shape of the ledger -------------------------------------------------

test_that("the ledger is square, named, and NA down the diagonal", {
  lenses <- list(.mk_lens("a", .hub_like), .mk_lens("b", .simulator),
                 .mk_lens("c", .hub_like))
  led <- quorum_independence(lenses)
  expect_s3_class(led, "quorum_independence")
  expect_equal(led$components,
               c("sampler", "objective", "priors", "data_prep"))
  expect_equal(dim(led$weight), c(3L, 3L))
  expect_equal(dimnames(led$weight), list(c("a", "b", "c"), c("a", "b", "c")))
  expect_equal(dimnames(led$shared), list(c("a", "b", "c"), c("a", "b", "c")))
  expect_true(is.integer(led$shared))
  expect_true(all(is.na(diag(led$shared))))
  expect_true(all(is.na(diag(led$weight))))
  expect_equal(led$weight["a", "c"], 0)
  expect_equal(led$weight["a", "b"], 1)
  expect_equal(led$weight, t(led$weight))
})

test_that("the ledger handles one lens and no lenses at all", {
  one <- quorum_independence(list(.mk_lens("only", .hub_like)))
  expect_equal(dim(one$weight), c(1L, 1L))
  expect_true(is.na(one$weight[1L, 1L]))

  none <- quorum_independence(list())
  expect_equal(dim(none$weight), c(0L, 0L))
  expect_equal(dim(none$shared), c(0L, 0L))
})

# ---- the data caveat ---------------------------------------------------------

test_that("the caveat stands unless data independence is established", {
  lenses <- list(.mk_lens("a", .hub_like), .mk_lens("b", .simulator))

  expect_equal(quorum_independence(lenses)$caveat, .CAVEAT)
  expect_true(is.na(quorum_independence(lenses)$data_independence))
  expect_equal(quorum_independence(lenses, data_independence = FALSE)$caveat,
               .CAVEAT)
  expect_equal(quorum_independence(lenses, data_independence = TRUE)$caveat,
               "")
  expect_true(
    quorum_independence(lenses, data_independence = TRUE)$data_independence
  )
})

test_that("the weights do not change with the data-independence flag", {
  lenses <- list(.mk_lens("a", .hub_like), .mk_lens("b", .simulator))
  expect_equal(quorum_independence(lenses, data_independence = TRUE)$weight,
               quorum_independence(lenses, data_independence = FALSE)$weight)
})

# ---- validation and display --------------------------------------------------

test_that("the ledger refuses anything that is not a list of lenses", {
  expect_error(quorum_independence("not a list"), "must be a list")
  expect_error(quorum_independence(list(.mk_lens("a", .hub_like), 42)),
               "must be a quorum_lens")
  expect_error(
    quorum_independence(list(.mk_lens("a", .hub_like)),
                        data_independence = "yes"),
    "single logical"
  )
  expect_error(
    quorum_independence(list(.mk_lens("a", .hub_like)),
                        data_independence = c(TRUE, FALSE)),
    "single logical"
  )
})

test_that("printing shows the rounded weights and the caveat", {
  lenses <- list(.mk_lens("a", .hub_like),
                 .mk_lens("b", c(sampler = "nuts", objective = "inla",
                                 priors = "flat", data_prep = "manual")))
  led <- quorum_independence(lenses)
  out <- capture.output(print(led))
  expect_true(any(grepl("quorum independence ledger", out)))
  expect_true(any(grepl("0.75", out, fixed = TRUE)))
  expect_true(any(grepl("corroboration of a shared data fact", out)))

  clean <- capture.output(
    print(quorum_independence(lenses, data_independence = TRUE))
  )
  expect_false(any(grepl("corroboration of a shared data fact", clean)))
  expect_true(any(grepl("data independence: TRUE", clean)))
})

test_that("print returns its argument invisibly", {
  led <- quorum_independence(list(.mk_lens("a", .hub_like)))
  capture.output(res <- expect_invisible(print(led)))
  expect_identical(res, led)
})
