# koine_genomic_lens() -- the field-standard REML fourth opinion for
# genomics. The lens shape + recovery are checked with sommer; the
# triangulation against a flexyBayes Bayesian answer is gated on flexyBayes
# carrying triangulate_genomic() (>= 0.8.0).

# Founder-related genotypes so REML breeding values are well identified.
.koine_gen_sim <- function(n_geno = 60L, n_markers = 400L, n_founders = 10L,
                           var_g = 2, var_e = 1, seed = 1L) {
  set.seed(seed)
  founders <- matrix(stats::rbinom(n_founders * n_markers, 2L, 0.25),
    n_founders, n_markers)
  Z <- matrix(0L, n_geno, n_markers)
  for (i in seq_len(n_geno)) {
    par <- sample(n_founders, 2L)
    Z[i, ] <- round((founders[par[1L], ] + founders[par[2L], ]) / 2)
  }
  Zc <- scale(Z, center = TRUE, scale = FALSE)
  G <- tcrossprod(Zc) / n_markers
  G <- G / mean(diag(G)) + diag(n_geno) * 1e-6
  rownames(G) <- colnames(G) <- paste0("g", seq_len(n_geno))
  e <- eigen(G, symmetric = TRUE)
  u <- as.vector(sweep(e$vectors, 2L, sqrt(pmax(e$values, 0)), `*`) %*%
    stats::rnorm(n_geno, 0, sqrt(var_g)))
  names(u) <- rownames(G)
  dat <- data.frame(
    geno = factor(rep(rownames(G), 3L), levels = rownames(G)),
    stringsAsFactors = FALSE
  )
  dat$y <- 10 + u[as.character(dat$geno)] +
    stats::rnorm(nrow(dat), 0, sqrt(var_e))
  list(data = dat, K = G, u_true = u, var_g = var_g, var_e = var_e)
}

test_that("koine_genomic_lens() emits a valid genomic lens recovering the REML quantities", {
  skip_if_not_installed("sommer")
  sim <- .koine_gen_sim(seed = 2L)
  lens <- koine_genomic_lens(y ~ 1, sim$data, sim$K, geno = "geno")

  # Lens contract: h2 / var_g / var_e are list(estimate, se); gebv is a
  # named numeric vector keyed by genotype.
  expect_type(lens, "list")
  expect_true(all(c("h2", "var_g", "var_e", "gebv", "label") %in% names(lens)))
  expect_true(all(c("estimate", "se") %in% names(lens$h2)))
  expect_match(lens$label, "sommer")

  # Heritability recovers the simulated 2/3 within REML uncertainty.
  expect_gt(lens$h2$estimate, 0.4)
  expect_lt(lens$h2$estimate, 0.9)
  expect_gt(lens$var_g$estimate, 0)

  # Breeding values are named by genotype and track the truth.
  expect_equal(length(lens$gebv), nrow(sim$K))
  expect_setequal(names(lens$gebv), rownames(sim$K))
  rho <- stats::cor(lens$gebv[rownames(sim$K)], sim$u_true[rownames(sim$K)])
  expect_gt(rho, 0.6)
})

test_that("koine_genomic_lens() validates its inputs", {
  skip_if_not_installed("sommer")
  sim <- .koine_gen_sim(n_geno = 20L, seed = 3L)
  K_nonames <- sim$K
  dimnames(K_nonames) <- NULL
  expect_error(koine_genomic_lens(y ~ 1, sim$data, K_nonames), "row / column names")
  expect_error(
    koine_genomic_lens(y ~ 1, sim$data, sim$K, geno = "nope"),
    "no column"
  )
})

test_that("the koine REML lens triangulates against a Bayesian lens", {
  skip_if_not_installed("sommer")
  skip_if_not_installed("flexyBayes")
  skip_if(
    utils::packageVersion("flexyBayes") < "0.8.0",
    "flexyBayes >= 0.8.0 (triangulate_genomic) not installed"
  )
  sim <- .koine_gen_sim(seed = 4L)
  koine <- koine_genomic_lens(y ~ 1, sim$data, sim$K, geno = "geno")

  # A stand-in Bayesian lens that broadly agrees (same data scale).
  set.seed(5L)
  bayes <- list(
    h2 = stats::rnorm(1000L, koine$h2$estimate, 0.05),
    var_g = stats::rnorm(1000L, koine$var_g$estimate, 0.2),
    var_e = stats::rnorm(1000L, koine$var_e$estimate, 0.1),
    gebv = koine$gebv + stats::rnorm(length(koine$gebv), 0, 0.1),
    label = "bayes"
  )
  tg <- flexyBayes::triangulate_genomic(bayes, koine)
  h2_row <- tg$components[tg$components$quantity == "heritability", ]
  expect_true(h2_row$intervals_overlap)
  expect_gt(tg$gebv$pearson, 0.9)
  expect_equal(tg$label_b, "koine(sommer REML)")
})
