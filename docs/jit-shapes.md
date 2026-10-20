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

8. **Leave no profiling TracePoint active after setup, and avoid hot
   `binding`/`eval`.** YJIT explicitly recommends avoiding TracePoint/binding;
   ZJIT's `NoTracePoint` patchpoints and environment-escape assumptions are
   invalidated by these operations
   ([`invariants.rs:454ff`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/invariants.rs#L454)).
   Facts' script capture is build-only and stopped; Observe intentionally
   samples into execution and is not a benchmark configuration. The RSpec
   reporter's temporary `:end` TracePoint disables when RSpec attaches; a
   Minitest-only diagnostic run can retain that waiting reporter hook. Such
   verify diagnostics are not representative performance measurements.

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
