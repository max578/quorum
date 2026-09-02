# =============================================================================
# make_agreement_draws.R -- build `agreement_draws.rds`, the synthetic two-lens
# fixture the agreement-metric tests and the deterministic half of oracle S3
# run on.
#
# The fixture is stored rather than regenerated inside the test so the oracle
# compares quorum and the hub on the same bytes on every R version: the RNG
# stream is not part of the contract being tested, and a stream change must
# not be able to move a verdict.
#
# The two lenses are built to exercise every branch of the verdict rule at
# once, and to have different draw counts so the Wasserstein-1 route through
# a common probability grid is exercised rather than assumed:
#
#   intercept  a small shift well inside the cut-offs      -> concordant
#   slope      a shift of three posterior SDs              -> discordant
#   spread     the same centre, SDs 1.4 apart              -> discordant
#   flat       a degenerate point mass on both sides       -> not_compared
#   extra      present on lens b only                      -> not in common
#
# Run: Rscript tests/testthat/fixtures/make_agreement_draws.R
# =============================================================================

set.seed(20260902L)

n_a <- 600L
n_b <- 500L

lens_a <- list(
  intercept = rnorm(n_a, mean = 1, sd = 0.5),
  slope = rnorm(n_a, mean = 2, sd = 0.3),
  spread = rgamma(n_a, shape = 20, rate = 20),
  flat = rep(3, n_a)
)

lens_b <- list(
  intercept = rnorm(n_b, mean = 1.02, sd = 0.51),
  slope = rnorm(n_b, mean = 2.9, sd = 0.3),
  spread = rgamma(n_b, shape = 20, rate = 20) * 1.4,
  flat = rep(3, n_b),
  extra = rnorm(n_b)
)

saveRDS(
  list(a = lens_a, b = lens_b),
  file.path("tests", "testthat", "fixtures", "agreement_draws.rds"),
  version = 3L
)
