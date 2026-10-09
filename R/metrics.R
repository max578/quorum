# =============================================================================
# metrics.R -- the agreement layer: the hub's per-parameter comparison
# semantics, re-derived over lens draws.
#
# quorum compares lenses that are not all hub fits, so it cannot reach the
# numbers through flexyBayes::triangulate(): that verb takes two *fit*
# objects and runs three gates of its own (a model fingerprint, each fit's
# convergence diagnostics, and matched priors on the variance components)
# before any metric is computed. In quorum the gates belong to the front
# door and the lens contract; the numbers belong here. The hub's metric
# helpers are internal to flexyBayes and cannot be called from another
# package, so this file re-derives them from the documented definitions and
# `tests/testthat/test-metrics.R` proves the re-derivation equals the hub's
# own output, column by column, on a pair of real hub fits.
#
# Every cut-off, reference scale, quantile rule and message string below is
# cited to its line in flexyBayes 0.10.0 `R/triangulate.R`. Each citation
# also names the symbol, so a citation still locates its source after the
# hub's line numbers move.
#
# Two hub behaviours are deliberately NOT re-derived, because quorum has no
# input from which to derive them. The matched-prior exclusion
# (`.triangulate_prior_exclusion`, hub line 861) reads a model fingerprint
# that only a `flexybayes()` fit carries, and the overall status's gate
# reasons (`.triangulate_status`, hub lines 875-908) read the comparability
# and diagnostic verdicts. A lens is not a fit; `agreement_status()`
# therefore implements the verdict-derived half of the hub's rule, and the
# gates sit in the quorum policy layer.
# =============================================================================

# ---- constants ---------------------------------------------------------------

# The probability grid the hub integrates the quantile function over
# (`.wasserstein1_1d`, hub line 944: `qs <- seq(0.01, 0.99, by = 0.01)`).
# Ninety-nine equally spaced interior points; the endpoints are excluded,
# which keeps the two extreme order statistics from dominating the integral.
.QUORUM_W1_PROBS <- seq(0.01, 0.99, by = 0.01)

# The verdicts that count as a comparison having happened
# (`.triangulate_status`, hub line 910).
.QUORUM_COMPARED <- c("concordant", "discordant")

# The columns of a pairwise agreement table, in the order they are reported.
.QUORUM_PAIRWISE_COLUMNS <- c(
  "param",
  "mean_a",
  "mean_b",
  "sd_a",
  "sd_b",
  "sd_ratio",
  "q025_diff",
  "q975_diff",
  "wasserstein_1",
  "mean_shift_sd",
  "w1_sd",
  "verdict",
  "reason"
)

# ---- thresholds --------------------------------------------------------------

