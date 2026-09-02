# koine_slot.R -- the dormant 4th-backend slot for koine, the synthesised
# fourth opinion on the orthogonal lens axis (CONSTELLATION.md contracts C1 +
# C3; the constellation's Leader direction item 2).
#
# This is the constellation's "dormant-but-correct activation" pattern
# (CONSTELLATION.md invariant 6), mirroring what R/gretaR_slot.R was before the
# 2026-06-02 gretaR activation: koine is registered in the backend registry
# (`R/backend_registry.R`, status = "dormant") and the canonical-name registry
# (`R/canonical_names.R`), but is NOT advertised on any user-facing `backend`
# argument. Every internal path that would dispatch to koine raises a structured
# `koine_dormant_refusal` naming the dormancy reason + the activation procedure.
#
# Unlike gretaR (an engine-axis HMC backend), koine's value is ORTHOGONAL-LENS
# diversity -- it is the synthesised fourth opinion `triangulate()` consumes,
# graded on the lens axis (ADR 0029), and it owns the Stage-0 koine_pass /
# koine_result data contract (C3). The slot here is its C1 backend seam: a
# draws-producing engine flexyBayes can triangulate against once koine's
# programmatic, re-entrant builder is confirmed against backend_contract.md
# clause 1 (the C1 conformance battery -- add a koine descriptor to
# .conformance_backends() in tests/testthat/test-backend-conformance.R).
#
# ACTIVATED 2026-06-08. The slot is live: `R/emit_koine.R` ports koine's real
# emit + the capability gate and registers `fb_as_draws_simple` /
# `canonical_names` S3 methods on flexyBayes core's exported generics, so core's
# generic `triangulate()` consumes a `flexybayes_koine` fit as its fourth column
# with no core edit (the lean-0.7.0 boundary holds). The single source of truth
# for activation state is the option `quorum.koine_activated`
# (default TRUE), queried here only.

# Minimum koine version carrying the programmatic, re-entrant builder
# (koine_pass_from_design) + the Stage-0 koine_pass/koine_result contract +
# the poisson (1 | g) corner. The Poisson corner landed at koine 0.2.0, so that
# is the activation floor.
.KOINE_VERSION_FLOOR <- "0.2.0"

# TRUE when koine is installed at or above the activation floor.
.koine_version_ok <- function() {
  nzchar(system.file(package = "koine")) &&
    utils::packageVersion("koine") >= .KOINE_VERSION_FLOOR
}

# Minimum koine version carrying the crossed / nested two-grouping (MET) entry
# -- the `groups` argument of koine_pass_from_design() and the `met` feature
# flag on the glmm_marginal / nimble_glmm lenses. The slot itself activates from
# .KOINE_VERSION_FLOOR (the single-intercept corner); a multi-environment model
# needs this higher floor, and emit_koine() abstains typedly below it.
.KOINE_MET_VERSION_FLOOR <- "0.3.0"

# TRUE when the installed koine carries the two-grouping MET entry.
.koine_met_version_ok <- function() {
  nzchar(system.file(package = "koine")) &&
    utils::packageVersion("koine") >= .KOINE_MET_VERSION_FLOOR
}

# ---------------------------------------------------------------- #
# Activation state introspection                                    #
# ---------------------------------------------------------------- #

# Resolve the current dormancy reason for the koine slot. Returns one of the
# documented sentinels; consumed by the dispatch refusal, the canonical-name
# mapper stub, and koine_status().
.koine_dormancy_reason <- function() {
  if (!nzchar(system.file(package = "koine"))) {
    return("koine_not_installed")
  }
  if (!.koine_version_ok()) {
    return("koine_below_floor")
  }
  activated <- isTRUE(getOption("quorum.koine_activated", TRUE))
  if (!activated) {
    return("slot_provisioned_not_activated")
  }
  # koine installed at/above the floor + the option on: the ported emit_koine()
  # builder is confirmed against the koine_pass/koine_result contract, so the
  # slot is fully active -- triangulate() consumes the fourth opinion.
  "koine_dispatch_eligible"
}

# Capability flag appended by lgm_gate() to an LGM-compatible IR. Always the
# dormant flag until activation flips the registry entry + a clause-1
# confirmation mechanism agrees.
.koine_slot_capability <- function() {
  if (identical(.koine_dormancy_reason(), "koine_dispatch_eligible")) {
    "koine_dispatch_eligible"
  } else {
    "koine_slot_dormant"
  }
}

# Standard activation procedure -- documented in one place so the dispatch
# refusal, the canonical-name stub, and koine_status() surface the same steps.
.koine_activation_procedure <- function() {
  c(
    paste0(
      "Install the koine package (>= ",
      .KOINE_VERSION_FLOOR,
      ", carrying koine_pass_from_design + the Stage-0 ",
      "koine_pass/koine_result contract + the poisson (1 | g) corner)."
    ),
    paste0(
      "Keep options(quorum.koine_activated = TRUE) (the default); ",
      "set it FALSE to hold the slot dormant."
    ),
    paste0(
      "Emit the fourth opinion with emit_koine(fit$fb, data) on a core fit and ",
      "pass it to flexyBayes::triangulate(engine_fit, koine_fit)."
    )
  )
}


