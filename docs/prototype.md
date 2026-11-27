# Lowering prototype (paused)

> **Paused since 2026-11-27** (Thomas): the Rust core in `src/` and the lowering runtime in `gem/` stay in the
> tree unchanged and are not developed ([PLAN.md](PLAN.md), [DECISIONS](DECISIONS.md#lowrail-reoriented-toward-upstream-fixes-and-advisory-types-2026-11-02)).
> This page is the README section that described them until then, moved here unchanged apart from links and heading levels.


Lowrail's original prototype, as it stood on 2026-10-22. It stays in the tree
as research, unchanged and not promoted
([decision](DECISIONS.md#lowrail-reoriented-toward-upstream-fixes-and-advisory-types-2026-11-02)).

The prototype's aim: **make an existing Rails app faster without rewriting
it, and prove that nothing changed.**

Lowrail boots your Rails application, learns what is fixed after boot (schema,
routes, config, method definitions, templates), and delivers specialized Ruby
for the parts it can prove equivalent, as MRI instruction sequences (ISeqs).
The real Rails and every gem keep running. Anything Lowrail cannot prove stays
your app's own code, and every refusal is recorded with its reason.

It is deeply inspired by [Roundhouse](https://github.com/rubys/roundhouse) by
Sam Ruby, which transpiles Rails apps into standalone programs in many
languages and types them without annotations. Lowrail makes a different bet:
keep the real framework, target only lowered Ruby, lower only what can be
guarded exactly, and measure every claim. See [Acknowledgements](../README.md#acknowledgements)
for the other projects we learned from.

> **Research prototype.** Lowrail is not published as a gem and gives no
> production speedup by default today. Use it on a copy of your app or in CI.

## Historical results (2026-10-21)

> **Historical.** These are the prototype's last measured results, on Ruby 4.0.7
> and Rails 8.1.4 at the linked commits. They have not been re-measured since.
> The upstream work measures on Ruby 4.0.9 and Rails main; see
> [Combined effect](upstream/combined-effect.md).

### Warm-request instruction counts

**Warm-request instruction results, including increases and historical records—not latency or throughput claims.**
**Ir instructions, not latency · no YJIT instruction claim yet · opt-in research, not default**.
Blog and Starter each cover one endpoint/fixture in the sealed tier. Fizzy has
a fixed six-GET block-link vector and a separate one-route branch prototype;
both are bench-only, not production admission.
Current prices pass total and GC-excluded A/A, fixed-heap, brk and actual-mode
gates. Each price applies only to its named endpoint/fixture and tier.

<!-- current-results:start -->
| Date | App / endpoint | Ruby / Rails | Mode / tier | Ir Δ vs no Lowrail [95% interval] | Measured / published |
|---|---|---|---|---|---|
| 2026-10-21 | [BlogShowGetOnly (blog), `GET /articles/1`](passes/production-aa01-reprice.md) | 4.0.7 / 8.1.4 | Interpreter; Sealed opt-in: production form/token/collection | **Total −15.02% [−15.05, −15.00]**; GC-excluded −15.02% [−15.04, −14.97] | [b059fc9](https://github.com/thomasklemm/lowrail/commit/b059fc9fbcdbc4cff6a7bc523defb01e7783385c) / [602e20c](https://github.com/thomasklemm/lowrail/commit/602e20c5b22c912bb3ef050949271a68395a1bba); [JSON](https://github.com/thomasklemm/lowrail/blob/602e20c5b22c912bb3ef050949271a68395a1bba/docs/passes/production-aa01-reprice-results.json) |
| 2026-10-21 | [React Starter Kit, `GET /dashboard` JSON](passes/yjit-regression.md#post-fix-whole-request-checks-one-finite-cohort-per-mode) | 4.0.7 / 8.1.4 | Interpreter; Sealed opt-in: config binding; not promoted | **Total −10.16% [−10.22, −10.08]**; GC-excluded −10.16% [−10.25, −10.11] | [ed7cbbe](https://github.com/thomasklemm/lowrail/commit/ed7cbbe8f8ab6e9b7be24775ac76a94cebecd95e) / [01cfc45](https://github.com/thomasklemm/lowrail/commit/01cfc45f2355b99eafd01f9ce17a6a13ef062aa7); [JSON](passes/yjit-regression.json) |
| 2026-10-21 | [Fizzy, fixed six-GET vector](block-link-specimen.md) | 4.0.7 / 8.1.4 | Interpreter; Bench-only block-link; N=10, fixed init-slot floors; not production admission; cold RED | **Total +0.40% [+0.39, +0.43]**; GC-excluded +0.40% [+0.38, +0.42] | [da5fe91](https://github.com/thomasklemm/lowrail/commit/da5fe91e2f04a27acef1f7245efa7f39a7332577) / [8385e0c](https://github.com/thomasklemm/lowrail/commit/8385e0cf5d951e378a690e55707e431eef049b69); [JSON](fizzy-link-ir-n10.json) |
| 2026-10-21 | [Fizzy (bet F), `GET /buckets`](https://github.com/thomasklemm/lowrail/blob/f2e2e35b4d6372e8d67d285f329f0c93823ba259/docs/ar-callsite.md#slot-3-result-accepted-scoped-interpreter-price-no-retry) | 4.0.7 / 8.1.4 | Interpreter; Guarded DirectSite call-site query programs; branch prototype, bench-only, one route, not on main, not admission | **Total −5.49% [−5.58, −5.42]**; GC-excluded −5.50% [−5.55, −5.45] | [87c3c19](https://github.com/thomasklemm/lowrail/commit/87c3c1974c424eabef5178f518641d013dd601b3) / [f2e2e35](https://github.com/thomasklemm/lowrail/commit/f2e2e35b4d6372e8d67d285f329f0c93823ba259); runtime [addf55e](https://github.com/thomasklemm/lowrail/commit/addf55e00b080d2627503b7f10a74bbe68e17ed1); [JSON](https://github.com/thomasklemm/lowrail/blob/f2e2e35b4d6372e8d67d285f329f0c93823ba259/docs/ar-callsite.json) |
| 2026-10-22 | [Lobsters (bet M), `GET /`](https://github.com/thomasklemm/lowrail/blob/94f3f321c8c73a3814f3828bb299f26ba31e2ab0/docs/screen-platform.md#lobsters-m-accepted-scoped-interpreter-price-2026-10-22) | 4.0.7 / 8.1.4 | Interpreter; Cache-read copy plan; branch prototype, bench-only, unchanged app ([ruby-bench 351a39b workload](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716)), not on main, not production admission | **Total −5.18% [−5.20, −5.13]**; GC-excluded −5.38% [−5.41, −5.33] | [e84cf55](https://github.com/thomasklemm/lowrail/commit/e84cf55116600d676172a5531e78b6d08d28926c) / [94f3f32](https://github.com/thomasklemm/lowrail/commit/94f3f321c8c73a3814f3828bb299f26ba31e2ab0); runtime [42d3e5a](https://github.com/thomasklemm/lowrail/commit/42d3e5ade83922afc1ed39c632cc3c8ecee0dcd0); [JSON](https://github.com/thomasklemm/lowrail/blob/94f3f321c8c73a3814f3828bb299f26ba31e2ab0/docs/screen-platform-results.json) |
| 2026-10-22 | [Lobsters (bet M), `GET /s/enr7ye`](https://github.com/thomasklemm/lowrail/blob/94f3f321c8c73a3814f3828bb299f26ba31e2ab0/docs/screen-platform.md#lobsters-m-accepted-scoped-interpreter-price-2026-10-22) | 4.0.7 / 8.1.4 | Interpreter; Cache-read copy plan; branch prototype, bench-only, unchanged app ([ruby-bench 351a39b workload](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716)), not on main, not production admission | **Total −1.64% [−1.67, −1.59]**; GC-excluded −1.65% [−1.67, −1.60] | [e84cf55](https://github.com/thomasklemm/lowrail/commit/e84cf55116600d676172a5531e78b6d08d28926c) / [94f3f32](https://github.com/thomasklemm/lowrail/commit/94f3f321c8c73a3814f3828bb299f26ba31e2ab0); runtime [42d3e5a](https://github.com/thomasklemm/lowrail/commit/42d3e5ade83922afc1ed39c632cc3c8ecee0dcd0); [JSON](https://github.com/thomasklemm/lowrail/blob/94f3f321c8c73a3814f3828bb299f26ba31e2ab0/docs/screen-platform-results.json) |
<!-- current-results:end -->

Displayed values are rounded; exact values are in the linked JSON exports.

**Lobsters scope:** both endpoints' total and GC-excluded A/A intervals are
wholly within ±0.1%. This is the unchanged
[ruby-bench `351a39b` workload](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
with a fixed clock, warm FileStore and pool reaping deferred outside the
instrumented synchronous request price; not advancing-time or asynchronous
maintenance performance.

**Blog A/A rule change, 2026-10-21:** set prospectively before counting, both
total and GC-excluded nominal 95% intervals must lie wholly within **±0.1%**;
zero containment is no longer required
([preregistration](https://github.com/thomasklemm/lowrail/blob/b059fc9fbcdbc4cff6a7bc523defb01e7783385c/docs/decisions-prototype.md#token-allocation-fix-and-one-new-rule-blog-cohort-preregistered-2026-10-21)).

Bet F's per-metric A/A gates both pass within ±0.1%. The linked branch JSON
documents a cosmetic `project_aa` field overwrite; the table uses the per-metric
records, not that field. Accepted off/off rejections remain: **login rate-limit
cache `expires_at`** and **SolidCache `created_at`**. This is not a whole-DB
certificate or admission.

**Blog history:** **−15.23%** at
[`553e7aa`](https://github.com/thomasklemm/lowrail/commit/553e7aafa88754fd32359e5e11ba0cc5bfcd6f65),
published in
[`47f8e7b`](https://github.com/thomasklemm/lowrail/commit/47f8e7bc2f6084181369d82846645a19c3a31f16),
was measured on defective source only, before the dispatch fixes. The
[`62f8a6b` cohort](passes/production-dispatch-reprice.md) remains rejected
under its old zero-containment/±0.5% A/A rule
([`673b1cc`](https://github.com/thomasklemm/lowrail/commit/673b1cc3cbbb341a6956e027e54bc2a18049bde0));
it was not rescored or pooled into the new cohort. The earlier **−15.49%**
is historical, valid only at
[`ae025b0`](https://github.com/thomasklemm/lowrail/commit/ae025b0d9f456d9f9bef55e9e131bc25178e83cb),
not the corrected source. [Protocol and historical records](bench.md#current-accepted-request-results).

**Not request prices:** production YJIT method stage 1 is rejected
([retained method and reaper-driven late-entry diagnosis](passes/production-yjit-method.md));
frozen props is an accepted isolated micro only, with integration deferred
([scope](passes/props-native.md#accepted-combined-interpreter-micro-integration-deferred)).

Fizzy's block-link N=10 warm bench price above is an **instruction INCREASE
(Lowrail slower here)** under fixed init-slot floors, not production
admission or cold-start performance; **cold still RED**.
The [first N=50 cohort remains INVALID (heap growth)](https://github.com/thomasklemm/lowrail/commit/7c6cd19dbe77605ab7066e3234001b4358519e51),
without a credited price or direction claim ([scope and evidence](block-link-specimen.md)).

### Full-request throughput (real Puma)

<!-- throughput-results:start -->
**2026-10-21 · [Blog (bet A), `GET /articles/1`](https://github.com/thomasklemm/lowrail/blob/51801edc3aab276da3538763257d7d12921aa37f/docs/native-bench.md#confirmatory-result-throughput-gate-passes-p99-is-higher) · Ruby / Rails 4.0.7 / 8.1.4 · Stock Ruby YJIT.**

**Sealed opt-in: production form/token/collection; one route, one orb, exploration harness on a branch; not whole-app, capacity or production-admission evidence.** Measured on [487bec5](https://github.com/thomasklemm/lowrail/commit/487bec5065e7d9bec5d1b2df48831eb926e457cb); does **not** include [b059fc9](https://github.com/thomasklemm/lowrail/commit/b059fc9fbcdbc4cff6a7bc523defb01e7783385c).
Puma 4 workers × 1 thread, c16, 5 s warmup / 20 s load, 20 rotated off-A/on/off-B rounds.
Protocol [44a33c4](https://github.com/thomasklemm/lowrail/commit/44a33c4967d27db5c91e8954c7736fd97d3e9da9); published [51801ed](https://github.com/thomasklemm/lowrail/commit/51801edc3aab276da3538763257d7d12921aa37f); [exact JSON](https://github.com/thomasklemm/lowrail/blob/51801edc3aab276da3538763257d7d12921aa37f/docs/native-bench.json).

**RPS A/A +0.37% [−1.24, +2.18].** The preregistered rule passes: A/A contains zero and the on/off RPS lower bound exceeds the A/A upper bound.
This does not establish ±2% resolution or a latency gate.

| Metric | Paired on/off Δ [95% interval] | off-A | on | off-B |
|---|---|---:|---:|---:|
| **RPS** | **+10.46% [+8.11, +12.81]** | 1613.8 | 1782.7 | 1611.2 |
| **p50, ms** | **−8.67% [−11.04, −6.17]** | 9.2 | 8.4 | 9.1 |
| **p90, ms** | **−12.90% [−16.62, −9.10]** | 15.8 | 14.0 | 15.8 |
| **p99, ms** | **+12.73% [+1.13, +24.78]** | 26.0 | 29.9 | 26.0 |
| **GC collections / 1,000 requests** | — | 18.7 | 24.0 | 18.9 |
| **Allocations / request** | — | 2679 | 2333 | 2679 |

**Not uniformly faster: p99 increases despite lower p50/p90 and higher RPS. GC collections increase despite fewer allocations; the cause is not established.**
Arm values are medians of windows; paired deltas are means of within-round ratios, not ratios of those medians. GC/allocations are load-bracketing four-process diagnostics including metrics/background work, not exclusive request counters.

**2026-10-22 · [Fizzy (bet Y), `GET /buckets`](https://github.com/thomasklemm/lowrail/blob/dbe678a268828fda9ba1b324efc0648e2cbe3b4b/docs/jit-guards.md#single-puma-cohort-accepted-scoped-throughput-result) · Ruby / Rails 4.0.7 / 8.1.4 · Stock Ruby YJIT.**

**Guarded DirectSite with JIT-friendly guards; branch prototype, bench-only, one route, not on main, not production admission.** Measured on [796fa58](https://github.com/thomasklemm/lowrail/commit/796fa5893b4e117168340c229908f89b86fdaf41); harness [6510cd2](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8); published [dbe678a](https://github.com/thomasklemm/lowrail/commit/dbe678a268828fda9ba1b324efc0648e2cbe3b4b); [exact JSON](https://github.com/thomasklemm/lowrail/blob/dbe678a268828fda9ba1b324efc0648e2cbe3b4b/docs/jit-guards.json).

| RPS Δ vs no Lowrail [95% interval] | RPS A/A [95% interval] |
|---|---|
| **+7.83% [+6.13, +9.84]** | −0.44% [−1.63, +0.80] |

The preregistered throughput rule passes: A/A contains zero and the on/off RPS lower bound exceeds the A/A upper bound.
Median-window p99: **265.5 → 246.5 ms** (off-A → on), a window statistic only, **not a tail-latency claim** or a pooled histogram.
This compares the new DirectSite prototype with Lowrail off, not old versus new guards; no whole-app, capacity or admission claim.
<!-- throughput-results:end -->

To update: publish the accepted export first, edit only the metadata/source
paths in [docs/results.json](results.json), then run
`python3 docs/render-results.py` (`--check` detects drift). Numbers are read
from the original exports, never copied into the index. Pinned exports use
an explicit `source_commit` matching the full publication SHA; fetch bet F's
branch with `git fetch origin thomasklemm/ar-callsite-compile` and bet A's with
`git fetch origin thomasklemm/native-yjit-bench` before rendering.
The new Lobsters and Fizzy guard records additionally require
`git fetch origin thomasklemm/screen-platform thomasklemm/jit-guards`.
They are read from that commit, never substituted from the main worktree.
Refresh the short
[status](#lowering-prototype-at-a-glance-2026-10-21-parked) and [benchmark summary](bench.md#current-accepted-request-results)
when scope or acceptance changes; retain superseded records as historical.

### Supported and unsupported today

- **Default:** lowers nothing; original Rails remains in control. The
  [corpus compatibility report](compat.md) distinguishes identical
  outcomes/SQL, baseline errors, bounded subsets, safe refusals and actual hits.
- **Opt-in:** sealed production units require the [separate contract](sealed.md)
  and exact passive admission. The two sealed production rows do not imply arbitrary
  endpoint coverage or config promotion. A separate
  [verification-only test certificate](test-certificate.md) exercises
  naturally ready Article/Comment and passive token/collection units,
  including true eager-load coverage; it is not production admission.
  Link/form remain refused.
- **Refused or quarantined:** the old source link/route passes remain
  quarantined, including old mixed artifacts; cached-fact passes are
  sealed-only or quarantined, not ordinary guarded opt-ins. Preload and sealed
  link builders now refuse **before emission**, even with `--sealed`;
  template delivery remains quarantined. Old artifacts containing preload
  plans, sealed link delivery or lowered templates still refuse as a whole:
  their on-only framework ancestry is app-observable, even when sealed
  ([boundary](decisions-prototype.md#ancestry-changing-delivery-refuses-whole-artifacts-2026-10-22)).
  The priced three-unit form/token/collection artifact is unaffected.
  Unsupported shapes, stale or mode-mismatched artifacts, and the Bundlebun
  boundary stay original
  ([pass ledger](decisions-prototype.md#passes), [loaders](loaders.md)).

### Also on main (2026-10-22)

- **Sealed mutation tripwire** ([ce47c62](https://github.com/thomasklemm/lowrail/commit/ce47c620cfe85dbc939189e351e051db09e8c484)):
  certified method/ancestor changes retire admitted units. This is a backstop,
  not enforcement of the whole [sealed contract](sealed.md#production-mutation-tripwire-not-enforcement).
- **Advisory types contracts** ([07829bf](https://github.com/thomasklemm/lowrail/commit/07829bfa6dc170ae8100cc7b04a2e0ea98f985fa)):
  +442 static slots and +843 observed argument slots across the fixed six-app
  ledger; sampled types are not proofs or runtime specialization
  ([evidence and limits](types-contracts.md)).
- **Plain sealed blog build** ([6fb2f14](https://github.com/thomasklemm/lowrail/commit/6fb2f149cd9ad81522694799eb188139e9e75459)):
  `lowrail build APP --sealed --env production --jit interpreter` now delivers
  **≈377 fewer objects/request on blog show/show2; index is neutral**, with
  no denylist or manual isolated-artifact selection. The unsafe preload/link
  builders ledger-refuse before emission; old combined artifacts still refuse
  as a whole. Allocation evidence only, not a new Ir, timing or throughput
  claim; form stays narrow and preload/link/template delivery stays quarantined
  ([current scope and history](decisions-prototype.md#plain-sealed-blog-build-and-historical-isolation-gap-2026-10-22)).

**Breadth is not savings:** Fizzy, Campfire, Writebook and CASA retain exact
own-suite off/on outcomes but **no certified optimized suite hits**. Fizzy's
suite has a compiler-certificate refusal (production queries separately fail
query certification); Campfire/Writebook have Bootsnap `KeyError`, and CASA
has unsupported RSpec certificate discovery at an older retained pin. Parity
includes Fizzy's baseline errors and CASA's skips. **No savings claim for
these plain sealed builds outside the blog**
([pins and limits](decisions-prototype.md#own-suite-breadth-is-not-optimized-coverage)).

## How it works

```text
┌──────────────────────┐
│   Your Rails app     │  source + boot
└──────────┬───────────┘
           ▼
┌──────────────────────┐   boot facts: schema · routes · config ·
│   lowrail facts      │──▶ method table · templates · loaders
└──────────┬───────────┘
           ▼
┌──────────────────────┐   .lowrail/ manifest + lowered ISeqs,
│   lowrail build      │──▶ each carrying the guards it assumes
└──────────┬───────────┘
           ▼
┌──────────────────────┐   at boot: certify guards
│ RUBYOPT=             │──▶   ├─ exact  ─▶ install lowered code
│  -rlowrail/setup     │      └─ failed ─▶ keep original Rails
└──────────┬───────────┘                   method (refusal visible)
           ▼
┌──────────────────────┐   your own suite, Lowrail off vs on:
│   lowrail verify     │──▶ identical per-test outcomes + ordered SQL
└──────────────────────┘
```

The Rust CLI parses with [Prism](https://github.com/ruby/prism) and indexes
with [Rubydex](https://github.com/Shopify/rubydex). The Ruby gem in `gem/` is
the runtime that boots the app, certifies facts and installs lowered code.

## Quick start

Requirements: a Rust toolchain, Ruby 4.0.7 (the prototype's pin,
`mise exec ruby@4.0.7`), and a
Rails 8.1 app whose test suite passes.

```sh
git clone https://github.com/thomasklemm/lowrail && cd lowrail
cargo build --release                       # CLI at target/release/lowrail
(cd gem && mise exec -- rake compile)       # optional native predicate

lowrail doctor path/to/app                  # boot, JIT mode, tracing checks
lowrail facts  path/to/app                  # what Lowrail learns at boot
lowrail build  path/to/app                  # writes path/to/app/.lowrail/
lowrail verify path/to/app                  # your suite off vs on
lowrail explain path/to/app                 # what was lowered, refused and why
lowrail types --rbs path/to/app             # RBS with per-slot evidence
```

Run your app with the runtime loaded, without Gemfile changes:

```sh
RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails test
```

`LOWRAIL=0` disables it, `LOWRAIL_DEBUG=1` prints refusals. A missing, stale
or incompatible build is a silent no-op. More options are in the
[reference](#reference) below.

## Status (2026-10-21)

- **Correctness machinery works.** `lowrail verify` compares per-test outcomes
  and ordered SQL with Lowrail off and on. The pinned Rails 8.1.4 framework
  suites are a standing gate ([rails-suite.md](rails-suite.md)). Real apps
  including Fizzy, Writebook, CASA, CodeTriage, Wikino, RubyToolbox and Fat
  Free CRM keep identical outcomes ([compat.md](compat.md)). Green
  comparisons are not a universal support claim.
- **The default build lowers nothing.** Every guarded specialization tried so
  far was either unsafe under mid-request mutation or its guard cost more than
  it saved ([decisions-prototype](decisions-prototype.md)).
- **The sealed tier has scoped interpreter results**, shown in
  [Historical results](#historical-results-2026-10-21). Passive production form,
  token and collection admission is implemented; the separate test certificate
  remains AR-only ([production](passes/sealed-production.md),
  [test coverage](test-certificate.md)).
- **No whole-request YJIT gain is established.** Retained cohorts/methods
  fail the strict compilation or A/A gates, including Lowrail-off arms
  ([bench.md](bench.md)).
- **Prism 2 is adopted** in Ruby tooling and Rust, with explicit target
  grammar and refusal for unknown versions; app bundles are not forced to
  upgrade ([implementation and evidence](prism-2.md)).
- **Types and MCP work.** `lowrail types`, `lowrail explain` and
  `lowrail mcp` serve boot facts, per-slot types (proven, static, observed or
  unknown), refusal reasons and recorded hits ([types.md](types.md)).

Every pursued, parked and rejected idea is in
[docs/decisions-prototype.md](decisions-prototype.md). Dated evidence is in
[the sections moved here from STATUS.md](#lowering-sections-moved-from-statusmd-2026-11-27).

## Direction

Two tiers, so that every app keeps running and apps that opt in can go
further:

| Tier | Who | Promise | State |
|---|---|---|---|
| **guarded** (default) | any Rails app, any gem | identical test outcomes; specializations guarded and refused when not exact | works; currently lowers nothing by default |
| **sealed** (opt-in) | apps that accept a contract: no code, subscriber, config or route mutation after boot, among others | compile endpoints ahead of time without per-call checks; `lowrail seal-check` runs the app's suite and lists every violation with `file:line` and the code change that fixes it | opt-in research: measured interpreter wins; admission must be passive ([sealed.md](sealed.md), [decision](decisions-prototype.md#architecture)) |

Apps that do not meet the sealed contract still run in the guarded tier. The
tooling explains why and what to change.

## Target matrix

| Axis | Primary | Secondary / diagnostic |
|---|---|---|
| Rails | 8.1.4 | 8.2 alpha (Campfire's pin) |
| Ruby (minimum 4.0) | 4.0.7 (the prototype's pin) | 4.1 preview ([separate compatibility matrix](ruby-4.1.md)) |
| Execution | interpreter instruction counts (Callgrind, fixed heap, A/A controls) | YJIT under a strict JIT-flat gate; ZJIT being added, diagnostic only |

How to read and reproduce measurements: [docs/bench.md](bench.md).

## Reference

All commands, from a checkout:

```sh
# 1. Toolchain: a Rust toolchain and the Ruby pinned in mise.toml
cargo build --release            # CLI at target/release/lowrail

# 2. Boot facts and a build (writes APP/.lowrail/)
lowrail facts path/to/app
lowrail build path/to/app [--env test|production]   # default selection
lowrail build path/to/app --passes default,+props,+endpoint

# 3. Prove it: your suite off vs on, per-test outcomes + ordered SQL
lowrail verify path/to/app     # prints its test seed to stderr; SEED=… to fix it

# 4. Types and tooling
lowrail explain path/to/app    # current selection, guards, refusals and recorded stats
lowrail observe path/to/app    # record observed types from a test run
lowrail types --rbs path/to/app # standalone RBS to stdout, with per-slot evidence
lowrail types path/to/app --rbs sig/lowrail
lowrail mcp path/to/app        # read-only MCP server over stdio

# 5. Measurements (see docs/bench.md before trusting a number)
lowrail bench path/to/app --pass NAME
```

The runtime loads without app or Gemfile changes:

```sh
RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails test
```

Alternatively, add `require "lowrail/setup"` in `config/boot.rb`, before or
after Bootsnap. `LOWRAIL=0` disables it. A missing, stale or incompatible build
is a silent no-op, and an artifact containing quarantined passes is refused
with `Lowrail.refusal_reason`. In development it is off unless `LOWRAIL=1`.
`LOWRAIL_DEBUG=1` prints refusals.

Sealed link's optional native holder prototype is built explicitly with
`rake compile` from `gem/`, under each chosen Ruby (headers and C compiler
required). It is loaded equally on/off, never compiled during app boot, and
never loads objspace. A missing/unloadable build keeps the original path with
a visible refusal. [Contract and bounded validation](sealed-verification.md#optional-native-holder-prototype-link-coverage-recovered).

`LOWRAIL_ROOT` names the real app root (default: the working directory).
`LOWRAIL_DIR` optionally selects a separate artifact directory containing
`manifest.json` (default: `LOWRAIL_ROOT/.lowrail`). Benchmark snapshots use
this separation; relocation/source certificates still check the real app root.

Build for the deployment's **startup JIT mode**:

```sh
lowrail build path/to/app --env production --jit yjit
RUBY_YJIT_ENABLE=1 RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails server
```

`--jit interpreter|yjit|zjit` configures certification, not the deployed app.
Without it, the build observes the app's mode (legacy `LOWRAIL_BUILD_JIT=0/1`
still works). Each artifact records `certification_jit`; a different actual
mode at admission, or missing mode metadata, refuses the whole artifact before
installers run. Rebuild old artifacts. For YJIT, start the process with
`RUBY_YJIT_ENABLE=1` or `--yjit`, not only Rails' late `config.yjit` switch.
Late changes at `initialize!` completion are reported as mode drift in
`LOWRAIL_DEBUG`, stats, verify and bench; guards remain fail-closed, with no
uninstall or mode forcing. Doctor compares startup/after-boot modes separately.

`--passes` must start with `default` or `all-opt-in`, then applies
`+name`/`-name` in order. Names are the stable
`area/name` identifiers in [docs/ARCHITECTURE.md](ARCHITECTURE.md).
Short aliases are `memo`, `preload_plans`, `ar_instantiate`, `ar_plans`,
`digest_memo`, `inertia_config`, `props` and `endpoint`, but only `props` and
`endpoint` remain eligible for guarded selection. The others refuse even in
`all-opt-in`; old mixed artifacts refuse as a whole. Sealed research builds
use `--sealed --env production` and require explicit production acceptance
of the [sealed contract](sealed.md). Production artifacts refuse in test;
the separate opt-in [verification-only AR certificate](test-certificate.md)
does not bypass that boundary.
File formats are documented in [docs/FORMATS.md](FORMATS.md).

`LOWRAIL_VERIFY_LOADS=1 lowrail verify APP` also compares non-autoloading
constant censuses, Zeitwerk-loaded paths and executed Active Support load
hooks at the first test and after the suite, including load/hook order.
Reproducible differences fail verification and automatically probe each pass;
off/off and on/on variation is reported separately as advisory noise.
This observer is opt-in because its snapshots and boot hooks have a cost;
the corpus compatibility checks enable it. Snapshot time is in the report.

## Complementary optimizations

Lowrail only applies changes it can guard exactly. These stay the app's own
decision, and Lowrail works next to them:

- **YJIT** (`RUBY_YJIT_ENABLE=1`): recommended in production. Lowrail measures
  under it too, but its primary gate is interpreter instruction counts,
  because whole-request YJIT windows do not yet pass our compiler-state gate.
- **Bootsnap**: works in any load order. Bootsnap caches the original
  bytecode, and Lowrail serves its lowered bytecode.
- **Frozen string literals** (`# frozen_string_literal: true` or
  [Freezolite](https://github.com/ruby-next/freezolite)): fewer allocations,
  but mutating a literal then raises. Enable it only after your suite passes
  with it. Lowrail compiles each file with the same options the app's loaders
  use ([loaders.md](loaders.md)).

## Lowering sections moved from STATUS.md (2026-11-27)

The lowering prototype is paused ([DECISIONS](DECISIONS.md#lowrail-reoriented-toward-upstream-fixes-and-advisory-types-2026-11-02)).
STATUS.md now holds only the current picture; its lowering sections, moved here unchanged apart from one heading level,
are below, with the 2026-10-20 "Next" list and its older follow-ups at the end.

### Lowering prototype at a glance (2026-10-21, parked)

| Area | State |
|---|---|
| Bet S current plain sealed/YJIT (2026-10-23) | **Runtime lowering parked: interpreter-only gains do not count, YJIT is the reference. NO-GO:** blog show +10.724% wall/request, exploratory four-block t95 [+7.158,+14.289]%; Fizzy buckets +7.207% [−7.527,+21.941]%. 20/47-unit fresh builds; cold gates also fail, no exemptions. Ten warmups do not reach JIT-flat windows; compilation is charged. Running interpreter work stopped; no Fizzy counter or Puma, no pass/default/quarantine change or support promotion. [Preregistered decision and diagnosis](passes/sealed-yjit-gate.md) |
| Token allocation / current blog price | Token-only +32/request traced and removed; now approximately allocation-neutral, not a standalone win. The one prospective `b059fc9` cohort is **accepted: −15.022961% total interpreter Ir [−15.051352,−14.996655]**, no-GC −15.021453%. Both A/A intervals wholly within preregistered ±0.1%; all other gates pass, no measurement retry/exclusions, slot 1 released. One three-unit endpoint/fixture only. [Trace](passes/token-allocation.md), [price and export](passes/production-aa01-reprice.md) |
| Production dispatch safety | Sealed token's preexisting private-helper / reflective-send P1 fixed with captured stock `BasicObject#instance_exec` fcalls; same primitive covers form helpers (except the named route's original public dispatch) and the separate link fix, collection unchanged. **−15.225536% remains defective-source only**. The [62f8a6b attempt](passes/production-dispatch-reprice.md) stays **rejected no-GC A/A**, not rescored by the later accepted cohort; YJIT seam paused, `835cf16` parked. [Sweep and gates](passes/sealed-production.md#helper-dispatch-safety) |
| Default build | lowers nothing: `view/link_to` and `route/path` quarantined (45fd07a); five-app manifests have 0 units |
| Ancestry delivery (2026-10-22) | Artifacts containing preload plans, sealed link delivery or templates **refuse whole** before installation: their on-only ancestry/method-owner/loaded-holder changes are app-observable. Full cold comparison is not weakened. The isolated priced form/token/collection artifact retains exact two-seed off/off/on ancestry across 1,843/1,857 framework holders and nonzero hits; **−15.02% remains representative, no reprice**. Mixed all-sealed is exact but unexercised, not optimized coverage. Test discovery explicitly ledgers link refusal. [Decision](decisions-prototype.md#ancestry-changing-delivery-refuses-whole-artifacts-2026-10-22) |
| Correctness gates | original five-app outcomes/SQL and Rails 8.1.4 AP/AV/AR outcomes identical; hook-free delivery preserves loader selection; Redprints' strict load census passes with targeted Bundlebun refusal, **0 hits** ([compatibility report](compat.md)) |
| Opt-in passes | guarded selection: only props + endpoint; seven cached-fact passes sealed-only after suppressed-hook audit; see [DECISIONS](decisions-prototype.md#passes) |
| Accepted request work | post-fix Starter `GET /dashboard` JSON config binding and [current-source blog form/token/collection](passes/production-aa01-reprice.md), each one endpoint/fixture, interpreter Ir not latency, sealed-only and not promoted. README/results refresh belongs to the docs owner. Blog's old defective-source price stays historical and its first corrected-source cohort stays rejected. No YJIT instruction claim |
| Real-Puma throughput | [Separate scoped result and tradeoffs](prototype.md#full-request-throughput-real-puma): blog sealed opt-in, stock Ruby YJIT; preregistered RPS rule passes, **p99 and GC collections increase, cause not established**. One route, one orb, branch harness on older measured main; not whole-app, capacity or admission evidence |
| Not production request prices | production YJIT method stage 1 rejected; [reaper-driven late compilation](passes/production-yjit-method.md) explains the native rejection, not a price. [Frozen props](passes/props-native.md#accepted-combined-interpreter-micro-integration-deferred) is an isolated micro, integration deferred. Fizzy N=50 **INVALID** (heap); N=10 accepted only as a scoped warm bench price, an instruction increase, not production admission ([specimen](block-link-specimen.md#replacement-result-scoped-warm-bench-price-not-a-win)) |
| Verification-only test tier | AR Article/Comment and passive token/collection own-suite coverage, not production admission; link/form/preload remain refused. Default and explicit-path invocations both retain 21 ordinary + 2 browser identities under CI unset/1, off/on-cold/on-warm; link is explicitly refused in the discovery ledger. [Current refusal and verification](development/testing.md#sealed-ancestry-runtime-refusal-2026-10-22); historical [explicit-path eager-load coverage](test-certificate.md#documented-explicit-path-invocation-actual-eager-loading) and its timeout diagnosis remain recorded |
| Campfire r81 | **KILLED after screen + one branch-only allocation variant; slot 2 released, no Ir.** Original adds ~52 objects/request; variant removes those but has no clear wall win (−4.168%, A/A 4.293%). Both screens reject body/headers even off/off. 52 warm hits + 2 STI fallbacks; cold 103 hits outside windows. Named browser/entropy/Redis-expiry rejections, blog feature exemption and 10 cached-bind gaps remain ([evidence](campfire-bench.md#13-screen-one-allocation-only-variant-then-kill)) |
| Historical upper bounds | endpoint render path, −26 %/−37 % handwritten specimens, not supported passes or current prices; caller-side certification loses (0fbb909) |
| Types/MCP | source-backed Sorbet + Rails signatures; blog slots 2/99/7/188, Wikino 0/1,715/1/1,129 (proven/static/observed/unknown); 517 original wrapped returns → static, forwarding placeholders removed; blog Steep 51 → 6 → 2, still non-gating ([details](types.md#sorbet-and-framework-signatures-follow-up--2026-10-21)) |
| Prism 2 | Ruby dev + Rust 2.0.0; explicit target grammar, unknown versions refuse. Census/delivered bytes and Rust facts/types/MCP match; both Ruby axes tested, named production-fixture skips preserved. No Prism.find witness adoption or speed claim ([evidence](prism-2.md)) |
| Rails 8.2 alpha | [Pinned corpus, source drift and fixed-count follow-up](rails-8.2.md); Campfire load/SQL variation reproduced off/off; Writebook lock corrected, baseline failures/Fizzy residuals retained; support blocked, sealed re-certification waits for beta/RC |
| Limits / next work | default/quarantine unchanged; broader sealed admission and active own-suite coverage remain incomplete; frozen-props integration deferred; Ruby 4.1/ZJIT remains a separate matrix |

### Blog prospective new-rule re-price: accepted (2026-10-21)

On clean detached `b059fc9`, **−15.022961% total Ir
[−15.051352,−14.996655]**, no-GC **−15.021453%
[−15.044109,−14.967704]**. Both A/A intervals lie wholly within the
prospectively published ±0.1%: total [−0.068389,+0.004169]%, no-GC
[−0.077337,+0.033586]%. All heap/exact-page/brk/mode and fresh pre/post cold,
192+192, native/deopt gates pass. Exactly 18 serial workers / six rounds;
72 dump totals/self sums, 36 subtractions, 18 certificates and 681 pins
independently reconcile. Launcher refusals outside counter work are retained;
no measurement retry/exclusions, service stopped and slot 1 released.

Token-only's traced +32 allocations/request is removed, leaving it neutral,
not a standalone win. The stack allocates 2281.25 → 1903.90/request
(diagnostic). This is a three-unit endpoint/fixture interpreter price, not
latency, YJIT, test-tier support or whole-app promotion. The prior rejection
below is unchanged, never rescored. [Protocol and complete accepted export](passes/production-aa01-reprice.md).

### Blog first dispatch-corrected re-price: rejected (2026-10-21)

The screen is exact and saves **343 objects/request** (2412/2412/2069
off-A/off-B/on), versus the earlier S reference saving 393. The single
authorized historical-method interpreter cohort at clean detached `62f8a6b`
then fails **GC-excluded A/A [+0.009283,+0.062511]%**, which excludes zero.
Total A/A, heaps/exact pages/brk/mode pass. **No accepted replacement price**:
raw total **−14.536782% [−14.552516,−14.507619]** and no-GC **−14.537277%**
are diagnostics only. All 72 dumps/self-cost sums, 36 subtractions, 18 source
certificates and 681 pins reconcile. Pre/post seeded cold, 192+192 observable
pairs and native/deopt gates pass; raw entropy still rejects. No retry,
exclusions, new cohort or YJIT; slot 1 released. The prior −15.225536% remains
defective-source only. [Protocol and complete data](passes/production-dispatch-reprice.md).

### Campfire r81: companions accepted, native bet killed (2026-10-21)

The shared three-round room screen adds about 52 allocations/request and
shows no resolved wall win. `ARShadow.enabled?` allocates one Array per hit
even with shadowing off. One branch-only allocation-free predicate brings
off-A/off-B/on medians to 15525.5/15525/15524.5, effectively a tie; wall
−4.168% does not clear 3× the 4.293% A/A floor. Both screens also reject body/
all-header identity off/off with valid entropy source pins: an unclassified
warm validation boundary, not a permitted cold exception. **Kill the Ir
cohort, release slot 2; no prototype code reaches main.** Bet A independently
finds allocation increases on all five routes, no resolved wall-time gain.
[Full screen results and private-receipt hashes](campfire-bench.md#13-screen-one-allocation-only-variant-then-kill).

One authorized rerun, exit 0: both seeds match HTTP status/header/body bytes,
SQLite schema/all rows, loads, ordered non-Lowrail features, observed events
and completed/post-exit state off/off/on. The 52-hit warm instantiation target
is unchanged; 103 cold login+room hits are outside the proposed windows.
**Named qualifications:** browser other-thread test nondeterminism; raw CSRF/
cookie/ETag/runtime/session-clock rejections; accepted off/off Redis absolute
expiry (`rate-limit:sessions` only, all 42 names/values and 41 other expiries
exact); exact blog Lowrail feature rule with path/content hashes; ten cached
lazy-Proc bind values unavailable/worker (153 SQL records retained, never
evaluated/recast). This is not active sealed own-suite or cold raw support.

All 16 exact-worker tool=none windows preserve frozen pages and the closed
52-hit/two-STI map. Slot 2 was assigned, but its launcher stops before any
counted Callgrind worker/window (initial log overwritten, cause unconfirmed).
The new screen-first policy led to the two rejected screens above, not pricing.
No speed claim, further attempt, app patch, runtime/default/quarantine change, or Oct-8-app
equivalence. [Full retained evidence and hashes](campfire-bench.md#12-one-authorized-companion-rerun-accepted-with-named-items).

### Fizzy block-link heap protocol (2026-10-21)

**Decision rule first:** any pin/mode/brk/exact-page/mix violation invalidates
the whole cohort; both total/no-GC A/A 95% intervals must contain zero wholly
within ±0.5%. The completed N=0/50 interpreter cohort is **INVALID**:
both off/on grow beyond the declared heap pages. **Diagnostics only, not a
price or direction claim:** total Δ +0.415777% [+0.364704, +0.733074],
no-GC Δ +0.413692% [+0.364724, +0.448149]. A/A, pins, mode, brk and exact
1200-hit mix pass, but heap failure invalidates the whole cohort. All 18
workers / 72 dumps / 36 subtractions reconcile; no retry/exclusions. Its
service/slot is released. [Complete INVALID export](fizzy-link-ir-invalid.json).

**N=0/10 accepted scoped warm bench price, not a win:** total Ir
**+0.403071% [+0.386235, +0.429585]**, GC-excluded Ir **+0.402000%
[+0.380081, +0.421142]** on these six Fizzy GETs with the stated floors only.
Cold off/off/on stays **RED**. Accepted named off/off rejections: nine
SolidCache `created_at` values and historical order-sensitive estimation SQL
interleaving. **Uncovered:** payload/assigns, lazy cached-bind values and
SolidCache completion. No production admission or cold-start claim.

Untimed **Valgrind tool=none** off-only whole-window budgeting at N=0/10
freezes the common init slots at `3350000,300000,460000,30000,20000` (254 MB of
slots), rather than mistaking init floors for hard caps. Fresh off/on workers
in both phase orders retain exact pages with zero page additions in all 16
windows. Full on windows have exactly **240 hits/19 identities**, preserving
the four explicit zeros. The one authorized replacement completes all 18
workers after the old slot release, six rounds / seed 41231 / off_a/off_b/on /
jobs=1. All 72 measured windows retain exact pages and zero additions; every
full on window has the exact 240-hit mix. A/A intervals contain zero within
±0.5%: total [−0.046920, +0.026381], no-GC [−0.042940, +0.026493].
Both 72 dumps and 36 subtractions independently reconcile. Same detached
harness and brk512 tool; no app/config/GC-policy change, higher-segment tool,
retry, exclusions, YJIT or pooling with N=50. Slot released.
[Complete scoped N=10 export](fizzy-link-ir-n10.json).
[Protocol and reproduction](block-link-specimen.md#untimed-heap-preconditioning-prefer-n10-on-the-existing-tool),
[all untimed evidence, including failed alternatives](fizzy-link-heap.json).

### Works (2026-10-20)

- **Production tracing fixed; promotion unchanged (2026-10-21):**
  [ed7cbbe](https://github.com/thomasklemm/lowrail/commit/ed7cbbe8f8ab6e9b7be24775ac76a94cebecd95e)
  removes global return observers from activation and cold delivery, using
  targeted initialization and a Loader witness. Native warmed Starter
  requests have **zero `exit_trace_leave`**. One finite six-round check per
  mode: interpreter **−10.156% [−10.219, −10.084]** accepted, 11 hits/request
  and no fallbacks in separate coverage; YJIT **rejected** both A/A and
  measured-window JIT flatness (10/24 workers). Raw −0.153% is not a speed
  claim. Untimed YJIT has 0 hits / 9,911 fallbacks because a JIT-disabled
  artifact certified a different `Array#each` implementation. That correct
  fact refusal must not be weakened. Config remains sealed-only, not
  promoted. Old cohorts, the CASA pre-flags SQL RED and the Redprints load
  boundary remain recorded separately. [Evidence and emit proposal](passes/yjit-regression.md).
- **JIT admission and drift (2026-10-21):** `build --jit MODE` certifies in
  the explicit mode; the manifest's actual `certification_jit` must match
  before installers. Missing/different metadata refuses the whole artifact.
  Actual mode changes by initialize! completion are debug/stats/verify/bench
  diagnostics, not uninstalls or forced app config. Doctor separately compares
  Lowrail-off startup/after-boot modes. Regressions cover both early mismatch
  directions and Rails late enablement; deploy YJIT at startup and rebuild
  `--jit yjit`. No new measurements or pass promotion.

Ruby 4.0+ (gemspec), developed on 4.0.7; the second target is Ruby 4.1
([separate compatibility matrix](ruby-4.1.md)). Ruby 3.4 was dropped by owner
decision on 2026-10-20. Historical, not current support evidence: real-blog
on Ruby 3.4.11 built the same 11 units and verified 21/21 identical with
114 hits.

**Quarantine supersedes the cached-fact results below.** Memo, file-digest
memo, all three AR passes and config binding are now sealed-only; their old
guarded commands refuse, and their previous hit maps are historical, not
current support. Defaults remain empty. Production sealed research requires
the separate contract; test processes refuse sealed artifacts. See the
[suppressed-hook audit and current maps](passes/suppressed-hooks.md).

- **Gem-breadth corpus:** four reproducible dependency-only Rails 8.1.4 /
  Ruby 4.0.7 overlays add CASA, Writebook, Fizzy and CodeTriage. CASA's I18n
  date formatting and Fizzy's Active Storage callback exposed genuine early
  loads; initialization, already-loaded-constant and lazy model/epoch gates
  fix them with regressions. Opt-in verify load censuses found further
  preload loads. Hook-free delivery fixes require-hooks/Bootsnap adapter
  selection; Bundlebun's unsorted integration enumeration requires a targeted
  delivery/activation refusal, so Redprints loses its 277 hits. Fresh
  framework artifacts recover all instantiate hits; an
  intermediate 118-hit loss was correct refusal of an old runtime source
  hash, not a missing `initialize!` path. Baseline failures, browser coverage,
  SQL controls, per-app hits/fallbacks, pins and boot/build timings:
  [compat.md](compat.md).

- **Post-registry cleanup:** all build selection now uses `--passes`; the five
  transitional per-pass flags are removed. Superseded cached-reader, preload
  and memo runners are removed, as are instantiate's request/micro branches.
  Its internal-cost/StackProf breakdown and the Lowrail-off AR implementation
  comparison remain diagnostic, with their operation workers unchanged.
  Application activation already has one owner; component-suite/test calls
  and AR dependency-invalidation hooks are not redundant activation paths.
  No gem runtime source changes are included in this cleanup.

  Fresh pre-K default/all-opt-in builds across all five corpus apps, including
  explicit browser gates, retain **1,626 identical gate outcomes / 34,042
  identical ordered own-thread SQL events** in 20 before/after cases (suite
  overlap is counted). Entire manifests and ledger identities/multiplicities
  match; non-system per-unit hit/fallback maps match exactly. Eighteen total
  maps are exact. The two Campfire browser controls are A/A on byte-identical
  runtime code and manifests, not counter-equality claims:

  | Browser build | Hits before → after | Fallbacks before → after |
  |---|---:|---:|
  | default | 4,169 → 4,193 | 0 → 0 |
  | all-opt-in | 9,904 → 9,840 | 847 → 843 |

  Default variance is at units 32/44/58 (+12/+4/+8); the all-opt-in map also
  varies in dependent AR work. All original maps and other-thread SQL
  advisories are [retained](cleanup-equivalence.json), alongside the earlier
  [request-count attribution](runtime-pass-equivalence.json). Rust **34 tests**,
  gem **90 tests / 1,575 assertions** (5 optional skips), bench **20 tests / 155
  assertions** pass. Retained breakdown worker arguments, environment and
  summary match the old diagnostic. No new speed/cold-cost claim; precompiling
  `passes.rb` remains a separate follow-up.

  After pulling main (including K), combined checks pass: Rust **34 tests**,
  gem **91 tests / 1,586 assertions** (5 optional skips), bench **21 tests /
  165 assertions**. A rebuilt default blog retains 21 identical outcomes and
  125 identical ordered queries at both seeds: **57/0** hits/fallbacks at
  41231, **55/1** at 14. The full cleanup matrix above remains explicitly
  pre-K, not relabeled as a post-integration corpus run.
- **Blog counter-order investigation:** archived runtimes `491ea27` and
  `f17790c` match exactly in 20 serial verifies each at `SEED=41231`
  (57 hits, zero fallbacks), and seed-by-seed for seeds 0–19:

  | Hits / fallbacks | Runs per runtime | Seeds |
  |---|---:|---|
  | 57 / 0 | 8 | 2, 11, 13, 15–19 |
  | 56 / 1 | 8 | 0, 4, 6–10, 12 |
  | 55 / 1 | 4 | 1, 3, 5, 14 |

  All 80 verifies retain 21 identical outcomes and 125 identical ordered
  same-thread queries; the complete per-unit maps match between runtimes.
  At seed 14, `CommentTest#test_belongs_to_article_association` creates a
  comment; its `after_create_commit` broadcasts the article before a controller
  request. At seed 0 the destroy-comment callback runs inside
  `ArticleTest#test_destroys_comments_when_article_is_destroyed` instead.
  Unit 0 correctly rejects `@self#article_path`: that method is **absent** on
  the anonymous view class. Tracing the original `link_to` shows it absent on
  entry and present on return at Rails' `route_set.rb:334`: lazy route loading,
  not an object-id cache collision or a registry regression. The fallback can
  also skip a nested unit 1 route hit. No guard is weakened or changed.
  [Retained per-seed maps and digests](guard-order-equivalence.json).

  Plain `lowrail verify` chooses a fresh seed on each invocation, prints
  `lowrail verify: test seed N for every run` to **stderr**, and shares it
  across off/on/bisect runs. Existing `SEED`, `TESTOPTS` or `SPEC_OPTS` takes
  precedence; it does not announce a generated seed in that case. Reproduce
  the 55/1 case with `SEED=14 PARALLEL_WORKERS=1 MT_CPU=1 lowrail verify
  .corpus/real-blog-r4`. The default seed policy is unchanged.
- **Compiled ERB investigation, no new pass** ([survey/profile/refusals](passes/erb.md)):
  literal-run fusion rejected (blog 1 / Campfire 0 / PingCRM 0 / Redprints 0 /
  starter 1 eligible templates). Off-only profiles assign 9.09% of blog edit
  to I18n and 5.72% of uncached Campfire room to URL generation, not savings.
  Blog has 11 key lookups/request (10 misses, 1 hit), all label/submit defaults;
  five result-changing mutation probes bypass the proposed I18n setter epoch.
  Campfire has 7 route guard hits but **zero completed specializations** per
  request: live controller defaults disable Rails' optimized route branch.
  The layout ledger gap is fixed diagnostically: rejected handlers are parsed
  in a method, then refused as `template_context` or `template_parse` rather
  than omitted. Campfire gains 14 refusal rows; its entire 60-unit manifest
  stays identical. Rust: 31 unit + 3 integration tests pass. No runtime fix
  or new pass was made. Three Action View before-gate groups retain 2,747 + 242 +
  173 identical outcomes in every layer. Tag/form attribute work belongs to
  candidate #4. No per-hit or request win claimed.
- **Template lookup surveyed and parked** ([survey](passes/template-lookup.md)):
  all five production HTML workloads already reuse filesystem/bound-template
  caches, with zero warm scans/builds. Rails 8.1.4 and the Campfire alpha both
  return new Templates after `clear_cache`/`DetailsKey.clear` while path and
  context-details identities remain unchanged. A complete filesystem-resolver
  epoch is needed for at most 0.42% opportunity before guards. No new pass.
- **Shared pass benchmark** (`lowrail bench APP --pass NAME [--path /path]`):
  fixed-heap Callgrind primary, independent mandatory A/A controls, actual-JIT
  attestation, general stale-build and activation rejection. Separate counted
  probes keep stats outside measurement windows; AR/preload method micros
  reuse their existing operations with shared off/off/on controls and
  guard-included per-hit budgets. Versioned `result.json` and `table.md` are
  the pass-thread handoff. Request-only or partially modeled measurements do
  not claim promotion. `--measure-budgets` now replays real emitted guarded
  route/link/memo/digest operations and real-controller Inertia bindings with
  independent off/off/on workers, per-operation A/A and the shared heap gates.
  Invocation budgets explicitly price guarded fallbacks without inventing hits.
  Complete instruction budgets explain blog default, Campfire default and
  Starter's opt-in binding effect. The current-K blog predicts/measures
  545k/549k saved instructions/request; uncached Campfire instead pays about
  195k for seven route attempts with zero completions. That default-route cost
  needs a separate exact fix. The current-K memo stack is rejected on two
  individual route A/A controls, not counted as a completed measurement.
  Fresh blog plus cached/uncached Campfire default and +instantiate instruction
  runs reproduce the base-cost result with both A/A and heap controls passing;
  the native guarded micro's failed A/A remains rejected. Exact numbers and
  run-to-run CI caveats are [recorded with the CLI validation](bench.md#cli-validation-against-the-base-cost-experiment).
  Stacked `--passes SET --default-build DIR` retains a separate default
  reference beside no-setup and the measured stack, with the same controls.
  Multi-unit/model `--budgets` input carries guarded operation replicates;
  the additivity residual resamples joint budget vectors and independent
  request boots, rather than adding CI endpoints. Missing budgets remain
  explicitly unmodeled; this does not manufacture instruction micros.
  First default+AR stacks pass all instruction A/A/heap gates: blog **+0.588%**
  versus default, Campfire uncached **−0.066%** (CI crosses zero); no incremental
  ≥2% win. Per-model instruction prices remain unmodeled. See
  [stacked validation](bench.md#stacked-cli-validation) and
  [genuine operation budgets](bench.md#capturing-genuine-instruction-budgets).
  See [the protocol and remaining adapters](bench.md#shared-command-lowrail-bench).
- **Boot facts** (`lowrail facts APP`): modules, methods with owner,
  source location, visibility and ISeq kind, models, controllers, routes and
  compiled template code. Prism classifies origins: real-blog has 13 source
  `def`s against 362 gem-generated methods on app classes.
- **Build-time oracle** (`gem/exe/lowrail-oracle`): a booted view context
  that evaluates helpers with marker strings; probes with special characters
  prove how each marker is escaped. Passes reuse Rails' own rules instead of
  re-implementing them.
- **View pass `link_to`** (`src/lower/view.rs`): per call site
  `((guard && type checks) ? inline : original)`, on the original line, with
  the original call verbatim as fallback.
- **Route pass `route/path`** (`src/lower/route.rs`,
  [docs/passes/route-helpers.md](passes/route-helpers.md)): named-route
  `*_path` calls in templates and in Ruby files under `app/` (the first
  Ruby-file pass, served as ISeqs); probes run the emitted code
  next to the real helper. Guards on `@self` facts are checked per class of
  `self` (`Lowrail.ok?`). Dynamic engine script completion stays in Rails;
  `_url` host normalization is memoized only on the request, keyed by its
  scalar inputs (including in-place string/encoding changes). `url_options`
  and application overrides remain live. `article_url` construction is
  3.71 → 2.21 µs, 25 → 9 allocations (YJIT; see pass notes).
  Block-backed `direct`/`resolve` helpers remain refused with block locations
  and operations: corpus blocks read current state, transform arguments or
  dispatch dynamically; a runtime probe rejects dropping their state/query.
  Arity refusals now identify default-backed parts and optional segments;
  Campfire's 17 such calls all default `user_id` to `"me"`, rather than
  simply recalling missing IDs. Generic generation's mapping, format and
  script-before-parameterization semantics remain an explicit boundary.
- **Active Record preload plans** ([design and measurements](passes/preload-plans.md)):
  guarded gem-level trees, scopes and loader groups computed once; fresh
  Rails Association loaders per call, no cached rows. Schema/reflection/scope
  changes and unsupported shapes retain the original Rails path. Already-loaded
  micro path −22.1% time/−29.3% allocations, but presentation +19.3% and
  response-cache-disabled room +10.2%: not a general application-speed win,
  so it is opt-in (`lowrail build APP --passes default,+preload_plans`) until it no longer
  slows real requests.
- **AR SQL plans** ([survey, guards and measurements](passes/ar-plans.md)),
  opt-in with `lowrail build APP --passes default,+ar_plans`: fixed scoped-association readers
  reuse Rails SQL builders/BindMaps; original relation loading, inverses,
  preloading, strict loading and query cache remain live. Five non-system
  corpus gates: **741 identical outcomes / 16,182 identical traced queries**.
  Campfire has eight eligible readers, **677 genuine hits / 367 explained
  scope/epoch fallbacks**; the other four apps have no eligible reader and
  zero AR-plan hits. Source refusals are in the ledger. Guarded logo reads
  save 21 objects but no measured time (79.14 → 90.66 µs); actual route
  coverage predicts **under 0.2%** time change everywhere. Request medians
  are noise-dominated, including 7–9% movement on zero-hit PingCRM controls.
  Keep opt-in. Attribute dispatch was a guarded negative result; general
  escaping app-chain plans remain unimplemented (SQL-only ceiling 21–22 µs).
- **Active Record instantiation** ([measurements and guards](passes/ar-instantiate.md)),
  opt-in `lowrail build APP --passes default,+ar_instantiate`: normal per-model singleton `def`s,
  lazy builder reuse, method facts and row-wise AR epoch guards; Rails still
  owns initialization, callbacks and STI. Five corpus apps: **779 outcomes
  and 17,261 ordered same-thread SQL events identical**, **3,363 pass hits**;
  Campfire's 3,129 fallbacks are 958 STI rows + 2,171 calls after a captured
  schema-test connection switch. Alpha 20/200-row load-only −38.9%/−37.0%,
  four fewer allocations/row; Rails 8.1 usually regresses. Five interleaved
  request pairs/app established **no request win**. Their blog +25.5% median
  did not control boot/heap phase; it is not an identified hot-path tax.
  See the [controlled instruction and GC diagnosis](bench.md) for the later
  default/instantiate comparison; no native YJIT request win is established.
  Keep it opt-in.
- **Inertia configuration binding** ([contract and measurements](passes/inertia-config.md)),
  opt-in `--passes default,+inertia/config_bind`: fresh controller-bound
  configurations, live shallow-copied options, shared method facts and exact
  ordered-schema/Hash-policy checks. Guarded bind micros save two objects
  and about 3 µs per hit; JSON requests save 10/18/22 objects in the three
  public apps. **Request speedup is unproven: native A/A control failed.**
  Runtime migration step 4 installs shared activation: integrated gates have
  **811 identical outcomes, 514 binding hits, zero fallbacks**, and all 12
  HTML/JSON byte comparisons pass. No temporary setup hook is needed.
- **Guarded memo** ([certificate/refusal details](passes/memo.md)), opt-in
  with `lowrail build APP --passes default,+memo`: fresh-return SHA-256 string reuse, bounded by
  runtime keys and guarded implementation facts. Campfire **634 identical**,
  **1,242 memo reuses** with its debugger disabled in both modes; default-debug
  verification also identical but correctly falls back. Four production HTML
  routes have byte-identical CSP headers in both cache modes. Rails' regexp
  timeout prevents URI memoization by default; file-backed version procs and
  whole importmap resolvers remain refused. real-blog **21 identical**, no memo
  candidate. Five interleaved pairs: cached medians −2.7…−6.1%, but cache-disabled
  medians **+3.9…+15.4% slower**, allocations +36…45/request. Not a general net
  win; keep it opt-in.
- **Exact file-digest memo** ([contract and public fixture](passes/digest-memo.md)),
  independent opt-in `lowrail build APP --passes default,+digest_memo`: reread the complete binary
  stream, reuse only after full byte equality; no stat-only shortcut or arbitrary
  Inertia-proc memo. RailsVite MD5 and vite_ruby SHA1 intrinsics retain original
  error/glob semantics. Public fixture: 7/7 identical, 65 reuses, no fallbacks.
  [Private Rails app with Inertia Rails](m0/private-inertia-app.md): historical
  unit/request and browser outcomes identical, nonzero digest reuses, zero
  fallbacks. Five YJIT pairs: page C median −14.3%
  with narrowly separated ranges; pages A/B −6.1%/−13.1% remain within
  overlapping noise. More allocations (+21/request), worse p95 tails, full file
  IO and guard limits remain. SQL-trace warnings also reproduce with every unit
  disabled; see the aggregate notes rather than assuming full SQL identity.
  Guarded digest builds are now refused; this is not current admission.
- **Runtime gem**: native translate / cache-output / ISeq eval seams, with
  no `load_iseq` definition (preserves Bootsnap and require-hooks/Freezolite
  method chains and adapter selection in every tested order), per-file compiler
  contracts captured from the booted app, unchanged-source/original-ISeq
  fingerprints, and original-only Bootsnap caches ([survey and tests](loaders.md));
  template seam (lowered handler code while the source digest matches),
  guards that reset on every definition path and revalidate lazily
  (including stubs on single objects), per-view-class checks, env check,
  stats, Minitest outcome reporter across forked workers and RSpec per-example
  outcomes via RUBYOPT (explicit `verify APP -- bundle exec rspec ...`). Setup
  loads no default gems, so apps pinning `json` still boot.
- **Layered request costs** ([method and results](bench.md)):
  `bench/request_pairs.rb` separates no setup, no manifest, zero units,
  all-disabled, default and optional instantiate builds. Primary Callgrind
  counts control all five heap-pool capacities, retain GC endpoints and
  report total/GC-excluded instructions with bootstrap CIs and independent
  off/off gates. Native YJIT CPU/wall and allocations remain secondary;
  failed controls are retained. Empty selections/manifests no longer install
  delivery/invalidation hooks. Disabled statistics leave the receiver guard
  hot path (1,295 → 663 instructions/check in a YJIT micro); class-identity
  caches and invalidation semantics are unchanged. Production-heap diagnosis
  finds allocation/GC-count changes driven by boot phase, with modest
  retained manifest/fact data, not a second application ISeq set. No runtime
  retention/GC tuning change was made. After-change interpreter total
  instructions, default vs no setup (95% bootstrap CIs): blog
  **−5.959% [−5.983, −5.949]**; Campfire uncached
  **+0.122% [+0.054, +0.151]**; cached
  **−0.045% [−0.110, +0.022], within noise**. All three after A/A gates pass;
  the before-cached gate fails and is not accepted. The all-disabled blog
  tax falls from +0.245% to below 0.1%. Optional instantiate uses −5.728%
  on blog / −0.126% uncached Campfire vs off, on the frozen pre-shadow AR
  runtime. No native YJIT speedup is established. Fresh builds after merging
  concurrent AR changes still verify identical outcomes/full SQL:
  blog 21/125 events, Campfire 634/15,108, default and instantiate, serial.
- **Rails' own compatibility gate** (`script/rails-suite`, [results and recipe](rails-suite.md)):
  pinned v8.1.4 component suites, setup-only / synthetic guarded fallback /
  existing AR-pass layers against independent off/off controls. SQLite AR
  **9240/9240**, PostgreSQL AR **10186/10186**, AP **4095/4095**, AV
  **3162/3162**, AM **1100/1100**, Mailer **268/268** in every layer;
  AS **5814/5815** and inline AJ **209/212** have four dynamic printed
  identities, not outcome failures. Railties is a bounded **125/125**.
  **Round 2** adds genuine coverage with zero shadow mismatches: preload
  **2 H / 650 F** in full SQLite, **1 / 652** in PG, **5 / 2** in AV-AR;
  one isolated, unmodified Rails association test has **1 reader H / 0 F**.
  Full AR still refuses 94 otherwise eligible readers because of genuine
  fake planners; no test-directory whitelist or guard weakening. Refusing
  144 noncanonical HABTM edges stops 546 unresolvable facts from disabling
  every ordinary preload. Full per-reason ledgers and per-unit H/F (including
  zeros) are retained. SQLite's **68,857/11,616** and AV's **118/0**
  instantiation controls remain exact. Five AR-only corpus gates retain
  **742 identical outcomes / 16,193 ordered same-thread queries**.
  Redis exercises **671 additional AS tests** (matching skips 1,068 → 397);
  full Railties generators and external AJ adapters remain unrun.
  These are bounded compatibility/coverage results, not speed claims.
- **AR visitor correctness fix**
  ([identity audit](ar-equivalence.md#connection-identity-audit-2026-10-20-round-2)):
  cached reader SQL is pinned to the certified visitor object; a connection
  visitor swap falls back without lazy re-certification. Published separately
  in [`9020e7a`](https://github.com/thomasklemm/lowrail/commit/9020e7a19ea5de9705f916e6b51add4e6c770831),
  after SQLite/PG/AV gates. Seven mutations across reader/preload/instantiate
  yield **21 identical exact row/query comparisons**; before, reader visitor
  replacement produced two strict shadow mismatches. Preload and instantiate
  are unaffected in the tested visitor/adapter/pool/role/shard/prepared cases.
- **Callbacks surveyed and parked**
  ([census and budgets](rails-suite.md#round-2-callbacks-are-parked-not-a-225-app-opportunity)):
  five apps have only **4–7 calls/request**, no nonempty symbol-condition-only
  chains. Eligible no-around machinery accounts for **0.141–0.975%** of eleven
  route captures before guards; the 22.5% Rails-suite inclusive figure wraps
  callback/action bodies and is not removable. Rails already caches compiled
  chains; upstream [PR59094](https://github.com/rails/rails/pull/59094) removes
  known-terminator thunks. No new runtime pass or ≥2% request claim. Revisit
  only as a stacking item with shared fixed-heap operation adapters/controls.
- **`lowrail verify [--bisect]`**: suite with `LOWRAIL=0` and `1`, per-test
  outcomes and fast-path hits. `--bisect` reruns with unit subsets
  (`LOWRAIL_UNITS`) and writes `.lowrail/denylist.json`, which `build`
  honors. Checked with a fault injected into one real-blog unit: found in 4
  reruns, the rebuild skips that template.
- **SQL-trace differential in `verify`** (`gem/lib/lowrail/sql_trace.rb`):
  per test, the ordered sql.active_record events of the test's thread
  (name, SQL with timestamps and 6+-digit literals masked, bind
  name:class, cached flag, row count) must match between `LOWRAIL=0` and
  `1`. Schema, fixture, connection-setup and internal-table queries are
  excluded; other threads' queries are advisory. Both runs share one seed
  (`SEED`/`SPEC_OPTS`); with several test processes the SQL check is
  advisory (run `PARALLEL_WORKERS=1` to gate). `LOWRAIL_SQL_TRACE=full`
  stores the lines, `=0` disables. When serial traces differ, verify runs
  `LOWRAIL=0` a second time and excludes tests whose traces already differ
  between the two off runs (inlined sequence ids, time, randomness). If
  differences remain, the on run is repeated too, so only differences that
  reproduce in both on runs against two agreeing off runs gate. In
  [Private Rails app with Inertia Rails](m0/private-inertia-app.md), the serial
  off-repeat-only control still left rare flaky differences with every unit
  disabled. With the symmetric check the same control passes: exit 0,
  2.7% of tests excluded as unstable (not SQL-gated), zero remaining differences,
  identical outcomes in all four runs. Campfire: 634 tests, 15,103 queries,
  identical; real-blog: 21 tests, 125 queries, identical.
- **Build surface** (PLAN 9.4): `lowrail facts` materializes lazy
  surface before dumping (production eager load, attribute methods,
  relation delegation, lazy routes, view context classes, every template
  compiled), captures every eval'd script (`TracePoint(:script_compiled)`,
  `.lowrail/generated/`) and links methods to the exact generated `def`
  (`--show Mod#meth`). `lowrail observe APP` records a test run
  (definitions after boot, scripts, sampled argument/return classes) into
  `.lowrail/observed.json` and diffs it against the facts.
- **Types and MCP** (first iteration, other thread): boot-first types with
  provenance, RBS generation, stdio MCP server. See `docs/types.md`.

### Evidence

| App | Lowered | verify | Other |
|---|---|---|---|
| real-blog (Rails 8.1.4) | 9/9 `link_to` sites, 10/10 route sites (1 in a controller), 12 units including preload plans | 21/21 identical, 116 fast-path hits across all 12 units (2 preload hits) | 4 HTML routes byte-identical on/off (CSRF masked); request time within noise, allocs −1 to −6 %; `edit_article_path` 2.7 → 1.4 µs |
| Campfire (Rails 8.2 alpha) | 1/4 `link_to`, 108/162 route sites (51 `_url`) | 634/634 identical (2 skips both ways), 13238 hits across 52 units, 0 fallbacks; with `+preload_plans` 786 preload hits | M0 in `docs/m0/campfire.md`; preload results in [pass notes](passes/preload-plans.md) |
| [Private Rails app with Inertia Rails](m0/private-inertia-app.md) | Historical route sites + one opt-in digest site; no eligible `link_to` sites | Unit/request and browser outcomes identical; route/digest hits, zero fallbacks; SQL-trace caveat in notes | Historical digest micro 298.40 → 129.81 µs; page C −14.3%, pages A/B within noise; about 20.7% non-untyped returns. Guarded digest now refused; not current admission |
| PingCRM (Rails 8.1.4, Ruby 4.0.7) | 30/30 route sites, 4 route units + preload | 26/26 identical, 11 route + 7 preload hits | [Public Inertia M0](m0/inertia.md); seed 41231, browser suite included |
| Redprints CFP (Rails 8.1.3, Ruby 4.0.7) | 25/27 route sites, 14 route units; 9 Ruby files compiled | 50/50 non-system + 12/12 browser outcomes identical; 25 + 19 fast-path hits, **zero fallbacks** in both runs | Freezolite delivery and dynamic mounted-engine script completion fixed ([loader survey](loaders.md)) |
| React Starter Kit (Rails 8.1.4, Ruby 4.0.7) | 23/26 route sites, 8 route units + preload | 36/36 identical, 25 route hits across 7 units; no preload hits | [M0](m0/inertia.md) includes healthy SSR HTML and authenticated JSON |

Public Inertia builds and `observe` completed on all three. Lowrail-off
production/YJIT baselines and StackProf area shares are in [the M0](m0/inertia.md),
not speedup claims. All three version digests are eager boot Strings: **zero
digest calls across 400 traced requests/app**, unlike the version proc in
Private Rails app with Inertia Rails.
Configuration binding and serializer/prop descriptors are measured candidates;
dynamic users, props, SQL and SSR output must remain per request.

#### Pass-build migration, steps 1–3 (2026-10-20)

The Rust registry owns pass selection (`--passes default,+name,-name`, with
legacy flags retained), ordering and summary. All selected runtime builders
share one boot and return data; Rust merges units and the shared reason-coded
ledger before the compiler writes the manifest. Runtime delivery, guards and
installation are unchanged; architecture step 4 remains separate.

Before/after evidence is saved in [build-pass-equivalence.json](build-pass-equivalence.json):
every pass's units, lowered/refused diagnostics, hits and fallbacks, including
explicit zeros, corpus pins, timings and comparison fingerprints. Ruby 4.0.7,
seed 41231, `PARALLEL_WORKERS=1`, local Redis/PostgreSQL, cached facts. Baseline
is [c57b26a](https://github.com/thomasklemm/lowrail/commit/c57b26a29ec4f13e053413f761ff8cfe77ca1acc).
Default and all-pass configurations each cover **779 outcomes**: blog 21,
Campfire 634 (2 skips), PingCRM 1 + 25 browser, Redprints 50 + 12 browser,
starter kit 36. Outcomes and ordered same-thread SQL match across all four
baseline/candidate × off/on runs. Diagnostic identities/multiplicities and
per-pass hits/fallbacks match, not just totals. No unit ids changed: traversal
and runtime pass order were retained. Manifest comparison allows Ruby's
method-fact enumeration order and the changed builders' own source hashes;
compiled-file entries, templates and other payload values match.

| App | Default build seconds, before → after | All passes, before → after |
|---|---|---|
| real-blog | 4.49 → 5.05 | 9.92 → 6.98 |
| Campfire | 16.44 → 17.44 | 27.79 → 19.12 |
| PingCRM | 4.61 → 4.89 | 9.61 → 6.09 |
| Redprints CFP | 10.88 → 10.70 | 23.54 → 14.22 |
| React Starter Kit | 4.12 → 3.97 | 9.88 → 5.16 |

Single wall-clock observations, not a controlled speed claim. Measured boots:
default **2 → 2**, all passes **6 → 3** (oracle, runtime builders, compiler);
fresh facts add one. Other-thread SQL remains advisory: nine PingCRM browser
tests in both versions, and one Campfire default test after migration. Their
own-thread traces match. Corpus digest/URI coverage is zero; Campfire's
default debugger keeps memo/preload hits at zero in both versions. Gem fixtures
exercise these behaviors; no new support claim follows from zero-hit gates.

`cargo test --locked`: **30 unit + 3 integration passed**; release build passed.
Full gem suite from the repository root: **77 runs, 1418 assertions, 0 failures,
0 errors, 3 skips** (optional minitest-mock and two tests expecting the separate
`real-blog-r4` directory). Selection and unit/ledger merging have Rust tests;
ledger normalization preserves detail, copies and survey metadata.

#### Runtime migration, step 4 (2026-10-20)

`Lowrail::Passes` owns runtime selection and the single after-initialize
helper. Each present runtime receives only its units; absent runtimes are
not required. Source/template delivery and memo tracing remain eager; AR
epochs retain their own Active Record load hook. Existing runtime constants
and file paths remain available through aliases, preserving emitted code and
fact owners. Guard, Loader, Stats and Templates bodies are unchanged.

After integrating the stacked-benchmark and template-ledger publications,
combined checks pass: `cargo test --locked` **31 unit + 3 integration**;
`cd gem && rake test`
**90 tests / 1,502 assertions**, zero failures/errors and six optional skips;
all `bench/*_test.rb` **20 tests / 155 assertions**, zero failures/errors/skips.

The shared helper was exercised through a real cold Rails initialization:
two runtimes share one temporary TracePoint, activate in order, and leave
the trace disabled. Registration after initialization activates immediately.
Missing, incompatible and empty builds and empty selections load neither
pass/delivery/invalidation hooks nor default gems.

Serial `lowrail verify` before and after, seed 41231 and
`PARALLEL_WORKERS=1`, uses freshly rebuilt manifests for each runtime source
fingerprint. Both default and all-existing-pass builds have identical test
outcomes, ordered own-thread SQL, unit IDs and ledger identities/multiplicities:

| Corpus app (non-system + browser) | Identical outcomes per build | Own-thread SQL events per build |
|---|---:|---:|
| real-blog-r4 | 23 | 129 |
| Campfire (Redis) | 664 (2 existing skips) | 15,246 |
| PingCRM | 26 | 607 |
| Redprints | 62 | 778 |
| Starter Kit | 36 | 256 |
| Total | 811 | 17,016 |

The Starter's explicit one-test browser rerun is additional coverage, not
counted twice here. All ten non-system per-unit hit/fallback maps are exact;
seven browser maps are exact, with the three timing-dependent exceptions
attributed below. All original counts, including differences, are retained in
[runtime-pass-equivalence.json](runtime-pass-equivalence.json). Only checked
source certificates and moved, byte-identical wrapper-definition locations
are canonicalized; ledger details and ordered SQL are not masked.

Framework L3 also matches exactly, including per-unit maps and
duplicate-preserving shadow observations. SQLite AR: **9,240 outcomes,
68,857 instantiation hits, 11,616 fallbacks**. Action View groups: **2,747 +
242 + 173 outcomes**, with **118 AV-AR hits and zero fallbacks**. Manifests
remain built in a separate off process; there are zero shadow mismatches.

PingCRM's browser User-instantiation counter **85 → 83** is dispositioned
as request-count variance, not a changed instantiation path. Old/old is
**85/83** and new/new **83/83** at the same seed. Full instrumented browser
runs have **83 hits and zero outside-action hits on both runtimes**, with
identical counts and hit distributions for every controller action:

| PingCRM action | Old requests / User hits | New requests / User hits |
|---|---:|---:|
| `UsersController#index` | 9 / 43 | 9 / 43 |
| All other actions combined | 59 / 40 | 59 / 40 |

The original extra pair is one authentication User load plus one
`owner = false` filtered User load (one row each) in the deleted-user filter
test. The test already sees the deleted user after selecting “With Trashed”
and does not wait for the subsequent role filter. A teardown trace completed
without that role request, including a half-second post-run observation.
Ordered own-thread SQL and outcomes remain exact; other-thread SQL remains
advisory, not silently promoted to a strict gate.

Browser A/A controls (each pair uses the same runtime/code/seed; `H` is hits,
`F` is fallbacks) retain the following nondeterministic counts:

| App/build/unit | Old/old | New/new |
|---|---:|---:|
| Campfire default 32 H | 519 / 528 | 537 / 531 |
| Campfire default 44 H | 34 / 35 | 39 / 31 |
| Campfire default 58 H | 603 / 601 | 617 / 619 |
| Campfire all 32 H | 516 / 540 | 540 / 537 |
| Campfire all 45 H | 35 / 39 | 33 / 33 |
| Campfire all 59 H | 597 / 621 | 623 / 615 |
| Campfire all 62 H | 1,351 / 1,358 | 1,357 / 1,358 |
| Campfire all 64 H | 286 / 290 | 284 / 284 |
| Campfire all 70 H | 422 / 425 | 420 / 420 |
| Campfire all 71 H | 307 / 311 | 305 / 305 |
| Campfire all 73 F | 733 / 737 | 731 / 731 |
| Campfire all 78 H | 622 / 634 | 628 / 627 |
| Campfire all 79 H | 1,912 / 1,960 | 1,948 / 1,943 |
| Campfire all 81 H | 431 / 439 | 427 / 427 |
| PingCRM all 12 H | 85 / 83 | 83 / 83 |

The default unit 58 shift is larger than its A/A spread, so A/A alone is
**not** its disposition. Instrumented full browser runs attribute every
watched hit/fallback to a controller action or background work and reconcile
with global Stats totals. Per-request hit buckets are unchanged:

| Campfire build/action | Old/new requests | Hits per request (old/new) |
|---|---:|---|
| Default `Rooms#show`, unit 58 | 93 / 93 | 1 / 1 |
| Default `Users::Sidebars#show`, unit 32 | 180 / 180 | 3 / 3 |
| Default `Users::Sidebars#show`, unit 58 | 180 / 180 | both `{2:110, 4:54, 6:16}` |
| Default `Messages#update`, unit 44 | 37 / 34 | 1 / 1 |
| All `Rooms#show`, unit 59 | 93 / 93 | 1 / 1 |
| All `Users::Sidebars#show`, unit 32 | 174 / 180 | 3 / 3 |
| All `Users::Sidebars#show`, unit 59 | 174 / 180 | `{2:108, 4:51, 6:15}` / `{2:112, 4:53, 6:15}` |
| All `Messages#update`, unit 45 | 39 / 36 | 1 / 1 |

Histogram entries mean `hits:request_count`, not an average. Four extra
2-hit and two extra 4-hit sidebar requests explain the entire all-build
unit 59 **+16**; default unit 58 totals are **625/625** in the attribution
run. The three fewer low-count update requests each account for one
RichText/Membership/Message/Session hit, two User/AR-plan hits and one Room
fallback. Other actions and all watched background maps are exact, including
316 background Room fallbacks; there are no outside-action route hits.
Thus these are request-count/composition differences, not changed per-request
specializations. No waits or corpus test semantics were changed to hide them.

Inertia integration is separate from existing-pass equivalence: **811
identical outcomes, 17,014 identical ordered own-thread SQL events, 514
binding hits and zero fallbacks**, with empty off-mode counters. Hits are
PingCRM **218**, Redprints **36 + 216**, Starter **44**; the other apps have no
unit. All **12 production HTML/JSON byte comparisons** pass through standard
shared activation, including live Starter SSR. Two new/new PingCRM runs
both have **68 requests, 182 in-action + 36 outside bindings, zero fallbacks**,
with identical full action histograms. Replaying the original activation
shim on the archived published runtime gives the exact same distribution
and **218/0**. The historical **222** is an unattributed cohort that the
original activation path does not reproduce; an optional role-filter request
is plausible but not proven for that untraced cohort. The pass stays opt-in;
its failed native A/A controls remain failed.

Fixed-heap blog `GET:/articles`, six interleaved rounds × 50 requests with
50 warmups, compares the same source-only manifest against the archived
pre-refactor library (`BENCH_BASELINE_LIB` in `bench/request_pairs.rb`).
Both independent A/A instruction controls and all five heap capacities pass.
Candidate/old-runtime total instructions: **−0.02090% [−0.05032, −0.00626]**;
GC-excluded: **−0.01292% [−0.05570, +0.00183]**. Missing/empty/disabled
layers remain within noise of off. No added request tax is observed.
The initial before-only total A/A control failed and is retained, not used
as equivalence evidence. These interpreter counts are not a native YJIT
speed claim. The stats-disabled YJIT receiver-guard micro remains about
663 instructions/check: **662.482978 → 662.506856 (+0.00360%)** over
1.5 million checks; its implementation is unchanged.

Cold `require + setup` is measured separately because request windows exclude
boot. Six paired rounds with independent old/old and new/new workers and
identical, unchanged capacities in all five heap pools show **+0.758%**, about
**0.37–0.40 million instructions once per boot**, not per request. Three
segmented observations per runtime attribute the cost as follows (medians;
the extra segment seams mean their sum need not equal the whole-setup delta):

| Cold phase | Before instructions | After instructions | Delta |
|---|---:|---:|---:|
| Require `lowrail.rb` | 2,052,121 | 1,663,981 | −388,140 |
| Require `passes.rb` | 0 | 843,805 | +843,805 |
| Source delivery and pass selection | 3,029,117 | 2,951,341 | −77,776 |
| Manifest/Guard/Loader require, load and install | 47,116,759 | 47,107,789 | −8,970 |
| Segmented net | | | +368,919 |

The blog's 11 source units cause **zero runtime-pass requires, installs or
activations**. Only the registry's static descriptors and empty selections
are built for absent runtimes; the cost is loading/compiling the registry and
shared helper, not eager pass state. A later option is shipping `passes.rb`
as a precompiled ISeq; that is a follow-up, not part of this refactor. See
[benchmark method](bench.md#runtime-registry-cold-cost) for the measurement boundary.

#### Per-file loader policy (2026-10-20)

Build captures the app's real compiler calls, including Freezolite's temporary
defaults and Bootsnap's selected per-file options. Runtime requires the same
recipe, original ISeq and source bytes before substituting lowered code;
Bootsnap caches only originals. Installation-order and ecosystem details are
in [loader composition](loaders.md). This is delivery/correctness work, not a
speed claim.

Executed on Ruby 4.0.7, using the `script/corpus` pins and seed 41231:

- real-blog: build 11 units, verify 21/21 identical, 56 hits across all
  11 units, 1 view fallback.
- Campfire: verify 634/634 identical (2 skips both ways), 6913 hits across
  52 units, zero fallbacks.
- Redprints: build 14 units and compile all 9 Ruby files with its own
  Freezolite policy. Non-system RSpec is 50/50 identical, 25 hits across
  9 units; browser RSpec is 12/12 identical, 19 hits across 8 units. Both
  report zero fallbacks. These runs include the separate
  [mounted-engine completion fix](https://github.com/thomasklemm/lowrail/commit/9fa9bd13313ad0314f606d37e221b66616751b8f):
  `find_script_name` remains dynamic instead of using a class-wide guard
  that engine singleton overrides could invalidate.

The full gem suite passes: 58 runs, 1583 assertions, 3 skips. Historical
Ruby 3.4.11 targeted compiler/loader/end-to-end tests passed: 20 runs,
483 assertions, 1 skip; Ruby 3.4 is no longer a target. Rust tests pass
(22 unit + 2 integration). The two loader-policy
regressions fail on pre-fix main and pass with the fix. A further cached-hijack
regression fails without the follow-up recipe guard and passes with it;
tests cover actual frozen-literal behavior and lowered-file delivery, not
just process success.

#### Build surface (2026-10-20)

Materialize, as added modules / methods / generated scripts per step after
`config/environment` (real-blog 5210 / 36752 / 1155 at boot, Campfire 6840
/ 49628 / 1602):

| step | real-blog | Campfire |
|---|---|---|
| `eager_load!` | +1520 / +9114 / +693 | +791 / +2765 / +464 |
| production eager load (Zeitwerk all, namespaces) | +726 / +4203 / +144 | +955 / +5895 / +174 |
| models (schema, attribute methods) | +41 / +524 / +48 | +26 / +4110 / +266 |
| relation delegation (speculative) | 0 | +0 / +6 / +6 |
| lazy routes | +0 / +68 / 0 | +88 / +704 / +22 |
| controllers (`view_context_class`) | +7 / +145 / +32 | +7 / +145 / +31 |
| templates compiled | +1 / +30 / +28 | +2 / +154 / +104 |

Generated scripts: real-blog 2096 (0.75 MB), Campfire 2664 (1.2 MB); methods
compiled from one: 5657 / 8960; app-relevant methods with a linked
generated `def`: 299 / 2840. Capture costs ~15–25 ms of hook time
(boot +0.05 s on real-blog, within noise on Campfire's 2 s).

Observed test run against the materialized facts: real-blog defines 9942
methods after boot, Campfire 19524; all but 1438 / 4446 are in the facts
(by name, generated `def` text, or template). The rest is test-only code
(Minitest/Rails testing, fixtures, mocha, webmock, rexml, DRb), no app
method; the only templates are Campfire's 8 exception-page templates,
recompiled per rendered exception (80 methods). Suite overhead: definitions
only +0.4 s real-blog (fixed cost), +3–4 % Campfire; with type sampling (16
per method, 586 methods hooked) +3–6 %; uncapped sampling up to +9 %.

### Learned

1. **Speed is in framework code** (M0: real-blog app self time ≈0 %,
   Campfire 1.5–4.9 %), so lowering targets Rails and gem code as used by the
   app, not just `app/**/*.rb`.
2. **Two delivery kinds**: Ruby-file ISeqs at native compilation, cache output
   or explicit eval, and the handler call in
   `ActionView::Template#compiled_source` for templates. No `load_iseq` override.
3. **Per-call-site guards beat per-method guards** for a first pass: they
   keep line numbers, never evaluate arguments twice, and need no change to
   method tables.
4. **Partial evaluation through the booted app** (the oracle) is the robust
   way to "derive from the booted Rails app": constants come from Rails
   itself, and probes turn escaping assumptions into checked facts.
5. **Single helpers are small wins** (`link_to` 6.6 → 2.6 µs); measurable
   gains need many sites per request or framework paths per request
   (Campfire: CSP/importmap URL work 34.8 % inclusive on cached pages,
   Active Record dispatch and fragment keys when uncached).

6. **Boot is not the whole app, but materialize nearly is.** In test env
   `eager_load!` sees a quarter of what production eager load plus lazy
   generation build (Campfire: 2765 of 13779 added methods). After
   materialize, a full test run adds no app method; what it adds is test
   machinery. Generated code is only meaningful per `def`: Active Support's
   CodeGenerator shares method caches across models and batches them in
   run-dependent order, so script digests differ while `def` texts match.

### Next (2026-10-20, as STATUS.md listed it)

Current priorities (2026-10-20):

1. **Endpoint, guarded tier:** price body-installed specialization, where
   normal VM dispatch keeps identity, visibility and redefinition exact, on
   the two show links before any runtime implementation.
2. **Sealed tier:** contract (`docs/sealed.md`), `lowrail seal-check` detector
   and five-app violation ledger, then a blog show sealed-endpoint pilot.
3. **Props pass** from the allocation survey (interpreter and YJIT micro gates
   pass), opt-in, with mutation regressions.
4. **Ruby 4.1 matrix column and ZJIT diagnostic mode,** plus a check for a
   public VM invalidation API.

Older follow-ups:

- Candidate #4 is **parked, upstream-solved**, with no Lowrail backport:
  Rails main's [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b)
  fuses attribute appends (not yet in `8-1-stable` or 8.1.0–8.1.4).
  Estimated pre-guard saving is only ~0.3–0.45% blog edit / ~0.2–0.3%
  Campfire room. [Five-app census and per-site refusals](passes/tag-options.md):
  12/94/2/0/0 direct tag/form sites; 504 scratch controls per Rails pin,
  zero differences. It remains the cheapest later component pilot.
- **Campfire fragment caches stay** ([measurements](passes/campfire-fragments.md)):
  six native off/off/on cohorts find no uncached-all-pass render cheaper
  than its warm hit (roughly 1.8–9.6× the hit cost). Uncached off/on query
  counts and complete collection HTML agree; native A/A fails, so no precise pass gain is claimed.
  App recommendation only; no cache-policy or runtime changes.
- Route defaults and template lookup are parked. Revisit routes as a stacking
  item after shared per-hit budgets; argument-less conversion covers 1/4
  Campfire guarded path calls, full base-AR certification could cover 4/4.
- Generic route generation and guarded block-result mappings remain unsupported;
  host normalization is request-local, but Rails' `url_options` assembly and
  application overrides remain per call.
- Extend controlled instruction measurements to the other corpus apps and
  resolve native YJIT boot/GC sensitivity before claiming request speedups.
- Broader memo certificates for timeout-sensitive URI work; exact file-digest
  memo now works, but its byte-indexing/read cost remains measurable.
- Active Record attribute/reflection dispatch (Private Rails app with Inertia
  Rails, Campfire uncached).
