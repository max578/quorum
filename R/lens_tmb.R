# lens_tmb.R -- the TMB lens: one objective, a Laplace point and NUTS draws.
#
# The lens fits the quorum's shared estimand with glmmTMB -- a Laplace
# implementation of the marginal likelihood written independently of INLA's --
# and then hands the very TMB objective that fit produced to tmbstan's NUTS
# sampler. One lens therefore carries a second Laplace point AND a Hamiltonian
# posterior over the same objective, which is the pair the ladder asks for:
# a Laplace family member distinct from INLA, and the same objective sampled
# two ways. `laplace = TRUE` leaves the random effects integrated out by the
# Laplace approximation and samples the remaining parameters; `laplace = FALSE`
# samples the joint vector, random effects included.
#
# Naming. The draws carry the hub's canonical parameter tokens, exactly as
# emit_koine() canonicalises koine's draws: "(Intercept)" and the model-matrix
# column names for the fixed effects, `sd_<grouping>` for the random-intercept
# standard deviation. An INLA fit read through the hub's canonical map and this
# lens's draws therefore align component by component with no relabel step.
#
# Priors. The hub's default is uniform(0, U) on every standard deviation, with
# U = 5 * sd(y) on an identity link, 3 on a log link and 5 on a logit link.
# glmmTMB parameterises the random-effect SD by its logarithm, so its own
# default (no prior at all) is flat on log(SD) -- a density proportional to
# 1/SD, which is not integrable at zero and leaves the posterior improper for a
# weakly identified variance component. glmmTMB's prior families are normal, t,
# cauchy, gamma and lkj; the gamma row is the only one written on the SD scale.
# It enters the negative log density as -log dgamma(exp(theta), shape, scale)
# with no Jacobian term, so the implied density on the SD scale is proportional
# to SD^(shape - 2) exp(-SD / scale): shape 2 is exactly flat, and a scale set
# far above the hub's bound leaves it flat across the whole region the
# likelihood occupies. That is the hub's uniform-on-SD statement, written in
# the syntax glmmTMB has. Two parts of the hub's default have no counterpart
# there -- the hard upper bound U itself, and the uniform prior on the residual
# SD, since glmmTMB's dispersion parameter admits only log-scale prior families
# -- and both are recorded in the returned diagnostics rather than assumed
# away. `shares["priors"]` reports `"hub_matched"` when every hub prior on a
# component this lens reports (the fixed effects and the random-intercept SD)
# was carried, and `"flat"` when the lens fits under glmmTMB's own defaults.

# ---- constants ---------------------------------------------------------------

# The two engines the lens reaches through requireNamespace(); both sit in
# Suggests, so a machine without them gets a typed abstention, never an error.
.TMB_ENGINES <- c("glmmTMB", "tmbstan")

# The response families the lens fields. Anything else is refused before a fit
# is attempted rather than silently routed to a different likelihood.
.TMB_FAMILIES <- c("gaussian", "poisson", "binomial", "nbinom2")

# The fb_terms type tokens that mean "a plain random intercept", the same set
# emit_koine()'s capability gate reads.
.TMB_INTERCEPT_TYPES <- c("simple", "ide", "id", "iid", "intercept")

# The hub's uniform-on-SD upper bound is 5 * sd(y) on an identity link.
.TMB_HUB_SD_MULTIPLIER <- 5

# A gamma prior on a glmmTMB SD parameter has implied SD-scale density
# proportional to SD^(shape - 2); shape 2 is flat. The scale is set to this
# multiple of the hub's bound so the exponential factor is flat to within
# 1e-6 across the whole interval the hub's uniform prior covers.
.TMB_FLAT_SD_SHAPE <- 2L
.TMB_FLAT_SD_SPREAD <- 1e6

# ---- spec shape --------------------------------------------------------------

# Resolve the grouping factor of a single lme4-style bar term. Returns the
# grouping variable's name for a plain random intercept and NULL for anything
# else (a random slope, a correlated structure, a nested or interaction
# grouping), which the caller turns into an `out_of_scope` abstention.
.tmb_bar_group <- function(label) {
  parts <- strsplit(label, "|", fixed = TRUE)[[1L]]
  if (length(parts) != 2L) {
    return(NULL)
  }
  lhs <- trimws(parts[1L])
  rhs <- trimws(parts[2L])
  if (!identical(lhs, "1")) {
    return(NULL)
  }
  if (!grepl("^[A-Za-z.][A-Za-z0-9._]*$", rhs)) {
    return(NULL)
  }
  rhs
}

