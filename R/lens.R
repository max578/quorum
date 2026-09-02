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

# ---- the lens registry -------------------------------------------------------

# The roster a quorum draws from. One package-level environment keyed by lens
# name; `parent = emptyenv()` stops a lookup falling through to the search path,
# so a lens registered as `c` or `data` can never resolve to a base R object by
# accident. Registration replaces by name, which is what a member re-declaring
# its own lens after an engine upgrade needs, and what keeps the roster free of
# two lenses answering to one name.
.lens_registry <- new.env(parent = emptyenv())

#' Register, retrieve, list and clear lenses
#'
#' The lens registry is the roster a quorum draws from. A member declares its
#' estimate once, as a [quorum_lens()], and registers it under a name; the
#' comparison then reaches the lens by that name rather than by holding the
#' object. Registration replaces by name, so re-registering after an engine
#' upgrade updates the roster in place rather than leaving two lenses answering
#' to one name.
#'
#' The registry holds declarations, not results. Registering a lens neither
#' fits nor ingests anything, because a lens is a fitter behind an adapter and
#' the fitting happens when the comparison calls its `fit()`. Clearing the
#' registry therefore costs nothing but the declarations themselves.
#'
#' @param lens A [quorum_lens()] to register. Anything else is a programmer
#'   error and raises a condition rather than returning an abstention: a
#'   registry that accepted non-lenses would defer the failure to the
#'   comparison, where the caller can no longer see which registration was
#'   wrong.
#' @param name Single non-empty string naming a registered lens.
#' @return `register_lens()` returns `lens` invisibly. `get_lens()` returns the
#'   registered [quorum_lens()], or `NULL` when nothing is registered under
#'   `name`; a lookup miss is a fact about the roster, not a failure.
#'   `list_lenses()` returns a `data.frame` with one row per registered lens
#'   ordered by name, carrying `name`, `member`, `kind`, `expresses` (the
#'   declared shapes collapsed with `"/"`, empty for a lens that expresses
#'   none) and one column per independence component (`sampler`, `objective`,
#'   `priors`, `data_prep`); it has zero rows when the registry is empty.
#'   `clear_lenses()` returns `NULL` invisibly.
#' @examples
#' d <- quorum_draws(list(beta = rnorm(50L)), source = "demo")
#' l <- lens_from_draws(
#'   d, name = "demo", member = "quorum",
#'   shares = c(sampler = "none", objective = "demo", priors = "none",
#'              data_prep = "none")
#' )
#' register_lens(l)
#' list_lenses()
#' identical(get_lens("demo"), l)
#' get_lens("never_registered")
#' clear_lenses()
#' @export
register_lens <- function(lens) {
  if (!S7::S7_inherits(lens, quorum_lens)) {
    stop("`lens` must be a quorum_lens object; got ",
         paste(class(lens), collapse = "/"), ".", call. = FALSE)
  }
  assign(S7::prop(lens, "name"), lens, envir = .lens_registry)
  invisible(lens)
}

#' @rdname register_lens
#' @export
get_lens <- function(name) {
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    stop("`name` must be a single non-empty string.", call. = FALSE)
  }
  if (!exists(name, envir = .lens_registry, inherits = FALSE)) {
    return(NULL)
  }
  get(name, envir = .lens_registry, inherits = FALSE)
}

#' @rdname register_lens
#' @export
list_lenses <- function() {
  nms <- sort(ls(envir = .lens_registry))
  lenses <- lapply(nms, function(nm) {
    get(nm, envir = .lens_registry, inherits = FALSE)
  })
  pull <- function(field) {
    vapply(lenses, function(l) S7::prop(l, field), character(1L),
           USE.NAMES = FALSE)
  }
  component <- function(key) {
    vapply(lenses, function(l) unname(S7::prop(l, "shares")[[key]]),
           character(1L), USE.NAMES = FALSE)
  }
  data.frame(
    name = nms,
    member = pull("member"),
    kind = pull("kind"),
    expresses = vapply(lenses, function(l) {
      paste(S7::prop(l, "expresses"), collapse = "/")
    }, character(1L), USE.NAMES = FALSE),
    sampler = component("sampler"),
    objective = component("objective"),
    priors = component("priors"),
    data_prep = component("data_prep"),
    stringsAsFactors = FALSE
  )
}

#' @rdname register_lens
#' @export
clear_lenses <- function() {
  rm(list = ls(envir = .lens_registry), envir = .lens_registry)
  invisible(NULL)
}

# ---- wrapping draws a member has already produced ----------------------------

#' Wrap draws a member has already produced as a lens
#'
#' The shortest path from a posterior to a lens. When a member has already
#' produced its draws -- a saved posterior, an ensemble read from disk, a
#' constant a practitioner is defending -- there is nothing left to fit, so the
#' lens's `fit()` ignores the specification and the data and hands back the
#' draws it was built from. Every built-in lens whose estimate is settled at
#' construction time is built this way.
#'
#' The `kind` is taken from the draws rather than declared again, because a
#' lens that disagreed with its own draws about whether they are parameters or
#' a response curve would be caught only at the comparison.
#'
#' @param draws A [quorum_draws()] object the lens returns unchanged.
#' @param name Single non-empty string, unique within a quorum.
#' @param member Single non-empty string naming the package the estimate comes
#'   from.
#' @param shares Named character vector over `sampler`, `objective`, `priors`
#'   and `data_prep`, the four components the independence ledger counts.
#' @param expresses Character subset of `linear`, `plateau`, `threshold` and
#'   `nonmonotone`; `character(0)` for a lens that expresses no shape at all,
#'   such as a constant.
#' @param scope A function `(spec)` returning `TRUE` inside the lens's scope
#'   and a [quorum_abstention()] outside it. The default accepts everything,
#'   which is right for draws that are already in hand.
#' @return A [quorum_lens()] whose `fit()` returns `draws`.
#' @examples
#' d <- quorum_draws(list(beta = rnorm(100L)), source = "saved")
#' l <- lens_from_draws(
#'   d, name = "saved", member = "quorum",
#'   shares = c(sampler = "none", objective = "saved", priors = "none",
#'              data_prep = "none")
#' )
#' identical(S7::prop(l, "fit")(NULL, NULL), d)
#' @export
lens_from_draws <- function(draws, name, member, shares,
                            expresses = "linear",
                            scope = function(spec) TRUE) {
  if (!S7::S7_inherits(draws, quorum_draws)) {
    stop("`draws` must be a quorum_draws object; got ",
         paste(class(draws), collapse = "/"), ".", call. = FALSE)
  }
  force(draws)
  quorum_lens(
    name = name,
    member = member,
    fit = function(spec, data, ...) draws,
    shares = shares,
    expresses = expresses,
    kind = S7::prop(draws, "kind"),
    scope = scope
  )
}
