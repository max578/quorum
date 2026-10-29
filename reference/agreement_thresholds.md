# The hub's agreement cut-offs

The cut-offs the hub's cross-engine comparison applied when it called a
parameter concordant, with the hub's own defaults. That comparison,
`triangulate()`, was removed from flexyBayes in version 0.14.0; the
source lines cited below are from flexyBayes 0.10.0. A parameter is
concordant when the absolute mean difference is at most
`mean_shift_sd_max` reference SDs, the Wasserstein-1 distance is at most
`w1_sd_max` reference SDs, and the ratio of the two posterior SDs lies
inside `sd_ratio_band`; any breach makes it discordant.

## Usage

``` r
agreement_thresholds(
  mean_shift_sd_max = 0.1,
  w1_sd_max = 0.1,
  sd_ratio_band = c(0.9, 1.1),
  quantile_probs = c(0.025, 0.975)
)
```

## Arguments

- mean_shift_sd_max:

  Single positive number: the largest absolute difference in posterior
  means, in reference-SD units, a concordant parameter may show. Hub
  default 0.1, from `.FB_TRIANGULATE_MEAN_SHIFT_MAX` at `flexyBayes`
  0.10.0 `R/triangulate.R:757`.

- w1_sd_max:

  Single positive number: the largest Wasserstein-1 distance, in
  reference-SD units, a concordant parameter may show. Hub default 0.1,
  from `.FB_TRIANGULATE_W1_MAX` at `R/triangulate.R:758`.

- sd_ratio_band:

  Numeric vector of length two, increasing: the band the ratio of the
  two posterior SDs must lie in. Hub default `c(0.9, 1.1)`, from
  `.FB_TRIANGULATE_SD_RATIO_BAND` at `R/triangulate.R:759`.

- quantile_probs:

  Numeric vector of length two, increasing, inside `(0, 1)`: the
  quantiles whose difference is reported. Hub default `c(0.025, 0.975)`,
  from the [`stats::quantile()`](https://rdrr.io/r/stats/quantile.html)
  calls in `.triangulate_one` at `R/triangulate.R:495` and
  `R/triangulate.R:497`.

## Value

A named list with the four elements above.

## Details

The cut-offs are heuristics in the sense the Bayesian-workflow
literature uses for cross-implementation checks: they are set to flag a
difference a reader should look at, they are not derived from a sampling
distribution, and they carry no error rate. The hub documents them that
way and quorum inherits both the numbers and the reading.

`quantile_probs` names the two quantiles whose difference the table
reports as `q025_diff` and `q975_diff`. The hub reports that tail drift
without ever thresholding it, so there is no quantile tolerance in the
verdict rule; the argument fixes which quantiles are reported, not a
cut-off they must clear.

## See also

[`agreement_pairwise()`](https://max578.github.io/quorum/reference/agreement_pairwise.md),
[`agreement_status()`](https://max578.github.io/quorum/reference/agreement_status.md).

## Examples

``` r
agreement_thresholds()
#> $mean_shift_sd_max
#> [1] 0.1
#> 
#> $w1_sd_max
#> [1] 0.1
#> 
#> $sd_ratio_band
#> [1] 0.9 1.1
#> 
#> $quantile_probs
#> [1] 0.025 0.975
#> 
agreement_thresholds(w1_sd_max = 0.05)
#> $mean_shift_sd_max
#> [1] 0.1
#> 
#> $w1_sd_max
#> [1] 0.05
#> 
#> $sd_ratio_band
#> [1] 0.9 1.1
#> 
#> $quantile_probs
#> [1] 0.025 0.975
#> 
```
