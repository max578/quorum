# =============================================================================
# surrogate_conformers.R -- C7 conformers from constellation siblings.
#
# The C7 surrogate contract (inst/surrogate_contract.md) is honoured by the
# self-contained reference `rff` (R/surrogate.R) and, optionally, by richer
# surrogates from sibling members that REGISTER here rather than being
# reimplemented (the "contracts not internals" rule, mirroring C1 / C5):
#
#   * PESTO's GP surrogate -- train_gp_surrogate() / predict_gp_surrogate()
#     already report a per-output predictive mean AND variance, so it maps
#     straight onto the C7 `<o>_mean` / `<o>_sd` shape.
#   * kernR's conditional mean embedding -- fit_cme() / predict.cme_fit() give a
#     conditional *mean* (a linear smoother y_hat(x*) = w(x*)' y), but no
#     predictive variance. The conformer supplies the standard linear-smoother
#     predictive variance sigma^2 (1 + ||w(x*)||^2) -- stated UQ on top of
#     kernR's mean, not a reimplementation of the embedding -- and gates that
#     variance on the smoother's weight mass, because the variance formula is
#     only meaningful where the smoother actually carries weight (see the
#     out-of-support gate below).
#
# Both adapters are requireNamespace-gated: flexyBayes stays standalone (the
# `rff` reference needs no sibling). The registration helpers below are also
# called opportunistically from .onLoad when a sibling is installed, so
# `fit_surrogate(method = "gp" / "cme")` works when the member is present.
# =============================================================================

# ---- shared helper: assemble the per-output <o>_mean / <o>_sd data.frame -----

.surrogate_mean_sd_df <- function(mean_mat, sd_mat, output_names) {
  mean_mat <- as.matrix(mean_mat)
  sd_mat <- as.matrix(sd_mat)
  if (ncol(mean_mat) != length(output_names)) {
    stop(
      "surrogate conformer: predicted ",
      ncol(mean_mat),
      " output column(s) but the ensemble declared ",
      length(output_names),
      " (",
      paste(output_names, collapse = ", "),
      ").",
      call. = FALSE
    )
  }
  out <- list()
  for (j in seq_along(output_names)) {
    nm <- output_names[j]
    out[[paste0(nm, "_mean")]] <- mean_mat[, j]
    out[[paste0(nm, "_sd")]] <- sd_mat[, j]
  }
  as.data.frame(out, stringsAsFactors = FALSE)
}

# ---- PESTO GP conformer ------------------------------------------------------

.fit_pesto_gp <- function(x, y, ...) {
  if (!requireNamespace("PESTO", quietly = TRUE)) {
    stop(
      "the 'gp' surrogate needs the 'PESTO' package (not installed).",
      call. = FALSE
    )
  }
  gp <- PESTO::train_gp_surrogate(as.matrix(x), as.matrix(y), ...)
  structure(
    list(gp = gp, output_names = colnames(y)),
    class = "fb_surrogate_pesto_gp"
  )
}

#' @export
predict.fb_surrogate_pesto_gp <- function(object, newdata, ...) {
  pr <- PESTO::predict_gp_surrogate(object$gp, as.matrix(newdata))
  .surrogate_mean_sd_df(
    pr$mean,
    sqrt(pmax(as.matrix(pr$variance), 0)),
    object$output_names
  )
}

#' Register PESTO's GP surrogate as a flexyBayes C7 conformer
#'
#' Makes `method = "gp"` available to [fit_surrogate()] by registering an
#' adapter around PESTO's `train_gp_surrogate()` / `predict_gp_surrogate()`.
#' PESTO's GP already reports a per-output predictive mean and variance, so the
#' adapter only reshapes its output into the contract-C7 `<o>_mean` / `<o>_sd`
#' data.frame (`inst/surrogate_contract.md`) -- PESTO's surrogate is consumed
#' through the registry, never copied into flexyBayes.
#'
#' Called opportunistically from `.onLoad()` when PESTO is installed, so the
#' method is usually already available; call it explicitly to (re-)register.
#'
#' @return Invisibly, the registered method name (`"gp"`).
#' @seealso [register_surrogate()], [fit_surrogate()],
#'   [register_kernr_surrogates()].
#' @export
register_pesto_surrogates <- function() {
  if (!requireNamespace("PESTO", quietly = TRUE)) {
    stop(
      "register_pesto_surrogates(): package 'PESTO' is not installed. ",
      "Install the constellation member, or use the built-in method = ",
      "\"rff\".",
      call. = FALSE
    )
  }
  register_surrogate("gp", .fit_pesto_gp)
  invisible("gp")
}

# ---- kernR CME conformer -----------------------------------------------------

