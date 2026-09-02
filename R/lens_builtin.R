# lens_builtin.R -- the lenses quorum ships: a hub fit, the koine fourth
# opinion, the simulator ensemble, and the status quo.
#
# Each one is an adapter, not a fitter. `lens_from_fit()` and `lens_koine()`
# reach an estimate the hub or koine produced; `lens_mechanism()` reads a
# simulation ensemble a simulator produced upstream; `lens_status_quo()` states
# the constant a practitioner is already defending, which is the lens every
# comparison needs and no package emits.
#
# The canonical-name composition below is the one piece of real translation in
# this file, and it is why a hub INLA lens and a koine lens can be compared
# component by component. `flexyBayes::fb_as_draws_simple()` returns each
# backend's NATIVE draw names: koine's wrapper is self-naming and already hands
# back the canonical tokens, but an INLA fit hands back INLA's raw latent and
# hyperparameter names -- one "Predictor:k" per observation, one "<group>:k"
# per random-effect level, "(Intercept):1" for the intercept, and precisions
# rather than standard deviations. The hub's exported `canonical_names()`
# generic carries the per-backend name map and the precision-to-SD value
# transforms, and composing the two is exactly what the hub's own
# `triangulate()` does internally before it compares two fits. We compose them
# the same way and in the same order -- transforms key on the native name and
# run BEFORE the rename, so a transform is never applied twice -- and drop the
# native nuisance nodes that map to no canonical parameter.

# ---- constants ---------------------------------------------------------------

# Every hub fit is written in the same formula interlingua and reaches the
# engine through the same model-frame preparation, so those two independence
# components are shared across the whole hub whatever the engine underneath.
.HUB_PRIORS <- "hub_interlingua"
.HUB_DATA_PREP <- "hub"

# ---- internal helpers --------------------------------------------------------

# The two hub-wide components, filled in around a per-engine sampler and
# objective.
.hub_shares <- function(sampler, objective) {
  # The hub's INLA path passes no `control.fixed` unless the caller sets
  # `prior_fixed_sd`, so INLA's own default fixed-effect prior applies
  # (precision 0.001, an informative N(0, 31.6^2) on a coefficient measured in
  # tens); the brms path carries the hub's prior interlingua. The two engines
  # therefore do not share a prior and must not be weighted as if they did.
  priors <- if (identical(objective, "inla")) "hub_inla_default" else .HUB_PRIORS
  c(sampler = sampler, objective = objective,
    priors = priors, data_prep = .HUB_DATA_PREP)
}

# The koine wrapper is not a hub fit: its opinion is a stacking mixture over
# koine's own battery, under koine's own fixed priors (declared `koine_scaled`
# when the wrapper standardised the design first, `koine_default` otherwise),
# on a design the wrapper builds itself from the hub's IR.
.koine_shares <- function(prior = "koine_scaled") {
  if (is.null(prior) || !nzchar(prior)) prior <- "koine_default"
  c(sampler = "koine_stack", objective = "koine",
    priors = prior, data_prep = "quorum")
}

# What a fit's class says about the estimate behind it: which sampler produced
# the draws, which objective it targeted, and which package the estimate comes
# from. NULL for a class no adapter covers, which the caller turns into a typed
# `unsupported_fit` decline rather than guessing.
.fit_profile <- function(fit) {
  if (inherits(fit, "flexybayes_koine")) {
    list(sampler = "koine_stack", objective = "koine", member = "koine")
  } else if (inherits(fit, "flexybayes_inla")) {
    list(sampler = "laplace", objective = "inla", member = "flexyBayes")
  } else if (inherits(fit, "flexybayes_brms")) {
    list(sampler = "stan_nuts", objective = "brms", member = "flexyBayes")
  } else {
    NULL
  }
}