#' The hub's agreement cut-offs
#'
#' The cut-offs the hub's cross-engine comparison applied when it called a
#' parameter concordant, with the hub's own defaults. That comparison,
#' `triangulate()`, was removed from flexyBayes in version 0.14.0; the
#' source lines cited below are from flexyBayes 0.10.0. A parameter is concordant when
#' the absolute mean difference is at most `mean_shift_sd_max` reference SDs,
#' the Wasserstein-1 distance is at most `w1_sd_max` reference SDs, and the
#' ratio of the two posterior SDs lies inside `sd_ratio_band`; any breach makes
#' it discordant.
#'
#' The cut-offs are heuristics in the sense the Bayesian-workflow literature
#' uses for cross-implementation checks: they are set to flag a difference a
#' reader should look at, they are not derived from a sampling distribution,
#' and they carry no error rate. The hub documents them that way and quorum
#' inherits both the numbers and the reading.
#'
#' `quantile_probs` names the two quantiles whose difference the table reports
#' as `q025_diff` and `q975_diff`. The hub reports that tail drift without ever
#' thresholding it, so there is no quantile tolerance in the verdict rule; the
#' argument fixes which quantiles are reported, not a cut-off they must clear.
#'
#' @param mean_shift_sd_max Single positive number: the largest absolute
#'   difference in posterior means, in reference-SD units, a concordant
#'   parameter may show. Hub default 0.1, from
#'   `.FB_TRIANGULATE_MEAN_SHIFT_MAX` at `flexyBayes` 0.10.0
#'   `R/triangulate.R:757`.
#' @param w1_sd_max Single positive number: the largest Wasserstein-1 distance,
#'   in reference-SD units, a concordant parameter may show. Hub default 0.1,
#'   from `.FB_TRIANGULATE_W1_MAX` at `R/triangulate.R:758`.
#' @param sd_ratio_band Numeric vector of length two, increasing: the band the
#'   ratio of the two posterior SDs must lie in. Hub default `c(0.9, 1.1)`,
#'   from `.FB_TRIANGULATE_SD_RATIO_BAND` at `R/triangulate.R:759`.
#' @param quantile_probs Numeric vector of length two, increasing, inside
#'   `(0, 1)`: the quantiles whose difference is reported. Hub default
#'   `c(0.025, 0.975)`, from the `stats::quantile()` calls in
#'   `.triangulate_one` at `R/triangulate.R:495` and `R/triangulate.R:497`.
#' @return A named list with the four elements above.
#' @seealso [agreement_pairwise()], [agreement_status()].
#' @export
#' @examples
#' agreement_thresholds()
#' agreement_thresholds(w1_sd_max = 0.05)
agreement_thresholds <- function(
  mean_shift_sd_max = 0.1,
  w1_sd_max = 0.1,
  sd_ratio_band = c(0.9, 1.1),
  quantile_probs = c(0.025, 0.975)
) {
  .agreement_check_cut("mean_shift_sd_max", mean_shift_sd_max)
  .agreement_check_cut("w1_sd_max", w1_sd_max)
  .agreement_check_band("sd_ratio_band", sd_ratio_band, lower = 0)
  .agreement_check_band("quantile_probs", quantile_probs, lower = 0, upper = 1)
  list(
    mean_shift_sd_max = as.numeric(mean_shift_sd_max),
    w1_sd_max = as.numeric(w1_sd_max),
    sd_ratio_band = as.numeric(sd_ratio_band),
    quantile_probs = as.numeric(quantile_probs)
  )
}

# A single finite positive cut-off, or a stop naming the argument.
.agreement_check_cut <- function(label, value) {
  ok <- is.numeric(value) && length(value) == 1L && is.finite(value) &&
    value > 0
  if (!ok) {
    stop("`", label, "` must be a single finite positive number.",
         call. = FALSE)
  }
  invisible(TRUE)
}

# A two-element increasing band inside the stated open interval.
.agreement_check_band <- function(label, value, lower = -Inf, upper = Inf) {
  ok <- is.numeric(value) && length(value) == 2L && all(is.finite(value)) &&
    value[[1L]] < value[[2L]] && value[[1L]] > lower && value[[2L]] < upper
  if (!ok) {
    stop("`", label, "` must be two increasing finite numbers strictly ",
         "inside (", lower, ", ", upper, ").", call. = FALSE)
  }
  invisible(TRUE)
}

# Reject a thresholds object that did not come through the constructor.
.agreement_check_thresholds <- function(thresholds) {
  needed <- c("mean_shift_sd_max", "w1_sd_max", "sd_ratio_band",
              "quantile_probs")
  if (!is.list(thresholds) || !all(needed %in% names(thresholds))) {
    stop("`thresholds` must be a list from `agreement_thresholds()`, ",
         "carrying ", paste(needed, collapse = ", "), ".", call. = FALSE)
  }
  .agreement_check_cut("mean_shift_sd_max", thresholds$mean_shift_sd_max)
  .agreement_check_cut("w1_sd_max", thresholds$w1_sd_max)
  .agreement_check_band("sd_ratio_band", thresholds$sd_ratio_band, lower = 0)
  .agreement_check_band("quantile_probs", thresholds$quantile_probs,
                        lower = 0, upper = 1)
  invisible(TRUE)
}