# Shape from an lme4-style two-sided formula. The formula is passed to glmmTMB
# unchanged; only its shape is checked here.
.tmb_shape_formula <- function(spec) {
  if (length(spec) != 3L) {
    return(quorum_abstention(
      "out_of_scope",
      "`spec` must be a two-sided formula naming a response.",
      scope = "lens"
    ))
  }
  labels <- attr(stats::terms(spec, keep.order = TRUE), "term.labels")
  bars <- labels[grepl("|", labels, fixed = TRUE)]
  if (length(bars) != 1L) {
    return(quorum_abstention(
      "out_of_scope",
      paste0(
        "the TMB lens fields exactly one random-intercept grouping term; ",
        "this formula carries ", length(bars), "."
      ),
      scope = "lens"
    ))
  }
  group <- .tmb_bar_group(bars)
  if (is.null(group)) {
    return(quorum_abstention(
      "out_of_scope",
      paste0(
        "the TMB lens fields a plain random intercept `(1 | g)` on a single ",
        "grouping variable; this formula carries `(", bars, ")`."
      ),
      scope = "lens"
    ))
  }
  response <- all.vars(spec[[2L]])
  list(
    formula = spec,
    response = if (length(response)) response[1L] else NA_character_,
    group = group,
    family = NULL,
    link = NULL
  )
}

# Shape from the hub's fb_terms IR. The formula is rebuilt the way
# emit_koine() rebuilds it: the fixed part from the IR's fixed-term labels,
# the intercept from the IR's own flag, and the single random intercept from
# the one grouping term the lens fields.
.tmb_shape_fb <- function(spec) {
  random <- spec$random_terms
  if (length(random) != 1L) {
    return(quorum_abstention(
      "out_of_scope",
      paste0(
        "the TMB lens fields exactly one random-intercept grouping term; ",
        "this model carries ", length(random), "."
      ),
      scope = "lens"
    ))
  }
  term <- random[[1L]]
  if (!isTRUE(term$type %in% .TMB_INTERCEPT_TYPES)) {
    return(quorum_abstention(
      "out_of_scope",
      paste0(
        "the TMB lens fields a plain random intercept; this model's random ",
        "term is of type \"", term$type %||% "<unknown>", "\"."
      ),
      scope = "lens"
    ))
  }
  group <- term$var
  if (!is.character(group) || length(group) != 1L || !nzchar(group)) {
    return(quorum_abstention(
      "out_of_scope",
      "the random term names no grouping variable.",
      scope = "lens"
    ))
  }
  labels <- vapply(
    spec$fixed_terms,
    function(t) {
      if (!is.null(t$vars)) paste(t$vars, collapse = ":") else t$var
    },
    character(1L)
  )
  formula <- stats::reformulate(
    c(labels, paste0("(1 | ", group, ")")),
    response = spec$response,
    intercept = isTRUE(spec$intercept)
  )
  list(
    formula = formula,
    response = spec$response,
    group = group,
    family = spec$family,
    link = spec$link
  )
}

# The one entry point: an lme4-style formula or the hub's fb_terms IR.
.tmb_shape <- function(spec) {
  if (inherits(spec, "fb_terms")) {
    return(.tmb_shape_fb(spec))
  }
  if (inherits(spec, "formula")) {
    return(.tmb_shape_formula(spec))
  }
  quorum_abstention(
    "out_of_scope",
    paste0(
      "`spec` must be an lme4-style formula or an fb_terms object; got ",
      paste(class(spec), collapse = "/"), "."
    ),
    scope = "lens"
  )
}

# ---- family ------------------------------------------------------------------

# Normalise a family given as a string or a base-R family object to one of the
# four names the lens fields, or an abstention naming the supported set.
.tmb_family_name <- function(family) {
  name <- if (inherits(family, "family")) family$family else family
  if (!is.character(name) || length(name) != 1L || !nzchar(name)) {
    return(quorum_abstention(
      "family_unsupported",
      "`family` must be a single family name or a family object.",
      scope = "lens"
    ))
  }
  name <- tolower(name)
  if (!name %in% .TMB_FAMILIES) {
    return(quorum_abstention(
      "family_unsupported",
      paste0(
        "the TMB lens fields ", paste(.TMB_FAMILIES, collapse = ", "),
        "; got \"", name, "\"."
      ),
      scope = "lens"
    ))
  }
  name
}

