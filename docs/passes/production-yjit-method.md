# Production form/token/collection: untimed YJIT method review

**Stage 1 only. No Callgrind or timing cohort is authorized or launched.**
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
These log events do not identify the thread, caller, threshold count or
entry-chain reason; do not assert that the reaper caused this particular
installation, or transplant the historical 119/120 observation as its count.

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

If a causal account rather than a conservative gate is required, a future,
separately approved **native diagnostic only** must retain effective pool
frequencies, thread/caller, per-entry counter and elapsed time at the actual
transition. No new diagnostic was run for this note. No forced helper calls,
reaper/config changes, compiler mutation or tracing in a price worker.

### Proposed bounded rule, for review only

Retain exact mode/artifact/cold/heap/log/window/idle/provenance controls. After
the same 10,000 rehearsal requests, sample all eight fields every **200 ordinary
requests plus the original N0/GC seam**. Stop successfully only after **K=10
consecutive quiet intervals**; reset that streak on any change. Record every
interval and the reached request index, not just the final quiet prefix.
Cap certification at **20,000 requests** and the complete warmup at **180
seconds**, whichever comes first; cap/missing field means refusal. No extension,
second process, counter exclusion or alternate parameter after seeing results.
Every off-A/off-B/on worker must reach quiet independently; no transplanting
one arm's warmup length or declaring the other arm warm by symmetry. If any
worker refuses, the declared candidate/cohort rejects in full.

This **constructs an observed quiet prefix on successful completion**, not
guaranteed termination, compiler closure or a flat future window. It resembles
the parked v3's bounded quiet mechanism and is **not evidence that v3's
pending-entry/branch/exception problems are solved**. In particular a quiet
prefix can precede a later reaper wake or an entry stuck below threshold.
All actual windows must still be flat and both A/A intervals must pass;
otherwise refuse. A/A may be **expected under the controls, never guaranteed**.
Do not derive a fixed 12,400- or 14,000-request rule from this single observed
transition: a time/caller-driven event need not repeat at that request index.

**No YJIT stage 2, v2 execution or cohort follows from this note.** The owner
must review the causal-evidence gap and whether an additional native-only
diagnostic is worth doing before authorizing anything further. `835cf16`
remains parked; interpreter Ir remains primary.
