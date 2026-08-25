# =============================================================================
# utils.R -- small internal helpers shared across the package
#
# `%||%` is used unqualified in nine places across R/ (ensemble_source.R,
# fb_pesto.R, surrogate_ppc.R, surrogate.R) but was previously defined
# nowhere in the package and imported from nowhere -- it resolved only
# because base R gained its own `%||%` at 4.4.0 and the R actually running
# happened to be at or above that. DESCRIPTION floors R (>= 4.1.0), on which
# base has no such operator and every one of those call sites would fail
# with "could not find function". Defining it locally makes the package
# correct at its declared floor regardless of which R happens to run it.
# =============================================================================

# Null-coalescing infix: `a` if not NULL, else `b`.
`%||%` <- function(a, b) if (is.null(a)) b else a