# The canonical parameter draws for any fit carrying a `canonical_names()`
# mapper: the backend's own draws, its value transforms applied on the native
# names, then the rename, then the nuisance nodes dropped. A backend with an
# empty map is already canonical (koine's self-naming wrapper) and passes
# through untouched. Returns a `quorum_draws` or a typed abstention; a fit that
# cannot hand over draws is a fact about that fit, not a programmer error.
.hub_draws <- function(fit, n_samples, source) {
  raw <- tryCatch(
    flexyBayes::fb_as_draws_simple(fit, n_samples = as.integer(n_samples)),
    error = function(e) e
  )
  if (inherits(raw, "error")) {
    return(quorum_abstention("draws_unavailable", conditionMessage(raw),
                             scope = "lens"))
  }
  if (!is.list(raw) || length(raw) == 0L || is.null(names(raw))) {
    return(quorum_abstention(
      "draws_unavailable",
      "the backend returned no named draw vectors.", scope = "lens"))
  }
  cn <- tryCatch(
    flexyBayes::canonical_names(fit, drop = TRUE),
    error = function(e) list(map = character(0), transform = list())
  )
  transform <- cn$transform %||% list()
  for (nm in names(transform)) {
    if (!is.null(raw[[nm]]) && is.function(transform[[nm]])) {
      raw[[nm]] <- transform[[nm]](raw[[nm]])
    }
  }
  name_map <- cn$map %||% character(0)
  if (length(name_map) > 0L) {
    native <- names(raw)[names(raw) %in% names(name_map)]
    canonical <- as.character(name_map[native])
    # One canonical token can be spelled several ways natively (INLA's map
    # carries both "(Intercept)" and "(Intercept):1"); the first spelling the
    # backend actually returned wins, so the result never carries a duplicated
    # parameter name.
    keep <- !duplicated(canonical)
    raw <- stats::setNames(raw[native][keep], canonical[keep])
  }
  if (length(raw) == 0L) {
    return(quorum_abstention(
      "draws_unavailable",
      "no canonical parameter survived the backend's name map.",
      scope = "lens"))
  }
  tryCatch(
    quorum_draws(raw, kind = "parameters", source = source,
                 diagnostics = list(n_samples = as.integer(n_samples))),
    error = function(e) {
      quorum_abstention("draws_malformed", conditionMessage(e), scope = "lens")
    }
  )
}

# koine's own fourth-column decline, re-typed as this package's decline. The
# nested reason and detail travel with it so a reader learns why koine stood
# down without reaching into the wrapper.
.koine_decline <- function(fit) {
  quorum_abstention(
    "lens_abstained",
    paste0("koine declined this model: ",
           fit$extras$reason %||% "reason not recorded", "."),
    scope = "lens",
    nested_reason = fit$extras$reason,
    nested_detail = fit$extras$detail
  )
}

# The hub's parsed model, from whatever the caller had to hand.
#
# `emit_koine()` needs the `fb_terms` intermediate representation, and a caller
# holding a hub fit does not always know where on it that lives: some fits
# carry the IR at `$fb` and others carry it at `$extras$fb_terms`, with `$fb`
# NULL. Reading only one of the two would make the koine lens abstain on half
# the fits the hub produces, for a reason that has nothing to do with koine's
# corner. An `fb_terms` passes straight through; a fit-shaped list is searched
# in both places; anything that is neither is a programmer error and says so
# rather than being quietly declined.
.resolve_fb_terms <- function(spec) {
  if (inherits(spec, "fb_terms")) {
    return(spec)
  }
  if (!is.list(spec)) {
    stop("`spec` must be an fb_terms object or a fitted hub model carrying ",
         "one; got ", paste(class(spec), collapse = "/"), ".", call. = FALSE)
  }
  found <- spec$fb %||% spec$extras$fb_terms
  if (inherits(found, "fb_terms")) found else NULL
}

# ---- a lens from a fitted model ----------------------------------------------

