# policy.R -- contributions, the declared policy, and the resolution cascade.
#
# A resolution reads one row per lens per decision cell -- which lens it is,
# whether its estimate is grounded, and whether it stood behind an action --
# together with a policy that declares the fallback order, and returns which
# lens's answer is carried and why. The cascade Study A0 wrote by hand for two
# lenses lives here as a rule over N lenses: walk the declared order, carry the
# first lens that is present, grounded and decisive; fall through to the
# declared status quo when a lens is present but will not stand behind a
# number; abstain when nothing grounded remains, and then issue no number at
# all.
#
# The two conventions the cascade replaced are kept as first-class policy
# objects rather than as prose, so the cost of each fallback convention is a
# column in one table rather than an argument.

# ---- seam lookup -------------------------------------------------------------

# Look a seam function up in this package's namespace, returning NULL when the
# file that defines it has not landed yet. The metric layer, the lens registry
# and the independence ledger are built beside this file, so the front door
# has to be able to record "not computed" rather than fail on a name.
.quorum_fn <- function(name) {
  env <- topenv(environment())
  if (!exists(name, envir = env, inherits = FALSE)) {
    return(NULL)
  }
  fn <- get(name, envir = env)
  if (is.function(fn)) fn else NULL
}

# A missing value is not a truth value: every flag read off a contributions
# table is reduced to TRUE or FALSE here, so an absent column never carries a
# cell into a tier by accident.
.flag <- function(x) {
  if (is.null(x)) {
    return(FALSE)
  }
  !is.na(x) & as.logical(x)
}

# ---- contributions -----------------------------------------------------------

#' One lens's contribution to a resolution
#'
#' Builds the single row a lens adds to a contributions table: which lens it
#' is, whether its estimate is grounded, whether it declined, the action it
#' stands behind, and the reason and grounding token it declared. The row is
#' the whole of what [quorum_resolve()] reads, so a lens that has abstained
#' cannot smuggle a number into a resolution.
#'
#' `decisive` defaults to the complement of `abstained` and is separate from
#' it because the two can come apart: a lens may fit, decline to abstain, and
#' still have no action to offer, and a caller that knows this records
#' `decisive = FALSE` rather than overloading the abstention flag.
#'
#' @param lens Single string naming the lens.
#' @param grounded Single logical: is the lens's estimate grounded?
#' @param abstained Single logical: did the lens decline to stand behind a
#'   number?
#' @param action The action the lens stands behind, as a single number, or
#'   `NA_real_` when it offers none.
#' @param reason Single string naming why the lens declined, or
#'   `NA_character_`.
#' @param grounding The grounding token the lens declared, conventionally one
#'   of `orchestraManifest::GROUNDING_GROUNDED` or its unverified complement,
#'   or `NA_character_`.
#' @param decisive Single logical: is this lens's answer usable as the carried
#'   answer? Defaults to `!abstained`.
#' @return A one-row data frame with the seven columns named above.
#' @seealso [contributions()] to bind rows into a table, [quorum_resolve()] to
#'   resolve one.
#' @export
#' @examples
#' lens_contribution("mechanism", grounded = TRUE, abstained = FALSE,
#'                   action = 120, grounding = "grounded")
lens_contribution <- function(lens, grounded, abstained, action = NA_real_,
                              reason = NA_character_,
                              grounding = NA_character_,
                              decisive = !abstained) {
  if (!is.character(lens) || length(lens) != 1L || !nzchar(lens)) {
    stop("`lens` must be a single non-empty string.", call. = FALSE)
  }
  .check_flag(grounded, "grounded")
  .check_flag(abstained, "abstained")
  .check_flag(decisive, "decisive")
  if (length(action) != 1L || !(is.numeric(action) || is.na(action))) {
    stop("`action` must be a single number or NA.", call. = FALSE)
  }
  .check_string(reason, "reason")
  .check_string(grounding, "grounding")
  data.frame(
    lens = lens,
    grounded = as.logical(grounded),
    abstained = as.logical(abstained),
    action = as.numeric(action),
    reason = as.character(reason),
    grounding = as.character(grounding),
    decisive = as.logical(decisive),
    stringsAsFactors = FALSE
  )
}

