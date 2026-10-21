# Gem-breadth compatibility corpus — 2026-10-20

The latest [blog/Fizzy own-suite contract check](#own-suite-product-contract-recheck--2026-10-21)
compares every test identity, including blog's browser suite, and separates
default no-op compatibility from refused sealed artifacts.

This is a compatibility experiment, **not** a claim that every Rails app or
every listed gem is supported. Four real app pins extend `script/corpus`;
three have green upgraded baselines; Fizzy is a useful negative control. The
exercise found genuine Lowrail load-order bugs. Hook-free delivery now fixes
require-hooks adapter selection; Bundlebun's integration order still needs a
targeted delivery/activation refusal. Redprints passes strict verify only as
a no-op. Its historical 277-hit target is obsolete after quarantine; the
current eligible ceiling is **14 `inertia/props` hits**, still refused.

All new app copies use **Ruby 4.0.7 and Rails 8.1.4**. Ruby 3.4 was dropped by
owner decision; the loader regression matrix also exercises 4.1-preview,
not these four app suites.
Only `.ruby-version`, `Gemfile` and `Gemfile.lock` change, through checked-in
`fixtures/corpus/*.patch`. No app/gem implementation or test is patched, no
upstream repository is modified, and no app failures are suppressed.

## Pins and dependency breadth

| App / pinned upstream commit | Original Rails / Ruby | Gems present in the tested lockfile |
|---|---|---|
| [CASA](https://github.com/rubyforgood/casa/commit/b584d2e6e6ebffe382f34c2ec202d20384d035ca) | 8.1.3.1 / 4.0.6 | Devise 5.0.4, Pundit 2.5.2, ViewComponent 4.15.0, Pagy 9.4.0, FriendlyId 5.7.0, Turbo 2.0.23, Stimulus 1.3.4, Active Storage, RSpec Rails 8.0.4, FactoryBot 6.5.6 |
| [Writebook](https://github.com/basecamp/writebook/commit/be1f8fcf1b0fc8064011c2d29d75133885b182e2) | 8.0.0.beta1 (git) / 3.4.7 | Turbo 2.0.11, Stimulus 1.3.4, Active Storage, Resque 2.6.0, image_processing 1.14.0, Minitest, Capybara/Selenium |
| [Fizzy](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9) | 8.1.0.alpha (git) / 3.4.1 | Solid Queue 1.1.2, Solid Cache/Cable, Turbo 2.0.11, Stimulus 1.3.4, Active Storage, Bootsnap 1.18.4, Minitest |
| [CodeTriage](https://github.com/codetriage/codetriage/commit/d1868f8634e97a111a7fca49d58cc776d206007e) | 8.1.3.1 / 4.0.5 | Devise 5.0.4, Sidekiq 8.1.7, OmniAuth, Sprockets, will_paginate, Bootsnap 1.25.0, SimpleCov/Minitest |

The lockfile overlays update Rails' components and their required dependency
metadata. Writebook also needs Rack 3.2.7, image_processing 1.14.0 /
mini_magick 5.4.0 and securerandom 0.4.1; Fizzy needs Rack 3.2.7. The complete
resolved changes, including platforms, are in the patches rather than an
unbounded `bundle update`. Assets use the apps' own build commands. CASA's
Node pin is 24.22.0; PostgreSQL and Redis are local disposable services.

**Round-1 gaps:** these first four baselines do not exercise Ransack,
PaperTrail, Kaminari, Sorbet runtime or dry-rb. [Round 2 below](#gem-breadth-round-2--2026-10-21)
adds real apps for all of these except Kaminari, with explicitly bounded
coverage. CanCanCan exists in the original PingCRM corpus, but its one-test
suite records no fast-path hits; presence is not coverage. Sidekiq is present
in CodeTriage and exercised through the app's test adapter, not against a
production worker deployment. Do not turn gem presence into a support claim
for every gem feature.

### Rejected candidates

Human Essentials and Circulate originally pin Ruby 3.4.5. Their disposable
Ruby-version overlays were retried on 4.0.7 **without Lowrail**:

- Human Essentials stops while requiring delayed_job 4.1.13: missing
  `benchmark`, removed from Ruby 4's default gems. No runtime shim is added.
  The earlier 3.4 experiment is diagnostic only, not a supported matrix row.
- Circulate's exact minitest 5.26.0 dependency requires Ruby < 4.0, so the
  unchanged dependency constraint cannot resolve. Drop it, rather than patch
  app/test code to manufacture a green result.
- Newer Fizzy snapshots require private gems or Rails 8.2; the public
  historical pin above is reproducible, but not green on Rails 8.1.4.

## Results

The hit-bearing tables below record the pre-quarantine activation/delivery
cohorts. The subsequent cached-fact quarantine removes memo, digest, AR and
config candidates from guarded `all-opt-in`; those historical hits are not
current support claims. The loader's synthetic matrix still exercises real
lowered delivery independently of pass eligibility. Final integrated checks
are reported separately, without reactivating sealed-only passes in test apps.

Commands use `RAILS_ENV=test`, seed **41231**, one Minitest worker, strict AR
shadow checking through verify, and **`LOWRAIL_VERIFY_LOADS=1`**. First run
the app's own suite with `LOWRAIL=0` and no Lowrail preload. Then collect
facts, build `default`, verify, build `all-opt-in`, verify. Browser suites
are separate so they cannot disappear behind a default exclusion.

"Identical" means equal per-test outcomes and equal ordered own-thread SQL
digests **outside identities unstable in off/off or on/on controls**. Those
identities remain advisory in the report; it does not mean every raw query
in two processes was identical. SQL values/order are not newly normalized
for these apps. Other-thread SQL remains advisory, including browser server
queries. A failed plain baseline is not repaired or called a support gate.

| App / suite | Plain baseline | Default verify (0 units) | All-opt-in verify | All-opt-in hits / fallbacks | Problems / scope |
|---|---|---|---|---|---|
| CASA, non-system | 2,992 examples; 0 failures, 21 pending | delivery recheck: SQL gate rejected on seed spec; outcomes identical, 0 stable load differences | identical, 126,101 queries; 46 advisory identities, 0 stable load differences | 12,920 / 3,645 | 12,820 / 2,733 instantiate; 100 / 912 preload; locale bug fixed; default SQL recheck not green |
| CASA, system | 769 examples; 0 failures | identical; 5 SQL-noisy identities, 0 stable load differences | identical; 62,268 queries, same 5 advisories; 0 stable load differences | 8,121 / 2,621 (instantiate) | Actual headless Chrome/Capybara suite; 8 unstable load entries |
| Writebook, non-system | 119 tests, 381 assertions; all pass | identical, 8,028 queries | identical, 8,028 queries | 2,714 / 0 (instantiate) | 0 stable load differences; 8 unstable load entries |
| Writebook, system | 2 tests, 8 assertions; all pass | identical, 217 queries | identical, 217 queries | 143 / 0 (instantiate) | Chrome, 0 stable load differences; 8 unstable entries |
| Fizzy | 124 tests; 117 pass, 7 errors | identical errors, 5,322 queries | identical errors, 5,322 queries | 1,963 / 51 (instantiate) | App calls nonexistent instance `Current.reset_all`; 0 stable load differences; 26 unstable in all-opt-in |
| CodeTriage | 222 tests, 483 assertions; all pass on a fresh schema-only DB | identical, 2,873 queries; 3 SQL-noisy identities | identical, 2,873 queries; same 3 advisories | 933 / 1 | Instantiate 933 / 0, preload 0 / 1; 0 stable load differences, 24 unstable entries; Label association modeling refusal retained |

Fizzy's `test/system` contains only `.keep` at this pin: no browser coverage
can be claimed. CodeTriage's regular integration tests run in its main suite;
no separate real-browser coverage is claimed for it.
Writebook's browser process enables YJIT itself; those are correctness runs,
not JIT-flat benchmarks or speed claims.

### Delivery-seam recheck

Fresh default/all-opt-in Writebook, Fizzy and CodeTriage verification retains
the outcomes, own-thread SQL and hits/fallbacks above, with zero stable load
differences. Writebook's separate browser cohort also retains 2 outcomes /
217 queries / 143 hits; default has 10 unstable load entries and all-opt-in 8.
Fizzy's seven pre-existing errors are still a negative control, not support.

CASA's zero-unit default recheck retains all 2,992 outcomes and a clean load
census, but **fails the SQL gate**: the seed example has 6,092 off versus
6,094 on queries, with 46 other SQL identities advisory. Keep that rejected
cohort rather than excluding the example or retrying until green. Six
isolated **off-only** seed-example runs also vary (6,534/6,531 queries and
three distinct digests); this establishes noise in the same example, not
the precise cause of the original two-query discrepancy. The app's seed
populator contains unseeded `sample`/`rand` calls despite its separate Faker
seed. The separately scheduled all-opt-in cohort passes with 126,101 queries,
46 advisory identities and the unchanged 12,920 / 3,645 hits/fallbacks; it
does not erase the default failure. No app/test/RNG workaround or SQL
normalization was added. The full requested unchanged-app gate cannot be
called green from this cohort.

### Integrated main recheck (2026-10-21)

Hook-free delivery was integrated after the six additional sealed-only flags,
the TracePoint activation/delivery fix, identity-keyed replacement tracking
and binary checks, format 2 and the `LOWRAIL_DIR` harness boundary. The code
tested here is
[7d0ea95](https://github.com/thomasklemm/lowrail/commit/7d0ea95dfd5b5c57e2bc1bb1cc226f9f78a94354),
based on
[cb83265](https://github.com/thomasklemm/lowrail/commit/cb832658d52e0a9f440d51ccac7dd985ceb09f2a).
The final rebase also includes upstream docs and the separate sealed-form
experiment through
[71a0ae9](https://github.com/thomasklemm/lowrail/commit/71a0ae9);
the tested gem, Rust, script and fixture contents are unchanged. Cargo and
the affected gem checks are rerun after that rebase; no measured cohorts run.
These are fresh `all-opt-in` builds, **not** reactivation of the historical
sealed-only hit maps above. Outcomes are identical per test; the table keeps
baseline skips/errors and SQL/load advisories explicit.

| App / suite | Outcomes in each mode | SQL traces | Load differences / unstable entries | Hits / fallbacks |
|---|---|---|---|---|
| Real Blog | 21 pass | 125, identical | 0 / 0 | 0 / 0 |
| Campfire | 632 pass, 2 skip | 15,109, identical | 0 / 0 | 0 / 0 |
| PingCRM | 1 pass | 4, identical | 0 / 0 | 0 / 0 |
| Redprints CFP | 50 pass | 692, identical | 0 / 32 | 0 / 0; Bundlebun refused |
| React Starter Kit | 36 pass | 264, identical | 0 / 8 | 30 / 0 (`inertia/props`, unit 0) |
| CASA, non-system | 2,971 pass, 21 pending | 126,101; 46 noisy identities advisory | 0 / 8 | 0 / 0 |
| CASA, system | 769 pass | 62,268; 5 noisy identities advisory | 0 / 8 | 0 / 0 |
| Writebook, non-system | 119 pass | 8,028, identical | 0 / 8 | 0 / 0 |
| Writebook, system | 2 pass | 217, identical | 0 / 8 | 0 / 0 |
| Fizzy | 117 pass, 7 errors | 5,322, identical | 0 / 8 | 0 / 0 |
| CodeTriage | 222 pass | 2,871 each; 2 noisy identities and 1 further difference advisory | 0 / 24 | 0 / 0 |

The CASA browser result above uses `TEST_ENV_NUMBER=100` (port 7754) and a
separate database/copy. Two earlier attempts overlapped on the app's fixed
port 7654 and are **invalid**, including the frozen run owning that listener:
the fresh copy was stopped in its first off run; the frozen browser report
has 5 outcome differences (1 off failure, 4 on failures). Neither is evidence
about the loader. Their logs, frozen JSON, inspected sign-in redirect capture
and reason are retained in the thread's `loader-port-collision` artifacts.
The same failed off example passes with the port offset; the full rerun and
both repeat controls pass all 769 examples. No app/test patch was needed.

CodeTriage's forked parse-docs child makes verify's process count two despite
`PARALLEL_WORKERS=1`. The further SQL advisory is
`UserMailerTest#test_sends_issues`: 22 queries in each mode, with different
cached/noncached query order. Four finite **off-only** full-suite controls
reproduce both exact digests (three of one, one of the other), with all 222
tests passing. This establishes off-only variation, not its precise cause.
No SQL suppression or normalization was added, and the multi-process report
is not represented as a strict single-process SQL gate. The earlier rejected
CASA default cohort remains rejected; this later scheduled integration run
does not erase it. Fizzy's seven baseline errors remain a negative control.

For Fizzy, the archived **all-opt-in** levers sweep on
[4eb7b58](https://github.com/thomasklemm/lowrail/commit/4eb7b58) reported **18
stable / 8 unstable** load differences (default: **0 / 8**), already with all
seven sealed-only flags and an empty format-1 artifact. Our frozen integration
based on [ed7cbbe](https://github.com/thomasklemm/lowrail/commit/ed7cbbe) and the
cb83265-based run above were both **all-opt-in**, not default: **0 / 8**, empty
format-2 artifacts and zero hits. On
[b091cb7](https://github.com/thomasklemm/lowrail/commit/b091cb7206a0bc877a9eef9a0201ec95f85c7a2a),
default is **18 / 8** and all-opt-in **0 / 26**; those 26 unstable entries
include the same 18 event identities. The format-2 manifests are identical
across these selections. A fresh default run on
[4a33992](https://github.com/thomasklemm/lowrail/commit/4a33992bd78c343e04764619781ce4008d608d94)
is again **0 / 8**, with gem/Rust contents unchanged from b091cb7. These are
not evidence of a selection, quarantine or delivery-seam fix: the bounded
off/off investigation below reproduces all 18 as app nondeterminism.

The integrated full gem suite passes **138 tests / 6,199 assertions**, with
no failures/errors/skips, including cold sealed delivery, `exit_trace_leave`,
replacement identity, binary tampering, wrong-root refusal and relocation.
Cargo passes **39 tests** (35 unit, 1 CLI and 3 verify integration); release
build passes. Both Ruby loader matrices pass without skips: **13 / 2,047**
on 4.0.7 and **13 / 1,460** on 4.1-preview. These are correctness checks, not
measured performance cohorts or a renewed claim for zero-hit passes.

### Facts and build cost

Wall seconds, single observations in the shared orb (not a performance study).
Facts boot excludes eager loading and dumping, shown separately. Build
includes planning/materialization and compilation where applicable. Default
builds still write their refusal ledger even though they lower nothing.

| App | Facts boot | Eager load | Dump | Default build wall | All-opt-in build wall |
|---|---:|---:|---:|---:|---:|
| CASA | 3.65 | 1.22 | 2.16 | 6.25 | 12.33 |
| Writebook | 2.15 | 0.44 | 1.07 | 3.48 | 6.78 |
| Fizzy | 1.06 | 0.57 | 1.20 | 2.56 | 5.57 |
| CodeTriage | 1.85 | 0.15 | 1.96 | 3.03 | 5.69 |

CodeTriage facts retains one modeling error:
`Label association repos klass: NoMethodError: undefined method 'klass' for nil`.
Its app declares `has_many :repos, through: :repo_lables` (misspelled).
It is recorded, not swallowed or converted into an eligible association.
The other three have zero modeling errors (skipped framework/internal
observations remain separately counted).

## What the experiment found

### Fixed Lowrail defects

1. **Pre-Rails setup compilation:** a parser-sensitive `defined?` check in
   a modifier `while` in `preload_facts.rb` raised `SyntaxError` on Ruby 3.4
   before Active Record was loaded. Moving the condition outside the loop
   retains its semantics and makes pre-framework setup loadable. The gem
   regression exercises setup before Rails/Active Record. This independent
   fix is retained even though Ruby 3.4 is no longer a supported target.
2. **Activation before I18n initialization (CASA):** the model evaluates a
   locale-formatted date during class loading. Two off controls returned
   `01/01/1989`; two on controls returned `1989-01-01`. Disabling activation
   removed the failure; selecting instantiate reproduced it. An
   `after_initialize` callback itself can precede Rails' I18n callback.
   Shared activation now waits until `Application#initialize!` has returned,
   rather than forcing model constants from an unfinished framework. The
   regression uses an asymmetric date and an actual locale file, not a
   CASA-specific exception.
3. **Lazy app hook (Fizzy):** instantiate forced
   `ActiveStorage::Attachment` to load, causing the app's `on_load` callback
   to change dependent-destroy behavior and issue two additional SELECTs.
   Instantiate now visits already-loaded models and subscribes to Zeitwerk
   for later loads. It does not eagerly load the remaining models. The gem
   regression verifies late models and hook/SQL behavior.
4. **Other early framework loads:** the new census caught preload activation
   loading `Preloader`/`Association` early; shared fact-receiver activation
   now waits for naturally loaded dependencies. AR epoch installation also
   no longer forces `ActiveRecord::Base`. Guard and plan constant lookups
   refuse unresolved autoloads instead of triggering them. This applies to
   all runtime installers, not two app-specific patches.
5. **Bisection:** disabling a source pass must retain its runtime entry
   points: the delivered original arm still references them. Otherwise the
   digest fixture crashed with `Lowrail::DigestMemo` missing before any
   pass could be diagnosed. The real source-delivery regression and CLI
   regression pass. A no-active-unit probe now separates setup/delivery
   load differences from individual activation effects.

The complete Ruby 4.0.7 gem run after hook-free delivery reports **126 tests,
5,881 assertions, 0 failures/errors/skips**. The loader matrix reports **13
tests, 2,039 assertions** on 4.0.7 and **13 tests, 1,452 assertions** on
4.1-preview, both without failures/errors/skips. `cargo test --all-targets`
passes all **38 tests** (34 unit, 4 integration); the release build also
passes. These are correctness checks, not throughput benchmarks. The first
full gem attempt lacked the fixture's `rails_vite` 0.3.0; installing that
existing dependency fixes it without changing code or assertions.

The final gem run includes the real-blog observation/materialization and
framework-profiler tests that were skipped in the initial 120-test run.
An intermediate fixture setup used a symlink as the observer's app root,
which did not match Ruby's physical source paths; discard that cohort.
Physical disposable copies pass, without changing the observer or tests.

### App/environment noise, not Lowrail fixes

Human Essentials' earlier default build had zero units yet eight apparent
SQL differences. Repeat controls and full traces identified unseeded factory
choices, including `product_drives.rb`'s `[true, false].sample`, which change
conditional query paths. It was not evidence that default lowering changed
the app. That preliminary 3.4 cohort also exposes existing association and
collation-sensitive app behavior. No SQL suppression or app workaround was
added. The optional per-test `Kernel.srand` proposal is **not implemented**:
the app is excluded on Ruby 4, and a suite-order seed is not a certificate
that all application randomness is synchronized. The noisy traces remain
advisory/diagnostic rather than a green support result.

Database authentication mistakes during setup were discarded, not counted
as app or Lowrail failures. In particular, CodeTriage's CI database config
defaults to user `postgres`; a socket DATABASE_URL must explicitly name the
local role, or Rails merges that username back in. CASA's DatabaseCleaner
requires a host-bearing URL. CodeTriage's earlier 222 fixture FK errors came
from development seed rows (`repo_labels.repo_id=2`) left in the test DB;
the fixtures do not clear that seed table. A fresh schema-only database
passes all 222 tests without any app changes. Discard the seeded cohort;
`script/corpus` prepares new test schemas without running development seeds.

### Hook-free delivery; Bundlebun still refused

The previous Redprints cohort had **50 passing examples and 692 identical
queries**, 277 hits / 0 fallbacks, but **26 stable load differences**. Both
require-hooks 0.4.0 and 0.5.1 detect Bootsnap from the top `load_iseq` method's
source path; Lowrail's former wrapper changed the adapter in 2/6 orders.

Build capture and runtime now define no `load_iseq` method. Native MRI
translation, post-serialization Bootsnap output and explicit eval deliver
lowered ISeqs without changing that method's owner, source or method chain.
Both Ruby 4.0.7 and 4.1-preview pass the presence/absence/all-order matrix,
including cold/warm/on/off cache checks and the load census. No gem mode is
forced and no introspection is spoofed.

With that fix alone the historical pre-quarantine build retains its 277 hits,
but **12 stable load differences** remain. Bundlebun enumerates integration
constants unsorted; additional Lowrail runtime identifier interning changes
the autoload order.
Six off and six setup-only fresh boots agree, while six active boots use
another order with the same correct adapter. This is not random suite noise
or a source-pass outcome divergence.

No exact general fix to that sensitivity was established. A known/locked
Bundlebun bundle now refuses delivery and runtime activation before runtime
installers load, with `bundlebun_load_order` in ledger/manifest and the stats
refusal reason. Existing artifacts are caught too. Final strict Redprints
verify: **50 pass, 692 identical queries, 0 stable load differences**, 32
unstable advisory entries, **0 hits / 0 fallbacks**. The current gate is
**14 eligible props hits**, identical outcomes/SQL and unchanged detection/load
behavior; the old seven-unit 277-hit aggregate is obsolete, not permission to
reactivate sealed-only passes. The current gate is **not met**: this is safe
refusal, not active Redprints support.

The bounded follow-up confirms a real Bundlebun boundary, not a synthetic
census mismatch. Compiling one symbol without evaluating it yields eight
stable load-event differences; `$LOADED_FEATURES` independently confirms the
ExecJS/JS order swap. Four processes without Lowrail, census or TracePoint
reproduce it too. Early props delivery has a coincidental census pass
(14 hits, 50 outcomes / 692 queries, zero stable differences), but changes
actual order in direct controls: **non-certifying**. Waiting until Bundlebun
naturally finishes preserves its order but misses the already loaded props
file and yields zero hits. Refusal stays unchanged. No upstream repository or
integration order was patched; the [upstream draft](upstream/bundlebun-integration-order.md)
is local only. [Detection, seams, matrix and bounded controls](loaders.md#refused-bundlebun-integration-enumeration).

## Existing corpus and framework regression gates

All five original apps were rebuilt all-opt-in after the shared activation
change and again after hook-free delivery. Per-unit maps were compared, not
only total hits. The Redprints refusal is an intentional coverage loss.

| App | Outcomes / own-thread SQL | Before → final hits / fallbacks | Explanation |
|---|---|---|---|
| Real Blog | 21 pass / 125 queries identical; 0 load differences | 41 / 2 → 41 / 1 | Preload no longer runs merely to force its framework dependencies; instantiate map unchanged |
| Campfire | 632 pass + 2 libvips skips / 15,108 queries identical; 0 load differences | 2,651 / 5,102 → 2,651 / 3,129 | Instantiate map unchanged; preload's 929 and AR plans' 1,044 setup fallbacks disappear when their unloaded fact receivers are not forced |
| PingCRM | 1 pass / 4 queries identical; 0 load differences | 0 / 0 → 0 / 0 | No hit coverage; cannot certify its Inertia passes from this suite |
| Redprints CFP | 50 pass / 692 queries identical; 0 stable load differences | 277 / 0 → **0 / 0** | Adapter selection fixed; targeted Bundlebun refusal drops all delivery/activation, not active support |
| React Starter Kit | 36 pass / 264 queries identical; 0 stable load differences, 8 unstable | 110 / 53 → 163 / 0 | Inertia config's 53 calls now hit; instantiate/props maps unchanged |

Rails 8.1.4 AP/AV/AR L3: **4,095 / 2,747 / 9,240** outcomes identical;
AV-with-AP **242**, AV-with-AR **173** identical; zero shadow mismatches.
The harness explicitly calls runtime activation **after loading fixtures**
(`bench/ar_rails_suite.rb`), so it does not depend on a Rails application's
`initialize!`. These component suites are not ordinary initialized apps.
AR's last clean pre-change control has 68,858 hits / 12,267 fallbacks;
the refreshed final cohort has the same totals. Against the intermediate
lazy-model cohort (68,859 / 12,266), one preload attempt falls back instead
of hitting; the instantiate map is unchanged. AP/AV without AR remain
zero-hit as before.

An intermediate AV-with-AR cohort lost 118 instantiate hits (123 / 2 →
4 / 3 total). A direct activation probe confirmed the affected models were
already loaded and the original method/version matched, but every source
certificate still contained the old `ar_guard.rb` hash. This is correct
stale-artifact refusal, **not** a missing `initialize!` path. A fresh combined
framework cohort with the identical dependency lockfile and rebuilt guards
recovers all 118 instantiate hits: final **122 / 3**, versus **123 / 2**
before; only preload changes **5 / 2 → 4 / 3**. No instantiate hits are lost
to missing initialization. The old 4-hit artifact cohort remains rejected
as hit-coverage evidence, rather than weakening its source hash check.
The framework harness disables SQL recording, so it is an outcome/shadow
gate, **not** an own-thread-SQL gate.

Boot smoke checks also cover Rails runner, `rake -T`, console and a non-Rails
Rack app: all exit successfully; the Rack app stays unchanged without any
`Application#initialize!`. Runner/console initialize Rails themselves;
pending activation in uninitialized/no-Rails paths is a no-op, not an error.

An old mixed/quarantined CodeTriage artifact was exercised separately:
`Lowrail.refusal_reason` records the quarantined source pass/rebuild reason,
no manifest is installed, Rails 8.1.4 boots and the original model query
returns its result. The valid artifact was restored afterwards.

## Fizzy: pinned app load nondeterminism — 2026-10-21

On 4a33992, **10 sequential off/off pairs** use the verifier's actual
preload/reporters/census, seed 41231 and one worker. Arm A sees the early
Active Job/Turbo variant **1/10** times (run `6-a`); arm B **0/10**. Every run
has the same **124 outcomes (117 pass, seven baseline errors), 5,322 own-thread
queries, zero hits and zero fallbacks**. Pair `6-a`/`6-b` differs in exactly
the 18 formerly "stable" load-event identities; it reorders nine identical
events at positions 349–357, without a set difference. This is an observed
rare branch, not a bound on its probability. Two repeats can miss it.

Separate targeted traces capture both paths with identical test order and
actual `$LOADED_FEATURES` sets, but different feature order:

- **Early, background thread:** Turbo's `broadcast_refresh_later_to` →
  `ThreadDebouncer` → `Concurrent::ScheduledTask` worker loads
  `Turbo::Streams::BroadcastStreamJob`, which loads `ActiveJob::Arguments`
  and fires `active_job_arguments` before `QrCodeLink`.
- **Late, main thread:** `Event#generate_notifications_later` loads
  `ActiveJob::Arguments` after `QrCodeLink`/`ApplicationJob`; the Turbo worker
  loads its job afterwards. Turbo's normal debounce delay is 0.5 seconds.

The plain trace pair `trace-plain-1`/`trace-plain-3` has **no Lowrail files
loaded at all**. The verifier off/off controls do preload the gem symmetrically,
but install no Guard, Loader or initialize observer. An empty on artifact also
returns before those installers. No app/gem source, delay or load order is
patched. These facts establish an app scheduling race, not a new Lowrail
autoload regression. The seven existing app errors still prevent a support
claim independently of the census.

The reviewed [18 exact identities](../fixtures/corpus/fizzy-load-controls.json)
each point to [off/off and thread/stack evidence](../fixtures/corpus/fizzy-load-evidence.json).
Use `verify --load-controls fixtures/corpus/fizzy-load-controls.json` explicitly.
Entries apply only to the Fizzy revision pinned above and lock SHA256 `73c7a5a9…`
(full pins in the files); changed pins or changed tracked app source make
them inert. The ordinary dependency-only corpus overlays remain allowed.
Event positions and absolute paths are literal, **not normalized or wildcarded**;
a new checkout/Ruby path needs new matching evidence, not path substitution.
Raw censuses retain every identity. Text separately reports **known app
nondeterminism**, with observed/differing/pinned counts, evidence and origins;
JSON retains the controls in `report.known_app_loads`, alongside raw loads.
Everything outside the list keeps the existing gate and repeat
controls; constants, SQL and census errors cannot be listed. There is no
global repeat relaxation. Fresh default **and** all-opt-in verifies with the
list each report
**0 stable differences / 8 other unstable entries / 9 known identities
observed (0 differing), 18 pinned**, with identical outcomes/SQL and no hits.
Both fresh artifacts have zero units. The rebased JIT-admission boundary also
records built-YJIT/startup-interpreter refusal (the app enables YJIT later);
these remain original-only comparisons, not active delivery support.
Regression coverage checks a reported listed event, an unlisted event,
a changed event position, a lock mismatch, a revision mismatch and dirty
tracked app code. The listed-event test fails before this feature exists.

Rebased policy checks: Cargo **40 tests** (35 unit, one MCP, four verifier
integration), release build and both Fizzy CLI verifies pass. The full gem
suite is **not green**: 144 tests / 6,320 assertions, two failures already on
main. `DigestMemoTest` still expects production hits from a built-YJIT artifact
started in interpreter (assigned to the TracePoint/JIT-mode owner);
`FormScaffoldTest` copies this orb's `RealBlog::Application` corpus while the
closed inventory requires `RealBlogR4::Application` (assigned to the sealed-form
owner). Neither admission/inventory boundary is relaxed and neither unrelated
test is edited by the policy change.

## Fat Free CRM: pinned SQL randomness — 2026-10-21

Round-2 uses the unchanged real Rails 8.0.5 app at
[`91595c4`](https://github.com/fatfreecrm/fat_free_crm/commit/91595c40a6baaa70512296157aab4bd56009e9b5)
with PaperTrail 16 and Ransack 4.4.1, Ruby 4.0.7 **YJIT at build and startup**.
The external dependency-only Gemfile evaluates the original app Gemfile and
pins unicode-emoji 4.3.0 / ffi 1.17.4; its Bundler 4.0.21 lock hash is
`4973b3a7b0c44ae90b08da790eb71c29ae41c70ee8e0270720b601443e850d92`.
No tracked app implementation or test changes. The bounded **model/lib
subset**, not the entire suite, passes **497 examples**. SQLite test DB,
`DATABASE_URL` unset, `RAILS_ENV=test`, explicit RSpec seed 41231, matching
`SEED`/`SPEC_OPTS`, strict shadow SQL and load census in both arms.

The original default artifact has **zero units** and is not JIT-refused.
Its verifier exits 1 on these three SQL differences, despite identical
outcomes and zero hits/fallbacks:

| Exact example id suffix | Original off → on queries | Exact-environment off-only controls (8) |
|---|---|---|
| `campaign_spec.rb[1:2:1]` | 59 → 58 | Seven 58, one 59 |
| `opportunity_spec.rb[1:10:1:12:1]` | 65 → 64 | Eight 64; no natural flip in this sample |
| `opportunity_spec.rb[1:10:1:9:1]` | 49 → 48 | Seven 48, one 49 |

All three differ by the **same one statement**, between campaign counter
update and tagging lookup, without reordering the other queries:

```sql
UPDATE "campaigns" SET "revenue" = ?, "updated_at" = ? WHERE "campaigns"."id" = ?
```

The bind signature is `revenue:Float,updated_at:Time,id:Integer`, uncached.
The observer's create callback takes this branch only when stage is `won`.
`spec/factories/opportunity_factories.rb:10` uses **bare `Array#sample`**,
with the unseeded Kernel RNG. RSpec's seed fixes test order but deliberately
does not call `srand`; FFaker's separate RNG is also unseeded by this app.
The earlier four off controls all agreeing was finite-sample agreement, not
proof of off-side determinism. Eight fresh full controls pass all 497 tests
and reproduce two identities' exact digests. The original rejected **off**
arm already contains all three higher-count variants.

No-Lowrail target traces capture `OpportunityObserver#after_create:14` →
`update_campaign_revenue:43`, along with actual stage/amount/discount/revenue
binds. Ten natural three-example traces give two `won` branches for
`[1:10:1:9:1]`, none for the other two; ten further traces of the remaining
identity still have no `won`. These are recorded, not repeated until green.
**Diagnostic only:** a fixed eight-seed experiment, with no Lowrail runtime
loaded, exercises the remaining identity's branch at `srand(0)` and `srand(1)`
but not seeds 2–7. Finally two off and two on **full subset** runs with
`srand(0); FFaker::Random.seed = 0` before each example have identical
original-three digests/counts **58/65/49** and 497 passing outcomes each.
This confirms app RNG behavior, not a Lowrail SQL change. None of these RNG
interventions is installed in the ordinary gate or the foreign app.

The approved [three SQL controls](../fixtures/corpus/fat-free-crm-load-controls.json)
contain exactly two whole-trace digest/count variants per test, all observed
with `LOWRAIL=0`, with [mechanism, stacks, rates and hashes](../fixtures/corpus/fat-free-crm-sql-evidence.json).
Use `--load-controls` explicitly. Both pins and tracked-source cleanliness
are checked before/after; `BUNDLE_GEMFILE` controls use the **effective** lock,
not the unchanged app's unused lock. Every entry/variant stays visible in
known-app-nondeterminism text and raw JSON. Unknown digests, counts or extra
queries in the same example still fail, even if repeat controls call that
example noisy. No global repeats, SQL normalization or blanket exclusions.

The first ordinary default verify with this list still **rejects two other,
unlisted identities** (`dropbox_spec.rb[1:3:1]`, 37 → 42;
`opportunity_spec.rb[1:10:1:6:1]`, 45 → 46). All 497 outcomes agree,
0 hits/0 fallbacks, **0 stable / 8 unstable loads**, 23 other SQL identities
advisory; all three approved identities happen to agree in this pair and
are still reported. This is not a green full-subset support claim and does
not erase either rejected cohort. Cargo: **42 pass**; the new CLI regression
fails before SQL controls exist and checks allowed variants, unknown digest,
an added unlisted query in the same example, wrong count and lock mismatch.

## Gem breadth round 2 — 2026-10-21

Three **real open-source Rails 8.x apps**, not rails-new substitutes, cover
the requested six gem families. All tracked app implementation and tests
remain unchanged. Dependency wrappers live outside the app. These are
sequential, bounded correctness runs, **not measured cohorts or full-suite
support claims**.

| App / source pin | Tested Rails | Gem boundaries exercised |
|---|---|---|
| [Wikino](https://github.com/wikinoapp/wikino/commit/25255d2d6c808df6672e293661ea797a76c6d2a9), `rails/` | 8.0.5.1 | sorbet-runtime 0.5.12435, ViewComponent 4.12.0 |
| [RubyToolbox](https://github.com/rubytoolbox/rubytoolbox/commit/3438c25712e522957dfc787fb78f09e68269baed) | 8.1.4 | dry-struct 1.8.1, dry-types 1.9.1, Sidekiq 8.1.7 |
| [Fat Free CRM](https://github.com/fatfreecrm/fat_free_crm/commit/91595c40a6baaa70512296157aab4bd56009e9b5) | 8.0.5 | PaperTrail 16.0.0, Ransack 4.4.1 |

**Mode, all three apps and every selection:** Ruby 4.0.7, build `--jit yjit`,
startup `RUBY_YJIT_ENABLE=1`; actual admission/current/certification all
`yjit`, no whole-artifact JIT refusal. Test selections use `RAILS_ENV=test`;
sealed selections use `--sealed --env production`, `RAILS_ENV=production`
and `LOWRAIL_SEALED=1`. Default/all-opt-in select zero units and record their
quarantine/unsupported reasons in the ledger; zero hits are **not support**.

The test commands keep the same subset, environment and seed 41231 in every
arm. Wikino: components/forms/models/records/policies/services, **275 examples,
2,467 queries**, default and all-opt-in identical, **0 hits / 0 fallbacks**,
**0 stable / 0 unstable** in the refreshed census (previously 8 inspect-address
identities). Its external Gemfile uses unicode-emoji 4.3.0, rqrcode_core 2.1.0,
rqrcode 3.1.1, ffi 1.17.4, pg 1.6.3 and test VCR 6.4.0; effective lock SHA256
`fe5ff605f98e9fedcecef6927188efcd78337932f11de0e65cf7b9027aceb319`.
PostgreSQL 18 is required for the app's schema. RubyToolbox uses its original
lock, SHA256 `9cd33318bc2ea51fdf7244a6fdd6d4a7ec545e4946706ae0c81c73ba525f6fbd`;
CRM's external lock and SQLite configuration are recorded above.

### RubyToolbox: order seed, observer identity and closed SQL variants

The **565 model/job/service/lib examples are a subset**, not the whole
suite. Its first plain exit 2 is SimpleCov's whole-app coverage threshold
applied to this subset: retained as a coverage artifact, **not** a Lowrail
result. Later symmetric subset runs explicitly use `SKIP_COVERAGE=1`.

The verifier originally overrode command `--seed 41231` through RSpec's
later-parsed `SPEC_OPTS`. The published seed fix makes the explicit command
win while preserving other options. Fresh fixed-seed runs still have **736
unstable constant entries**, so those entries were **not test-order noise**.
Four exact-config off-only full-subset controls give **368 differing constant
identities in a pair / 736 in their union**, with no load-event difference.
Their names are dry-types descendants of anonymous Module subclasses, e.g.
`#<#<Class:0x...>:0x...>::Coercible::Array`. The census now elides only inspect
addresses there, never paths, event indexes or ordering. The strengthened
observer regression fails on the old census and passes with the correction;
the CLI regression still rejects a real A/B reorder.

The same four off-only controls reproduce **both full digest/count variants
of all 18 truncation-order identities**, twice each. `spec/rails_helper.rb:118`
calls DatabaseCleaner for the clean-database examples. For each identity,
the only different trace line is the **same table set in a different order**
inside TRUNCATE. No SQL normalization or blanket example exclusion:
[18 pinned closed controls](../fixtures/corpus/rubytoolbox-load-controls.json),
[exact queries, off-only hashes and observations](../fixtures/corpus/rubytoolbox-sql-evidence.json).
Fresh default and all-opt-in verifies with those controls pass **565/565**,
**0 hits / 0 fallbacks**, **0 stable / 0 unstable loads**. Off query counts are
5,450 / 5,441; 18 known SQL identities differ visibly in each run, with
14 / 12 other SQL-noisy identities advisory. The original rejection stays.

### CRM: stop list growth; require exact two-seed companions

The two subsequently approved identities are now included in the five-entry
closed list: Dropbox 37/42 comes from bare lead-factory status `sample` at
`lead_factories.rb:19`, then `Dropbox#attach:171` new→contacted; opportunity
45/46 uses the already observed won/revenue branch. Each allowed complete
trace is observed off-only, and diagnostic seed 0/1 off/off/on/on traces
agree. [Follow-up evidence](../fixtures/corpus/fat-free-crm-sql-evidence.json#followup)
also retains an invalid on attempt that accidentally used the production
artifact; that refused attempt is not counted as seeding evidence.

A fresh five-control ordinary default verify still rejects **one new**
opportunity identity `[1:10:1:2:1]`, 44→45, at the same won callback. Do not
keep adding exemptions until a random suite turns green. The explicit,
pinned [two-seed companion policy](FORMATS.md#declared-rng-companions) instead
declares **Kernel and FFaker::Random** with evidence, seeds both before every
example, and compares **all** own-thread SQL and outcomes without SQL list,
repeat-noise or multi-worker exemptions. Loads remain independent.

The first new default verify passes both complete **497-example** companions:
seed 0 **13,451 queries**, seed 1 **13,467 queries**, exactly equal off/on
within each seed, all outcomes pass, **0 hits / 0 fallbacks**. The ordinary
unseeded traces remain **13,443 / 13,434 queries**, with **23 raw differing
tests visibly classified RNG-dependent, companion-verified**, not claimed
identical. There are **0 stable / 0 unstable loads** in this new run. Both
original default/all-opt-in rejections and the five-control rejection are
retained. After refreshing main, new default **and all-opt-in** runs each
pass both 497-example companions with those same exact seed-specific query
counts. Their unseeded gates still reject **two SQL identities each before
companion classification**: raw totals 13,436/13,444 (default) and
13,445/13,444 (all-opt-in), with **20 / 16** raw differences visibly
companion-verified, respectively. Both selections retain **0 hits / 0
fallbacks**, **0 stable / 0 unstable loads**. No RNG hook runs in the ordinary
gate or is added to the app.

### Sealed production probes: bounded non-vacuous coverage

The apps' suites require test mode. The shared
[production probe](../fixtures/corpus/breadth_production_spec.rb) is therefore
an explicitly separate **two-example smoke/contract probe**, not their suites.
It asserts production/YJIT mode, real own-thread SQL, and app/gem behavior:
Wikino renders the real typed ViewComponent and retains Sorbet's TypeError;
RubyToolbox retains real dry-struct coercions/errors and class-body Sidekiq
retry/lock options; CRM retains PaperTrail registration and the app's Ransack
scope. None forces model loading just to manufacture activation or hits.

The later [real-app C GET eligibility check](sealed-verification.md#real-app-get-eligibility-after-passive-form-activation)
tests only the current link/form builders after passive form activation.
Five of the seven requested apps boot production/YJIT but return zero units;
Writebook and CASA fail production boot before inventory. **No eligible GET
workers run, and no new on-only difference or runtime hit count is claimed.**
The exact per-app reasons and pins are in that table. The older preload and
instantiate hits below are separate probes, not link/form GET coverage.

| App / selection / mode | Outcomes | Own-thread SQL | Hits / fallbacks | Stable / unstable loads |
|---|---|---|---|---|
| Wikino sealed production / YJIT | 2 pass, identical | 3, identical | **1 preload / 0** | **0 / 0** |
| RubyToolbox sealed production / YJIT | 2 pass, identical | 2, identical | **1 instantiate / 0** | **0 / 0** |
| CRM sealed production / YJIT | 2 pass, identical | 7, identical | **0 / 0** | **0 / 0** |

Only the hit-bearing probes provide active breadth coverage, and only for
these exercised paths. CRM's eligible plans were not exercised as fast paths;
its unaudited Rails 8.0 instantiate implementation remains a ledger refusal,
**not a support claim**. Initial CRM production probes against an empty DB
failed in both arms; the corrected isolated schema-only probe is a new run,
not a hidden repair of the failed evidence. Sidekiq worker deployment is not
covered. These refreshed production runs retain the earlier hit counts;
the old address-bearing censuses were 8 / 736 / 8 unstable identities,
respectively. No performance claim or measured cohort is made.

**Fizzy mode-mismatch follow-up:** the new all-opt-in matching-YJIT build/run
has null admission refusal, the same **124 outcomes (117 pass, seven app
errors), 5,322 queries, 0 hits / 0 fallbacks**, **0 stable / 0 other unstable
loads** after the observer correction (8 in the previous matching-mode run),
with the 18 pinned race identities still visible (9 observed,
0 differing in this pair). This is a new run, separate from the earlier
**built-YJIT/startup-interpreter mode-mismatch refusal**. Neither the baseline
errors nor zero-hit/no-support classification changes.

**Repository checks:** Cargo **43 pass**, plus the owned gem reporter/SQL/census
tests **9 tests / 128 assertions, green** on refreshed main. The full earlier
gem run is **147 tests / 6,390 assertions, one pre-existing FormScaffoldTest
inventory failure**. After the sealed thread's inventory correction, that
test progresses to a different existing fixture/checker mismatch: the off-only
worker raises `wrong app` at `bench/experiments/blog_endpoint_check.rb:63`
(requires `RealBlogR4::Application`; this corpus is `RealBlog::Application`).
The retained off log SHA256 is
`013b18a0830e23cc1742305f3a7434f2cf3378f7a2224fa56ac21c1576c88d6f`.
This remains with the sealed owner; no checker, app identity or unrelated
test was relaxed. Raw runs, rejected/invalid attempts and the off log remain
under `.lowrail/private/breadth-evidence/`; no app source is changed.

For repeatable dependency-only setup, the tested wrapper/lock copies are
[Wikino](../fixtures/corpus/wikino.Gemfile) and
[CRM](../fixtures/corpus/fat-free-crm.Gemfile), adjacent to their exact locks;
both pass frozen `bundle check`. Fetch the app revisions above to
`.corpus/wikino` / `.corpus/fat-free-crm`; the wrappers reference their original
Gemfiles, not copies with patched app code. Use `BUNDLE_GEMFILE` pointing to
the wrapper's absolute path. RubyToolbox uses its unchanged app Gemfile.
Supply isolated databases and the app's required production dummy settings.
Refresh `lowrail facts APP` when changing Rails environment, then build with
the matching mode before verifying:

```sh
# Common: RUBY_YJIT_ENABLE=1 LOWRAIL_VERIFY_LOADS=1, Ruby 4.0.7.
# Test-mode commands from the repo root; verify runs the command in APP.
lowrail verify .corpus/wikino/rails -- bundle exec rspec --seed 41231 \
  spec/components spec/forms spec/models spec/records spec/policies spec/services
# RubyToolbox also needs SKIP_COVERAGE=1 (explicit subset).
lowrail verify .corpus/rubytoolbox --load-controls fixtures/corpus/rubytoolbox-load-controls.json \
  -- bundle exec rspec --seed 41231 spec/models spec/jobs spec/services spec/lib
lowrail verify .corpus/fat-free-crm --load-controls fixtures/corpus/fat-free-crm-load-controls.json \
  --companion-seeds 0,1 -- bundle exec rspec --seed 41231 spec/models spec/lib
# Production, separate from the above suites; LOWRAIL_COMPAT_APP is
# wikino, rubytoolbox or fat-free-crm. Set RAILS_ENV=production,
# LOWRAIL_SEALED=1 and matching database/wrapper before facts/build/verify.
lowrail build APP --sealed --env production --jit yjit
lowrail verify APP -- bundle exec rspec --options /dev/null --seed 41231 \
  "$PWD/fixtures/corpus/breadth_production_spec.rb"
```

## Reproduction

Use isolated copies/databases; never point these commands at a live app DB.
`script/corpus` verifies the pin and applies a dependency patch once; a
reverse applicability check accepts rerunning the same overlay, but rejects
drift. Fresh Writebook bootstrap (clone, frozen bundle, schema, assets) was
also executed successfully.

```sh
cargo build --release
# CASA example: provision a fresh local role-owned DB and Redis first.
export DATABASE_URL='postgresql://user@localhost/lowrail_casa_test?host=/var/run/postgresql'
script/corpus casa
export RAILS_ENV=test SEED=41231 MT_CPU=1 PARALLEL_WORKERS=1
export LOWRAIL_VERIFY_LOADS=1
mise exec ruby@4.0.7 node@24.22.0 -- bash
# Plain baseline, before installing any Lowrail preload:
(cd .corpus/casa && LOWRAIL=0 bundle exec rspec --seed 41231 \
  --exclude-pattern 'spec/system/**/*_spec.rb')
target/release/lowrail facts .corpus/casa
for tier in default all-opt-in; do
  target/release/lowrail build .corpus/casa --passes "$tier"
  target/release/lowrail verify .corpus/casa -- bundle exec rspec --seed 41231 \
    --exclude-pattern 'spec/system/**/*_spec.rb'
  # Preserve .lowrail/verify/last.json before the next tier overwrites it.
done
# Repeat baseline/build/verify with: bundle exec rspec --seed 41231 spec/system
```

For Writebook/Fizzy/CodeTriage the suite command is
`bundle exec rails test --seed 41231`; Writebook's browser command is
`bundle exec rails test:system --seed 41231`. Use a separate database/copy
for concurrently running system and non-system suites. CASA also fixes its
Capybara server port to `7654 + TEST_ENV_NUMBER.to_i`: concurrent browser
copies need distinct offsets as well as databases (for example,
`TEST_ENV_NUMBER=100`, with an explicit isolated `DATABASE_URL`). A collided
browser cohort is invalid, including the run owning the shared listener;
retain its log and reason rather than counting its outcomes. Chrome/driver
and libvips/ImageMagick must be installed as required by the apps' own tests.
`LOWRAIL_SQL_TRACE=full` retains query lines for diagnosis. Census overhead
on three alternating Real Blog off/on pairs: observer disabled
1.83/1.80/1.85 s, enabled 1.94/2.05/1.95 s, median **+0.12 s / +6.6%**;
snapshots themselves about 0.05 s. This is why the census is opt-in rather
than hidden in ordinary verify overhead.

## Own-suite product-contract recheck — 2026-10-21

### What already existed

- `src/verify/mod.rs` runs the app's command off, then on (default
  `bin/rails test`), comparing test identities, outcomes, failure descriptions
  and exit success. Missing identities reject. Minitest/RSpec reporters retain
  per-unit hits/fallbacks and admission refusals. `--bisect` can isolate an
  on-only difference. `script/corpus` fetches pins and dependency overlays;
  it is setup, not an automatic all-app suite runner.
- The latest preceding integrated own-suite record is the **2026-10-21**
  [7d0ea95 recheck](#integrated-main-recheck-2026-10-21): blog, Campfire,
  PingCRM, Redprints, Starter, CASA, Writebook, Fizzy and CodeTriage, with CASA
  and Writebook system suites separately recorded. Those fresh `all-opt-in`
  builds mostly had zero units; only Starter recorded hits. Earlier default
  runs and historical pre-quarantine hits are not current active coverage.
  Wikino, RubyToolbox and Fat Free CRM have bounded RSpec subsets, not complete
  own suites. Baseline errors/skips and SQL/load advisories remain explicit.
- `gem/test/e2e_test.rb#test_real_blog_outcomes_identical_with_hooks` checks
  the 21-test blog suite with a compatible **empty** manifest, not sealed
  lowering or browser tests. Synthetic runtime/verify tests and the seeded AR
  differential harness in `bench/ar_equivalence.rb` are not corpus-own suites.
  `script/rails-suite` / `bench/ar_rails_suite.rb` run **Rails framework** tests;
  request/measurement harnesses in `bench/` do not establish app-suite parity.
- `script/blog-production-verify` is a two-GET external production driver,
  not `bin/rails test`. Its latest documented entropy-companion gates still
  reject SQL/load differences. `fixtures/corpus/breadth_production_spec.rb`
  likewise supplies narrow production probes, not full-suite coverage.
  [DECISIONS](DECISIONS.md#sealed-verification-external-production-scenarios-first-slice-rejected-2026-10-21)
  keeps wider production replay/test seams open. There was **no active sealed
  whole-own-suite gate** for blog or Fizzy, and this check does not create one.

### Fresh results

Executed on [74abb60](https://github.com/thomasklemm/lowrail/commit/74abb60fa1f24dff3618ccef70b21b91ac61fc08),
Ruby **4.0.7**, Rails **8.1.4**, startup YJIT enabled in every arm, seed
**41231**, one worker. The subsequent pull through
[d5fbdf1](https://github.com/thomasklemm/lowrail/commit/d5fbdf1)
changes experiments/docs only, not the tested runtime, verifier or corpus
inputs. No app/test implementation was patched. Fizzy is the pinned
[6f1d200](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9)
with exactly `fixtures/corpus/fizzy.patch`; blog is an isolated copy of the
Rails 8.1.4 Roundhouse-generated `real-blog-r4` app, retaining `RealBlogR4`.

Each cell below is the result in **each** off/on arm, not a totals-only
comparison. The [machine-readable evidence](own-suite-results.json) retains
every literal test identity and its result/failure in the native plain arm
and all four verify arms, plus artifact/input hashes and native exit codes.

| App / complete command | Plain, no preload | Default off / on | Sealed artifact off / on | On-only differences |
|---|---|---|---|---|
| Blog `bin/rails test` | 21 pass | 21 pass / 21 pass | 21 pass / 21 pass; refused | 0 |
| Blog `bin/rails test:system` | 2 pass | 2 pass / 2 pass | 2 pass / 2 pass; refused | 0 |
| Fizzy `bin/rails test` | 117 pass, 7 error | 117 pass, 7 error / same | 117 pass, 7 error / same; refused | 0 |

All verify commands exit 0; the native Fizzy commands exit **1 in every
arm**, and blog exits 0. Fizzy's seven unchanged errors all say
`NoMethodError: undefined method 'reset_all' for an instance of Current`, at
`test/test_helpers/session_test_helper.rb:22`; exact identities/messages are
in the evidence. **Fizzy is not green or supported.** Blog's native Capybara /
Selenium system tests ran with Chrome for Testing **155.0.8059.79** and the
matching driver. Fizzy's `test/system` contains no tests, so no Fizzy browser
behavior is covered.

Both default manifests have **0 units, 0 hits, 0 fallbacks, no refusal**.
After `rake compile`, blog's combined production sealed artifact contains
20 units: one `sealed/link_to`, one `sealed/form_scaffold`, one preload plan
and 17 instantiate units. Fizzy has 0 eligible units: the link/form builders
require the blog's loaded `ArticlesController` / model/template inventory.
With `RAILS_ENV=test LOWRAIL_SEALED=1`, **both entire artifacts refuse**:
`sealed artifact requires LOWRAIL_SEALED=1, production, and the separate SEAL001–009 contract; this test runs unoptimized`.
All sealed-arm hits/fallbacks are 0. This verifies **safe refusal**, not active
link/form equivalence; production admission was not bypassed. The earlier
missing-native build attempt is retained locally, not presented as an active
link test. Active sealed whole-suite coverage remains **uncovered**, not a
passing release gate.

No on-only outcome difference was found to reduce. Own-thread SQL maps also
match exactly (blog 125 queries, system 55, Fizzy 5,322), with no unstable
identities or declared controls. No new normalization, filtering, RNG
companions, Callgrind or measurement cohorts were used. The existing reporter
stores the exception's first line and masks object addresses; these seven
messages contain no addresses and also match the unmodified plain logs.
This is an outcome gate, not a new load-census or production-behavior claim.

### Reproduce this gate

Use fresh disposable copies/databases, the pins above and Ruby 4.0.7. Preserve
the blog's generated application module; do not rename it to gain admission.
Set `RAILS_ENV=test RUBY_YJIT_ENABLE=1 MT_CPU=1 PARALLEL_WORKERS=1 SEED=41231`;
unset inherited `RUBYOPT`, `LOWRAIL_DIR`, `LOWRAIL_ROOT`, `LOWRAIL_UNITS`,
`LOWRAIL_VERIFY_LOADS` and companion variables. From the repo root:

```sh
cargo build --locked
(cd gem && rake compile)
bash script/corpus fizzy  # exact pin, dependency patch, schema and assets
# Prepare blog's test DB with its own bin/rails db:prepare.
# APP is one disposable app path; repeat separately for blog and Fizzy.
(cd "$APP" && LOWRAIL=0 bin/rails test --seed 41231 --verbose)
target/debug/lowrail facts "$APP"
target/debug/lowrail build "$APP" --jit yjit
target/debug/lowrail verify "$APP" -- bin/rails test --seed 41231
# Blog only: repeat plain + verify with bin/rails test:system --seed 41231.
# Archive APP/.lowrail/verify before each next verify overwrites it.
# Prepare the disposable blog production DB with its own db:prepare first.
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 target/debug/lowrail build "$APP" \
  --sealed --env production --jit yjit
LOWRAIL_SEALED=1 target/debug/lowrail verify "$APP" -- bin/rails test --seed 41231
# Blog only: repeat sealed verify with bin/rails test:system --seed 41231.
# Expect a whole-artifact refusal in test, not optimized execution.
```

The orb's Chrome wrapper adds `--no-sandbox --disable-dev-shm-usage` and is
selected through Selenium's `SE_BROWSER_PATH`, with an isolated
`SE_CACHE_PATH`; no app driver code changes. Compare every identity and
result/failure across plain, default-off/on and sealed-off/on before reading
totals. Cargo tests and the Minitest reporter's 4 tests / 83 assertions also
pass. The complete strict E2E file passes 18 tests / 345 assertions with no
skips, including its existing 21-test blog hook gate. Runtime, lowering,
admission and reporter code are unchanged.

### Follow-up: optimized admission blocked; Fizzy errors classified

Checked on [bda793a](https://github.com/thomasklemm/lowrail/commit/bda793a5eb2b962ae385929f295adb110667b9f7),
with Ruby 4.0.7. The existing CLI cannot produce the requested test-environment
20-unit artifact. Both commands exit **1**, leaving the production manifest
byte-identical:

```text
lowrail build APP --sealed --env test --jit yjit
--sealed requires --env production and cannot be combined with --passes; see docs/sealed.md

lowrail build APP --env test --passes default,+sealed_link_to,+form_scaffold --jit yjit
sealed passes require build --sealed and the separate production contract
```

| Check | Observed result | Optimized own-suite coverage |
|---|---|---|
| Build sealed artifact for test through CLI | Rejected before build, exit 1 | Blocked |
| Load existing 20-unit production artifact in test | Whole artifact refused | None |
| Current form activator under test | `production_only; this test runs unoptimized; terminal admission, attempts=0/1` | None |
| Fizzy unchanged `Current`, Rails 8.1.4 API, Lowrail off | Exact `reset_all` error reproduced | Baseline diagnosis only |
| Same model/Ruby/dependencies, original pinned CurrentAttributes source | `reset_all` succeeds; session becomes nil | Bounded API control, not an original-stack full-suite run |

The publication rebase picked up the owner's
[91d76da passive-form admission](https://github.com/thomasklemm/lowrail/commit/91d76da)
through [497d696](https://github.com/thomasklemm/lowrail/commit/497d696).
After rebuilding the CLI on that head, the sealed test build still exits 1
with the same error above. A fresh runtime probe with
`LOWRAIL=1 LOWRAIL_SEALED=1 RAILS_ENV=test` still reports exactly:
`sealed artifact requires LOWRAIL_SEALED=1, production, and the separate SEAL001–009 contract; this test runs unoptimized`.
There are independent production checks in `src/build/mod.rs`,
`gem/lib/lowrail/manifest.rb`, `sealed_build.rb`, `sealed.rb`,
`form_scaffold_inventory.rb` and `form_scaffold.rb` (the last four under
`gem/lib/lowrail/`). Environment equality in `guard.rb` must also remain intact.

At the initial head, the form activator always declined its runtime inventory:
`form certification requires runtime controller/view/I18n/ERB effects; passive activation unavailable; keep original`.
The newly published owner change replaces that activation path with a passive
witness after the first natural original form render, still **production-only**.
The current activator's direct test-mode probe returns the exact refusal in
the table, before any admission attempt. Old effectful form certificates also
require rebuilding. The historical inventory-method refusal is retained in
the evidence, but is **not** a claim that new production passive admission is
unavailable. A manifest containing a form unit is not execution coverage.

**Smallest owner-scoped proposal, not implemented:** add an explicit
verification-only sealed **test-environment certificate**, built against and
admitted only to the same test environment. Coordinate the CLI, manifest,
link builder/activator and form inventory/activator; retain opt-in, environment
equality, source/native certificates, original fallback and the sealed
contract/deopt checks. Reuse the owner's passive natural-render witness for
fresh test certificates, rather than restoring the old effectful activator.
Do not admit a production certificate into test or simply delete production
predicates. Test config must itself be certified (for example, blog's eager
loading is controlled by `CI`, and CSRF differs). This belongs to the
sealed/admission owner. This task made no admission/runtime changes, relabeled
no artifact, and presents no zero-hit suite rerun as new coverage. Per-unit
active hits/fallbacks and on-only bisection remain blocked until that seam exists.

**Fizzy is an overlay/API incompatibility, not intrinsically permanently red.**
The app at
[6f1d200](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9/test/test_helpers/session_test_helper.rb#L22)
uses the internal `Current.reset_all` API in its helper's `ensure`.
Its original [Rails pin](https://github.com/rails/rails/blob/5520bd835e3724ffafe3f719f9aafe951567f2f3/activesupport/lib/active_support/current_attributes.rb#L156-L163)
defines that inherited class method. Rails removed it in
[475877f](https://github.com/rails/rails/commit/475877fc5e2fffbb80c654c5248b5eb6a5cf587d),
before 8.1.4, switching framework cleanup to `clear_all`. The overlay therefore
removes an API this historical app calls. `Current.reset_all` now falls through
the class's `method_missing` to `instance.public_send`, explaining why the
error names **an instance of Current**. `clear_all` drops the registry;
`Current.reset` only resets that class's instance, so neither should be
silently installed as a compatibility alias.

The control loads only the original CurrentAttributes source file alongside
8.1.4 support dependencies, then loads the unchanged app model, in a fresh
Ruby 4.0.7 process without Lowrail. The original API succeeds and the installed
8.1.4 API gives the exact seven-test error. This isolates the API break from
Ruby/Lowrail; it does **not** prove the full original dependency stack green.
The [evidence](own-suite-results.json) retains both probe outputs and source
pins. Keep the current overlay as a red negative control until an approved
compatible app/dependency pin or explicit upstream helper change is chosen
and the complete suite rerun. No app or framework patch was applied.
