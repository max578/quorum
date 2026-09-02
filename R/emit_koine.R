# emit_koine.R -- activates the koine fourth-opinion slot from the companion.
#
# koine is the synthesised fourth opinion on flexyBayes's orthogonal lens axis
# (the orchestra's C1 backend seam + the C3 koine_pass / koine_result contract).
# The 0.7.0 lean-core split moved koine out of flexyBayes core; this companion is
# now its home. Activation does NOT touch lean core: core's exported
# `triangulate()` is generic over fit objects, dispatching through the exported
# generics `fb_as_draws_simple()` and `canonical_names()`. We register methods
# for those generics on a `flexybayes_koine` fit, so triangulate consumes koine
# as its fourth column without any core edit (the lean-0.7.0 boundary holds).
#
# emit_koine() translates flexyBayes's `fb_terms` IR to koine's IR-targetable
# array builder (koine::koine_pass_from_design, backend-contract clause 1),
# synthesises one opinion over koine's OWN battery (koine::synthesise -- a single
# independent witness on the lens axis, never a pool across the engine-axis
# backends; C3 + koine charter), and returns it as a draws-bearing
# `flexybayes_koine` object -- or an honest abstained object (the "fourth column
# = abstained" when koine cannot add diversity).
#
# koine's corner widened at 0.3.0: as well as a population GLM and a single
# random intercept (1 | g), it fields the breeder-standard multi-environment
# trial (MET) structure of TWO crossed or nested random intercepts,
# (1 | variety) + (1 | trial), through the `groups` argument of
# koine_pass_from_design() (probed on the installed namespace, not assumed).
# Routing the MET case through `groups` is what stops the fourth opinion
# abstaining on every multi-environment model. Richer random structure -- random
# slopes, correlated effects, more than two groupings -- is still outside the
# corner, and the capability gate below refuses it before any koine call.

# ---- capability constants + the typed abstained object ----------------------

# koine's random-effects corner: at most two groupings (a single random
# intercept, or the crossed / nested MET pair), each a plain intercept. The
# accepted `fb_terms` type tokens for "a plain random intercept".
.KOINE_MAX_GROUPINGS <- 2L
.KOINE_INTERCEPT_TYPES <- c("simple", "ide", "id", "iid", "intercept")

# Prepend the fleet-recognised decline stamp to an outer `flexybayes_koine`
# wrapper's class vector, idempotently. The orchestra's cross-member
# refusal/abstention contract (ORCHESTRA_dev's `integration/refusal_contract.R`
# -- `is_orchestra_decline()`) is producer-agnostic: it recognises any class
# ending in `_refusal` / `_abstention`, or the explicit `orchestra_refusal`
# marker, but it only ever inspects the OUTER object a caller actually holds.
# `emit_koine()`'s abstained exit already carries a real, correctly-typed
# nested `koine_abstention` at `$koine` -- koine's own honest decline -- but
# the outer wrapper itself was always plain `c("flexybayes_koine", "list")`,
# invisible to that predicate. Stamping `"quorum_abstention"`
# (this package's own member-specific suffix, matching every other member's
# `<member>_abstention` naming convention) ahead of `"orchestra_refusal"`
# (the explicit opt-in marker) makes the outer object dispatchable while
# `class(x)[-(1:2)]` -- and every existing `inherits(x, "flexybayes_koine")` /
# `is.list(x)` consumer -- is unchanged: the original two-element class vector
# is preserved, just with two names prepended.
.stamp_flexybayes_koine_abstention <- function(x) {
  cls <- class(x)
  new_cls <- c("quorum_abstention", "orchestra_refusal")
  class(x) <- c(new_cls[!new_cls %in% cls], cls)
  x
}

# Mint the honest fourth column: a typed `flexybayes_koine` carrying koine's own
# abstention out of koine's corner, never a silently wrong opinion. The outer
# wrapper is itself stamped as an orchestra decline (see
# `.stamp_flexybayes_koine_abstention()`), so a fleet-level gate sees it
# without having to reach into `$koine`.
.koine_abstained <- function(fb, data, the_call, reason, detail) {
  .stamp_flexybayes_koine_abstention(structure(
    list(
      koine = koine::abstention(reason, scope = "synthesis", detail = detail),
      draws = NULL, koine_draws = NULL, fb = fb, data = data,
      status = "abstained",
      extras = list(status = "abstained", reason = reason, detail = detail,
                    the_call = the_call)
    ),
    class = c("flexybayes_koine", "list")
  ))
}

