# quorum.R -- the front door: lenses in, a typed verdict out.
#
# `quorum()` gates each lens on its own declared scope, asks it to fit, keeps
# only the lenses that came back with draws, compares them with the agreement
# semantics, weighs the comparison by how independent the lenses actually are,
# and resolves what is left through the declared policy. Nothing here fits a
# model: every estimate arrives through a lens's own adapter, and a lens that
# declines is recorded as having declined rather than replaced by a number.
#
# The metric layer, the lens registry and the independence ledger are built
# beside this file. Each is reached by name through `.quorum_fn()`, so the
# front door records what it could not compute instead of failing on a name
# that has not landed yet.

# ---- the verdict -------------------------------------------------------------

#' The verdict a quorum returns
#'
#' Everything the comparison established, in one object: which lenses were
#' asked, what each contributed, the pairwise agreement, the independence
#' weights behind it, the shape findings that explain a disagreement rather
#' than counting it, the overall status, the resolution the policy reached,
#' and the manifest the rest of the orchestra reads.
#'
#' @param lenses Character vector of the lens names that were asked.
#' @param contributions The contributions data frame, one row per lens.
#' @param agreement The agreement result, or `NULL` when the metric layer was
#'   not available.
#' @param independence The independence result, or `NULL`.
#' @param findings A data frame of shape findings.
#' @param status One of `"concordant"`, `"discordant"`, `"no_quorum"` or
#'   `"not_computed"`.
#' @param resolution The resolution data frame from [quorum_resolve()].
#' @param policy The [quorum_policy()] the resolution used.
#' @param manifest The emitted manifest, or the typed decline explaining why
#'   none was emitted, or `NULL`.
#' @param abstention A [quorum_abstention()] when the verdict carries no
#'   number, else `NULL`.
#' @return A `quorum_verdict` S7 object.
#' @seealso [quorum()], [quorum_manifest()].
#' @export
quorum_verdict <- S7::new_class(
  "quorum_verdict",
  properties = list(
    lenses = S7::class_character,
    contributions = S7::class_data.frame,
    agreement = S7::class_any,
    independence = S7::class_any,
    findings = S7::class_data.frame,
    status = S7::class_character,
    resolution = S7::class_data.frame,
    policy = S7::class_any,
    manifest = S7::class_any,
    abstention = S7::class_any
  ),
  constructor = function(lenses, contributions, status, resolution, policy,
                         agreement = NULL, independence = NULL,
                         findings = .empty_findings(), manifest = NULL,
                         abstention = NULL) {
    if (!is.character(lenses)) {
      stop("`lenses` must be a character vector of lens names.", call. = FALSE)
    }
    if (!is.character(status) || length(status) != 1L) {
      stop("`status` must be a single string.", call. = FALSE)
    }
    S7::new_object(
      S7::S7_object(),
      lenses = lenses, contributions = contributions, agreement = agreement,
      independence = independence, findings = findings, status = status,
      resolution = resolution, policy = policy, manifest = manifest,
      abstention = abstention
    )
  }
)

.empty_findings <- function() {
  data.frame(lens_a = character(0L), lens_b = character(0L),
             finding = character(0L), shapes = character(0L),
             stringsAsFactors = FALSE)
}