#' Wrap a fitted hub or koine model as a lens
#'
#' Turns a model somebody has already fitted into a lens the comparison can
#' read. The draws are taken once, at wrap time, and canonicalised: the fit's
#' native parameter names become the hub's canonical tokens -- `(Intercept)`,
#' one per fixed-effect term, `sigma`, and `sd_<group>` for each random-effect
#' group -- with the variance components on the standard-deviation scale
#' whatever the engine stored. That is what lets an INLA lens, a brms lens and
#' the koine lens be compared component by component instead of by position.
#'
#' The independence declaration is read off the fit's class rather than asked
#' for, because the caller holding a fitted object cannot be expected to
#' restate what the engine that produced it already determines. An INLA fit
#' declares the Laplace sampler and the INLA objective, a brms fit declares
#' Stan's NUTS sampler and the brms objective, and the koine wrapper declares
#' koine's stacked battery and koine's own objective; all three declare the hub's formula
#' interlingua and the hub's data preparation, which they genuinely do share.
#'
#' A class no adapter covers, an engine that cannot hand over its draws, and a
#' koine wrapper that already stood down all return a [quorum_abstention()]
#' rather than a lens. None of the three is a programmer error: they are facts
#' about the fit, and a comparison that receives them can carry on with the
#' lenses it does have.
#'
#' @param fit A fitted model: a `flexybayes_inla` fit, a `flexybayes_brms` fit,
#'   or the `flexybayes_koine` wrapper [emit_koine()] returns.
#' @param name Single non-empty string naming the lens, or `NULL` (the default)
#'   to name it after the objective -- `"inla"`, `"brms"` or `"koine"`.
#' @param n_samples Number of posterior draws to take. It reaches the engine's
#'   sampler on the INLA path, where the draws are generated on demand, and is
#'   ignored by backends that already carry every draw they kept.
#' @param expresses Character subset of `linear`, `plateau`, `threshold` and
#'   `nonmonotone` naming the response shapes this parameterisation can
#'   express. The default is `linear` because a fit's expressiveness is a
#'   property of the model formula, which this function does not read.
#' @return A [quorum_lens()] whose `fit()` returns the canonicalised draws, or
#'   a [quorum_abstention()] with reason `unsupported_fit` (no adapter for the
#'   class), `lens_abstained` (koine stood down, with the nested reason
#'   attached), `draws_unavailable` (the engine could not hand over draws) or
#'   `draws_malformed` (the draws did not form a posterior).
#' @seealso [lens_koine()] to fit koine rather than wrap an existing fit,
#'   [lens_from_draws()] for draws that need no adapter at all.
#' @examples
#' # An object no adapter covers is declined by name, never guessed at.
#' a <- lens_from_fit(structure(list(), class = "lm"))
#' is_quorum_abstention(a)
#' a$reason
#' @export
lens_from_fit <- function(fit, name = NULL, n_samples = 1000L,
                          expresses = "linear") {
  if (!is.numeric(n_samples) || length(n_samples) != 1L ||
        !is.finite(n_samples) || n_samples < 1L) {
    stop("`n_samples` must be a single positive number of draws.",
         call. = FALSE)
  }
  profile <- .fit_profile(fit)
  if (is.null(profile)) {
    return(quorum_abstention(
      "unsupported_fit",
      paste0("no lens adapter for an object of class ",
             paste(class(fit), collapse = "/"), "."),
      scope = "lens"))
  }
  if (identical(profile$objective, "koine") &&
        identical(fit$status, "abstained")) {
    return(.koine_decline(fit))
  }
  draws <- .hub_draws(fit, n_samples, source = profile$objective)
  if (is_quorum_abstention(draws)) {
    return(draws)
  }
  lens_from_draws(
    draws,
    name = name %||% profile$objective,
    member = profile$member,
    shares = if (inherits(fit, "flexybayes_koine")) {
      .koine_shares(fit$extras$prior)
    } else {
      .hub_shares(profile$sampler, profile$objective)
    },
    expresses = expresses
  )
}