# Default safety factor on the out-of-support gate: a prediction point must
# carry at least this fraction of the LEAST-supported design point's smoother
# weight mass. See .fit_kernr_cme() for the derivation and the reasoning.
.CME_WEIGHT_MASS_FRAC <- 0.5

# Mint the typed out-of-support abstention. The class ends in `_abstention`, so
# the constellation's shared decline predicate
# (`is_orchestra_decline()`)
# recognises it without depending on this package's namespace.
.cme_out_of_support <- function(rows, mass, floor_value, design_range) {
  n_bad <- length(rows)
  msg <- paste0(
    "the 'cme' surrogate declines to predict at ",
    n_bad,
    " of the supplied point(s): the conditional-mean smoother carries a ",
    "weight mass of ",
    format(signif(min(mass[rows]), 3)),
    " there (row ",
    rows[which.min(mass[rows])],
    "), below the out-of-support floor ",
    format(signif(floor_value, 3)),
    ". On the training design the mass runs ",
    format(signif(design_range[1L], 4)),
    " to ",
    format(signif(design_range[2L], 4)),
    "; as a point leaves the design the kernel evaluations decay to zero, the ",
    "smoother mean collapses toward zero and the linear-smoother variance ",
    "sigma^2 (1 + ||w||^2) collapses to its in-design floor -- a confident ",
    "wrong answer. Emulate this region with fit_surrogate(method = \"rff\"), ",
    "which widens off-design as declared, keep the prediction inside the ",
    "design, or lower `weight_mass_floor` deliberately."
  )
  cond <- structure(
    class = c(
      "fb_surrogate_cme_abstention",
      "fb_surrogate_abstention",
      "error",
      "condition"
    ),
    list(
      message = msg,
      call = NULL,
      rows = rows,
      weight_mass = mass[rows],
      weight_mass_floor = floor_value,
      mass_design_range = design_range
    )
  )
  stop(cond)
}

.fit_kernr_cme <- function(x, y, weight_mass_frac = .CME_WEIGHT_MASS_FRAC,
                           weight_mass_floor = NULL, ...) {
  if (!requireNamespace("kernR", quietly = TRUE)) {
    stop(
      "the 'cme' surrogate needs the 'kernR' package (not installed).",
      call. = FALSE
    )
  }
  if (
    !is.numeric(weight_mass_frac) ||
      length(weight_mass_frac) != 1L ||
      !is.finite(weight_mass_frac) ||
      weight_mass_frac < 0
  ) {
    stop(
      "fit_surrogate(method = \"cme\"): `weight_mass_frac` must be a single ",
      "non-negative number.",
      call. = FALSE
    )
  }
  x <- as.matrix(x)
  y <- as.matrix(y)
  fit <- kernR::fit_cme(x, y, ...)
  # In-sample linear-smoother matrix S = K_xx W = predict(fit, x_train); the
  # CME prediction y_hat(x*) = w(x*)' y is a linear smoother, so its residual
  # noise variance is RSS / (n - tr(S)) and the predictive variance of a NEW
  # observation is sigma^2 (1 + ||w(x*)||^2). kernR owns the mean, the adapter
  # owns only the spread.
  s_mat <- stats::predict(fit, x)
  edf <- sum(diag(s_mat))
  resid <- y - s_mat %*% y
  n <- nrow(x)
  denom <- max(n - edf, 1)
  sigma2 <- colSums(resid^2) / denom
  sigma2[!is.finite(sigma2) | sigma2 < 0] <- NA_real_
  # Out-of-support gate. The smoother weights w(x*) are an approximate
  # partition of unity wherever the embedding of x* lies in the span of the
  # design embeddings: sum(w) is ~1 across the training design (the range is
  # recorded below). With a bounded, decaying kernel every k(x*, x_i) tends to
  # zero as x* leaves the design, so sum(w(x*)) -> 0, the mean w(x*)'y -> 0 and
  # ||w(x*)||^2 -> 0, which drives the reported sd to its in-design floor
  # sqrt(sigma^2). That is the failure mode the C7 contract exists to catch, so
  # the mass is gated rather than trusted. The floor is derived from the design
  # itself -- a fraction of the least-supported design point's mass -- so it
  # calibrates to the fitted ridge instead of assuming one.
  mass_design <- rowSums(s_mat)
  mass_design <- mass_design[is.finite(mass_design)]
  design_min <- if (length(mass_design)) min(mass_design) else NA_real_
  floor_value <- weight_mass_floor %||%
    (weight_mass_frac * if (is.finite(design_min)) design_min else 1)
  structure(
    list(
      cme = fit,
      y_train = y,
      sigma2 = sigma2,
      weight_mass_floor = floor_value,
      weight_mass_frac = weight_mass_frac,
      mass_design_range = if (length(mass_design)) {
        range(mass_design)
      } else {
        c(NA_real_, NA_real_)
      },
      output_names = colnames(y)
    ),
    class = "fb_surrogate_kernr_cme"
  )
}

