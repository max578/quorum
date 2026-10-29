# Construct a typed quorum abstention

The single constructor for every decline the package issues. A lens that
is out of scope, an engine that is not installed, a comparison with
fewer contributing lenses than the policy's quorum, or a resolution with
nothing grounded left all return one of these rather than a number.

## Usage

``` r
quorum_abstention(reason, detail = NULL, scope = "quorum", ...)

is_quorum_abstention(x)
```

## Arguments

- reason:

  A single string naming the reason in snake_case, for example
  `"engine_missing"`, `"out_of_scope"`, `"no_quorum"`, `"not_grounded"`.

- detail:

  Optional single string with the specifics a reader needs.

- scope:

  Single string naming the part of the package that declined (`"lens"`,
  `"comparison"`, `"resolution"`, `"manifest"`).

- ...:

  Further named fields carried on the object.

- x:

  Any object.

## Value

A list of class `c("quorum_abstention", "orchestra_refusal")` with
`abstained = TRUE`, `reason`, `detail`, `scope` and any extra fields.

## Examples

``` r
a <- quorum_abstention("engine_missing", "tmbstan is not installed", "lens")
is_quorum_abstention(a)
#> [1] TRUE
```
