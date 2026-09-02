# independence.R -- the evidential-weight ledger over a set of lenses.
#
# Two lenses that name the same sampler, the same objective, the same priors
# and the same data preparation are one lens counted twice, and their agreement
# carries no evidence at all. The ledger counts, for every pair, how many of
# the four declared components hold identical values, and turns the count into
# an evidential weight `1 - shared / 4`: 1 for a pair that shares nothing, 0
# for a pair that shares everything, and the quarters in between. The quorum
# rule reads that weight before it treats two agreeing lenses as corroboration.
#
# Sharing is plain equality on the declared value, and `"none"` is a value like
# any other: two lenses that both declare `"none"` for a component do share it,
# which is the right answer for two constants and the reason the status-quo
# lens must never be counted twice.
#
# What the ledger cannot see is the data. Lenses fitted to one dataset agree
# about that dataset, which is a weaker thing than corroborating the fact
# behind it, and no declaration on the lens can establish which of the two
# happened. `data_independence` records what the caller has established, and
# the caveat says the rest in the plainest sentence available.

#' The independence ledger over a set of lenses
#'
#' Counts what every pair of lenses shares and converts it into the evidential
#' weight the quorum rule reads. Two lenses declare four components --
#' `sampler`, `objective`, `priors` and `data_prep` -- and the weight for a
#' pair is `1 - shared / 4`, so a pair sharing nothing carries full weight, a
#' pair sharing all four carries none, and a pair sharing one component carries
#' three quarters.
#'
#' The declarations are the lenses' own. The ledger does not inspect an
#' engine to discover what it shares with another, because the point of the
#' declaration is that a member states its own dependencies where a reader can
#' see and dispute them.
#'
#' Data independence is a separate question the declarations cannot answer, so
#' the caller supplies it. Left at `NA` -- or set to `FALSE` -- the result
#' carries a caveat saying what agreement between lenses on one dataset does
#' and does not establish. The caveat is empty only when the caller has
#' positively established that the lenses saw independently-collected data.
#'
#' @param lenses A list of [quorum_lens()] objects. An empty list is allowed
#'   and yields empty matrices; anything in the list that is not a lens is a
#'   programmer error.
#' @param data_independence Single logical. `TRUE` when the lenses were fitted
#'   to independently-collected data, `FALSE` when they share one dataset, and
#'   `NA` (the default) when the caller has not established which. Anything
#'   other than `TRUE` attaches the caveat.
#' @return A list of class `quorum_independence` with `components` (the four
#'   component names), `shared` (an integer matrix of the number of components
#'   each pair holds in common, `NA` on the diagonal), `weight` (the numeric
#'   matrix `1 - shared / 4`, `NA` on the diagonal, rows and columns named for
#'   the lenses), `data_independence` as supplied, and `caveat` (the sentence
#'   to carry alongside the weights, or `""`).
#' @seealso [quorum_lens()] for the declarations the ledger reads.
#' @examples
#' d <- quorum_draws(list(beta = rnorm(20L)))
#' mk <- function(nm, shares) {
#'   lens_from_draws(d, name = nm, member = "quorum", shares = shares)
#' }
#' a <- mk("a", c(sampler = "nuts", objective = "brms", priors = "hub",
#'                data_prep = "hub"))
#' b <- mk("b", c(sampler = "ies", objective = "simulator",
#'                priors = "ensemble", data_prep = "pesto"))
#' quorum_independence(list(a, b))
#' @export
quorum_independence <- function(lenses, data_independence = NA) {
  if (!is.list(lenses)) {
    stop("`lenses` must be a list of quorum_lens objects.", call. = FALSE)
  }
  is_lens <- vapply(lenses, function(l) S7::S7_inherits(l, quorum_lens),
                    logical(1L))
  if (!all(is_lens)) {
    stop("every element of `lenses` must be a quorum_lens; element(s) ",
         paste(which(!is_lens), collapse = ", "), " are not.", call. = FALSE)
  }
  if (!is.logical(data_independence) || length(data_independence) != 1L) {
    stop("`data_independence` must be a single logical value.", call. = FALSE)
  }
  n <- length(lenses)
  nms <- vapply(lenses, function(l) S7::prop(l, "name"), character(1L),
                USE.NAMES = FALSE)
  declared <- lapply(lenses, function(l) {
    unname(S7::prop(l, "shares")[.LENS_COMPONENTS])
  })
  # The diagonal stays NA: a lens shares everything with itself, and reporting
  # weight 0 there would read as a finding rather than as the identity it is.
  shared <- matrix(NA_integer_, nrow = n, ncol = n,
                   dimnames = list(nms, nms))
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i != j) {
        shared[i, j] <- sum(declared[[i]] == declared[[j]])
      }
    }
  }
  weight <- 1 - shared / length(.LENS_COMPONENTS)
  caveat <- if (isTRUE(data_independence)) {
    ""
  } else {
    paste0("Agreement between lenses fitted to the same data is agreement, ",
           "not corroboration of a shared data fact.")
  }
  structure(
    list(components = .LENS_COMPONENTS, shared = shared, weight = weight,
         data_independence = data_independence, caveat = caveat),
    class = "quorum_independence"
  )
}

#' Print an independence ledger
#'
#' Shows the evidential weights rounded to two decimal places, and the caveat
#' whenever the data behind the lenses has not been established as
#' independently collected.
#'
#' @param x A `quorum_independence` object.
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @export
print.quorum_independence <- function(x, ...) {
  cat("<quorum independence ledger>\n")
  cat("  components: ", paste(x$components, collapse = ", "), "\n", sep = "")
  cat("  evidential weight (1 = shares nothing, 0 = shares everything)\n")
  print(round(x$weight, 2L))
  cat("  data independence: ", as.character(x$data_independence), "\n",
      sep = "")
  if (nzchar(x$caveat)) {
    cat("  ", x$caveat, "\n", sep = "")
  }
  invisible(x)
}