# ---- Wasserstein-1 -----------------------------------------------------------

# Empirical 1D Wasserstein-1 distance, the hub's definition
# (`.wasserstein1_1d`, hub lines 936-948).
#
# W1 between two distributions is the integral of the absolute difference of
# their quantile functions over u in (0, 1). This computes that integral as
# the mean of |F_a^-1(u) - F_b^-1(u)| over the 99-point uniform grid
# u = 0.01, 0.02, ..., 0.99, with each quantile function evaluated by
# `stats::quantile()`'s default type 7 -- linear interpolation between the
# sorted sample's order statistics. Interpolating both samples onto one
# common grid of probabilities is what makes the distance well defined when
# the two samples have different lengths, and it is the route the hub takes,
# so it is the route quorum takes.
#
# It is therefore a Riemann sum over 99 interior points rather than the exact
# piecewise-linear integral (which for two equal-length samples reduces to
# `mean(abs(sort(a) - sort(b)))`). The two agree to about 1e-3 of a posterior
# SD on posterior-sized samples; `test-metrics.R` measures the gap and holds
# it, and the closed-form N(0, 1) vs N(0.5, 1) check holds the value itself.
# Bit-equality with the hub is the binding constraint here: a distance quorum
# reports must be the same number the hub would report on the same draws.
#
# Returns `NA_real_` when either sample is empty, as the hub does.
.wasserstein1_1d <- function(a, b) {
  if (length(a) == 0L || length(b) == 0L) {
    return(NA_real_)
  }
  q_a <- stats::quantile(a, .QUORUM_W1_PROBS, names = FALSE, na.rm = TRUE)
  q_b <- stats::quantile(b, .QUORUM_W1_PROBS, names = FALSE, na.rm = TRUE)
  mean(abs(q_a - q_b))
}

# ---- draws coercion ----------------------------------------------------------

# Take the named list of numeric draw vectors out of whatever a lens handed
# over: a `quorum_draws` of kind "parameters", or a plain named list already
# in that shape. Returns the list, or a `quorum_abstention` when the object
# is a well-formed thing of the wrong sort (a response-curve lens in a
# parameter comparison). A malformed list is an adapter defect, not a
# runtime condition, so it stops.
#
# The membership test is `S7::S7_inherits()` and not `inherits()`: an S7
# object's class attribute is the package-qualified name, so
# `inherits(x, "quorum_draws")` is FALSE for every lens's draws and every
# `quorum_draws` would fall through to the plain-list branch.
.agreement_components <- function(x, label) {
  if (S7::S7_inherits(x, quorum_draws)) {
    if (!identical(x@kind, "parameters")) {
      return(quorum_abstention(
        "kind_not_parameters",
        paste0("`", label, "` is a quorum_draws of kind '", x@kind,
               "'; the agreement metrics compare parameter draws."),
        scope = "comparison"
      ))
    }
    return(x@draws)
  }
  ok <- is.list(x) && length(x) > 0L && !is.null(names(x)) &&
    all(nzchar(names(x))) && !anyDuplicated(names(x)) &&
    all(vapply(x, is.numeric, logical(1L)))
  if (!ok) {
    stop("`", label, "` must be a `quorum_draws` of kind 'parameters' or a ",
         "non-empty, uniquely named list of numeric vectors.", call. = FALSE)
  }
  x
}

# ---- pairwise agreement ------------------------------------------------------

