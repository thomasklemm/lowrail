# Rails' own suites as a Lowrail gate

2026-10-20; Rails **v8.1.4**, source commit
[`c3466ea`](https://github.com/rails/rails/commit/c3466ea00d7121798e3aa3144ffdf7174b81d8cb),
Ruby **4.0.7** (the runner requires Ruby 3.4+), seed **41231**. This is a
compatibility gate, not a speed benchmark or a universal support certificate.
It complements app `lowrail verify` gates before broadening PLAN §7 decision 2
to framework/gem specialization. No new framework pass is implemented here.
The measured runtime is main at
[`d9fd466`](https://github.com/thomasklemm/lowrail/commit/d9fd466afac5de38c30ecb5d4b56f475ed4dd840);
later benchmark/report-only main commits do not change those runtime files.

## Compatibility table

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

### L3 coverage and refusal boundaries

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

No runtime outcome defect was found in these layers. The held base-runtime,
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

## Runner regression checks

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