# Build the glmmTMB family object, honouring an explicit link when the spec
# carries one.
.tmb_family_object <- function(name, link = NULL) {
  use_link <- is.character(link) && length(link) == 1L && nzchar(link)
  if (identical(name, "nbinom2")) {
    return(if (use_link) glmmTMB::nbinom2(link = link) else glmmTMB::nbinom2())
  }
  builder <- switch(
    name,
    gaussian = stats::gaussian,
    poisson = stats::poisson,
    binomial = stats::binomial
  )
  if (use_link) builder(link = link) else builder()
}

# ---- priors ------------------------------------------------------------------

# The hub's uniform-on-SD upper bound for this model: 5 * sd(y) on an identity
# link, 3 on a log link, 5 on a logit link. The link branches are tested in the
# hub's own order, logit before log, so a family carrying both readings
# resolves the way the hub resolves it.
.tmb_hub_sd_bound <- function(family_name, link, data, response) {
  link_name <- if (is.character(link) && length(link) == 1L) {
    tolower(link)
  } else {
    NA_character_
  }
  if (identical(link_name, "logit") || identical(family_name, "binomial")) {
    return(5)
  }
  if (identical(link_name, "log") ||
        family_name %in% c("poisson", "nbinom2")) {
    return(3)
  }
  y <- if (is.character(response) && response %in% names(data)) {
    data[[response]]
  } else {
    NULL
  }
  if (!is.numeric(y)) {
    return(1)
  }
  y <- as.numeric(y)
  y <- y[is.finite(y)]
  if (length(y) < 2L) {
    return(1)
  }
  spread <- stats::sd(y)
  if (!is.finite(spread) || spread <= 0) {
    spread <- 1
  }
  .TMB_HUB_SD_MULTIPLIER * spread
}

# The `priors=` argument for glmmTMB, plus the record of what was carried and
# what could not be. `"flat"` writes no rows at all and declares itself so.
.tmb_prior_plan <- function(mode, family_name, link, data, response, group) {
  if (identical(mode, "flat")) {
    return(list(
      mode = "flat",
      declared = "flat",
      rows = NULL,
      hub_bound = NA_real_,
      unmatched = "every hub prior; the fit runs under glmmTMB's defaults",
      note = paste0(
        "glmmTMB's default is no prior, which is flat on log(SD) and so ",
        "proportional to 1/SD on the SD scale."
      )
    ))
  }
  bound <- .tmb_hub_sd_bound(family_name, link, data, response)
  scale <- .TMB_FLAT_SD_SPREAD * bound
  rows <- data.frame(
    prior = sprintf(
      "gamma(%.6g, %d)", .TMB_FLAT_SD_SHAPE * scale, .TMB_FLAT_SD_SHAPE
    ),
    class = "ranef_sd",
    coef = group,
    stringsAsFactors = FALSE
  )
  unmatched <- c(
    paste0(
      "the hub's upper bound uniform(0, ", format(bound, digits = 4),
      ") is carried as a flat SD-scale density without the bound"
    ),
    if (identical(family_name, "gaussian")) {
      paste0(
        "the hub's uniform prior on the residual SD: glmmTMB's dispersion ",
        "parameter admits only log-scale prior families"
      )
    }
  )
  list(
    mode = "hub",
    declared = "hub_matched",
    rows = rows,
    hub_bound = bound,
    unmatched = unmatched,
    note = paste0(
      "shape-2 gamma on the random-intercept SD; implied SD-scale density ",
      "proportional to SD^0, the hub's uniform-on-SD statement."
    )
  )
}

# ---- draws and diagnostics ---------------------------------------------------

# The stanfit column names for a glmmTMB parameter vector: rstan writes a
# length-one vector under its bare name and a longer one with a bracketed
# index, so the fixed-effect columns depend on how many there are.
.tmb_beta_columns <- function(n) {
  if (n == 1L) "beta" else paste0("beta[", seq_len(n), "]")
}