#' Per-component agreement between two lenses
#'
#' Compare two lenses' parameter draws component by component, on the hub's
#' terms. For every component the two lenses share, the table reports each
#' lens's posterior mean and SD, the ratio of the SDs, the drift at the two
#' reported quantiles, the Wasserstein-1 distance between the two marginals,
#' the mean shift and the Wasserstein-1 distance expressed in reference-SD
#' units, and the verdict those three scaled quantities imply.
#'
#' The reference SD is the larger of the two posterior SDs, which is the scale
#' the hub uses (`.triangulate_verdicts`, `flexyBayes` 0.10.0
#' `R/triangulate.R:809`: `s_ref <- max(metrics$sd_a[[i]], metrics$sd_b[[i]],
#' na.rm = TRUE)`), and it is the default here so that a quorum comparison
#' returns the same numbers the hub's comparison returned on the same draws. `sd_ref`
#' offers the pooled and the one-sided scales for callers who want the
#' comparison read against a fixed lens instead, at the cost of leaving the
#' hub's scale.
#'
#' A component with no posterior spread on either side cannot be scaled
#' against anything, so it is reported with its raw distances, a
#' `not_compared` verdict and the hub's reason string rather than a verdict
#' the scale cannot support.
#'
#' Agreement is not validation. Two lenses that share a sampler, an objective,
#' a prior or a data-preparation step can agree because they share it; the
#' independence ledger, not this table, is what says whether their agreement
#' carries evidential weight.
#'
#' @param a,b A [quorum_draws()] of kind `"parameters"`, or a named list of
#'   numeric vectors in that shape.
#' @param names Optional character vector naming the components to compare.
#'   The default compares every component the two lenses share, in `a`'s
#'   order. Every name asked for must be present on both sides.
#' @param thresholds A list from [agreement_thresholds()].
#' @param sd_ref The reference SD the mean shift and the Wasserstein-1
#'   distance are scaled by: `"max"` (the hub's larger-of-the-two, the
#'   default), `"pooled"` (the root-mean-square of the two), `"a"` or `"b"`.
#' @return A data.frame with one row per compared component and the columns
#'   `param`, `mean_a`, `mean_b`, `sd_a`, `sd_b`, `sd_ratio`, `q025_diff`,
#'   `q975_diff`, `wasserstein_1`, `mean_shift_sd`, `w1_sd`, `verdict` and
#'   `reason`; or a [quorum_abstention()] of scope `"comparison"` when the two
#'   lenses share no component, when a requested component is absent, or when
#'   either input is a response-curve rather than a parameter lens.
#' @seealso [agreement_status()] for the overall verdict, [agreement_matrix()]
#'   for a quorum of more than two lenses.
#' @export
#' @examples
#' set.seed(1)
#' a <- list(intercept = rnorm(500L, 1, 0.5), slope = rnorm(500L, 2, 0.3))
#' b <- list(intercept = rnorm(500L, 1, 0.5), slope = rnorm(500L, 2.9, 0.3))
#' agreement_pairwise(a, b)[, c("param", "w1_sd", "verdict")]
agreement_pairwise <- function(
  a,
  b,
  names = NULL,
  thresholds = agreement_thresholds(),
  sd_ref = c("max", "pooled", "a", "b")
) {
  # `names` is the seam contract's argument name and it shadows the base
  # function inside this body, so the requested set is bound to its own name
  # and `names` itself is never read again below.
  requested <- names
  sd_ref <- match.arg(sd_ref)
  .agreement_check_thresholds(thresholds)

  draws_a <- .agreement_components(a, "a")
  if (is_quorum_abstention(draws_a)) {
    return(draws_a)
  }
  draws_b <- .agreement_components(b, "b")
  if (is_quorum_abstention(draws_b)) {
    return(draws_b)
  }

  common <- intersect(base::names(draws_a), base::names(draws_b))
  if (!is.null(requested)) {
    if (!is.character(requested) || length(requested) == 0L) {
      stop("`names` must be NULL or a non-empty character vector.",
           call. = FALSE)
    }
    absent <- setdiff(requested, common)
    if (length(absent) > 0L) {
      return(quorum_abstention(
        "names_not_present",
        paste0("not present on both lenses: ",
               paste(absent, collapse = ", ")),
        scope = "comparison"
      ))
    }
    common <- requested
  }
  if (length(common) == 0L) {
    return(quorum_abstention(
      "no_common_parameters",
      paste0("lens a carries ", length(draws_a), " component(s) and lens b ",
             length(draws_b), ", with no name in both."),
      scope = "comparison"
    ))
  }

  rows <- lapply(common, function(p) {
    .agreement_row(p, draws_a[[p]], draws_b[[p]], thresholds, sd_ref)
  })
  out <- do.call(rbind, lapply(rows, as.data.frame, stringsAsFactors = FALSE))
  row.names(out) <- NULL
  out[, .QUORUM_PAIRWISE_COLUMNS, drop = FALSE]
}

