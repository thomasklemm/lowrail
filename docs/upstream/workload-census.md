# U3: writes, JSON, jobs, Cable, mail and boot

2026-10-22. This extends the HTML-GET-heavy U/U2/W censuses, not Lowrail's
runtime. Five unchanged production app implementations, **24 operations × two
observed modes = 48 cells**, and ten separate boot/eager-load receipts.
The warm ranking contains **2,158 source sites**; the boot ranking contains
**64,195**. Rankings identify work, not how much can safely disappear.
No upstream PR, issue or comment, no main write, and no Lobsters-tree edit.
Two allocation-only candidates are published: PostgreSQL result fields and
TZInfo signed transition decoding. Both remain fork-only; independent
review and upstream submission belong to the separate PR threads.

## Method and boundaries

Reuses the allocation-generation method in
[U](https://github.com/thomasklemm/lowrail/blob/aeb6f064445db51d418ab22d3f7ef36579307898/docs/upstream/rails-main-census.md),
[U2](https://github.com/thomasklemm/lowrail/blob/367ab4e8f09f7da3424b584859916f717c21af20/docs/upstream/rails-main-census-2.md)
and [W](https://github.com/thomasklemm/lowrail/blob/eda593ae6f2689e6923536762f65ada8f2641dda/docs/upstream/gem-census.md).
Ruby 4.0.7 (`229531a6cf`), Rails 8.1.4, frozen dependency-only corpus
overlays. No Lowrail preload. Each operation has 100 warmups, three
GC-enabled totals of 20 operations, and a distinct ten-operation
GC-disabled ObjectSpace allocation-generation receipt. SQL witnesses
require actual INSERT/UPDATE work for write/enqueue/persistence labels;
requests assert status and parse JSON rather than accepting an error page.

Ownership follows the loaded gem's source root, separating Rails components,
Ruby stdlib/default gems and third-party gems. Versions remain separate.
Native/internal/unavailable-source residuals stay visible and unattributed.
Rack mock client allocations are excluded from the warm ranking, not totals.
The score sums per-app means, with equal operation and mode weights within
each app. It is not an expected saving or an operation frequency model.

Boot runs are separate processes: one production eager boot with warm
Bootsnap caches, GC disabled throughout attribution. They assert that GC
did not run. CASA's external throwaway credential construction is outside
the reported `boot_objects` interval but inside `traced_objects`; neither
number is latency. Initial attribution attempts failed on BasicObject's
missing `class`; the collector now binds Kernel's class method. An empty
DATABASE_URL override also caused one setup failure; successful SQLite
receipts leave it unset. These were collection failures, not rejected
performance cohorts. No counted cohort is rerun until green.

No Ir, whole-request speed, JIT-flat throughput, Lowrail support, RSS or
production-admission claim follows from these untimed receipts.

### App pins and operation coverage

| App | Source | Operations |
| --- | --- | --- |
| Retained blog | Roundhouse `bb90df2514f80817f98d89848dd0a6baa8df20a9`, retained real-blog-r4 source/lock | form POST and PATCH with enqueue; JSON POST success/error; jbuilder show; Solid Queue enqueue and empty claim; synchronous Solid Cable persistence and row polling; model as_json + encoding |
| Campfire-r81 | `02023b0f0cafc4d66e06e43be072cf4d6ca328fa` | authenticated message POST, callbacks/Turbo/Redis; synchronous render/broadcast; model JSON |
| Fizzy | `6f1d200316ec3bae91d32c557d88647300807ee9` | authenticated bubble PATCH with callbacks/enqueue; AutoPopAllDueJob perform_now; Turbo broadcast job perform_now; synchronous Cable/Solid Cable 3.0.5 broadcast; model JSON |
| CASA | `b584d2e6e6ebffe382f34c2ec202d20384d035ca` | real Devise login outside windows; preference POST/UPDATE; real mailer render and MIME encode, without delivery; model JSON |
| CodeTriage | `d1868f8634e97a111a7fca49d58cc776d206007e` | model validation/callback UPDATE; validation errors/as_json; model JSON |

All app copies are disposable `.corpus/workload-*` trees. PostgreSQL 15,
Redis and Memcached are local disposable services. CASA uses the existing
external credentials fixture pattern, not production credentials. Fixture
rows, schema preparation and assets are setup, not app implementation edits.
Writebook remains excluded because it cannot boot in production.

The Fizzy AutoPop job warms to an empty due-work scan; it is **not** evidence
for nonempty queue dequeue/worker execution. Blog's Cable 4.1 default writer
is asynchronous, so its measured direct Message.broadcast is explicitly
synchronous persistence, not completed asynchronous delivery. There is no
real WebSocket delivery, network accept loop, SMTP delivery, separate worker
process lifecycle or external API measurement here. CodeTriage writes are
model operations, not an invented HTTP write route. Queue-related framework
allocations mostly attribute to Active Record, not Solid Queue source files.

### Representative allocation receipts

Median of the three GC-enabled totals; objects per operation, not savings.
All operations, traced counts and residuals are retained in the data archive.

| Operation | Interpreter | YJIT |
| --- | ---: | ---: |
| Blog form POST + INSERT/enqueue | 2,119.35 | 2,125.95 |
| Blog PATCH + UPDATE/enqueue | 2,129.05 | 2,138.65 |
| Blog JSON POST + jbuilder | 2,194.10 | 2,200.30 |
| Blog JSON validation error | 1,552.00 | 1,548.90 |
| Blog jbuilder show | 874.20 | 877.20 |
| Blog Solid Queue enqueue | 755.00 | 763.00 |
| Blog empty queue claim | 271.00 | 276.00 |
| Blog synchronous Cable persistence | 148.00 | 150.00 |
| Blog Cable row poll | 248.00 | 252.00 |
| Campfire message POST + Turbo/Redis | 10,257.00 | 10,299.75 |
| Fizzy PATCH + callbacks/enqueue | 5,756.70 | 5,813.60 |
| Fizzy Cable 3 broadcast | 417.15 | 419.45 |
| CASA preference POST/UPDATE | 2,053.95 | 2,073.45 |
| CASA mail render/MIME encode | 1,959.60 | 1,972.60 |
| CodeTriage model UPDATE | 324.00 | 329.00 |

| Production boot, warm cache | Interpreter objects | YJIT objects |
| --- | ---: | ---: |
| Blog | 1,087,113 | 1,087,151 |
| Campfire-r81 | 1,200,014 | 1,200,047 |
| Fizzy | 1,450,178 | 1,450,213 |
| CASA | 2,307,319 | 2,307,358 |
| CodeTriage | 1,517,262 | 1,517,298 |

## Priority lead: Solid Cable YAML rereads

**Confirmed in 3.0.5, already fixed on current main.** Fifty warmed genuine
Fizzy Cable broadcasts give 48 operations with **two** config_for/YAML parses
and two trimming operations with **five**. Ordinary paths are autotrim?
and trim_batch_size; trimming additionally reads retention/skip-lock/batch
configuration. Each individually probed polling/config accessor parses once.
These are actual call-path counts, not an inference from Bootsnap's ranking.
An additional real subscription/listener probe observes **two parses in
each of eight complete polling iterations**: with_polling_volume reads
silence_polling?, then the sleep boundary reads polling_interval. It performs
real database polling and clean listener shutdown, not a simulated loop.

Current main `bd0442f84b10c44cbd915d919c74fcd698e02b11` already contains
merged [rails/solid_cable#86](https://github.com/rails/solid_cable/pull/86),
commit `10ab28a68822aa516f07ed277ca2633f033bd463`. Its configuration source
is byte-identical to installed 4.1.0. Fifty warmed synchronous persistence
operations and all probed accessors perform **zero** config_for/YAML parses.
The eight real listener iterations also perform **zero**. The later
broadcast sample has no trimming events; the original two/five distribution
is retained separately rather than treated as a fixed trimming frequency.
Do not submit another memoization patch.

Semantics checked against the existing implementation:

* Configuration is global to SolidCable, sourced from Rails.application's
  cable config, not cached separately per adapter/connection. connects_to
  remains an explicit configuration override and is symbolized as before.
* configure replaces the configuration object; explicit false is retained.
  Changing the config source alone does not refresh a warmed cache;
  reset_configuration! does. No automatic development reload hook was found
  in the current engine/source. Do not promise live YAML editing reload.
* Eight threads × 100 warmed reads agree. This checks steady-state values,
  **not** serialized cold initialization or concurrent configure/reset.
  The existing `||=` is not a once-only initialization mutex.
* Fork inherits the warmed value; a child configure changes only the child.
  Parent remains unchanged. No new database pool/thread is cached here.

Open #93 (invalid duration fallback), #96 (listener failure), #98 (optional
synchronous writes) and #91 (late-commit delivery) are different work. The
3.0.5-to-4.1 figures are not an isolated patch benchmark: writer architecture
also changed. No new fork commit is warranted for this lead.

## Priority lead: Mail MIME encoding

Current mikel/mail master `d645d7b5b7d03218b0bc8971ef041c991a63f5f7`
still uses lines/find in EightBit.compatible_input?. It is warm rank 16,
score 36 (108 attributed objects per CASA mail operation before equal
three-operation app weighting). **Open [#1693](https://github.com/mikel/mail/pull/1693)
already covers it**, including a byteindex scanner, older-Ruby/UTF-16
fallback and missing-header attachment exceptions. Its source diff and
boundary tests were inspected; no competing implementation was authored.

Nearby parameter matcher compilation and group-address repeated rendering
are covered by open #1673 and #1676. Remaining dasherize output is fresh
caller-visible text; Ragel parser output is a public parsed graph, not a
disposable line Array. A general replacement of the String blank predicate
would change String-subclass operator dispatch. No additional exact small
MIME fix was established. Mail CONTRIBUTING requires passing specs, supported
Rubies and a changelog, exempting pure refactors from new specs. No explicit
AI prohibition was found in the checked contribution file.

## Warm ranking: bounded source triage

Ranks group the same responsibility; they do not mean every attributed
object can be removed. The complete ranking includes exposures by app,
operation and mode. Previous U/U2/W dispositions are reused rather than
re-prototyped. Unlisted sites remain ranked, **not fully audited**.

| Rank(s) | Owner/site | Disposition |
| ---: | --- | --- |
| 1, 32 | useragent detection/version | Prior W Unicode/retained-output rejections; not revived. |
| 2, 7 | Rails Time.change | Exact subsecond/timezone construction; no rounding or shared-Time shortcut. Time-zone call-path work also overlaps open Rails #59199. |
| 3, 12, 15, 20 | Rails tag/SafeBuffer | Fresh escaping/output and prior U disposition; no new buffer rewrite. |
| 4, 18, 21 | Rails WhereClause | Current main already has #59257's empty-clause improvement; nonempty predicate/result ownership remains. |
| 5, 23, 24 | TZInfo timestamps/periods | Returned timestamp/period values and fractional precision; no cross-call sharing. Boot decoder investigated separately below. |
| 6, 26, 27 | Rails attributes | Per-record mutable values and dup_or_share ownership; no shared attribute instance. |
| 8 | Arel Attribute | Mutable query AST node; prior U2 ownership boundary. |
| 9, 33, 39 | Rails callbacks | rank 9 Proc already removed by main's 7a2033c9b8; remaining lambdas/environment carry callback and per-invocation state. |
| 10, 37 | PostgreSQL cast_result | Only the duplicate fields Array is eligible; rows/types/name Strings are not all redundant. Experiment below. |
| 11 | PostgreSQL type-map lookup | Live type registration/OID dispatch; no global type-result reuse. |
| 13, 22, 31, 34 | Rails notifications | #59235 already handles empty grouping; active handles/groups keep independent timing, silencing and payload state. |
| 14 | Rails transaction callbacks | Block/ensure behavior and failure actions remain; no callback elision. |
| 16 | Mail 8bit | Open #1693, not a new candidate. |
| 17, 19, 47, 54 | Rails relations | Fresh mutable values/relations and copy-on-spawn ownership; prior U2 boundary. |
| 25, 28, 29 | Rails predicate builder | Live scalar/tuple/association conversion and owned output; no cached AST graph. |
| 30 | Rails deep key transform | Returns a fresh Hash, including subclasses; no in-place caller mutation. |
| 35 | Rails blank? | Prior census disposition, not revived. |
| 36, 45 | Rails inflector | Output ownership, mutable acronym registry and current dispatch; no shared normalized String. |
| 38 | Rails String type cast | String.new deliberately detaches caller-owned strings and subclasses. |
| 40, 44 | Rails association scope | Live owner values and composite key pairing, not a cached query clause. |
| 41 | Rails SQL instrumentation | Public event payload/observer boundary, not removable bookkeeping. |
| 42, 55 | Mail dasherize/parser | Fresh transformed text/parsed graph; no small exact shortcut established. |
| 43 | Rails to_param | Composite IDs, delimiter and live conversion; no scalar-only shortcut. |
| 46 | Bootsnap YAML | In Fizzy this exposes old Solid Cable rereads, already fixed by #86. |
| 48 | Rails database version comparison | Mutable/overridable string split result; no retained-array map! rewrite. |
| 49 | Rails TimeWithZone | Returned zone wrapper lifetime/identity; not reusable across conversions. |
| 50–54, 57–59 | Predicate/reflection/relation/extract/tag construction | Fresh public/mutable objects or already dispositioned U2 sites; no new patch. |
| 56 | Ruby JSON.parse keyword options | Current ruby/json parser still accepts/forwards mutable option hashes. Parser semantics/custom classes preclude a shared default Hash. No matching open allocation PR found. |
| 60–61 | i18n except/interpolation | Current default branch uses Hash#except where available. Fresh option Hash and runtime interpolation patterns/callbacks remain; no cached translation String. |

Other coverage leads: strong parameters begin at rank 421; Active Job enqueue
at 357; Solid Queue's own batch wrapper at 1,228. Their framework/ORM work
appears much higher. These ranks are not evidence that worker execution,
params parsing or validation is cheap in other workloads. Solid Queue main
`73602fe39b95d48d99f0f419293c566310dae3e2` and open/closed poll/allocation
searches were checked; no new small exact patch was established in the
exercised empty-claim/enqueue boundary. Nonempty worker claims remain open
coverage, not a silently accepted support claim.

## Boot ranking and Lowrail implications

| Boot rank(s) | Owner/site | Disposition |
| ---: | --- | --- |
| 1, 8, 12–17, 19, 22 | TZInfo timestamp/annual transition values | Necessary transition graph; do not memoize returned mutable graphs or force loading earlier. |
| 2, 9 | Rails Time calculations | Calendar/zone construction used by TZInfo's rule expansion; no lossy integer-only specialization. |
| 3, 6, 7, 11, 20 | TZInfo zoneinfo reader | Actual binary reads, transition Hashes/objects and signed64 intermediate Integers. Only signed64 reconstruction is prototyped. |
| 4, 5, 10 | Ruby Psych | Parser/node/tag/alias-aware construction, not repeated application config access per warm operation. No shared parsed YAML graph proposed. |
| 18, 21, 25, 32 | Ruby bundled-gem loading | Boot-only require/load paths; no warm-request optimization inferred. |
| 24, 31 | Rails delegation/class_attribute | Generated method/state ownership; not an unnecessary application eager load. |
| 26, 30 | Zeitwerk | Loader constant-path work; no early app-constant loading or shared mutable path return. |
| 27, 34 | mime-types | Boot data construction, not Mail MIME negotiation's line Array. |

No new Lowrail lowering is recommended from this screen. The removable
fields Array and signed64 intermediates belong in their owning upstreams.
Stable configuration remains a possible sealed specialization only with
explicit configure/reset/fork/development invalidation; Solid Cable's
existing upstream cache already removes the large YAML cost. Callback,
schema and query nodes still need exact live-boundary/ownership guards.
Boot/eager loading must never be moved earlier merely to lower counts.

## Reproduction

### Standalone public candidate benchmarks

Download either file independently; neither needs Lowrail, a corpus app or
private fixtures. The header contains public clone/worktree commands,
exact baseline/fork commits, gem prerequisites and run commands:

* [PostgreSQL fields benchmark](../../bench/upstream/pg_fields_bench.rb):
  Rails main 7e3828a6 versus fork 220c4f2, genuine native PG results and an
  explicitly supplied disposable database URL. It does no persistent writes.
* [TZInfo signed decoder benchmark](../../bench/upstream/tzinfo_signed_bench.rb):
  master fdab2521 versus fork 57c9c3a, entirely synthetic TZif files, no
  installed system tzdata dependency.

Both validate the pinned source-file hashes and report allocations only.
The standalone scripts were exercised off/on in interpreter/YJIT/ZJIT;
their [12 output receipts](data/workload-census/public-benchmarks.json)
confirm the same allocation deltas as the original finite cohorts. They
are public reproducers, not replacement or rerun performance cohorts.

### Corpus receipt reproduction

Use the existing dependency-only corpus helpers and the exact source/lock
pins in the receipts, not fresh app generations:

```sh
bash script/corpus real-blog-r4 workload-blog
bash script/corpus campfire-r81 workload-campfire
bash script/corpus fizzy workload-fizzy
bash script/corpus casa workload-casa --source-only
bash script/corpus codetriage workload-codetriage --source-only
```

Prepare dedicated production schemas and assets in these disposable copies,
including local PostgreSQL URLs for CASA/CodeTriage and CodeTriage's example
database config. The external CASA credential fixture is in the runner.
From each app directory, with the Ruby 4.0.7 frozen bundle and local services:

```sh
# Once after preparing the schema; refuses the already-prepared marker.
mise exec ruby@4.0.7 -- bundle exec ruby ../../bench/upstream/workload_census.rb prepare APP
mise exec ruby@4.0.7 -- bundle exec ruby ../../bench/upstream/workload_census.rb assets APP
CENSUS_MODE=interpreter mise exec ruby@4.0.7 -- bundle exec ruby ../../bench/upstream/workload_census.rb profile APP NEW_JSON
CENSUS_MODE=yjit mise exec ruby@4.0.7 -- bundle exec ruby ../../bench/upstream/workload_census.rb profile APP NEW_JSON
CENSUS_MODE=interpreter mise exec ruby@4.0.7 -- bundle exec ruby ../../bench/upstream/workload_boot_census.rb APP NEW_JSON
CENSUS_MODE=yjit mise exec ruby@4.0.7 -- bundle exec ruby ../../bench/upstream/workload_boot_census.rb APP NEW_JSON
```

Assets for CASA need its Node toolchain too (24.22.0 here); the app's missing
24.13.0 pin warning during a Ruby-only census is not an asset build pass.
Run workload_census_rank.rb with all ten warm profiles to reproduce the
warm TSV/JSON, or all ten boot profiles for the separate boot ranking;
mixing boot and warm profiles is refused. All output paths must be fresh.
The separate Cable probe uses the same boot/workload fixture and records
actual config/YAML calls.

## Experiments and handoffs

The PostgreSQL and TZInfo experiments use Ruby master
`8ff4ae135d438314090f0dc23916601ef9c444d5`, built with YJIT and ZJIT, and a
separate native gem home. Source hashes, observed modes, every sample,
JIT deltas and a protocol written before counting are retained. Twelve
serial shuffled rounds contain off-A/off-B/on in all three modes. Each case
has 3,000 warmups, 2,000 allocation operations and 10,000 CPU-time diagnostic
operations; query/fixture construction is outside endpoints. Paired percent
differences use 5,000 bootstrap resamples, seed 1729. A resolved positive
CPU-time interval rejects a candidate. A/A CPU intervals are reported, not
mistaken for the ±0.1% Ir gate. There is no speed claim, even if a CPU-time
interval excludes zero. Rejected cohorts remain rejected.

Independent Thermos reviewers were not launched under the instruction to
do this work ourselves. Semantic/source review and counterexample probes
are recorded here; a separate PR thread must complete independent
correctness/maintainability review before upstream submission.

### Handoff 1: PostgreSQL result fields

Fork: `thomasklemm/rails`, branch
`thomasklemm/reuse-postgresql-result-fields`, clean commit
[`220c4f2387290038dccb4d93e4e6b0bf81bc196a`](https://github.com/thomasklemm/rails/commit/220c4f2387290038dccb4d93e4e6b0bf81bc196a).
Base: Rails main
[`7e3828a6b573cfda08ad9985060bcaaf76358826`](https://github.com/rails/rails/commit/7e3828a6b573cfda08ad9985060bcaaf76358826).
Both identities are Thomas Klemm <github@tklemm.eu>; commit message has no
Amp/thread/co-author trailer. Remote branch head was verified after push.

The one-line hoist reuses the first genuine PG::Result#fields Array instead
of asking for a second one. It does **not** replace fields with nfields,
share a result across queries or eliminate all field-name Strings attributed
to that source line. pg 1.6.3 caches its frozen names; each fields call still
returns a fresh Array. A zero-column result follows the same branch and
clearing path; zero-row results still retain their columns and types.

| Case | Off objects/cast | On objects/cast | Every mode/round |
| --- | ---: | ---: | --- |
| No columns | 7.001 | 7.001 | unchanged control |
| Zero rows, two columns | 11 | 10 | −1 Array |
| One integer column | 10 | 9 | −1 Array |
| 32 columns | 72 | 71 | −1 Array |
| Unicode/binary/NULL | 16 | 15 | −1 Array |

All 15 mode/case cells pass the preregistered allocation rule in all 12
rounds. No CPU-time regression is resolved: interpreter median changes
range −2.64% to +1.06%, YJIT −3.11% to +1.41%, ZJIT −3.29% to +1.52%.
Intervals and A/A controls are noisy; for example interpreter's unchanged
no-column control has a −7.05% to +5.71% on/off interval. Some A/A CPU
intervals exclude zero. This **does not** establish a speed win, an Ir
result, JIT-flat execution or absence of small regressions. All raw windows
and their JIT deltas are retained; no rejected cohort was replaced.

Verification on the exact published source:

* Full upstream PostgreSQL adapter suite, before/after, Ruby 4.0.7,
  seed 1729, MT_CPU=1/PARALLEL_WORKERS=1: **11,076 runs / 40,096 assertions /
  zero failures / zero errors / 31 same named skips**. All 11,076 named
  outcomes compare equal, including the one outcome whose expected trigger
  warning splits its verbose result across lines. Skips are retained by
  identity in the outcome archive, not counted as coverage. PostgreSQL is 15.
* Genuine PG controls match in primary Ruby and master interpreter/YJIT/ZJIT:
  Unicode names/cells, binary data, NULL, arrays/JSON/numeric/date/time,
  duplicate column names, zero rows, affected rows and RETURNING, SQL error,
  independent columns/rows/nested rows/mutable cells, AR model subclass,
  frozen and cleared PG receivers, symbol field names. PG::Result subclasses
  cannot be allocated through the native allocator; no fake result protocol
  is used as evidence.
* RuboCop: **one file inspected, no offenses**. git diff --check passes.
  Existing public query tests are retained unchanged; no private call-count
  test is added for this behavior-preserving refactor.

Commands from the relevant Rails checkout's activerecord directory:

```sh
BUNDLE_ONLY=default:test:rubocop:db:cable PARALLEL_WORKERS=1 MT_CPU=1 SEED=1729 \
  mise exec ruby@4.0.7 -- bundle exec rake test:postgresql TESTOPTS='--verbose --seed=1729'
# From Lowrail root, native master gems installed in a separate gem home:
COHORT_RUBY=/tmp/u3-ruby-master/bin/ruby COHORT_GEM_HOME=/tmp/u3-master-gems \
  mise exec ruby@4.0.7 -- ruby bench/upstream/workload_cohort.rb NEW_DIRECTORY pg
```

Duplicate checks: current main still has both fields calls; historical
[#11955](https://github.com/rails/rails/pull/11955) concerned an older
implementation and was closed to retarget master, not rejected on semantics.
[#52461](https://github.com/rails/rails/pull/52461) added the present
column-preserving empty check; open
[#57517](https://github.com/rails/rails/pull/57517) is a reconnect-lock fix
whose inspected diff retains the duplicate. Searches for cast_result,
result.fields and PostgreSQL allocations covered open and closed PRs;
no competing current fix was found. #30411/#33312 were larger lazy-result
proposals, not this local reuse.

Contribution/AI policy: CONTRIBUTING.md, root AGENTS.md, the contribution
guide and PR template at the pinned base were read. The guide requires
representative benchmarks and the affected component suite; the template
does not require a changelog or new tests for an internal refactor without
behavior change. No AI prohibition was found in those files; AGENTS.md
explicitly addresses AI coding agents. This is a scoped file-policy check,
not a claim that all external policies were searched. Independent Thermos
and the separate upstream PR/submission thread remain the coordinator's
next step. No whole-app request benefit is claimed.

### Handoff 2: TZInfo signed zoneinfo transitions

Fork: `thomasklemm/tzinfo`, branch
`thomasklemm/signed-zoneinfo-transitions`, clean commit
[`57c9c3ad35c3fa08bb4d0310cf3f0e52ae01f961`](https://github.com/thomasklemm/tzinfo/commit/57c9c3ad35c3fa08bb4d0310cf3f0e52ae01f961).
Base/current upstream master:
[`fdab2521b1319d88445e22c9e34aa40794f3b917`](https://github.com/tzinfo/tzinfo/commit/fdab2521b1319d88445e22c9e34aa40794f3b917).
Both identities are Thomas Klemm <github@tklemm.eu>, with no trailers.
Remote head matches the published commit. The change replaces two unsigned
32-bit words and manual signed arithmetic with unpack('q>'.freeze)[0],
removing the now-unused private helper: **one insertion, fourteen deletions**.
It neither batches file reads nor changes truncated-read error boundaries.

| Whole TZif read | Off objects | On objects | All modes/rounds |
| --- | ---: | ---: | --- |
| Format 1 control | 37.0005 | 37.0005 | unchanged |
| 32 positive transitions | 160 | 160 | unchanged |
| 32 negative transitions | 288 | 160 | −128 intermediate objects |
| Six signed boundaries | 72 | 60 | −12 intermediate objects |
| Empty format 2 | 30 | 30 | unchanged |

All 108 workers pass the preregistered allocation/regression screen.
No positive CPU-time interval is resolved in interpreter, YJIT or ZJIT.
For the negative-transition case, diagnostic median/95% intervals are
−16.00% [−17.36%, −15.39%], −14.02% [−16.10%, −12.25%] and
−11.74% [−12.11%, −11.46%], respectively. These **are not speed claims**:
the experiment has no Ir/±0.1% A/A gate, and some other A/A CPU intervals
exclude zero. JIT window deltas and unchanged-control noise are retained.
No whole-boot latency or whole-app saving is claimed.

Verification on the published source:

* Complete upstream `rake test`, before and after, Ruby 4.0.7, seed 1729,
  runs all three data-source suites: **1,863 runs / 13,256 assertions**,
  **1,861 / 13,254**, **1,861 / 13,254**. Each has zero failures/errors and
  the same 22 named skips for removed Object#taint. All **5,585** named
  outcomes match, with suite identity retained rather than deduplicated.
* Whole-file probes cover formats 2 and 3, 272 independently generated
  boundary/random signed timestamps including both signed64 extremes,
  negative pre-epoch values, Unicode abbreviations, separate returned
  arrays/transition objects, frozen reader/path, reader and String-path
  subclasses, and identical malformed/truncated/unsorted error results.
  Three real system zones also have equal transition counts and digests.
  Before/after probe output agrees in interpreter/YJIT/ZJIT.
* Minimum supported MRI 1.9.3 and JRuby 1.7.27 q> support was checked in
  engine sources, **not executed**. The older-compatible unpack()[0] API
  is intentional; unpack1 is not used. Old engines, Windows and the full
  upstream multi-platform CI matrix remain unrun. No supported-version
  runtime claim follows from the source compatibility check.
* Existing public TZif tests already exercise signed transition semantics;
  no test of the deleted private arithmetic helper is added. diff --check
  and Ruby syntax checks pass.

```sh
# In each baseline/draft TZInfo checkout, with its frozen bundle:
mise exec ruby@4.0.7 -- bundle exec rake test TESTOPTS='--verbose --seed=1729'
# From Lowrail root, with the same master build/gem home as the PG screen:
COHORT_RUBY=/tmp/u3-ruby-master/bin/ruby COHORT_GEM_HOME=/tmp/u3-master-gems \
  mise exec ruby@4.0.7 -- ruby bench/upstream/workload_cohort.rb NEW_DIRECTORY tzinfo
```

Duplicate check: the latest default branch still uses manual reconstruction;
open/closed PR searches for unpack, signed, performance and zoneinfo found no
matching fix. README, gemspec, root file listing and CI policy were checked;
no CONTRIBUTING/AGENTS file or explicit AI prohibition was found there.
This is a scoped repository-policy check, not an exhaustive external-policy
claim. The separate PR thread still needs independent Thermos and supported
platform coverage before submission.

## Evidence files

* [Warm ranking TSV](data/workload-census/ranking.tsv) and
  [all ten raw warm profiles plus ranking](data/workload-census/ranking.json.gz).
* [Boot ranking TSV, compressed](data/workload-census/boot-ranking.tsv.gz) and
  [all ten raw boot profiles plus ranking](data/workload-census/boot-ranking.json.gz).
* [Cable 3.0.5 call counts](data/workload-census/cable-3.0.5.json),
  [4.1.0 cache contracts](data/workload-census/cable-4.1.0.json), and
  [3.0.5 real listener counts](data/workload-census/cable-poll-3.0.5.json),
  [4.1.0 real listener counts](data/workload-census/cable-poll-4.1.0.json), plus
  [retained-output/subclass counterexamples](data/workload-census/boundary-probes.json).
* [PG protocol](data/workload-census/pg-protocol.json),
  [summary](data/workload-census/pg-summary.json),
  [all 108 workers and genuine-result controls](data/workload-census/pg-cohort.json.gz),
  [all 11,076 matched suite outcomes](data/workload-census/pg-suite-outcomes.json.gz), and
  [duplicate search receipts](data/workload-census/duplicate-checks.json).
* [TZInfo protocol](data/workload-census/tzinfo-protocol.json),
  [summary](data/workload-census/tzinfo-summary.json),
  [all 108 workers and exactness controls](data/workload-census/tzinfo-cohort.json.gz),
  [all 5,585 matched suite outcomes](data/workload-census/tzinfo-suite-outcomes.json.gz),
  [priority-lead PR receipts](data/workload-census/priority-duplicates.json), and
  [file hashes/provenance](data/workload-census/manifest.json).
* [Mail EightBit allocation receipt](data/workload-census/mail-eightbit.json):
  108 attributed objects per mail operation in each mode (104 Strings,
  two SafeBuffers, two Arrays), not 108 proven removable allocations.

The boot/warm ranker independently reproduces both site-score maps; warm
TSV app-key ordering can differ with input order, not the weighted scores.
Before publication, all five app repositories were confirmed public; every
published text and decompressed receipt was inspected. Absolute orb paths
in provenance/JIT diagnostics are normalized to RAILS_BASE, RAILS_FORK,
TZINFO_BASE, TZINFO_FORK, RUBY_4_0_7, RUBY_MASTER, MASTER_GEMS and LOWRAIL.
No numerical measurement or source hash is altered by path normalization.
Gzip files contain numerical/source provenance, not credentials, private app
names/paths or heap contents. Builds, corpus trees, databases and raw service
logs remain unpublished.
