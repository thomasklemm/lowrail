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
| 1 | **IX1: adapter-specific `IndexDefinition` readers removed.** `index.lengths` / `index.type` raise `NoMethodError` on PostgreSQL, all five readers on SQLite | #59850 (kamipo, merged 2026-11-18) | index-recreating migration helpers of GitLab and Mastodon (`length: index.lengths`), online_migrations 0.37 (`lengths`, `opclasses`), active_record_doctor 2.1 (`type`) | rails/rails: no issue or PR (open-PR files and #59850's cross-references checked: only oracle-enhanced and sqlserver adapter follow-ups). Downstream: gregnavis/active_record_doctor#251 (open, 2026-11-20) | built: `thomasklemm/index-definition-adapter-readers` @ `0f2f426a85`; queue [IX1](../../bench/upstream/pr-queue/items/IX1.md); thermos-sol review running; fix list pending |
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