# ---- the headline verb: emit the koine fourth opinion -----------------------

#' Emit a koine fourth-opinion fit for triangulation
#'
#' Activates the koine lens-axis backend from the companion. Given a flexyBayes
#' `fb_terms` intermediate representation (the `$fb` element of any core fit) and
#' the model frame, `emit_koine()` synthesises koine's fourth opinion and returns
#' a `flexybayes_koine` object that [flexyBayes::triangulate()] consumes
#' alongside an engine-axis fit (greta / INLA / brms / gretaR).
#'
#' koine's corner is a population GLM for the gaussian, binomial, and poisson
#' families, with either a single random intercept `(1 | g)` or -- from koine
#' 0.3.0 -- the breeder-standard multi-environment-trial structure of two
#' crossed or nested random intercepts, `(1 | variety) + (1 | trial)`. A single
#' grouping is routed through `koine_pass_from_design(group = )`; two groupings
#' are routed through `koine_pass_from_design(groups = )`, koine's crossed /
#' nested entry, and whether they are crossed or nested is resolved by koine
#' from the data. Outside that corner -- more than two groupings, a random
#' slope, a correlated random structure, koine below 0.3.0 on a two-grouping
#' model -- or whenever koine's own convergence gate fires, the returned object
#' carries `status = "abstained"`, the honest fourth column. The synthesised
#' opinion is a stacking mixture over koine's battery, an independent witness on
#' the orthogonal lens axis, never a pool across the engine-axis backends.
#'
#' Activation is gated by [koine_status()]: koine installed at or above
#' `0.2.0` and `options(quorum.koine_activated = TRUE)` (the
#' default). The draws are canonicalised to flexyBayes's parameter tokens, so the
#' fit is self-naming and needs no `name_map` at the triangulate seam: the group
#' SDs koine reports as `tau` / `tau_<grouping>` become `sd_<grouping>`.
#'
#' @param fb An `fb_terms` object (the `$fb` element of a core flexyBayes fit).
#' @param data The model frame the fit was built on.
#' @param n_samples Integer count of opinion draws to synthesise.
#' @param seed Integer RNG seed, pinned for reproducibility regardless of caller
#'   RNG state.
#' @param the_call Optional originating call, carried into the fit's extras.
#' @param ... Reserved for future use.
#'
#' @return A `flexybayes_koine` object: a list with `status`
#'   (`"contributed"` or `"abstained"`), the canonicalised `draws`, the koine
#'   `koine` result, the `fb` IR, and an `extras` record (stacking weights,
#'   stacked ELPD, independence and diagnostics on the contributed path; the
#'   refusal reason and detail on the abstained path). On the abstained path
#'   the object's class additionally carries `"quorum_abstention"`
#'   and `"orchestra_refusal"` prepended ahead of `"flexybayes_koine"`, so a
#'   producer-agnostic decline predicate (any class ending in `_refusal` /
#'   `_abstention`, or the `orchestra_refusal` marker) recognises the outer
#'   object without inspecting `$koine`; `inherits(x, "flexybayes_koine")` and
#'   every `*.flexybayes_koine` method still dispatch unchanged.
#'
#' @seealso [koine_status()] for the activation state; [flexyBayes::triangulate()]
#'   for the consumption seam.
#' @export
emit_koine <- function(fb, data, n_samples = 4000L, seed = 1L,
                       the_call = NULL, ...) {
  if (!inherits(fb, "fb_terms")) {
    stop("`fb` must be an fb_terms object (the `$fb` of a flexyBayes fit).",
         call. = FALSE)
  }
  if (!requireNamespace("koine", quietly = TRUE)) {
    stop("Package 'koine' (>= 0.2.0) is required to emit a koine opinion.",
         call. = FALSE)
  }

  # Capability gate -- koine fields a population GLM with either a single random
  # intercept (1 | g) or, from 0.3.0, the MET structure of two crossed / nested
  # random intercepts. A richer random structure is out of corner; abstain
  # honestly before any koine call (never a silent wrong fourth opinion).
  n_re <- length(fb$random_terms)
  re_ok <- n_re <= .KOINE_MAX_GROUPINGS &&
    (n_re == 0L ||
       all(vapply(fb$random_terms, function(t) {
         isTRUE(t$type %in% .KOINE_INTERCEPT_TYPES)
       }, logical(1L))))
  if (!re_ok) {
    return(.koine_abstained(
      fb, data, the_call, "feature_unsupported",
      paste0("koine fields at most two crossed or nested random intercepts; ",
             "this model carries ", n_re, " random term(s), not all of them ",
             "plain intercepts.")))
  }
  # The MET (two-grouping) entry is koine 0.3.0's `groups` argument. Below that
  # floor koine has only the single-`group` entry, so a MET is genuinely out of
  # the installed member's corner -- say so rather than silently fitting one
  # grouping and calling it the fourth opinion.
  if (n_re > 1L && !.koine_met_version_ok()) {
    return(.koine_abstained(
      fb, data, the_call, "feature_unsupported",
      paste0("the two-grouping (MET) entry needs koine (>= ",
             .KOINE_MET_VERSION_FLOOR, "); installed koine is ",
             as.character(utils::packageVersion("koine")), ".")))
  }

  # IR -> koine design arrays. The fixed part is rebuilt from fb's fixed terms;
  # the single random intercept's grouping factor becomes koine's `group`.
  labs <- vapply(fb$fixed_terms, function(t) {
    if (!is.null(t$vars)) paste(t$vars, collapse = ":") else t$var
  }, character(1))
  ff <- if (length(labs)) {
    stats::reformulate(labs, response = fb$response,
                       intercept = isTRUE(fb$intercept))
  } else {
    stats::reformulate("1", response = fb$response)
  }
  x <- stats::model.matrix(ff, stats::model.frame(ff, data))
  y <- data[[fb$response]]
  grp_vars <- vapply(fb$random_terms, function(t) t$var, character(1L))
  # One grouping -> koine's `group`; two -> koine's `groups` (the crossed /
  # nested MET entry, koine >= 0.3.0). The two arguments are mutually exclusive
  # in koine, so exactly one is supplied.
  group <- if (length(grp_vars) == 1L) factor(data[[grp_vars]]) else NULL
  groups <- if (length(grp_vars) == 2L) {
    stats::setNames(
      lapply(grp_vars, function(v) factor(data[[v]])),
      grp_vars
    )
  } else {
    NULL
  }

  # Pin the RNG so the synthesised opinion is reproducible regardless of the
  # caller's RNG state; koine's per-lens seeds derive from the pass seed, but a
  # belt-and-braces set.seed here guarantees determinism even if a lens leaks
  # global RNG.
  t0 <- proc.time()
  set.seed(seed)
  pass <- koine::koine_pass_from_design(x, y, fb$family, group = group,
                                        groups = groups, seed = seed)
  res <- koine::synthesise(pass, keep_fits = TRUE)
  elapsed <- unname((proc.time() - t0)["elapsed"])

  # The resolved model shape, recorded on BOTH exits: a reader (and the study
  # harness) must be able to see which koine entry the model was routed
  # through even when koine's own convergence gate then declined it.
  model_info <- list(
    n_obs = nrow(data), n_fixed = ncol(x), groupings = grp_vars,
    re_structure = if (length(grp_vars) == 2L) {
      "met"
    } else if (length(grp_vars) == 1L) {
      "single_intercept"
    } else {
      "population"
    },
    family = fb$family, link = fb$link
  )

  if (koine::is_abstention(res)) {
    return(.stamp_flexybayes_koine_abstention(structure(list(
      koine = res, draws = NULL, koine_draws = NULL, fb = fb, data = data,
      status = "abstained",
      extras = list(status = "abstained", reason = res$reason,
                    detail = res$detail, model_info = model_info,
                    run_time = elapsed,
                    the_call = the_call, formula = ff)),
      class = c("flexybayes_koine", "list"))))
  }

  draws <- .koine_canonicalise_draws(
    koine::koine_opinion_draws(res, n_draws = n_samples), fb)
  structure(list(
    koine = res, draws = draws, koine_draws = draws, fb = fb, data = data,
    status = "contributed",
    extras = list(
      status = "contributed",
      weights = res$opinion$weights,
      elpd_stacked = res$opinion$elpd_stacked,
      independence = res$independence,
      diagnostics = res$diagnostics,
      model_info = model_info,
      run_time = elapsed, the_call = the_call, formula = ff)),
    class = c("flexybayes_koine", "list"))
}

