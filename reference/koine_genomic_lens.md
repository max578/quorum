# Koine genomic fourth opinion (REML lens via sommer)

Fit the established REML genomic BLUP with sommer on the same data and
return a genomic *lens*: the field-standard fourth opinion to set beside
the Bayesian multi-backend answer. (`triangulate_genomic()`, which
compared the two, was removed from flexyBayes in version 0.14.0.) The
lens carries the REML heritability, variance components (with standard
errors), and breeding values (named by genotype, aligning to the
flexyBayes GEBVs), so divergence between the Bayesian and REML answers
is surfaced rather than hidden.

## Usage

``` r
koine_genomic_lens(fixed, data, K, geno = "geno")
```

## Arguments

- fixed:

  A fixed-effect formula, e.g. `y ~ 1` or `y ~ env`.

- data:

  A data frame with the response, fixed effects, and the genotype
  factor; one or more records per genotype.

- K:

  The genomic (or pedigree) relationship matrix; its row / column names
  are the genotype levels and must cover the genotypes in `data`.

- geno:

  The genotype grouping-factor column name (default `"geno"`).

## Value

A genomic lens: `list(h2, var_g, var_e, gebv, label)`, where `h2` /
`var_g` / `var_e` are `list(estimate, se)` (the heritability SE is a
delta-method approximation) and `gebv` is a named numeric vector of REML
breeding values.

## Examples

``` r
if (FALSE) { # \dontrun{
bayes_fit <- flexyBayes::flexybayes(
  y ~ 1, random = ~ vm(geno, G), data = dat,
  known_matrices = list(G = G), backend = "greta"
)
koine <- koine_genomic_lens(y ~ 1, dat, G, geno = "geno")
koine$h2
head(koine$gebv)
} # }
```
