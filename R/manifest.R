# manifest.R -- the verdict, emitted into the orchestra's contract.
#
# A consensus is a result like any other member's, so it leaves the package as
# an `orchestra_manifest` with `inferential_target = "consensus"`: the same
# integrity hash, the same grounding vocabulary, the same typed verdict slot.
# The contributions table is the payload, the headline and the numbers behind
# it are the summary, and both sit inside the hash, so a tampered verdict is
# caught exactly as a tampered posterior is. When the quorum is concordant
# over a single cell the carried lens's draws ride in `outputs`, hashed with
# the rest, so a decision layer downstream can price the consensus instead of
# receiving a verdict it cannot read.
#
# The grounding token is deliberately not the maximum of the lenses' own
# tokens. A consensus is grounded when a contributing lens is grounded AND the
# lenses did not read the same upstream data fact, because agreement between
# two readings of one fact is agreement about the reading, not about the world.

.quorum_version <- function() {
  as.character(utils::packageVersion("quorum"))
}

#' Emit a verdict as an orchestra manifest
#'
#' Builds the `orchestra_manifest` the rest of the orchestra reads from a
#' [quorum_verdict()]: the contributions table as the payload, the status,
#' the carried lens, the action, the independence weights and the
#' independence caveat in the typed summary, and the grounding token the
#' consensus earned.
#'
#' The grounding rule is stricter than the lenses'. The consensus is stamped
#' grounded only when at least one contributing lens is grounded *and*
#' `data_independence` was not declared `FALSE`; lenses that agree because
#' they read the same upstream fact corroborate the reading, not the world,
#' and the manifest says so by carrying the unverified token instead.
#'
#' @param verdict A [quorum_verdict()].
#' @return An `orchestraManifest::orchestra_manifest`, or a
#'   [quorum_abstention()] when the installed contract has no `"consensus"`
#'   target to emit into.
#' @seealso [quorum()], [quorum_verdict()].
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
#' v <- quorum(list(one, two), policy = quorum_policy(c("one", "two")))
#' quorum_manifest(v)
quorum_manifest <- function(verdict) {
  if (!S7::S7_inherits(verdict, quorum_verdict)) {
    stop("`verdict` must be a quorum_verdict.", call. = FALSE)
  }
  if (!"consensus" %in% orchestraManifest::inferential_targets()) {
    return(quorum_abstention(
      "target_unavailable",
      paste0("the installed orchestraManifest (",
             as.character(utils::packageVersion("orchestraManifest")),
             ") has no 'consensus' inferential target"),
      scope = "manifest"
    ))
  }
  contrib <- verdict@contributions
  res_local <- verdict@resolution
  one_cell <- nrow(res_local) == 1L
  carried <- if (one_cell) res_local$carried_lens[1L] else NA_character_
  action <- if (one_cell) res_local$action[1L] else NA_real_
  ind_local <- verdict@independence
  caveat <- if (is.list(ind_local)) ind_local$caveat else NA_character_

  summary_local <- orchestraManifest::manifest_summary(
    headline = .manifest_headline(verdict@status, carried, nrow(res_local)),
    abstained = !is.null(verdict@abstention),
    metrics = list(
      status = verdict@status,
      carried_lens = carried,
      action = action,
      n_lenses = length(verdict@lenses),
      n_contributing = sum(.flag(contrib$contributed)),
      n_findings = nrow(verdict@findings),
      independence_weights = if (is.list(ind_local)) ind_local$weight,
      independence_caveat = caveat
    ),
    abstain_reason = if (is.null(verdict@abstention)) {
      NA_character_
    } else {
      verdict@abstention$reason
    }
  )
  params <- as.data.frame(contrib, stringsAsFactors = FALSE)
  # The carried lens's posterior rides in `outputs`, which is where the
  # contract puts a payload and where a consumer's draws reader looks first.
  # It is NULL unless the quorum was concordant over a single cell, so a
  # verdict that declined to issue a number cannot be priced downstream. It is
  # hashed with everything else: a tampered posterior is caught exactly as a
  # tampered contributions table is.
  outputs_local <- verdict@carried_draws
  data_hash <- orchestraManifest::manifest_data_hash(
    params, outputs_local, NULL, NULL, NA_integer_, summary_local
  )
  orchestraManifest::orchestra_manifest(
    emitter_package = "quorum",
    emitter_version = .quorum_version(),
    inferential_target = "consensus",
    run_id = paste0("quorum-", substr(sub("^sha256:", "", data_hash), 1L, 12L)),
    method = "quorum:consensus",
    seed = NA_integer_,
    params = params,
    outputs = outputs_local,
    summary = summary_local,
    metadata = list(
      derived = FALSE,
      grounding = .consensus_grounding(contrib, ind_local),
      lenses = verdict@lenses,
      status = verdict@status,
      independence_caveat = caveat
    ),
    timestamp = Sys.time(),
    data_hash = data_hash
  )
}

.manifest_headline <- function(status, carried, n_cells) {
  if (n_cells != 1L || is.na(carried)) {
    return(paste0("consensus ", status, " over ", n_cells, " cells"))
  }
  paste0("consensus ", status, "; carried lens ", carried)
}

.consensus_grounding <- function(contrib, ind_local) {
  contributing <- if ("contributed" %in% names(contrib)) {
    .flag(contrib$contributed)
  } else {
    !.flag(contrib$abstained)
  }
  any_grounded <- any(contributing & .flag(contrib$grounded))
  shared_data <- is.list(ind_local) && isFALSE(ind_local$data_independence)
  if (any_grounded && !shared_data) {
    orchestraManifest::GROUNDING_GROUNDED
  } else {
    orchestraManifest::GROUNDING_UNVERIFIED
  }
}
