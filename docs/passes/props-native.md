# Props native dispatch predicate: stop at price

2026-10-21. **Accepted interpreter micro, still a loss: +1.384% Ir.
Stop at price; no retry, YJIT run, production integration or promotion.**
The ordinary-def Ruby-reflection shape separately still stops at its
[accepted interpreter loss](yjit-regression.md#corrected-interpreter-pricing-stop-at-price):
30,482.987 Ir of checks versus 4,445.573 Ir of unchecked iteration saving,
6.857×. Its YJIT micro remains cancelled. This is a separately requested
native alternative, not a rescore or retry of either historical cohort.

## Primitive and boundary

`Lowrail::Native.plain_hash_iteration?(object)` checks, on every invocation:

1. `CLASS_OF(object) == rb_cHash`: actual VM class, not `object.class`,
   `instance_of?`, `respond_to?`, or a materialized singleton class.
2. Both effective `Hash#each` and inherited `Enumerable#each_with_object`
   retain MRI's basic-definition flag.
3. Both effective methods are public. Basic-definition flags alone miss
   `Hash.send(:private, :each)` and protected methods. The additional
   `rb_method_boundp(rb_cHash, id, 3) == 1` checks exclude both.

There is no Ruby callback, receiver eigenclass creation, method-hook trust,
dispatch cache owned by Lowrail, or private VM-struct copy. `extconf.rb`
detects both C APIs; absent APIs make the predicate return false. The flag
argument is an **undocumented, deprecated MRI API**, not a portability
promise. The public visibility behavior is inspected in the pinned MRI
`vm_method.c` and witnessed on Ruby 4.0.7 revision `229531a6cf` and 4.1 preview
revision `2d08b5f42f`. New VMs need the same witnesses before support claims.

This certifies only the **audited unrefined iterator sites**, not an
arbitrary caller's lexical refinements. A caller-only `Hash#each` refinement
changes that caller's send, but neither the separately defined original
resolver nor the existing unrefined receiver guard. Tests preserve that
distinction rather than treating a refined top-level reflection as the
production guard. Registering an `each_with_object` refinement can clear the
basic flag and cause a conservative refusal even for an unrefined site.

The extension stays Ractor-unsafe: direct non-main calls raise
`Ractor::UnsafeError`. The pricing adapter retains the existing main-Ractor
check **before** consulting unit state or the primitive. It also retains
source activation, full unit/fact validation, statistics and a check at
**every** recursive traversal entry. Existing iterations are not restarted
after a callback mutates a later receiver. Production `inertia_props.rb`,
its builder and its emitted guard are unchanged.

The extension still loads symmetrically with Lowrail on/off, never compiles
at runtime, and uses the owner's per-Ruby/revision/platform output path.
Adding this function changes the whole binary and C-source certificate:
**recompile and rebuild artifacts; never reuse the previous native witness.**

## Witnesses and additional refusals

On both Rubies, `NativePropsTest` covers plain/frozen hashes, non-hashes,
subclasses, singleton/private singleton overrides, extend/prepend, both
private/protected methods, undef, method_missing/respond_to_missing?,
suppressed method_added, same-behavior Ruby redefinition, native aliases,
visibility mutation/restoration between traversals, refinements, and the
non-main-Ractor boundary. A warm identical-callsite N=0/N=1,000 allocation
control reports **0 / 0 allocations**, with the receiver still plain after
the calls. This is a hot-call observation, not a cold VM-metadata allocation
guarantee.

The interpreter lifetime fixture additionally passes **478 comparisons per
Ruby**, across Inertia 3.21.2/3.22.0/3.23.0: every discovered post-entry body
call boundary, suppressed receiver mutations, lazy callback mutation,
private iteration, subclasses, stale/malformed facts and a non-main Ractor.
Both native shapes preserve the original values, ordered effects and
once-only evaluation. Direct native witnesses pass **4 tests / 157 assertions**
per Ruby; existing native passivity/load tests pass **2 / 25**, and pricing
admission/refusal regressions **6 / 163** per Ruby. These are untimed checks.

Compared with the existing complete receiver reflection, the predicate also
refuses these otherwise accepted cases:

- An already materialized empty eigenclass, an unrelated singleton method,
  or an empty extension module. This deliberately avoids eigenclass lookup.
- Restoring `each` through a saved alias after redefinition, or reinstalling
  a captured native UnboundMethod via `define_method`: method equality may
  recover, while the BASIC flag does not. Direct `alias_method :each,
  :each_pair` remains accepted and is witnessed independently.
- The inherited-iterator refinement registration described above.

These are conservative refusals, not evidence of changed original behavior.
The unrefined differential receiver check must run **after** the native
decision: running it first creates the very eigenclass the candidate avoids.

## Exact operation census, not an Ir attribution

Both Rubies execute the same fresh-input whole resolver operation with
`guard_valid=true` and **two authorized entries per resolve**. Ten-operation
liveness companions give **20 authorizations / 0 fallbacks** in every checked
arm and zero counts in original/unchecked controls. The
[numeric export](props-native.json) retains both censuses, all arm liveness,
Ruby revisions and this orb's C-source/build/binary hashes.

| Receiver work per resolve | Existing complete Ruby check | Native predicate |
|---|---:|---:|
| `UnboundMethod#bind_call` dispatches | 12 | 0 |
| Of those: class / singleton_class / visibility / method lookup | 2 / 2 / 4 / 4 | 0 / 0 / 0 / 0 |
| UnboundMethod comparisons | 4 | 0 |
| Receiver class equality calls | 2 | 0 |
| Native predicate entries | 0 | 2 |
| Inside the two positive C entries | — | 2 class-pointer reads, 4 BASIC and 4 public-entry lookups |

The forwarded native calls are **inside** the twelve bind_call dispatches,
not twelve more independent operations. The two main-Ractor equalities,
active-unit hash lookups, Guard state access and cached fact checks remain.
No body/visibility requirement or recursive entry is elided.

The historical 30,482.987 Ir figure includes all checks and reflection side
effects; the operation census alone cannot determine its removable Ir
fraction. The separate native cohort below prices the replacement against
its own contemporaneous complete-check control, not by subtracting results
from different cohorts. The native predicate still pays method lookup, and
all outer checks remain.

## Reproduce without a measured window

```sh
# Build separately under each Ruby, from gem/.
mise exec -- rake compile
mise exec ruby@4.1.0-preview1 -- rake compile

# From the repository root; repeat with the preview Ruby for its witnesses.
LOWRAIL_STRICT_GATES=1 mise exec -- ruby -Igem/lib gem/test/native_props_test.rb --seed=1729
mise exec -- ruby bench/experiments/yjit_regression_test.rb --seed=1729
BENCH_JIT=0 mise exec -- ruby bench/experiments/yjit_regression.rb --census props_native checks_original
BENCH_JIT=0 mise exec -- ruby bench/experiments/yjit_regression.rb --census props_native native_checks_original
BENCH_JIT=0 mise exec -- ruby bench/experiments/yjit_regression.rb --liveness props_native native_split
BENCH_JIT=0 mise exec -- ruby bench/experiments/props_variant.rb --check-native /tmp/NEW-native-props-lifetime
```

The census is a disposable untimed process: its return observer targets only
the guard ISeq, and its global C-call observer only records calls while that
guard executes. Neither observer runs in a measured worker. Lifetime/pricing
source proofs now include the native C/build recipe and compiled binaries.
The harness regression forces the native predicate false and requires the
liveness gate to refuse, preserving fallback-priced-cohort protection.

The `props_native` group has original paired A/A controls,
Ruby-reflection `split` and `checks_original`, native `native_split` and
`native_checks_original`, plus unchecked `each`. All build fresh nested
inputs identically. Its one authorized interpreter cohort is complete; both
worker slots are released. No further cohort or integration follows.

## One finite interpreter price

Measured clean
[83bf0ba](https://github.com/thomasklemm/lowrail/commit/83bf0baa9c21d86955e31f626bbc466b60c41f9d),
Ruby 4.0.7 revision `229531a6cf`, Inertia 3.22.0, pinned Valgrind 3.19/brk512:
six rounds, seed 41231, N=1,000, **two workers maximum**, 42 independent
worker boots and 168 windows, one cohort and no retry. Both A/A controls,
all five heap pools, brk, actual interpreter mode and unchanged-source gates
pass. Before any window, every checked arm has `guard_valid=true`, **20
authorizations / 0 fallbacks** per ten resolves; original/unchecked controls
have zero counts. No Stats instrumentation runs in a priced process.

| Paired result | Total Ir, median [95% CI] | GC-excluded Ir, median [95% CI] |
|---|---:|---:|
| Complete native candidate versus original | **+1.383906% [1.360285, 1.409477]** | **+1.383817% [1.360197, 1.409653]** |
| Complete Ruby checks (`checks_original − original`) | 30,982.589 [30,705.145, 31,262.448] | 30,982.376 [30,675.444, 31,289.648] |
| Remaining native checks (`native_checks_original − original`) | 5,849.248 [5,821.248, 5,897.248] | 5,849.248 [5,821.248, 5,897.248] |
| Available iteration saving (`original − each`) | 4,445.369 [4,393.471, 4,471.573] | 4,445.471 [4,393.471, 4,471.471] |
| Complete-check cost removed | 81.188% [80.810, 81.296] | 81.058% [80.938, 81.297] |
| Remaining checks / available saving | **1.321176× [1.301877, 1.336813]** | **1.321176× [1.301877, 1.336813]** |

Original/native-checks-original allocate **55 / 55 objects per resolve**;
native-split/unchecked allocate **46 / 46**. Removing nine objects does not
make the complete candidate win. The paired remaining check-minus-saving
gap is **1,427.777 Ir [1,349.777, 1,479.777]**, about **24.309%
[23.188, 25.194]** of the remaining checks. These are medians of paired-round
differences/ratios, not differences/ratios of independently rounded medians.

**Stop this shape at price.** The primitive removes most reflection cost but
does not close the deficit enough. No retry, YJIT run or production props
integration is authorized. The older 30,482.987 Ir / 6.857× result and earlier
invalid fallback-priced cohort remain unchanged; this is not a rescore.
Production reflection/delivery remains uncertified, and no request saving
is claimed. Outer-check attribution is an untimed follow-up using retained
dumps/censuses, not another measured cohort.

[Sanitized numeric export](props-native-interpreter.json) retains both CIs,
all paired rounds, liveness, gate verdicts and Ruby/native/source/counter/tool
fingerprints. It contains no raw private app files, process environments or
Callgrind dumps. The native binary SHA is
`38f0f5b540a44e7e1c2597b04d0664b2e5ca194b65e736c50a1e506517a34f6a`;
the Valgrind tool SHA is
`5fe02646537c5669b032c5146665728f9dab384918fea30118b7c7df3dc30ad7`.

The single completed command, **not an instruction to retry**:

```sh
PATH=/tmp/vg/bin:$PATH CPATH=/tmp/vg/include \
BENCH_JIT=0 BENCH_JOBS=2 BENCH_REQUESTS=1000 BENCH_AA_TOLERANCE=0.5 \
BENCH_HEAP_SLOTS=1000000,250000,100000,20000,10000 \
env -u RUBYOPT -u RUBY_YJIT_ENABLE -u RUBY_ZJIT_ENABLE \
  -u BENCH_YJIT_LOG -u BENCH_JIT_CALL_THRESHOLD \
  mise exec -- ruby bench/experiments/yjit_regression.rb props_native NEW_OUTDIR
```

## Untimed attribution of the remaining checks

This is a read of the **retained 83bf0ba cohort**, not another cohort or a
rescore. Across six rounds × two native arms × both N=1,000 windows, all
**24** incoming `lowrail_plain_hash_iteration` edges report 2,000 calls and
1,132,000 Ir. Each edge reconciles to its native self cost plus four child
edges. The two calls cost **1,132 Ir/resolve, not approximately 50**:

| Native work per resolve | Ir |
|---|---:|
| BASIC lookup for `each` / `each_with_object` | 214 / 240 |
| Public visibility lookup for `each` / `each_with_object` | 288 / 314 |
| Native self: class check, argument handling, branches and return | 76 |
| **Native total** | **1,132** |

There are four BASIC and four visibility queries per resolve, not four
combined queries. The figures above include their lookup descendants. The
undocumented visibility query is not a cheap flag read. Therefore
**4,717.248 Ir** of the measured 5,849.248 remains outside the predicate.

The retained dumps also permit this disjoint machine-function accounting.
For each arm, subtract its N=0 self-cost table from its N=1,000 table, then
subtract `off_a`; collapse recursive function-name suffixes. Self-cost totals
reconcile to each dump's `summary`, and the paired result reconciles to the
published check cost. Inclusive native/`vm_defined` edges below replace,
rather than add to, their descendant self rows. Both modes give the same
rows; these are medians across six rounds, **not new component CIs**.

| Component | Ir/resolve |
|---|---:|
| Native predicate, inclusive as above | 1,132.000 |
| Disabled-Stats `vm_defined` calls and descendants | 630.000 |
| Ractor current/main builtin bodies and `equal?` body | 30.000 |
| `vm_exec_core`, incremental self cost | 2,284.105 |
| `rb_vm_opt_getconstant_path`, self | 504.000 |
| C-function frame dispatch helpers, self | 420.000 |
| Ruby ISeq setup helpers, self | 302.000 |
| `vm_call_ivar`, self | 128.000 |
| `rb_hash_aref`, self | 174.000 |
| Other machine-function self cost, after the inclusive exclusions | 245.143 |
| **Remaining complete-check cost** | **5,849.248** |

The Hash row varies 170–174 Ir and the residual 197.143–293.143 across
rounds. The other listed rows are constant. Do not sum inclusive annotate
rows: inlined source-file rows can duplicate the native function, and
recursive VM frames overlap. The incoming edges are authoritative.

### Ruby-component census and the disabled instrumentation tax

The VM table is **not** a per-Ruby-method Ir profile. Guard, activation and
body bytecodes all run in shared `vm_exec_core`; the retained dumps cannot
assign its 2,284.105 Ir honestly among them. A disposable targeted-ISeq
observer and the existing scoped C-call census establish the warm operation
counts instead:

| Operation per fresh whole resolve | Count |
|---|---:|
| Guard entry / positive authorization | 2 / 2 |
| `Ractor.current` / `Ractor.main` expressions / identity tests | 2 / 2 / 2 |
| `InertiaProps.active?` / active-table Hash reads | 2 / 2 |
| `Guard.state` getter / cached-state Array reads | 2 / 2 |
| `Guard.validate` / state writes | **0 / 0** |
| Native predicate | 2 |
| Disabled Stats conditional / nested-constant `defined` instructions | 2 / 4 |
| `Stats.enabled?` / counting / extra recursive checks outside those entries | **0 / 0 / 0** |

Stats is **absent**, not enabled, in these measured processes. Disassembly
shows two `defined` instructions per guard: first `::Lowrail`, then `Stats`.
Their four calls cost 630 Ir/resolve inside `vm_defined` and descendants,
before charging their interpreter opcodes. Merely removing counting work
would save nothing: no counter executes. The avoidable tax is testing for
disabled instrumentation at every traversal.

There is also no full unit-metadata lookup to cache on this warm path.
Hoisting its activation/state **booleans** per request would weaken the
callback boundary: a later traversal must still see invalidation. Caching
the backing table/array across `install` is not equivalent either; install
can replace them. Keep fresh reads unless a separate lifetime proof covers
replacement. Likewise, do not remove the main-Ractor guard from directly
callable helper entries. No supported direct main-Ractor predicate was
found in the installed public/exported C API; this report does not propose
copying VM structs or making the existing unsafe extension Ractor-safe.

### Candidate budget before combined-specimen preparation

First remove **only disabled instrumentation dispatch**: provide ordinary
non-counting/counting guard definitions, selected when installed and when
`Stats.enable!` runs later, following the existing `Lowrail.check` pattern.
The non-counting definition omits `defined?/enabled?`; the counting definition
retains exactly the current authorization/fallback counts, early Ractor
refusal and exception behavior. Both still perform Ractor, active-table,
current-state and actual-iterator checks at **every recursive entry**. A late
enable witness must prove no hit escapes counting. Optionally inline the
same guard expression in the ordinary-def entry to avoid its Ruby helper
dispatch, without hoisting any predicate. That dispatch saving is unpriced;
the machine-function table is not a fabricated estimate of it.

Removing the disabled conditional targets at least the identified 630 Ir
plus its VM opcodes, but **does not alone prove closure** of the paired
1,427.777-Ir gap. This is a candidate for correctness preparation, not an
authorization for integration or a new cohort.

For the independently prepared **frozen-holder** companion, native lookup
work is still real: freezing can remove the 1,056 Ir of BASIC/visibility
queries while retaining `exact_class?` on every receiver. Nevertheless even
a free predicate saves at most 1,132 Ir, below the paired gap; freezing alone
cannot close it. Combining that separately witnessed, symmetrically frozen
contract with non-counting/counting guard selection targets over 1,686 Ir of
identified work before replacement/interaction costs. That is the concrete
combined budget to investigate, **not an additive speed claim**. Freezing
is not a substitute for a certificate in the mutable guarded tier. The
freeze owner has this breakdown and remains prepared/unpriced.

After pulling the guard-dependency prerequisite
[7f9f97c](https://github.com/thomasklemm/lowrail/commit/7f9f97c19e13be2ab047d83e5fda8768cc112147),
untimed native-split admission still gives `guard_valid=true`, **20
authorizations / 0 fallbacks** per ten resolves on both Rubies. The current
`guard.rb` proof is
`9f0f1d99ee6593ac4594e5e0b092f2543195482e1523ceb15d7593624ce64437`.
This refresh does not change the historical cohort's source certificate.
No new Callgrind worker, slot, YJIT run or production change was used for
this attribution.

## Combined frozen-holder and selected-counting specimen

**Untimed preparation only; no combined cohort, integration or speed claim.**
The independently published freeze-only base is
[d5fbdf1](https://github.com/thomasklemm/lowrail/commit/d5fbdf13081a30b91b0430a353ab2fe412adbec2).
The combined specimen extends that same `bench/experiments/props_freeze.rb`,
not a parallel candidate or a changed `yjit_regression.rb` factory. Its
`frozen_split` and `frozen_checks_original` arms retain the main-Ractor,
source activation, current Guard state/cold validation and actual receiver
checks at every recursive entry. Only the frozen method census and disabled
Stats dispatch are removed. No admission boolean or receiver authorization
is carried across app callbacks.

`Hash`, `Enumerable` and their complete ordinary/singleton ancestry are
frozen without an observer in **every** arm at the declared preparation
point. The native original-iterator/public-visibility precondition must pass
before freezing. Per-instance singleton mutations remain legal and force
the original fallback; forbidden holder mutations raise symmetrically.
This is the explicit frozen contract, not transparent behavior for mutable
apps. First Ractor startup is warmed symmetrically only in the Ractor
lifetime witness: its cold Kernel prepend after freezing remains a refusal.

Two ordinary guard definitions are selected by alias at installation and
late `Stats.enable!`. Neither definition tests `defined?/enabled?` on its
warm path: the counted one counts directly, the uncounted one never counts.
The Stats library and selection hook are explicitly preloaded in **all**
arms without enabling counters. This declared setup differs from the old
Stats-absent cohort; do not silently reuse its price for the new shape.
There is no production Stats change or global lazy-require observer.

**Alias-only selection is insufficient.** Enabling Stats from inside an
already executing guard loses its current authorization: the negative
control reports one hit instead of two. The specimen records one completion
marker in the uncounted frame. Only when Stats is enabled, a return observer
targets that retired guard ISeq, preserving pending normal decisions while
new entries use the counted definition. Early non-main returns and rescued
guard errors are not counted. The observer is never enabled globally and
does not exist in a Stats-disabled pricing process. Its marker/local cost
is part of the future price, not an excluded cost or a free saving.

Both Rubies pass the focused **6 tests / 115 assertions**: eight-arm 20/0
liveness with zero-count controls, forced-false refusal, symmetric forbidden
mutation, initial-off/late-on/already-on/repeated enable/reset, once-only
callback enable plus receiver mutation, and in-flight positive/refused/error
decisions against the existing inline-Stats native guard. Stats has no public
disable API; these witnesses do not invent an unsupported off toggle.
The strict native/guard/freeze tests also pass **16 / 239, no skips** per
Ruby; Cargo passes **39 + 1 + 8**. Disassembly and a trapped `Stats.enabled?`
confirm that the disabled warm guard has no Stats test/count opcode or
enabled observer.

All four complete interpreter matrices pass **478 / 478 comparisons each**:
Ruby 4.0.7 and 4.1 preview, each with counting enabled and with the actual
non-counting guard. That is **1,912 comparisons**, covering Inertia
3.21.2/3.22.0/3.23.0, both frozen shapes, every discovered mutation boundary,
callbacks, receiver overrides/visibility, stale/malformed facts and the
explicitly bootstrapped non-main-Ractor witness. These are lifetime proofs,
not a measured cohort; no Callgrind slots were used.

The fc40772 preparation retained these SHA-256 pins, including the unchanged
factory and iteration emitter. Both native binaries are built separately,
not copied between Rubies; private paths and raw per-case files stay local.

| Combined preparation input | SHA-256 |
|---|---|
| `bench/experiments/yjit_regression.rb` | `dfa1a3ee0d9bcdb4a4730dbf14b6d0e2092faba4dad0fe64ee51832e486d2422` |
| `bench/experiments/props_variant.rb` | `e6be6f9060798195719536e3dab348ed6359f8bfaf88630a97530ba350ddcbeb` |
| `bench/experiments/props_freeze.rb` | `35a0a66ea1349a71c559cb7f0baa73d63161a48bc992541bdf5ddf5ec54830f6` |
| `bench/experiments/props_freeze_test.rb` | `29d23691beb2c64f22c30c3058ccc2a27473b567d8dd4984962ec5b0b943c7a7` |
| `gem/lib/lowrail/guard.rb` | `9f0f1d99ee6593ac4594e5e0b092f2543195482e1523ceb15d7593624ce64437` |
| `gem/lib/lowrail/stats.rb` | `d1a7924403ddc296abab4fdd85ef8b18428d8a0632bab9a32d3e2683b6f0a311` |
| `gem/lib/lowrail/freeze_audit.rb` | `8446079e2924aea41b806bb2485136e4ae6376d04655feacf8ec2e7ac9fcf87e` |
| `gem/ext/lowrail_native/lowrail_native.c` | `c6d69bf723c3f5c942d3ea1ebfbebe8ce17978b57fca86b2bd3338a7f70c2b10` |
| Ruby 4.0.7 `229531a6cf` native binary | `38f0f5b540a44e7e1c2597b04d0664b2e5ca194b65e736c50a1e506517a34f6a` |
| Ruby 4.1 preview `2d08b5f42f` native binary | `956dd758c2970ebba428365d87bd9832ee45affa423f6149656520e030972169` |

Run the complete three-version lifetime matrix separately for each selected
guard definition, under each Ruby:

```sh
BENCH_JIT=0 LOWRAIL_FREEZE=1 mise exec -- ruby \
  bench/experiments/props_freeze_test.rb --seed=1729
BENCH_JIT=0 LOWRAIL_FREEZE=1 mise exec -- ruby \
  bench/experiments/props_freeze.rb --check NEW_COUNTED_OUTDIR
BENCH_JIT=0 LOWRAIL_FREEZE=1 mise exec -- ruby \
  bench/experiments/props_freeze.rb --check-uncounted NEW_UNCOUNTED_OUTDIR
# Repeat under: mise exec ruby@4.1.0-preview1 -- ruby ...
```

The uncounted matrix uses **untimed targeted return receipts**, not Stats
activation, to satisfy the pinned gate's positive-authorization checks while
executing the actual non-counting ISeq. No such observer belongs in a priced
worker. Proofs retain the statistics mode and current specimen/factory,
Guard, runtime, native C/build/binary fingerprints. Liveness additionally
requires current manifest format and interpreter certification/actual mode.
No measured-worker/cohort entrypoint is added here; request a separate
two-worker allocation only after these proofs pass.

## Tracked pricing launcher and zero-window invalid attempt

The initial private launch on fc40772 is **invalid/unpriced**. Its worker
branch expected `--worker`, but `RequestPairs.heap_instructions` passes the
route argument `unused`. One worker exited on the output-directory check;
the other re-entered the controller and spawned two nested children. Thus
three Callgrind processes overlapped, exceeding the two-process cap. All
four dumps report `totals: 0`: **zero measured windows and zero completed
rounds**, not evidence for either a saving or a permanent price stop.
All six admission companions and the pinned-tool preflight had passed.
The failed launch was stopped without retry/salvage and both slots released.
The original private launcher SHA-256 is
`ccf9595de832045498a37b0c2cb462c17ed0d983cafe9cc279363e3d4493150e`;
its source, logs, zero-Ir dumps and nested outputs remain local evidence.

The separately authorized first measurement uses the tracked
`bench/experiments/props_freeze_price.rb`. Explicit inherited worker roles
accept **only** the exact `unused` route and reject controller arguments;
an absent role never treats that route as a controller output directory.
Each child verifies its parent PID, current source proof and positive
admission. Worker-local Kernel/Process/IO guards reject system, spawn,
fork, exec, daemon, backticks and popen before freezing, symmetrically in
all arms. The controller supervises the actual `system` launch boundary:
two mutex-held permits span each child's lifetime, and a third attempt
raises **before spawn**. Peak/active/refusal counts are retained even on
failure. These are benchmark process controls, not production changes.

The exact-route **native E2E check passes** with no Callgrind process:
all six unique arms, seven direct worker boots including off-A/off-B, N=3,
**28 executed windows, 14 positive operation windows**, all with allocation
work; original/checks arms allocate 165 objects in each positive window,
split/unchecked arms 138. Every child reports the controller as parent;
all PIDs are unique, no nested controller, peak **2**, final active/refused
**0/0**. Counted companions authorize 20/0 in checked arms and 0/0 in
controls. This validates plumbing, not Ir or A/A. The specimen, iteration
factory, guard/runtime/native inputs still match the fc40772 lifetime proof.
Both Rubies additionally pass **9 tests / 128 assertions**: the existing
Stats/freeze witnesses plus wrong-role/route controller refusal, twelve
child-process API refusals, and a concurrent third-launch negative control
whose callback never runs. The tracked launcher SHA-256 is
`fdaa43bccb075b6ab5f873a77480b7dd2ca8a2d7b1cd976e4f3340c43d6660ef`.

```sh
# Native-only exact-route check; NEW_CHECK_OUT must not exist.
PATH=/tmp/vg/bin:$PATH CPATH=/tmp/vg/include BENCH_JIT=0 BENCH_JOBS=2 \
  mise exec -- ruby bench/experiments/props_freeze_price.rb --check NEW_CHECK_OUT

# Only with the separate two-slot authorization; PIN is the published head.
PATH=/tmp/vg/bin:$PATH CPATH=/tmp/vg/include BENCH_JIT=0 BENCH_JOBS=2 \
BENCH_REQUESTS=1000 BENCH_AA_TOLERANCE=0.5 \
BENCH_HEAP_SLOTS=1000000,250000,100000,20000,10000 PROPS_FREEZE_PIN=PIN \
  mise exec -- ruby bench/experiments/props_freeze_price.rb --cohort NEW_OUT
```

The one cohort keeps seed 41231, six rounds, seven labels, 42 independent
boots, 168 windows and **every shared A/A/heap/brk/mode/source gate unchanged**.
Stats stays preloaded but disabled in all measured arms, with no observer.
Both native reference arms are also frozen; their predicate still performs
the BASIC/visibility queries. Compare native/frozen check costs and unchecked
iteration saving **within the new paired rounds**, not by re-scoring the
historical 83bf0ba cohort. The marker/replacement costs are inside the measured
candidate. Unless net paired savings establish break-even after the agreed
1,428-Ir gap and these costs, props stops permanently. No retry or salvage.

## Strict-gate provenance

Both complete strict suites pass with the native candidate over
[9e61c52](https://github.com/thomasklemm/lowrail/commit/9e61c52): Ruby 4.0.7
**162 tests / 6,123 assertions**, one optional Rails profiling-bundle skip;
Ruby 4.1 preview **162 / 5,155**, that same skip plus the three explicitly
Ruby-4.0-only cold-blog, sealed-link and sealed-form fixtures. After pulling
the audit/evidence additions through
[315d56f](https://github.com/thomasklemm/lowrail/commit/315d56f), Cargo passes
again and both Rubies pass the combined native/new freeze-audit gates
**11 / 205**, plus harness **6 / 163**. The native source/binary fingerprints
and both 478-case lifetime proofs remain identical. The full-suite counts
above do not silently include the five subsequently added freeze-audit tests.

The primary cold-blog gate uses the native owner's canonical source export
(archive SHA-256 `ad1ccb8cc926b06e0a20643cc8975cf37fd20c5d74839195bc5c6e7c819dc761`),
with source pin `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`
and lock pin `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
Extract into a new corpus directory, install with the frozen lock, and use a
disposable `LOWRAIL_TEST_CORPUS_ROOT`; do not overwrite existing sources or
change shared entropy pins. Its `real-blog-r4` must be a **physical copy**:
the observed-run recorder filters expanded root paths while Rails reports
real source paths, so a symlink overlay yields no controller samples. That
fixture mistake was reproduced and corrected; no recorder/runtime code was
changed, and the corrected gate passes **1 / 11** before the full rerun.
