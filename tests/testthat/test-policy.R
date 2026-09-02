# test-policy.R -- contributions, policies and the resolution cascade.

.contrib_of <- function(...) contributions(...)

test_that("a lens contribution is one row with the seam's columns", {
  row_local <- lens_contribution("mechanism", grounded = TRUE,
                                 abstained = FALSE, action = 120,
                                 reason = NA_character_,
                                 grounding = "grounded")
  expect_s3_class(row_local, "data.frame")
  expect_identical(nrow(row_local), 1L)
  expect_identical(names(row_local),
                   c("lens", "grounded", "abstained", "action", "reason",
                     "grounding", "decisive"))
  expect_identical(row_local$lens, "mechanism")
  expect_true(row_local$decisive)
  expect_identical(row_local$action, 120)
})

test_that("decisive defaults to the complement of abstained", {
  expect_false(lens_contribution("m", TRUE, TRUE)$decisive)
  expect_true(lens_contribution("m", TRUE, FALSE)$decisive)
  expect_false(lens_contribution("m", TRUE, FALSE, decisive = FALSE)$decisive)
})

test_that("a malformed contribution is refused at its own line", {
  expect_error(lens_contribution("", TRUE, FALSE), "non-empty string")
  expect_error(lens_contribution(c("a", "b"), TRUE, FALSE), "non-empty string")
  expect_error(lens_contribution("m", "yes", FALSE), "single logical")
  expect_error(lens_contribution("m", TRUE, FALSE, action = c(1, 2)),
               "single number")
  expect_error(lens_contribution("m", TRUE, FALSE, reason = 1),
               "single string")
})

test_that("contributions binds rows and fills columns a part omits", {
  tab_local <- .contrib_of(
    cbind(lens_contribution("mechanism", TRUE, FALSE, action = 120),
          data.frame(producer_abstained = FALSE)),
    lens_contribution("statistical", TRUE, FALSE, action = 30)
  )
  expect_identical(nrow(tab_local), 2L)
  expect_true("producer_abstained" %in% names(tab_local))
  expect_true(is.na(tab_local$producer_abstained[2L]))
})

test_that("contributions accepts a list of rows and refuses non-frames", {
  tab_local <- contributions(list(lens_contribution("a", TRUE, FALSE),
                                  lens_contribution("b", TRUE, FALSE)))
  expect_identical(nrow(tab_local), 2L)
  expect_error(contributions(1L), "data frame")
  expect_error(contributions(), "at least one")
})

test_that("a policy declares an order and refuses a malformed one", {
  pol <- quorum_policy(c("mechanism", "statistical"), status_quo = 60)
  expect_identical(pol@order, c("mechanism", "statistical"))
  expect_identical(pol@min_lenses, 2L)
  expect_identical(pol@status_quo, 60)
  expect_null(pol@thresholds)
  expect_error(quorum_policy(character(0L)), "non-empty character")
  expect_error(quorum_policy(c("a", "a")), "not name a lens twice")
  expect_error(quorum_policy("a", min_lenses = 0L), "at least 1")
  expect_error(quorum_policy("a", status_quo = c(1, 2)), "single number")
  expect_error(quorum_policy("a", independence_min = NA), "single number")
})

test_that("the cascade carries the first grounded and decisive lens", {
  tab_local <- .contrib_of(
    lens_contribution("mechanism", TRUE, FALSE, action = 120),
    lens_contribution("statistical", TRUE, FALSE, action = 30)
  )
  res <- quorum_resolve(tab_local,
                        quorum_policy(c("mechanism", "statistical"),
                                      status_quo = 60))
  expect_identical(res$carried_lens, "mechanism")
  expect_identical(res$verdict, "decide")
  expect_identical(res$action, 120)
  expect_true(res$tier_mechanism)
  expect_false(res$tier_statistical)
  expect_false(res$tier_status_quo)
  expect_false(res$tier_abstain)
})

test_that("a declining first lens falls through to the next in the order", {
  tab_local <- .contrib_of(
    lens_contribution("mechanism", TRUE, TRUE, reason = "input_ungrounded"),
    lens_contribution("statistical", TRUE, FALSE, action = 30)
  )
  res <- quorum_resolve(tab_local,
                        quorum_policy(c("mechanism", "statistical"),
                                      status_quo = 60))
  expect_identical(res$carried_lens, "statistical")
  expect_identical(res$action, 30)
  expect_true(res$tier_statistical)
})

