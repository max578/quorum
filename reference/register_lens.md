# Register, retrieve, list and clear lenses

The lens registry is the roster a quorum draws from. A member declares
its estimate once, as a
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md),
and registers it under a name; the comparison then reaches the lens by
that name rather than by holding the object. Registration replaces by
name, so re-registering after an engine upgrade updates the roster in
place rather than leaving two lenses answering to one name.

## Usage

``` r
register_lens(lens)

get_lens(name)

list_lenses()

clear_lenses()
```

## Arguments

- lens:

  A
  [`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md)
  to register. Anything else is a programmer error and raises a
  condition rather than returning an abstention: a registry that
  accepted non-lenses would defer the failure to the comparison, where
  the caller can no longer see which registration was wrong.

- name:

  Single non-empty string naming a registered lens.

## Value

`register_lens()` returns `lens` invisibly. `get_lens()` returns the
registered
[`quorum_lens()`](https://max578.github.io/quorum/reference/quorum_lens.md),
or `NULL` when nothing is registered under `name`; a lookup miss is a
fact about the roster, not a failure. `list_lenses()` returns a
`data.frame` with one row per registered lens ordered by name, carrying
`name`, `member`, `kind`, `expresses` (the declared shapes collapsed
with `"/"`, empty for a lens that expresses none) and one column per
independence component (`sampler`, `objective`, `priors`, `data_prep`);
it has zero rows when the registry is empty. `clear_lenses()` returns
`NULL` invisibly.

## Details

The registry holds declarations, not results. Registering a lens neither
fits nor ingests anything, because a lens is a fitter behind an adapter
and the fitting happens when the comparison calls its `fit()`. Clearing
the registry therefore costs nothing but the declarations themselves.

## Examples

``` r
d <- quorum_draws(list(beta = rnorm(50L)), source = "demo")
l <- lens_from_draws(
  d, name = "demo", member = "quorum",
  shares = c(sampler = "none", objective = "demo", priors = "none",
             data_prep = "none")
)
register_lens(l)
list_lenses()
#>   name member       kind expresses sampler objective priors data_prep
#> 1 demo quorum parameters    linear    none      demo   none      none
identical(get_lens("demo"), l)
#> [1] TRUE
get_lens("never_registered")
#> NULL
clear_lenses()
```
