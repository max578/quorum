# test-quorum.R -- the front door: lenses in, a typed verdict out.

.shares_of <- function(tag) {
  c(sampler = paste0("s_", tag), objective = paste0("o_", tag),
    priors = paste0("p_", tag), data_prep = paste0("d_", tag))
}

.fixed_lens <- function(name, draws, expresses = "linear",
                        scope = function(spec) TRUE, tag = name) {
  force(draws)
  quorum_lens(name = name, member = "test",
              fit = function(spec, data, ...) draws,
              shares = .shares_of(tag), expresses = expresses,
              kind = S7::prop(draws, "kind"), scope = scope)
}

# The print method is registered against the package-qualified S7 class name,
# which S3 dispatch reaches only through the NAMESPACE registration. The
# method's own output is exercised by calling it, and the dispatch that
# registration buys is exercised separately.
.verdict_lines <- function(v) {
  fn <- get("print.quorum::quorum_verdict", envir = asNamespace("quorum"))
  utils::capture.output(fn(v))
}

.print_registered <- function() {
  tbl <- get(".__S3MethodsTable__.", envir = asNamespace("base"))
  exists("print.quorum::quorum_verdict", envir = tbl, inherits = FALSE)
}

.par_draws <- function(mu = 0, n = 400L, seed = 1L) {
  set.seed(seed)
  quorum_draws(list(`(Intercept)` = stats::rnorm(n, mu),
                    sigma = stats::rgamma(n, 9, 3)),
               source = "test")
}

test_that("two agreeing lenses are concordant and resolve to the first", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  expect_s7_class(v, quorum_verdict)
  expect_identical(v@status, "concordant")
  expect_identical(v@lenses, c("one", "two"))
  expect_identical(nrow(v@contributions), 2L)
  expect_true(all(v@contributions$contributed))
  expect_identical(v@resolution$carried_lens, "one")
  expect_identical(v@resolution$verdict, "decide")
  expect_null(v@abstention)
  expect_identical(nrow(v@findings), 0L)
})

test_that("a contributing lens without a decision rule offers no number", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  expect_true(is.na(v@resolution$action))
  expect_true(all(v@contributions$decisive))
})

test_that("lenses that disagree are discordant", {
  v <- quorum(list(.fixed_lens("one", .par_draws(0, seed = 1L)),
                   .fixed_lens("two", .par_draws(8, seed = 2L))),
              policy = quorum_policy(c("one", "two")))
  expect_identical(v@status, "discordant")
})

test_that("a disagreement across expressive power is a finding, not discord", {
  v <- quorum(list(
    .fixed_lens("one", .par_draws(0, seed = 1L), expresses = "linear"),
    .fixed_lens("two", .par_draws(8, seed = 2L),
                expresses = c("linear", "plateau"))
  ), policy = quorum_policy(c("one", "two")))
  expect_identical(nrow(v@findings), 1L)
  expect_identical(v@findings$finding, "shape_difference")
  expect_identical(v@findings$shapes, "plateau")
  expect_identical(v@status, "concordant")
})

test_that("a lens outside its scope contributes nothing", {
  d_local <- .par_draws()
  out_of_scope <- function(spec) {
    quorum_abstention("out_of_scope", "the spec is not this lens's", "lens")
  }
  v <- quorum(list(.fixed_lens("one", d_local),
                   .fixed_lens("two", d_local, scope = out_of_scope)),
              policy = quorum_policy(c("one", "two")))
  expect_identical(v@status, "no_quorum")
  expect_false(v@contributions$contributed[2L])
  expect_true(v@contributions$abstained[2L])
  expect_identical(v@contributions$reason[2L], "out_of_scope")
})

test_that("no quorum means no number, whatever the lenses that spoke said", {
  d_local <- .par_draws()
  declined <- function(spec) quorum_abstention("out_of_scope", NULL, "lens")
  v <- quorum(list(.fixed_lens("one", d_local),
                   .fixed_lens("two", d_local, scope = declined)),
              policy = quorum_policy(c("one", "two"), status_quo = 60))
  expect_identical(v@status, "no_quorum")
  expect_identical(v@resolution$verdict, "abstain")
  expect_true(is.na(v@resolution$action))
  expect_false(v@resolution$tier_one)
  expect_true(v@resolution$tier_abstain)
  expect_true(is_quorum_abstention(v@abstention))
  expect_identical(v@abstention$reason, "no_quorum")
  expect_identical(v@abstention$scope, "resolution")
})

