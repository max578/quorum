# abstention.R -- the package's typed decline.
#
# Every refusal quorum issues is a classed object carrying the
# `quorum_abstention` and `orchestra_refusal` markers so the fleet predicate
# (ORCHESTRA_dev `is_orchestra_decline()`) dispatches on it, and `abstained`,
# `reason`, `scope` and `detail` fields a caller can read without parsing text.

#' Construct a typed quorum abstention
#'
#' The single constructor for every decline the package issues. A lens that is
#' out of scope, an engine that is not installed, a comparison with fewer
#' contributing lenses than the policy's quorum, or a resolution with nothing
#' grounded left all return one of these rather than a number.
#'
#' @param reason A single string naming the reason in snake_case, for example
#'   `"engine_missing"`, `"out_of_scope"`, `"no_quorum"`, `"not_grounded"`.
#' @param detail Optional single string with the specifics a reader needs.
#' @param scope Single string naming the part of the package that declined
#'   (`"lens"`, `"comparison"`, `"resolution"`, `"manifest"`).
#' @param ... Further named fields carried on the object.
#' @return A list of class `c("quorum_abstention", "orchestra_refusal")` with
#'   `abstained = TRUE`, `reason`, `detail`, `scope` and any extra fields.
#' @export
#' @examples
#' a <- quorum_abstention("engine_missing", "tmbstan is not installed", "lens")
#' is_quorum_abstention(a)
quorum_abstention <- function(reason, detail = NULL, scope = "quorum", ...) {
  if (!is.character(reason) || length(reason) != 1L || !nzchar(reason)) {
    stop("`reason` must be a single non-empty string.", call. = FALSE)
  }
  if (!is.null(detail) && (!is.character(detail) || length(detail) != 1L)) {
    stop("`detail` must be NULL or a single string.", call. = FALSE)
  }
  if (!is.character(scope) || length(scope) != 1L || !nzchar(scope)) {
    stop("`scope` must be a single non-empty string.", call. = FALSE)
  }
  structure(
    c(list(abstained = TRUE, reason = reason, detail = detail, scope = scope),
      list(...)),
    class = c("quorum_abstention", "orchestra_refusal")
  )
}

#' @rdname quorum_abstention
#' @param x Any object.
#' @export
is_quorum_abstention <- function(x) {
  inherits(x, "quorum_abstention")
}

#' @export
print.quorum_abstention <- function(x, ...) {
  cat("<quorum abstention> ", x$reason, " [", x$scope, "]", sep = "")
  if (!is.null(x$detail)) cat("\n  ", x$detail, sep = "")
  cat("\n")
  invisible(x)
}
