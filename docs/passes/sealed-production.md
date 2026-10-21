# Passive production token and collection units

**One accepted whole-request price: interpreter Ir on one blog endpoint and
fixture.** `sealed/token_tag` and `sealed/collection_render` have public
build/runtime certificates. The measured production form/token/collection
units are separate from the rejected [combined pricing specimen](sealed-combined.md).
That specimen stays rejected and is not measured again. This is not a Rails
throughput/latency claim or a whole-app result. No default-tier, quarantine or
guarded-pass behavior changes.

## What is certified

Both units use a first **natural original operation** as their witness. The
observation seams are installed identically in explicit sealed off/on arms;
only an admitted on arm takes the fast path. Admission has one try-lock
attempt, checks actual native holders, stock method/body/visibility and source
fingerprints, and rechecks the seal epoch before publishing. Failure is
terminal with a reason in stats/explain. There is no runtime objspace,
materialization, view construction, template lookup, compilation, schema
probing or on-only prepend. Build-only inventory remains build-only.

- **Token:** retain live protection policy, token generation/masking, name
  conversion and autocomplete policy. Literal tag output requires plain
  String name/value, the exact cached view/tag-builder context and the known
  action/method options. Unknown inputs or epoch changes after generation
  continue at stock `tag` with the already generated/converted values; they
  do not replay generation or conversion. SafeBuffer, Array, Regexp and nil
  values are original tag continuations, not forced into a String shortcut.
- **Collection:** specialize only stock `collection_with_template` with a
  nonnil template and no layout. Keep live collection derivation/loading,
  lookup, iterator/preloading, local-name/cache-key effects, `Template#render`,
  events and rendered-result objects. This removes fewer branches than the
  old pricing adapter: **there is no cached-template lookup shortcut** and
  no transfer of its isolated or request prices.
- **Form composition:** unwrap only the exact source/body-certified symmetric
  token observer when checking the original helper beneath it. Arbitrary
  helper overrides still refuse. Existing form admission is otherwise intact.

The first production domain deliberately inherits the existing narrow
Ruby 4.0.7 / Rails 8.1.4 stock-blog build inventory. This is not a general
token/collection support claim, a lazy-app certificate, or a test-environment
certificate. The known broader all-sealed Template/Preloader ancestry failure
is not repaired or normalized by these units.

## Explicit fixture boundary

[`BlogShowGetOnly`](../../fixtures/corpus/blog_show_get_only.rb) is a separately
named, tracked fixture, **not a hidden BlogProduction variant**. It creates
fresh schemas and inserts three literal articles and three comments, with
comment counts 2/1/0 and a fixed timestamp, without callbacks/jobs. Preparation
refuses existing SQLite storage. Parent-only read-only validation checks all
rows and absence of queued jobs before cold workers start. The fixture digest
is a required pin in the [numeric gate export](sealed-production-results.json).

The old `db/seeds.rb` snapshot is retained as the named failure
**`historical_seed_six_unfinished_turbo_jobs`**. Both entropy companions reject
`rejected_async_completion` in all three restored arms: six ready
`Turbo::Streams::ActionBroadcastJob` jobs, no supervisor, no completed snapshot.
Its cold equality does not waive async completion. Raw capture digests and
the actual refusal records are retained in the export; the dedicated terminal
completion regression continues to exercise pending work and a held Cable
writer. No jobs were deleted from that seed to make it pass.

Any future price uses **only the new fixture** for all candidate/control arms.
It must not be compared with −17.86%, older form prices or any older cohort.

## Executed gates

The public CLI regression builds an isolated artifact containing exactly
form/token/collection, with no delivered files/templates. The reusable
[`sealed_production_check.rb`](../../bench/experiments/sealed_production_check.rb)
then runs restored production workers, not a pricing installer:

