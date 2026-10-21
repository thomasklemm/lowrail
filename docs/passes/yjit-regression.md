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

### First pricing attempt: numerically green, invalid fast-path pricing

The one finite interpreter cohort on
[d7b232f](https://github.com/thomasklemm/lowrail/commit/d7b232f)
used three workers, six rounds, seed 41231, N=1,000 and pinned brk512
Valgrind. Both A/A controls, five heaps, brk and actual-mode gates passed.
**It is nevertheless invalid pricing, not a losing complete fast path.**
The shared micro factory still wrote `format: 1`; the runtime required
`Lowrail::FORMAT == 2`. `Manifest` refused, `Guard.validate(0)` returned
false, and props short-circuited before its receiver reflection. Source
activation alone remained true. A separate ten-operation replay records
**guard_valid=false, 0 hits / 20 fallbacks**, with refusal
`unsupported manifest format 1; rebuild for relocatable format 2`.
The public lifetime fixture used the current format, explaining why its
478-comparison gate did not catch this different pricing factory.

Raw split-vs-original total Ir is +8.380% [8.324, 8.432]; raw
checks_original excess is 7,393.607 [7,389.607, 7,419.607] Ir, versus
4,445.573 [4,393.369, 4,495.471] unchecked iteration saving. These remain
**fallback/incomplete-check diagnostics**, not the price of exact reflection
or a stop-at-design verdict. No rescore, no retry of that cohort. Its raw
numeric verdict is retained separately from `pricing_valid:false` in the
[export](yjit-regression.json). The YJIT cohort never started.

The corrected factory uses **`Lowrail::FORMAT`**, records its actual
`certification_jit`, and refuses incompatible manifests/facts before a pass
installer. It does not add a sealed tier to synthetic manifests: legacy
config/global/check arms requiring sealed config-bind now refuse explicitly,
rather than bypassing the production contract.

Before any Callgrind preflight or window, **every arm** runs a separate native
`--liveness` companion in the requested, observed mode. The exact-guard props
arms require `guard_valid=true`, positive unit-0 authorizations and zero
fallbacks. Original/unchecked controls require zero counts. Thus
`checks_original` executes the complete positive reflection at each recursive
entry, then the original work; its hits still mean authorization only.
Each measured worker requires the saved source-pinned liveness proof and
rechecks its own guard. Stats is **never enabled in a measured process**:
enabling then disabling counters would leave counting method replacements.
Failed companion stdout/stderr are retained and the cohort is not launched.

Untimed probes on both Ruby targets, interpreter and YJIT: ten resolutions
give **20 authorizations / 0 fallbacks** in guarded, split and checks_original;
controls have zero counts. The retained regression covers current-format
admission, malformed-format refusal, original-only emission falsely presented
as either candidate, missing preflight proof, and driver refusal before any
pricing tool starts. Run it without Valgrind:

```sh
mise exec -- ruby bench/experiments/yjit_regression_test.rb --seed=1729
mise exec ruby@4.1.0-preview1 -- ruby bench/experiments/yjit_regression_test.rb --seed=1729
BENCH_JIT=1 mise exec -- ruby --yjit bench/experiments/yjit_regression.rb --liveness props_variant checks_original
```

### Corrected interpreter pricing: stop at price

**One finite corrected-code cohort is accepted; the exact-guard ordinary-def
shape loses. Stop at price, no promotion. The YJIT props micro is cancelled,
not held, and never started.** The earlier format-1 cohort above remains
invalid fallback/incomplete-check pricing, unchanged and not rescored.

Measured clean
[fb07512](https://github.com/thomasklemm/lowrail/commit/fb07512d06ca217ec1fdb1e49e0cd24ab4fa8345),
Ruby **4.0.7**, revision `229531a6cf`, x86_64 Linux, inertia_rails **3.22.0**.
The resolver SHA-256 is
`48957d68dc3b619ca5a9de807c74ab12d425304592b410a95684d0bd89be32af`.
Pinned Valgrind **3.19.0 / 512 MiB brk**, upstream archive SHA-256
`dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02`,
patch SHA-256
`ab95c4a3c2ffae1db00116ff550b19f1f30f3ae3333349779c221d1fb55f84d1`,
Callgrind binary SHA-256
`5fe02646537c5669b032c5146665728f9dab384918fea30118b7c7df3dc30ad7`.
The numeric export additionally pins the Ruby binary and specimen/runtime
sources. These are this orb's binaries, not universal binary hashes.

The new worker release allowed **four** concurrent workers for this
interpreter cohort only: six randomized rounds, seed **41231**, N=**1,000**,
36 fresh-process workers and 144 measured N=0/N=1,000 windows. Every worker
freshly builds its micro manifest/emission with the current runtime format
constant. This is not certification of production artifact delivery. The
fixed heap floors remain **1,000,000 / 250,000 / 100,000 / 20,000 / 10,000**;
the existing micro A/A, heap, brk, mode and c9d2397-lineage window gates are
unchanged. This is not a warmup-v3 or YJIT acceptance result.

Before Callgrind, all five arms have **guard_valid=true**. Ten fresh native
resolutions authorize **20 times / 0 fallbacks** in each of `guarded`, `split`
and `checks_original`; original/unchecked controls have zero counts. All 36
measured workers recheck the guard; Stats never enters measured processes.
Current-head preparation also passes **478** lifetime/mutation comparisons
over all three audited Inertia versions and **5 tests / 135 assertions** for
factory/liveness refusal. No failed worker or cohort was replaced.

| Comparison | Total Ir, paired estimate [95% CI] | GC-excluded Ir, paired estimate [95% CI] |
|---|---:|---:|
| Split ordinary-def vs original | **+22.594% [22.496, 22.731]** | **+22.614% [22.469, 22.739]** |
| Existing inline guarded vs original | +22.558% [22.447, 22.659] | +22.550% [22.421, 22.693] |
| Unchecked `each` vs original, upper bound only | −4.281% [−4.307, −4.281] | −4.281% [−4.308, −4.281] |
| Complete checks cost: `checks_original − original`, Ir/resolve | **30,482.987 [30,218.378, 30,726.693]** | **30,480.710 [30,169.664, 30,773.099]** |
| Available saving: `original − each`, Ir/resolve | **4,445.573 [4,445.369, 4,471.471]** | **4,445.471 [4,445.369, 4,471.573]** |
| Checks cost / available saving | **6.857× [6.758, 6.912]** | **6.818× [6.787, 6.921]** |
| Split vs inline guarded | +0.037% [0.018, 0.074] | +0.036% [0.020, 0.073] |

Estimates pair within each of six rounds; intervals resample whole rounds
5,000 times with seed 41231, not individual operations. Ratios and differences
are computed per round, not from the displayed marginal medians. Allocations
per resolution are 55 original, 64 inline, 64 split, 75 checks-original and 46
unchecked. Common fresh-input/resolver construction is not available saving.
Exact reflection and its receiver-shape side effects overwhelm the iterator
budget; merely moving the fallback to an ordinary def does not help.

Both A/A controls pass: total −0.025040% [−0.050080, +0.025052], GC-excluded
−0.025040% [−0.050080, +0.025053], containing zero within ±0.5%. All five heap
pools match, all 36 workers attest interpreter mode, and the Valgrind
preflight plus all 36 worker logs are brk-clean. An independent retained-data
audit checks every raw window total and all 72 slopes. The
[numeric export](yjit-regression.json) keeps both valid and invalid cohorts,
paired samples, source/tool pins, liveness and raw-file hashes. Raw files stay
under the ignored workspace-local
`.lowrail/diagnostics/props-corrected-interpreter-fb07512/`; no rerun is needed
to inspect them. All four slots were released.

**Decision:** stop this exact-guard shape at price; no pass implementation,
promotion, native-throughput or request-win claim. Production reflection and
delivery remain uncertified. The older request measurements remain separate.
Config-bind YJIT stays on hold until the YJIT measurement method is accepted;
the props YJIT cancellation is not a new authorization for that cohort.

**Backlog only, not implemented or priced:** a VM-owned, non-callback query
for an actual receiver's effective iterator bodies and visibility could avoid
creating an eigenclass and batch the reflective checks. It would need a
supported exact certificate for existing singleton methods, suppressed hooks,
alias/undef/visibility changes and the Ractor boundary, rechecked at every
recursive entry after app code. A complete VM mutation token is another form
of that requirement, not a Ruby hook cache. No supported cheap certificate
is established; the checks need roughly **85.4%** less work just to fit the
measured saving. The earlier `public_method`/`unbind` shortcut can execute
`respond_to_missing?` and is not an exact replacement. No freezing app inputs,
weakened guards, runtime extension or new pricing run follows from this note.

### Admission-factory audit since format 2

Exact searches of `bench/` manifest constructors/writers/readers and the
[format-2 change](https://github.com/thomasklemm/lowrail/commit/db2209275ba5fda0cc0c793e5f64ad5b910518c1)
find **one remaining hardcoded format-1 factory**, the shared factory fixed
above. The audit also checks tier, JIT mode, relocation, certificate copying
and pre-window coverage, rather than assuming a current format is sufficient.

| Factory / consumer | Admission inputs and liveness boundary |
|---|---|
| `experiments/yjit_regression.rb` | Fixed above. The old props variant interpreter run demonstrably priced fallback dispatch. Sealed-only config units are now refused, not synthetically admitted. |
| `inertia_config.rb` micro | Uses `Lowrail::FORMAT`; no sealed tier, so today's config-bind unit refuses. Its existing **pre-timing G[0] assertion** stops the micro. `check` instead uses a public artifact and asserts positive hits / no fallbacks. |
| `ar_equivalence_runtime.rb`, persisted by `ar_rails_suite.rb` | Both use the constant. Synthetic framework/test units have no sealed production tier (or JIT certificate); the adapter explicitly skips installation on refusal. Intentional original-only correctness coverage, not an accepted speed cohort. |
| `guard_cost.rb`, `guard_breakdown.rb` | Use the constant, local non-pass `@self` probe facts, no sealed/JIT/root certificate. Direct Guard installation, not public artifact admission. Warmup calls are **not assertions of true guards**; no counted pre-window liveness. Flag historical accepted guard prices as lacking that coverage, not as demonstrated format refusals. |
| `experiments/guard_inline_cache.rb` | Same local probe format constant and missing liveness assertion; explicitly inexact K-cache prototype, not a production candidate. |
| `speculation_holes.rb` (both factories) | Uses the constant; non-pass probe facts. Asserts positive boot guards before mutation and counterexample results afterward. No measured cohort. |
| `experiments/endpoint_bodies.rb`, `experiments/sealed_provenance.rb` | Real Compiler writes current format, observed JIT mode and delivery certificates; experimental unit names are **not** sealed-only production units. Setup and actual delivery witnesses must succeed. Their broad diagnostic return observers remain a separate reason not to reuse them as post-fix pricing. No format literal found. |
| `experiments/speculative_build.rb`, `speculation.rb` | Recompile original `units.json` through Compiler; preserve mode/tier/root inputs and produce a deliberately incompatible unsafe marker. The ancestry-scoped reader retains format checks. This is an explicit unsafe ablation, never a guarded candidate. |
| `request_pairs.rb` | Copies complete public artifacts; empty control clears units/files/templates and their path-pointer targets without stripping mode/tier metadata. The published LOWRAIL_DIR seam keeps the real app root. No hand-built version or certificate replacement. |
| `pass.rb` / `pass_probe.rb` | Public artifact preflight checks format/refusal/source certificates; actual setup/probe rejects JIT mismatch/drift before request pricing. Method micros have runtime activity checks and a separate counted sample **after** timing, not the new per-arm pre-window positive-count guarantee. Request coverage alone does not prove a particular micro hits. |
| Other manifest readers (`ar_instantiate_runs.rb`, allocation/hotspot studies, `yjit_study.rb`, `yjit_request_probe.rb`) | Select/pin existing public artifacts rather than inventing format metadata. Instantiate checks a live selected plan; discovery/diagnostic studies are not new accepted guarded-pass prices. The old config request's 0/9,911 fallback attribution is already recorded above. |

**Historical accepted micros without this new liveness gate:** config-yjit,
config-interpreter, props-yjit, global-yjit and shapes-yjit in the existing
export; the guard-cost/breakdown prices in [speculation](speculation.md#fixed-heap-guard-micro-costs)
and [the 4.1 study](../ruby-4.1.md) also lack counted pre-window assertions.
Global/ordinary shape bodies do not claim a pass hit; `cached_guard`/unchecked
arms deliberately bypass checks. Guard-dependent arms are flagged as
**historical fast-path coverage unproven**, not retroactively certified by
today's positive probes. None was rescored or rerun.

Do **not** infer historical format refusal from the publication date or from
the current reader. The old config/props/shape export pins factory
`dfb4fe05…` **together with reader `45dabea6…`**. The latter exactly matches
`manifest.rb` at
[45fd07a](https://github.com/thomasklemm/lowrail/commit/45fd07a), whose direct
constructor did not refuse format 1 or enforce the later sealed tier.
Its guard pin `189ad92f…` matches the historical guard and only declines a
manifest's recorded refusal. Consequently this new format-2 failure is
**not established for those historical cohorts**. The missing liveness
evidence leaves possible inactivity unexcluded; it does not prove fallback
pricing. In contrast, d7b232f's recorded reader is `47da0de0…`, which does
refuse format 1, and its separate replay confirms zero hits. Keep both code
states and verdicts distinct. The original source map omitted core
`lowrail.rb`/pass-registry pins; the corrected harness now pins them too.

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

## Reporter readiness and global tracing audit

The RSpec reporter's waiting global `:end` hook was a second, distinct
contamination source. Before the fix, the public RUBYOPT regression fails:
all five form primitive fingerprints (`Array#first/#last`,
`Symbol#to_s/#name`, `Object#class`) differ with outcomes reporting enabled,
even though RSpec itself is never loaded. A fresh two-process `Symbol#to_s`
probe isolates `opt_invokebuiltin_delegate_leave` off versus
`opt_invokebuiltin_delegate` with the reporter. Minitest's own const/plugin
attachment does not require tracing. Refusing the changed inventory was
correct; no instruction normalization or certificate relaxation is needed.

RSpec readiness now observes creation of the RSpec constant and the actual
definition of its `configuration` API, then prepends that entrypoint. It
does not make `rspec/support` alone appear configured. `super` must finish constructing
**and storing** the configuration before public `Formatters.register` /
`config.add_formatter` run. It does not wrap require, activate RSpec early,
or use TracePoint. Attachment is idempotent per formatter list, including
`RSpec.reset` and `clear_examples`; existing preloaded RSpec also works.
The six-example outcome fixture retains distinct duplicate IDs and all
pass/failure/error/skip/pending/fixed-pending outcomes, hits, and RNG
attestation, including Bootsnap boot. Memo no longer exempts any reporter
TracePoint from its tracing refusal.

The opt-in `VerifyLoads` census had its own global `:end` readiness hook.
It now uses existing ActiveSupport readiness plus Zeitwerk constant/setup
hooks, without forcing autoloads. The same five primitive facts agree with
reporter alone **and** reporter+census on both Rubies. On the primary Ruby,
the real production blog's **complete** `FormScaffoldInventory.check` agrees
in all three boots; 192 isolated form request pairs, both ordinary and with
render subscribers, retain positive form hits and zero form fallbacks with
the reporter preloaded. These are untimed correctness checks, not a new
performance cohort. The inventory implementation is unchanged.

Doctor's `--trace-check` additionally retains `builtin_dispatch` under the
existing `return_tracing` report. It warns on unfused zero-argument VM
delegates (`Symbol#to_s/#name`, `Object#class`), in interpreter as well as
YJIT processes. Fresh controls on both targets distinguish off from active
`:end`/`:class` hooks and from a builtin materialized under such a hook then
inspected after disable. The native six-event probe also checks `:call`,
`:return`, and `:script_compiled`: the first two unfuse `Symbol#to_s`, while
script capture leaves it fused, matching off. No Callgrind run is needed
for these observable ISeq differences.

**Limitations:** this is shape evidence, not an API exposing active
events/targets, historical event masks, or the responsible gem. Previous
materialization and compiler options can affect the result; it is not a
clean-VM certificate or a performance claim. Array's optional-argument
methods legitimately contain an unfused arity-check delegate even off,
so doctor does not use them as warning sentinels. Original return-counter
unavailability remains explicit when YJIT/stats are absent; a separate
positive builtin warning is still reported. Never enable tracing to probe
an already booted app.

### Inventory of all remaining tracing sites

Audit scope: `TracePoint.new`/`.trace`, `set_trace_func`, `trace_var`, and
enable sites throughout `gem/lib/` and `bench/`. A callback's own path or
method filter **does not** make its enable targeted. The following is the
complete remaining inventory, not merely the return-event subset.

| File (under `gem/lib/lowrail/`) | Enable scope / disposition |
|---|---|
| `rspec.rb`, `verify_loads.rb` | Global `:end` hooks **removed**, replaced above. |
| `passes.rb` | `:return` **targeted** at the app's `initialize!`; retain the already tested local completion boundary. |
| `observe.rb` | `:call/:return` **targeted** per observed UnboundMethod; intentional profiling, not measured production. |
| `script_capture.rb` | Global `:script_compiled`, build/facts/observe only; generated eval discovery needs all compilation events. Stopped after capture; fresh builtin control stays fused. Never installed by normal runtime setup. |
| `seal.rb` | Global boot `:end/:return`, then global `:call/:c_call/:return/:c_return`, including re-enable after writing. Intentionally observes arbitrary mutations across the exercised suite in the **separate seal-check process**, never normal delivery or timing. Cannot certify a clean performance process. |
| `memo.rb` | Intercepts TracePoint construction/activation and inspects tracing state to **refuse** reuse; creates/enables no trace. No special reporter exemption remains. |
| `jit_diagnostics.rb`, `compilation.rb` | Inspect enabled state/ISeqs only; create/enable no trace. |
| `jit_shapes.rb`, `seal_static.rb` | Recognize tracing/reflection in code to diagnose/refuse; do not execute tracing APIs. |

All bench paths below are relative to `bench/`. Historical experiments are
retained to reproduce their source-pinned records, **not** silently rewritten
or re-scored. A retained global observer is not permission to reuse its
process for a fresh clean-VM price; use targeted captures or a separate
untimed companion first. This audit starts no measured cohort.

| File | Enable scope / disposition |
|---|---|
| `callback_survey.rb` | `:call` **targeted** at `ActiveSupport::Callbacks#run_callbacks`; intentional untimed census. |
| `heap_requests.rb` | `:line` **targeted** at the actual lowered body for the separate idle-operation companion. No global hook. |
| `inertia_setup.rb` | Global `:call` for asset-digest positive control and request census; standalone corpus preparation exits, never a measured worker. |
| `requests.rb` | Global `:call` only for explicit trace commands. `request_pairs.rb` sends these after all timed samples/profiles, then closes the workers. Never send another timed command to a traced process. |
| `importmap.rb` | Global `:call/:c_call/:return` in standalone `trace` mode only; not the separate `micro`/correctness modes. Intentional method census, not timing. |
| `experiments/yjit_request_probe.rb` | Global `:call` in the `YJIT_REQUEST_CENSUS` branch; prints counts and **exits before** windows. Native diagnosis only. |
| `experiments/trace_stickiness.rb` | Deliberately global chosen event versus targeted `:return` arm: this is the causal contamination experiment itself. Its trace tax is the subject, not a clean production price. |
| `experiments/endpoint_sections.rb` | Historical global `:call` link capture before cost windows. Retain only for its pinned diagnostic record; new clean-VM prices must replace/segregate capture. |
| `experiments/sealed_helpers.rb` | Same historical global `:call` capture and limitation. Not the production sealed pass or its current request driver. |
| `experiments/sealed_links.rb` | Same historical global `:call` capture; provenance variant additionally uses the next row's observer. No new clean-VM price on this factory as written. |
| `experiments/sealed_provenance.rb` | Historical global `:return` delivery witness and global constructor `:call/:return/:c_call/:c_return` semantics probe. The former also contaminates its historical pricing caller; production now records delivery directly. Retain as historical evidence, not a current pricing seam. |
| `experiments/endpoint_bodies.rb` | Historical global `:return` delivery witness, global `:line/:call/:c_call` contract observer (two enable sites), and global `:call` link capture. Contract events are intentionally global semantics evidence. The priced worker's boot/capture is contaminated and cannot price a clean production shape as written. |

No additional runtime `set_trace_func` or `trace_var` invocation exists in
these directories. No historical result was rerun, promoted or assigned a
new score by this audit. Keep the earlier missing-liveness audit distinct
from this tracing audit: an unproven hit is not proof of fallback pricing,
and a traced specimen is not evidence about an untraced VM.

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
