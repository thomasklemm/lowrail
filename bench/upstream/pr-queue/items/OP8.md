---
id: OP8
repo: rails/rails
kind: fix
area: Active Record / Active Model attributes
reviewer: "tenderlove (author of #59083)"
branch: thomasklemm/frozen-default-attribute-unread
head: "9b2a64d040"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: "OpenProject's HealthReport.new(...).save! stops raising PG::NotNullViolation; nested JSON defaults no longer shared between new records; fixes unreleased #59083"
rank: 1
risky: true
state: draft
pr: 59662
note: "opened as draft 2026-11-05; earlier heads f95cc1b6df, de7aff270c, c52724804d, 02443a3b04, 3b35e79cb5; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: the freezable_default? hook for custom types; affected-model counts (OpenProject 51/305, Mastodon 6/117, shipit 9/26, lobsters 1/24) and the 18-22% Model.new microbenchmark, in docs/upstream/app-suites.md#openproject and bench/upstream/app_suites/op8-bench"
passes:
  - {reviewer: astra, head: "c52724804d", date: 2026-11-05, verdict: changes, open: "duck-typed types, sharper tests, body scope; applied"}
  - {reviewer: skeptic, head: "02443a3b04", date: 2026-11-05, verdict: changes, open: "blocker: DDL under sqlite3_ractor, applied, plus two nits"}
  - {reviewer: astra, head: "3b35e79cb5", date: 2026-11-05, verdict: nits, open: "round 2: approve; wrapper tests over Type::Json and the benchmark wording, applied in 9b2a64d040"}
  - {reviewer: sol, head: "9b2a64d040", date: 2026-11-05, verdict: approve, open: production code identical to the Astra-approved head}
  - {reviewer: astra, head: "9b2a64d040", date: 2026-11-05, verdict: nits, open: "production code verified identical to 3b35e79cb5; nits: native-JSON nested-isolation test; CHANGELOG entry declined (fixed change unreleased)"}
  - {reviewer: skeptic, head: "9b2a64d040", date: 2026-11-05, verdict: nits, open: "optional: body says override or forward the hook, but freezable_default? is nodoc; split test_freezing_eligibility_of_column_defaults; activerecord none-claim unverifiable"}
---

# Keep models with mutable defaults off the frozen defaults

#59083 [freezes a model's default attributes](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/model_schema/schema_context.rb#L119-L121) when [every one is freezable](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activemodel/lib/active_model/attribute.rb#L42-L44); new records dup the cast value. Two mutable defaults break:

* A serialized default the coder doesn't round-trip reads as changed and is saved. OpenProject's [`HealthReport`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/models/health_report.rb#L33) loads its [`jsonb DEFAULT '{}' NOT NULL`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/db/structure.sql#L3050) as `[]`, so `HealthReport.new(subject: storage).save!` raises `PG::NotNullViolation` (8.1: only after a read).
* A nested default (`'{"theme":{"mode":"light"}}'` with a JSON coder) is shared between new records.

Now types that include `Helpers::Mutable` (JSON, PostgreSQL arrays, hstore, points) freeze only NULL defaults, and serialized attributes never freeze their defaults, because a coder may load NULL as a container. `normalizes` and `encrypts` defer to the wrapped type, other custom types can override or forward `freezable_default?`, and types without the hook keep main's behaviour. Models with such defaults keep 8.1's uncast writable defaults. In the measured workloads, `Model.new` with a first read of a `'{}'` or nested JSON default uses 18–22% more Callgrind instructions than on main, Ruby 4.0.9 ([results](https://github.com/thomasklemm/lowrail/tree/816b8c9e04c2e8988fed27e049dddbe7da33767d/bench/upstream/app_suites/op8-bench)).

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/cb32d8e9ab8940671cf707304bbfea0a4258e4b4/docs/upstream/app-suites.md#openproject), part of my research project Lowrail).</sub>
