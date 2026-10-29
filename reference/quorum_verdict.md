# The verdict a quorum returns

Everything the comparison established, in one object: which lenses were
asked, what each contributed, the pairwise agreement, the independence
weights behind it, the shape findings that explain a disagreement rather
than counting it, the overall status, the resolution the policy reached,
and the manifest the rest of the orchestra reads.

## Usage

``` r
quorum_verdict(
  lenses,
  contributions,
  status,
  resolution,
  policy,
  agreement = NULL,
  independence = NULL,
  findings = .empty_findings(),
  manifest = NULL,
  abstention = NULL,
  carried_draws = NULL
)
```

## Arguments

- lenses:

  Character vector of the lens names that were asked.

- contributions:

  The contributions data frame, one row per lens.

- status:

  One of `"concordant"`, `"discordant"`, `"no_quorum"` or
  `"not_computed"`.

- resolution:

  The resolution data frame from
  [`quorum_resolve()`](https://max578.github.io/quorum/reference/quorum_resolve.md).

- policy:

  The
  [`quorum_policy()`](https://max578.github.io/quorum/reference/quorum_policy.md)
  the resolution used.

- agreement:

  The agreement result, or `NULL` when the metric layer was not
  available.

- independence:

  The independence result, or `NULL`.

- findings:

  A data frame of shape findings.

- manifest:

  The emitted manifest, or the typed decline explaining why none was
  emitted, or `NULL`.

- abstention:

  A
  [`quorum_abstention()`](https://max578.github.io/quorum/reference/quorum_abstention.md)
  when the verdict carries no number, else `NULL`.

- carried_draws:

  A numeric matrix of the carried lens's draws, one column per quantity,
  when the status is `"concordant"` over a single resolved cell; else
  `NULL`.

## Value

A `quorum_verdict` S7 object.

## See also

[`quorum()`](https://max578.github.io/quorum/reference/quorum.md),
[`quorum_manifest()`](https://max578.github.io/quorum/reference/quorum_manifest.md).
