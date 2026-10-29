# Introspect the koine backend slot

Returns the activation state of the koine backend slot plus the
procedure to activate it. koine is the synthesised fourth opinion on
flexyBayes's orthogonal lens axis (the constellation's C1 + C3
contracts). The slot has been **active by default since 2026-06-08** on
an installed koine at or above the version floor, gated only by
`options(quorum.koine_activated)`; it falls back to dormant (a
structured `koine_dormant_refusal`) when koine is absent, below floor,
or the option is set `FALSE`. This helper is the canonical
discoverability surface – call `koine_status()` to check whether the
slot is currently active on the installed koine version and, if not, why
and how to activate it.

## Usage

``` r
koine_status()
```

## Value

A list with components:

- `activated`:

  Logical: `TRUE` when koine is installed at or above the activation
  floor and `options(quorum.koine_activated)` is not set `FALSE` (the
  slot is live as of 2026-06-08).

- `koine_installed`:

  Logical: result of `nzchar(system.file(package = "koine"))`.

- `builder_confirmed`:

  Logical: whether koine's `koine_pass_from_design` builder is installed
  at or above the floor (the ported
  [`emit_koine()`](https://max578.github.io/quorum/reference/emit_koine.md)
  confirms it against the koine_pass/koine_result contract).

- `dormancy_reason`:

  Character: one of `"koine_not_installed"`, `"koine_below_floor"`,
  `"slot_provisioned_not_activated"`, or `"koine_dispatch_eligible"`
  (the last meaning the slot is fully active).

- `activation_procedure`:

  Character vector: numbered steps to activate the slot, in order.

## See also

`gretaR_status()` (withdrawn from the hub in 0.10.0) for the engine-axis
sibling slot.

## Examples

``` r
ks <- koine_status()
ks$activated         # TRUE when koine (>= 0.2.0) is installed
#> [1] TRUE
ks$dormancy_reason   # "koine_dispatch_eligible" when active
#> [1] "koine_dispatch_eligible"
cat(ks$activation_procedure, sep = "\n")
#> Install the koine package (>= 0.2.0, carrying koine_pass_from_design + the Stage-0 koine_pass/koine_result contract + the poisson (1 | g) corner).
#> Keep options(quorum.koine_activated = TRUE) (the default); set it FALSE to hold the slot dormant.
#> Emit the fourth opinion with emit_koine(fit$fb, data) on a core fit, wrap it and the engine fit with lens_from_fit(), and compare them with agreement_pairwise().
```
