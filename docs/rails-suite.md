# Rails' own suites as a Lowrail gate

2026-10-20; Rails **v8.1.4**, source commit
[`c3466ea`](https://github.com/rails/rails/commit/c3466ea00d7121798e3aa3144ffdf7174b81d8cb),
Ruby **4.0.7** (the runner requires Ruby 3.4+), seed **41231**. This is a
compatibility gate, not a speed benchmark or a universal support certificate.
It complements app `lowrail verify` gates before broadening PLAN §7 decision 2
to framework/gem specialization. Round 2 below exercises existing passes;
no callback pass is installed. The original Round 1 runtime is main at
[`d9fd466`](https://github.com/thomasklemm/lowrail/commit/d9fd466afac5de38c30ecb5d4b56f475ed4dd840);
later benchmark/report-only main commits do not change those runtime files.

## Round 1 compatibility table

Cells are **raw identical observations / baseline observations**, including
matching skips. Dynamic identities are excluded only after controls, never
silently normalized into passes. Differences means reproducible differences
after independent off/off and, where needed, on/on controls.

| Suite | L1: no manifest | L2: fallback manifest | L3: existing AR passes | Differences | Status |
|---|---:|---:|---:|---:|---|
| Active Support | 5814/5815 | 5814/5815 | 5814/5815 | 0 | One anonymous-class identity; 1068 matching skips |
| Active Model | 1100/1100 | 1100/1100 | 1100/1100 | 0 | Identical; no L3 units |
| Active Record / SQLite memory | 9240/9240 | 9240/9240 | 9240/9240 | 0 | 44 matching skips; instantiation hits |
| Active Record / PostgreSQL 15 | 10186/10186 | 10186/10186 | 10186/10186 | 0 | 24 matching skips; instantiation hits |
| Action Pack | 4095/4095 | 4095/4095 | 4095/4095 | 0 | Identical; no L3 units |
| Action View (three upstream task groups) | 3162/3162 | 3162/3162 | 3162/3162 | 0 | Instantiation hits in AR integration group |
| Active Job / inline | 209/212 | 209/212 | 209/212 | 0 | Three time-dependent identities; no L3 units |
| Action Mailer | 268/268 | 268/268 | 268/268 | 0 | Identical; no L3 units |
| Railties (11 core files only) | 125/125 | 125/125 | 125/125 | 0 | Bounded; no L3 units |

All five unprofiled processes per row (off, off-repeat, L1, L2, L3) exit
successfully with **zero failures/errors**. The four unstable printed names
are not outcome changes: all observations pass in both modes, but cannot be
paired by identity. Active Support's skips include unavailable Redis and
memcached integrations; matching skips are not exercised coverage.

### Round 1 L3 coverage and refusal boundaries

| Group | Instantiate / SQL-reader / preload units | Hits | Counted fallbacks | Shadow mismatches |
|---|---:|---:|---:|---:|
| AR / SQLite | 620 / 0 / 1 | 68,857 | 11,616 | 0 |
| AR / PostgreSQL | 642 / 0 / 1 | 67,744 | 13,439 | 0 |
| Action View / AR integration | 16 / 1 / 1 | 118 | 0 | 0 |
| All other groups | 0 / 0 / 0 | 0 | 0 | 0 |

**All measured L3 hits are instantiation hits.** No SQL-reader or preload
fast-path coverage is claimed. The full AR suite replaces part of the Arel
method inventory with Minitest::Spec methods, so SQL-reader certification
refuses it. Generated HABTM model names are not root constants; their
unresolvable facts safely disable the shared preload unit. These are
recorded refusal/guard boundaries, not reasons to weaken certification.
The existing preload pass does not count every guard fallback, so the table
reports available counters, not all attempted preload calls. L2 records 17
synthetic fallbacks in every group; those are not specialization hits.

### Wall time

Seconds per fresh process, including loading; single observations, **not
controlled performance comparisons**. The Action View row sums its three
processes. Concurrent orb work, deliberate sleeps, IO and strict shadow
instrumentation make these unsuitable for a speed claim.

| Suite | Off | Off repeat | L1 | L2 | L3 |
|---|---:|---:|---:|---:|---:|
| Active Support | 50.36 | 50.44 | 50.48 | 50.81 | 50.49 |
| Active Model | 1.76 | 1.74 | 1.73 | 1.86 | 1.72 |
| AR / SQLite | 49.03 | 51.80 | 49.13 | 48.65 | 53.40 |
| AR / PostgreSQL | 116.21 | 118.11 | 119.05 | 118.06 | 120.55 |
| Action Pack | 12.05 | 12.30 | 11.81 | 12.22 | 12.53 |
| Action View | 7.64 | 7.50 | 7.60 | 7.95 | 7.63 |
| Active Job | 0.57 | 0.59 | 0.65 | 0.58 | 0.58 |
| Action Mailer | 1.01 | 1.09 | 1.02 | 1.25 | 1.06 |
| Railties selection | 0.88 | 0.86 | 0.95 | 1.08 | 0.90 |

## Round 2: real AR fast-path coverage

The correctness fix landed first, separately:
[`9020e7a`](https://github.com/thomasklemm/lowrail/commit/9020e7a19ea5de9705f916e6b51add4e6c770831).
A SQL reader could reuse SQL after a connection's `@visitor` was replaced.
It now certifies the actual visitor hierarchy/class and pins a cached statement
to its visitor object; a swap falls back without lazy re-certification.
Fresh SQLite, PostgreSQL and AV gates passed before lifting coverage refusals.
Seven identity mutations × three passes gave **21 identical exact row/query
comparisons** after the fix; before it, the reader visitor-swap case had two
strict shadow mismatches. Preload and instantiate were unaffected in those
cases. See the [identity audit](ar-equivalence.md#connection-identity-audit-2026-10-20-round-2)
for adapter, pool, role/shard and prepared-statement boundaries.

Two narrowly scoped builder changes follow that fix:

* **Reader:** use the real `Module#name` and omit actual `::Minitest::Test`
  subclasses from the Arel implementation inventory. Spec-generated test
  classes are not planners. Do **not** trust Rails' entire test directory:
  `Arel::FakeCrudder < Arel::SelectManager` and its `FakeEngine` in
  `activerecord/test/cases/arel/crud_test.rb` are real custom implementations,
  not Minitest subclasses. They still refuse all 94 otherwise eligible readers
  in the full AR load. An isolated, unmodified association test obtains a hit
  without these unrelated implementations loaded. The full association file
  still has **0 hits / 5 fallbacks**: diagnostics identify method stubs/restored
  aliases (`Relation#size` and `#destroy_all`) against the pinned originals.
  Their guards remain unchanged; a hit in isolation is not full-file coverage.
* **Preload:** refuse edges whose owner/target public name does not resolve to
  that exact class. The old inventory admitted generated HABTM join models:
  **546 unresolvable method facts / 42 receiver names** poisoned the shared
  unit. The new ledger refuses **144 noncanonical edges** before collecting
  their facts. Ordinary canonical edges retain all existing method, schema,
  scope and scheduling guards; HABTM itself stays on Rails. This is filtering
  unsupported edges, not dropping failed facts from accepted edges.

Regression scenarios compare asymmetric owners/results, exact events and live
mutations. The reader scenario includes an Arel-namespaced test class with the
Lowrail Minitest reporter loaded (avoiding a `Lowrail::Minitest` namespace
collision), and still rejects replacement nodes/custom planners. The preload
scenario combines ordinary completed preloads with a real two-owner HABTM
fallback, so disabling the entire unit or mixing up owners cannot pass.
Preload now counts every original-path `Preloader#call` fallback, including
unsupported shapes; old totals omitted these calls and are not comparable.

### After gates: counts are per pass, not summed coverage

Every row runs separate off-build, off, off-repeat and **L1/L2/L3** processes,
seed 41231, against unmodified Rails v8.1.4 sources. All outcomes are identical
and all strict shadow mismatch lists are empty. `H/F` means completed hits /
counted original-path fallbacks; `—` means no unit, not a passing specialization.

| Workload | Identical observations in each layer | Instantiate H/F | Reader H/F | Preload H/F |
|---|---:|---:|---:|---:|
| Full AR / SQLite | 9,240 | 68,857 / 11,616 | — | **2 / 650** |
| Full AR / PostgreSQL 15 | 10,186 | 67,744 / 13,439 | — | **1 / 652** |
| AV / AR integration | 173 | 118 / 0 | 0 / 0 | **5 / 2** |
| `has_many_associations_test.rb`, full file | 320 | 180 / 665 | 0 / 5 | 0 / 13 |
| Same file, `test_has_many_build_with_options` | 1 | 2 / 0 | **1 / 0** | 0 / 0 |

The other two AV groups remain **2,747 + 242 identical**, with no units.
SQLite's 68,857/11,616 and AV's 118/0 instantiation refactor controls are
unchanged; the final PostgreSQL instantiation control also matches exactly.
Earlier exploratory cohorts had different preload counts (15 SQLite / 5 PG);
they are not the final source-certified snapshot and are not added to these
numbers. There is no new framework pass or speed claim.

Evidence directories: `.lowrail/round2-certified-sqlite/`,
`.lowrail/round2-certified-postgresql/`, `.lowrail/round2-certified-reader/`,
`.lowrail/round2-reader-focused/`. Their runtime fingerprint is
`b66ee1bbd19c44aa1a2df0b25e856b8f9c8b386f4294f157173cfac2ad9bf8df`;
`environment.json` records the dirty-tree runtime hash as well as Git HEAD.
Each `summary.json` now includes **every unit's pass/target/H/F, including
zeros**. Raw `.build.json` ledgers and `.shadow.json` checks are retained.

### Complete full-AR refusal census

Counts are ledger entries, not calls; the first applicable refusal wins.
SQLite and PostgreSQL differ only where shown. No listed unsupported boundary
is lifted just to obtain hits.

| Reader reason | SQLite | PostgreSQL | Why retained |
|---|---:|---:|---|
| No scope | 2,524 | 2,529 | Rails already caches these readers |
| Dynamic/unsupported scope operations | 494 | 494 | Live values/operations must execute |
| STI target | 116 | 116 | Runtime target predicates/identity |
| Custom planning implementation | 94 | 94 | FakeCrudder/FakeEngine are outside library certificate |
| Through association | 71 | 71 | Unmodeled join/chain semantics |
| Default scope | 53 | 53 | Live scope assembly |
| Owner-dependent scope | 34 | 34 | Per-owner evaluation |
| Association extensions | 5 | 5 | Custom reader behavior |
| Not one fixed query chain | 5 | 5 | Unsupported scope structure |
| Unknown column/alias | 4 | 4 | No exact bind/column model |
| Polymorphic belongs_to | 2 | 2 | Runtime target selection |
| Model unavailable (`NameError`) | 1 | 1 | OverridingAssociationsTest's unavailable HABTM constant |

| Preload outcome/reason | SQLite | PostgreSQL | Why retained |
|---|---:|---:|---|
| Eligible, tree checked at runtime | 714 | 718 | Not a promise every call can specialize |
| Through association | 1,074 | 1,074 | Unmodeled intermediate loaders |
| Non-certified scope | 617 | 617 | Arbitrary app closures are live |
| STI target | 367 | 367 | Runtime class/reflection selection |
| Default scope | 204 | 204 | Live scope assembly |
| Noncanonical model name | 144 | 144 | Exact constant identity cannot be represented |
| `NotImplementedError` | 106 | 106 | Abstract/unsupported reflection metadata |
| Polymorphic belongs_to | 64 | 65 | Runtime target selection |
| Composite key | 61 | 61 | Unmodeled key shape |
| Owner-dependent scope | 29 | 29 | Per-owner evaluation |
| Deprecated association | 9 | 9 | Preserve notification behavior |
| `NoMethodError` | 6 | 6 | Unavailable reflection metadata |
| `NameError` | 4 | 4 | Unavailable target metadata |
| Abstract target | 3 | 3 | Not an instantiable target |
| Model unavailable (`NameError`) | 1 | 1 | Same unavailable HABTM constant |

Previously the SQLite preload ledger admitted 786 edges, refused 434 as STI
and 209 for default scope. The new early noncanonical check moves 72 eligible,
67 STI and 5 default-scope edges to the explicit 144-edge refusal. This
reclassification is visible, not suppressed diagnostics. Full reader counts
are unchanged; their custom-source reason now names `crud_test.rb` instead of
Minitest's `spec.rb`.

Fresh AR-only corpus builds/verifies also retain **742 identical outcomes**
and **16,193 identical ordered same-thread queries**: blog 21/125, Campfire
634/15,108 (two matching skips), PingCRM 1/4, Redprints 50/692, starter 36/264.
All three AR passes were selected, other passes excluded. Campfire reader
coverage remains **677 H / 367 F**; blog has one completed preload and one
preload fallback. PingCRM's one unit test has zero hits; its browser matrix
was not rerun for this coverage change and is not claimed here.

### Optional integrations exercised

With local Redis, Active Support L1/L2/L3 retains **5,814/5,815 raw identical
observations**, zero reproducible differences and zero failures/errors. The
same anonymous printed identity is excluded after controls. Matching skips
fall from **1,068 to 397**: **671 additional tests exercised**, not additional
test identities. Evidence: `.lowrail/round2-support-redis/`.
Memcached is still absent. The full isolated Railties application/generator
matrix and external Active Job adapters remain unrun; the bounded Round 1
Railties/inline-AJ results are not promoted to those integrations.

## Running

From the Lowrail checkout, with native build prerequisites and the `sqlite3`
CLI installed:

```sh
mise install
mise exec -- script/rails-suite --prepare
mise exec -- script/rails-suite --profile
```

The runner clones a disposable `.corpus/rails` checkout if absent, verifies
the exact tag commit and refuses modified tracked Rails sources. `--prepare`
installs an isolated component test bundle with Rails components from that
checkout; it does not modify Rails' Gemfile or pretend installed Rails gems
are the tested implementation. `bench/rails_suite.lock` pins the component
test dependencies (including Minitest 6.0.6, sqlite3 2.10.1, pg 1.7.0 and
StackProf 0.2.28); preparation substitutes the checkout path and installs
with Bundler's frozen mode. Retain the generated lock with the evidence.

Options: `--checkout DIR`, `--out DIR`, `--suites activesupport,activerecord`,
`--layers L1,L2,L3`, `--seed 41231`, `--profile`. Use a new output directory
for a new cohort, and prepare that directory first. It refuses to overwrite
outcome files. Arguments after `--` select component-relative test files and
Minitest options; this is also the isolated-reproduction interface:

```sh
mise exec -- script/rails-suite --out .lowrail/rails-view-repro --prepare
mise exec -- script/rails-suite --out .lowrail/rails-view-repro \
  --suites activerecord -- test/cases/view_test.rb
```

Each fresh process uses `RUBYOPT=-I<lowrail>/gem/lib -rlowrail/setup`, the
existing `LOWRAIL_OUTCOMES` reporter, `PARALLEL_WORKERS=1`, `MT_CPU=1` and
the same seed. SQL tracing is disabled for this **outcome** gate; exact AR
planning checks use `LOWRAIL_SHADOW=strict` in L3. This does not replace the
ordered SQL and bind gates in [ar-equivalence.md](ar-equivalence.md).

### Layers

- **Off:** setup/reporter loaded with `LOWRAIL=0`, no plan construction or
  runtime activation. Run twice for every group, not only after a failure.
- **L1:** `LOWRAIL=1`, guaranteed empty build root (no manifest).
- **L2:** the runner synthesizes compatible units with an absent receiver
  constant and real, frequently redefined method names. It verifies every
  guard returns false. Stale entries for framework Ruby sources and fixture
  ERB templates install the actual loader/template seams but cannot serve
  lowered code. AR epoch hooks are requested before test models load.
  The 17 synthetic guard fallbacks are **probe counts**, not pass coverage.
- **L3:** build the existing instantiate, SQL-reader and preload passes
  against the models loaded by that test group, in a **separate off process**.
  Its manifest is then loaded through the real setup path before the on
  suite loads. Activate variants after the models exist (component suites
  need not initialize a Rails application). No invented models, loosened
  guards or additional pass are used. Groups without eligible AR models
  have no L3 coverage, even if their outcomes match.

Action View runs template, Action Pack integration and AR integration tests
in separate processes, matching its upstream rake tasks. AR selects the
upstream general cases and the selected adapter cases, excluding encryption
performance benchmarks and other adapters. Active Job uses the inline
adapter, excluding async/delayed-job-only files as upstream does for inline;
external queue-server integrations are not covered. `--suites railties`
runs every Railties file separately; a bounded selection after `--` is faster.
The full Railties application/generator matrix is not claimed by the table.

The measured Railties selection is reproducible as:

```sh
mise exec -- script/rails-suite --out .lowrail/rails-railties-core --prepare
mise exec -- script/rails-suite --out .lowrail/rails-railties-core \
  --suites railties -- \
  test/app_loader_test.rb test/backtrace_cleaner_test.rb \
  test/code_statistics_calculator_test.rb test/code_statistics_test.rb \
  test/initializable_test.rb test/paths_test.rb test/rack_logger_test.rb \
  test/rack_silence_request_test.rb test/rails_health_controller_test.rb \
  test/rails_info_test.rb test/version_test.rb
```

### PostgreSQL

Use only a **disposable local test server/databases**. Rails' adapter tests
create/drop tables and databases and need corresponding permissions. Do not
point this at an application or production database. Start the server using
your environment's service manager, create `lowrail_rails_arunit` and
`lowrail_rails_arunit2`, then save this outside Git as `/tmp/rails-pg.yml`:

```yaml
connections:
  postgresql:
    arunit:
      database: lowrail_rails_arunit
      min_messages: warning
    arunit2:
      database: lowrail_rails_arunit2
      min_messages: warning
    arunit_without_prepared_statements:
      database: lowrail_rails_arunit
      min_messages: warning
      prepared_statements: false
```

```sh
mise exec -- script/rails-suite --checkout .corpus/rails-pg \
  --out .lowrail/rails-postgresql --prepare
ARCONN=postgresql ARCONFIG=/tmp/rails-pg.yml mise exec -- script/rails-suite \
  --checkout .corpus/rails-pg --out .lowrail/rails-postgresql \
  --suites activerecord --profile
```

Local socket authentication uses the current role; supply ordinary libpq
connection settings privately if necessary. The separate checkout prevents
fixture-file races with concurrent SQLite runs. The measured server is
PostgreSQL 15; adapter tests cover prepared and unprepared cases selected by
Rails, not every PostgreSQL/server configuration.

### Evidence and failure handling

`.lowrail/rails-suite/` contains `summary.json` (timings, commands, exit
codes, comparisons, hits/fallbacks), `environment.json` (Ruby/Rails/Lowrail
and source fingerprint), the bundle lock, manifests, build/refusal ledgers,
per-process outcomes, duplicate-safe `.shadow.json` observations, loaded-file
markers, full logs and optional `.stackprof` profiles. Incomplete test-file
loading is a failed gate even if Minitest's exit handler ran a partial suite.
Nonzero suite exits remain in the report; matching baseline failures are
not represented as a green Rails suite (an equivalence exit of zero alone
does not mean Rails passes). Nonempty reproducible differences, differing
exit codes, shadow mismatches or missing/empty outcomes fail the gate.

The executed cohorts are `.lowrail/rails-final` (AS, AM, SQLite AR, Mailer),
`.lowrail/rails-view` (AP and all AV groups), `.lowrail/rails-locked` (AJ),
`.lowrail/rails-railties` (bounded selection) and `.lowrail/rails-pg`.
Earlier AP/AV/AJ attempts in `rails-final` lacked test dependencies and are
**incomplete**, not passing gates; the table uses the completed cohorts.
The final pinned bundle includes those dependencies. Raw profiles/absolute
local evidence paths are not committed as portable source artifacts.

The existing AR comparator remains available:

```sh
mise exec -- ruby bench/ar_rails_suite.rb --compare OFF.json ON.json
# Symmetric controls, preserving colliding printed identities/multiplicities:
mise exec -- ruby bench/ar_rails_suite.rb --compare \
  OFF.json ON.json OFF-REPEAT.json ON-REPEAT.json
```

For a difference, use the report's identity and `.shadow.json` source location
to select its file and `--name`; run the same four processes. Isolation that
loses a difference is not a minimal repro: retain the original seeded group
and its preceding tests instead. The runner does not automatically claim
history-dependent failures have a standalone one-test reproducer.

## Flakiness controls

The comparator compares multisets of observations for each identity, not
totals or an identity hash that drops duplicates. A stable off/off identity
gates only differences that remain identical across two on runs. Raw
differences, off-unstable and on-transient identities remain separate in
JSON. No allowlist suppresses a genuine outcome change.

- **Active Support:** `DuplicableTest` interpolates an anonymous Class's
  address into one test name. Off/off differs in that identity, despite all
  results passing. Reproduce with `test/core_ext/object/duplicable_test.rb`.
- **Active Job:** `ArgumentSerializationTest` interpolates `10.days.ago`,
  `10.hours.ago..Time.current` and a DateTime range into three test names at
  file load. Reproduce with `test/cases/argument_serialization_test.rb` in
  off processes separated by at least a second. Controls and repeat runs
  are separated by 1.1 seconds, so subsecond suites cannot accidentally
  appear stable at whole-second precision.

## Correction to the earlier AR experiment

The old [d9fd466 worker](https://github.com/thomasklemm/lowrail/commit/d9fd466afac5de38c30ecb5d4b56f475ed4dd840)
built plans in **both test processes**, including
`LOWRAIL=0`. That forced schema/attribute materialization and made the
view-primary-key failure appear to be a Rails baseline failure. A genuinely
unmodified off process has **9240 runs, zero failures** on this pin. A focused
old-style **off + build** run of `view_test.rb` fails two primary-key tests;
the new separate-build off/on runs pass **17/17** with instantiation hits.
This is a harness correction, not evidence that a runtime guard should be
relaxed or that Rails' test should be changed.

No runtime outcome defect was found in the Round 1 inputs. The held base-runtime,
guard, loader, stats and template files are unchanged; no experimental fixes
branch is needed. The separate-build regression fails on the old worker.
Profiling also initially added wrapper frames that failed two Rails
backtrace-cleaner assertions. Starting StackProf before autorun and stopping
after it removes those frames; the old-wrapper fault control fails exactly
those two tests, and all final off-profile processes pass. These fixes are
in the harness, not Rails or Lowrail's runtime.

## Hot framework methods

StackProf wall sampling, 1 ms, Lowrail off; dependency loading and plan
construction are outside the captured interval. Aggregate with:

```sh
mise exec -- ruby bench/rails_suite_profiles.rb \
  .lowrail/rails-suite/*-off-profile.json.stackprof > /tmp/rails-profiles.json
```

For multiple adapter cohorts, give captures distinct basenames (e.g.
`activerecord-postgresql-off-profile.json.stackprof`); duplicate labels are
rejected rather than silently overwriting a profile. The aggregator groups
by framework-relative **file + method**, unions recursive occurrences within
each raw stack, and reports inclusive percentages plus self samples. It
uses raw-stack weights as denominators and equal capture weighting for the
mean, retaining AV's three groups and the two AR adapters separately.

The exact-method intersection with [candidates.md](candidates.md), in order,
is `ActiveSupport::Callbacks#run_callbacks`,
`ActionView::LookupContext::ViewPaths#find`, `ActionView::PathSet#find`, and
`ActionView::Helpers::TagHelper::TagBuilder#tag_options`:

| Method (framework file) | Mean inclusive % across 11 captures | Representative suite inclusive % | App-profile intersection |
|---|---:|---|---|
| `Callbacks#run_callbacks` (`activesupport/lib/active_support/callbacks.rb`) | 22.50 | AR SQLite 29.16; PG 13.35; AM 5.50; AP 8.08; Mailer 57.20 | All five apps; empty-chain saving <0.006%, not the inclusive body |
| `LookupContext::ViewPaths#find` (`actionview/lib/action_view/lookup_context.rb`) | 1.05 | AV template 7.24; AP 1.04 | Blog, uncached Campfire, PingCRM HTML, Redprints HTML; combined lookup budget 0.40–1.36% |
| `PathSet#find` (`actionview/lib/action_view/path_set.rb`) | 0.95 | AV template 6.73; AP 0.96 | Same joint lookup category; do not add it to its parent |
| `TagBuilder#tag_options` (`actionview/lib/action_view/helpers/tag_helper.rb`) | 0.12 | AV template 1.29; AP 0.06 | All five HTML profiles, 0.68–5.14% inclusive |

The app document's lookup and tag budgets, and its warning that callback
inclusive time wraps the action body, remain the controlling production evidence. `find_all`
is not the priced `find`; Inertia, Alba and Jbuilder methods are not Rails;
the app document's broad Arel category does not identify an exact method.

Suite profiles are candidate discovery only: test scaffolding, assertions,
deliberate cold paths, database IO and process startup do not describe
production request costs. AS's roughly 50-second capture has only 2,690
raw-stack samples and 46,582 missed samples; treat the missing time as
unattributed, not as a measured optimization opportunity. Short AJ/Railties captures are especially
noisy. Inclusive parent/child percentages must not be added or treated as
removable work. No framework pass or speed claim follows from this list.

## Round 2: callbacks are parked, not a 22.5% app opportunity

The corpus census uses `bench/callback_survey.rb` with Lowrail **absent**,
actual YJIT enabled, 400 warmups and 20 observed production requests per route.
A targeted TracePoint observes the original `run_callbacks` ISeq, not a wrapper.
It records receiver, kind, optional type, effective filters, conditions,
around filters and terminator. Categories are **per call**, not numbers of
classes or filters; condition-free does not mean callback bodies are static.
Symbol-only conditions would still have to execute on every call.

| Corpus route | Calls/request | Empty | Condition-free | Symbol-only conditions | Dynamic conditions |
|---|---:|---:|---:|---:|---:|
| Blog index / edit | 4 | 1 | 2 | 0 | 1 |
| Campfire cached room / uncached room / stream | 6 | 2 | 3 | 0 | 1 |
| PingCRM organizations HTML / JSON | 5 | 2 | 3 | 0 | 0 |
| Redprints proposals HTML / JSON | 7 | 3 | 3 | 0 | 1 |
| Starter dashboard HTML / JSON | 6 | 3 | 3 | 0 | 0 |

Every request runs executor `run`/`complete` (condition-free) and
`ActionDispatch::Callbacks#call` (empty). Current-attribute resets contribute
the extra empty chains. Campfire `Session#initialize` and Redprints
`User#initialize` each add one condition-free chain. Controllers contribute
the remaining call: Blog/Campfire/Redprints have dynamic action conditions
and around callbacks; Starter is condition-free **but has an around callback**.
Only PingCRM's controller chain belongs to the proposed no-around subset.
There are no nonempty symbol-condition-only chains in these app requests.

Separate Lowrail-off Rails-suite censuses cover many more chains:

| Suite | Calls | Empty | Condition-free | Symbol-only | Dynamic |
|---|---:|---:|---:|---:|---:|
| AR / SQLite | 82,719 | 48,203 | 14,250 | 1,258 | 19,008 |
| Active Model | 4,548 | 1,923 | 2,531 | 15 | 79 |
| Active Support, original services | 11,376 | 9,079 | 2,262 | 3 | 32 |
| Action Pack | 11,009 | 7,563 | 2,560 | 2 | 884 |
| Action View template group | 5,530 | 2,725 | 2,805 | 0 | 0 |
| Active Job inline | 812 | 341 | 471 | 0 | 0 |
| Action Mailer | 1,005 | 462 | 543 | 0 | 0 |

These are workload observations, not stable global chain counts. Run with
`script/rails-suite --callbacks` to write a separate `off-callbacks` process
and `.callbacks.json`; the untimed census is outside performance windows.
Rails tests exercise replacements and type-selected chains, including empty
Array chains. The survey regression checks those selected-filter boundaries
and that a user kind object's `to_sym` executes only once.

### The removable budget, not the inclusive body

Fresh off profiles of the same eleven production routes use
`bench/requests.rb`, wall sampling at 100 µs, raw stacks and actual YJIT.
Boot and census instrumentation are outside the capture. Weight each raw
stack once; callback machinery is a leaf Ruby frame in
`active_support/callbacks.rb`, including native work beneath that Ruby frame,
not arbitrary descendants inside the action or a callback body. Use the
nearest external caller of `run_callbacks` to distinguish executor, reset,
middleware, model initialization and controller chains. The census determines
which callers have eligible no-around empty/condition-free/symbol chains.

| Route | All callback machinery % | Eligible no-around machinery % |
|---|---:|---:|
| Blog index | 1.285 | 0.605 |
| Blog edit | 2.031 | 0.902 |
| Campfire cached room | 1.587 | 0.574 |
| Campfire uncached room | 0.434 | 0.141 |
| Campfire stream | 0.663 | 0.196 |
| PingCRM HTML | 0.973 | 0.973 |
| PingCRM JSON | 0.975 | 0.975 |
| Redprints HTML | 1.428 | 0.648 |
| Redprints JSON | 1.886 | 0.897 |
| Starter HTML | 0.849 | 0.347 |
| Starter JSON | 2.177 | 0.896 |

`run_callbacks` **self alone** is 0.075–0.460%; that is not the full dispatch
budget. Its inclusive share is 69.90–92.36% here because it encloses the
action. Neither that number nor the Rails-suite 22.5% is removable machinery.
Even deleting *all* eligible machinery in these captures is below 1% on
every route; a real guarded specialization can remove only part of it.
These are sampled opportunity bounds, not controlled speedup measurements
or statistical proofs of a universal ceiling.

Rails **already caches** `CallbackChain#compile(type)` (`@all_callbacks` and
`@single_callbacks`), including a direct no-around path. Chain mutations
invalidate those caches; recompiling once per class is not new work to remove.
CallTemplate already selects specialized method/proc/object invocation forms.
Current Rails main goes further in
[PR59094](https://github.com/rails/rails/pull/59094),
[`7a2033c`](https://github.com/rails/rails/commit/7a2033c9b88b4eb4ff5c50fcc2bf68b5d50c70e4):
`call_direct` removes the per-before-callback lambda for known terminators,
while preserving custom terminators' old interface. Do not duplicate that
upstream improvement as a Lowrail pass.

**Decision:** no runtime callback pass and no further unroll experiments in
this round. Park it as a possible stacking item, not a ≥2% standalone win.
Earlier synthetic shared fixed-heap Callgrind trials are not app predictions:
empty/one-after cases regressed about 16–17%; four/five-before cases saved only
0.66/1.08% **per synthetic call**, and mixed/symbol cases failed A/A controls.
Those failures remain retained; the disposable prototype was removed. No
native-YJIT µs was converted into interpreter instructions. A future experiment
needs the shared bench activation/operation adapter, all independent A/A and
heap controls, genuine completed hits and route-level validation.

Evidence: `.lowrail/round2-callback-survey/` contains the chain censuses and
logs, including failed initial instrumentation attempts and corrected runs;
`.lowrail/round2-callback-profiles/` contains all eleven raw JSON profiles,
secondary timing output and the self/inclusive/all-machinery analysis.
Synthetic trial evidence remains under `.lowrail/round2-callback-*`.

## Round 2 validation

`mise exec -- cargo test --locked`: **31 unit + 3 integration tests pass**.
Full gem suite: **90 tests / 1,577 assertions**, zero failures/errors, four
optional skips. All `bench/*_test.rb`: **21 tests / 165 assertions**, zero
failures/errors/skips, including the callback census regression. The retained
reader/preload regression scenarios fail on the unchanged builders (reader
source refusal and zero completed preloads), then pass with these changes.
No native-YJIT request speedup is claimed.

Reproduce the genuine reader case without changing any Rails test source:

```sh
mise exec -- script/rails-suite --suites activerecord --out .lowrail/reader-new --prepare
mise exec -- script/rails-suite --suites activerecord --out .lowrail/reader-new -- \
  test/cases/associations/has_many_associations_test.rb --name test_has_many_build_with_options
```

## Round 1 runner regression checks

```sh
mise exec -- ruby -Igem/lib gem/test/rails_suite_report_test.rb
mise exec -- ruby -Igem/lib:gem/test \
  -e 'Dir["gem/test/*_test.rb"].sort.each { require_relative _1 }'
```

Targeted: **3 tests, 17 assertions, no failures/errors/skips**; full gem
suite: **87 tests, 930 assertions, no failures/errors, 14 optional skips**.
The two checkout-backed regressions require the prepared Rails checkout;
the profiler regression also uses the default `.lowrail/rails-suite/Gemfile`.
Fresh pinned-runner view smoke: **17/17** in L1/L2/L3 and its off profile,
with one L3 instantiation hit and zero shadow mismatches. No Rust source
changed; this is runner/reporting work, not a new pass.