# A single logical, missing values allowed: `grounded = NA` is a lens whose
# grounding was never established, which `.flag()` later reads as not grounded.
.check_flag <- function(x, nm) {
  if (length(x) != 1L || !is.logical(x)) {
    stop("`", nm, "` must be a single logical value.", call. = FALSE)
  }
  invisible(NULL)
}

.check_string <- function(x, nm) {
  if (length(x) != 1L || !(is.character(x) || is.na(x))) {
    stop("`", nm, "` must be a single string or NA.", call. = FALSE)
  }
  invisible(NULL)
}

#' Bind lens contributions into one table
#'
#' Row-binds the rows produced by [lens_contribution()] into the contributions
#' table a resolution reads. Parts may carry extra columns beyond the seven of
#' the seam -- a `cell` identifier when the table spans many decision cells,
#' or the per-cell facts a comparison policy needs -- and columns absent from
#' one part are filled with `NA` rather than dropped, so lenses that declare
#' different extras still bind.
#'
#' @param ... Data frames of contributions, each with at least the columns
#'   [lens_contribution()] produces.
#' @return One data frame holding every row, with the union of the columns.
#' @seealso [lens_contribution()], [quorum_resolve()].
#' @export
#' @examples
#' contributions(
#'   lens_contribution("mechanism", TRUE, FALSE, action = 120),
#'   lens_contribution("statistical", TRUE, TRUE, reason = "insufficient")
#' )
contributions <- function(...) {
  parts <- list(...)
  if (length(parts) == 1L && is.list(parts[[1L]]) &&
        !is.data.frame(parts[[1L]])) {
    parts <- parts[[1L]]
  }
  if (length(parts) == 0L) {
    stop("`contributions()` needs at least one contribution.", call. = FALSE)
  }
  ok <- vapply(parts, is.data.frame, logical(1L))
  if (!all(ok)) {
    stop("every argument to `contributions()` must be a data frame.",
         call. = FALSE)
  }
  .rbind_fill(parts)
}