test_that("one lens is a quorum when the policy says so", {
  v <- quorum(list(.fixed_lens("one", .par_draws())),
              policy = quorum_policy("one", min_lenses = 1L))
  expect_identical(v@status, "not_computed")
  expect_identical(v@resolution$carried_lens, "one")
  expect_null(v@abstention)
})

test_that("a fit that declines is recorded, never replaced by a number", {
  declining <- quorum_lens(
    name = "two", member = "test",
    fit = function(spec, data, ...) {
      quorum_abstention("engine_missing", "the engine is not installed",
                        "lens")
    },
    shares = .shares_of("two")
  )
  v <- quorum(list(.fixed_lens("one", .par_draws()), declining),
              policy = quorum_policy(c("one", "two"), min_lenses = 1L))
  expect_false(v@contributions$contributed[2L])
  expect_identical(v@contributions$reason[2L], "engine_missing")
  expect_true(is.na(v@contributions$action[2L]))
})

test_that("a caller's decision rule drives the action and the grounding", {
  decide_fn <- function(draws, grid) {
    list(action = 120, abstained = FALSE, reason = NA_character_,
         grounding = orchestraManifest::GROUNDING_GROUNDED)
  }
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")), decide = decide_fn)
  expect_identical(v@resolution$action, 120)
  expect_identical(v@contributions$grounding,
                   rep(orchestraManifest::GROUNDING_GROUNDED, 2L))
})

test_that("a decision rule that declines falls through to the status quo", {
  decide_fn <- function(draws, grid) {
    list(action = NA_real_, abstained = TRUE, reason = "insufficient_evidence",
         grounding = orchestraManifest::GROUNDING_GROUNDED)
  }
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two"), status_quo = 60),
              decide = decide_fn)
  expect_identical(v@resolution$carried_lens, "status quo")
  expect_identical(v@resolution$action, 60)
})

test_that("a decision rule that reports no grounding blocks the carry", {
  decide_fn <- function(draws, grid) {
    list(action = 120, abstained = FALSE, reason = "input_ungrounded",
         grounding = orchestraManifest::GROUNDING_UNVERIFIED)
  }
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two"), status_quo = 60),
              decide = decide_fn)
  expect_false(any(v@contributions$grounded))
  expect_identical(v@resolution$verdict, "abstain")
  expect_true(is.na(v@resolution$action))
})

test_that("the independence ledger weighs the pair and states its caveat", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  expect_true(is.list(v@independence))
  expect_true(is.matrix(v@independence$weight))
  expect_identical(v@independence$weight["one", "two"], 1)
  expect_true(is.na(v@independence$data_independence))
  expect_true(is.character(v@independence$caveat))
})

test_that("declared data independence clears the caveat", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")),
              data_independence = TRUE)
  expect_true(is.na(v@independence$caveat))
  expect_true(v@independence$data_independence)
})

test_that("two lenses sharing everything are one lens counted twice", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local, tag = "same"),
                   .fixed_lens("two", d_local, tag = "same")),
              policy = quorum_policy(c("one", "two"), independence_min = 0.5))
  expect_identical(v@independence$weight["one", "two"], 0)
  expect_identical(v@status, "concordant")
  expect_identical(v@agreement$pairs$status, "concordant")
})

test_that("the front door refuses a malformed call", {
  d_local <- .par_draws()
  one <- .fixed_lens("one", d_local)
  expect_error(quorum(list(one)), "`policy` is required")
  expect_error(quorum(list(one), policy = "no"), "must be a quorum_policy")
  expect_error(quorum(list(one), policy = quorum_policy("one"), decide = 1),
               "must be NULL or a function")
  expect_error(quorum(list(one), policy = quorum_policy("one"),
                      data_independence = "yes"), "single logical")
  expect_error(quorum(list(), policy = quorum_policy("one")), "non-empty list")
  expect_error(quorum(list(one, one), policy = quorum_policy("one")),
               "names must be unique")
  expect_error(quorum(list(1L), policy = quorum_policy("one")),
               "must be a quorum_lens")
})

test_that("a lens that breaks its own contract stops rather than degrades", {
  broken <- quorum_lens(name = "broken", member = "test",
                        fit = function(spec, data, ...) list(a = 1),
                        shares = .shares_of("broken"))
  expect_error(quorum(list(broken), policy = quorum_policy("broken")),
               "neither quorum_draws nor a typed abstention")
})