# ---------------------------------------------------------------- #
# Canonical-name mapper stub                                        #
# ---------------------------------------------------------------- #
# Registered into .canonical_mappers under the key "koine" at package load.
# Hands back the scaffold-dormant sentinel so triangulate() short-circuits
# cleanly against a (currently impossible) koine fit.

.mapper_koine_stub <- function(fit, fb_terms) {
  list(
    map = character(0),
    transform = list(),
    source = "scaffold_dormant",
    dormancy_reason = .koine_dormancy_reason()
  )
}


# ---------------------------------------------------------------- #
# Registry capability predicate (dormant)                           #
# ---------------------------------------------------------------- #
# The backend registry stores this as koine's capability_predicate. While the
# slot is dormant it refuses every model with the dormancy flag, so a stray
# dispatch can never silently produce a wrong fit -- it is caught by the
# capability gate before the dispatch refusal even fires.

.capability_koine_dormant <- function(fb) {
  .koine_slot_capability()
}


# ---------------------------------------------------------------- #
# Exported helper                                                   #
# ---------------------------------------------------------------- #

#' Introspect the koine backend slot
#'
#' Returns the activation state of the koine backend slot plus the procedure to
#' activate it. koine is the synthesised fourth opinion on flexyBayes's
#' orthogonal lens axis (the constellation's C1 + C3 contracts). The slot has
#' been **active by default since 2026-06-08** on an installed koine at or
#' above the version floor, gated only by
#' `options(quorum.koine_activated)`; it falls back to dormant
#' (a structured `koine_dormant_refusal`) when koine is absent, below floor, or
#' the option is set `FALSE`. This helper is the canonical discoverability
#' surface -- call `koine_status()` to check whether the slot is currently
#' active on the installed koine version and, if not, why and how to activate
#' it.
#'
#' @return A list with components:
#'   \describe{
#'     \item{`activated`}{Logical: `TRUE` when koine is installed at or above the
#'       activation floor and `options(quorum.koine_activated)` is
#'       not set `FALSE` (the slot is live as of 2026-06-08).}
#'     \item{`koine_installed`}{Logical: result of
#'       `nzchar(system.file(package = "koine"))`.}
#'     \item{`builder_confirmed`}{Logical: whether koine's
#'       `koine_pass_from_design` builder is installed at or above the floor (the
#'       ported `emit_koine()` confirms it against the koine_pass/koine_result
#'       contract).}
#'     \item{`dormancy_reason`}{Character: one of
#'       `"koine_not_installed"`, `"koine_below_floor"`,
#'       `"slot_provisioned_not_activated"`, or `"koine_dispatch_eligible"` (the
#'       last meaning the slot is fully active).}
#'     \item{`activation_procedure`}{Character vector: numbered steps to
#'       activate the slot, in order.}
#'   }
#'
#' @examples
#' ks <- koine_status()
#' ks$activated         # TRUE when koine (>= 0.2.0) is installed
#' ks$dormancy_reason   # "koine_dispatch_eligible" when active
#' cat(ks$activation_procedure, sep = "\n")
#'
#' @seealso [gretaR_status()] for the engine-axis sibling slot.
#' @export
koine_status <- function() {
  installed <- nzchar(system.file(package = "koine"))
  reason <- .koine_dormancy_reason()
  fully_active <- identical(reason, "koine_dispatch_eligible")
  list(
    activated = fully_active,
    koine_installed = installed,
    builder_confirmed = installed && .koine_version_ok(),
    dormancy_reason = reason,
    activation_procedure = .koine_activation_procedure()
  )
}


# ---------------------------------------------------------------- #
# Dispatch refusal constructor                                      #
# ---------------------------------------------------------------- #
# Called from .dispatch_backend() (R/dispatch.R) when the internal value
# backend = "koine" reaches the dispatch branch. The branch is unreachable from
# user-facing entries (match.arg rejects "koine"); reachable only from internal
# callers + tests. Activation replaces the branch body with the real
# emit_koine() call; this helper is removed at that time.

.koine_dormant_refusal <- function(call = NULL) {
  reason <- .koine_dormancy_reason()
  proc <- .koine_activation_procedure()
  msg <- paste0(
    "The koine backend slot is currently dormant (reason: ",
    reason,
    "). koine is the synthesised fourth opinion on the orthogonal lens axis; ",
    "its slot is provisioned but not yet activated. Recommended fallback: use ",
    "an active engine (backend = \"greta\" / \"inla\" / \"brms\" / ",
    "\"gretaR\"). Activation procedure:\n",
    paste0("  ", seq_along(proc), ". ", proc, collapse = "\n")
  )
  cond <- structure(
    class = c("koine_dormant_refusal", "error", "condition"),
    list(
      message = msg,
      call = call,
      dormancy_reason = reason,
      activation_procedure = proc
    )
  )
  stop(cond)
}


# Canonical-name mapper. While koine is dormant it never produces a fit, so its
# mapper is never consulted by flexyBayes::triangulate() -- the stub is therefore
# NOT registered at load (that would be an inert cross-package side-effect, and
# flexyBayes's .canonical_mappers registry is core-owned). On activation, the
# real .mapper_koine is registered from the companion .onLoad via
# flexyBayes:::register_canonical_mapper("koine", .mapper_koine).
