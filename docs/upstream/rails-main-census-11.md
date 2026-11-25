# Rails-main census 11: main against 8-1-stable before 8.2, with a compatibility sweep

**In progress (2026-11-25).** The CPU and allocation labels and the gem-suite sweep are still running; this page
is pushed early so reviewers can append sections. Numbers below this line are final only where a section says so.

Census 11 compares Rails main [`cf0325a832`](https://github.com/rails/rails/commit/cf0325a832a1594f01d866da1e4ad23d962d886b)
(2026-11-25, #59918) with 8-1-stable [`1afb398af9`](https://github.com/rails/rails/commit/1afb398af94c3f76567d427a279637dbfaac8b3f)
(2026-11-24) and with census 10's main [`4500a94c34`](https://github.com/rails/rails/commit/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff),
on Ruby 4.0.9, census 10's 8 apps and its method. Main merged 55 first-parent commits since census 10, 8-1-stable 10.

## Findings so far (correctness)

| # | Finding | Introduced by | Reach | Ownership | State |
| ---: | --- | --- | --- | --- | --- |
| 1 | **IX1: adapter-specific `IndexDefinition` readers removed.** `index.lengths` / `index.type` raise `NoMethodError` on PostgreSQL, all five readers on SQLite | #59850 (kamipo, merged 2026-11-18) | index-recreating migration helpers of GitLab and Mastodon (`length: index.lengths`), online_migrations 0.37 (`lengths`, `opclasses`), active_record_doctor 2.1 (`type`) | rails/rails: no issue or PR (open-PR files and #59850's cross-references checked: only oracle-enhanced and sqlserver adapter follow-ups). Downstream: gregnavis/active_record_doctor#251 (open, 2026-11-20) | built: `thomasklemm/index-definition-adapter-readers` @ `0f2f426a85`; queue [IX1](../../bench/upstream/pr-queue/items/IX1.md); [thermos-sol: changes](#ix1): delete redundant comment/trailer; correct body claims and permalinks |
| 2 | **TA1: token-auth block gets a third argument**, so `authenticate_with_http_token(&method(:x))` with a two-parameter method raises `ArgumentError` | #58211 (Chad Cole, July 2026) | keygen-api, quepid, token_authenticate_me | **open rails/rails#59858 (czj, 2026-11-18) fixes it**, and keeps an optional third parameter's default. Missed by keyword search; found by thermos-sol | superseded ([TA1](../../bench/upstream/pr-queue/items/TA1.md)); fork branch `thomasklemm/token-auth-two-parameter-procedures` @ `a8a0745f1d` kept, not to open |
| 3 | **AM2: `action_mailer/railtie` no longer loads `active_job/railtie`.** An app that requires the mailer railtie without the Active Job one: `config.active_job.*` raises `NoMethodError` at boot, and `deliver_later` enqueues to the default Async adapter instead of the configured one; `defined?(ActiveJob)` is false at test-case load, so turbo-rails skips `Turbo::Broadcastable::TestHelper` (view_component's sandbox no longer loads) | #59820 (byroot, merged 2026-11-16) | apps with an explicit railtie list that omits `active_job/railtie`; of 10 sampled `config/application.rb` files that require the mailer railtie, 9 also require Active Job's; gem dummy apps (view_component) | deliberate; the CHANGELOG mentions only standalone use ("add Active Job to your Gemfile"), the 8.2 upgrade guide nothing. No issue or PR; #59820 has no cross-references | candidate upgrade-guide note (UG82 style); not built |
| 4 | **SC1: main's YAML schema cache cannot be loaded by 8.1** (`PostgreSQL::IndexDefinition`, `slot:`) | #59850, #59141 | apps that dump `db/schema_cache.yml` and roll back a deploy from 8.2 to 8.1 | none | record only (forward compatibility is not promised); it broke census 11's codetriage labels until the cache was removed |
| 5 | **RQ1: 26 framework files no longer load on their own after `require "active_support"`** (e.g. `action_controller/metal/strong_parameters`: `class_attribute` without its require, c562b54c09) | several, mostly cattr→class_attribute and new core-ext uses | pundit's spec requires `strong_parameters` directly and no longer loads | none; precedent b3b2662f13 (Kenta Ishizaki) merged the same kind of missing requires | record; low |

Not findings (read and probed, no break): #59855 token-scheme parsing (8.1 vs main header matrix differs only in
case-insensitive schemes and DPoP, both intended), #59868 `SubstituteBinds`, #59933 integer shards, #59966
`MessageEncryptor` class attribute, #59963 `AttributeSet#to_hash`/`#keys` single pass, #59901 shared relation
delegation methods.

## Compatibility sweep

95 suites: every suite of ecosystem rounds 1 and 2 and round-59141 with their recorded settings, plus
active_record_doctor 2.1.0 (PostgreSQL, SQLite) and online_migrations 0.37.0. Manifest
[`round-c11.yml`](../../bench/upstream/readiness/round-c11.yml), readiness runner, seeds 4242 and 1717, two runs per
tree. **Running**; partial report after 14 suites: one new flag (view_component, AM2), the rest known (E2, ransack
`SelectManager`, L1) or failing on both trees.

## Census (CPU and allocations)

**Running.** Labels `a11m`/`a11m2`, `a11s`/`a11s2`, `a11c10` (allocations, interpreter and YJIT) and `c11m`/`c11m2`,
`c11s`, `c11c10` (Callgrind, interpreter), fixed heap, A/A, census 10's scripts. codetriage is rerun for every label
without `db/schema_cache.yml` (SC1).

## Method and pins

* Rails main `cf0325a832`, 8-1-stable `1afb398af9`, census 10 main `4500a94c34`; Ruby 4.0.9 (`3e93b23afc`).
* Fixed heap `RUBY_GC_HEAP_{0..4}_INIT_SLOTS=1000000/250000/100000/20000/10000`; census 8's patched Valgrind 3.19.
* Repros: `.amp/in/orb-backup/c11/repro/` (`ix1_index_readers.rb`, `pg_index_dump.rb`, `ta1_token_method_arity.rb`,
  `token_auth.rb`, `am2_mailer_without_job_railtie.rb`, `ac1_action_cable_hook.rb`).

## Exact-head review method (2026-11-25)

The two passes below are final for their named heads and the queue bodies read from Lowrail `c51b20c3`; the census above remains in progress. Reviewer `thermos-sol` applied both Thermos rubrics directly in [this review thread](https://ampcode.com/threads/T-01a212b7-add7-770d-90b0-f74112d7d64c), without delegation or other threads. Code was audited before the introducing PR discussions were read. No Rails source, branch, PR or comment was changed.

Both candidates have parent [`cf0325a832a1594f01d866da1e4ad23d962d886b`](https://github.com/rails/rails/commit/cf0325a832a1594f01d866da1e4ad23d962d886b). Stable control: [`1afb398af94c3f76567d427a279637dbfaac8b3f`](https://github.com/rails/rails/commit/1afb398af94c3f76567d427a279637dbfaac8b3f), reporting 8.1.4.1. Runtime source locations were checked to ensure the stable probes loaded that checkout, not the candidate. Neither introducing change is an ancestor of this stable control; the latest published Rails release checked was v8.1.4.1. Both defects also remain in upstream main [`818edfd76a405b29f4695e051c07ea28a5476a4e`](https://github.com/rails/rails/commit/818edfd76a405b29f4695e051c07ea28a5476a4e).

These review runs use Ruby **4.0.7** (`229531a6cf`), Minitest 6.1.0, SQLite 2.10.2 gem and PostgreSQL 17, not the census's Ruby 4.0.9. The isolated component bundle, lockfile, generated before/after sources, probes, complexity reports and run logs are retained locally under `.amp/in/orb-backup/rails-review/`. `env.sh` selects that bundle; no Lowrail runtime is loaded. Commands below run in the named Rails component, with seed 41231 and one worker.

## IX1

**Pass:** `reviewer: thermos-sol`; **head:** [`0f2f426a85b759ee74af71692a9651f7391a616f`](https://github.com/thomasklemm/rails/commit/0f2f426a85b759ee74af71692a9651f7391a616f); **verdict: changes**. The five readers have no identified functional defect within the proposed scope. Comment, commit metadata and body corrections are required before opening; this is not an approval of the current head/body.

### Correctness, intent and ownership

[The introducing PR](https://github.com/rails/rails/pull/59850) deliberately moved adapter-specific state and its schema handling into the adapter classes. Its two commits are [`350cf02795`](https://github.com/rails/rails/commit/350cf02795c538718683e42853c820e6bbdcfeae) and [`023563b8c5`](https://github.com/rails/rails/commit/023563b8c51f8197c2044a8543863e9645940023), merged 2026-11-18. The PR has no conversation comments, inline comments or reviews. Its body explicitly retains abstract `valid_index_options` for cross-adapter schema compatibility; it does not discuss downstream reader calls, approve breaking those callers, or prescribe a deprecation. No corresponding removal/deprecation CHANGELOG entry was found.

Thus this is an **unreleased compatibility regression caused by an intentional internal refactor**, not an accidental deletion of a promised public API. `IndexDefinition` is `:nodoc:`. The DECISIONS private-restore conditions are met: unreleased, several released callers, five small fallbacks that leave adapter ownership and schema handling intact. Plain fallbacks are a reasonable proposal. If the maintainer's goal is also to eliminate these reader names on unsupported adapters, use deprecated neutral-value fallbacks as a transition rather than reverting the adapter split. There is no evidence that the maintainer requested that removal or deprecation policy; do not present either as agreed.

Searches for `IndexDefinition lengths`, `59850`, and adapter-specific readers found no competing Rails restore. [active_record_doctor issue 251](https://github.com/gregnavis/active_record_doctor/issues/251) is an existing open downstream report, created 2026-11-20, with no replies when checked; it proposes guarding `type` in the gem. The Rails fix is therefore a compatibility choice, not the only possible ownership decision.

The head restores these live `connection.indexes` values, equal to the stable control:

| Reader | SQLite | PostgreSQL |
| --- | --- | --- |
| `lengths` | `{}` | `{}` |
| `opclasses` | `{}` | `{}` for an ordinary index; adapter-owned opclasses still win |
| `type` | `nil` | `nil` |
| `include` | `nil` | `nil` for an ordinary index; included columns still win |
| `nulls_not_distinct` | `nil` | `false` for an ordinary index; `true` still wins when set |

The same live probe also created a PostgreSQL index with `opclass: :text_pattern_ops`, `include: [:score]` and `nulls_not_distinct: true`; both stable and the head retained all three. The abstract hash fallbacks return fresh hashes rather than restoring instance-variable identity/mutation behavior: this is a neutral reader-value shim, not restoration of the old constructor or every internal object behavior. No MySQL execution was performed. Constructor keyword removals and schema-cache rollback compatibility are outside this diff and are not certified by this pass.

### Released callers and default-branch check

Each linked file was fetched at its SHA and its quoted line checked. Rubygems reports the named gem versions as the latest releases. GitLab is pinned to the v19.5.1 tag available in its GitHub mirror, not claimed to be the latest release on gitlab.com.

| Caller | Released source and exact call | Default branch when checked |
| --- | --- | --- |
| GitLab v19.5.1 | [migration_helpers.rb:605](https://github.com/gitlabhq/gitlabhq/blob/449ed2875c2e3c4b51169484b799f4f803194ab5/lib/gitlab/database/migration_helpers.rb#L602-L606): `length: index.lengths,` | [master:605](https://github.com/gitlabhq/gitlabhq/blob/d7b9a6176ab4e279465ba3ee09922cde2b74de47/lib/gitlab/database/migration_helpers.rb#L605): still calls it |
| Mastodon v4.7.6 | [migration_helpers.rb:669](https://github.com/mastodon/mastodon/blob/a593c9420d2ff4664d448a9cb71bf8ed4ff0c29a/lib/mastodon/migration_helpers.rb#L666-L670): `length: index.lengths,` | [main:669](https://github.com/mastodon/mastodon/blob/18a36b09e39529e683a3fe9352c906fd147d27d0/lib/mastodon/migration_helpers.rb#L669): still calls it |
| online_migrations 0.37.0 | [change_column_type_helpers.rb:439](https://github.com/fatkodima/online_migrations/blob/82e264fd468158c6a4f68a866dbc5261e9b96b24/lib/online_migrations/change_column_type_helpers.rb#L437-L449): `length: index.lengths,`; also `if index.opclasses.present?` at line 449 | master is the same commit; no unreleased fix |
| active_record_doctor 2.1.0 | [extraneous_indexes.rb:74](https://github.com/gregnavis/active_record_doctor/blob/62882337c817f0b9ca13df996c4cc8c804cfe29f/lib/active_record_doctor/detectors/extraneous_indexes.rb#L73-L77): `return false if index1.type != index2.type` | [master:74](https://github.com/gregnavis/active_record_doctor/blob/df5265fea6f76dae826d7df2c1edf84e5f51e122/lib/active_record_doctor/detectors/extraneous_indexes.rb#L74): still calls it |

The first three are index-recreating migration helpers. The doctor is an index-comparison detector, not a helper recreating an index after a column type change. Reading its `respond_to?` guards also confirmed that `opclasses` and `include` are guarded but `type` is not.

### Tests and maintainability

On the **unmodified exact head**, from `activerecord/`:

```sh
bundle exec ruby bin/test test/cases/migration/index_test.rb test/cases/schema_dumper_test.rb test/cases/connection_adapters/schema_cache_test.rb --seed 41231
bundle exec ruby bin/test -a postgresql test/cases/migration/index_test.rb test/cases/schema_dumper_test.rb test/cases/connection_adapters/schema_cache_test.rb test/cases/adapters/postgresql/schema_test.rb test/cases/adapters/postgresql/postgresql_adapter_test.rb test/cases/adapters/postgresql/active_schema_test.rb --seed 41231
```

| Run | Runs | Assertions | Failures | Errors | Skips |
| --- | ---: | ---: | ---: | ---: | ---: |
| SQLite (`sqlite3_mem`) | 116 | 1383 | 0 | 0 | 5 |
| PostgreSQL | 373 | 2294 | 0 | 0 | 1 |

The standalone new regression test passes with five assertions. To test the production diff removed, `ix1-without-fix.rb` removes exactly the five added abstract methods in-process, leaving the test and every other method unchanged. Running `bin/test .../migration/index_test.rb -i test_adapter_specific_attributes_are_readable_on_every_adapter --seed 41231` with that preload gives **1 run, 1 error, 0 assertions** on each adapter: `NoMethodError: lengths`, on `IndexDefinition` / `PostgreSQL::IndexDefinition` respectively. The initializer, adapter overrides and production files remain untouched. Initial runner setup errors (a wrong schema-cache test path, then PostgreSQL's missing `en_US.UTF-8` locale) were corrected before the reported runs; they are not test failures or suppressed checks.

Cold read: “If an adapter has no implementation for an index attribute, return the previous neutral value; supported adapters keep their readers.” There is no new state, guard, layer or schema behavior. The existing endless-method style is already used nearby. The file was already over 1000 lines (1184 → 1192); this does not cross the threshold or justify a new abstraction. Each new literal-return reader has ABC 0, cyclomatic/perceived complexity 1/1, and no nonzero Flog score. This is the simplest shape for the stated compatibility proposal.

### Body and commit audit; required changes

The queue body was reviewed as written, not silently rewritten:

| Sentence / part | Assessment |
| --- | --- |
| Title, “Keep adapter-specific index readers on every `IndexDefinition`” | Correct scope. |
| “#59850 moved … into `MySQL::IndexDefinition` and `PostgreSQL::IndexDefinition`.” | Verified in the two introducing diffs. Add that the base class/API is private (`:nodoc:`), as DECISIONS requires for a restore. |
| “Code that runs on any adapter … raises `NoMethodError`” and the PostgreSQL example | Verified with a real indexed table on stable, the head and the counterfactual. Do not expand this to a promise of constructor compatibility. |
| “Migration helpers … GitLab's and Mastodon's … and so do online_migrations and active_record_doctor” | Must replace branch-only links with the release/line links above, link the two currently unlinked gems, and separate the doctor's `type` comparison from the migration-helper `lengths` claim. |
| “This defines the five readers … with the values 8.1 returned …” | Verified for the neutral reader values; not a claim of mutable-object identity or accepted constructor keywords. |
| “The adapter subclasses keep their own readers …” | Verified by inheritance, supported-value probes, dumper/cache tests and PostgreSQL adapter tests. |

The body is short, has a useful concrete failure and no test-count/benchmark/footer noise. For the prescribed problem → change → affected callers shape, move the existing change paragraph before the caller paragraph; cut rather than adding a report. There is no need for a new CHANGELOG entry for this minor unreleased bug fix ([Rails contributing guide](https://github.com/rails/rails/blob/cf0325a832a1594f01d866da1e4ad23d962d886b/guides/source/contributing_to_ruby_on_rails.md#L614-L618)). A decision to add a deprecation would instead need its notice/entry.

The commit title and substantive message describe the actual reader move and failure, with Thomas as both author and committer. **Must remove its `Amp-Thread-ID` trailer** using `script/commit` when the builder rebuilds it. **Must delete the added two-line comment** at [schema_definitions.rb:36–37](https://github.com/thomasklemm/rails/blob/0f2f426a85b759ee74af71692a9651f7391a616f/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb#L36-L42): it narrates the adapter overrides already clear from the definitions and regression test. These are required by DECISIONS, not functional defects. Any rebuilt head needs its own confirm pass.

## TA1

**Pass:** `reviewer: thermos-sol`; **head:** [`a8a0745f1dbb4749bc4bb49deb309fde2b7b290f`](https://github.com/thomasklemm/rails/commit/a8a0745f1dbb4749bc4bb49deb309fde2b7b290f); **verdict: changes / do not open**. The coordinator has marked the item superseded by the existing [Rails PR 59858](https://github.com/rails/rails/pull/59858), by czj, created 2026-11-18, head [`db2a82518b0938d0e548cc3e9ec706b61539da43`](https://github.com/czj/rails/commit/db2a82518b0938d0e548cc3e9ec706b61539da43). Its diff addresses this same regression, also covering optional-third defaults that TA1 misses. No competing PR or upstream comment should be created from this item.

### Regression, original discussion and ownership correction

[PR 58211](https://github.com/rails/rails/pull/58211) merged 2026-07-28; its substantive commit is [`156cd688e9df0d0a8b363494e484101a0cc96bc7`](https://github.com/rails/rails/commit/156cd688e9df0d0a8b363494e484101a0cc96bc7). The [CHANGELOG entry](https://github.com/rails/rails/blob/a8a0745f1dbb4749bc4bb49deb309fde2b7b290f/actionpack/CHANGELOG.md#L313-L330) calls the scheme “an optional third argument.” This is absent from 8-1-stable and unreleased; a two-positional-argument method still works on the stable control and raises on main.

However, this was **explicitly discussed before merge**, not an undiscovered accidental break:

* [chad-cole](https://github.com/rails/rails/pull/58211#discussion_r3632789816) said the original arity check was for two-argument methods converted to procs.
* [byroot](https://github.com/rails/rails/pull/58211#discussion_r3636481877) asked whether checking arity was necessary, expecting a Proc rather than a Lambda or Method.
* After confusing `&:method` with `&method(:method)`, [the author corrected that conclusion](https://github.com/rails/rails/pull/58211#discussion_r3659069922): method blocks would get argument errors without the check.
* [The author repeated the precise compatibility failure](https://github.com/rails/rails/pull/58211#discussion_r3659698217) on the final unconditional call.

The earlier queue note's “only comment is a thank-you” described conversation comments but missed the inline review, and its “no PR on arity” is false: #59858 is open. The observed break is real; a documented/deprecated removal of method callbacks is not established. A compatibility fix, not a new deprecation, matches the optional-argument feature description. If maintainers intend to exclude lambda/method callbacks, that needs an explicit transition rather than an immediate argument error. That decision now belongs in the already-open PR, without an unsolicited competing discussion from us.

### Released callers

| Caller | Released call and signature, checked at the linked SHA | Default-branch check |
| --- | --- | --- |
| keygen-api v1.7.0 | [authentication.rb:12](https://github.com/keygen-sh/keygen-api/blob/c0d319d3cad90ca94fb88e53828391d20608447c/app/controllers/concerns/authentication.rb#L9-L12): `authenticate_or_request_with_http_token(&method(:http_token_authenticator))`; [line 297](https://github.com/keygen-sh/keygen-api/blob/c0d319d3cad90ca94fb88e53828391d20608447c/app/controllers/concerns/authentication.rb#L297-L299): `def http_token_authenticator(http_token = nil, options = nil)` | [master:12](https://github.com/keygen-sh/keygen-api/blob/69c8327815cf16f987e3d2e01e35a38e667fccb6/app/controllers/concerns/authentication.rb#L12) and [297](https://github.com/keygen-sh/keygen-api/blob/69c8327815cf16f987e3d2e01e35a38e667fccb6/app/controllers/concerns/authentication.rb#L297): unchanged call/signature |
| quepid v8.8.0 | [api_key_authenticatable.rb:18](https://github.com/o19s/quepid/blob/c9a2f9bf815b49a9b9ec0177ceaad5d4103b559f/app/controllers/concerns/api_key_authenticatable.rb#L17-L18): `@current_user = authenticate_or_request_with_http_token(&method(:authenticator)) if @current_user.nil? && !request.headers['Authorization'].nil?`; [line 30](https://github.com/o19s/quepid/blob/c9a2f9bf815b49a9b9ec0177ceaad5d4103b559f/app/controllers/concerns/api_key_authenticatable.rb#L30-L33): `def authenticator http_token, _options` | [main:18](https://github.com/o19s/quepid/blob/bef885958b1143807a654cdd31d457893d6b4cab/app/controllers/concerns/api_key_authenticatable.rb#L18) and [30](https://github.com/o19s/quepid/blob/bef885958b1143807a654cdd31d457893d6b4cab/app/controllers/concerns/api_key_authenticatable.rb#L30): unchanged |
| token_authenticate_me 0.11.2 (latest Rubygems release) | [header_authentication.rb:10–15](https://github.com/wildland/token_authenticate_me/blob/79af17dedb49c43666e192cd900611f9663733cb/lib/token_authenticate_me/header_authentication.rb#L9-L16): `controller.authenticate_with_http_token(&method(:token_handler))`; `def token_handler(token, options)` | [master:10–15](https://github.com/wildland/token_authenticate_me/blob/fa2fd0c0ef23923f3b065527328826a7c63637b1/lib/token_authenticate_me/header_authentication.rb#L9-L16): unchanged |

The gem supports the queue's reach claim even though it is not named in the proposed body. These are source-level compatibility callers; this pass did not boot the complete apps or claim that they already deploy Rails main.

### Exactness finding and boundaries

**P2 — incomplete restoration for optional third positional parameters**, [takes_scheme?:603](https://github.com/thomasklemm/rails/blob/a8a0745f1dbb4749bc4bb49deb309fde2b7b290f/actionpack/lib/action_controller/metal/http_authentication.rb#L599-L604). Counting both `:req` and `:opt` means a lambda or method `(token, options, strict = false)` receives `:token` in `strict` instead of retaining `false` as on 8.1. Authentication code using that flag can change its decision without raising. This is a main regression left unaddressed by the new predicate, not a new defect introduced relative to the parent. The test covers an optional first/second parameter, but no optional third parameter.

If the item were revived, the smallest correction is to count only `:req` in the final clause, keeping the non-lambda and `:rest` clauses. A scratch-only replacement of that clause passes all 21 policy cases below. The existing #59858 already implements that compatibility choice, so fixing/opening our duplicate is not recommended.

| Probe group | Exact head | Stable / policy |
| --- | --- | --- |
| Two positional parameters: lambdas, bound methods, one/both optional | Correct, no third argument | Same as 8.1 |
| Two positional plus optional keyword, `**kwargs`, or `**nil` | Correct, no positional scheme | Same as 8.1; keyword parameters do not consume a positional slot |
| Optional third positional, lambda or method; optional second and third | **Three mismatches:** third value is `:token` | Keep `false` as on 8.1 |
| Three required positional arguments | Receives normalized scheme | Preserve #58211's feature, not a valid two-argument 8.1 callback |
| Ordinary procs, splats, method splats | Three arguments, ignored or captured normally | Preserve the new feature; this is not a blanket 8.1 argument-count restore |
| Curried three-argument lambda | Receives enough arguments to execute, not a partially applied Proc | Keep the rest-parameter path; passing only two could return a truthy Proc as a login result |
| `Symbol#to_proc` forwarding to a one-argument method on the token | Still errors, as on main | Worked with two total arguments in 8.1; opaque rest forwarding is not repaired here |
| Invalid one-/four-positional or required-keyword signatures | Still raises `ArgumentError` | No retry/rescue that could mask a callback error |

The symbol boundary was exercised with a token subclass and a `check(options)` method through an overridden parser. Its `&:check` proc advertises a rest parameter, so both TA1 and the required-only scratch variant still forward the scheme and raise. General splat forwarders to two-argument methods have the same limitation. Do not replace the predicate with `arity == 2` (optional/keyword cases differ) or send two arguments to every opaque rest proc (currying changes the authentication result). These are explicit scope boundaries, not newly introduced failures or a claim that #59858 solves every callback shape.

### Tests and maintainability

On the **unmodified exact head**, from `actionpack/`:

```sh
bundle exec ruby bin/test test/controller/http_token_authentication_test.rb test/controller/http_basic_authentication_test.rb test/controller/http_digest_authentication_test.rb --seed 41231
```

**108 runs, 242 assertions, 0 failures, 0 errors, 0 skips.** Restoring exactly the parent's `authenticate` method in-process from `git show a8a0745f1d^:.../http_authentication.rb`, while retaining the added test, gives **1 run, 1 error, 0 assertions** for `-i test_authenticate_calls_a_two-parameter_lambda_without_the_scheme`: `ArgumentError (given 3, expected 2)`. Thus the added test does fail without the production fix, but misses the optional-third defect.

`ta1-matrix.rb` calls the public controller helper with asymmetric token/options values. The stable control passes all **18** stable-valid cases. The parent fails **13/21** policy cases, the head fails **3/21**, and the required-only scratch variant passes **21/21**. The symbol boundary is logged separately, not counted as a passing case. Five scheme/empty-token/non-invocation controls pass on main and the head. Seven additional invalid-signature, custom `to_proc`, and exact false/nil-return controls pass on the stable control and the head. No security bypass was demonstrated; the optional-third mismatch is a verified callback-semantics defect, not a claim of an exploit in the named apps.

Cold read: “Ordinary procs and rest-accepting callbacks get the scheme; fixed-arity callbacks get it when their positional signature selects the new feature.” The call-site branch lives at the correct boundary and the private classifier avoids duplicating authentication/parsing logic. Inspecting parameter kinds is justified; there is no safe one-number arity replacement. No new wrapper/type/version mode or file-size boundary is introduced (604 → 617 lines). The predicate's optional-slot choice, not its placement, is wrong for 8.1 compatibility. Complexity cost is real but local: `authenticate` ABC 13.34 → 15.68, cyclomatic 4 → 5, perceived 5 → 7, Flog 16.5 → 19.1; new `takes_scheme?` ABC 11, cyclomatic/perceived 6/6, Flog 16.5. The extra dispatch is justified by strict callback compatibility, not performance. RuboCop metrics were measured with zero thresholds to report all scores, not used as a pass/fail style gate.

### Body and commit audit; disposition

| Sentence / part | Assessment |
| --- | --- |
| Title, “Don't pass the scheme to two-parameter token authentication lambdas” | Accurately names the narrow change; not proof of complete compatibility. |
| “Since #58211, token authentication calls its block with a third argument, the request's scheme.” | Verified in the introducing diff and CHANGELOG. |
| “A method passed as the block is a lambda, so an app that does …” | `Method#to_proc.lambda?` is true; the two-parameter example follows the released quepid caller. |
| “… gets `ArgumentError …` on every request with a token on main, where 8.1 authenticated it.” | Verified for a valid token whose callback would succeed; no token still skips the callback. Prefer describing callback invocation rather than promising success for arbitrary credentials. |
| “keygen-api and quepid authenticate this way.” | Source verified above, including keygen's optional two-positional signature. Replace drifting branch URLs with both call and signature line permalinks. |
| “This passes the scheme only to blocks that can take it: procs, and lambdas with a third or a rest parameter.” | Describes the current maximum-capacity predicate, but hides optional-third default changes and opaque forwarders. Must change the predicate/claim if pursuing 8.1 compatibility; a third *required positional* parameter is the relevant distinction. |
| “Lambdas that take the token and options get those two, as before.” | True for maximum-two-positional signatures, not every lambda callable with two arguments. Narrow that wording. |

The draft is otherwise short, with a concrete failure and no suite counts, commands, pins or footer. It need not gain an independent CHANGELOG entry for an unreleased minor fix; clarify the existing optional-third feature entry if its contract is narrowed, as #59858 does. The commit's substantive text matches the narrow two-parameter failure, but has the same overbroad “blocks that can take it” summary and a forbidden `Amp-Thread-ID` trailer. Both author and committer are Thomas. If ever rebuilt, remove that trailer and the added redundant two-line comment above `takes_scheme?`; the signature tests should explain the boundary. The immediate smallest action is to leave **TA1 superseded** and open/post nothing.

## IX1 confirmation

**Pass:** `reviewer: thermos-sol`; **head:** [`30368145ecb76500e10ae487c4ffff219b1403d7`](https://github.com/thomasklemm/rails/commit/30368145ecb76500e10ae487c4ffff219b1403d7), branch `thomasklemm/index-definition-adapter-readers-2`; **verdict: approve**, no remaining must-fixes. This supersedes the first pass's changes verdict for the rebuilt head and current queue body. Both Thermos rubrics were applied directly in the same review thread, without delegation. The parent is still `cf0325a832a1594f01d866da1e4ad23d962d886b`.

The complete tree diff against `0f2f426a85b759ee74af71692a9651f7391a616f` deletes **only the redundant two-line comment**. All five readers and the regression test are byte-identical; no source, schema, constructor or test behavior changed. The [first pass's correctness, private-API restore and ownership assessment](#ix1) therefore still applies, including the distinction between an intentional adapter split and an unannounced break for released reader callers. No new layer, conditional, state or maintainability problem was introduced.

Every required correction was checked:

* The redundant comment is gone. Both author and committer are Thomas Klemm `<github@tklemm.eu>`, and the commit has no trailers. Its title and message describe the reader move, affected calls, neutral values and retained adapter overrides accurately.
* The body now starts with the introducing change and proposed fix. “The adapter subclasses keep their own readers” still matches the code. The next paragraph explicitly discloses `:nodoc:` and limits the failure to callers of those readers; its PostgreSQL example remains valid.
* The caller paragraph now separates the doctor's `type` detector from index-recreating migration helpers. All four released-version SHA/line permalinks in the body were refetched and their calls reconfirmed against the [caller table](#released-callers-and-default-branch-check). No default-branch link remains in that paragraph.
* The remaining body sentences make no new constructor, identity, schema-cache or full-app compatibility promise. There are no test counts, commands, review notes, footer or performance claims in the draft. Its 127 whitespace-delimited tokens, including the example and links, do not justify adding further explanation.

The exact-head commands from [Tests and maintainability](#tests-and-maintainability) were rerun independently with the same isolated bundle, Ruby 4.0.7, seed 41231 and one worker:

| Run | Runs | Assertions | Failures | Errors | Skips |
| --- | ---: | ---: | ---: | ---: | ---: |
| SQLite (`sqlite3_mem`) | 116 | 1383 | 0 | 0 | 5 |
| PostgreSQL | 373 | 2294 | 0 | 0 | 1 |
| SQLite, new test with exactly the five readers removed in-process | 1 | 0 | 0 | 1 | 0 |
| PostgreSQL, same counterfactual | 1 | 0 | 0 | 1 | 0 |

Both counterfactual errors are `NoMethodError: lengths`, on the abstract and PostgreSQL index definitions respectively. Logs: `ix1-confirm-{sqlite,postgresql,without-sqlite,without-postgresql}.log` in the review scratch directory. This approves this exact reader-value shim and body, not MySQL execution, removed constructor keywords or schema-cache rollback behavior. No Rails branch, PR or comment was changed by this confirmation.

## UG82M

**Pass:** `reviewer: thermos-sol`; **head:** [`de4d27b257337464438695d3d6600af13bdf0482`](https://github.com/thomasklemm/rails/commit/de4d27b257337464438695d3d6600af13bdf0482), branch `thomasklemm/upgrade-guide-mailer-active-job-railtie`; **verdict: changes**, for PR-body accuracy, not a production-code defect. Both Thermos rubrics were applied directly, without delegation. The parent is `cf0325a832a1594f01d866da1e4ad23d962d886b`; the entire diff is 16 added guide lines. The body audited is the queue version first published at Lowrail `7001364f39`, unchanged when read from `d6410af0`.

### Intent, duplication and reach

[Rails PR 59820](https://github.com/rails/rails/pull/59820), by Jean Boussier, merged 2026-11-16 as [`ed17c90871d2c65acc201c082c1f6f924d6d55f9`](https://github.com/rails/rails/commit/ed17c90871d2c65acc201c082c1f6f924d6d55f9). Its substantive commit, [`1897e3587fc6e26b533d0f9e5462feb90921bad3`](https://github.com/rails/rails/commit/1897e3587fc6e26b533d0f9e5462feb90921bad3), explicitly intends mailer-only apps to load less code and removes `require "active_job/railtie"`. It has no conversation comments, inline comments or reviews. That change is absent from the stable control. The behavioral difference is real and unreleased, but **the decoupling itself is deliberate**. A guide note with an explicit require is a better fit than restoring coupling or demanding deprecation of it.

The [CHANGELOG entry](https://github.com/rails/rails/blob/1897e3587fc6e26b533d0f9e5462feb90921bad3/actionmailer/CHANGELOG.md#L1-L6) generally announces removal of the hard dependency. Its only migration instruction concerns standalone Action Mailer and adding Active Job to the Gemfile. It does not explain Rails applications' explicit railtie lists, missing `config.active_job`, adapter initialization or test hooks. The queue's “covers only standalone use” is too categorical; “omits the explicit-railtie migration” is accurate. The upgrade guide on the parent and checked upstream main `818edfd76a405b29f4695e051c07ea28a5476a4e` has no such note. Searches for the railtie require and recent Action Mailer upgrade-guide PRs found no competing note or restore.

The census reports nine of ten sampled mailer applications already require the Job railtie. This review did not rerun that sample or turn it into a prevalence estimate. That is narrow reach, not a reason to restore the deliberate dependency or invent a broad compatibility emergency. A short upgrade note is worthwhile: the affected framework-list configuration is concrete, and its fix is one require.

Released caller evidence was fetched at the linked SHAs:

| Caller | Released line permalink and observation | Default-branch check |
| --- | --- | --- |
| turbo-rails 2.0.23 | [engine.rb:103–109](https://github.com/hotwired/turbo-rails/blob/435135b26a4b62e49d2f55bb4b1fd419e3bfb228/lib/turbo/engine.rb#L103-L109): `if defined?(ActiveJob)` guards `include Turbo::Broadcastable::TestHelper` inside the test-case load hook | Same guard at main `10d72f2445217e4dcbcea73924c99e9cc12705f5`; no unreleased repair |
| ViewComponent 4.25.0 | [application.rb:5–12](https://github.com/ViewComponent/view_component/blob/2ebe9f9e3b6550c9df4d92a847b0acf160617fd2/test/sandbox/config/application.rb#L5-L12): `require "action_mailer/railtie"` and `require "turbo-rails"`, but no Job railtie | Main is the same release commit |

The Turbo omission was reproduced on the real released gem in a small Rails application. The complete ViewComponent sandbox suite was **not** run; the linked source shows the affected require pattern, not independent certification of the census's complete sandbox-failure claim.

### Behavioral checks and smallest required corrections

Fresh-process probes use the public Rails application configuration, mail delivery and test-case hooks, with source locations proving which checkout is loaded. They separate the three effects instead of describing one boot-failing application as also silently ignoring configuration:

| Scenario | 8-1-stable control | Exact UG82M head |
| --- | --- | --- |
| Mailer railtie, no Job railtie, test environment, no adapter setting | Job railtie loaded; `config.active_job` exists; `deliver_later` uses TestAdapter, one enqueued mail | Active Job absent after boot; delivery loads it late and uses AsyncAdapter |
| `config.active_job.queue_adapter = :inline` during initialization | Boots; one mail delivered inline | Boot raises `NoMethodError: active_job` |
| Explicit Job railtie before or after the mailer railtie, before boot | TestAdapter, one enqueued mail | Same; both require orders work |
| `rails/all` | TestAdapter, one enqueued mail | Same |
| Turbo action-cable/test-case hooks, implicit Job only | Broadcastable test helper included | Helper omitted; loading `active_job` after the test-case hook does not repair it |
| Turbo hooks with explicit Job railtie | Helper included | Same |
| Set `ReviewMailer.delivery_job.queue_adapter = :inline` directly | One mail delivered inline | Same; direct adapter configuration is not ignored |
| Production, implicit railtie, no adapter setting | AsyncAdapter | AsyncAdapter |

The boot error and changed test default are alternative paths. There is no evidence that a successfully configured queue adapter is silently discarded; the direct-adapter control contradicts a blanket version of that claim. This refines the AM2 row and UG82M `impact` wording above, without rewriting the census author's in-progress observations.

**P2, must fix before opening: the draft body conflates missing configuration with ignored configuration.** Delete “and `deliver_later` no longer uses its configured queue adapter.” Name `config.active_job.queue_adapter` (or settings under `config.active_job`) rather than saying setting the namespace itself fails. If retaining adapter detail, distinguish the unconfigured test default, TestAdapter → AsyncAdapter, from boot failure. Correct the same configured-adapter wording in `impact`.

**Must correct the CHANGELOG characterization:** delete the final “outside Rails only” sentence, or say its migration instructions do not cover explicit Rails railtie lists. The general decoupling announcement does cover the change. Cut the meta opening “This adds a section…” so the body starts with the affected application and introducing change. No new code, abstraction or upstream investigation is needed for these text corrections.

The guide itself is substantially accurate. Optional precision at [lines 155–156](https://github.com/thomasklemm/rails/blob/de4d27b257337464438695d3d6600af13bdf0482/guides/source/upgrading_ruby_on_rails.md#L155-L156): say “settings under `config.active_job`” and distinguish the boot failure from the fallback path. “If your app relied on the implicit require” also states the boundary more precisely than treating every explicit framework list alike; another engine can load the Job railtie. These are clarity improvements, not an identified runtime defect in the note's explicit-require remedy.

### Sentence audit and maintainability

| Draft part | Assessment against DECISIONS |
| --- | --- |
| Title, “Note in the upgrade guide that Action Mailer no longer loads Active Job” | Names the documentation change; body/guide correctly specify the railtie, rather than claiming Active Job can never load later. |
| “This adds a section … that the guide doesn't mention yet.” | True at the pinned parent and checked main, but meta text duplicates the diff. Cut for the prescribed problem-first shape. |
| “Since #59820 … no longer loads the Active Job railtie.” | Verified from the introducing source and boot probes. |
| “An app that lists its frameworks … raises … sets `config.active_job` … no longer uses its configured queue adapter.” | Boot-error portion needs a nested setting example; configured-adapter clause is unsupported and must be cut or replaced with the separate test-default behavior. |
| “The CHANGELOG entry covers Action Mailer used outside Rails only.” | Overstates the entry; cut or narrow to missing railtie-list migration instructions. |

The 75-word body has no test counts, commands, SHAs, review notes, footer or performance claim. It needs less text, not a report. It cites no downstream caller needing a body permalink; released caller evidence remains here. The commit contains only its accurate title, with Thomas as both author and committer and no trailers.

Cold read of the guide change: “If the mailer railtie was your only path to Job integration, require the Job railtie yourself; `rails/all` already does.” The existing 8.1 → 8.2 section is the canonical location. The Ruby fence and local prose style match neighboring upgrade notes. There is no added guard, state, framework branch, helper, abstraction or coupling. The file was already 3113 lines and becomes 3129, so this does not cross the 1000-line threshold or justify decomposing a chronological upgrade guide. No structural must-fix was found.

### Exact-head validation

All commands use the isolated review bundle and Ruby 4.0.7. The harness is retained in `.amp/in/orb-backup/rails-review/ug82m-{contract,probe}.rb`; it asserts expected adapters, boot-error names, helper inclusion and enqueued/delivered counts, not just successful process exits. Its stable control is `1afb398af94c3f76567d427a279637dbfaac8b3f`.

```sh
# Lowrail root, after sourcing .amp/in/orb-backup/rails-review/env.sh
bundle exec ruby .amp/in/orb-backup/rails-review/ug82m-contract.rb
# Repeat ug82m-probe.rb implicit with TREE=stable/head and RAILS_ENV=production

# actionmailer/
bundle exec ruby bin/test test/message_delivery_test.rb test/parameterized_test.rb test/test_helper_test.rb --seed 41231
# railties/
bundle exec ruby -Itest test/application/initializers/frameworks_test.rb --seed 41231
bundle exec ruby -Itest test/application/configuration_test.rb --name /active.job.adapter/ --seed 41231
# guides/
bundle exec rake test TESTOPTS='--seed=41231'
# Rails root, where the repository .mdlrc is applied
bundle exec mdl guides/source/upgrading_ruby_on_rails.md
```

| Check | Runs / assertions | Failures / errors | Skips |
| --- | --- | --- | ---: |
| Stable/head fresh-process contract | 18 scenarios passed | 0 mismatches | 0 |
| Production controls | Both trees use AsyncAdapter | 0 mismatches | 0 |
| Action Mailer delivery, parameterized and test-helper suites | 88 / 275 | 0 / 0 | 0 |
| Railties framework initializers | 28 / 52 | 0 / 0 | 0 |
| Railties adapter configuration cases | 7 / 14 | 0 / 0 | 0 |
| Guides suite | 18 / 39 | 0 / 0 | 2 |
| Rails-configured Markdown lint | Passed | 0 violations | — |

The first frameworks/Guides attempts exposed missing local `mysql2`/Dart Sass tooling; both were installed in the isolated review bundle, then the reported checks were rerun. Guides emits existing duplicate RDoc/lexer warnings. Running `mdl` from the Lowrail root applies the wrong defaults and reports numerous legacy guide violations; the Rails-root invocation above applies Rails's rules and passes. No check was suppressed or Rails source modified. This is documentation-only, so it adds no runtime test expected to fail without the note; the differential probes instead establish that the behavior it documents is real. Logs are retained under the review scratch directory (`ug82m-*-final.log`, `ug82m-mailer.log`, `ug82m-configuration.log`, `ug82m-production-controls.log`).
