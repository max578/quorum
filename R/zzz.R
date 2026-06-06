# Package load hooks for flexyBayesOrchestra.
#
# Constellation C7 surrogate-conformer auto-registration. When the sibling
# member packages are installed (PESTO's GP surrogate, kernR's CME surrogate),
# register their conformers so fit_surrogate(method = "gp" / "cme") becomes
# discoverable. This mirrors the hook that lived in flexyBayes's .onLoad before
# the lean-core split (2026-06-06) relocated the surrogate layer to this package.
# The explicit helpers register_pesto_surrogates() / register_kernr_surrogates()
# do the same on demand; the built-in "rff" reference surrogate needs no sibling.
.onLoad <- function(libname, pkgname) {
  if (requireNamespace("PESTO", quietly = TRUE)) {
    tryCatch(register_pesto_surrogates(), error = function(e) NULL)
  }
  if (requireNamespace("kernR", quietly = TRUE)) {
    tryCatch(register_kernr_surrogates(), error = function(e) NULL)
  }
  invisible(NULL)
}
