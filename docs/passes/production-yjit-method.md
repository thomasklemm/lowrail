# Production form/token/collection: untimed YJIT method review

**YJIT stage 1 only. No YJIT Callgrind or timing cohort is authorized or launched.**
The separately authorized [interpreter re-price](production-interpreter-reprice.md)
is complete; it does not execute this method or rescue its rejection.
The specimen is the current public production artifact, exactly
`sealed/form_scaffold`, `sealed/token_tag`, `sealed/collection_render`, on
**BlogShowGetOnly GET /articles/1**, Ruby 4.0.7 / Rails 8.1.4. No link, AR,
preload, template delivery, default-tier or quarantine changes. The token
continuation safety fix is included. The historical **−15.49% interpreter Ir
on one blog endpoint and fixture** stays scoped to
[`ae025b0`](https://github.com/thomasklemm/lowrail/commit/ae025b0d9f456d9f9bef55e9e131bc25178e83cb),
not this source, YJIT, wall time or Rails generally.

## Decision rule, registered before the native dry run

Flat compilation counters cannot make statistical A/A pass **by construction**.
They remove one observable confound; unrelated heap/layout/scheduler effects
remain. The rule is **strict-flat, fixed-budget, all-workers, no rescue**:

1. Separate public builds use `--env production --sealed --jit interpreter`
   and `--jit yjit`. Exactly three units, zero files/templates. JIT flags are
   not artifact certification: each runtime must report the requested actual
   mode, active natural admissions and no refusal.
2. Run the existing cold off/off/on controls in the actual mode, both seeded
   entropy companions, both **192-pair** controls, and native/deopt checks.
   Keep raw off-control rejection; never normalize headers, ancestry, feature
   order, SQL, events, assigns or post-exit effects. Source/lock/entropy pins
   stay unchanged. These are correctness gates, not speed observations.
3. Pin a **clean detached harness SHA in every worker before and after**,
   together with app source/lock, manifest, fixture, runtime/harness files,
   actual Ruby executable, native binary and counter-extension hashes.
   A different current-main revision needs fresh certification, not a claim
   that an old artifact prices it. No live edits, default threshold changes,
   compiler writes, forced helper calls, Binding inspection or heap census
   in a measurement worker. `LOWRAIL_STATS` is off there; coverage is separate.
4. Preserve the common fixed-heap worker and its actual N0/N50, total/no-GC
   endpoints, GC, observers, idle preparation and settling. Default YJIT
   thresholds remain unchanged. The native research candidate uses exactly
   **10,000 rehearsal requests (200 × N50/N0 + GC)** and **2,000 certification
   requests (10 × N200/N0 + GC)**, following the common initial 50 requests,
   idle request and heap preparation. No adaptive extension or retry. Require
   all ten certification intervals and every actual window to be flat.
5. Require integer, unchanged `compiled_iseq_count`, `compiled_iseq_entry`,
   `compiled_block_count`, `compiled_blockid_count`, `invalidation_count`,
   `code_gc_count`, `compile_time_ns`, and full YJIT compile-log byte count.
   Missing counters/logs mean **unknown/refuse**, not zero. Include N0 windows;
   observer/endpoint compilation also rejects rather than being subtracted or
   excluded as free compiler work. No `--yjit-stats` profiling overhead.
6. Native flatness is **not** measured-window flatness or pending-entry
   closure. [The parked method](yjit-regression.md) demonstrated entries stuck
   at 119/120 and late compilation even after quiet native warmup; ordinary
   repetition cannot force every entry/branch/exception path. This candidate
   does not implement v4 or silently remove its pending-entry/attempt-visibility
   blockers. A green dry run alone cannot authorize a cohort. A red one stops
   this candidate; retain it, do not extend warmup until green.

The bench-only [native driver](../../bench/experiments/production_yjit_dry.rb)
runs each off-A/off-B/production arm once in each phase order: **six native
processes**, sequential, seed 41231. It executes the unchanged shared heap
worker and native counter extension **without Valgrind**. Counter client
requests are inert outside Valgrind; no instruction/timing estimate is
calculated. All six records, failures and logs are retained. It does not
consume a Callgrind/timing slot. The production checker now selects its
mode from the manifest; its default interpreter behavior is unchanged.

## Original conditional stage 2 proposal — superseded, never executed

After accepting the stage-1 rejection, the coordinator explicitly declined
YJIT stage 2. A **separate interpreter-only** reprice is authorized using the
already accepted interpreter protocol, not the joint proposal below. The
original declaration remains here to preserve what preceded the dry run.

Do not launch while the entry/attempt-admission blocker remains unresolved or
the native candidate rejects. A supported way to prevent new compilation
after warmup would be stronger, but this Ruby exposes no public freeze API;
do not invent one or patch production as part of this task. Any Ruby/tool or
runtime change needs its own review and new pins first.

After an accepted method and explicit approval, use **one finite declaration,
one slot/one worker at a time**, containing interpreter and YJIT strata on
the same then-current runtime/fixture. Six independent randomized rounds,
seed 41231, off-A/off-B/production; N0/50, both phase orders balanced by round,
five floors `[1000000,250000,100000,20000,10000]`, exact page gates and the pinned
brk512 tool. Eighteen counter workers per mode, 36 total, not 36 retries or
independent opportunities to select a result. Interpreter Ir is primary;
YJIT Ir is a distinct secondary result, not throughput. Keep all guard,
witness, dispatch and continuation work in the specimen. Allocations remain
diagnostic.

Both total **and** GC-excluded A/A 95% intervals must contain zero and lie
within ±0.5%, separately in each mode. Every heap/page/brk/provenance/mode,
actual-window JIT and completed-hit gate must pass. Preserve required untimed
idle companions for YJIT (not applicable in interpreter); a native companion
cannot certify a Valgrind worker's flatness. No measurement worker census or
compiler-cost exclusion. A failure rejects the declared joint cohort; report
both strata descriptively, no accepted saving from a surviving subset, no
worker/round exclusions, retry, threshold relaxation or comparison to old
prices. A separate counted companion must show **1 form / 4 token / 1
collection hits per warm request, zero fallbacks**. The cold/negative checker
intentionally exercises unsupported collection inputs, so its retained
fallbacks are not falsely described as a zero-fallback catalog.

## Untimed evidence

**Rejected, as registered.** The [numeric export](production-yjit-method-results.json)
records all six native processes at clean detached
**local** `f34a35c578937ead3853d2b10290d57ead862a06` (not the rebased publication SHA),
before/after pins, full certification histories and all 24 window snapshots.
No Valgrind, timing estimate, A/A cohort, slot use, exclusions or retry.

- A fresh `build --env production --sealed --jit yjit` certifies exactly the
  three production units. Manifest:
  `822ec9f50b670360774236fd863ccd25aeaf6cf567f4030332e492dc60a2f5ff`.
  Actual certification/admission/current/after-initialize mode is YJIT,
  no drift/refusal. Runtime/source/lock/Ruby/native/fixture pins are retained.
- Both seeded cold off/off/on comparisons and **192+192** controls pass.
  Raw entropy is still `rejected_off_control`. Paired hits are
  **104/398/87**, with **62 collection fallbacks retained** per control.
  Native 50 shows complete **50/200/50 hits, zero fallbacks**; after global
  deopt, **1/4/1 fallbacks** and no extra hits. The warm per-request coverage
  is **1/4/1**, not a claim about every cold/negative scenario.
- All six processes exit 0; every counter/log field is available. All **24/24
  actual native windows** are flat. Five workers reach 10 quiet certification
  intervals; **production/order0 reaches only 8/10**, so the whole native
  candidate rejects. Do not rescue it with the flat windows or other workers.
- At its request-400 snapshot, relative to request 200: entry **1344→1345**,
  blocks **41932→41934**, log **7059777→7060185 bytes (+408)**, compiler time
  **1774436172→1774654113 ns**; ISeq count stays **2861**, invalidations **965**,
  code-GC **0**. The exact added log range names two `ConnectionPool#discarded?`
  blocks at `connection_pool.rb:577`, indices 0/3. Sampling locates the work
  in **requests 201–400**, not necessarily the exact 400th request.

An earlier missing-sealed-opt-in preflight launched no native worker. The
initial six launches at `a50532c` used a relative script path after `chdir`:
all exited before app boot/warmup. That launch failure remains retained; only
the path was corrected before the one completed native candidate. The final
checker regression was also corrected: off-only wrong-app checks need no
`Lowrail` constant; mode is read directly from RubyVM. Existing strict
interpreter production regressions pass **2 runs / 123 assertions / 0 failures,
errors or skips** after that correction. The completed dry run is attributed
to its actual SHA, not that subsequent checker fix or upstream updates.

## V2 design only — not implemented or executed

### What the retained evidence actually explains

This is a **late additional entry installation**, not first discovery of a
new ISeq: the method already has five log events before certification in
every worker. All six eventually show the same additional indices 0/3:

| Arm | First five→additional two events, seconds | Additional events relative to certification |
|---|---:|---|
| off-B/order1 | 0.164 | before |
| off-A/order0 | 0.199 | before |
| off-A/order1 | 0.165 | before |
| off-B/order0 | 0.181 | before |
| production/order0 | 58.955 | requests 201–400 |
| production/order1 | 59.083 | just before |

Thus the **compilation exists in both off/on**, but its phase is not symmetric.
It is not an on-only new dependency. A fixed request count is an unreliable
surrogate for the normal-entry counter or elapsed-time/background execution.
Those original log events do not identify the thread, caller, threshold count
or entry-chain reason. The separate diagnostic below now establishes the on
mechanism, not retroactive caller provenance for all six original processes.

Rails 8.1.4's [method](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb#L577-L579)
is only `@connections.nil?`, not a deferred expensive method body. Real callers
include conditional request-end `release_connection`, new-connection creation,
and the background [AR Pool Reaper](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/connection_adapters/abstract/connection_pool/reaper.rb#L87-L119),
which calls it while filtering pools and through maintenance. The default
[reaping frequency](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/database_configurations/hash_config.rb#L209-L212)
is the minimum of 20 seconds, idle timeout, max age and keepalive (normally
**20 seconds**, not an assumed 60). Three ticks could line up near one minute,
but neither tick/caller nor the worker's effective configuration was recorded.
The **hypothesis** is that optimized request-call topology leaves an entry
pending until a different, possibly periodic caller advances it. The logs
prove the delayed installation and phase asymmetry, not that mechanism.

### Authorized scratch-only caller diagnostic

After the interpreter re-price, exactly **one off and one on native YJIT
process** used the retained local `f34a35c` runtime and its original certified
YJIT artifact (`822ec9f…`). Both executed the preregistered 50 initial requests,
200×50, 10×200, GC between batches, then idle to a fixed 90-second observation
horizon; 180-second process cap, 190-second external timeout. This is a separate
scratch workload, not the complete shared heap/idle worker, a candidate retry,
a flatness pass or a price. The [caller export](production-yjit-caller-results.json)
retains exact source/binary/artifact identities, recorder source as inert data,
all events, missing observations and both final records. No Valgrind or slot.

Hardware data watches observed the real ISeq's normal-entry count and installed
pointer; hardware execution breakpoints observed the installed normal entry and
the reaper's natural sleep. Ruby caller/thread frames were read from stopped VM
memory. No target wrapper/TracePoint, forced helper call, compiler write, app
configuration change or Binding inspection. Debugger stops perturb scheduling;
event clocks locate causes, **not** performance. The recorder is absent from
every priced artifact and all runtime/harness files used in a counter worker.

**On evidence:** boot count 12, threshold 120; the request phase leaves the
normal-entry count at **91**. Primary/cable/queue/cache all retain their actual
**20-second** reaper frequency. One `AR Pool Reaper` thread contributes **10
normal-path invocations per tick**: four WeakRef-filter dispatches, reap, flush,
prepopulate, and three sequential-maintenance checks. Its counts are:

| Reaper tick | Normal-entry increments | Installed normal-entry executions | Distinct observed normal-path calls |
|---|---:|---:|---:|
| 1 | 92–101 (10) | 0 | 10 |
| 2 | 102–111 (10) | 0 | 10 |
| 3 | 112–120 (9) | 2 | 10 |
| 4 | none | 10 | 10 |

The third tick's `keep_alive → sequential_maintenance → synchronize →
discarded?` call crosses **119→120**, then installs the normal entry on the
**same reaper thread**. The request count is fixed at **12,050**, phase idle;
installation is about 59.3 seconds after recorder start. The compile log adds
the same indices 0/3. This is a **periodic caller crossing a call-count
threshold**, not a lazy request-400 branch or a new ISeq. The source-pinned Ruby
[entry path](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/vm.c#L521-L528)
immediately [executes the installed function](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/vm.c#L561-L571)
on the triggering invocation: tick 3 observes that call twice, not eleven
distinct calls. Direct JIT-to-JIT entries are outside this normal-entry counter
and recorder; these are not total application call counts. All 108 increments
13–120 are retained. One early request-1/call-20 stack read is unavailable;
the counter and every reaper/installation context remain recorded.

**Off limit/failure:** `handle SIGSTOP … noprint` also disabled GDB's stop, so
the off app completed without an installed recorder. GDB subsequently errored
at the edited command-file cursor. The signal setting was corrected for the
one on process; **the off process was not rerun**. Its final count/entry is
120/installed, but there is no off caller/tick provenance. The original six
logs still show this extra compilation in both arms, early in off and late in
on; identical caller/topology in off is **not established**. Both native apps
finish 12,050 requests, and on ends with all three admissions active. No speed,
full observation or equivalence claim follows from these diagnostic processes.

### Revised bounded rule — inside each Valgrind worker, design only

The native-calibrated **10 quiet 200-request intervals / 180 seconds** proposal
above is superseded, not executed or extended until green. A 20-second reaper
clock advances at different request indices under Valgrind and across off/on.
Neither native completion nor a fixed request index certifies a priced worker.

Proposed preregistration for a separately reviewed candidate:

1. Retain exact mode/artifact/cold/heap/log/window/idle/provenance and both A/A
   controls. Start from the common initial-50/heap/idle preparation, **not a
   native-derived 10,000-request certificate**. Sample all eight fields after
   each 200 ordinary requests plus the original N0/GC seam **inside the actual
   Valgrind process**. Reset quiet on any field change.
2. Require **K=10 consecutive quiet intervals AND a quiet elapsed span of at
   least four times the largest observed reaper frequency (80 seconds here)**.
   That is an elapsed minimum, not proof that four ticks actually completed.
   No sleeping to avoid a future window, threshold change, reaper suppression
   or forced method calls. Each off-A/off-B/on worker must reach this itself.
   Record every interval, reached request index, actual elapsed span, effective
   frequencies and all counters/log sizes. No native transplantation.
3. Preregister **20,000 warmup requests / 3,600 seconds per worker**, whichever
   comes first, as hard limits appropriate to the instrumented process, not
   a rescaling after observing a failed run. Cap, missing field or worker failure
   rejects the entire finite cohort; no retry, extension or selected subset.
   These new bounds need owner review before implementation or execution.
4. Require all eight observations flat across **every actual N0/N50 window**
   and its conservative endpoint envelope in that same process. Pending normal
   entries, other callers/branches/exceptions and late background compilation
   can still invalidate a quiet prefix. Keep compiler work charged; reject it,
   never subtract or exclude it. `835cf16` remains parked.

### Background work: attribution prerequisite and symmetric bound

JIT flatness does **not** say that the reaper did no already-compiled work.
The conservative proposed bound is **zero reaper-thread work in the envelope
of every window**, in every arm including N0. An overlap, unavailable thread
identity, new/unmapped thread or unavailable exact counter rejects the **whole
cohort**. Do not move/repeat a window to dodge a tick or drop its Ir afterward.
This policy can reject a perfectly correct specimen; that is a reported result,
not a reason to weaken the rule. Keep the primary Ir total process-wide, with
all background and observer work charged. No main-thread-only speed claim.

This needs an independently validated **bench-only all-thread attribution
adapter**, not the scratch native recorder in a price worker. The existing
Linux CPU endpoints are too coarse to prove zero short reaper work. Simply
adding `--separate-threads=yes` to the current worker is also **incorrect**:
Callgrind's [client dump/zero requests](https://valgrind.org/docs/manual/cl-manual.html#cl-manual.clientrequests)
then cover only the issuing thread, while external monitor dumps cover all
threads. Before any cohort approval, an adapter must establish stable
Ruby/LWP/Valgrind thread mapping and all-thread reset/dump envelope semantics,
retain every thread's costs, and demonstrate that background-only work is
detected without losing it from the primary total. An external monitor scrape
may conservatively bracket the real counter endpoints, but may not be treated
as an exact endpoint or used to erase work. Missing capability means refusal.
**No such adapter was implemented or executed here.** No production method or
app config change is proposed; any additional runtime seam needs prior approval.

The successful stop condition constructs only an **observed quiet prefix**,
not termination, pending-entry closure, future flatness or symmetry of ticks.
A/A may be **expected only conditionally**, never guaranteed. The same reaper
tick is wall-clock driven in all arms, and equal tick counts would not alone
prove equal work or clean windows. The zero-overlap attribution prerequisite
is additional to both statistical A/A intervals, not a replacement for them.

**Stop for owner review. No YJIT v2 execution, measurement cohort or further
native retry is authorized by this note.** Interpreter Ir remains primary.
