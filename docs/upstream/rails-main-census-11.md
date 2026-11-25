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
