# Register PESTO's GP surrogate as a flexyBayes C7 conformer

Makes `method = "gp"` available to
[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md)
by registering an adapter around PESTO's `train_gp_surrogate()` /
`predict_gp_surrogate()`. PESTO's GP already reports a per-output
predictive mean and variance, so the adapter only reshapes its output
into the contract-C7 `<o>_mean` / `<o>_sd` data.frame
(`inst/surrogate_contract.md`) – PESTO's surrogate is consumed through
the registry, never copied into flexyBayes.

## Usage

``` r
register_pesto_surrogates()
```

## Value

Invisibly, the registered method name (`"gp"`).

## Details

Called opportunistically from `.onLoad()` when PESTO is installed, so
the method is usually already available; call it explicitly to
(re-)register.

## See also

[`register_surrogate()`](https://max578.github.io/quorum/reference/register_surrogate.md),
[`fit_surrogate()`](https://max578.github.io/quorum/reference/fit_surrogate.md),
[`register_kernr_surrogates()`](https://max578.github.io/quorum/reference/register_kernr_surrogates.md).
