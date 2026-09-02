# =============================================================================
# test-utils.R -- internal helpers the rest of the package leans on
# =============================================================================

test_that("%||% is defined inside the package, not borrowed from base", {
  # base R only gained %||% at 4.4.0 (r-devel NEWS); DESCRIPTION floors
  # R (>= 4.1.0), and NAMESPACE carries no import/importFrom directive that
  # could bring it in from a dependency. Nine call sites across R/ use it
  # unqualified, so it must resolve inside this package's own namespace,
  # not merely happen to resolve via base on the R actually running the
  # tests.
  expect_true(
    exists("%||%", envir = asNamespace("quorum"), inherits = FALSE)
  )
})

test_that("%||% returns the left side when non-NULL, else the right", {
  op <- get("%||%", envir = asNamespace("quorum"), inherits = FALSE)
  expect_identical(op(5, 2), 5)
  expect_identical(op(NULL, 2), 2)
  expect_identical(op(NULL, NULL), NULL)
})