# Rename koine's native draw variables to flexyBayes's canonical tokens so the
# fit is SELF-NAMING: `b_<col>` -> `<col>`, `sigma` stays, and `tau` (the
# random-intercept SD) -> the group-SD token `sd_<grouping>` (matching the INLA
# mapper). koine's draws are already SD-scale, so no value transform is needed.
.koine_canonicalise_draws <- function(draws, fb) {
  vars <- dimnames(draws)[[3L]]
  grp <- tryCatch(fb$random_terms[[1L]]$var, error = function(e) NULL)
  if (is.null(grp) || !nzchar(grp)) grp <- "g"
  canon <- vapply(vars, function(v) {
    if (identical(v, "sigma")) {
      "sigma"
    } else if (identical(v, "tau")) {
      # single-grouping model: koine names the one group SD `tau`
      paste0("sd_", grp)
    } else if (grepl("^tau_", v)) {
      # MET: koine names the two group SDs `tau_<grouping>`
      sub("^tau_", "sd_", v)
    } else {
      sub("^b_", "", v)
    }
  }, character(1))
  dimnames(draws)[[3L]] <- unname(canon)
  draws
}

# ---- triangulate-seam S3 methods on flexyBayes core generics ----------------

#' Extract simple draws from a koine fit (triangulate seam)
#'
#' S3 method on flexyBayes's exported `fb_as_draws_simple()` generic. Returns a
#' named list of numeric draw vectors over the canonical parameters, the shape
#' [flexyBayes::triangulate()] aligns on.
#'
#' @param fit A `flexybayes_koine` object.
#' @param n_samples Unused (koine draws are pre-synthesised); kept for generic
#'   signature compatibility.
#' @param ... Unused.
#' @return A named list of numeric vectors, one per canonical parameter.
#' @exportS3Method flexyBayes::fb_as_draws_simple
fb_as_draws_simple.flexybayes_koine <- function(fit, n_samples = 1000L, ...) {
  if (identical(fit$status, "abstained") || is.null(fit$draws)) {
    stop("koine abstained on this model; there are no draws to extract.",
         call. = FALSE)
  }
  if (!requireNamespace("posterior", quietly = TRUE)) {
    stop("Package 'posterior' is required to extract koine draws.",
         call. = FALSE)
  }
  m <- as.matrix(posterior::as_draws_matrix(fit$draws))
  stats::setNames(lapply(seq_len(ncol(m)), function(j) as.numeric(m[, j])),
                  colnames(m))
}