# Canonically named draws from the sampler output. Returns NULL when the
# expected parameter columns are absent, which the caller turns into a typed
# abstention rather than a mis-named draw set.
.tmb_extract_draws <- function(samples, coefs, group) {
  columns <- c(.tmb_beta_columns(length(coefs)), "theta")
  matrix_draws <- as.matrix(samples)
  if (!all(columns %in% colnames(matrix_draws))) {
    return(NULL)
  }
  beta_columns <- columns[seq_along(coefs)]
  draws <- stats::setNames(
    lapply(
      seq_along(coefs),
      function(j) as.numeric(matrix_draws[, beta_columns[j]])
    ),
    names(coefs)
  )
  draws[[paste0("sd_", group)]] <-
    exp(as.numeric(matrix_draws[, "theta"]))
  list(draws = draws, columns = columns)
}

# Worst-case R-hat over the sampled parameters the lens reports, and the total
# divergent-transition count after warmup. Both come from rstan, which tmbstan
# depends on; absent it, the two fields are reported as unavailable rather than
# invented.
.tmb_sampler_diagnostics <- function(samples, columns) {
  if (!requireNamespace("rstan", quietly = TRUE)) {
    return(list(rhat = NA_real_, n_divergent = NA_integer_))
  }
  summary_table <- rstan::summary(samples)$summary
  rows <- intersect(columns, rownames(summary_table))
  rhat <- summary_table[rows, "Rhat"]
  rhat <- rhat[is.finite(rhat)]
  params <- rstan::get_sampler_params(samples, inc_warmup = FALSE)
  divergent <- vapply(
    params,
    function(chain) sum(chain[, "divergent__"]),
    numeric(1L)
  )
  list(
    rhat = if (length(rhat)) max(rhat) else NA_real_,
    n_divergent = as.integer(sum(divergent))
  )
}

# The glmmTMB point estimates on the names the draws carry: the conditional
# fixed effects verbatim, plus the fitted random-intercept SD.
.tmb_laplace_point <- function(fit, group) {
  coefs <- glmmTMB::fixef(fit)$cond
  variance <- glmmTMB::VarCorr(fit)$cond[[group]]
  sd_hat <- if (is.null(variance)) {
    NA_real_
  } else {
    as.numeric(attr(variance, "stddev"))[1L]
  }
  c(coefs, stats::setNames(sd_hat, paste0("sd_", group)))
}

# ---- the fitter --------------------------------------------------------------

# A single positive count, or a stop() -- these are constructor arguments, not
# data-dependent conditions, so a bad one is a caller error and not an
# abstention.
.tmb_count <- function(x, what) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 1) {
    stop("`", what, "` must be a single positive integer.", call. = FALSE)
  }
  as.integer(x)
}

