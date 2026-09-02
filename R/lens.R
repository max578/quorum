# lens.R -- the lens contract: what a member's estimate must declare to sit in
# a quorum, and the draws shape every lens returns.
#
# A lens is a member's fitter behind an adapter. It declares what it shares
# with other lenses (the independence ledger reads this), which response
# shapes it can express (the shape-finding rule reads this), and its scope (a
# typed abstention outside it). quorum never fits a model of its own.
#
# Skeleton laid by the leader 2026-09-02 (plan/quorum_v0.1.md section 5.1);
# the registry, the built-in lenses and the independence ledger are completed
# in this file by wave L1. The class properties below are the seam every
# other file codes against and must not change without the leader.

# ---- constants ---------------------------------------------------------------

.LENS_KINDS <- c("parameters", "response_curve")
.LENS_SHAPES <- c("linear", "plateau", "threshold", "nonmonotone")
.LENS_COMPONENTS <- c("sampler", "objective", "priors", "data_prep")

# ---- quorum_draws ------------------------------------------------------------

#' The draws every lens returns
#'
#' A `quorum_draws` object is the one shape a lens hands to the comparison.
#' For `kind = "parameters"` the draws are a named list of numeric vectors,
#' one per estimand component, named with the hub's canonical parameter names.
#' For `kind = "response_curve"` the draws are a numeric matrix with one row
#' per draw and one column per grid point, and `grid` carries the candidate
#' grid (for example nitrogen rates).
#'
#' @param draws Named list of numeric vectors, or a numeric matrix.
#' @param kind One of `"parameters"` or `"response_curve"`.
#' @param grid Numeric grid for a response curve, else `NULL`.
#' @param source Single string naming where the draws came from.
#' @param diagnostics List of the producing lens's own diagnostics.
#' @return A `quorum_draws` S7 object.
#' @export
quorum_draws <- S7::new_class(
  "quorum_draws",
  properties = list(
    kind = S7::class_character,
    draws = S7::class_any,
    grid = S7::class_any,
    n = S7::class_integer,
    source = S7::class_character,
    diagnostics = S7::class_list
  ),
  constructor = function(draws, kind = "parameters", grid = NULL,
                         source = "unknown", diagnostics = list()) {
    kind <- match.arg(kind, .LENS_KINDS)
    if (kind == "parameters") {
      ok <- is.list(draws) && length(draws) > 0L && !is.null(names(draws)) &&
        all(nzchar(names(draws))) &&
        all(vapply(draws, is.numeric, logical(1L)))
      if (!ok) {
        stop("`draws` for kind 'parameters' must be a non-empty named list ",
             "of numeric vectors.", call. = FALSE)
      }
      n <- length(draws[[1L]])
      if (!all(vapply(draws, length, integer(1L)) == n)) {
        stop("every component of `draws` must have the same length.",
             call. = FALSE)
      }
      grid <- NULL
    } else {
      if (!is.matrix(draws) || !is.numeric(draws)) {
        stop("`draws` for kind 'response_curve' must be a numeric matrix ",
             "(rows = draws, columns = grid points).", call. = FALSE)
      }
      if (is.null(grid) || !is.numeric(grid) || length(grid) != ncol(draws)) {
        stop("`grid` must be a numeric vector with one entry per column of ",
             "`draws`.", call. = FALSE)
      }
      n <- nrow(draws)
    }
    S7::new_object(
      S7::S7_object(),
      kind = kind, draws = draws, grid = grid, n = as.integer(n),
      source = source, diagnostics = diagnostics
    )
  }
)

# ---- quorum_lens -------------------------------------------------------------

#' A lens: a member's estimate of a shared estimand, with its declarations
#'
#' @param name Single string, unique within a quorum.
#' @param member Single string naming the package the estimate comes from.
#' @param kind One of `"parameters"` or `"response_curve"`.
#' @param fit A function `(spec, data, ...)` returning a [quorum_draws()] or a
#'   [quorum_abstention()].
#' @param shares Named character vector over the components `sampler`,
#'   `objective`, `priors` and `data_prep`; two lenses that name the same value
#'   for a component share it, and the independence ledger counts it.
#' @param expresses Character subset of `linear`, `plateau`, `threshold`,
#'   `nonmonotone`: the response shapes the lens can express.
#' @param scope A function `(spec)` returning `TRUE` inside the lens's scope
#'   and a [quorum_abstention()] outside it.
#' @return A `quorum_lens` S7 object.
#' @export
quorum_lens <- S7::new_class(
  "quorum_lens",
  properties = list(
    name = S7::class_character,
    member = S7::class_character,
    kind = S7::class_character,
    fit = S7::class_function,
    shares = S7::class_character,
    expresses = S7::class_character,
    scope = S7::class_function
  ),
  constructor = function(name, member, fit, shares, expresses = "linear",
                         kind = "parameters", scope = function(spec) TRUE) {
    if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
      stop("`name` must be a single non-empty string.", call. = FALSE)
    }
    if (!is.character(member) || length(member) != 1L || !nzchar(member)) {
      stop("`member` must be a single non-empty string.", call. = FALSE)
    }
    kind <- match.arg(kind, .LENS_KINDS)
    if (!is.function(fit)) stop("`fit` must be a function.", call. = FALSE)
    if (!is.character(shares) || is.null(names(shares)) ||
        !all(.LENS_COMPONENTS %in% names(shares))) {
      stop("`shares` must be a named character vector over the components ",
           paste(.LENS_COMPONENTS, collapse = ", "), ".", call. = FALSE)
    }
    shares <- shares[.LENS_COMPONENTS]
    if (!is.character(expresses) || !all(expresses %in% .LENS_SHAPES)) {
      stop("`expresses` must be a subset of ",
           paste(.LENS_SHAPES, collapse = ", "), ".", call. = FALSE)
    }
    if (!is.function(scope)) stop("`scope` must be a function.", call. = FALSE)
    S7::new_object(
      S7::S7_object(),
      name = name, member = member, kind = kind, fit = fit, shares = shares,
      expresses = unique(expresses), scope = scope
    )
  }
)

#' @rdname quorum_lens
#' @param ... Passed to the `quorum_lens` constructor.
#' @export
lens <- function(...) quorum_lens(...)