#' Print a quorum verdict
#'
#' Shows the status, how many lenses contributed and how many declined, the
#' lens whose answer is carried and the number it carries, the count of shape
#' findings, the independence caveat when there is one, and the typed decline
#' when the verdict carries no number.
#'
#' The method is registered against the package-qualified `S7` class name,
#' which is what `S7` puts in the class vector.
#'
#' @param x A [quorum_verdict()].
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
`print.quorum::quorum_verdict` <- function(x, ...) {
  contrib_local <- x@contributions
  n_contributing <- sum(.flag(contrib_local$contributed))
  n_abstained <- sum(.flag(contrib_local$abstained))
  cat("<quorum verdict> status: ", x@status, "\n", sep = "")
  cat("  lenses: ", length(x@lenses), " (", n_contributing,
      " contributing, ", n_abstained, " abstained)\n", sep = "")
  res_local <- x@resolution
  if (nrow(res_local) == 1L) {
    action_local <- if (is.na(res_local$action[1L])) {
      "no number issued"
    } else {
      format(res_local$action[1L])
    }
    cat("  carried: ", res_local$carried_lens[1L], " (",
        res_local$verdict[1L], ") -> ", action_local, "\n", sep = "")
  } else {
    cat("  carried: ", nrow(res_local), " cells resolved\n", sep = "")
  }
  cat("  findings: ", nrow(x@findings), "\n", sep = "")
  caveat_local <- if (is.list(x@independence)) {
    x@independence$caveat
  } else {
    NA_character_
  }
  if (!is.null(caveat_local) && !is.na(caveat_local)) {
    cat("  independence: ", caveat_local, "\n", sep = "")
  }
  if (!is.null(x@abstention)) {
    cat("  abstained: ", x@abstention$reason, "\n", sep = "")
  }
  invisible(x)
}

# ---- seam readers ------------------------------------------------------------

# Reduce what the metric layer returns to the pair identities and the pair
# status the quorum rule reads. `agreement_matrix()` reports a status matrix
# over the lenses; a pair the metric layer declined to compare keeps whatever
# status it gave that pair, and only `"concordant"` counts as agreement.
.read_pairs <- function(agr) {
  if (is.null(agr) || is_quorum_abstention(agr)) {
    return(NULL)
  }
  st_local <- if (is.list(agr)) agr$status else NULL
  if (!is.matrix(st_local) || is.null(rownames(st_local)) ||
        nrow(st_local) < 2L) {
    return(NULL)
  }
  nm_vec <- rownames(st_local)
  s1 <- length(nm_vec)
  s2 <- s1 * (s1 - 1L) / 2L
  a_vec <- character(s2)
  b_vec <- character(s2)
  status_vec <- character(s2)
  loc_c <- 0L
  for (i1 in seq_len(s1 - 1L)) {
    for (i2 in seq(i1 + 1L, s1)) {
      loc_c <- loc_c + 1L
      a_vec[loc_c] <- nm_vec[i1]
      b_vec[loc_c] <- nm_vec[i2]
      status_vec[loc_c] <- st_local[i1, i2]
    } # ends i2, over the lenses above i1 on the diagonal
  } # ends i1, over the unordered pairs of the status matrix
  data.frame(lens_a = a_vec, lens_b = b_vec, status = status_vec,
             concordant = !is.na(status_vec) & status_vec == "concordant",
             stringsAsFactors = FALSE)
}

# The evidential weight of a pair, read off the ledger's named weight matrix.
# Returns NULL when there is no ledger to read, which the caller reports as a
# caveat rather than treating an unweighed pair as weightless.
.weight_lookup <- function(ind) {
  wts <- if (is.list(ind)) ind$weight else NULL
  if (!is.matrix(wts) || is.null(rownames(wts)) || is.null(colnames(wts))) {
    return(NULL)
  }
  function(a, b) {
    if (a %in% rownames(wts) && b %in% colnames(wts)) {
      as.numeric(wts[a, b])
    } else {
      NA_real_
    }
  }
}

.pair_key <- function(a, b) {
  s1 <- length(a)
  out <- character(s1)
  for (i1 in seq_len(s1)) {
    out[i1] <- paste(sort(c(as.character(a[i1]), as.character(b[i1]))),
                     collapse = "\r")
  } # ends i1, over the pairs being keyed
  out
}

# ---- the front door ----------------------------------------------------------

