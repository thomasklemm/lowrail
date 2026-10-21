# Lowrail JIT shape guide: YJIT and ZJIT

2026-10-20. Optimize emitted Ruby for **both JITs**, without changing Ruby
semantics or treating a JIT preference as a correctness proof. Ruby 4.0.7 is
measurement-primary; 4.1 is also a correctness target. Its gem suite and
[five-app correctness matrix with dependency overlays are green](ruby-4.1.md).
No pass changes are part of this guide. The guarded endpoint slice was
[stopped](https://github.com/thomasklemm/lowrail/commit/5f81980fb0cee2cfee6c379c25fd29b71c48389e);
its singleton-class rewrite is dropped, not a pending runtime task. Retain
the finding below for future/sealed code.

Sources below pin Ruby to
[`2d08b5f`](https://github.com/ruby/ruby/commit/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1)
and Roundhouse's
[Fractal JIT rules](https://github.com/rubys/roundhouse/blob/b6e6a68b828b09dfeca1c95c4b5a83b2f226fbe0/docs/pipeline/fractal.md#jit-shape).
These are implementation-specific preferences, not permanent Ruby restrictions.

## Rules and their concrete reasons

1. **Prefer a whole-method variant in its own ISeq.** ZJIT profiles and compiles
   a method at a time; mixing the original and specialized arms in one method
   shares its profile and expands its control flow. YJIT compiles blocks and
   specializes contexts, so the cost is not automatically the same. Preserve
   the method's lexical constant scope, parameters, visibility and original
   fallback. Source: Fractal's first rule and Ruby's
   [ZJIT overview](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/doc/jit/zjit.md).
   [Finite YJIT ablations](passes/yjit-regression.md) put the same tiny body
   at 441.965 Ir in a plain/separately selected def, versus 470.965 with an
   inline G branch. The selected-def binder saves 75.835% versus original;
   the existing guarded binder saves 65.215%. These are micro shapes, not
   whole-request promotion or permission to drop guards.

2. **Choose at load time only when the lifetime of the facts is covered.**
   Fractal avoids per-call checks and avoids compiling an original only to
   redefine it after warmup. Both JITs invalidate method assumptions when the
   method entry changes
   ([`vm_method.c:314–345`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/vm_method.c#L314-L345)).
   Lowrail's facts can change during a call, including with suppressed hooks.
   **Do not turn today's guards into load-only checks.** An exact alternative
   needs immutable facts, complete invalidation before the next use, or a
   refused specialization; a stale compiled method is not acceptable.

3. **Emit `def`, not a block-backed `define_method`, for hot variants.**
   Both JITs support some BMETHODs; this is not a blanket unsupported claim.
   ZJIT's direct-send path requires no passed block and an ISeq-backed Proc;
   an unshareable Proc also needs single-Ractor mode
   ([`hir.rs:5051–5087`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/hir.rs#L5051-L5087)).
   YJIT has corresponding Proc/Ractor handling and declines a block passed
   to a BMETHOD
   ([`codegen.rs:7495–7537`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/yjit/src/codegen.rs#L7495-L7537)).
   Build-only Prism visitors using `define_method` are not request overhead.
   A no-block YJIT body costs only 444.965 versus 441.965 Ir as a def in the
   finite shape micro; BMETHOD alone is not the config request regression.

4. **Keep hot call sites receiver/name-stable; prefer direct named calls to
   dynamic `send`.** A receiver-type guard plus a direct send can expose an
   inlineable callee to ZJIT; polymorphic sites can remain dynamic or need
   extra dispatch. YJIT also spends contexts and guards on receiver variation.
   Sources: ZJIT's `SendPolymorphic`/`SendDirect` handling in
   [`hir.rs`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/hir.rs)
   and YJIT's advice to keep variable/argument types stable in
   [Code Optimization Tips](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/doc/jit/yjit.md#code-optimization-tips).
   Do not devirtualize an app-overridable send without a certificate at the
   actual use boundary. Literal dynamic sends may be optimized already.

5. **Use a consistent ivar initialization order for objects Lowrail owns.**
   Shapes describe layouts; ZJIT emits `GuardShape` at profiled ivar accesses
   ([`hir.rs:6147–6370`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/hir.rs#L6147-L6370)).
   YJIT's `gen_get_ivar` likewise guards layout
   ([`codegen.rs:2929ff`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/yjit/src/codegen.rs#L2929)).
   Conditional ivar introduction/removal can add shapes and guards. Do not
   preinitialize observable controller/model ivars just for a JIT: this changes
   `instance_variables`, assigns and possibly app behavior. Existing Lowrail
   Entry/Execution objects initialize their own fields together.

6. **Never create singleton classes on ordinary receiver instances in a hot
   check.** ZJIT's no-singleton-class assumption is per receiver class:
   creation can invalidate direct sends for other instances too
   ([`invariants.rs:335ff`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/invariants.rs#L335)).
   YJIT has `assume_no_singleton_class` and the
   `invalidate_no_singleton_class` counter. Distinguish ordinary instances
   from class/module singleton setup; do not remove visibility or effective
   method checks to avoid the singleton class.
   **Bound `Kernel#public_method` is not a drop-in exact replacement.** On
   a missing/undefined method it calls application `respond_to_missing?`;
   captured `Module#instance_method` raises without that callback. This is
   observable even when both ultimately raise NameError. Confirmed on 4.0.7
   and the pinned preview: remove `link_to`, record callback names, then the
   old lookup records `[]`, `public_method` records `[:link_to]`. Source:
   [`proc.c:2547–2561`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/proc.c#L2547-L2561).
   Future sealed code must not create eigenclasses as provenance evidence;
   use an exact certified factory boundary or retain ordinary dispatch, and
   price all residual checks. Array enumeration before lookup may avoid the
   missing-method callback, but is not a demonstrated cheap/atomic guard.
   The real nested props micro confirms this cost independently: +68.962%
   guarded, versus −11.255% with only its guard replaced by cached G, and
   17 extra singleton-class send fallbacks per resolution. The latter is an
   intentionally inexact ablation, not an implemented replacement.

7. **Avoid unnecessary splat, keyword-splat, forwarding and passed blocks in
   a certified hot path; inspect actual fallback/exit counters.** Not all of
   these side-exit. Some use a generic send instead, and literal blocks are
   often optimized. ZJIT explicitly leaves `sendforward`/`invokesuperforward`
   unoptimized in this pin (`hir.rs`, `SendForward`/`InvokeSuperForward`);
   direct-call argument handling is at
   [`hir.rs:2742ff`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/hir.rs#L2742).
   YJIT's
   [`stats.rs`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/yjit/src/stats.rs)
   names concrete splat/keyword/BMETHOD/block side-exit and fallback reasons.
   Preserve keyword separation, arity, block identity and once-only evaluation;
   a generic public signature may still require forwarding on fallback.
   Finite YJIT evidence: direct/splat 481.965/567.965 Ir; literal keyword/
   Hash kwargs 482.965/1,194.136; mono/eight-class sends 546.965/696.090.
   Price the actual public signature instead of extrapolating these deltas.

8. **Never use global TracePoints for production or reporter readiness;
   avoid hot `binding`/`eval`.** Disabling a global return hook does not restore
   executable instruction shape on Ruby 4.0.7 or the 4.1 preview: the VM's
   historical mask remains set, including for future ISeqs. YJIT exits at
   `trace_leave`; disasm/to_a print bare `leave`, so use executable counters.
   The finite unrelated-body micro adds exactly 157 YJIT / 72 interpreter
   Ir per return after disable. A targeted boot-only return hook exactly
   matches off; native `exit_trace_leave` is 0 instead of 1,000 per 1,000
   calls on both VMs. Production activation targets initialize! only;
   Loader records delivery directly, with nontracing lazy readiness hooks.
   [Diagnosis, inventory and evidence](passes/yjit-regression.md);
   [pinned Ruby mechanism](upstream-drafts/ruby-sticky-trace.md).
   YJIT explicitly recommends avoiding TracePoint/binding;
   ZJIT's `NoTracePoint` patchpoints and environment-escape assumptions are
   invalidated by these operations
   ([`invariants.rs:454ff`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/invariants.rs#L454)).
   Global `:end`/`:class` (also `:call`/`:return`) changes lazily materialized
   VM builtin ISeqs from `opt_invokebuiltin_delegate_leave` to
   `opt_invokebuiltin_delegate`. That shape can survive disable and must not
   be normalized out of a certificate. RSpec now attaches through its public
   configuration/formatter API; the load census uses AS readiness and
   Zeitwerk constant/setup hooks. Neither enables a TracePoint. Both targets
   preserve the five affected builtin facts; the primary's complete sealed
   form inventory and cold hits are covered too.
   [`doctor --trace-check`](passes/yjit-regression.md#reporter-readiness-and-global-tracing-audit)
   reports selected builtin shapes as well as return counters, with explicit
   limitations. Facts' global `:script_compiled` capture is build-only and
   preserves the fused builtin in fresh-process controls. Observe intentionally
   samples into execution and is not a benchmark configuration.

9. **Mutate guard containers, not their constant bindings.** `G[id] = ...`,
   `K[id] = ...`, `V[id] = ...` change Arrays/Hash entries, not the `Lowrail::G`,
   `K`, `V` constants. They do **not** call the VM's constant-redefinition
   hooks. Constant assignment/removal does, potentially invalidating compiled
   constant assumptions in both JITs (same `vm_method.c` source as rule 2).
   A warmed preview API probe under interpreter/YJIT/ZJIT observes **0**
   constant-cache invalidations for 2,000 triples of container writes, then
   **4** after removing/reassigning G with populated read sites. This is a
   cache probe, not proof of a usable epoch, nor a performance cohort. Avoid
   fresh runtime `const_set`/`remove_const`; cold setup constants are different.
   The finite 4.0.7 YJIT G/K/V entry-write micro likewise records zero
   invalidations; container reads still cost instructions (cached G/K/V
   examples 474.965/518.965/837.930 Ir versus 441.965 bare).

10. **Keep hot callees small enough to be considered for ZJIT inlining, not
    artificially small at any semantic cost.** The preview's default callee
    threshold is **30 encoded YARV words**, not 30 instructions or Ruby lines;
    its cumulative caller budget is **200 HIR instructions**, not the same
    unit. Other eligibility tests still apply, and large methods can still
    compile. Sources:
    [`options.rs:34–47`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/options.rs#L34-L47),
    [`hir.rs:5790–5834`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/hir.rs#L5790-L5834).
    YJIT warns that Ruby calls/layers themselves cost; do not split methods
    just to cross ZJIT's threshold. Measure the whole guarded operation.

11. **Certify in the startup JIT mode, then observe initialization drift.**
    YJIT enablement can replace core methods, not merely change execution:
    the untimed config-only request attribution found 0 hits / 9,911
    fallbacks when an interpreter certificate expected C `Array#each` but
    YJIT used `<internal:array>:219`. Keep that guard exact. Build with
    `--jit interpreter|yjit|zjit`; manifests record `certification_jit` and
    setup refuses a different/unknown mode before installers. Deploy YJIT
    with `RUBY_YJIT_ENABLE=1` or `--yjit`. Enabling it only through Rails'
    `config.yjit` can drift after admission; targeted initialize! completion
    reports that in debug/stats/verify/bench, without uninstalling or forcing
    the app's mode. Regressions cover both early mismatch directions and a
    warmed Array#each certificate invalidated by real Rails late enablement.
    This closes admission/attribution, not the rejected cohort or promotion.

12. **Prove live authorization before pricing a guarded shape.** Source-active
    or installed is insufficient: a stale micro manifest can make every call
    fall back, and can short-circuit reflection so a purported checks-only arm
    omits its expensive predicates. The first ordinary-def props interpreter
    cohort passed numerical controls but used format 1 against a format-2
    reader: **0 hits / 20 fallbacks** in ten untimed resolutions. It is retained
    as invalid pricing, not a complete-guard cost. Use the runtime's format
    constant and explicit actual mode, reject admission failure, then require
    positive authorizations / expected fallbacks for every guarded arm in
    source-pinned native companions **before any measured window**. Keep Stats
    out of measured processes; it replaces methods and cannot be undone by
    toggling a flag. Corrected props probes authorize 20/20 with zero fallbacks
    in both modes on both Rubies. Historical micros lacking this gate remain
    coverage-unproven, not retroactively rescored; inspect their **paired
    factory/reader pins**, not today's reader or their publication date.
    [Failure, correction and admission-factory audit](passes/yjit-regression.md#first-pricing-attempt-numerically-green-invalid-fast-path-pricing).

13. **Select instrumentation outside the warm path, but preserve active
    frames on late enable.** Retained native-props interpreter dumps charge
    630 Ir/resolve inside the disabled Stats constant checks alone. Separate
    ordinary counting/non-counting definitions remove that warm conditional;
    alias selection alone is not exact when enable happens inside an already
    executing guard (one authorization instead of two). The frozen-holder
    specimen witnesses both definitions, with a completion marker and a
    targeted retired-ISeq return observer only after Stats activation. Its
    disabled worker has neither a Stats query nor a trace. Keep main-Ractor,
    admission and actual receiver checks at every recursive entry. This is
    untimed correctness evidence and an interpreter cost target, **not a
    combined or YJIT saving**. The marker and replacement call shape still
    need pricing. [Accounting and specimen](passes/props-native.md#combined-frozen-holder-and-selected-counting-specimen).

## Concrete Lowrail audit and exact alternatives (not implemented)

| Current place / cost | Alternative and required boundary |
|---|---|
| Historical source lowering (`src/lower/route.rs`, `view.rs`) puts K/ok? or G/check plus both arms in the original method | A separately profiled whole-method `def`, selected before first use, preserving lexical nesting and an exact original body. Only if facts cannot change, or complete invalidation/local continuation protects every use. The quarantined passes remain quarantined; moving their existing checks to load would be wrong. |
| Stopped guarded endpoint: `gem/lib/lowrail/endpoint.rb`, `Entry#template_current?` and `#helper_current?`, use bound `singleton_class` on each live view | Do not carry this into future/sealed code. Bound `Kernel#public_method` plus `unbind` reads `CLASS_OF(obj)` without creating an eigenclass, but the missing/undefined-method callback above makes the simple replacement inexact. Comparing only `view.class.instance_method` misses singleton overrides. No runtime rewrite or pricing cohort was performed after the owner dropped this step. |
| Endpoint generated `_run` wraps inline template bodies/collection dispatch; `process(action, ...)` and Execution forward arguments | Retain real def ISeqs, but choose one separately compiled template method per certified shape and explicit call signature for a closed endpoint. Keep original generic `_run`/`process` as fallback; preserve locals, buffer restore, CREF, events, streaming and every live helper boundary. No wholesale endpoint bypass. |
| `ARInstantiate.source` emits a real `def _load_from_sql`, but carries entry/per-row certificates, blocks and original arms | An entry-only variant is not exact: notification subscribers and preceding rows' callbacks can mutate methods/schema. Retain per-row `plan.current?`; if a whole certified component can have separate original/fast ISeqs, price that complete guard/dispatch cost, without replaying rows. No safe load-only alternative established. |
| `AR.hooks_for` uses `define_method` with `*args, **kw, &blk` closures | Generate real def hooks with signatures from audited methods and an immutable setup-time event/target table. Preserve private visibility, alias/super behavior and hook semantics. Only helps schema/mutation paths unless those methods are hot; do not count build-only define_methods as request work. |
| Inertia Config's Variant already uses `def` and owns a stable initialization order, but calls `valid?` and creates a live options copy | A separate def still needs the exact options/schema/method boundary; freeze-at-boot or removing live-copy semantics is not an alternative. Keep `valid?`, and measure a certified fixed-key copy rather than claiming kwargs syntax always exits. |
| Stats installs counting replacements, keeps G cold, and receiver checks count on every call | Keep this in verify/untimed coverage only. Bench already clears Stats for measured workers. Diagnostic ratios from counted verification are not production ratios. |

## Cheap build-time check

`Lowrail::Compiler` walks each emitted file/endpoint binary's child ISeqs,
without evaluating it. It adds `pass: "jit/shape", outcome: "warning"` rows
to the existing ledger, preserving pass refusals and units. Reasons:
`dynamic_send`, `block_method`, `singleton_class`, `call_shape`,
`tracing_binding`, `constant_write`, `inline_size`, `uninspected`.
Recompilation replaces only its previous shape rows.

The size check sums encoded instruction/operand words, excluding line/event
markers and nested child bodies. Call flags use the pinned ISeq serialization
and VM call-flag bits (splat 1, blockarg 2, keyword-splat 128). Unknown format
or inspection failures become **uninspected**, never a broken app. Templates
compiled later by Action View and runtime-installed variants get explicit
uninspected ledger rows, not a false clean bill.

This is intentionally warning-only. It cannot prove receiver monomorphism,
ivar initialization order across paths, TracePoint lifetimes, or whether a
singleton operation is on an instance or on a module at setup. It scans both
original and fast arms in delivered binaries; a warning is not attributed
exclusively to newly lowered code. Do not refuse correct code merely for being
large or accepting a block, and do not remove safety guards to silence it.

## Diagnostic counters, never gates

Set `LOWRAIL_JIT_DIAGNOSTICS=1` on verify or bench. Verify's common
Minitest/RSpec outcome writer saves separate process snapshots, and Rust
retains them in `last.json` at `report.off/on.jit_diagnostics`; fork/aggregate
merging does not add lifetime counters together. `ruby_descriptions` records
the actual outcome writers even without diagnostics.

Bench saves one snapshot in **untimed** `coverage.jit_diagnostics`. The flag
is explicitly cleared in measured workers and micro probes, and no stats
option is injected into timed execution. The flat gate, A/A, heaps, counters,
warmup and settling code are unchanged. Historical runtime libraries may not
have the delivered-method annotation hook; their process counters remain
available, with no manufactured per-unit attribution.

`RubyVM::YJIT.runtime_stats` and `RubyVM::ZJIT.stats` expose process totals.
The output keeps their numeric counters plus explicit nullable exit count,
invalidation count and `ratio_in_jit` (YJIT `ratio_in_yjit`, ZJIT
`ratio_in_zjit`). Availability depends on the build/stats options. The preview
release's default options provide ZJIT compiled/failed ISeq counts and
invalidation time, but not executed exits, an invalidation count or execution
ratio. An **untimed** `--zjit-stats` probe does expose `side_exit_count` in
this release build; it still exposes no invalidation count, and
`ratio_in_zjit` additionally needs a `ZJIT_STATS` build's interpreter instruction
counter (`stats.rs:939–948`). Do not inject that instrumentation into these
measured cohorts. **Compiled exit stubs are not executed side exits. Missing
is null, not zero.**

Neither public API exposes per-ISeq exits/invalidations/ratios. File delivery
optionally retains named method ISeqs with candidate unit IDs and YJIT's
`insns_compiled` instruction-version count (index/opcode pairs, not flat Array
length) where available; that is compilation evidence, not fast-arm execution.
Zero is not proof that no work was JIT-inlined into a caller.
It excludes runtime/template variants and does not repair
that attribution gap. Retained wrappers and the snapshot itself perturb the
process, so its scope is labeled **process lifetime including boot and
diagnostics**, not a measured-window delta.

## Pass decision rule

Require identical supported outcomes/fast-path hits first, **no interpreter
regression**, and a gain in the **guard-included YJIT micro gate**. Add ZJIT
micro evidence later, after the blocked matrix and strict stability seam are
resolved; never use this research as a ZJIT promotion gate. Keep whole-request
JIT results diagnostic while the flat gate rejects. Compare the same app and
same Ruby binary with/without the change, preserve finite rejected cohorts,
and report Ir separately from native CPU/wall time, objects/bytes, retained
memory and GC. No retry-to-green or relaxation of existing gates.
