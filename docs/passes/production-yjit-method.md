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

## Conditional stage 2 proposal — requires a separate approval

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

Pending the single registered native execution. Publish the actual worker
revision, mode-specific artifact, gate summary, per-request coverage and
before/after counters, including rejection. This section is not a promise
that this candidate will pass, nor an approval request to measure yet.