.resolve_lenses <- function(lenses) {
  if (S7::S7_inherits(lenses, quorum_lens)) {
    lenses <- list(lenses)
  }
  if (is.character(lenses)) {
    lenses <- as.list(lenses)
  }
  if (!is.list(lenses) || length(lenses) == 0L) {
    stop("`lenses` must be a non-empty list of quorum_lens objects or names.",
         call. = FALSE)
  }
  get_fn <- .quorum_fn("get_lens")
  s1 <- length(lenses)
  for (i1 in seq_len(s1)) {
    one_local <- lenses[[i1]]
    if (is.character(one_local) && length(one_local) == 1L) {
      if (is.null(get_fn)) {
        stop("lens names need the lens registry; pass quorum_lens objects.",
             call. = FALSE)
      }
      found_local <- get_fn(one_local)
      if (is.null(found_local)) {
        stop("no lens named '", one_local, "' is registered.", call. = FALSE)
      }
      lenses[[i1]] <- found_local
    }
    if (!S7::S7_inherits(lenses[[i1]], quorum_lens)) {
      stop("every element of `lenses` must be a quorum_lens.", call. = FALSE)
    }
  } # ends i1, over the lenses being resolved to objects
  names(lenses) <- vapply(lenses, function(l) l@name, character(1L))
  if (anyDuplicated(names(lenses)) > 0L) {
    stop("lens names must be unique within a quorum.", call. = FALSE)
  }
  lenses
}

# Ask one lens: its own scope first, then its fit, then the caller's decision
# rule. Each step may decline, and a decline is recorded, never replaced.
.ask_lens <- function(one, spec, data, grid, decide) {
  scope_local <- one@scope(spec)
  if (is_quorum_abstention(scope_local)) {
    return(list(draws = NULL,
                row = .contribution_row(one, FALSE, TRUE, NA_real_,
                                        scope_local$reason, NA_character_,
                                        FALSE)))
  }
  if (!isTRUE(scope_local)) {
    return(list(draws = NULL,
                row = .contribution_row(one, FALSE, TRUE, NA_real_,
                                        "out_of_scope", NA_character_,
                                        FALSE)))
  }
  fit_local <- one@fit(spec, data)
  if (is_quorum_abstention(fit_local)) {
    return(list(draws = NULL,
                row = .contribution_row(one, FALSE, TRUE, NA_real_,
                                        fit_local$reason, NA_character_,
                                        FALSE)))
  }
  if (!S7::S7_inherits(fit_local, quorum_draws)) {
    stop("lens '", one@name, "' returned neither quorum_draws nor a typed ",
         "abstention.", call. = FALSE)
  }
  if (is.null(decide)) {
    return(list(draws = fit_local,
                row = .contribution_row(
                  one, TRUE, FALSE, NA_real_, NA_character_,
                  orchestraManifest::GROUNDING_GROUNDED, TRUE
                )))
  }
  dec_local <- decide(fit_local, grid)
  if (!is.list(dec_local)) {
    stop("`decide` must return a list with `action`, `abstained`, `reason` ",
         "and `grounding`.", call. = FALSE)
  }
  abstained_local <- isTRUE(dec_local$abstained)
  grounding_local <- dec_local$grounding %||% NA_character_
  grounded_local <- is.na(grounding_local) ||
    identical(as.character(grounding_local),
              orchestraManifest::GROUNDING_GROUNDED)
  list(draws = fit_local,
       row = .contribution_row(one, grounded_local, abstained_local,
                               as.numeric(dec_local$action %||% NA_real_),
                               as.character(dec_local$reason %||%
                                              NA_character_),
                               as.character(grounding_local),
                               TRUE))
}

.contribution_row <- function(one, grounded, abstained, action, reason,
                              grounding, contributed) {
  row_local <- lens_contribution(one@name, grounded = grounded,
                                 abstained = abstained, action = action,
                                 reason = reason, grounding = grounding,
                                 decisive = !abstained)
  row_local$member <- one@member
  row_local$kind <- one@kind
  row_local$contributed <- contributed
  row_local
}