# ---- the koine fourth opinion as a lens --------------------------------------

#' The koine fourth opinion as a lens
#'
#' Declares koine's synthesised opinion as a lens without fitting anything yet.
#' The lens's `fit()` calls [emit_koine()] on the specification and data it is
#' handed and canonicalises the result. The specification is the hub's
#' `fb_terms` intermediate representation; a fitted hub model is accepted in
#' its place and the representation is taken from it, because different hub
#' fits carry it at `$fb` and at `$extras$fb_terms` and a lens that read only
#' one of the two would decline half the hub's fits for a reason that has
#' nothing to do with koine. koine is already self-naming, so the
#' canonicalisation is a
#' pass-through there; it is the same code path a hub fit takes, which is what
#' keeps the two lenses' parameter tokens identical by construction rather than
#' by coincidence.
#'
#' koine is the independent witness on the methodological axis: a stacked battery of independent lenses
#' synthesised into one opinion, not another sampler over the hub's objective.
#' Its corner is a population GLM with at most two crossed or nested random
#' intercepts, and outside that corner -- or whenever koine's own convergence
#' gate fires -- it stands down. The lens re-types that as a `lens_abstained`
#' decline carrying koine's own reason, so an abstaining lens contributes no
#' number to the quorum and the reader still learns why.
#'
#' @param name Single non-empty string naming the lens.
#' @param ... Further arguments passed to [emit_koine()] at fit time, such as
#'   `n_samples` (the count of opinion draws to synthesise) and `seed`.
#' @return A [quorum_lens()] of kind `parameters` whose `fit(spec, data)`
#'   returns a [quorum_draws()] over the canonical parameters, or a
#'   [quorum_abstention()] with reason `engine_missing` (koine is not
#'   installed), `spec_missing` (the fitted model handed in carries no parsed
#'   model), `lens_abstained` (koine stood down on this model, with the nested
#'   reason attached) or `draws_unavailable`.
#' @seealso [emit_koine()] for the opinion itself, [lens_from_fit()] to wrap a
#'   koine fit already in hand.
#' @examples
#' l <- lens_koine()
#' S7::prop(l, "shares")
#' @export
lens_koine <- function(name = "koine", ...) {
  koine_args <- list(...)
  fit_koine <- function(spec, data, ...) {
    if (!requireNamespace("koine", quietly = TRUE)) {
      return(quorum_abstention(
        "engine_missing",
        "package 'koine' (>= 0.2.0) is not installed.", scope = "lens"))
    }
    fb <- .resolve_fb_terms(spec)
    if (is.null(fb)) {
      return(quorum_abstention(
        "spec_missing",
        "the fitted model carries no fb_terms at `$fb` or `$extras$fb_terms`.",
        scope = "lens"))
    }
    fit <- do.call(emit_koine, c(list(fb, data), koine_args))
    if (identical(fit$status, "abstained")) {
      return(.koine_decline(fit))
    }
    .hub_draws(fit, n_samples = 1000L, source = "koine")
  }
  quorum_lens(
    name = name,
    member = "koine",
    fit = fit_koine,
    shares = .koine_shares(if (isFALSE(koine_args$standardise)) {
      "koine_default"
    } else {
      "koine_scaled"
    }),
    expresses = "linear",
    kind = "parameters"
  )
}

# ---- the status-quo lens -----------------------------------------------------

