test_that("package loads", {
  expect_true(requireNamespace("quorum", quietly = TRUE))
})