.call_agreement <- function(draws_list, thresholds) {
  fn <- .quorum_fn("agreement_matrix")
  if (is.null(fn)) {
    return(NULL)
  }
  args_local <- list(draws_list)
  if ("thresholds" %in% names(formals(fn)) && !is.null(thresholds)) {
    args_local$thresholds <- thresholds
  }
  do.call(fn, args_local)
}

.call_independence <- function(lens_list, data_independence) {
  fn <- .quorum_fn("quorum_independence")
  if (is.null(fn)) {
    return(NULL)
  }
  if (length(formals(fn)) >= 2L) {
    fn(lens_list, data_independence)
  } else {
    fn(lens_list)
  }
}

#' Compare a quorum of lenses and resolve them into one verdict
#'
#' The front door. Each lens is gated on its own declared scope, then asked to
#' fit; a lens that declines either is recorded as having declined and
#' contributes no number. The lenses that returned draws are compared with the
#' agreement semantics, weighed by the independence ledger, and resolved
#' through the declared policy, and the whole comparison is emitted as a
#' manifest the rest of the orchestra can read.
#'
#' A disagreement between two lenses that cannot express the same response
#' shapes is recorded as a finding rather than counted as discordance: the
#' more expressive lens seeing a plateau the other cannot represent is
#' information about the pair, not evidence that either is wrong.
#'
#' The status is `"no_quorum"` when fewer lenses contribute than the policy
#' requires, `"not_computed"` when there is nothing to compare or the metric
#' layer is unavailable, `"concordant"` when every counted pair agrees, and
#' `"discordant"` otherwise. A pair the metric layer could not compare is not
#' concordant, so it makes the status `"discordant"`; the agreement matrix
#' names it as inconclusive rather than as disagreement.
#'
#' No quorum means no number. When fewer lenses contribute than the policy
#' requires, the resolution abstains whatever the contributing lenses said,
#' and the verdict carries the typed decline that says so.
#'
#' @param lenses A [quorum_lens()], a list of them, or their registered names.
#' @param spec The estimand specification each lens's `scope` and `fit`
#'   receive.
#' @param data The data each lens's `fit` receives.
#' @param policy A [quorum_policy()] declaring the fallback order and quorum.
#' @param grid The candidate grid a decision is taken over, or `NULL`.
#' @param decide An optional function `(draws, grid)` returning a list with
#'   `action`, `abstained`, `reason` and `grounding`, supplied by the caller
#'   -- a decision layer's wrapper, for instance. Without one, a contributing
#'   lens is decisive and its action is `NA`: `quorum` compares lenses and
#'   never prices a decision itself.
#' @param data_independence Single logical: do the lenses read independent
#'   upstream data? `FALSE` blocks the manifest's grounded token, `NA` records
#'   that it was not declared.
#' @return A [quorum_verdict()].
#' @seealso [quorum_policy()], [quorum_resolve()], [quorum_manifest()].
#' @export
#' @examples
#' fit_fn <- function(spec, data, ...) {
#'   quorum_draws(list(`(Intercept)` = stats::rnorm(200L)),
#'                source = "example")
#' }
#' one <- quorum_lens("one", "example", fit_fn,
#'                    c(sampler = "a", objective = "b", priors = "c",
#'                      data_prep = "d"))
#' two <- quorum_lens("two", "example", fit_fn,
#'                    c(sampler = "w", objective = "x", priors = "y",
#'                      data_prep = "z"))
#' quorum(list(one, two), policy = quorum_policy(c("one", "two")))
quorum <- function(lenses, spec = NULL, data = NULL, policy, grid = NULL,
                   decide = NULL, data_independence = NA) {
  if (missing(policy)) {
    stop("`policy` is required: a quorum resolves through a declared policy.",
         call. = FALSE)
  }
  if (!S7::S7_inherits(policy, quorum_policy)) {
    stop("`policy` must be a quorum_policy.", call. = FALSE)
  }
  if (!is.null(decide) && !is.function(decide)) {
    stop("`decide` must be NULL or a function of (draws, grid).",
         call. = FALSE)
  }
  if (length(data_independence) != 1L || !is.logical(data_independence)) {
    stop("`data_independence` must be a single logical value.", call. = FALSE)
  }
  lens_list <- .resolve_lenses(lenses)
  s1 <- length(lens_list)
  rows_list <- vector("list", s1)
  draws_list <- vector("list", s1)
  names(draws_list) <- names(lens_list)
  for (i1 in seq_len(s1)) {
    ask_local <- .ask_lens(lens_list[[i1]], spec, data, grid, decide)
    rows_list[[i1]] <- ask_local$row
    draws_list[[i1]] <- ask_local$draws
  } # ends i1, over the lenses being asked
  contrib <- .rbind_fill(rows_list)

  contributed_vec <- .flag(contrib$contributed)
  names_contributing <- contrib$lens[contributed_vec]
  agreement <- .agreement_over(lens_list, draws_list, names_contributing,
                               policy)
  pairs_local <- agreement$pairs
  findings <- .shape_findings(lens_list, pairs_local)
  independence <- .independence_over(lens_list, names_contributing,
                                     data_independence)
  status <- .quorum_status(sum(contributed_vec), policy, pairs_local,
                           findings, independence$lookup)

  resolution <- quorum_resolve(contrib, policy)
  if (identical(status, "no_quorum")) {
    resolution <- .abstain_resolution(resolution)
  }
  abstention <- .verdict_abstention(status, resolution, policy,
                                    sum(contributed_vec))
  out <- quorum_verdict(
    lenses = names(lens_list), contributions = contrib,
    agreement = agreement$result, independence = independence$result,
    findings = findings, status = status, resolution = resolution,
    policy = policy, manifest = NULL, abstention = abstention
  )
  S7::prop(out, "manifest") <- quorum_manifest(out)
  out
}

