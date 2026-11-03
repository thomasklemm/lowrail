# Lowrail

**Lowrail measures real open-source Rails apps on Rails main and upstreams
small, exact fixes for the avoidable work it finds** in Rails, in Ruby and its
JITs (YJIT, ZJIT), and in gems. Results are allocation and instruction counts;
no request speedup is claimed.

If you came here from a PR, [how candidates are found and measured](docs/upstream/method.md)
explains where its numbers come from.

Until 2026-11-02 Lowrail was a prototype that lowered Rails apps to specialized
Ruby. That work is kept below as [research](#lowering-prototype-research)
([why it changed](docs/DECISIONS.md#lowrail-reoriented-toward-upstream-fixes-and-advisory-types-2026-11-02)).

## The census

[`script/census`](docs/upstream/census.md) moves about 20 open-source apps onto
one pinned Rails main commit and runs their request, job and mailer workloads.
The latest round, [census 7](docs/upstream/rails-main-census-7.md), covered 20
apps in 23 configurations and 251 workloads, on SQLite, PostgreSQL and MySQL,
in the interpreter and under YJIT. The apps include Mastodon, Discourse,
Lobsters, Chatwoot, Sure, Fizzy, Campfire, Writebook, Loomio and CASA. Each app
keeps its own code; only Rails and the gems it needs change.

## How candidates are found and measured

In short, from [method.md](docs/upstream/method.md):

1. **Find.** For every workload the census counts objects allocated per source
   line. Every round runs twice, as an A/A pair, to show the noise floor. Lines
   are ranked by how many apps reach them, then by objects per workload, and
   open and closed PRs that touch a line are searched before anything is built.
2. **Build.** The smallest change that behaves exactly as before for every
   caller, checked against the original by a differential harness and the
   framework's own test suites, and read by two independent reviews. A change
   that makes the code noticeably harder to read is shrunk or dropped.
3. **Price.** Per call (objects and Callgrind instruction counts), on
   ruby-bench (railsbench, lobsters, shipit), and in the census again, always
   against the same commit without the change and as an A/A pair. A candidate
   whose CPU gain stays within the A/A and that adds code is not opened.

## Combined effect

Measured together, as Rails main against the same commit with our merged PRs
reverted ([combined effect](docs/upstream/combined-effect.md)):

* **11 PRs** (#59533–#59544), Ruby 4.0.7: **1.66%** fewer allocations in the
  interpreter and **1.64%** under YJIT, across 206 request, job and mailer
  workloads in sixteen apps. Every app moves, by 0.8% to 3.0%, and no workload
  allocates more. Wall time on ruby-bench's railsbench and lobsters is a tie
  within the A/A, and GC runs per iteration do not change.
* **22 PRs** (merged by 2026-11-03 10:43 UTC), Ruby master: **3.27%** fewer
  allocations interpreted and **3.21%** under ZJIT, across census 4's nine apps
  (97 workloads). Under ZJIT, ruby-bench runs **0.54%** (railsbench) and
  **0.49%** (lobsters) fewer instructions per iteration, outside the A/A.

These are allocation and instruction savings, not a measured speedup.

## Contributions

The [contributions ledger](docs/upstream/contributions.md) lists merged, open
and closed PRs, each with its own measured result and caveats: rails/rails,
ruby/ruby (YJIT and ZJIT), sqlite3-ruby, Prism, Campfire and other gems. It also
records validation reviews and the candidates investigated and not submitted,
with the reasons. What we pursue, park or reject, and why, is in
[DECISIONS.md](docs/DECISIONS.md).

## Reproduce

Requirements: Git, [mise](https://mise.jdx.dev), network access, and the local services an app needs
(Redis, PostgreSQL, MySQL; see [census.md](docs/upstream/census.md#services-and-apps)).
`script/census` measures on Ruby 4.0.9 (installed by mise on demand; `--ruby` picks another);
`mise.toml` pins 4.0.7, the lowering prototype's Ruby, which runs the script itself.
The Blog needs none of the services:

```sh
git clone https://github.com/thomasklemm/lowrail && cd lowrail
mise exec -- script/census setup --rails main --apps blog     # app copy on Rails main, smoke-tested
mise exec -- script/census run --label base --aa --apps blog  # A/A pair: base and base2
mise exec -- script/census rank --label base2                 # Rails lines by breadth, then objects
mise exec -- script/census compare --base base2 --aa base     # the A/A noise floor
```

Omit `--apps` for every app. To measure a Rails branch, run it under a new
label with `--rails OWNER/REPO@BRANCH` and compare it against `base2`. To add
your own app, see [Run it on your own app](docs/upstream/census.md#run-it-on-your-own-app).
Each report under [docs/upstream/](docs/upstream/) lists its pins and commands;
receipts of published rounds are in [docs/upstream/data/](docs/upstream/data/).

## Lowering prototype (research)

Lowrail's original prototype, as it stood on 2026-10-22. It stays in the tree
as research, unchanged and not promoted
([decision](docs/DECISIONS.md#lowrail-reoriented-toward-upstream-fixes-and-advisory-types-2026-11-02)).

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
guarded exactly, and measure every claim. See [Acknowledgements](#acknowledgements)
for the other projects we learned from.

> **Research prototype.** Lowrail is not published as a gem and gives no
> production speedup by default today. Use it on a copy of your app or in CI.

### Historical results (2026-10-21)

> **Historical.** These are the prototype's last measured results, on Ruby 4.0.7
> and Rails 8.1.4 at the linked commits. They have not been re-measured since.
> The upstream work measures on Ruby 4.0.9 and Rails main; see
> [Combined effect](#combined-effect).

#### Warm-request instruction counts

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
| 2026-10-21 | [BlogShowGetOnly (blog), `GET /articles/1`](docs/passes/production-aa01-reprice.md) | 4.0.7 / 8.1.4 | Interpreter; Sealed opt-in: production form/token/collection | **Total −15.02% [−15.05, −15.00]**; GC-excluded −15.02% [−15.04, −14.97] | [b059fc9](https://github.com/thomasklemm/lowrail/commit/b059fc9fbcdbc4cff6a7bc523defb01e7783385c) / [602e20c](https://github.com/thomasklemm/lowrail/commit/602e20c5b22c912bb3ef050949271a68395a1bba); [JSON](https://github.com/thomasklemm/lowrail/blob/602e20c5b22c912bb3ef050949271a68395a1bba/docs/passes/production-aa01-reprice-results.json) |
| 2026-10-21 | [React Starter Kit, `GET /dashboard` JSON](docs/passes/yjit-regression.md#post-fix-whole-request-checks-one-finite-cohort-per-mode) | 4.0.7 / 8.1.4 | Interpreter; Sealed opt-in: config binding; not promoted | **Total −10.16% [−10.22, −10.08]**; GC-excluded −10.16% [−10.25, −10.11] | [ed7cbbe](https://github.com/thomasklemm/lowrail/commit/ed7cbbe8f8ab6e9b7be24775ac76a94cebecd95e) / [01cfc45](https://github.com/thomasklemm/lowrail/commit/01cfc45f2355b99eafd01f9ce17a6a13ef062aa7); [JSON](docs/passes/yjit-regression.json) |
| 2026-10-21 | [Fizzy, fixed six-GET vector](docs/block-link-specimen.md) | 4.0.7 / 8.1.4 | Interpreter; Bench-only block-link; N=10, fixed init-slot floors; not production admission; cold RED | **Total +0.40% [+0.39, +0.43]**; GC-excluded +0.40% [+0.38, +0.42] | [da5fe91](https://github.com/thomasklemm/lowrail/commit/da5fe91e2f04a27acef1f7245efa7f39a7332577) / [8385e0c](https://github.com/thomasklemm/lowrail/commit/8385e0cf5d951e378a690e55707e431eef049b69); [JSON](docs/fizzy-link-ir-n10.json) |
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
[`62f8a6b` cohort](docs/passes/production-dispatch-reprice.md) remains rejected
under its old zero-containment/±0.5% A/A rule
([`673b1cc`](https://github.com/thomasklemm/lowrail/commit/673b1cc3cbbb341a6956e027e54bc2a18049bde0));
it was not rescored or pooled into the new cohort. The earlier **−15.49%**
is historical, valid only at
[`ae025b0`](https://github.com/thomasklemm/lowrail/commit/ae025b0d9f456d9f9bef55e9e131bc25178e83cb),
not the corrected source. [Protocol and historical records](docs/bench.md#current-accepted-request-results).

**Not request prices:** production YJIT method stage 1 is rejected
([retained method and reaper-driven late-entry diagnosis](docs/passes/production-yjit-method.md));
frozen props is an accepted isolated micro only, with integration deferred
([scope](docs/passes/props-native.md#accepted-combined-interpreter-micro-integration-deferred)).

Fizzy's block-link N=10 warm bench price above is an **instruction INCREASE
(Lowrail slower here)** under fixed init-slot floors, not production
admission or cold-start performance; **cold still RED**.
The [first N=50 cohort remains INVALID (heap growth)](https://github.com/thomasklemm/lowrail/commit/7c6cd19dbe77605ab7066e3234001b4358519e51),
without a credited price or direction claim ([scope and evidence](docs/block-link-specimen.md)).

#### Full-request throughput (real Puma)

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
paths in [docs/results.json](docs/results.json), then run
`python3 docs/render-results.py` (`--check` detects drift). Numbers are read
from the original exports, never copied into the index. Pinned exports use
an explicit `source_commit` matching the full publication SHA; fetch bet F's
branch with `git fetch origin thomasklemm/ar-callsite-compile` and bet A's with
`git fetch origin thomasklemm/native-yjit-bench` before rendering.
The new Lobsters and Fizzy guard records additionally require
`git fetch origin thomasklemm/screen-platform thomasklemm/jit-guards`.
They are read from that commit, never substituted from the main worktree.
Refresh the short
[status](docs/STATUS.md#at-a-glance-2026-10-21) and [benchmark summary](docs/bench.md#current-accepted-request-results)
when scope or acceptance changes; retain superseded records as historical.

#### Supported and unsupported today

- **Default:** lowers nothing; original Rails remains in control. The
  [corpus compatibility report](docs/compat.md) distinguishes identical
  outcomes/SQL, baseline errors, bounded subsets, safe refusals and actual hits.
- **Opt-in:** sealed production units require the [separate contract](docs/sealed.md)
  and exact passive admission. The two sealed production rows do not imply arbitrary
  endpoint coverage or config promotion. A separate
  [verification-only test certificate](docs/test-certificate.md) exercises
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
  ([boundary](docs/decisions-prototype.md#ancestry-changing-delivery-refuses-whole-artifacts-2026-10-22)).
  The priced three-unit form/token/collection artifact is unaffected.
  Unsupported shapes, stale or mode-mismatched artifacts, and the Bundlebun
  boundary stay original
  ([pass ledger](docs/decisions-prototype.md#passes), [loaders](docs/loaders.md)).

#### Also on main (2026-10-22)

- **Sealed mutation tripwire** ([ce47c62](https://github.com/thomasklemm/lowrail/commit/ce47c620cfe85dbc939189e351e051db09e8c484)):
  certified method/ancestor changes retire admitted units. This is a backstop,
  not enforcement of the whole [sealed contract](docs/sealed.md#production-mutation-tripwire-not-enforcement).
- **Advisory types contracts** ([07829bf](https://github.com/thomasklemm/lowrail/commit/07829bfa6dc170ae8100cc7b04a2e0ea98f985fa)):
  +442 static slots and +843 observed argument slots across the fixed six-app
  ledger; sampled types are not proofs or runtime specialization
  ([evidence and limits](docs/types-contracts.md)).
- **Plain sealed blog build** ([6fb2f14](https://github.com/thomasklemm/lowrail/commit/6fb2f149cd9ad81522694799eb188139e9e75459)):
  `lowrail build APP --sealed --env production --jit interpreter` now delivers
  **≈377 fewer objects/request on blog show/show2; index is neutral**, with
  no denylist or manual isolated-artifact selection. The unsafe preload/link
  builders ledger-refuse before emission; old combined artifacts still refuse
  as a whole. Allocation evidence only, not a new Ir, timing or throughput
  claim; form stays narrow and preload/link/template delivery stays quarantined
  ([current scope and history](docs/decisions-prototype.md#plain-sealed-blog-build-and-historical-isolation-gap-2026-10-22)).

**Breadth is not savings:** Fizzy, Campfire, Writebook and CASA retain exact
own-suite off/on outcomes but **no certified optimized suite hits**. Fizzy's
suite has a compiler-certificate refusal (production queries separately fail
query certification); Campfire/Writebook have Bootsnap `KeyError`, and CASA
has unsupported RSpec certificate discovery at an older retained pin. Parity
includes Fizzy's baseline errors and CASA's skips. **No savings claim for
these plain sealed builds outside the blog**
([pins and limits](docs/decisions-prototype.md#own-suite-breadth-is-not-optimized-coverage)).

### How it works

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

### Quick start

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

### Status (2026-10-21)

- **Correctness machinery works.** `lowrail verify` compares per-test outcomes
  and ordered SQL with Lowrail off and on. The pinned Rails 8.1.4 framework
  suites are a standing gate ([rails-suite.md](docs/rails-suite.md)). Real apps
  including Fizzy, Writebook, CASA, CodeTriage, Wikino, RubyToolbox and Fat
  Free CRM keep identical outcomes ([compat.md](docs/compat.md)). Green
  comparisons are not a universal support claim.
- **The default build lowers nothing.** Every guarded specialization tried so
  far was either unsafe under mid-request mutation or its guard cost more than
  it saved ([decisions-prototype](docs/decisions-prototype.md)).
- **The sealed tier has scoped interpreter results**, shown in
  [Historical results](#historical-results-2026-10-21). Passive production form,
  token and collection admission is implemented; the separate test certificate
  remains AR-only ([production](docs/passes/sealed-production.md),
  [test coverage](docs/test-certificate.md)).
- **No whole-request YJIT gain is established.** Retained cohorts/methods
  fail the strict compilation or A/A gates, including Lowrail-off arms
  ([bench.md](docs/bench.md)).
- **Prism 2 is adopted** in Ruby tooling and Rust, with explicit target
  grammar and refusal for unknown versions; app bundles are not forced to
  upgrade ([implementation and evidence](docs/prism-2.md)).
- **Types and MCP work.** `lowrail types`, `lowrail explain` and
  `lowrail mcp` serve boot facts, per-slot types (proven, static, observed or
  unknown), refusal reasons and recorded hits ([types.md](docs/types.md)).

Every pursued, parked and rejected idea is in
[docs/decisions-prototype.md](docs/decisions-prototype.md). Dated evidence is in
[docs/STATUS.md](docs/STATUS.md).

### Direction

Two tiers, so that every app keeps running and apps that opt in can go
further:

| Tier | Who | Promise | State |
|---|---|---|---|
| **guarded** (default) | any Rails app, any gem | identical test outcomes; specializations guarded and refused when not exact | works; currently lowers nothing by default |
| **sealed** (opt-in) | apps that accept a contract: no code, subscriber, config or route mutation after boot, among others | compile endpoints ahead of time without per-call checks; `lowrail seal-check` runs the app's suite and lists every violation with `file:line` and the code change that fixes it | opt-in research: measured interpreter wins; admission must be passive ([sealed.md](docs/sealed.md), [decision](docs/decisions-prototype.md#architecture)) |

Apps that do not meet the sealed contract still run in the guarded tier. The
tooling explains why and what to change.

### Target matrix

| Axis | Primary | Secondary / diagnostic |
|---|---|---|
| Rails | 8.1.4 | 8.2 alpha (Campfire's pin) |
| Ruby (minimum 4.0) | 4.0.7 (the prototype's pin) | 4.1 preview ([separate compatibility matrix](docs/ruby-4.1.md)) |
| Execution | interpreter instruction counts (Callgrind, fixed heap, A/A controls) | YJIT under a strict JIT-flat gate; ZJIT being added, diagnostic only |

How to read and reproduce measurements: [docs/bench.md](docs/bench.md).

### Reference

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
a visible refusal. [Contract and bounded validation](docs/sealed-verification.md#optional-native-holder-prototype-link-coverage-recovered).

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
`area/name` identifiers in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
Short aliases are `memo`, `preload_plans`, `ar_instantiate`, `ar_plans`,
`digest_memo`, `inertia_config`, `props` and `endpoint`, but only `props` and
`endpoint` remain eligible for guarded selection. The others refuse even in
`all-opt-in`; old mixed artifacts refuse as a whole. Sealed research builds
use `--sealed --env production` and require explicit production acceptance
of the [sealed contract](docs/sealed.md). Production artifacts refuse in test;
the separate opt-in [verification-only AR certificate](docs/test-certificate.md)
does not bypass that boundary.
File formats are documented in [docs/FORMATS.md](docs/FORMATS.md).

`LOWRAIL_VERIFY_LOADS=1 lowrail verify APP` also compares non-autoloading
constant censuses, Zeitwerk-loaded paths and executed Active Support load
hooks at the first test and after the suite, including load/hook order.
Reproducible differences fail verification and automatically probe each pass;
off/off and on/on variation is reported separately as advisory noise.
This observer is opt-in because its snapshots and boot hooks have a cost;
the corpus compatibility checks enable it. Snapshot time is in the report.

### Complementary optimizations

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
  use ([loaders.md](docs/loaders.md)).

## Docs

| Read | For |
|---|---|
| [upstream/method.md](docs/upstream/method.md) | how upstream candidates are found, built and measured |
| [upstream/census.md](docs/upstream/census.md) | `script/census`: run, rank, compare, add an app |
| [upstream/combined-effect.md](docs/upstream/combined-effect.md) | merged Rails PRs measured together |
| [upstream/contributions.md](docs/upstream/contributions.md) | upstream PRs, their results and caveats |
| [upstream/explainers.md](docs/upstream/explainers.md) | German explainer per open ruby/ruby and rails/rails PR, and where a reply is owed |
| [PLAN.md](docs/PLAN.md) | goals, contract, why this design |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | pipeline, pass contract, registry |
| [DECISIONS.md](docs/DECISIONS.md) · [decisions-prototype.md](docs/decisions-prototype.md) | current rules and decisions; the parked prototype's decisions and stacking backlog |
| [STATUS.md](docs/STATUS.md) | dated evidence log |
| [compat.md](docs/compat.md) | pinned real apps, gem breadth, baseline failures, load-order findings and verify results |
| [bench.md](docs/bench.md) | measurement protocol and results |
| [types.md](docs/types.md) | typed facts, MCP and RBS |
| [docs/passes/](docs/passes/) | one study per pass or idea |
| [rails-suite.md](docs/rails-suite.md), [ar-equivalence.md](docs/ar-equivalence.md) | framework-suite and Active Record gates |
| [development/workflow.md](docs/development/workflow.md) | bet counterexamples, exact-head gates, review and publication rules |

## Acknowledgements

Lowrail stands on other people's work. Thank you to the authors and
maintainers of:

- [Roundhouse](https://github.com/rubys/roundhouse) (Sam Ruby): the
  inspiration for this project, its lowering pipeline and unsupported-code
  ledger, whole-program typing without annotations, the MCP tools, and the
  real-blog fixture we still use as our first corpus app.
- [Prism](https://github.com/ruby/prism) and its `ruby-prism` crate (Kevin
  Newton and the Ruby core team): parsing.
- [Rubydex](https://github.com/Shopify/rubydex) (Shopify): code indexing and
  its arena/typed-ID design.
- [Ruby](https://github.com/ruby/ruby), YJIT and ZJIT: the VM, `RubyVM::InstructionSequence`
  and the JITs we measure under.
- [Rails](https://github.com/rails/rails), [Zeitwerk](https://github.com/fxn/zeitwerk)
  and [Bootsnap](https://github.com/rails/bootsnap): the framework, loader and
  cache Lowrail has to stay exact with.
- Loader prior art: [require-hooks](https://github.com/ruby-next/require-hooks)
  and [Ruby Next](https://github.com/ruby-next/ruby-next) (Vladimir Dementyev),
  [Yomikomu](https://github.com/ko1/yomikomu) (Koichi Sasada),
  [Vernacular](https://github.com/kddnewton/vernacular) (Kevin Newton),
  [Tapioca](https://github.com/Shopify/tapioca) and
  [Freezolite](https://github.com/ruby-next/freezolite) ([loaders.md](docs/loaders.md)).
- [Inertia Rails](https://github.com/inertiajs/inertia-rails),
  [Herb](https://github.com/marcoroth/herb) and
  [ReActionView](https://github.com/marcoroth/reactionview).
- The open-source apps in our corpus: [Campfire](https://github.com/basecamp/once-campfire),
  [Fizzy](https://github.com/basecamp/fizzy), [Writebook](https://github.com/basecamp/writebook),
  [CASA](https://github.com/rubyforgood/casa), [CodeTriage](https://github.com/codetriage/codetriage),
  [PingCRM](https://github.com/ledermann/pingcrm),
  [Redprints CFP](https://github.com/evilmartians/redprints-cfp),
  [Inertia React starter kit](https://github.com/inertia-rails/react-starter-kit),
  [Wikino](https://github.com/wikinoapp/wikino),
  [RubyToolbox](https://github.com/rubytoolbox/rubytoolbox) and
  [Fat Free CRM](https://github.com/fatfreecrm/fat_free_crm).
- [Valgrind](https://valgrind.org/)'s Callgrind, which makes our instruction
  counts reproducible.

## License

MIT, see [LICENSE](LICENSE).