# One component's metrics and verdict, as a one-row list.
#
# The arithmetic tracks `.triangulate_one` (hub lines 488-516) and
# `.triangulate_verdicts` (hub lines 805-847) statement for statement: the
# same means, the same `stats::sd()`, the same type-7 quantiles, the same
# guarded SD ratio, the same reference scale, the same strict inequalities,
# and the same reason strings at the same two-decimal rounding.
.agreement_row <- function(param, a, b, thresholds, sd_ref) {
  a <- as.numeric(a)
  b <- as.numeric(b)
  mean_a <- mean(a, na.rm = TRUE)
  mean_b <- mean(b, na.rm = TRUE)
  sd_a <- stats::sd(a, na.rm = TRUE)
  sd_b <- stats::sd(b, na.rm = TRUE)
  probs <- thresholds$quantile_probs
  q_a <- stats::quantile(a, probs, names = FALSE, na.rm = TRUE)
  q_b <- stats::quantile(b, probs, names = FALSE, na.rm = TRUE)

  # Hub line 507: a ratio is reported only when the denominator is a real
  # positive spread.
  sd_ratio <- if (is.finite(sd_b) && sd_b > 0) sd_a / sd_b else NA_real_

  row <- list(
    param = param,
    mean_a = mean_a,
    mean_b = mean_b,
    sd_a = sd_a,
    sd_b = sd_b,
    sd_ratio = sd_ratio,
    q025_diff = q_a[[1L]] - q_b[[1L]],
    q975_diff = q_a[[2L]] - q_b[[2L]],
    wasserstein_1 = .wasserstein1_1d(a, b),
    mean_shift_sd = NA_real_,
    w1_sd = NA_real_,
    verdict = NA_character_,
    reason = NA_character_
  )

  s_ref <- .agreement_sd_ref(sd_a, sd_b, sd_ref)
  if (!is.finite(s_ref) || s_ref <= 0) {
    row$verdict <- "not_compared"
    # Hub lines 813-816, verbatim.
    row$reason <- paste0(
      "no posterior spread to scale the comparison against (both SDs are ",
      "zero or not finite)"
    )
    return(row)
  }

  row$mean_shift_sd <- abs(mean_a - mean_b) / s_ref
  row$w1_sd <- row$wasserstein_1 / s_ref
  breach <- c(
    if (row$mean_shift_sd > thresholds$mean_shift_sd_max) {
      sprintf("mean shift %.2f SD", row$mean_shift_sd)
    },
    if (row$w1_sd > thresholds$w1_sd_max) {
      sprintf("Wasserstein-1 %.2f SD", row$w1_sd)
    },
    if (!is.finite(sd_ratio) ||
          sd_ratio < thresholds$sd_ratio_band[[1L]] ||
          sd_ratio > thresholds$sd_ratio_band[[2L]]) {
      sprintf("SD ratio %.2f", sd_ratio)
    }
  )
  if (length(breach) > 0L) {
    row$verdict <- "discordant"
    row$reason <- paste(breach, collapse = "; ")
  } else {
    row$verdict <- "concordant"
  }
  row
}

