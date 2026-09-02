# test-a0.R -- the characterisation oracle.
#
# Study A0 resolved 200 decision cells through a hand-written two-lens
# cascade. The recorded per-cell result is the fixture; the package's
# generalised resolution has to reproduce it exactly, tier by tier and rate by
# rate, or the graduation from study code to package verb has changed the
# answer. The fixture carries the recorded inputs and the recorded outputs, so
# nothing here is re-derived from the same code that produced it.

.a0_cells <- function() {
  readRDS(testthat::test_path("fixtures", "a0_cells.rds"))
}

# Build the contributions table from the recorded INPUT columns only: the two
# lenses' grounding, declines, actions, reasons and tokens. The recorded
# output columns are never read here -- they are what the resolution is
# checked against.
.a0_contributions <- function(tab_a0) {
  cell_vec <- paste0(tab_a0$site_id, "_", tab_a0$season)
  s1 <- nrow(tab_a0)
  rows_list <- vector("list", 2L * s1)
  for (i1 in seq_len(s1)) {
    row_mech <- lens_contribution(
      "mechanism",
      grounded = tab_a0$grounded[i1],
      abstained = tab_a0$dec_abstained[i1],
      action = tab_a0$dec_action[i1],
      reason = tab_a0$dec_reason[i1],
      grounding = tab_a0$dec_grounding[i1]
    )
    row_mech$cell <- cell_vec[i1]
    row_mech$lenses_disagree <- tab_a0$lenses_disagree[i1]
    row_mech$producer_abstained <- tab_a0$producer_abstained[i1]
    rows_list[[i1]] <- row_mech
    row_stat <- lens_contribution(
      "statistical",
      grounded = tab_a0$stat_available[i1],
      abstained = tab_a0$stat_abstained[i1],
      action = tab_a0$stat_action[i1],
      reason = tab_a0$stat_reason[i1]
    )
    row_stat$cell <- cell_vec[i1]
    rows_list[[s1 + i1]] <- row_stat
  } # ends i1, over the recorded decision cells
  contributions(rows_list)
}

test_that("the fixture is the recorded belt, with its two fallback rates", {
  tab_a0 <- .a0_cells()
  expect_s3_class(tab_a0, "data.frame")
  expect_identical(nrow(tab_a0), 200L)
  expect_identical(attr(tab_a0, "status_quo_rate"), 60)
  expect_identical(attr(tab_a0, "safe_rate"), 0)
  expect_identical(attr(tab_a0, "rate_vec"), c(0, 30, 60, 90, 120, 150))
  expect_match(attr(tab_a0, "source"), "Study A0")
  expect_true(all(c("grounded", "dec_abstained", "stat_available",
                    "tier_mechanism", "cascade_lens", "action_rate",
                    "verdict_prior", "action_rate_zero", "action_rate_sq")
                  %in% names(tab_a0)))
})

test_that("the cascade reproduces the recorded tiers cell by cell", {
  tab_a0 <- .a0_cells()
  res <- quorum_resolve(
    .a0_contributions(tab_a0),
    quorum_policy(order = c("mechanism", "statistical"),
                  status_quo = attr(tab_a0, "status_quo_rate"))
  )
  expect_identical(nrow(res), 200L)
  expect_identical(res$tier_mechanism, tab_a0$tier_mechanism)
  expect_identical(res$tier_statistical, tab_a0$tier_statistical)
  expect_identical(res$tier_status_quo, tab_a0$tier_status_quo)
  expect_identical(res$tier_abstain, tab_a0$tier_abstain)
})

test_that("the cascade reproduces the recorded lens, verdict and rate", {
  tab_a0 <- .a0_cells()
  res <- quorum_resolve(
    .a0_contributions(tab_a0),
    quorum_policy(order = c("mechanism", "statistical"),
                  status_quo = attr(tab_a0, "status_quo_rate"))
  )
  expect_identical(res$carried_lens, tab_a0$cascade_lens)
  expect_identical(res$verdict, tab_a0$verdict)
  expect_identical(res$action, tab_a0$action_rate)
})

