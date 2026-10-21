# Why lowering lost under YJIT

2026-10-20. **The config binder is not the primary regression. A boot-time
global `TracePoint(:return)` leaves VM-wide `trace_leave` instructions after
disable.** YJIT exits on those instructions; the interpreter also pays a
trace-dispatch tax. Merely checking that no TracePoint remains enabled, or
comparing disassembly, misses it. Production activation now targets only
`Application#initialize!`; cold delivery records its witness in Loader.
No pass body, admission certificate or guard was weakened in this fix.

This is a diagnosis, not pass promotion. The separately accepted pre-fix
Starter JSON cohort reported +16.339% Ir under YJIT and −6.947% interpreter;
HTML reported +16.459% at only five binder hits instead of eleven. Those
numbers motivated the zero-hit activation control. Subsequent measurements
must rebuild source-pinned artifacts and satisfy every request gate again.

## Cause ranking

1. **Confirmed, process-wide: global return tracing at boot.** With the pass
   activated but its prepended binder removed, calls again resolve to the
   exact original binder and there are **zero variant hits**, yet trace exits
   remain. This falsifies a solely per-hit/emit-shape explanation. There are
   no live observers and no BOP invalidations in these native probes.
2. **Confirmed, local to props: reflective guards create singleton classes.**
   The asymmetric real `PropsResolver#resolve` micro loses 68.962% with its
   existing guard. Replacing only that guard with a prevalidated G slot
   changes it to −11.255%; keeping the original method shape but changing
   `each_with_object` to `each` gives −11.435%. The guard causes 17 extra
   singleton-class send fallbacks per resolution. This is independent of the
   global boot defect, and is not permission to remove exact checks.
3. **Confirmed but smaller: dispatch/guard residuals.** Inline branches,
   array/hash guard reads, dynamic keywords and polymorphism have measurable
   local costs. They do not explain the flat whole-request config penalty.
4. **Not supported as the config cause:** BOP redefinition, G/K/V container
   writes invalidating constants, BMETHOD alone, and blank-line/ISeq layout.
   Weak maps/finalizers were not individually isolated; direct installer
   activation without boot observers has no material unrelated-work penalty.
   The sealed study separately contradicts different bytecode/compiler
   options in untouched delivered methods (45 identical executable trees).
   That comparison does **not** inspect live VM trace patching.

## Native full-request counters: retain the zero-hit control

Ruby 4.0.7, Starter `/dashboard` JSON, native instrumented YJIT, after warmup,
50 requests. These are counter probes, **not Callgrind speed measurements**.
“Restored” deletes only the diagnostic prepend's `bind_controller` method
after full setup; no request passes through the lowered binder.

| Counter | Off | Activated binder | Activated, restored original |
|---|---:|---:|---:|
| Window `exit_trace_leave` | 0 | 114,450 | 128,200 |
| Window side exits | 400 | 114,800 | 128,550 |
| Compiled ISeqs before window | 2,794 | 2,792 | 2,792 |
| Compiled blocks before window | 40,986 | 32,123 | 32,101 |
| Inline code bytes | 3,734,226 | 3,040,148 | 3,040,202 |
| Outlined code bytes | 3,294,179 | 2,763,305 | 2,689,044 |
| Boot `invalidate_everything` | 0 | 2 | 2 |
| Boot BOP invalidations | 0 | 0 | 0 |
| Window compilation/invalidation | 0 / 0 | 0 / 0 | 0 / 0 |

The reduced compiled-block/code footprint is not better optimization: many
returns now exit instead of staying in native code. The export retains
nonzero `send_iseq_*`, `send_cfunc_*`, splat, keyword, singleton and megamorphic
counters. These vary with the executed request path, but `trace_leave`
dominates this new exit population. A boot invalidation alone would not
explain the continuing flat-window tax; the sticky instruction mask does.

The one finite pre-fix full-request diagnostic in this thread was **rejected**:
total-Ir A/A excluded zero and JIT flatness failed. Its raw +16.499% binder and
+29.517% restored-original deltas remain in the export, not accepted effects
or a replacement for the originating accepted +16.339% cohort. No retries.

## Post-fix whole-request checks: one finite cohort per mode