1. Raw off/off/on remains `rejected_off_control` for real entropy/clock fields.
   Both declared entropy seeds pass exact off/off/on comparisons of full cold
   ancestry, feature/load order, hooks, ordered SQL, events, response and
   parent-read exit effects, including the async completion boundary. No
   `Templates::CompiledSource` or `PreloadPlans::Hook` occurs in any arm; no
   census field is dropped.
2. **192 ordinary + 192 header-writing render-subscriber pairs** have identical
   status/body/all headers, SQL, events and assigns. Each on arm records
   **form104/token398/collection87** hits and **62 collection fallbacks**.
   The latter remain visible; the nonnil-template/no-layout domain does not
   cover all negative/alternate rendering cases. Off hit counters are zero.
3. After natural admission, **50 native show requests** give
   **form50/token200/collection50**, zero fallbacks/refusals. Epoch deopt gives
   original-path fallback counts **1/4/1**, with no further hits.
4. Public regression additionally compares literal and unsupported live token
   values against the stock continuation, including output class/encoding and
   once-only generation/name conversion. Tampered observer certificates leave
   three successful original requests, zero token/collection hits and explicit
   terminal refusals. No wrong-answer special cases are added.

Reproduce the self-contained build/fixture/gate regression under the repository
Ruby with an available `real-blog-r4` corpus:

```sh
LOWRAIL_TEST_CORPUS_ROOT=/absolute/corpus/root \
  ruby -Igem/test gem/test/form_scaffold_test.rb --name /passive_production/
# For an already prepared, isolated app and the unchanged fixture snapshot:
ruby bench/experiments/sealed_production_check.rb APP SEED_STORAGE NEW_OUTPUT
```

The scheduling/counter prerequisite is separate: the actual Callgrind
`gc_exclusion` regression executes the native counter, rather than only its
stub, outside slots/cohorts. Affinity/CPU/overlap observations remain symmetric
and outside window endpoints; unavailable migration counters remain null.

### Broader validation and a caught integration regression

The first full primary suite recorded **173 tests / 5,918 assertions, three
failures, zero errors, two named Rails-checkout/bundle skips**. One failure is
the unchanged all-sealed cold-ancestry gate. The others were not dismissed:
the old-artifact test's explicit matrix grows from 27 to 33 cases for the two
new sealed pass IDs, and the new observer had allocated an extra initialization
TracePoint that correctly retired memo's tracing-sensitive fast path.

Clean main passes the same production-activation regression (1/91); the draft
fails it, and the corrected observer plus manifest matrix pass **8/178**. The
observer now uses Rails' existing `after_initialize` load hook directly: it
needs completed Zeitwerk aliasing, not a new initialized-app TracePoint.
Memo's conservative trace policy and all guarded passes are unchanged. The
dedicated Rails report rerun passes **3/17**, zero skips. The final affected
suite and published source/artifact pins are recorded in the numeric export;
the original failed run remains reported, not relabeled green.

The corrected strict run records **170 tests / 3,552 assertions, one failure,
zero errors/skips**: only the retained all-sealed cold-ancestry failure above.
It includes every gem test file except the unchanged `inertia_props_test.rb`
(its three tests passed in the initial full run). Cargo passes **39 + 1 + 8**.
Actual counter/placement regressions pass **3/155**; the separately pinned
512-MiB-brk counter regression passes **1/13**, with zero skips. These are
untimed prerequisites, not an app cohort or a speed result.

## Accepted finite interpreter cohort