#' The status quo as a lens
#'
#' A constant over the candidate grid: the rate a grower already applies, the
#' variety already sown, the decision the analysis is being asked to improve
#' on. It is the lens every comparison needs and no member emits, and it is the
#' fallback a resolution policy carries when no quorum forms.
#'
#' It declares `"none"` for all four independence components, so it shares
#' nothing with any lens that came from an engine and the ledger gives every
#' such pair the full evidential weight. It expresses no response shape at all,
#' which is the point: a constant cannot show a plateau or a threshold, so the
#' shape-finding rule must never read one into it.
#'
#' @param value Single finite number, the status-quo response held across the
#'   whole grid.
#' @param grid Non-empty numeric vector of candidate values -- nitrogen rates,
#'   sowing dates, whatever the decision ranges over.
#' @param name Single non-empty string naming the lens.
#' @return A [quorum_lens()] of kind `response_curve` whose `fit()` returns a
#'   one-row [quorum_draws()] matrix of `value` over `grid`.
#' @examples
#' l <- lens_status_quo(value = 3.2, grid = c(0, 40, 80, 120))
#' d <- S7::prop(l, "fit")(NULL, NULL)
#' dim(S7::prop(d, "draws"))
#' @export
lens_status_quo <- function(value, grid, name = "status_quo") {
  if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
    stop("`value` must be a single finite number.", call. = FALSE)
  }
  if (!is.numeric(grid) || length(grid) == 0L) {
    stop("`grid` must be a non-empty numeric vector.", call. = FALSE)
  }
  draws <- quorum_draws(
    matrix(as.numeric(value), nrow = 1L, ncol = length(grid)),
    kind = "response_curve",
    grid = grid,
    source = "status_quo",
    diagnostics = list(value = as.numeric(value))
  )
  lens_from_draws(
    draws,
    name = name,
    member = "quorum",
    shares = c(sampler = "none", objective = "none", priors = "none",
               data_prep = "none"),
    expresses = character(0)
  )
}

# ---- the mechanism lens ------------------------------------------------------

# Which package the mechanism estimate comes from, read off the ensemble's own
# provenance rather than assumed: a PESTO calibration manifest names "pesto",
# and anything else names whatever producer the C5 ingest recorded.
.mechanism_member <- function(ensemble) {
  source <- ensemble$provenance$source %||% "raw"
  if (identical(source, "pesto")) "PESTO" else source
}

# The outputs columns carrying the response over the candidate grid.
#
# `output` selects among several output sets: a character vector of column
# names takes those columns in the order given, and a single string is also
# matched against `output_dims$variable`, the long labelling the C5 contract
# carries when the ensemble came from a labelled simulator run. NULL takes
# every column, which is right for a single-output ensemble and makes a
# multi-output one fail the grid check by name rather than silently pooling
# two variables into one curve. An unmatched selection returns no columns,
# which the caller reports as the grid mismatch it is.
.mechanism_columns <- function(ensemble, output) {
  nms <- colnames(ensemble$outputs)
  if (is.null(output)) {
    return(nms)
  }
  if (!is.character(output) || length(output) == 0L) {
    stop("`output` must be NULL or a character vector of output names.",
         call. = FALSE)
  }
  if (all(output %in% nms)) {
    return(output)
  }
  dims <- ensemble$output_dims
  if (length(output) == 1L && is.data.frame(dims) && !is.null(dims$variable)) {
    return(nms[as.character(dims$variable) == output])
  }
  character(0)
}

