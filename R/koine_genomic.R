# koine_genomic.R -- the koine fourth opinion for genomics: a
# field-standard REML lens.
#
# In genomics the orchestra's value is not replacing the decades of
# established REML / field-standard tools but *catching divergence*: "our
# Bayesian GEBVs disagree with sommer's REML -- investigate." This is the
# strongest articulation of the fourth-opinion thesis, in a field where the
# established methods are trusted.
#
# `koine_genomic_lens()` runs the established REML genomic BLUP (via
# sommer) on the same data and emits the genomic *lens*
# `list(h2, var_g, var_e, gebv, label)` that
# flexyBayes's former `triangulate_genomic()` consumed as a fourth column. The lens
# contract keeps flexyBayes core lean -- core never depends on sommer; the
# companion produces the lens and core compares it. sommer / the field
# tools stay in Suggests (oracle / cross-check only, never on the fit
# path), per the genomics expansion's light-core discipline (G-I3).
#
# GEMMA / rrBLUP (GWAS) and BGLR (Bayesian marker) lenses are the same
# pattern and are planned; they are design-only here because those tools
# are not assumed installed.

#' Koine genomic fourth opinion (REML lens via sommer)
#'
#' Fit the established REML genomic BLUP with \pkg{sommer} on the same data
#' and return a genomic *lens*: the field-standard fourth opinion to set
#' beside the Bayesian multi-backend answer. (`triangulate_genomic()`, which
#' compared the two, was removed from flexyBayes in version 0.14.0.) The lens carries the REML heritability, variance
#' components (with standard errors), and breeding values (named by
#' genotype, aligning to the flexyBayes GEBVs), so divergence between the
#' Bayesian and REML answers is surfaced rather than hidden.
#'
#' @param fixed A fixed-effect formula, e.g. `y ~ 1` or `y ~ env`.
#' @param data A data frame with the response, fixed effects, and the
#'   genotype factor; one or more records per genotype.
#' @param K The genomic (or pedigree) relationship matrix; its row / column
#'   names are the genotype levels and must cover the genotypes in `data`.
#' @param geno The genotype grouping-factor column name (default
#'   `"geno"`).
#'
#' @return A genomic lens: `list(h2, var_g, var_e, gebv, label)`, where
#'   `h2` / `var_g` / `var_e` are `list(estimate, se)` (the heritability SE
#'   is a delta-method approximation) and `gebv` is a named numeric vector
#'   of REML breeding values.
#'
#' @examples
#' \dontrun{
#' bayes_fit <- flexyBayes::flexybayes(
#'   y ~ 1, random = ~ vm(geno, G), data = dat,
#'   known_matrices = list(G = G), backend = "greta"
#' )
#' koine <- koine_genomic_lens(y ~ 1, dat, G, geno = "geno")
#' koine$h2
#' head(koine$gebv)
#' }
#' @export
koine_genomic_lens <- function(fixed, data, K, geno = "geno") {
  if (!requireNamespace("sommer", quietly = TRUE)) {
    stop(
      "koine_genomic_lens() needs the 'sommer' package (the REML field ",
      "oracle). Install via install.packages('sommer'). It is a Suggests ",
      "dependency used only for the koine cross-check, never on the ",
      "flexyBayes fit path.",
      call. = FALSE
    )
  }
  if (!inherits(fixed, "formula")) {
    stop("`fixed` must be a fixed-effect formula, e.g. y ~ 1.", call. = FALSE)
  }
  K <- as.matrix(K)
  lv <- rownames(K)
  if (is.null(lv)) {
    stop(
      "`K` must carry row / column names (the genotype levels) so the REML ",
      "breeding values align with the flexyBayes GEBVs.",
      call. = FALSE
    )
  }
  if (!geno %in% names(data)) {
    stop("`data` has no column '", geno, "'.", call. = FALSE)
  }
  data[[geno]] <- factor(as.character(data[[geno]]), levels = lv)
  response <- all.vars(fixed)[[1L]]

  # Build the sommer random term ~ vsr(<geno>, Gu = K). sommer resolves the
  # `Gu` argument in mmer()'s calling frame (parent.frame), so the matrix is
  # bound as a plain local variable in this function's environment -- the
  # frame sommer searches -- rather than in a child formula environment.
  .koine_K <- K
  random <- stats::as.formula(
    paste0("~ sommer::vsr(", geno, ", Gu = .koine_K)")
  )

  fit <- tryCatch(
    sommer::mmer(
      fixed = fixed, random = random, data = data,
      verbose = FALSE, dateWarning = FALSE
    ),
    error = function(e) {
      stop("koine_genomic_lens(): sommer::mmer() failed: ",
        conditionMessage(e), call. = FALSE)
    }
  )

  vc <- summary(fit)$varcomp
  gen_row <- grep(geno, rownames(vc))[[1L]]
  res_row <- grep("units", rownames(vc))[[1L]]
  vg <- vc[gen_row, 1L]
  ve <- vc[res_row, 1L]
  se_vg <- vc[gen_row, 2L]
  se_ve <- vc[res_row, 2L]

  h2 <- vg / (vg + ve)
  # Delta-method heritability standard error (independence approximation).
  denom <- (vg + ve)^2
  se_h2 <- sqrt((ve / denom)^2 * se_vg^2 + (vg / denom)^2 * se_ve^2)

  u <- fit$U[[paste0("u:", geno)]]
  gebv <- if (!is.null(u) && !is.null(u[[response]])) u[[response]] else NULL

  list(
    h2 = list(estimate = h2, se = se_h2),
    var_g = list(estimate = vg, se = se_vg),
    var_e = list(estimate = ve, se = se_ve),
    gebv = gebv,
    label = "koine(sommer REML)"
  )
}
