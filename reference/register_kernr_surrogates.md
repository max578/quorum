# Register kernR's conditional mean embedding as a flexyBayes C7 conformer

Makes `method = "cme"` available to
[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md)
by registering an adapter around kernR's `fit_cme()`. kernR's CME is a
kernel linear smoother that yields a conditional *mean* but no
predictive variance; the adapter supplies the standard linear-smoother
predictive variance `sigma^2 (1 + ||w||^2)` (with
`sigma^2 = RSS / (n - tr(S))` from the in-sample smoother), so the
emulator honours the C7 distribution-preserving `<o>_sd` requirement.
The conditional-mean map stays kernR's; only the uncertainty
quantification is added here – not a reimplementation.

## Usage

``` r
register_kernr_surrogates()
```

## Value

Invisibly, the registered method name (`"cme"`).

## Out-of-support gate

The smoother weights `w(x*)` are an approximate partition of unity
wherever `x*` is supported by the design: `sum(w)` is close to 1 across
the training design. With a bounded, decaying kernel every `k(x*, x_i)`
tends to zero as `x*` leaves the design, so `sum(w(x*))` tends to 0, the
mean `w(x*)'y` decays to zero, and `||w(x*)||^2` decays to zero – which
drives the reported sd *down* to its in-design floor `sqrt(sigma^2)`.
Ungated, the conformer would report an in-design-sized uncertainty on a
fabricated mean at exactly the point where it knows least.

The conformer therefore records the weight mass across the training
design at fit time and refuses to predict where the mass falls below
`weight_mass_frac` (default 0.5) times the least-supported design
point's mass, raising a classed `fb_surrogate_cme_abstention` condition
that names the offending rows, their mass, and the floor. Pass
`weight_mass_frac` (or an absolute `weight_mass_floor`) through
[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md)
to retune it, or `weight_mass_floor` to
[`predict()`](https://rdrr.io/r/stats/predict.html) to override it for
one call; set the floor to 0 to disable the gate. The reference `rff`
surrogate widens as declared off-design and is the named fallback for
extrapolation.

Called opportunistically from `.onLoad()` when kernR is installed.

## See also

[`register_surrogate()`](https://max578.github.io/quorum/reference/register_surrogate.md),
[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md),
[`register_pesto_surrogates()`](https://max578.github.io/quorum/reference/register_pesto_surrogates.md).

## Examples

``` r
if (requireNamespace("kernR", quietly = TRUE)) {
  register_kernr_surrogates()
  set.seed(1)
  a <- runif(80, -2, 2)
  e <- fb_ensemble(
    params = data.frame(a = a),
    outputs = data.frame(y = sin(a) + rnorm(80, 0, 0.05)),
    provenance = list(source = "raw")
  )
  s <- fit_surrogate(e, method = "cme", lambda = 1e-2)
  predict(s, data.frame(a = 0.5))
  # far outside the design the conformer declines rather than guessing:
  tryCatch(
    predict(s, data.frame(a = 40)),
    fb_surrogate_cme_abstention = function(cnd) conditionMessage(cnd)
  )
}
#> [1] "the 'cme' surrogate declines to predict at 1 of the supplied point(s): the conditional-mean smoother carries a weight mass of 6.41e-258 there (row 1), below the out-of-support floor 0.434. On the training design the mass runs 0.867 to 1.004; as a point leaves the design the kernel evaluations decay to zero, the smoother mean collapses toward zero and the linear-smoother variance sigma^2 (1 + ||w||^2) collapses to its in-design floor -- a confident wrong answer. Emulate this region with fit_surrogate(method = \"rff\"), which widens off-design as declared, keep the prediction inside the design, or lower `weight_mass_floor` deliberately."
```