# Union the columns of a list of data frames and bind them. `rbind()` alone
# refuses parts whose columns differ, which is exactly the case a lens that
# declares an extra fact creates.
.rbind_fill <- function(parts) {
  cols <- unique(unlist(lapply(parts, names), use.names = FALSE))
  s1 <- length(parts)
  for (i1 in seq_len(s1)) {
    part_local <- parts[[i1]]
    miss_vec <- setdiff(cols, names(part_local))
    s2 <- length(miss_vec)
    if (s2 > 0L) {
      for (i2 in seq_len(s2)) {
        part_local[[miss_vec[i2]]] <- NA
      }
    } # ends i2, over the columns this part does not declare
    parts[[i1]] <- part_local[, cols, drop = FALSE]
  } # ends i1, over the parts being bound
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

# ---- policies ----------------------------------------------------------------

#' A resolution policy
#'
#' Declares how a comparison is resolved into one carried answer: the fallback
#' priority of the lenses, how many must contribute before a verdict is
#' issued, the agreement thresholds to compare them with, the evidential
#' weight below which a pair is not counted, and what a cell falls back to
#' when no lens stands behind a number.
#'
#' `status_quo` is the whole of the difference between a cell that defaults
#' and a cell that abstains. Left `NULL`, a resolution with no decisive lens
#' abstains and issues no number at all; set to a value, that value is carried
#' and the cell is marked as having defaulted rather than decided.
#'
#' `thresholds` left `NULL` means the agreement thresholds in force at the
#' time of use, read from `agreement_thresholds()` when the metric layer is
#' present, so a policy written today does not pin yesterday's cut-offs.
#'
#' @param order Character vector of lens names in fallback priority: the first
#'   name that is present, grounded and decisive is the one carried.
#' @param min_lenses Single whole number: how many lenses must contribute
#'   before a comparison is a quorum at all.
#' @param thresholds A list of agreement thresholds, or `NULL` to read
#'   `agreement_thresholds()` at the point of use.
#' @param independence_min Single number: the evidential weight at or above
#'   which a pair counts towards concordance.
#' @param status_quo A single number to fall back on, or `NULL` to abstain
#'   instead of defaulting.
#' @param safe_action The action a single lens falls back to inside its own
#'   decision. It is carried for the caller and is what
#'   `policy_committed(fixed = "zero")` resolves an abstention to; the cascade
#'   never mints a rate from it.
#' @return A `quorum_policy` S7 object.
#' @seealso [quorum_resolve()], [policy_committed()].
#' @export
#' @examples
#' quorum_policy(order = c("mechanism", "statistical"), status_quo = 60)
quorum_policy <- S7::new_class(
  "quorum_policy",
  properties = list(
    order = S7::class_character,
    min_lenses = S7::class_integer,
    thresholds = S7::class_any,
    independence_min = S7::class_numeric,
    status_quo = S7::class_any,
    safe_action = S7::class_any
  ),
  constructor = function(order, min_lenses = 2L, thresholds = NULL,
                         independence_min = 0, status_quo = NULL,
                         safe_action = NULL) {
    if (!is.character(order) || length(order) == 0L || !all(nzchar(order))) {
      stop("`order` must be a non-empty character vector of lens names.",
           call. = FALSE)
    }
    if (anyDuplicated(order) > 0L) {
      stop("`order` must not name a lens twice.", call. = FALSE)
    }
    if (length(min_lenses) != 1L || !is.numeric(min_lenses) ||
          is.na(min_lenses) || min_lenses < 1) {
      stop("`min_lenses` must be a single whole number of at least 1.",
           call. = FALSE)
    }
    if (!is.null(thresholds) && !is.list(thresholds)) {
      stop("`thresholds` must be NULL or a list.", call. = FALSE)
    }
    if (length(independence_min) != 1L || !is.numeric(independence_min) ||
          is.na(independence_min)) {
      stop("`independence_min` must be a single number.", call. = FALSE)
    }
    .check_fallback(status_quo, "status_quo")
    .check_fallback(safe_action, "safe_action")
    S7::new_object(
      S7::S7_object(),
      order = order,
      min_lenses = as.integer(min_lenses),
      thresholds = thresholds,
      independence_min = as.numeric(independence_min),
      status_quo = status_quo,
      safe_action = safe_action
    )
  }
)

.check_fallback <- function(x, nm) {
  if (!is.null(x) && (length(x) != 1L || !is.numeric(x))) {
    stop("`", nm, "` must be NULL or a single number.", call. = FALSE)
  }
  invisible(NULL)
}

#' The committed convention the cascade replaced
#'
#' Builds the policy Study A0 committed to before the cascade: one decision
#' lens decides, a declared disagreement between the lenses demotes the cell
#' to the status quo, a decision declined for insufficient evidence does the
#' same, and an ungrounded input or an abstaining producer resolves to a fixed
#' rate. It is kept as an object rather than as prose so that
#' [quorum_compare_policies()] can price it against the cascade in one table.
#'
#' The convention's defining property is that an abstention still mints a
#' number. `fixed = "zero"` resolves it to `safe_action`, the no-input floor;
#' `fixed = "status_quo"` resolves it to `status_quo`. Withholding a rate is
#' not among its outcomes, which is precisely what the cascade changed.
#'
#' @param fixed Which fixed rate an abstention resolves to: `"zero"` for
#'   `safe_action`, `"status_quo"` for `status_quo`.
#' @param lens Single string naming the deciding lens whose contribution rows
#'   the convention reads.
#' @param status_quo A single number: the rate a demoted cell holds, or `NULL`
#'   to leave it unstated (the action is then `NA`).
#' @param safe_action A single number: the no-input floor, or `NULL`.
#' @return A `quorum_policy_committed` S7 object, which is a [quorum_policy()]
#'   carrying the two extra declarations.
#' @seealso [quorum_resolve()], [quorum_compare_policies()].
#' @export
#' @examples
#' policy_committed("zero", lens = "mechanism", status_quo = 60,
#'                  safe_action = 0)
quorum_policy_committed <- S7::new_class(
  "quorum_policy_committed",
  parent = quorum_policy,
  properties = list(
    fixed = S7::class_character,
    decision_lens = S7::class_character
  ),
  constructor = function(fixed = c("zero", "status_quo"),
                         lens = "mechanism", status_quo = NULL,
                         safe_action = NULL) {
    fixed <- match.arg(fixed, c("zero", "status_quo"))
    if (!is.character(lens) || length(lens) != 1L || !nzchar(lens)) {
      stop("`lens` must be a single non-empty string.", call. = FALSE)
    }
    S7::new_object(
      quorum_policy(order = lens, min_lenses = 1L, status_quo = status_quo,
                    safe_action = safe_action),
      fixed = fixed,
      decision_lens = lens
    )
  }
)

#' @rdname quorum_policy_committed
#' @param ... Passed to the `quorum_policy_committed` constructor.
#' @export
policy_committed <- function(...) quorum_policy_committed(...)

# The thresholds a policy resolves to at the point of use: its own when it
# declared them, and otherwise whatever the metric layer holds now.
.policy_thresholds <- function(policy) {
  if (!is.null(policy@thresholds)) {
    return(policy@thresholds)
  }
  fn <- .quorum_fn("agreement_thresholds")
  if (is.null(fn)) NULL else fn()
}

# ---- resolution --------------------------------------------------------------

# The cell key a contributions table resolves over. A table with no `cell`
# column is one cell, which is the shape `quorum()` hands in.
.contrib_key <- function(contrib) {
  if ("cell" %in% names(contrib)) {
    as.character(contrib$cell)
  } else {
    rep("", nrow(contrib))
  }
}

.contrib_cells <- function(contrib) {
  unique(.contrib_key(contrib))
}

.check_contrib <- function(contrib) {
  if (!is.data.frame(contrib) || nrow(contrib) == 0L) {
    stop("`contrib` must be a non-empty contributions data frame.",
         call. = FALSE)
  }
  need_vec <- c("lens", "grounded", "abstained", "action", "decisive")
  miss_vec <- setdiff(need_vec, names(contrib))
  if (length(miss_vec) > 0L) {
    stop("`contrib` is missing the column(s) ",
         paste(miss_vec, collapse = ", "), ".", call. = FALSE)
  }
  key_vec <- paste(.contrib_key(contrib), contrib$lens, sep = "\r")
  if (anyDuplicated(key_vec) > 0L) {
    stop("`contrib` carries a lens twice within one cell.", call. = FALSE)
  }
  invisible(NULL)
}

# Line the rows of one lens up against the cell vector, giving NA where that
# lens said nothing about a cell.
.lens_rows <- function(contrib, key_vec, cells_vec, lens_name) {
  sel <- contrib$lens == lens_name & !is.na(contrib$lens)
  rows_local <- contrib[sel, , drop = FALSE]
  loc_c <- match(cells_vec, key_vec[sel])
  list(rows = rows_local, loc = loc_c, present = !is.na(loc_c))
}

#' Resolve a comparison into one carried answer
#'
#' Walks the policy's declared order and carries the first lens that is
#' present, grounded and decisive for that cell. When no lens is, but at least
#' one is present and grounded and simply would not stand behind a number, the
#' policy's `status_quo` is carried and the cell is recorded as having
#' defaulted. When nothing grounded remains, the cell abstains and carries no
#' number at all.
#'
#' The three outcomes are deliberately distinct. A defaulting cell has a
#' grounded lens that declined; an abstaining cell has none, and the
#' difference is the whole reason an abstention is not simply resolved to a
#' fixed rate. A lens that abstained never contributes its number to either.
#'
#' Handed a [policy_committed()], the function applies that convention instead
#' of the cascade and returns the same columns, so the two are comparable
#' cell by cell.
#'
#' Only lenses named in `policy@order` take part: a contribution from a lens
#' the policy did not declare is carried in the table but not in the
#' resolution.
#'
#' @param contrib A contributions data frame from [contributions()]. A `cell`
#'   column makes the resolution per cell; without one the whole table is
#'   treated as a single cell.
#' @param policy A [quorum_policy()] or a [policy_committed()].
#' @return A data frame with one row per cell: `cell` (when the input had
#'   one), a `tier_<lens>` logical for each lens in the policy's order,
#'   `tier_status_quo`, `tier_abstain`, `carried_lens`, `verdict` (`"decide"`,
#'   `"default"` or `"abstain"`) and `action`.
#' @seealso [contributions()], [quorum_compare_policies()], [quorum()].
#' @export
#' @examples
#' contrib <- contributions(
#'   lens_contribution("mechanism", grounded = TRUE, abstained = TRUE),
#'   lens_contribution("statistical", grounded = TRUE, abstained = FALSE,
#'                     action = 30)
#' )
#' quorum_resolve(contrib, quorum_policy(c("mechanism", "statistical"),
#'                                       status_quo = 60))
quorum_resolve <- function(contrib, policy) {
  .check_contrib(contrib)
  if (!S7::S7_inherits(policy, quorum_policy)) {
    stop("`policy` must be a quorum_policy (or a policy_committed).",
         call. = FALSE)
  }
  if (S7::S7_inherits(policy, quorum_policy_committed)) {
    return(.resolve_committed(contrib, policy))
  }
  key_vec <- .contrib_key(contrib)
  cells_vec <- unique(key_vec)
  s1 <- length(cells_vec)
  lens_vec <- policy@order
  s2 <- length(lens_vec)

  tier_mat <- matrix(FALSE, nrow = s1, ncol = s2,
                     dimnames = list(NULL, paste0("tier_", lens_vec)))
  carried_vec <- rep(NA_character_, s1)
  action_vec <- rep(NA_real_, s1)
  declined_vec <- rep(FALSE, s1)

  for (i1 in seq_len(s2)) {
    hit_local <- .lens_rows(contrib, key_vec, cells_vec, lens_vec[i1])
    grounded_local <- hit_local$present &
      .flag(hit_local$rows$grounded[hit_local$loc])
    decisive_local <- hit_local$present &
      .flag(hit_local$rows$decisive[hit_local$loc])
    tier_local <- grounded_local & decisive_local & is.na(carried_vec)
    act_local <- as.numeric(hit_local$rows$action[hit_local$loc])
    carried_vec[tier_local] <- lens_vec[i1]
    action_vec[tier_local] <- act_local[tier_local]
    tier_mat[, i1] <- tier_local
    # A lens that is present and grounded but will not stand behind a number
    # is what separates a default from an abstention.
    declined_vec <- declined_vec | (grounded_local & !decisive_local)
  } # ends i1, over the lenses in the policy's fallback order

  tier_sq_vec <- is.na(carried_vec) & declined_vec &
    !is.null(policy@status_quo)
  tier_ab_vec <- is.na(carried_vec) & !tier_sq_vec
  carried_vec[tier_sq_vec] <- "status quo"
  carried_vec[tier_ab_vec] <- "none"
  if (!is.null(policy@status_quo)) {
    action_vec[tier_sq_vec] <- as.numeric(policy@status_quo)
  }

  verdict_vec <- rep("decide", s1)
  verdict_vec[tier_sq_vec] <- "default"
  verdict_vec[tier_ab_vec] <- "abstain"

  .resolution_frame(contrib, cells_vec, tier_mat, tier_sq_vec, tier_ab_vec,
                    carried_vec, verdict_vec, action_vec)
}

# The committed convention, applied to the deciding lens's rows only. Order
# matters and is the convention's own: a demotion to the status quo is
# overwritten by an abstention, never the other way round.
.resolve_committed <- function(contrib, policy) {
  key_vec <- .contrib_key(contrib)
  cells_vec <- unique(key_vec)
  s1 <- length(cells_vec)
  hit_local <- .lens_rows(contrib, key_vec, cells_vec, policy@decision_lens)
  rows_local <- hit_local$rows[hit_local$loc, , drop = FALSE]

  verdict_vec <- rep("decide", s1)
  verdict_vec[.flag(rows_local$lenses_disagree)] <- "default"
  insufficient_vec <- .flag(rows_local$abstained) &
    !is.na(rows_local$reason) & rows_local$reason == "insufficient_evidence"
  verdict_vec[insufficient_vec] <- "default"
  ungrounded_vec <- (!is.na(rows_local$grounding) &
    rows_local$grounding %in%
      c(orchestraManifest::GROUNDING_UNVERIFIED, "[unverified]")) |
    .flag(rows_local$producer_abstained)
  verdict_vec[ungrounded_vec] <- "abstain"

  action_vec <- as.numeric(rows_local$action)
  sq_local <- if (is.null(policy@status_quo)) {
    NA_real_
  } else {
    as.numeric(policy@status_quo)
  }
  safe_local <- if (is.null(policy@safe_action)) {
    NA_real_
  } else {
    as.numeric(policy@safe_action)
  }
  action_vec[verdict_vec == "default"] <- sq_local
  action_vec[verdict_vec == "abstain"] <- if (policy@fixed == "zero") {
    safe_local
  } else {
    sq_local
  }

  tier_mat <- matrix(verdict_vec == "decide", nrow = s1, ncol = 1L,
                     dimnames = list(NULL,
                                     paste0("tier_", policy@decision_lens)))
  carried_vec <- rep("none", s1)
  carried_vec[verdict_vec == "decide"] <- policy@decision_lens
  carried_vec[verdict_vec == "default"] <- "status quo"

  .resolution_frame(contrib, cells_vec, tier_mat, verdict_vec == "default",
                    verdict_vec == "abstain", carried_vec, verdict_vec,
                    action_vec)
}

.resolution_frame <- function(contrib, cells_vec, tier_mat, tier_sq_vec,
                              tier_ab_vec, carried_vec, verdict_vec,
                              action_vec) {
  out <- as.data.frame(tier_mat, stringsAsFactors = FALSE)
  out$tier_status_quo <- tier_sq_vec
  out$tier_abstain <- tier_ab_vec
  out$carried_lens <- carried_vec
  out$verdict <- verdict_vec
  out$action <- action_vec
  if ("cell" %in% names(contrib)) {
    out <- cbind(data.frame(cell = cells_vec, stringsAsFactors = FALSE), out)
  }
  rownames(out) <- NULL
  out
}

#' Price several fallback conventions in one table
#'
#' Resolves the same contributions under every policy handed in and returns
#' one table carrying each policy's verdict and action side by side, so the
#' cost of a fallback convention is read off a column rather than argued.
#'
#' @param contrib A contributions data frame from [contributions()].
#' @param policies A named list of [quorum_policy()] and [policy_committed()]
#'   objects. The names become the column suffixes.
#' @return A data frame with one row per cell: `cell` (when the input had
#'   one), then `verdict_<name>` and `action_<name>` for each policy.
#' @seealso [quorum_resolve()].
#' @export
#' @examples
#' contrib <- contributions(
#'   lens_contribution(
#'     "mechanism", grounded = FALSE, abstained = TRUE,
#'     reason = "input_ungrounded",
#'     grounding = orchestraManifest::GROUNDING_UNVERIFIED
#'   ),
#'   lens_contribution("statistical", grounded = TRUE, abstained = FALSE,
#'                     action = 30)
#' )
#' quorum_compare_policies(contrib, list(
#'   cascade = quorum_policy(c("mechanism", "statistical"), status_quo = 60),
#'   committed = policy_committed("zero", status_quo = 60, safe_action = 0)
#' ))
quorum_compare_policies <- function(contrib, policies) {
  .check_contrib(contrib)
  if (!is.list(policies) || length(policies) == 0L ||
        is.null(names(policies)) || !all(nzchar(names(policies)))) {
    stop("`policies` must be a non-empty named list of policies.",
         call. = FALSE)
  }
  cells_vec <- .contrib_cells(contrib)
  out <- if ("cell" %in% names(contrib)) {
    data.frame(cell = cells_vec, stringsAsFactors = FALSE)
  } else {
    data.frame(row.names = seq_along(cells_vec))
  }
  s1 <- length(policies)
  for (i1 in seq_len(s1)) {
    res_local <- quorum_resolve(contrib, policies[[i1]])
    out[[paste0("verdict_", names(policies)[i1])]] <- res_local$verdict
    out[[paste0("action_", names(policies)[i1])]] <- res_local$action
  } # ends i1, over the policies being priced
  rownames(out) <- NULL
  out
}