# Compare the contributing lenses within each kind: a parameter posterior and
# a response curve are not the same shape and are never compared to each other.
.agreement_over <- function(lens_list, draws_list, names_contributing,
                            policy) {
  if (length(names_contributing) < 2L) {
    return(list(result = NULL, pairs = NULL))
  }
  kind_vec <- vapply(lens_list[names_contributing],
                     function(l) l@kind, character(1L))
  thresholds <- .policy_thresholds(policy)
  by_kind <- list()
  pairs_all <- NULL
  kinds_vec <- unique(kind_vec)
  s1 <- length(kinds_vec)
  for (i1 in seq_len(s1)) {
    nm_local <- names_contributing[kind_vec == kinds_vec[i1]]
    if (length(nm_local) < 2L) {
      next
    }
    res_local <- .call_agreement(draws_list[nm_local], thresholds)
    by_kind[[kinds_vec[i1]]] <- res_local
    pairs_all <- rbind(pairs_all, .read_pairs(res_local))
  } # ends i1, over the kinds present among the contributing lenses
  if (length(by_kind) == 0L) {
    return(list(result = NULL, pairs = NULL))
  }
  computed <- !is.null(pairs_all)
  list(result = list(by_kind = by_kind, pairs = pairs_all,
                     status = if (computed) "computed" else "not_computed"),
       pairs = pairs_all)
}

.independence_over <- function(lens_list, names_contributing,
                               data_independence) {
  ind_local <- .call_independence(lens_list[names_contributing],
                                  data_independence)
  lookup <- .weight_lookup(ind_local)
  caveat_vec <- character(0L)
  if (is.list(ind_local) && is.character(ind_local$caveat) &&
        nzchar(ind_local$caveat)) {
    caveat_vec <- c(caveat_vec, ind_local$caveat)
  }
  if (is.null(lookup)) {
    caveat_vec <- c(caveat_vec,
                    "Evidential weights are unavailable; every pair counted.")
  }
  caveat <- if (length(caveat_vec) == 0L) {
    NA_character_
  } else {
    paste(caveat_vec, collapse = " ")
  }
  list(result = list(ledger = ind_local,
                     weight = if (is.list(ind_local)) ind_local$weight,
                     data_independence = data_independence,
                     caveat = caveat),
       lookup = lookup)
}

