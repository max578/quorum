# =============================================================================
# test-koine-slot.R -- the dormant koine fourth-opinion slot (R/koine_slot.R).
#
# koine is the synthesised fourth opinion on the orthogonal lens axis. In the
# lean-core split (2026-06-06) it moved out of flexyBayes core to this companion
# as an INFORMATIONAL surface: koine_status() reports its dormant state and the
# pure dormancy / mapper helpers behave correctly. It is no longer a core
# dispatchable backend (the core backend registry locks at load and resolves
# engines from the flexyBayes namespace), so the former core-dispatch /
# core-registry integration tests are retired -- they asserted behaviour the
# lean core no longer provides.
# =============================================================================

# ---------------------------------------------------------------- #
# (1) koine_status() returns the documented dormant shape           #
# ---------------------------------------------------------------- #

test_that("koine_status() returns the documented dormant shape", {
  ks <- koine_status()
  expect_type(ks, "list")
  expect_named(
    ks,
    c(
      "activated",
      "koine_installed",
      "builder_confirmed",
      "dormancy_reason",
      "activation_procedure"
    )
  )
  expect_false(ks$activated)
  expect_type(ks$koine_installed, "logical")
  expect_true(is.na(ks$builder_confirmed))
  expect_true(
    ks$dormancy_reason %in%
      c(
        "koine_not_installed",
        "slot_provisioned_not_activated",
        "koine_builder_unconfirmed"
      )
  )
  expect_type(ks$activation_procedure, "character")
  expect_true(length(ks$activation_procedure) >= 1L)
})


# ---------------------------------------------------------------- #
# (2) dormancy reason resolves from install + activation state      #
# ---------------------------------------------------------------- #

test_that("dormancy reason resolves correctly when koine is absent", {
  # koine is not a published package in this environment, so the reason
  # resolves to not-installed regardless of the activation boolean.
  if (nzchar(system.file(package = "koine"))) {
    testthat::skip("koine installed -- this test exercises the absent path")
  }
  withr::local_options(flexyBayes.koine_activated = TRUE)
  expect_identical(
    flexyBayesOrchestra:::.koine_dormancy_reason(),
    "koine_not_installed"
  )
  expect_identical(
    flexyBayesOrchestra:::.koine_slot_capability(),
    "koine_slot_dormant"
  )
})


# ---------------------------------------------------------------- #
# (3) the canonical-name mapper stub returns the dormant sentinel   #
# ---------------------------------------------------------------- #

test_that("the koine canonical mapper stub returns the scaffold-dormant sentinel", {
  out <- flexyBayesOrchestra:::.mapper_koine_stub(fit = NULL, fb_terms = NULL)
  expect_identical(out$source, "scaffold_dormant")
  expect_identical(out$map, character(0))
  expect_true(
    out$dormancy_reason %in%
      c(
        "koine_not_installed",
        "slot_provisioned_not_activated",
        "koine_builder_unconfirmed"
      )
  )
})