test_that("a grounded lens that declines defaults to the status quo", {
  tab_local <- .contrib_of(
    lens_contribution("mechanism", TRUE, TRUE),
    lens_contribution("statistical", TRUE, TRUE)
  )
  res <- quorum_resolve(tab_local,
                        quorum_policy(c("mechanism", "statistical"),
                                      status_quo = 60))
  expect_identical(res$carried_lens, "status quo")
  expect_identical(res$verdict, "default")
  expect_identical(res$action, 60)
  expect_true(res$tier_status_quo)
})

test_that("nothing grounded abstains and issues no number", {
  tab_local <- .contrib_of(
    lens_contribution("mechanism", FALSE, TRUE),
    lens_contribution("statistical", FALSE, TRUE)
  )
  res <- quorum_resolve(tab_local,
                        quorum_policy(c("mechanism", "statistical"),
                                      status_quo = 60))
  expect_identical(res$carried_lens, "none")
  expect_identical(res$verdict, "abstain")
  expect_true(is.na(res$action))
  expect_true(res$tier_abstain)
})

test_that("grounding that was never established is not grounded", {
  tab_local <- .contrib_of(lens_contribution("mechanism", NA, FALSE,
                                             action = 120))
  res <- quorum_resolve(tab_local, quorum_policy("mechanism",
                                                 status_quo = 60))
  expect_identical(res$verdict, "abstain")
  expect_true(is.na(res$action))
})

test_that("a policy with no status quo abstains rather than defaulting", {
  tab_local <- .contrib_of(lens_contribution("mechanism", TRUE, TRUE))
  res <- quorum_resolve(tab_local, quorum_policy("mechanism"))
  expect_identical(res$carried_lens, "none")
  expect_identical(res$verdict, "abstain")
  expect_true(is.na(res$action))
})

test_that("a lens outside the policy's order takes no part", {
  tab_local <- .contrib_of(
    lens_contribution("mechanism", FALSE, TRUE),
    lens_contribution("koine", TRUE, FALSE, action = 90)
  )
  res <- quorum_resolve(tab_local, quorum_policy("mechanism",
                                                 status_quo = 60))
  expect_false("tier_koine" %in% names(res))
  expect_identical(res$verdict, "abstain")
})

test_that("a cell column resolves per cell", {
  tab_local <- .contrib_of(
    cbind(lens_contribution("mechanism", TRUE, FALSE, action = 120),
          data.frame(cell = "c1", stringsAsFactors = FALSE)),
    cbind(lens_contribution("statistical", TRUE, FALSE, action = 30),
          data.frame(cell = "c1", stringsAsFactors = FALSE)),
    cbind(lens_contribution("mechanism", TRUE, TRUE),
          data.frame(cell = "c2", stringsAsFactors = FALSE)),
    cbind(lens_contribution("statistical", TRUE, FALSE, action = 45),
          data.frame(cell = "c2", stringsAsFactors = FALSE))
  )
  res <- quorum_resolve(tab_local,
                        quorum_policy(c("mechanism", "statistical"),
                                      status_quo = 60))
  expect_identical(res$cell, c("c1", "c2"))
  expect_identical(res$carried_lens, c("mechanism", "statistical"))
  expect_identical(res$action, c(120, 45))
})

test_that("a lens silent about a cell is absent, not declining", {
  tab_local <- .contrib_of(
    cbind(lens_contribution("mechanism", TRUE, FALSE, action = 120),
          data.frame(cell = "c1", stringsAsFactors = FALSE)),
    cbind(lens_contribution("mechanism", FALSE, TRUE),
          data.frame(cell = "c2", stringsAsFactors = FALSE)),
    cbind(lens_contribution("statistical", TRUE, FALSE, action = 30),
          data.frame(cell = "c1", stringsAsFactors = FALSE))
  )
  res <- quorum_resolve(tab_local,
                        quorum_policy(c("mechanism", "statistical"),
                                      status_quo = 60))
  expect_identical(res$carried_lens, c("mechanism", "none"))
})

test_that("a contributions table is checked before it is resolved", {
  pol <- quorum_policy("mechanism", status_quo = 60)
  expect_error(quorum_resolve(data.frame(), pol), "non-empty")
  expect_error(quorum_resolve(data.frame(lens = "m"), pol), "missing the")
  dup_local <- .contrib_of(lens_contribution("mechanism", TRUE, FALSE),
                           lens_contribution("mechanism", TRUE, FALSE))
  expect_error(quorum_resolve(dup_local, pol), "twice within one cell")
  expect_error(quorum_resolve(.contrib_of(lens_contribution("m", TRUE, FALSE)),
                              "not a policy"),
               "must be a quorum_policy")
})