Measured boundary:
[ed7cbbe](https://github.com/thomasklemm/lowrail/commit/ed7cbbe8f8ab6e9b7be24775ac76a94cebecd95e),
Ruby 4.0.7, same Starter JSON route/headers, pinned brk512 Valgrind, six
rounds and at most four workers. A public format-2 production `--sealed`
build excludes unrelated passes through the existing denylist: exactly one
config-bind unit, no delivered files/templates. The custom request probe
uses the **actual app root**, not generic request-pair snapshot wrappers.
At that boundary the latter needed a separate real-root/artifact-directory
seam for format-2 file delivery; relocation admission was not bypassed here.
The subsequent
[artifact-directory seam](https://github.com/thomasklemm/lowrail/commit/cb832658d52e0a9f440d51ccac7dd985ceb09f2a)
provides `LOWRAIL_DIR` while keeping the certified app root unchanged.

| Mode | Total Ir vs off, 95% interval | Gates / interpretation |
|---|---|---|
| Interpreter | **−10.156% [−10.219, −10.084]** | **accepted**, both A/A, heap, brk and actual mode |
| YJIT | −0.153% [−0.563, −0.071] | **rejected**, both A/A controls and JIT-flat measured windows; diagnostic only |

Interpreter no-GC is −10.161% [−10.254, −10.105]. Activated but original
binder restored is −0.161% [−0.190, −0.094] total, not the former flat tax.
Separate untimed interpreter coverage is **11 hits / 0 fallbacks** per
request. YJIT heap/brk gates pass, but 10/24 workers compile during measured
windows despite stable warmups. No rerun and no clean-worker salvage.

**Additional YJIT limitation: installed ownership is not fast-path proof.**
Untimed statistics show **0 hits / 9,911 fallbacks**. Inspecting every actual
fact finds exactly one mismatch: the artifact was built with
`LOWRAIL_BUILD_JIT=0`, certifying C `Array#each` (`source_location: nil`),
but runtime `--yjit` uses Ruby `Array#each` at `<internal:array>:219`.
The existing guard correctly declines it; do not relax this fact. The
rejected raw delta therefore does not price a demonstrated config fast
path. A future experiment needs a mode-matched artifact and untimed hits
before pricing. **Config remains sealed-only, no promotion.**

Native post-fix 50-request counters still have **`exit_trace_leave = 0`**,
400 side exits and zero window compilation/invalidation. This establishes
clean production activation/ordinary fallback, not YJIT fast-path coverage.
The independent targeted/global micros remain causal evidence for the
sticky-trace fix. Numeric hashes, gates and attribution are retained in
the export; the original accepted regression is not overwritten.

### Operational follow-up: explicit mode admission, not weaker facts

Build now accepts `--jit interpreter|yjit|zjit`. The oracle observes its actual
mode and passes it through runtime certification and `units.json` to the ISeq
compiler; `manifest.json` records `certification_jit`. Setup compares the actual
mode before Guard, Loader or pass installers, retaining earlier
delivery/quarantine refusal precedence. Mismatched or missing mode metadata
declines the whole artifact with a `LOWRAIL_DEBUG` reason, not a guard charge
on every original-only call. Rebuild old artifacts.

Admission does not predict or change app configuration. The existing targeted
initialize! completion observer re-reads the mode: an off-certified artifact
can enter before Rails enables YJIT, then reports **mode drift** through
debug, Stats, verify's per-process `jit_modes`, and bench coverage/worker
metadata. Bench activation refuses drift; correctness remains guarded without
uninstall machinery. Doctor also records startup/after-initialize modes in
its **Lowrail-off metadata comparison**, explicitly not an admission probe.

Deploy with `RUBY_YJIT_ENABLE=1` or `--yjit` and build `--jit yjit`, rather than
relying only on late `config.yjit`. Public regressions cover early mismatch
in both directions (no Guard/Loader, zero fallbacks), matched hits, and a real
Rails late enable after a warmed C Array#each fact (original result, fallback
and drift in stats/outcomes). The sealed cold-delivery regression additionally
rebuilds in YJIT mode and retains positive hits plus zero `trace_leave` exits.
Mode preparation that requires config/application is inside the compiler's
observation/cold-cache window, preserving native delivery certificates.
**No new measured cohort, no revised YJIT verdict, no promotion.**

## Minimal causal proof: enable, boot, disable, then call unrelated code

`bench/experiments/trace_stickiness.rb` uses a boot method and an unrelated
arithmetic method. Six fresh-process paired rounds; pinned Valgrind from
`script/bench-valgrind /tmp/vg` (512 MiB brk); fixed heaps; N=0 subtraction;
both GC modes; max four workers; ordinary YJIT, no stats instrumentation in
priced windows. Both A/A controls, heaps, brk and JIT-flat gates pass.

| Disabled boot observer | YJIT Ir/call | Interpreter Ir/call |
|---|---:|---:|
| None | 445.897 | 640.931 |
| Global `:return` | 602.897 | 712.931 |
| Targeted `:return` on boot method | 445.897 | 640.931 |
| Global `:end` | 445.897 | 640.931 |
| Global `:script_compiled` | 445.897 | 640.931 |

Global return adds exactly **157 YJIT / 72 interpreter Ir per hot call** in
this specimen. Relative effects: +35.210% [35.202,35.218] and +11.234%
[11.232,11.235]. Every disassembly still prints ordinary `leave`. Separate
native stats observe 1,000 `exit_trace_leave` for 1,000 hot calls only in the
global-return arm; zero for original and targeted on **both 4.0.7 and
4.1.0-preview1**. The preview result is a counter check, not a priced cohort.
The first interpreter attempt aborted on a harness observer-variable bug
before producing a valid cohort; the corrected finite run is labeled
`trace-interpreter-corrected`, not a discarded bad control retried to green.

The sealed request study independently attributes native `vm_trace` **SELF**
Ir in already accepted no-GC windows: empty setup 0 vs full 279,708 per blog
index request, all six rounds. Its matched factory-only arm (no lowered
sites/dispatch) still costs +3.538% and 283,074 `vm_trace` Ir/request. See
[sealed pilot](sealed-links.md) and its numeric export. These are the sealed
thread's published observations, not new runs performed here.

## Binder, props and emit-shape ablations

All following micros passed their finite A/A, heap, brk and strict YJIT gates.
The binder micro activates its real runtime directly, intentionally excluding
the bootstrap observers whose global effect is tested above.

| Config binder, same options/controller | YJIT Ir/bind | Change vs original |
|---|---:|---:|
| Original public binder | 58,481.659 | baseline |
| Current guarded public binder | 20,334.927 | −65.215% |
| Same residual allocation/copy body, no guards | 14,072.923 | diagnostic ablation |
| Selected own-class ordinary `def` | 14,123.919 | −75.835% |
| Existing guard only | 6,534.055 | diagnostic component |

Interpreter original/current: 71,069.348 → 24,675.747 (−65.254%). This
**does not reproduce a binder-only YJIT regression**; it contradicts that
hypothesis. Objects removed alone cannot predict whole-request Ir.

Props uses asymmetric nested hashes/arrays, false and empty values, checking
the returned value against the input: original 34,354.257; guarded 58,043.307;
plain each 30,414.409; same emitted inline branch with cached G 30,488.944.
The native extra singleton-class fallbacks are evidence of the cost, not
proof that deleting reflection is semantically safe. Props remains guarded
and unmodified.

The shape micro holds the tiny arithmetic body constant:

| Shape | YJIT Ir/call |
|---|---:|
| Plain def / separately selected def / extra blank lines | 441.965 each |
| Inline G branch | 470.965 |
| `G[id] || check(id)` (cached true) | 474.965 |
| K identity test | 518.965 |
| V hash lookup | 837.930 |
| Actual prevalidated `Lowrail.check` | 576.965 |
| `define_method` body | 444.965 |
| Direct positional call / array splat | 481.965 / 567.965 |
| Literal keyword / kwargs Hash splat | 482.965 / 1,194.136 |
| Monomorphic / eight receiver classes | 546.965 / 696.090 |
| G/K/V entry writes plus body | 1,298.465 |

Entry writes cause **zero measured invalidations**. BMETHOD alone costs
three Ir in this small no-block case, not a universal ban or an explanation
of +16% requests. Positional/keyword forwarding is not equivalent to the
literal case for arbitrary public APIs. Source-line padding has no effect
here; this does not exhaust all ISeq size/layout possibilities.

## Production observer inventory and replacement

| Site | Previously normal production? | Disposition |
|---|---|---|
| `passes.rb` pre-AS bootstrap `:end` | yes, selected runtime units | nonloading Object/AS constant-definition and LazyLoadHooks extension notifications |
| `passes.rb` receiver readiness `:end` | yes, lazy dependencies | successful native require/autoload completion + Zeitwerk on_load, no eager resolution |
| `passes.rb` `initialize!` `:return` | yes | `enable(target: app.method(:initialize!))`; disable before activation |
| `ar_guard.rb` AS readiness `:end` | yes | shared nonloading AS readiness |
| `sealed.rb` Loader `:return` + binding | sealed pilot | Loader records successful serve paths directly; no observer |
| `script_capture.rb` `:script_compiled` | build/facts only | retained, explicitly diagnostic; not normal runtime setup |
| `observe.rb` targeted call/return | observe only | retained, not benchmark mode |
| `verify_loads.rb` `:end`; RSpec attachment `:end` | outcome/verify only | retained, not benchmark/production mode |
| `seal.rb` broad boot/mutation events | seal-check only | retained, contract observation is not production timing |

Stats creates **no TracePoint**. Memo intercepts TracePoint APIs to decline
unsafe reuse; it does not create an observer. A verify process can therefore
have instrumentation that a production benchmark must not inherit.

AS readiness observes existing constants without forcing autoloads. It waits
until LazyLoadHooks has completed its own `extended` initializer before
registering hooks. Delayed framework receivers use exact pending autoload
features; callbacks wait until the outer successful require completes.
Failed or unidentified loaders stay inactive. `require_relative` is not
wrapped (doing so changes its lexical base). Native completion observation is
installed only after boot, after Zeitwerk has established its require seam.

## Emit proposal, not a pass change

Fix the VM-wide observer first. For a **sealed** whole-method specialization,
prefer a separate ordinary-def ISeq with the exact original signature,
lexical nesting, magic comments, source location and visibility; select it
once at safe load/activation before hot compilation. Keep the original ISeq
as admission-time fallback, with no per-call branch/forwarding dispatcher.
The selected-def binder micro above proves that this shape can remain
YJIT-friendly: −75.835%, not merely neutral; the constant-body separate-def
control exactly matches the plain def at 441.965 Ir.

This follows the shape principles of
[Roundhouse Fractal](https://github.com/rubys/roundhouse/blob/main/docs/pipeline/fractal.md),
which currently registers no pass: a whole-method ISeq, choice at load,
ordinary def, no per-instance eigenclass creation. It does **not** transfer
Fractal's admission rules as a Lowrail exactness proof. Guarded tier cannot
select once and forget mid-request changes. Even sealed admission must
refuse observable redefinition hooks, foreign method owners/visibility,
lexical mismatches and unsupported provenance. A separate wrapper that sends
`*args, **kwargs, &block` merely relocates costs and changes observable method
metadata; it is not the proposal. Existing passes are untouched.

For sealed link_to, the published operation micros and evolving full delivery
are different specimens. The full specimen uses an inline template local
continuation, source-preserving factory/Metal edits and WeakKeyMap membership.
No new link_to micro/request acceptance is claimed here; the already-published
factory-only tracing ablation is the relevant isolation, and the sealed
thread owns fresh post-fix request cohorts.

The downloaded, read-only full-delivery specimens were `sealed.rb` SHA-256
`ef1ea44e413b697590090995ed95cf971afea62662ec0a161cd8dd257509af43`
and `sealed_build.rb`
`f1c5edd58348c40111f05285658754ef8c52f4208da87444548032c8a48f7523`.
They were evolving specimens, not accepted request artifacts. The legacy
`bench/experiments/sealed_provenance.rb` also creates its own global return
observer; do not use that v3 operation harness as clean post-fix pricing.
Its instrumentation is not installed by production Lowrail setup.

## Runtime regression and correctness gates

The retained bootstrap regression fails on the pre-fix runtime: after a real
Rails boot, an unrelated warmed method returns 146 correctly but adds one
`exit_trace_leave` instead of zero. The fixed runtime passes both new
readiness tests (2 runs / 4 assertions). A separate public production sealed
request test requires successful cold delivery, positive fast-path hits and
zero warmed request trace exits. Disasm is deliberately not its oracle.

Full `rake test`, before the six additional sealed-only flags: Ruby 4.0.7
**129 runs / 4,787 assertions, zero failures or
errors, 6 skips**; Ruby 4.1.0-preview1 **129 / 1,588, zero failures or errors,
14 optional-dependency/fixture skips**, without test exclusions. The preview
uses physical blog/Campfire copies with the source dependency workaround
described in [the 4.1 study](../ruby-4.1.md); the original locked native
bundles were not compatible and that failed attempt is retained privately.

`cargo test --locked`: **35 unit + 1 types/MCP + 3 verify integration tests
pass**. Fresh format-2 facts exposed a separate MCP reader still admitting
only format 1. Its separately committed correction reuses `facts::load`,
including app-relative path expansion; the existing method-span fixture now
checks relative format-2 locations. No duplicate format whitelist was added.

After rebasing onto the relocation and six-flag boundary `827a816`, Cargo
passes again. Changed/quarantine-affected test files pass on both Rubies:
4.0.7 **17 / 221, zero skips**, plus **32 / 687, 2 skips**; 4.1 preview
**17 / 130, 2 skips**, plus **32 / 681, 4 skips**. No failures or errors.
The new sealed request assertion selects its actual unit ID, not an assumed
unit zero. A fresh public format-2 sealed Starter build, with unrelated
passes excluded by the existing build denylist, contains exactly one
config-bind unit and no delivered files/templates. Its native warmed
50-request counter probe reports **zero trace exits**, 400 side exits and
zero window compilation/invalidation. This is not a priced cohort.

AP/AV/AR L3 outcome identities match off/off/on: **4,095 AP, 2,747 AV, 242
AV/AP, 173 AV/AR and 9,240 AR**, no stable differences or shadow mismatches.
AV/AR records 122 hits; AR records 68,860 hits / 12,265 fallbacks. AP/AV have
no promoted source units: matching outcomes are compatibility, not a newly
supported lowering claim.

The nine-app rerun below is **before the six additional sealed-only flags**
in [827a816](https://github.com/thomasklemm/lowrail/commit/827a816af9f6beed94efb5ae0feb3328951f1bd2).
Both tiers use strict SQL/load recording, seed 41231 and the unchanged app
suites. A positive hit here does not admit that pass in the later guarded
tier.

| App | Outcomes | Default / all-opt-in verdict | All-opt-in hits / fallbacks |
|---|---:|---|---:|
| Blog | 21 | identical / identical | 41 / 1 |
| Campfire | 634 | identical / identical | 2,651 / 3,129 |
| PingCRM | 1 | identical / identical | 0 / 0 |
| Redprints | 50 | **RED / RED, strict loads** | 241 / 0 |
| Starter | 36 | identical / identical | 110 / 0 |
| CASA non-system | 2,992 | identical / **RED, seed SQL** | 12,920 / 3,645 |
| Writebook non-system | 119 | identical / disabled-JIT build refused | not measured |
| Fizzy | 124 | identical errors / identical errors | 1,963 / 51 |
| CodeTriage | 222 | identical / identical | 933 / 1 |

Redprints has identical passing outcomes, but the known require-hooks load
boundary remains red even for zero-unit default setup; no census suppression.
Fizzy retains seven baseline errors, not a green supported app. SQL/load
identities unstable in same-mode controls remain advisory: CASA default 48
SQL identities, all-opt-in 46; CodeTriage 2/3. Load advisories are 8 for
Starter/CASA/Writebook/Fizzy and 24 for CodeTriage; Redprints has 32 unstable
entries **as well as** stable differences.

CASA all-opt-in has identical outcomes and zero stable load differences,
but its full-suite seed identity is **6089 → 6094 queries**, consistently in
that full suite's own controls. The query multiset adds five
`SupervisorVolunteer` UPDATEs with identical per-table INSERT counts. Its
cause is **unestablished**, not dismissed as noise. A separately labeled
isolated seed diagnostic records 4,737 instantiate hits / 227 fallbacks,
zero preload hits, and noisy own-mode SQL (on/on 6534 → 6771). That different
execution context does not overturn the full-suite RED. RSpec seeds the
global RNG, so merely seeing `rand`/`sample` is insufficient attribution.
Attribute/dirty-state drift in the now-quarantined instantiate pass is a
hypothesis; the TracePoint fix changes no AR implementation.

The separately labeled rebased isolated CASA seed check has one matching
outcome and zero lowered units/hits; its own-mode SQL control remains noisy.
This does not prove disappearance of the full-suite difference. A same-seed
full-suite off/off or on/on attribution control has not been established.
Rebased browser correctness checks are separate, not a retry of that RED.

Writebook's real-browser baseline passes 2 tests / 8 assertions. Browser
default/all-opt-in verification is identical, with 143 all-opt-in hits and
8 unstable load entries. Its own initializer enables YJIT; forcing
`LOWRAIL_BUILD_JIT=0` correctly refuses the runtime build. The successful
browser build retained app-native JIT configuration; this is correctness,
not JIT-flat performance evidence. Protocol unit checks with pinned headers
pass 13 / 151 (`request_pairs_test.rb`) and 16 / 157 (`pass_test.rb`); an
earlier invocation without the pinned Valgrind include path failed as such.

## Guarded props ordinary-def pricing specimen

`bench/experiments/props_variant.rb` is a **pre-implementation specimen**,
not a runtime pass or a promotion. It retains the actual
`InertiaProps.valid?(id, props)` check at **every recursive traversal entry**.
There is no cached-G replacement or load-only authorization. An iterator
already executing is not restarted if app code mutates a later receiver.

The `split` arm puts the original `each_with_object` body in a separate
private ordinary `def`. The fast method retains its explicit positional and
keyword signature, executes the existing guard, and either runs the `each`
body or calls that original fallback with explicit local arguments (no
`*args`, `**kwargs` or block-backed dispatcher). Recursive calls still enter
the guarded method. This adds a method and changes fallback frames/source
layout: passing the specimen's value/lifetime gate is **not** certification
of production reflection, backtraces or delivery.

The `props_variant` pricing group in `yjit_regression.rb` prepares five arms:

| Arm | Purpose |
|---|---|
| `original` (paired off/off controls) | Whole original resolver work |
| `guarded` | Current emitted inline branch and exact receiver checks |
| `checks_original` | Original work **plus** every exact recursive guard, including its singleton-class side effects; paired excess prices checks |
| `split` | Proposed ordinary-def shape, with the same complete checks |
| `each` | Unchecked iteration upper bound only; never a safe candidate |

`checks_original`'s Stats hits mean successful **authorization**, not a
completed fast iterator: that arm deliberately always performs original
work. Comparing a single root guard against an entire resolution would
underprice recursive checks and fresh receiver shapes.

Unlike the historical `props` group, every `props_variant` operation builds
fresh nested input hashes/arrays and a new resolver, identically in all arms.
Reusing a resolver only makes the expanded root fresh; its nested inputs
remain shared and could underprice singleton-class churn. Compare
`checks_original − original` against `original − each`, so common
construction cost is not counted as saving or as available check budget.
Then require the complete guarded candidate itself to win. This is the
pricing plan, not measured evidence that it does win.

The untimed `--check` gate reuses the public resolver fixture on all three
audited gem versions, discovering first/last calls at every exercised body
callsite. It compares values, metadata, ordered effects and once-only lazy
evaluations against the original through suppressed mutations, changed
`each`, private iteration, Hash subclasses, stale/malformed facts and a
non-main Ractor. The observer recognizes the moved fallback body too; the
plain control still determines the mutation boundaries. Normal calls must
authorize without fallback, mutated receivers must fall back, and stale or
malformed certificates must have zero authorizations. Each child asserts
and records its actual JIT mode, not the driver's mode. A separate hot case
warms the resolver, proves its ISeq compiled under YJIT, then mutates the
later receiver from a real lazy-prop callback without enabling the fixture's
TracePoint.
That case must preserve the original ordered effects and observe the changed
iterator through fallback. Signature/private visibility are checked too;
source hashes are retained and must stay unchanged for the entire gate.

Ruby 4.0.7 passes **478 comparisons in each of interpreter and YJIT mode**
across Inertia 3.21.2/3.22.0/3.23.0. Ruby 4.1 preview separately passes the
**six hot-callback comparisons** under YJIT, not a full preview matrix.

```sh
BENCH_JIT=0 mise exec -- ruby bench/experiments/props_variant.rb --check /tmp/NEW-props-check-interpreter
BENCH_JIT=1 mise exec -- ruby bench/experiments/props_variant.rb --check /tmp/NEW-props-check-yjit
```

No `props_variant` Callgrind cohort has run; worker authorization remains
held. When released, the prepared group uses the pinned Valgrind and the
same finite A/A/heap/brk/JIT-flat protocol, with at most four workers. If
checks alone exceed the potential saving, stop at design; an ordinary `def`
does not make expensive reflection cheap. No speed claim or pass change
follows from an untimed correctness check.

## Doctor: detect sticky tracing from any gem

Third-party boot debuggers, coverage/APM/profilers can cause the same VM-wide
condition without Lowrail. Do not identify a guilty gem from a counter alone.
**Opt-in diagnostic:** `lowrail doctor APP --trace-check`, optionally with
`--path /safe-get`. It runs in doctor's independent `LOWRAIL=0` boot process,
before any seal-check observers. It never enables YJIT, stats or a TracePoint
itself. Supply stats-capable YJIT flags in a disposable diagnostic run:

```sh
RUBYOPT="--yjit --yjit-stats=quiet" lowrail doctor APP --trace-check --path /up -- bin/rails test
```

The unrelated ordinary-def leaf warms 1,000 calls, proves compilation with
`insns_compiled`, then counts 1,000 returns. With a request path it also
executes ten warmup GETs and samples one GET, without following redirects.
Use a safe endpoint. Reports retain status and counter deltas, not response
bodies or headers, under `doctor.json.return_tracing` and `doctor-trace.json`.
The ordinary baseline suite still runs. Warning is advisory, not a failed
correctness gate. Normal setup/benchmarks never call this probe.

Positive leaf exits suggest VM-wide contamination even with zero enabled
Ruby TracePoints; positive request-only exits do not establish global
stickiness. Counters are process-wide, so concurrent traced work can also
contribute. `not_observed` is not a clean-VM certificate: other event classes
and unexercised paths remain outside scope. Disabled YJIT, absent counters
or unproven leaf compilation yield `unavailable`, never an inferred zero.
Regression tests run a third-party global boot hook then disable it: **1,000
exits**, versus **0** for off and targeted-only boot hooks, on both Ruby
targets. They also distinguish request-only targeted tracing and missing
stats/interpreter mode. Do not turn stats on in benchmark windows.

Without YJIT, no supported public Ruby API directly exposes the sticky global
event mask. Disasm/to_a normalize it away. An interpreter return-heavy micro
against a **fresh process with identical VM/options but no tracing** can
diagnose a tax, not prove its source or offer a universally calibrated
threshold. If the app already booted with sticky tracing, disable is not a
repair: restart without that global observer. Do not secretly probe by
enabling a global hook (that poisons the process being diagnosed).

## Reproduction and evidence

[Numeric export](yjit-regression.json) retains per-arm estimates, all gate
verdicts (including rejection), raw-data hashes and native counters. Zero
native counters are elided except the named control counters; a missing
elided counter is not a missing VM capability. Raw private logs stay out of
Git; no authentication headers are exported.

```sh
bash script/bench-valgrind /tmp/vg
export PATH=/tmp/vg/bin:$PATH CPATH=/tmp/vg/include
ulimit -d unlimited
BENCH_JIT=1 BENCH_JOBS=4 mise exec -- ruby bench/experiments/yjit_regression.rb config /tmp/NEW-config
BENCH_JIT=1 BENCH_JOBS=4 mise exec -- ruby bench/experiments/yjit_regression.rb props /tmp/NEW-props
BENCH_JIT=1 BENCH_JOBS=4 mise exec -- ruby bench/experiments/yjit_regression.rb shapes /tmp/NEW-shapes
BENCH_JIT=1 BENCH_JOBS=4 mise exec -- ruby bench/experiments/trace_stickiness.rb /tmp/NEW-trace-yjit
BENCH_JIT=0 BENCH_JOBS=4 mise exec -- ruby bench/experiments/trace_stickiness.rb /tmp/NEW-trace-interpreter
mise exec -- ruby --yjit --yjit-stats=quiet bench/experiments/yjit_regression.rb --stats config guarded
TRACE_SHAPE=targeted TRACE_STATS=1 mise exec -- ruby --yjit --yjit-stats=quiet bench/experiments/trace_stickiness.rb
```

Each invocation is one finite cohort in a new directory, never a command to
repeat rejected controls until green. Diagnosis predates the sealed/relocated
manifest boundaries; standalone direct-installer micros do not assert public
production artifact acceptance. Full-request builds must use the current
sealed production contract. See also the
[unpublished Ruby source note](../upstream-drafts/ruby-sticky-trace.md).
