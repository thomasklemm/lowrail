# Bet Z: work with the JIT, not around its invalidation

2026-10-22. **Best upstream lead: ZJIT direct sends with empty `**kwrest`.**
The restricted prototype reduces compiled-caller micro elapsed time 62.49% and
removes 15/6 kwrest fallback-counter increments per blog/Fizzy request.
Interpreter Callgrind Ir is exactly unchanged. A **fork-only PR draft** is
prepared on `thomasklemm/ruby:thomasklemm/zjit-empty-kwrest`; nothing was
submitted upstream. **Whole-request wall gain remains HOLD.**

Aaron's direction is sound for method dispatch: retain calls and let the JIT
specialize them under its own method-entry dependencies. It does **not** make
already-erased calls, precomputed SQL plans, or folded mutable configuration
safe. This investigation does not establish that a JIT recovers Lowrail's
historical form/DirectSite savings.

## Scope and evidence

- Actual source for **both JITs**, pinned to Ruby master
  [5f2bc22560](https://github.com/ruby/ruby/commit/5f2bc22560e9063fb8dec736afbf378251cad3ec).
  Source links below all use this pin, not moving master. Built out of tree
  with `--enable-yjit=stats --enable-zjit=stats --disable-install-doc`.
- Lowrail base [ac17871](https://github.com/thomasklemm/lowrail/commit/ac17871);
  no production lowering/admission changes. Ruby 4.0.7 passes were **not**
  admitted by pretending master was 4.0.7.
- [jit-internals.json](jit-internals.json) retains paired workers, exact
  response digests for seeds 0/1, call censuses, selected JIT counters, build
  hashes, discarded iterations, micro code, Callgrind results, dependency
  overlays, entropy policies, historical audit, and upstream PR samples.
  Per-ISeq call-count maps and unrelated counters are omitted, not zeroed.
- [jit_hooks.rb](../bench/experiments/jit_hooks.rb) runs isolated production
  Rack workers and the focused micro. Exact, traced-call, stats and wall
  phases are separate: **TracePoint allocation/time is not a price**.
  NativeBench's existing 5,000-resample paired-round estimator is reused from
  [6510cd2](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8).
- Blog `GET /articles/1`: retained blog fixture, Rails 8.1.4. Fizzy
  `GET /buckets`: corpus plus `vm_epoch_fizzy_setup.rb`, signed normal Session
  cookie, one census bucket. **This is smaller than historical bet F's
  fixture**; its −572 objects are not attributed using this specimen.
  Master's external Fizzy bundle uses redcarpet 3.6.1 rather than 3.6.0 to
  build on master. App source/checked-in locks are not edited.
- Wall screens: serial CPU-2 workers, 1,200 warm requests, 300 measured
  requests, three rotated base/base/patch rounds; stats disabled during wall.
  These are diagnostic screens, **not Lowrail's fixed-heap/JIT-flat acceptance
  protocol, full Rails verification, or a production support claim**.

## Ranked mechanisms

| Rank | Mechanism / Lowrail action | Gain evidence or estimate | Change boundary | Decision / main risk |
|---|---|---|---|---|
| 1 | Empty kwrest → ZJIT `SendDirect`; keep Ruby calls visible | Micro elapsed −62.49%; 15/6 request fallback increments removed; no resolved request gain | Small **upstream ZJIT** change, prototyped on fork | Prepare draft; do not generalize to all kwrest |
| 2 | Leave ordinary sends in the ISeq; use JIT CME guards/inlining | Dispatch is already optimized; recovery of −377/−572 objects **unproved** | **No patch** to benefit from existing machinery; more JIT inlining may need upstream work | Preferred representation; not a certificate for manual inlining |
| 3 | Avoid per-object singleton classes; deliver stable methods once | Prior K: Fizzy fallbacks 243→469/request from guards | **No patch** if a passive, exact check exists; otherwise refuse | Do not weaken exactness to improve a counter |
| 4 | Optimize reads of already frozen literal tables inside JIT | Blog removes 35 frozen TAG_TYPES reads/request in stack; time share unknown | **Upstream JIT** fold, not a new app annotation | Small potential follow-up; frozen is shallow, `[]` is overridable |
| 5 | Feed representative executions, not trusted RBS or CME pointers | No measured gain; profile/call-site quality lever | **No patch** for warmup; **fork/upstream** for profile import | Hints require runtime guards, process/ISEq identity validation |
| 6 | Enable JIT after delivery; tune thresholds/boot/fork warmup | No measured gain; mostly warmup, memory and tail latency | Existing controls: **no patch**; per-method eager compile would need one | Threshold 1 harms ZJIT profiling; warmup executes app effects |
| 7 | Watched mutable data / sealed config or builtin annotations | No defensible gain estimate from this census | Broad **VM/JIT** change for watches; **fork** to annotate app ISeqs | Not a small follow-up; unsafe as a Lowrail guard replacement |

### 1. Empty kwrest: smallest useful upstream patch

**How it works.** Base [can_direct_send][ZHIR] rejects every callee with
`params.flags.has_kwrest()`. The caller remains generic `Send`; that is a VM
dispatch fallback, **not necessarily a side exit or an interpreted callee**.
The callee can itself have compiled code. The rejection also prevents the
later general inliner from seeing `SendDirect`.

The fork accepts **no caller keywords, no named keyword parameters, and no
anonymous positional rest**. `plan_send_direct_keyword_arguments` appends a
fresh Hash for named `**kw`, nil for anonymous `**`, matching
[`vm_args.c::args_setup_kw_rest_parameter`][ARGS]. The argc gains one slot;
`plan_send_direct_rest_parameter` excludes that slot from its positional
section. Existing `KeywordHash` emission produces `NewHash`; no VM helper,
binding token, profile import, or public API is introduced. **The inliner
still rejects kwrest.**

```diagram
Before: compiled caller ──→ generic VM send ──→ kwrest callee
After:  compiled caller ━━▶ CME/type-guarded direct call ━━▶ same callee
                            fresh Hash (or anonymous nil)
```

**Runtime census, base master.** Counts are emitted runtime ZJIT counters
from a diagnostic-only patch (embedded in the evidence recipe below), divided
by 300 requests, not compile-time counts or TracePoint estimates:

| kwrest planner rejection | Blog / request | Fizzy / request |
|---|---:|---:|
| All | 77 | 349 |
| Caller has literal keyword slots | 31 | 262 |
| Caller passes no keywords | 46 | 87 |
| Named generated tag-helper group | 11 | 229 |
| Other method names | 66 | 120 |
| `form_with`, `token_tag`, `url_for`, `render`, `capture` | **0 each** | **0 each** |

The kwrest counter was the only planner rejection attached at these sites.
These numbers are **counter increments, not guaranteed unique physical
calls**: the optimizer may emit retained-send counters across fixed-point
iterations (also documented by upstream [PR #18267][PR18267]). The diagnostic
patch groups a declared list of method names, not every possible tag helper.
Runtime `**hash` is rejected earlier (`complex_arg_pass_caller_kw_splat`), so
the literal/no-keyword split is not a census of all Ruby keyword calls.

Do not label all of Rails' form/url/render calls “kwrest failures.” Blog's
TracePoint census sees `form_with` 1, `token_tag` 4, `tag` 24, `tag_options` 36,
`tag_option` 95 and `url_for` 6 times/request, but those are a different
population. For example `token_tag` has a named keyword, not kwrest; several
tag/url/render interfaces accept a positional options Hash. No counter at
this planner does not mean a call is optimized—it can fall back earlier.

**Why not support all 46/87 no-keyword cases immediately?** A wider prototype
failed Fizzy route initialization (`TypeError: wrong argument type Hash
(expected set)`). Named keyword defaults place a hidden keyword-bits local
before kwrest; [gen_function_stub / prepare_for_exit][ZCODE] spill/reshape
packed args without that extra gap. Simply appending a Hash overwrote that
slot. Another wider iteration added 4/13 objects/request: anonymous `*` uses
the VM's shared frozen empty Array ([vm_args.c, rest setup][ARGS]), whereas
`RestArray` packing allocates. These versions were rejected, not papered over.
The final narrow patch removes only **15/6** fallback increments/request.

**Literal-keyword follow-up size.** Kwrest-only callees with static keyword
slots are the next plausible bounded step: put key/value pairs not assigned
to named parameters into a fresh `KeywordHash`, adjust count validation, and
retain the current rest-slot accounting. Existing planner code already
synthesizes a positional Hash for a non-keyword callee. However, it currently
rejects extra/unknown keywords and assumes all keyword values map into named
slots (`plan_send_direct_keyword_arguments`, around lines 4305–4460).
Mixed named/default keywords require coordinated stub/exit/entry layout work
and tests; runtime `**hash`, `ruby2_keywords`, duplicate-key semantics and
forwarding are separate. **No literal-keyword prototype or gain claim**.

**App screen of final restricted patch.** Body and full-header digests match
for both seeds in base/base/patch, with real CSRF/cookie code under the
declared disposable entropy policy. Allocation and counter windows below
have 300 requests; code compilation is not quite flat (two ISeqs compile), so
this cannot become a Lowrail accepted JIT price.

| Metric | Blog base / patch | Fizzy base / patch |
|---|---:|---:|
| Objects/request | 2306.21 / 2306.24 | 3871.17 / 3871.16 |
| kwrest fallback increments/request | 77 / 62 | 349 / 343 |
| Direct-send fallback increments/request | 77 / 62 | 385 / 379 |
| Side exits / 300 requests | 10,801 / 10,801 | 14,401 / 14,401 |
| ZJIT instructions / 300 requests | 26,510,070 / same | 49,941,986 / same |
| Mean paired wall change, 95% interval | −0.29% [−3.06%, +1.36%] | +1.12% [−0.59%, +3.23%] |
| A/A wall change, 95% interval | +5.05% [−4.88%, +13.76%] | −0.16% [−0.57%, +0.49%] |

**Focused micro and interpreter control.** The micro returns/validates two
million successful `kwargs.empty?` results. It heats the **caller** with 100
separate invocations, not one long loop. Ten rotated paired rounds, identical
CPU, stats off; intervals resample rounds, not correlated loop iterations:

| Mode | Base mean | Patch mean | Paired change [95%] | A/A [95%] |
|---|---:|---:|---:|---:|
| ZJIT | 107.23 ms | 40.10 ms | −62.49% [−63.90%, −61.55%] | −0.14% [−4.51%, +3.27%] |
| Interpreter | 142.32 ms | 147.72 ms | +3.80% [+1.15%, +6.95%] | +1.54% [−0.52%, +3.85%] |

Both binaries/modes allocate **2,000,007 objects**. Separate HIR/stats workers
confirm the hot caller compiled, no compilation during measurement, and
2,000,000 kwrest fallback increments → zero. Earlier single-long-loop micro
results are retained but are **not** evidence about direct-send dispatch:
the caller had not crossed its invocation threshold.

The interpreter timing is not silently discarded. Executable changes touch
only `zjit/src/{hir.rs,hir/opt_tests.rs,codegen_tests.rs}`; no VM/headers change.
Unchanged `bench/callgrind.c`, built against the same master install, gives:

| Calls | Base Ir | Patch Ir | Seam-subtracted Ir/call, both |
|---:|---:|---:|---:|
| 0 | 2,732 | 2,732 | — |
| 5,000 | 3,988,012 | 3,988,012 | 797.056 |
| 10,000 | 8,052,482 | 8,052,482 | 804.975 |

This micro-only window disables GC after warmup, to isolate executed
interpreter work. Objects at 10,000 calls are 10,006 on both binaries.
Per-call Ir need not agree across different window sizes;
**base and patch agree exactly at each size**. There is no added interpreter
instruction cost. Binary-layout/noise is a plausible timing explanation, not
a verified cause; equal Ir does not prove universal equal wall time.

**Decision:** prepare the small upstream-style draft under the owner's
micro-gain + equal-interpreter-Ir criterion. No whole-app gain/no-regression
claim beyond the observed exactness, allocations and instruction controls.
`make zjit-test ZJIT_TEST_FEATURES=disasm ZJIT_TESTS='-j 4'`: **1,886 passed,
15 skipped**. Tests cover fresh Hash mutation, anonymous forwarding,
asymmetric positional optional/rest/post args, a compile-failure stub exit,
and the HIR direct-call path. AArch64, hosted CI, full ruby-spec and full Rails
test suites were not run. The broader failed iterations and contaminated
early wall runs remain in the evidence; none are accepted measurements.

### 2. CME invalidation: useful only for dependencies the JIT sees

A callable method entry (CME) is CRuby's resolved method implementation.
[`vm_method.c::vm_cme_invalidate`][METHOD] calls both JITs when effective
lookup changes. YJIT [invariants.rs][YINV] maps CME → compiled blocks;
`rb_yjit_cme_invalidate` invalidates those blocks. ZJIT [invariants.rs][ZINV]
maps CME → patch points; it overwrites a patch point with a side-exit jump
and invalidates the compiled version. [HIR type specialization][ZHIR]
emits `MethodRedefined` plus a receiver-type guard before `SendDirect`.
Inlining retains that dependency and recoverable frame states.

Therefore a real `receiver.helper(arg)` can lose Ruby dispatch/frame work
without a Lowrail method-token guard. A literal pasted copy of `helper` has
**no send, therefore no CME dependency on helper**. Replacing a caller once
does not attach dependencies on every original callee erased by Lowrail.
Attaching arbitrary erased dependencies would itself require a new compiler
interface/fork patch and exact deoptimization boundaries—not just an entry
epoch guard. A plain method is desirable, not magic certification.

**BOPs/constants/shapes are distinct assumptions:**

| Assumption | Source / mechanism | What it does NOT certify |
|---|---|---|
| Basic operators (BOP) | [vm.c][VM], `rb_vm_check_redefinition_opt_method`; JIT BOP tables and patch points | That a Hash's entries stayed unchanged after `Hash#[]` remained stock |
| Constant binding/path | [vm_method.c][METHOD] constant-cache invalidation; YJIT stable-name blocks, ZJIT `constant_state_patch_points` | Mutation of the bound object's contents, defaults or nested objects |
| Ivar offset/shape | [YJIT getivar][YCODE], [ZJIT guard_shape / GetIvar][ZHIR] | The value in an existing ivar: same-shape assignment need not change shape |
| No singleton class | [class.c::make_singleton_class][CLASS] notifies both JITs | A safe reason to create singleton classes in a Lowrail guard |

No existing public subscription registers “these arbitrary app facts protect
this lowered ISeq.” Do not replace an unsupported exactness proof with JIT
enablement: interpreter fallback must remain correct too.

### 3. Stable, JIT-friendly output; do not manufacture singleton receivers

Prefer one stable installation before representative warmup; ordinary sends,
natural fixed keyword call sites, normal ivar access and shallow stable helper
boundaries. Keep original visibility, arity, live effects and fallbacks. Do
not rewrite kwargs or `define_method` to `def` unless closure capture,
reflection, block and exception semantics genuinely match.

Replacing warmed methods invalidates dependent callers; a new ISeq starts
with new profiles, and generated copies can distribute hotness or make
shared sites polymorphic. Monomorphic observations are not permanent proofs.
YJIT's [code memory paths][YCORE] use code GC only when configured; repeated
invalidation consumes code/memory until reclaimed rather than guaranteeing
instant reuse. ZJIT tracks versions/recompilation and GC references
([state][ZSTATE], [GC][ZGC]); its default max versions is four.

YJIT [gen_send_general][YCODE] deliberately falls back for ordinary singleton
receivers to avoid retaining objects. Its broad no-singleton invalidation
optimization is currently limited to Array/Hash/String ([YINV]), whereas
ZJIT's [NoSingletonClass patch points][ZINV] apply at profiled class assumptions
and remember invalidation to avoid loops. These are different effects:
per-object singleton receivers can hurt even without a broad invalidation.

Prior K already measured the guard-induced singleton regression; no rerun.
Current unmodified master YJIT baselines execute real JIT code, have zero
invalidation/code-GC increments in the stats window, and report 94/112
singleton-send fallbacks/request (different fixtures/runtime from K).
Creating `object.singleton_class` merely to inspect lookup is not passive.
Prefer the existing non-creating exact-holder primitive where valid; if no
exact non-creating guard exists, retain/refuse rather than weaken it.

### 4. Folded data is not covered by method invalidation

`TAG_TYPES` is already frozen in Rails 8.1.4; `PRE_CONTENT_STRINGS` is a mutable
Hash with a default proc. A plausible upstream optimization is constant
lookup in an **exact, identity-known frozen Hash** with literal immutable key,
known stock `[]` (CME/BOP protection), safe default behavior and GC rooting.
Freezing the Hash is shallow: returning a live mutable value by identity is
different from folding its nested state or embedding rendered output.
Missing keys/default procs and customized `hash`/`eql?` must not be evaluated
early or suppressed. Do not freeze an app's mutable config on its behalf.

The pinned JITs do not offer a general watched-object-content assumption.
ZJIT recently [reverted frozen-object LoadField folding, PR #19129][PR19129],
which is a warning against treating “frozen” as a ready-made general solution.
A watched mutable Hash/config object would need dependency tracking across
every relevant Ruby/C write, replace/clear/default/default_proc mutation,
GC/compaction, aliasing, Ractor boundaries, and deoptimization after effects.
That is VM infrastructure, not a small method-lookup API or this kwrest patch.
A genuinely sealed/deeply immutable app data graph could simplify it, but is
a different opt-in semantic contract, not current JIT functionality.

### 5. ZJIT's actual pipeline and Rails limitations

[`profile.rs`][PROFILE] rewrites selected interpreter instructions to collect
receiver/argument types, block handlers, ivar receiver shapes and splat
lengths. [`distribution.rs`][DIST] summarizes mono/poly/mega and skewed
profiles. HIR construction builds a whole-method CFG with frame states;
type inference, `type_specialize`, inlining and cleanup run to a bounded
fixed point, then lower to LIR/register allocation/machine code.

Profile-derived types are **speculation**: guarded, side-exitable and
recompilable, not trusted annotations. Default [options][ZOPT]: call threshold
30, five profiling calls, callee inline threshold 30 YARV words, cumulative
caller inline budget 200 HIR instructions, depth/fixed-point bound 10.
Those are different size units; increasing the threshold is not free.

| Rails pattern | Pinned-master handling / useful next question |
|---|---|
| Ordinary `send` bytecode | Profile receiver → CME lookup → guarded `SendDirect`; polymorphic/skewed paths may specialize, otherwise dynamic send |
| Ruby `.send`/`public_send` | Distinct dynamic method-name/access semantics; static-name and permission restrictions apply; not synonymous with an ordinary send bytecode |
| `define_method` / bmethod | ISeq-backed Proc can direct-call when supported; non-ISeq Proc/symbol bmethods, block/arg constraints and single-Ractor/EP assumptions matter; not “all bmethods unsupported” |
| `instance_exec` | No dedicated `instance_exec` optimization found in either JIT's Rust source; generic C/block/environment work remains, not a purity certificate |
| Named keywords | Planner reorders slots, fills defaults and keyword bits, snapshots recoverable arguments; kwrest/dynamic splats are separate blockers |
| Blocks/`yield` | Literal/Proc block handlers have supported direct paths; kw/splat block invocation, complex block params, arg0 autosplat and nonlocal control flow constrain specialization |
| Tiny helpers | ZJIT general inliner acts on `SendDirect`; `can_inline` rejects kwrest/forwardable/escaping environments. YJIT has simple ISeq-return, builtin and special-block inlining, not the same general HIR inliner |

The current census identifies kwrest, not a measured `instance_exec` fix or a
reason to globally raise inline budgets. Form construction/AR relation chains
allocate and perform dynamic effects; faster dispatch alone does not erase
that work. Lowrail's useful upstream feed is minimal real Rails reproductions
with profiles, fallback identities, argument shapes and exactness checks.

### 6. What can be fed or scheduled today?

| Information/control | Exists today? | Lowrail use / risk |
|---|---|---|
| Real representative calls | Yes, both JITs | Warm normal requests after delivery; no extra API. Do not execute writes/I/O merely to heat methods without app approval |
| YJIT runtime enable | [`RubyVM::YJIT.enable`][YRB] accepts stats/log/memory/call threshold | Delay enablement until after boot replacement to avoid compiling throwaway code; can trade startup against first-request latency |
| ZJIT runtime enable | [`RubyVM::ZJIT.enable`][ZRB], no kwargs | CLI call/profile/inline knobs are not this Ruby method's keywords; only one JIT enabled at once |
| Compile budget | ZJIT `max_compile_time_ns` / `total_compile_time_ns` | Existing warmup CPU budgeting, not per-method eager compilation |
| Compile-only/log/dump options | [ZJIT options][ZOPT] | Selection/diagnostics, not a profile import or force-compile API |
| Boot RBS, inferred types, resolved CMEs, cached shapes | No public profile-seeding API found | A fork could seed per-ISeq profiles **as hints**, with source/bytecode identity, GC ownership and normal guards. Never trust raw persisted pointers or stale shapes |
| Per-method eager compile / compile-on-fork | No public facility found in these sources | Warm executions can share some pre-fork code; threshold knobs are not compile-on-fork. Boot distribution may not represent worker traffic |
| `--zjit-call-threshold=1` | Yes | Explicitly skips profile rewriting; not a shortcut to good specialization |
| [`Process.warmup`][WARM] | Yes | Major GC, compaction, promotion and related heap preparation; **not** “compile every hot method” |
| `Primitive.attr! :leaf / :always_inline` | Internal builtin loader/compiler only | [`compile.c`][COMPILE], [`mk_builtin_loader.rb`][BUILTIN]. `:always_inline` bypasses size heuristics, not correctness checks; `:leaf` permits special frame/block treatment. App annotation needs a fork and unsafe promises, not a supported Ruby DSL |

## Erased calls versus folded data: measured decomposition and limits

Historical **blog** [b059fc9](https://github.com/thomasklemm/lowrail/commit/b059fc9)
is −15.02% interpreter Ir and about −377 objects. Historical **Fizzy**
[addf55e](https://github.com/thomasklemm/lowrail/commit/addf55e) DirectSite is
−572 objects. Do not combine those apps, windows, heaps or runtime versions.

Ruby 4.0.7 YJIT ablation uses real admitted units, ten separately traced
requests and 300 **untraced** allocation requests per arm. Scoped call totals
include Ruby/C events whose owner names start ActionView/ActionController/
ActiveRecord/ActiveModel/ARRequestSites; they are **not all program calls**.
Data-table counts are separate so they are not double-counted as calls:

| Blog arm | Objects/request | Net scoped calls erased/request | TAG_TYPES reads | PRE_CONTENT_STRINGS reads |
|---|---:|---:|---:|---:|
| Off | 2432.38 | — (3502 total) | 115 | 15 |
| Form only | 2054.66 | 357 | 92 | 14 |
| Token only | 2432.19 | 32 | 103 | 15 |
| Collection only | 2432.22 | 1 | 115 | 15 |
| Stack | 2054.38 | 390 | 80 | 14 |

**The form unit accounts for essentially the observed allocation saving**;
token erases calls but has no resolved allocation saving here. It is not
valid to assign −15.02% Ir to “call dispatch” from those counts: form lowering
also suppresses builders, strings/Hashes and conditionals under configuration,
translation, route and schema facts. `FormScaffoldAdmission.check` reads
mutable class attributes, I18n trees, URL-default Hashes and caches as well as
method bodies; it is not purely body inlining. The three rendered
`@table[...]` values in `FormScaffold.render` remain live. The one net mutable
table read removed does **not** account for all folded mutable facts.

Fizzy's current census fixture with the external DirectSite overlay from
[936cc46](https://github.com/thomasklemm/lowrail/commit/936cc462ffa2586a45458f6efa69d9717f965fe8)
(includes later fork rebinding) has:

- Both-seed exact responses; one DirectSite hit/request (310 total includes
  300 warmups + 10 traced requests).
- Objects 4128.19 → 3835.15 (**−293.04**, not historical −572).
- Scoped calls 7728 → 6437 (**1291 net erased/request**).
- It stages query construction, SQL/Arel and a bind map, then checks mutable
  scope/reflection/connection facts and executes a normal association result.
  This is **precomputed work**, not just Ruby callee text pasted inline.

Consequently neither app supplies a pure “erased sends” versus “mutable data
folds” cost split. No independent Ir allocation between those buckets was
measured, and no percentage of the historical −15.02%/−572 is asserted.
Original calls remain visible in the master JIT screens; removing 15/6
dispatch fallbacks does not recover the form/DirectSite allocation savings.
The strongest defensible answer to Aaron is narrower: **a real dispatch
coverage gap can be fixed inside ZJIT, using its own CME invalidation, without
an application method-token API**. Recovering Lowrail's larger staged-work
gain still needs a separate guarded-data/optimization argument.

## Historical A/K activation audit — read-only, no reruns

**YES / YES.** Bundler autoswitch can re-exec without the original CLI JIT
flags; the current harness pins `BUNDLER_VERSION=4.0.20` before setup and
asserts actual worker enablement after Rails boot. That discovery does not
invalidate cohorts whose worker receipts already prove JIT activation:

- A [51801ed](https://github.com/thomasklemm/lowrail/commit/51801edc3aab276da3538763257d7d12921aa37f),
  `docs/native-bench.json:rps_confirmatory_blog.rows[0..59].boot.jit`: **60/60
  `yjit: true` and nonzero compiled-ISeq counters** (first: 1070). All three
  validation worker receipts also say enabled with compiled code.
- K [b62a098](https://github.com/thomasklemm/lowrail/commit/b62a098bf6d5648ec2aa6dc7b3e31fb89f39a0e4),
  `docs/yjit-aware.json:studies.{blog-final,fizzy-final,candidate-screen}.workers`:
  **45/45 Ruby descriptions include `+YJIT`**. All nine stats workers have
  nonzero `jit_delta.yjit_insns_count`; Fizzy's off/on singleton counts are
  121,500/234,500 over 500 requests, reproducing 243/469 from the receipts.

This answers “was it active?”, not every other validity question about an
accepted cohort. No historical work was rerun or repriced.

## Recent merged upstream evidence bar (sample, not a formal policy)

Read PR bodies, changed files, reviews and comments from the last two months,
as of this investigation. Small compiler-coverage work can land without a
resolved whole-app speedup; tests/recoverability matter at least as much as a
headline number. Do not infer that passing this local screen guarantees merge.

| Merged PR | Observed evidence |
|---|---|
| [#18682: Fold Class#superclass][PR18682], Sep 22 | HIR tests/helper/bindings; body says YJIT has the fast path; no timing table |
| [#18180: Proc block arg → SendDirect][PR18180], Sep 23 | Executable + HIR tests, fallback counts; some fallback merely moves to another reason; restricted cases are explicit |
| [#18606: direct sends to forwardable callees][PR18606], Sep 12 | Executable + HIR tests, lobsters about 1.8%, counters; review explicitly questions eager VM-frame writes and future inlining design |
| [#19428: polymorphic splatkw][PR19428], Oct 21 | HIR tests and about 28k fewer lobsters side exits; no wall table in body |
| [#18981: String#to_sym][PR18981], Sep 23 | Four micros plus protoboeuf, modest gains, tests for alias as well |

The empty-kwrest draft fits that scope/evidence style with a focused resolved
micro and equal interpreter Ir. The frame-layout failures found here are
exactly why it remains narrow. Owner approval is required before posting.

## Reproduction notes

Prepare corpus fixtures with `script/corpus real-blog` / `script/corpus fizzy`
and the named Fizzy setup, preserve the retained blog prerequisite, and use
closed disposable four-database snapshots. Do not repin historical fixtures
to make a check pass. The evidence contains the exact app/lock/runtime entropy
pins and the external master Gemfile/lock overlays.

Build control at the pinned master, save its executable, apply the Ruby fork
patch, rebuild/save the patch executable against the same installed stdlib.
For example, after setting actual paths in a configuration with `base`,
`patched`, `harness` (the native-bench worktree above) and `cpu`:

```sh
mise exec ruby@4.0.7 -- ruby bench/experiments/jit_hooks.rb micro CONFIG.json micro-result.json
mise exec ruby@4.0.7 -- ruby bench/experiments/jit_hooks.rb run APP_CONFIG.json NEW_OUTPUT
```

The JSON cohort configs include the worker flags, DB snapshot paths, warmup,
samples, phases and arm overlays. Translate orb-specific paths; never use
these disposable deterministic secrets/entropy controls in production. Run
CPU-pinned benchmarks sequentially, not alongside builds/censuses. Master
YJIT exact/stats-only baselines are retained separately; no patched-YJIT wall
claim is made for a change that only affects ZJIT.

For the named fallback census, apply only the diagnostic patch recorded in
`census_patch` in the evidence to a separate control build. It adds runtime
counter instructions, so **never price it against an uninstrumented build**.
For interpreter Ir, `interpreter_ir_code` records the complete worker;
compile unchanged `bench/callgrind.c` for that Ruby, adjust its require path,
run `valgrind --tool=callgrind --instr-atstart=no` for N=0/5000/10000 on both
binaries, compare the first client-request dump and subtract the N=0 seam.

[ZHIR]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/hir.rs
[YINV]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/yjit/src/invariants.rs
[ZINV]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/invariants.rs
[METHOD]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/vm_method.c#L314-L346
[VM]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/vm.c#L2481-L2497
[CLASS]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/class.c#L1388-L1412
[YCODE]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/yjit/src/codegen.rs
[ZCODE]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/codegen.rs#L3930-L4132
[ARGS]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/vm_args.c
[YCORE]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/yjit/src/core.rs#L3280-L3294
[ZGC]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/gc.rs
[ZSTATE]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/state.rs
[PROFILE]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/profile.rs
[DIST]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/distribution.rs
[ZOPT]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit/src/options.rs
[YRB]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/yjit.rb#L59-L91
[ZRB]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/zjit.rb
[WARM]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/process.c#L8672-L8710
[COMPILE]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/compile.c#L9420-L9455
[BUILTIN]: https://github.com/ruby/ruby/blob/5f2bc22560e9063fb8dec736afbf378251cad3ec/tool/mk_builtin_loader.rb#L1-L12
[PR18267]: https://github.com/ruby/ruby/pull/18267
[PR19129]: https://github.com/ruby/ruby/pull/19129
[PR18682]: https://github.com/ruby/ruby/pull/18682
[PR18180]: https://github.com/ruby/ruby/pull/18180
[PR18606]: https://github.com/ruby/ruby/pull/18606
[PR19428]: https://github.com/ruby/ruby/pull/19428
[PR18981]: https://github.com/ruby/ruby/pull/18981