# The lens's fit: shape gate, family gate, glmmTMB fit, tmbstan sample,
# canonical draws. Every non-programmer failure leaves by a typed abstention.
.tmb_fit <- function(spec, data, family, laplace, n_draws, chains, iter,
                     warmup, seed, priors_mode, ...) {
  present <- vapply(
    .TMB_ENGINES, requireNamespace, logical(1L), quietly = TRUE
  )
  if (!all(present)) {
    return(quorum_abstention(
      "engine_missing",
      paste0(
        "the TMB lens needs ", paste(.TMB_ENGINES, collapse = " and "),
        "; missing: ", paste(.TMB_ENGINES[!present], collapse = ", "), "."
      ),
      scope = "lens"
    ))
  }
  shape <- .tmb_shape(spec)
  if (is_quorum_abstention(shape)) {
    return(shape)
  }
  family_name <- .tmb_family_name(shape$family %||% family)
  if (is_quorum_abstention(family_name)) {
    return(family_name)
  }
  if (!is.data.frame(data)) {
    return(quorum_abstention(
      "out_of_scope",
      "`data` must be a data frame holding the model's variables.",
      scope = "lens"
    ))
  }

  plan <- .tmb_prior_plan(
    priors_mode, family_name, shape$link, data, shape$response, shape$group
  )
  fit <- tryCatch(
    glmmTMB::glmmTMB(
      formula = shape$formula,
      data = data,
      family = .tmb_family_object(family_name, shape$link),
      priors = plan$rows
    ),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    return(quorum_abstention(
      "fit_failed",
      paste0("glmmTMB() failed: ", conditionMessage(fit)),
      scope = "lens"
    ))
  }

  iter <- if (is.null(iter)) {
    2L * as.integer(ceiling(n_draws / chains))
  } else {
    .tmb_count(iter, "iter")
  }
  warmup <- if (is.null(warmup)) iter %/% 2L else .tmb_count(warmup, "warmup")
  samples <- tryCatch(
    tmbstan::tmbstan(
      fit$obj,
      laplace = laplace,
      chains = chains,
      iter = iter,
      warmup = warmup,
      seed = seed,
      silent = TRUE,
      refresh = 0L,
      ...
    ),
    error = function(e) e
  )
  if (inherits(samples, "error")) {
    return(quorum_abstention(
      "sampling_failed",
      paste0("tmbstan::tmbstan() failed: ", conditionMessage(samples)),
      scope = "lens"
    ))
  }

  extracted <- .tmb_extract_draws(samples, glmmTMB::fixef(fit)$cond,
                                  shape$group)
  if (is.null(extracted)) {
    return(quorum_abstention(
      "draws_unavailable",
      paste0(
        "the sampler output carries no `beta` / `theta` columns, so the ",
        "draws cannot be named with the hub's canonical parameters."
      ),
      scope = "lens"
    ))
  }
  diagnostics <- .tmb_sampler_diagnostics(samples, extracted$columns)

  quorum_draws(
    draws = extracted$draws,
    kind = "parameters",
    source = "glmmTMB+tmbstan",
    diagnostics = list(
      laplace_point = .tmb_laplace_point(fit, shape$group),
      rhat = diagnostics$rhat,
      n_divergent = diagnostics$n_divergent,
      laplace = laplace,
      priors = plan,
      formula = shape$formula,
      family = family_name,
      group = shape$group,
      chains = chains,
      iter = iter,
      warmup = warmup
    )
  )
}

# ---- the lens ----------------------------------------------------------------

