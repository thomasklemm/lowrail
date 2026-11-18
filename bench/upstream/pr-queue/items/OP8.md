---
id: OP8
repo: rails/rails
kind: fix
area: Active Record / Active Model attributes
reviewer: "tenderlove (author of #59083)"
branch: thomasklemm/frozen-default-attribute-unread
head: "71c77e3a01"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "OpenProject's HealthReport.new(...).save! stops raising PG::NotNullViolation; nested JSON defaults no longer shared between new records; fixes unreleased #59083"
rank: 1
risky: true
state: ready
pr: 59662
note: "2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-rails-ruby.md): body corrected in this item only, not PATCHed (live body unchanged): 'on an earlier revision of this change' cut (revision history). 2026-11-14: still needed after rails#59141 (tenderlove, merged 2026-11-11, an Array for Active Record attributes), which rewrote the default path; rebased onto main 50c54eed06 with no conflicts and an identical patch (range-diff =), force-pushed with a lease on 490fdf855b as 71c77e3a01, CI green (Buildkite 136616), merge state clean; body unchanged, its bdb3d96012 links still describe main (the same three lines are schema_context.rb L137-L139, attribute.rb L42-L44 unchanged); no comment. Evidence in the claude-code pass on 71c77e3a01. 2026-11-10: marked ready for review by script/pr-queue ready OP8 on Thomas's decision (head 490fdf855b, merge state clean, no comment); 15/15 non-draft rails/rails PRs after it. 2026-11-07: body fixed per claude-code pass (OpenProject migration link, hook clause) and Sol/Astra nits. opened as draft 2026-11-05; earlier heads f95cc1b6df, de7aff270c, c52724804d, 02443a3b04, 3b35e79cb5, 9b2a64d040; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: the freezable_default? hook for custom types; affected-model counts (OpenProject 51/305, Mastodon 6/117, shipit 9/26, lobsters 1/24) and the 18-22% Model.new microbenchmark, in docs/upstream/app-suites.md#openproject and bench/upstream/app_suites/op8-bench"
passes:
  - {reviewer: astra, head: "c52724804d", date: 2026-11-05, verdict: changes, open: "duck-typed types, sharper tests, body scope; applied"}
  - {reviewer: skeptic, head: "02443a3b04", date: 2026-11-05, verdict: changes, open: "blocker: DDL under sqlite3_ractor, applied, plus two nits"}
  - {reviewer: astra, head: "3b35e79cb5", date: 2026-11-05, verdict: nits, open: "round 2: approve; wrapper tests over Type::Json and the benchmark wording, applied in 9b2a64d040"}
  - {reviewer: sol, head: "9b2a64d040", date: 2026-11-05, verdict: approve, open: production code identical to the Astra-approved head}
  - {reviewer: astra, head: "9b2a64d040", date: 2026-11-05, verdict: nits, open: "production code verified identical to 3b35e79cb5; nits: native-JSON nested-isolation test; CHANGELOG entry declined (fixed change unreleased)"}
  - {reviewer: skeptic, head: "9b2a64d040", date: 2026-11-05, verdict: nits, open: "optional: body says override or forward the hook, but freezable_default? is nodoc; split test_freezing_eligibility_of_column_defaults; activerecord none-claim unverifiable"}
  - {reviewer: claude-code, head: "9b2a64d040", date: 2026-11-07, verdict: changes, open: "applied in 490fdf855b (rebased onto 9ba8b1edee, no conflicts, #59083 code unmoved): tests rewritten to public-API behaviour per the 11-06 rule (dropped the coder call-count test, _default_attributes.frozen? asserts, direct freezable_default? calls and the AM Attribute#freezable? tests); removed Value#freezable_default? and the NormalizedValueType override, dead because ActiveSupport DelegateClass is a ::Delegator and forwards dynamically; commit message updated"}
  - {reviewer: claude-code, head: "490fdf855b", date: 2026-11-07, verdict: changes, open: "code and commit message approved; body only, not posted: the structure.sql link 404s, use https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/db/migrate/20260428133700_create_health_reports.rb#L34; cut the nodoc hook clause to: `normalizes` and `encrypts` defer to the wrapped type, and other types keep main's behaviour. Verified: new tests fail on main, every remaining production line fails the suite when reverted, AR SQLite 9829 and PostgreSQL 11254 runs green, AM 1256, sqlite3_ractor file green, RuboCop clean; PG probe of jsonb/serialized/array/hstore/STI/proc defaults matches 8-1-stable and safe models stay frozen; store_model and attr_json unchanged vs main. Residual: no test for an encrypted Type::Json with a non-NULL default (needs support_unencrypted_data). Sol/Astra need a pass on the new head"}
  - {reviewer: sol, head: "490fdf855b", date: 2026-11-07, verdict: nits, open: "body: writable-defaults wording (applied to body; commit message left); per-case tests and a deserialize-count test (kept: count tests break the behaviour-only rule)"}
  - {reviewer: astra, head: "490fdf855b", date: 2026-11-07, verdict: nits, open: "body: 18-22% measured on an earlier revision (labelled in body); per-case tests (kept); CHANGELOG (none: regression unreleased)"}
  - {reviewer: claude-code, head: "490fdf855b", date: 2026-11-07, verdict: approve, open: "body confirm pass: live body equals the recorded one; all five links resolve (OpenProject migration L34 is `t.jsonb :results, null: false, default: {}`); every claim matches 490fdf855b (Mutable freezes only nil, Serialized never, encrypts forwards explicitly, normalizes by delegation, other types as on main, non-freezable models take 8.1's writable path); 18-22% label holds: measured on 8b817f9f36, which leaves the same measured models unfrozen, and the freezability check runs only at schema load"}
  - {reviewer: claude-code, head: "71c77e3a01", date: 2026-11-14, verdict: approve, open: "Rebase check after rails#59141 (main 50c54eed06, Ruby 4.0.9, PostgreSQL 17). Where new-record defaults come from now: Core#initialize calls attributes_builder.build_from_initialize, a LazyIndexedAttributeSet over an empty row with the FromInitContext; the first read (fetch_value_at!, behind _read_attribute_at!) goes cast_value -> default_attribute -> store(index, @ctx.default_at(index).dup), and the builder's @defaults are the Attribute objects of schema_attributes.defaults, the set build_default_attributes returns (now laid out by index_default_attributes into an IndexedRow::Mutable). That set is still frozen, which casts each value, only when every attribute is freezable?; Attribute#freezable?, #freeze, #initialize_dup, Helpers::Mutable and Type::Serialized are unchanged since 9ba8b1edee, and nothing on the new path casts a shared default in place (column_defaults deep_dups, init_attributes uses with_value_from_user). So OP8's decision applies unchanged. Plain main: OP8's two tests fail 4/4 on SQLite and PostgreSQL; serialized_jsonb_default_insert.rb changed=[results], PG::NotNullViolation; op8_probe2.rb unread changed=[prefs] saved nil, nested shared true, coder loads 2 before the first read; op8_probe3.rb nested jsonb, text[] and hstore defaults shared in Native and its STI child, read-only defaults. With OP8 every line equals 8-1-stable 71e963ed1b (saved {}; unread [] saved empty string, read first [prefs] saved nil, nothing shared, loads 0/2 in both models; probe3 nothing shared), models with scalar or NULL defaults keep read-only defaults. Reverting any of the four production lines fails OP8's tests. serialized_attribute_test 121 runs on sqlite3, postgresql and sqlite3_ractor; AR SQLite 10,379 and PostgreSQL 11,302 runs, only the secure_password timing test (green alone) and 4 sqlite_rake_test errors from a missing sqlite3 CLI (15 runs green once installed); AM 1,269; RuboCop 3,581 files clean. Callgrind vs main, median of 3, identical lockfiles (op8-bench/matrix5.sh, results-50c54eed06.tsv): scalar defaults -0.01%, '{}' JSON +18.94%, nested JSON +22.26%, A/A 0.00%, so the body's 18-22% holds; body unchanged. Range-diff against 490fdf855b is =, so the Sol and Astra passes on 490fdf855b reviewed the same patch; not rerun."}
  - {reviewer: claude-code, head: "71c77e3a01", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: nits, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Clause backed by app-suites.md OP8 (storages health status controller specs). op8-bench results link cut. Nit applied: 'in OpenProject's test suite' -> 'in its test suite'."}
  - reviewer: thermos-sol
    orb: T-01a1ee60-a4df-75cc-9428-abffe636e31c
    head: "71c77e3a013680390154ef9f8390c263e9fed126"
    date: 2026-11-18
    verdict: approve
    open: >-
      Both Thermos rubrics applied personally; the earlier-revision parenthesis
      is unnecessary and its removal leaves the recorded measurements honest.
      Keep respond_to?(:freezable_default?) for real duck-typed/decorated types
      without the optional hook, and the nil predicate for the only safely
      freezable Mutable default. Serialized must return false even for nil;
      the surviving coder-may-load-nil-as-container comment prevents replacing
      it with Mutable's predicate; encrypted_attribute_type's # :nodoc: keeps
      the internal hook out of the public docs. Both optional-hook guards use
      the same real type contract. Existing forwarding/delegation preserves
      normalizes and encrypts. Opened model/migration links and checked the
      described default against app-suites.md; body accurately separates the
      correctness restoration from its recorded instruction cost. Ruby 4.0.9
      serialized_attribute_test: 121 runs/290 assertions, 0F/0E, one existing
      Psych safe_load Time skip. Raw cat-file: one commit on 50c54eed06,
      Thomas author/committer, author date 1794052149 +0000, no trailers.
      No must-fix or structural regression.
---

# Keep models with mutable defaults off the frozen defaults

#59083 [freezes a model's default attributes](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/model_schema/schema_context.rb#L119-L121) when [every one is freezable](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activemodel/lib/active_model/attribute.rb#L42-L44); new records dup the cast value. Two mutable defaults break:

* A serialized default the coder doesn't round-trip reads as changed and is saved. OpenProject's [`HealthReport`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/models/health_report.rb#L33) loads its [`t.jsonb :results, null: false, default: {}`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/db/migrate/20260428133700_create_health_reports.rb#L34) as `[]`, so in its test suite on Rails main, `HealthReport.new(subject: storage).save!` raises `PG::NotNullViolation` (8.1: only after a read).
* A nested default (`'{"theme":{"mode":"light"}}'` with a JSON coder) is shared between new records.

Now types that include `Helpers::Mutable` (JSON, PostgreSQL arrays, hstore, points) freeze only NULL defaults, and serialized attributes never freeze their defaults, because a coder may load NULL as a container. `normalizes` and `encrypts` defer to the wrapped type, and other types keep main's behaviour. Models with such defaults keep 8.1's writable-defaults path. `Model.new` with a first read of a `'{}'` or nested JSON default uses 18–22% more Callgrind instructions than on main, Ruby 4.0.9.