# A pair whose lenses cannot express the same response shapes is a finding,
# not a disagreement: it is excluded from the discordance count and named.
.shape_findings <- function(lens_list, pairs_local) {
  out <- .empty_findings()
  if (is.null(pairs_local)) {
    return(out)
  }
  s1 <- nrow(pairs_local)
  for (i1 in seq_len(s1)) {
    if (isTRUE(pairs_local$concordant[i1])) {
      next
    }
    a_local <- pairs_local$lens_a[i1]
    b_local <- pairs_local$lens_b[i1]
    if (is.null(lens_list[[a_local]]) || is.null(lens_list[[b_local]])) {
      next
    }
    ea <- lens_list[[a_local]]@expresses
    eb <- lens_list[[b_local]]@expresses
    only_vec <- sort(union(setdiff(ea, eb), setdiff(eb, ea)))
    if (length(only_vec) == 0L) {
      next
    }
    out <- rbind(out, data.frame(
      lens_a = a_local, lens_b = b_local, finding = "shape_difference",
      shapes = paste(only_vec, collapse = ", "), stringsAsFactors = FALSE
    ))
  } # ends i1, over the discordant pairs
  rownames(out) <- NULL
  out
}

.quorum_status <- function(n_contributing, policy, pairs_local, findings,
                           lookup) {
  if (n_contributing < policy@min_lenses) {
    return("no_quorum")
  }
  if (n_contributing < 2L || is.null(pairs_local)) {
    return("not_computed")
  }
  keep_vec <- rep(TRUE, nrow(pairs_local))
  if (!is.null(lookup)) {
    w_vec <- vapply(seq_len(nrow(pairs_local)), function(i1) {
      as.numeric(lookup(pairs_local$lens_a[i1], pairs_local$lens_b[i1]))
    }, numeric(1L))
    keep_vec <- is.na(w_vec) | w_vec >= policy@independence_min
  }
  if (nrow(findings) > 0L) {
    excluded_vec <- .pair_key(findings$lens_a, findings$lens_b)
    keep_vec <- keep_vec &
      !(.pair_key(pairs_local$lens_a, pairs_local$lens_b) %in% excluded_vec)
  }
  if (all(.flag(pairs_local$concordant[keep_vec]))) "concordant" else
    "discordant"
}

# No quorum means no number. The lenses that did contribute stay in the
# contributions table, but the resolution carries none of their answers: a
# comparison the policy does not recognise as a quorum has not established one.
.abstain_resolution <- function(res) {
  tier_vec <- grep("^tier_", names(res))
  s1 <- length(tier_vec)
  for (i1 in seq_len(s1)) {
    res[[tier_vec[i1]]] <- rep(FALSE, nrow(res))
  } # ends i1, over the tier columns being cleared
  res$tier_abstain <- rep(TRUE, nrow(res))
  res$carried_lens <- "none"
  res$verdict <- "abstain"
  res$action <- NA_real_
  res
}

.verdict_abstention <- function(status, resolution, policy, n_contributing) {
  if (identical(status, "no_quorum")) {
    return(quorum_abstention(
      "no_quorum",
      paste0(n_contributing, " lens(es) contributed; the policy requires ",
             policy@min_lenses),
      scope = "resolution"
    ))
  }
  if (nrow(resolution) == 1L && identical(resolution$verdict[1L], "abstain")) {
    return(quorum_abstention(
      "not_grounded",
      "no grounded lens remained; no number is issued",
      scope = "resolution"
    ))
  }
  NULL
}