Measured commit:
[`ae025b0`](https://github.com/thomasklemm/lowrail/commit/ae025b0d9f456d9f9bef55e9e131bc25178e83cb),
Ruby **4.0.7**, Rails **8.1.4**, actual **interpreter**, production
`GET /articles/1` on **BlogShowGetOnly** only. The three-unit manifest is
`5271a66ff71c44f4276363adef136f65cadc2e1b7729ef6f2e953dd0d212d7e6`;
the fixture is
`21a0de39f113d57e9303967b801c7b34d86aca7bcfcbe8c3d94013914cf5c970`.
Full runtime, harness, app, lock, native and tool pins are in the
[numeric export](sealed-production-results.json), alongside all six round
rows, complete summaries and all 18 worker records / 72 windows.

One separately authorized cohort used slots 1+2, six randomized rounds,
seed **41231**, off-A/off-B/production, **N=0/50** subtraction, real entropy,
the unchanged five heap floors and the pinned **512-MiB-brk** tool. Maximum
observed worker-process envelope concurrency is **two**. Both slots were
released after all 18 workers finished. No retry, excluded round, rescore,
older-price comparison or additional cohort. **No YJIT cohort**; that method
is parked and interpreter Ir remains primary.

The harness ran from a **clean detached worktree at the measured commit**.
Each worker recorded its actual revision, clean state, harness aggregate,
Ruby description and private metadata-wrapper SHA before and after execution.
The original source-path runtime worktree was also clean at that commit; its
bytes and the artifact were not rebuilt or relocated. The wrapper only checks
pins outside the unchanged shared worker's windows; it installs no pricing
adapter. Its executed source and the driver's source are retained in the export.
Source, framework, native, tool and artifact hashes match before and after.

The first command **refused `RAILS_ENV=nil`** at parent manifest preflight,
before creating a cohort directory or any counter worker. Only the explicit
production command environment was corrected. This was not a counter retry.

### Result and gates

**Accepted by the shared harness: total AND GC-excluded A/A pass.** Values
below are per-request medians and nominal 95% bootstrap intervals over the six
independent round pairs, not independent samples for each request.

| Metric | Off-A / request | Production / request | Production Δ% [95% interval] | Off-B/A Δ% [95% interval] |
|---|---:|---:|---:|---:|
| Total Ir | 8,803,370.57 | 7,440,039.03 | **−15.492980 [−15.511296, −15.461565]** | −0.029975 [−0.047392, +0.028585] |
| GC-excluded Ir | 8,804,989.22 | 7,439,041.47 | **−15.509265 [−15.527966, −15.471767]** | −0.037196 [−0.055493, +0.015382] |
| Allocated objects (diagnostic only) | 2,281.14 | 1,870.60 | −17.994038 [−18.012700, −17.977800] | +0.003945 [−0.010521, +0.015785] |

- Both instruction A/A intervals contain zero and stay within **±0.5%**.
  All five slot-range/exact-page heap gates, brk preflight/worker checks and
  actual-interpreter/JIT-state checks pass. All 72 counter dumps independently
  reconcile with exported totals and all 36 N=0 subtractions reconcile.
- Every window has **zero minor/major collections**. Total and GC-excluded
  windows are separate executions, not one trace with GC removed. Their
  difference is not GC savings. The allocation figure is diagnostic only.
- The **JIT-specific idle companion is not applicable to interpreter** and
  was not run (`idle_boundary` is absent); it is not relabeled an executed
  pass. The normal request-settle seam ran in every worker.
- All 72 windows retain symmetric thread CPU/affinity and overlap endpoints:
  affinity `0-7`, 32 windows overlap a peer counter envelope and 48 overlap
  a peer worker-process envelope. These are conservative envelopes, not a
  census of unrelated host load. **Migration counts remain null/unavailable**;
  equal endpoint CPUs do not establish zero migrations.
- All six on workers finish with all three production admissions active and
  no refusal. Post-cohort untimed cold and **192+192** controls pass again,
  with paired hits **104/398/87**, 62 collection fallbacks retained, and
  native 50-show hits **50/200/50**, zero fallbacks/refusals. Witness work is
  outside warm windows, not a controlled cold-latency estimate.

This establishes reduced **interpreter instruction work for this one endpoint
and fixture** with these production units. It does not establish native
latency, YJIT performance, arbitrary subscribers/apps, test-tier admission or
the broader all-sealed ancestry gate. No comparison with another fixture or
the rejected pricing specimen follows.
