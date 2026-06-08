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
# = abstained" when koine cannot add diversity). koine fields a population GLM +
# a single random intercept (1 | g) for gaussian / binomial / poisson; the
# capability gate below refuses the rest before any koine call.

#' Emit a koine fourth-opinion fit for triangulation
#'
#' Activates the koine lens-axis backend from the companion. Given a flexyBayes
#' `fb_terms` intermediate representation (the `$fb` element of any core fit) and
#' the model frame, `emit_koine()` synthesises koine's fourth opinion and returns
#' a `flexybayes_koine` object that [flexyBayes::triangulate()] consumes
#' alongside an engine-axis fit (greta / INLA / brms / gretaR).
#'
#' koine's corner is a population GLM with at most a single random intercept
#' `(1 | g)` for the gaussian, binomial, and poisson families. Outside that
#' corner -- or whenever koine's own convergence gate fires -- the returned
#' object carries `status = "abstained"`, the honest fourth column. The
#' synthesised opinion is a stacking mixture over koine's battery, an independent
#' witness on the orthogonal lens axis, never a pool across the engine-axis
#' backends.
#'
#' Activation is gated by [koine_status()]: koine installed at or above
#' `0.2.0` and `options(flexyBayesOrchestra.koine_activated = TRUE)` (the
#' default). The draws are canonicalised to flexyBayes's parameter tokens, so the
#' fit is self-naming and needs no `name_map` at the triangulate seam.
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
#'   refusal reason and detail on the abstained path).
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

  # Capability gate -- koine fields a population GLM + at most a single random
  # intercept (1 | g). A richer random structure is out of corner; abstain
  # honestly before any koine call (never a silent wrong fourth opinion).
  re_ok <- length(fb$random_terms) <= 1L &&
    (length(fb$random_terms) == 0L ||
       isTRUE(fb$random_terms[[1L]]$type %in%
                c("simple", "ide", "id", "iid", "intercept")))
  if (!re_ok) {
    return(structure(list(
      koine = koine::abstention(
        "feature_unsupported", scope = "synthesis",
        detail = "koine fields a single random intercept (1 | g) only."),
      draws = NULL, koine_draws = NULL, fb = fb, data = data,
      status = "abstained",
      extras = list(status = "abstained", reason = "feature_unsupported",
                    detail = "random structure beyond (1 | g)",
                    the_call = the_call)),
      class = c("flexybayes_koine", "list")))
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
  group <- if (length(fb$random_terms)) {
    factor(data[[fb$random_terms[[1L]]$var]])
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
                                        seed = seed)
  res <- koine::synthesise(pass, keep_fits = TRUE)
  elapsed <- unname((proc.time() - t0)["elapsed"])

  if (koine::is_abstention(res)) {
    return(structure(list(
      koine = res, draws = NULL, koine_draws = NULL, fb = fb, data = data,
      status = "abstained",
      extras = list(status = "abstained", reason = res$reason,
                    detail = res$detail, run_time = elapsed,
                    the_call = the_call, formula = ff)),
      class = c("flexybayes_koine", "list")))
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
      model_info = list(n_obs = nrow(data), n_fixed = ncol(x),
                        family = fb$family, link = fb$link),
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
      paste0("sd_", grp)
    } else {
      sub("^b_", "", v)
    }
  }, character(1))
  dimnames(draws)[[3L]] <- unname(canon)
  draws
}

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