# The scale the mean shift and the Wasserstein-1 distance are divided by.
# `"max"` is the hub's (hub line 809); `na.rm = TRUE` over two NAs returns
# -Inf and warns, and -Inf is exactly the not-comparable signal the caller
# tests for, so the warning is suppressed at the one line that provokes it
# rather than left to surface as a spurious anomaly.
.agreement_sd_ref <- function(sd_a, sd_b, sd_ref) {
  switch(
    sd_ref,
    max = suppressWarnings(max(c(sd_a, sd_b), na.rm = TRUE)),
    pooled = sqrt((sd_a^2 + sd_b^2) / 2),
    a = sd_a,
    b = sd_b
  )
}

# ---- overall status ----------------------------------------------------------

#' The overall status of an agreement table
#'
#' Reduce a pairwise agreement table to one of the hub's three statuses.
#' A table with at least one discordant component is `"discordant"`; a table
#' whose compared components are all concordant is `"concordant"`; a table in
#' which nothing was compared -- every row `not_compared`, or no rows at all
#' -- is `"inconclusive"`.
#'
#' This is the verdict-derived half of the hub's rule (`.triangulate_status`,
#' `flexyBayes` 0.10.0 `R/triangulate.R:910-927`). The other half of that rule
#' turns a failed comparability check or a fit's own failed diagnostics into
#' `"inconclusive"` before the verdicts are read at all. Those two gates take
#' a model fingerprint and a sampler's diagnostics, which a lens does not
#' carry, so in quorum they sit with the lens contract and the policy rather
#' than here: a caller that has gate findings of its own reports
#' `"inconclusive"` without consulting this function.
#'
#' @param table A data.frame from [agreement_pairwise()], or a
#'   [quorum_abstention()], which is returned unchanged so a declined
#'   comparison propagates instead of being scored.
#' @param thresholds A list from [agreement_thresholds()]. The status rule
#'   reads verdicts only -- the cut-offs were already applied, per component,
#'   when the table was built -- and the argument is validated and carried so
#'   one thresholds object passes unchanged through every verb of this layer.
#' @return A single string, one of `"concordant"`, `"discordant"` or
#'   `"inconclusive"`; or the abstention it was given.
#' @seealso [agreement_pairwise()].
#' @export
#' @examples
#' tbl <- data.frame(
#'   param = c("a", "b"),
#'   verdict = c("concordant", "discordant"),
#'   stringsAsFactors = FALSE
#' )
#' agreement_status(tbl)
agreement_status <- function(table, thresholds = agreement_thresholds()) {
  if (is_quorum_abstention(table)) {
    return(table)
  }
  .agreement_check_thresholds(thresholds)
  if (!is.data.frame(table) || !("verdict" %in% base::names(table))) {
    stop("`table` must be a data.frame carrying a `verdict` column, as ",
         "returned by `agreement_pairwise()`.", call. = FALSE)
  }
  verdict <- as.character(table$verdict)
  # Hub lines 910-927: nothing compared outranks any verdict; a single
  # discordant component outranks every concordant one.
  if (sum(verdict %in% .QUORUM_COMPARED) == 0L) {
    return("inconclusive")
  }
  if (any(verdict == "discordant")) {
    return("discordant")
  }
  "concordant"
}

# ---- the quorum's agreement matrix -------------------------------------------