#' The TMB lens: a second Laplace implementation, sampled with NUTS
#'
#' Registers glmmTMB's Laplace-approximated marginal likelihood as a lens, and
#' samples the very TMB objective that fit produced with `tmbstan`'s NUTS. The
#' lens therefore contributes two things the hub's own engines do not: a
#' Laplace implementation written independently of INLA's, and one objective
#' sampled two ways, so a disagreement between the Laplace point and the
#' Hamiltonian posterior is attributable to the approximation rather than to a
#' difference of model.
#'
#' The `fit` function accepts the model either as an lme4-style formula or as
#' the hub's `fb_terms` intermediate representation, from which the formula is
#' rebuilt the way [emit_koine()] rebuilds it. The lens fields a plain random
#' intercept on one grouping variable; a random slope, a correlated structure,
#' a nested or interaction grouping, or a second grouping term returns an
#' `out_of_scope` abstention. When the spec is an `fb_terms` object its own
#' family and link are authoritative, so a hub fit and this lens are never
#' compared across two different likelihoods; a formula spec takes the
#' `family` argument instead.
#'
#' @section Priors:
#'
#' The hub's default is `uniform(0, U)` on every standard deviation, with
#' `U = 5 * sd(y)` on an identity link, `3` on a log link and `5` on a logit
#' link. glmmTMB parameterises the random-effect SD by its logarithm, so
#' fitting with no prior at all is flat on `log(SD)` and thus proportional to
#' `1/SD` on the SD scale, which is not integrable at zero: for a weakly
#' identified variance component the posterior is improper and the sampler
#' does not settle. With `priors = "hub"` (the default) the lens writes a
#' shape-2 gamma prior on the random-intercept SD. glmmTMB adds a gamma row to
#' the negative log density as `-log dgamma(exp(theta), shape, scale)` with no
#' Jacobian term, so the implied density on the SD scale is proportional to
#' `SD^(shape - 2)`, and shape 2 is flat; the scale is set far above the hub's
#' bound so it stays flat across the whole interval the hub's uniform prior
#' covers. Two parts of the hub's default have no counterpart in glmmTMB's
#' prior syntax -- the hard upper bound itself, and the uniform prior on the
#' residual SD, since the dispersion parameter admits only log-scale families
#' -- and both are named in the fitted object's `diagnostics$priors$unmatched`
#' rather than assumed away. `shares["priors"]` reads `"hub_matched"` when
#' every hub prior on a component the lens reports (the fixed effects, which
#' the hub leaves to the engine by default, and the random-intercept SD) was
#' carried. With `priors = "flat"` the fit runs under glmmTMB's own defaults
#' and the lens declares `"flat"`.
#'
#' @param family One of `"gaussian"`, `"poisson"`, `"binomial"` or
#'   `"nbinom2"`, used when the spec is a formula. Any other family returns a
#'   `family_unsupported` abstention at fit time.
#' @param laplace Logical: when `TRUE` (the default) the random effects stay
#'   integrated out by the Laplace approximation and NUTS samples the
#'   remaining parameters; when `FALSE` NUTS samples the joint vector.
#' @param n_draws Target number of post-warmup draws in total across chains;
#'   sets the default `iter` when `iter` is `NULL`.
#' @param chains Number of NUTS chains.
#' @param iter Iterations per chain, warmup included. `NULL` derives it from
#'   `n_draws` and `chains` with a half-warmup split.
#' @param warmup Warmup iterations per chain. `NULL` uses half of `iter`.
#' @param seed Integer RNG seed passed to the sampler.
#' @param priors `"hub"` to match the hub's default priors as far as
#'   glmmTMB's prior syntax allows, or `"flat"` to fit under glmmTMB's own
#'   defaults. See the Priors section.
#' @param name Lens name; defaults to `"tmb"`.
#'
#' @return A [quorum_lens()] with member `"glmmTMB"` and kind `"parameters"`.
#'   Its `fit(spec, data, ...)` returns a [quorum_draws()] whose components are
#'   named with the hub's canonical parameters -- `"(Intercept)"`, the
#'   model-matrix column names, and `sd_<grouping>` -- and whose `diagnostics`
#'   carry `laplace_point` (the glmmTMB point estimates on those same names),
#'   `rhat` (the worst-case R-hat), `n_divergent`, the `laplace` flag, and the
#'   prior plan actually used. Further arguments in `...` reach
#'   [tmbstan::tmbstan()]. Where glmmTMB or tmbstan is not installed, the model
#'   is outside the lens's shape, or the family is unsupported, `fit()` returns
#'   a [quorum_abstention()] and never a number.
#'
#' @seealso [quorum_lens()] for the contract, [emit_koine()] for the formula
#'   construction and the canonical naming this lens follows.
#' @export
#' @examples
#' lens <- lens_tmb()
#' lens@shares
#' # Outside the lens's shape, the scope gate declines rather than fits.
#' is_quorum_abstention(lens@scope(y ~ x + (1 + x | g)))
lens_tmb <- function(family = "gaussian", laplace = TRUE, n_draws = 2000L,
                     chains = 2L, iter = NULL, warmup = NULL, seed = 1L,
                     priors = c("hub", "flat"), name = NULL) {
  priors <- match.arg(priors)
  if (!is.logical(laplace) || length(laplace) != 1L || is.na(laplace)) {
    stop("`laplace` must be TRUE or FALSE.", call. = FALSE)
  }
  n_draws <- .tmb_count(n_draws, "n_draws")
  chains <- .tmb_count(chains, "chains")
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed)) {
    stop("`seed` must be a single finite number.", call. = FALSE)
  }
  seed <- as.integer(seed)
  if (!is.null(iter)) iter <- .tmb_count(iter, "iter")
  if (!is.null(warmup)) warmup <- .tmb_count(warmup, "warmup")
  if (!is.null(name) &&
        (!is.character(name) || length(name) != 1L || !nzchar(name))) {
    stop("`name` must be NULL or a single non-empty string.", call. = FALSE)
  }

  quorum_lens(
    name = name %||% "tmb",
    member = "glmmTMB",
    kind = "parameters",
    fit = function(spec, data, ...) {
      .tmb_fit(
        spec = spec, data = data, family = family, laplace = laplace,
        n_draws = n_draws, chains = chains, iter = iter, warmup = warmup,
        seed = seed, priors_mode = priors, ...
      )
    },
    shares = c(
      sampler = "stan_nuts",
      objective = "tmb",
      priors = if (identical(priors, "hub")) "hub_matched" else "flat",
      data_prep = "quorum"
    ),
    expresses = "linear",
    scope = function(spec) {
      shape <- .tmb_shape(spec)
      if (is_quorum_abstention(shape)) shape else TRUE
    }
  )
}