test_that("an unregistered lens name is named in the refusal", {
  expect_error(quorum("no_such_lens", policy = quorum_policy("no_such_lens")),
               "no lens named 'no_such_lens'")
})

test_that("the verdict prints its status, its carry and its caveat", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  out <- .verdict_lines(v)
  expect_true(any(grepl("status: concordant", out, fixed = TRUE)))
  expect_true(any(grepl("2 contributing, 0 abstained", out, fixed = TRUE)))
  expect_true(any(grepl("carried: one (decide)", out, fixed = TRUE)))
  expect_true(any(grepl("findings: 0", out, fixed = TRUE)))
  expect_true(any(grepl("independence:", out, fixed = TRUE)))
})

test_that("a no-quorum verdict prints the decline", {
  d_local <- .par_draws()
  declined <- function(spec) quorum_abstention("out_of_scope", NULL, "lens")
  v <- quorum(list(.fixed_lens("one", d_local),
                   .fixed_lens("two", d_local, scope = declined)),
              policy = quorum_policy(c("one", "two")))
  out <- .verdict_lines(v)
  expect_true(any(grepl("abstained: no_quorum", out, fixed = TRUE)))
})

test_that("a registered verdict prints through base::print", {
  skip_if_not(.print_registered(),
              "the S3 registration arrives with the generated NAMESPACE")
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  out <- utils::capture.output(print(v))
  expect_true(any(grepl("<quorum verdict>", out, fixed = TRUE)))
})

test_that("the verdict print method is defined for the qualified class", {
  expect_true(is.function(get("print.quorum::quorum_verdict",
                              envir = asNamespace("quorum"))))
})

test_that("the verdict is emitted as a consensus manifest that verifies", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  m <- v@manifest
  expect_true(orchestraManifest::is_orchestra_manifest(m))
  expect_identical(S7::prop(m, "inferential_target"), "consensus")
  expect_identical(S7::prop(m, "emitter_package"), "quorum")
  expect_true(orchestraManifest::verify_manifest(m)$ok)
  expect_s3_class(S7::prop(m, "summary"), "manifest_summary")
  expect_identical(S7::prop(m, "summary")$metrics$status, "concordant")
  expect_identical(S7::prop(m, "summary")$metrics$carried_lens, "one")
  expect_identical(nrow(S7::prop(m, "params")), 2L)
})

test_that("a manifest's payload edit is caught by its own hash", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  m <- v@manifest
  S7::prop(m, "params")$grounded[1L] <- FALSE
  expect_false(orchestraManifest::verify_manifest(m)$ok)
})

test_that("the run id is stable under re-emission of the same verdict", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")))
  expect_identical(S7::prop(quorum_manifest(v), "run_id"),
                   S7::prop(v@manifest, "run_id"))
  expect_match(S7::prop(v@manifest, "run_id"), "^quorum-[0-9a-f]{12}$")
})

test_that("lenses reading one data fact do not mint a grounded consensus", {
  d_local <- .par_draws()
  v <- quorum(list(.fixed_lens("one", d_local), .fixed_lens("two", d_local)),
              policy = quorum_policy(c("one", "two")),
              data_independence = FALSE)
  expect_identical(S7::prop(v@manifest, "metadata")$grounding,
                   orchestraManifest::GROUNDING_UNVERIFIED)
  v_ok <- quorum(list(.fixed_lens("one", d_local),
                      .fixed_lens("two", d_local)),
                 policy = quorum_policy(c("one", "two")),
                 data_independence = TRUE)
  expect_identical(S7::prop(v_ok@manifest, "metadata")$grounding,
                   orchestraManifest::GROUNDING_GROUNDED)
})

test_that("a manifest of a no-quorum verdict is typed as an abstention", {
  d_local <- .par_draws()
  declined <- function(spec) quorum_abstention("out_of_scope", NULL, "lens")
  v <- quorum(list(.fixed_lens("one", d_local),
                   .fixed_lens("two", d_local, scope = declined)),
              policy = quorum_policy(c("one", "two")))
  expect_true(S7::prop(v@manifest, "summary")$abstained)
  expect_identical(S7::prop(v@manifest, "summary")$abstain_reason,
                   "no_quorum")
  expect_true(orchestraManifest::verify_manifest(v@manifest)$ok)
})

test_that("quorum_manifest refuses anything that is not a verdict", {
  expect_error(quorum_manifest(list()), "must be a quorum_verdict")
})