test_that("the recorded cross-tab of carried lenses is reproduced", {
  tab_a0 <- .a0_cells()
  res <- quorum_resolve(
    .a0_contributions(tab_a0),
    quorum_policy(order = c("mechanism", "statistical"),
                  status_quo = attr(tab_a0, "status_quo_rate"))
  )
  tab_lens <- table(res$carried_lens)
  expect_identical(as.integer(tab_lens[["mechanism"]]), 150L)
  expect_identical(as.integer(tab_lens[["statistical"]]), 48L)
  expect_identical(as.integer(tab_lens[["status quo"]]), 2L)
  expect_false("none" %in% names(tab_lens))
  expect_identical(sum(tab_lens), 200L)
})

test_that("an abstaining cell would carry no rate at all", {
  tab_a0 <- .a0_cells()
  res <- quorum_resolve(
    .a0_contributions(tab_a0),
    quorum_policy(order = c("mechanism", "statistical"),
                  status_quo = attr(tab_a0, "status_quo_rate"))
  )
  expect_true(all(is.na(res$action[res$verdict == "abstain"])))
  expect_true(all(res$action[!is.na(res$action)] %in%
                    attr(tab_a0, "rate_vec")))
})

test_that("the two committed conventions are reproduced from one table", {
  tab_a0 <- .a0_cells()
  sq_local <- attr(tab_a0, "status_quo_rate")
  safe_local <- attr(tab_a0, "safe_rate")
  cmp <- quorum_compare_policies(.a0_contributions(tab_a0), list(
    cascade = quorum_policy(order = c("mechanism", "statistical"),
                            status_quo = sq_local),
    prior_zero = policy_committed("zero", lens = "mechanism",
                                  status_quo = sq_local,
                                  safe_action = safe_local),
    prior_sq = policy_committed("status_quo", lens = "mechanism",
                                status_quo = sq_local,
                                safe_action = safe_local)
  ))
  expect_identical(nrow(cmp), 200L)
  expect_identical(cmp$verdict_prior_zero, tab_a0$verdict_prior)
  expect_identical(cmp$verdict_prior_sq, tab_a0$verdict_prior)
  expect_identical(cmp$action_prior_zero, tab_a0$action_rate_zero)
  expect_identical(cmp$action_prior_sq, tab_a0$action_rate_sq)
  expect_identical(cmp$action_cascade, tab_a0$action_rate)
})

test_that("the conventions differ from the cascade exactly where recorded", {
  tab_a0 <- .a0_cells()
  sq_local <- attr(tab_a0, "status_quo_rate")
  cmp <- quorum_compare_policies(.a0_contributions(tab_a0), list(
    cascade = quorum_policy(order = c("mechanism", "statistical"),
                            status_quo = sq_local),
    prior_zero = policy_committed("zero", lens = "mechanism",
                                  status_quo = sq_local,
                                  safe_action = attr(tab_a0, "safe_rate"))
  ))
  differ_vec <- cmp$verdict_cascade != cmp$verdict_prior_zero
  expect_identical(sum(differ_vec),
                   sum(tab_a0$verdict != tab_a0$verdict_prior))
  # The committed convention mints a rate for every cell; the cascade is the
  # policy under which a cell may carry none.
  expect_false(any(is.na(cmp$action_prior_zero)))
})

test_that("the cell identifiers survive the resolution in order", {
  tab_a0 <- .a0_cells()
  res <- quorum_resolve(
    .a0_contributions(tab_a0),
    quorum_policy(order = c("mechanism", "statistical"),
                  status_quo = attr(tab_a0, "status_quo_rate"))
  )
  expect_identical(res$cell, paste0(tab_a0$site_id, "_", tab_a0$season))
})