#' A simulation ensemble as a mechanism lens
#'
#' Reads a simulation ensemble as a lens on the response over a candidate
#' grid: one row of the ensemble's outputs per ensemble member, one column per
#' grid point. The simulator is the most independent witness the orchestra has
#' -- it shares no sampler, no objective, no priors and no data preparation
#' with any statistical lens -- and it is the only lens that can express a
#' plateau, a threshold or a non-monotone response without being told to look
#' for one, so it declares all four shapes.
#'
#' quorum never runs the simulator. The ensemble is produced upstream and
#' reaches this function through the C5 ingest contract, so a
#' `pesto_ensemble_manifest`, a saved ensemble and a bare list carrying
#' `params` and `outputs` are all accepted on the same terms.
#'
#' The grid check is the substance of this adapter. An ensemble whose outputs
#' do not cover the grid -- the wrong number of columns, or numerically-named
#' columns naming different values from the grid -- is a mismatch between two
#' descriptions of the same axis, and reading it anyway would silently attach
#' the simulator's response to the wrong candidates. It returns a typed
#' `grid_mismatch` decline instead.
#'
#' @param ensemble A simulation ensemble: an [fb_ensemble()], a PESTO
#'   calibration manifest, a saved `.rds` path, or a list carrying `params` and
#'   `outputs`. It reaches the canonical shape through [as_fb_ensemble()], so
#'   an object no coercer covers is a programmer error rather than a decline.
#' @param grid Non-empty numeric vector of candidate values the response is
#'   read over.
#' @param output Which output columns carry the response, when the ensemble
#'   holds more than one output set: a character vector of column names, or a
#'   single string naming a value of the ensemble's `output_dims$variable`.
#'   `NULL` (the default) takes every output column, which is right for a
#'   single-output ensemble.
#' @param name Single non-empty string naming the lens.
#' @return A [quorum_lens()] of kind `response_curve` whose `fit()` returns a
#'   [quorum_draws()] matrix with one row per ensemble member and one column
#'   per grid point, or a [quorum_abstention()] with reason `grid_mismatch`
#'   (the selected outputs do not cover the grid) or `outputs_not_numeric`
#'   (the selected columns do not hold a numeric response).
#' @seealso [fb_ensemble()] and [as_fb_ensemble()] for the ingest contract.
#' @examples
#' ens <- fb_ensemble(
#'   params = data.frame(k = c(0.1, 0.2, 0.3)),
#'   outputs = data.frame(a = c(4.1, 4.6, 5.0), b = c(5.2, 5.9, 6.1))
#' )
#' l <- lens_mechanism(ens, grid = c(0, 50))
#' dim(S7::prop(S7::prop(l, "fit")(NULL, NULL), "draws"))
#'
#' # A grid the outputs do not cover is declined, not stretched to fit.
#' is_quorum_abstention(lens_mechanism(ens, grid = c(0, 50, 100)))
#' @export
lens_mechanism <- function(ensemble, grid, output = NULL,
                           name = "mechanism") {
  if (!is.numeric(grid) || length(grid) == 0L) {
    stop("`grid` must be a non-empty numeric vector.", call. = FALSE)
  }
  ens <- as_fb_ensemble(ensemble)
  columns <- .mechanism_columns(ens, output)
  if (length(columns) != length(grid)) {
    return(quorum_abstention(
      "grid_mismatch",
      paste0("the selected outputs give ", length(columns),
             " column(s) for a grid of ", length(grid), " point(s)."),
      scope = "lens"))
  }
  labelled <- suppressWarnings(as.numeric(columns))
  if (!anyNA(labelled) &&
        !isTRUE(all.equal(labelled, as.numeric(grid), check.names = FALSE))) {
    return(quorum_abstention(
      "grid_mismatch",
      paste0("the outputs are labelled with grid values (",
             paste(columns, collapse = ", "), ") that differ from the grid (",
             paste(grid, collapse = ", "), ")."),
      scope = "lens"))
  }
  values <- as.matrix(ens$outputs[, columns, drop = FALSE])
  if (!is.numeric(values)) {
    return(quorum_abstention(
      "outputs_not_numeric",
      paste0("the selected output columns (",
             paste(columns, collapse = ", "), ") are not numeric."),
      scope = "lens"))
  }
  dimnames(values) <- NULL
  draws <- quorum_draws(
    values,
    kind = "response_curve",
    grid = grid,
    source = ens$provenance$source %||% "ensemble",
    diagnostics = list(n_members = nrow(values), outputs = columns)
  )
  lens_from_draws(
    draws,
    name = name,
    member = .mechanism_member(ens),
    shares = c(sampler = "ies", objective = "simulator", priors = "ensemble",
               data_prep = "pesto"),
    expresses = .LENS_SHAPES
  )
}