#' @export
predict.fb_surrogate_kernr_cme <- function(object, newdata,
                                           weight_mass_floor = NULL, ...) {
  floor_value <- weight_mass_floor %||% object$weight_mass_floor
  w <- stats::predict(object$cme, as.matrix(newdata)) # n_new x n_train weights
  mass <- rowSums(w) # smoother weight mass per row
  if (is.finite(floor_value)) {
    bad <- which(!is.finite(mass) | mass < floor_value)
    if (length(bad) > 0L) {
      .cme_out_of_support(bad, mass, floor_value, object$mass_design_range)
    }
  }
  mean_mat <- w %*% object$y_train # n_new x d_y
  wnorm2 <- rowSums(w^2) # smoother weight energy per row
  sd_mat <- matrix(NA_real_, nrow(mean_mat), ncol(mean_mat))
  for (j in seq_along(object$output_names)) {
    sd_mat[, j] <- sqrt(object$sigma2[j] * (1 + wnorm2))
  }
  .surrogate_mean_sd_df(mean_mat, sd_mat, object$output_names)
}

#' Register kernR's conditional mean embedding as a flexyBayes C7 conformer
#'
#' Makes `method = "cme"` available to [fit_surrogate()] by registering an
#' adapter around kernR's `fit_cme()`. kernR's CME is a kernel linear smoother
#' that yields a conditional *mean* but no predictive variance; the adapter
#' supplies the standard linear-smoother predictive variance
#' `sigma^2 (1 + ||w||^2)` (with `sigma^2 = RSS / (n - tr(S))` from the
#' in-sample smoother), so the emulator honours the C7 distribution-preserving
#' `<o>_sd` requirement. The conditional-mean map stays kernR's; only the
#' uncertainty quantification is added here -- not a reimplementation.
#'
#' @section Out-of-support gate:
#' The smoother weights `w(x*)` are an approximate partition of unity wherever
#' `x*` is supported by the design: `sum(w)` is close to 1 across the training
#' design. With a bounded, decaying kernel every `k(x*, x_i)` tends to zero as
#' `x*` leaves the design, so `sum(w(x*))` tends to 0, the mean `w(x*)'y` decays
#' to zero, and `||w(x*)||^2` decays to zero -- which drives the reported sd
#' *down* to its in-design floor `sqrt(sigma^2)`. Ungated, the conformer would
#' report an in-design-sized uncertainty on a fabricated mean at exactly the
#' point where it knows least.
#'
#' The conformer therefore records the weight mass across the training design at
#' fit time and refuses to predict where the mass falls below
#' `weight_mass_frac` (default 0.5) times the least-supported design point's
#' mass, raising a classed `fb_surrogate_cme_abstention` condition that names
#' the offending rows, their mass, and the floor. Pass `weight_mass_frac` (or an
#' absolute `weight_mass_floor`) through [fit_surrogate()] to retune it, or
#' `weight_mass_floor` to `predict()` to override it for one call; set the floor
#' to 0 to disable the gate. The reference `rff` surrogate widens as declared
#' off-design and is the named fallback for extrapolation.
#'
#' Called opportunistically from `.onLoad()` when kernR is installed.
#'
#' @return Invisibly, the registered method name (`"cme"`).
#' @seealso [register_surrogate()], [fit_surrogate()],
#'   [register_pesto_surrogates()].
#' @examples
#' if (requireNamespace("kernR", quietly = TRUE)) {
#'   register_kernr_surrogates()
#'   set.seed(1)
#'   a <- runif(80, -2, 2)
#'   e <- fb_ensemble(
#'     params = data.frame(a = a),
#'     outputs = data.frame(y = sin(a) + rnorm(80, 0, 0.05)),
#'     provenance = list(source = "raw")
#'   )
#'   s <- fit_surrogate(e, method = "cme", lambda = 1e-2)
#'   predict(s, data.frame(a = 0.5))
#'   # far outside the design the conformer declines rather than guessing:
#'   tryCatch(
#'     predict(s, data.frame(a = 40)),
#'     fb_surrogate_cme_abstention = function(cnd) conditionMessage(cnd)
#'   )
#' }
#' @export
register_kernr_surrogates <- function() {
  if (!requireNamespace("kernR", quietly = TRUE)) {
    stop(
      "register_kernr_surrogates(): package 'kernR' is not installed. ",
      "Install the constellation member, or use the built-in method = ",
      "\"rff\".",
      call. = FALSE
    )
  }
  register_surrogate("cme", .fit_kernr_cme)
  invisible("cme")
}