#' Pairwise agreement across a quorum of lenses
#'
#' Run [agreement_pairwise()] over every unordered pair of a quorum's lenses
#' and collect the results: a square matrix of pairwise statuses, and the long
#' table of every component comparison behind it.
#'
#' A pair that shares no component is not a disagreement. Its status is
#' `"inconclusive"` and it enters the long table as a single row whose reason
#' is `no_common_parameters`, so the matrix and the table always tell the same
#' story and no pair goes missing from either.
#'
#' The matrix is symmetric and its diagonal is `NA`: a lens is not compared
#' with itself, and a diagonal of `"concordant"` would inflate any count taken
#' over the matrix.
#'
#' @param draws A named list of [quorum_draws()] objects of kind
#'   `"parameters"`, or of named lists of numeric vectors, one per lens. Names
#'   are the lens names and label the matrix and the table.
#' @param thresholds A list from [agreement_thresholds()].
#' @return A list of class `quorum_agreement` with elements `status` (an
#'   `N` by `N` character matrix of pairwise statuses, diagonal `NA`), `table`
#'   (the long data.frame: `lens_a`, `lens_b`, then the columns of
#'   [agreement_pairwise()]) and `thresholds` (the cut-offs used); or a
#'   [quorum_abstention()] of scope `"comparison"` when fewer than two lenses
#'   were given.
#' @seealso [agreement_pairwise()], [agreement_status()].
#' @export
#' @examples
#' set.seed(2)
#' lenses <- list(
#'   inla = list(mu = rnorm(400L)),
#'   brms = list(mu = rnorm(400L)),
#'   koine = list(mu = rnorm(400L, 3))
#' )
#' agreement_matrix(lenses)$status
agreement_matrix <- function(draws, thresholds = agreement_thresholds()) {
  .agreement_check_thresholds(thresholds)
  if (!is.list(draws) || is.null(base::names(draws)) ||
        !all(nzchar(base::names(draws))) ||
        anyDuplicated(base::names(draws))) {
    stop("`draws` must be a uniquely named list of lens draws.", call. = FALSE)
  }
  lens_names <- base::names(draws)
  n_lens <- length(draws)
  if (n_lens < 2L) {
    return(quorum_abstention(
      "too_few_lenses",
      paste0("an agreement matrix needs at least two lenses; ", n_lens,
             " was given."),
      scope = "comparison"
    ))
  }

  status <- matrix(
    NA_character_,
    nrow = n_lens,
    ncol = n_lens,
    dimnames = list(lens_names, lens_names)
  )
  parts <- list()
  for (i in seq_len(n_lens - 1L)) {
    for (j in seq(i + 1L, n_lens)) {
      pair <- agreement_pairwise(
        draws[[i]],
        draws[[j]],
        thresholds = thresholds
      )
      tbl <- .agreement_pair_table(pair)
      status[i, j] <- agreement_status(tbl, thresholds = thresholds)
      status[j, i] <- status[i, j]
      parts[[length(parts) + 1L]] <- cbind(
        data.frame(
          lens_a = lens_names[[i]],
          lens_b = lens_names[[j]],
          stringsAsFactors = FALSE
        ),
        tbl,
        row.names = NULL
      )
    }
  }

  long <- do.call(rbind, parts)
  row.names(long) <- NULL
  structure(
    list(status = status, table = long, thresholds = thresholds),
    class = "quorum_agreement"
  )
}

# Turn whatever `agreement_pairwise()` returned into table rows. A declined
# comparison becomes the one row that carries its reason, so the long table
# stays rectangular and a reader never has to look outside it to learn why a
# pair was not scored.
.agreement_pair_table <- function(pair) {
  if (!is_quorum_abstention(pair)) {
    return(pair)
  }
  row <- as.data.frame(
    c(
      list(param = NA_character_),
      stats::setNames(
        rep(list(NA_real_), 10L),
        .QUORUM_PAIRWISE_COLUMNS[2L:11L]
      ),
      list(verdict = "not_compared", reason = pair$reason)
    ),
    stringsAsFactors = FALSE
  )
  row[, .QUORUM_PAIRWISE_COLUMNS, drop = FALSE]
}

#' @export
print.quorum_agreement <- function(x, ...) {
  n_lens <- nrow(x$status)
  cat("<quorum agreement> ", n_lens, " lenses, ",
      nrow(x$table), " component comparisons\n", sep = "")
  print(x$status, quote = FALSE, na.print = ".")
  invisible(x)
}