test_that("the committed convention decides, demotes and abstains", {
  base_row <- function(...) {
    cbind(lens_contribution("mechanism", ...),
          data.frame(lenses_disagree = FALSE, producer_abstained = FALSE))
  }
  tab_local <- contributions(list(
    cbind(base_row(TRUE, FALSE, action = 120),
          data.frame(cell = "decide", stringsAsFactors = FALSE)),
    cbind(base_row(TRUE, TRUE, reason = "insufficient_evidence"),
          data.frame(cell = "insufficient", stringsAsFactors = FALSE)),
    cbind(base_row(FALSE, TRUE, reason = "input_ungrounded",
                   grounding = orchestraManifest::GROUNDING_UNVERIFIED),
          data.frame(cell = "ungrounded", stringsAsFactors = FALSE))
  ))
  tab_local$lenses_disagree[1L] <- FALSE
  pol_zero <- policy_committed("zero", lens = "mechanism", status_quo = 60,
                               safe_action = 0)
  res <- quorum_resolve(tab_local, pol_zero)
  expect_identical(res$verdict, c("decide", "default", "abstain"))
  expect_identical(res$action, c(120, 60, 0))
  expect_identical(res$carried_lens, c("mechanism", "status quo", "none"))
  pol_sq <- policy_committed("status_quo", lens = "mechanism",
                             status_quo = 60, safe_action = 0)
  expect_identical(quorum_resolve(tab_local, pol_sq)$action, c(120, 60, 60))
})

test_that("a declared disagreement demotes a decisive cell", {
  tab_local <- contributions(
    cbind(lens_contribution("mechanism", TRUE, FALSE, action = 120),
          data.frame(lenses_disagree = TRUE, producer_abstained = FALSE))
  )
  pol <- policy_committed("zero", status_quo = 60, safe_action = 0)
  expect_identical(quorum_resolve(tab_local, pol)$verdict, "default")
  expect_identical(quorum_resolve(tab_local, pol)$action, 60)
})

test_that("an abstaining producer overrides a demotion", {
  tab_local <- contributions(
    cbind(lens_contribution("mechanism", TRUE, FALSE, action = 120),
          data.frame(lenses_disagree = TRUE, producer_abstained = TRUE))
  )
  pol <- policy_committed("zero", status_quo = 60, safe_action = 0)
  expect_identical(quorum_resolve(tab_local, pol)$verdict, "abstain")
  expect_identical(quorum_resolve(tab_local, pol)$action, 0)
})

test_that("the committed convention ignores a clause it has no column for", {
  tab_local <- contributions(lens_contribution("mechanism", TRUE, FALSE,
                                               action = 120))
  pol <- policy_committed("zero", status_quo = 60, safe_action = 0)
  expect_identical(quorum_resolve(tab_local, pol)$verdict, "decide")
})

test_that("policy_committed is a quorum_policy and validates its arguments", {
  pol <- policy_committed("status_quo", lens = "mechanism", status_quo = 60)
  expect_true(S7::S7_inherits(pol, quorum_policy))
  expect_identical(pol@fixed, "status_quo")
  expect_identical(pol@decision_lens, "mechanism")
  expect_error(policy_committed("neither"), "arg")
  expect_error(policy_committed("zero", lens = ""), "non-empty string")
})

test_that("comparing policies gives one verdict and action column each", {
  tab_local <- contributions(
    cbind(lens_contribution("mechanism", TRUE, TRUE,
                            reason = "insufficient_evidence"),
          data.frame(lenses_disagree = FALSE, producer_abstained = FALSE,
                     cell = "c1", stringsAsFactors = FALSE)),
    cbind(lens_contribution("statistical", TRUE, FALSE, action = 30),
          data.frame(cell = "c1", stringsAsFactors = FALSE))
  )
  cmp <- quorum_compare_policies(tab_local, list(
    cascade = quorum_policy(c("mechanism", "statistical"), status_quo = 60),
    committed = policy_committed("zero", status_quo = 60, safe_action = 0)
  ))
  expect_identical(names(cmp), c("cell", "verdict_cascade", "action_cascade",
                                 "verdict_committed", "action_committed"))
  expect_identical(cmp$verdict_cascade, "decide")
  expect_identical(cmp$action_cascade, 30)
  expect_identical(cmp$verdict_committed, "default")
  expect_identical(cmp$action_committed, 60)
  expect_error(quorum_compare_policies(tab_local, list()), "non-empty named")
  expect_error(quorum_compare_policies(tab_local, list(quorum_policy("m"))),
               "non-empty named")
})