#' Canonical names for a koine fit (self-naming)
#'
#' S3 method on flexyBayes's exported `canonical_names()` generic. koine is
#' self-naming -- `emit_koine()` canonicalises the draws -- so no relabel map is
#' needed; triangulate aligns on the already-canonical names.
#'
#' @param fit A `flexybayes_koine` object.
#' @param drop Unused; kept for generic signature compatibility.
#' @param ... Unused.
#' @return A list with an empty `map`, empty `transform`, and
#'   `source = "self_naming"`.
#' @exportS3Method flexyBayes::canonical_names
canonical_names.flexybayes_koine <- function(fit, drop = FALSE, ...) {
  list(map = character(0), transform = list(), source = "self_naming")
}

# ---- summary + display methods ----------------------------------------------

#' Posterior-mean coefficients for a koine fit
#'
#' @param object A `flexybayes_koine` object.
#' @param ... Unused.
#' @return A named numeric vector of koine's synthesised posterior means.
#' @export
coef.flexybayes_koine <- function(object, ...) {
  if (identical(object$status, "abstained") || is.null(object$draws)) {
    stop("koine abstained on this model; there are no coefficients.",
         call. = FALSE)
  }
  if (!requireNamespace("posterior", quietly = TRUE)) {
    stop("Package 'posterior' is required to summarise koine draws.",
         call. = FALSE)
  }
  m <- as.matrix(posterior::as_draws_matrix(object$draws))
  stats::setNames(colMeans(m), colnames(m))
}

#' Print a koine fourth-opinion fit
#'
#' @param x A `flexybayes_koine` object.
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @export
print.flexybayes_koine <- function(x, ...) {
  cat("Bayesian fit  [flexybayes_koine / koine lens-axis backend]\n")
  cat(strrep("-", 55), "\n")
  if (identical(x$status, "abstained")) {
    cat("  status: ABSTAINED (", x$extras$reason, ")\n", sep = "")
    cat("  ", x$extras$detail, "\n", sep = "")
  } else {
    w <- x$extras$weights
    cat("  status:  contributed (synthesised lens-axis opinion)\n")
    cat("  weights: ", paste(names(w), round(w, 2), collapse = "  "), "\n",
        sep = "")
    cat("  runtime: ", round(x$extras$run_time, 2), " sec\n", sep = "")
  }
  cat(strrep("-", 55), "\n")
  invisible(x)
}
