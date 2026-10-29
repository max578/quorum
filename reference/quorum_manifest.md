# Emit a verdict as an orchestra manifest

Builds the `orchestra_manifest` the rest of the orchestra reads from a
[`quorum_verdict()`](https://max578.github.io/quorum/reference/quorum_verdict.md):
the contributions table as the payload, the status, the carried lens,
the action, the independence weights and the independence caveat in the
typed summary, and the grounding token the consensus earned.

## Usage

``` r
quorum_manifest(verdict)
```

## Arguments

- verdict:

  A
  [`quorum_verdict()`](https://max578.github.io/quorum/reference/quorum_verdict.md).

## Value

An
[`orchestraManifest::orchestra_manifest`](https://rdrr.io/pkg/orchestraManifest/man/orchestra_manifest.html),
or a
[`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
when the installed contract has no `"consensus"` target to emit into.

## Details

The grounding rule is stricter than the lenses'. The consensus is
stamped grounded only when at least one contributing lens is grounded
*and* `data_independence` was not declared `FALSE`; lenses that agree
because they read the same upstream fact corroborate the reading, not
the world, and the manifest says so by carrying the unverified token
instead.

## See also

[`quorum()`](https://max578.github.io/quorum/reference/quorum.md),
[`quorum_verdict()`](https://max578.github.io/quorum/reference/quorum_verdict.md).

## Examples

``` r
fit_fn <- function(spec, data, ...) {
  quorum_draws(list(`(Intercept)` = stats::rnorm(200L)),
               source = "example")
}
one <- quorum_lens("one", "example", fit_fn,
                   c(sampler = "a", objective = "b", priors = "c",
                     data_prep = "d"))
two <- quorum_lens("two", "example", fit_fn,
                   c(sampler = "w", objective = "x", priors = "y",
                     data_prep = "z"))
v <- quorum(list(one, two), policy = quorum_policy(c("one", "two")))
quorum_manifest(v)
#> <orchestraManifest::orchestra_manifest>
#>  @ manifest_version  : chr "2.0.0-draft"
#>  @ emitter_package   : chr "quorum"
#>  @ emitter_version   : chr "0.1.0.9000"
#>  @ inferential_target: chr "consensus"
#>  @ run_id            : chr "quorum-ea231aa96be8"
#>  @ method            : chr "quorum:consensus"
#>  @ seed              : int NA
#>  @ params            :'data.frame':  2 obs. of  10 variables:
#>  .. $ lens       : chr  "one" "two"
#>  .. $ grounded   : logi  TRUE TRUE
#>  .. $ abstained  : logi  FALSE FALSE
#>  .. $ action     : num  NA NA
#>  .. $ reason     : chr  NA NA
#>  .. $ grounding  : chr  "grounded" "grounded"
#>  .. $ decisive   : logi  TRUE TRUE
#>  .. $ member     : chr  "example" "example"
#>  .. $ kind       : chr  "parameters" "parameters"
#>  .. $ contributed: logi  TRUE TRUE
#>  @ outputs           : NULL
#>  @ weights           : NULL
#>  @ obs_target        : NULL
#>  @ obs_schema        : NULL
#>  @ summary           :List of 4
#>  .. $ headline      : chr "consensus discordant; carried lens one"
#>  .. $ abstained     : logi FALSE
#>  .. $ abstain_reason: chr NA
#>  .. $ metrics       :List of 8
#>  ..  ..$ status              : chr "discordant"
#>  ..  ..$ carried_lens        : chr "one"
#>  ..  ..$ action              : num NA
#>  ..  ..$ n_lenses            : int 2
#>  ..  ..$ n_contributing      : int 2
#>  ..  ..$ n_findings          : int 0
#>  ..  ..$ independence_weights: num [1:2, 1:2] NA 1 1 NA
#>  ..  .. ..- attr(*, "dimnames")=List of 2
#>  ..  .. .. ..$ : chr [1:2] "one" "two"
#>  ..  .. .. ..$ : chr [1:2] "one" "two"
#>  ..  ..$ independence_caveat : chr "Agreement between lenses fitted to the same data is agreement, not corroboration of a shared data fact."
#>  .. - attr(*, "class")= chr "manifest_summary"
#>  @ consumed_manifests: list()
#>  @ metadata          :List of 5
#>  .. $ derived            : logi FALSE
#>  .. $ grounding          : chr "grounded"
#>  .. $ lenses             : chr [1:2] "one" "two"
#>  .. $ status             : chr "discordant"
#>  .. $ independence_caveat: chr "Agreement between lenses fitted to the same data is agreement, not corroboration of a shared data fact."
#>  @ timestamp         : POSIXct[1:1], format: "2026-10-29 04:11:59"
#>  @ data_hash         : chr "sha256:ea231aa96be845e9fec5fde370ead8fbdb1a8142efffd97b55b9cd085dc6750d"
```
