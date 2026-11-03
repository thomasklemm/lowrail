# Where ZJIT spends more instructions than YJIT on Rails

Which work makes ZJIT slower than YJIT on Rails, and how big is each part? The [ZJIT lead
queue](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03) ranks leads by fallback counts. Fallback counts don't
say how many instructions each one costs, or whether YJIT does the same generic work at that site. This page
measures the instruction gap directly, splits it into buckets, and ties the biggest buckets to Rails call sites.
Nothing was built or posted.

## Result

On one Ruby master build, ZJIT runs **+3.9% (railsbench), +5.8% (lobsters) and +18.3% (shipit)** more instructions
per iteration than YJIT. Without GC the gaps are +3.4%, +5.6% and +17.2%, and every run is within 0.27% of the other
runs in its mode. Per benchmark the gap is +184 M, +179 M and +619 M Ir per iteration.

* **About half the gap in all three benchmarks is the generic send path** that ZJIT reaches after a fallback:
  `rb_vm_send` / `rb_vm_opt_send_without_block` / `rb_vm_invokeblock` → VM frame setup → `rb_vm_exec` → ZJIT's
  entry trampoline. With the block bucket and the trampoline, this is 89%, 69% and 60% of the gap. Each extra
  generic call costs **272 / 285 / 350 Ir** more than YJIT's handling of the same site.
* **Generic ivar reads** add 9%, 22% and 17%: `rb_ivar_get` walks the shape tree at about 120 Ir per call.
  YJIT inlines these reads with shape guards, or calls `rb_ivar_get_at_no_ractor_check` with a known index.
* **JIT code** adds 31%, 26% and 14%. A cfunc call with a frame costs ZJIT about **40 Ir per call against YJIT's
  30**, a difference of 23 / 10 / 14 M Ir. (This page first said 18 for YJIT; that count missed YJIT's call tail.
  See [Lead 12](#lead-12-what-a-cfunc-call-with-a-frame-costs).)
* **GC** adds 15%, 5% and 12%. Most of it is `rb_zjit_root_mark`, which marks the ISEQ of every JITFrame on every
  GC, minor ones too: 38k, 150k and 119k JITFrames.
* **ZJIT does better than YJIT** on allocation (−42 / −17 / −27 M), the interpreter (−30 / −20 / −1 M: ZJIT
  compiles more ISEQs) and write barriers (−13 / −4 / −5 M).
* Side exits and frame materialization are 8%, 3% and 2%. Compile and invalidation inside the window are ≤ 0.3% of
  Ir either way.

Ranked by size, the leads are (M Ir per iteration, railsbench / lobsters / shipit, and share of each gap):

| # | lead | M Ir | share of gap | status |
|---|---|---|---|---|
| 11 | attr_reader/getivar on shape-polymorphic receivers without a shape profile (`getivar_fallback_no_profile_missing_ic`) | 12.4 / 30.8 / 83.9 | 7% / 17% / 14% | taken (tekknolagi: ruby/ruby#19443 open, ruby/ruby#18616 draft; see [Lead 11](#lead-11-why-there-is-no-profile)) |
| 3 | class-polymorphic sends to one method entry (`send_polymorphic_fallback`) | 7.2 / 42.1 / 180.1 | 4% / 24% / 29% | **free** (Shopify/ruby#1099 pattern 2; slot granted) |
| 1 | polymorphic or unspecialized yields in `Array#each`/`#map` | 70.4 / 27.2 / 60.9 | 38% / 15% / 10% | taken (k0kubun, Shopify/ruby#1093) |
| 12 | cfunc calls with a frame: 40 Ir of JIT code against YJIT's 30 | 22.7 / 10.3 / 14.4 | 12% / 6% / 2% | **free** in part: dead stores and the register switch, 11.2 / 5.1 / 8.7 M ([Lead 12](#lead-12-what-a-cfunc-call-with-a-frame-costs)) |
| 7 | `&block` forwarding (`send_block_arg_not_nil`) | 29.4 / 25.1 / 66.0 | 16% / 14% / 11% | **free** (Shopify/ruby#1014; slot granted) |
| 13 | `rb_zjit_root_mark` marks every JITFrame's ISEQ on every GC | 25.4 / 6.7 / 37.1 | 14% / 4% / 6% | **free** |
| 14 | `&block` passed to a C method (`Rack::Request#fetch_header`) and other `complex_arg_pass` | 19.5 / 6.1 / 13.1 | 11% / 3% / 2% | **free** (Shopify/ruby#1039 row 42, unassigned) |
| 4 | protected calls | 14.9 / 4.4 / 10.6 | 8% / 2% / 2% | taken (ours, ruby/ruby#19483) |
| 5 | `Kernel#send` | 11.3 / 4.7 / 14.3 | 6% / 3% / 2% | taken (tekknolagi, ruby/ruby#19583) |
| 15 | getivar on final versions and long-lived singleton objects (`getivar_fallback_no_side_exits`) | 3.9 / 7.8 / 24.0 | 2% / 4% / 4% | **free** (Shopify/ruby#1099 pattern 3) |
| 17 | `throw` from blocks and exception handlers unwind by longjmp and materialize frames | 15.6+ / 5.3+ / 13.2+ | 8% / 3% / 2% | taken (Shopify/ruby#1093, ruby/ruby#18759, ruby/ruby#18244) |
| 16 | PatchPoint nop padding executed inline | 31.7 / 14.0 / 27.9 | Ir only, not cycles | free, low priority |

Lead 3 is the largest free lead on lobsters and shipit, and lead 13 is the largest free lead on railsbench. Lead 12 shrank
to about half its first estimate ([Lead 12](#lead-12-what-a-cfunc-call-with-a-frame-costs)).
Lead 11 turned out to be taken ([Lead 11](#lead-11-why-there-is-no-profile)). The full list with sites is in
[Leads](#leads). No crash, wrong result or divergence turned up. The only failed run was a lobsters 500 caused by two processes sharing one `tmp/cache`, not by a JIT. After that,
every run used its own copy of ruby-bench.

## Pins and method

* **Ruby:** master [`a8b095a07e`](https://github.com/ruby/ruby/commit/a8b095a07e55adf429839d4642027e832e30d3a7)
  (2026-11-03 16:41 UTC), release build (`-O3 -ggdb3`), `--enable-zjit --enable-yjit`. ZJIT and YJIT ran on this
  one build.
* **ruby-bench** [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2fc1a84702fea63e06f64d179751d69df4):
  railsbench and lobsters on Rails 8.1.1, shipit on Rails 8.1.2.
* **Flags:** ZJIT `--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024`; YJIT `--yjit` with defaults (YJIT
  `exec_mem_full_count` was 0).
* **Out of memory:** `compile_error_out_of_memory` was **0 in every ZJIT stats run**, read for the whole process
  before `reset_stats!` and again at the end. Code region: 12.3 MB, 42 MB and 33 MB. The Callgrind runs used the
  same flags without `--zjit-stats`, so they emit less code than the stats runs. `failed_iseq_count` was 0.
* **Callgrind:** Valgrind 3.19, `--smc-check=all-non-file --dump-instr=yes`, harness
  [`zjit_yjit_gap_harness.rb`](../../bench/upstream/zjit_yjit_gap_harness.rb) (`GAP_MODE=callgrind`): 15 warmup
  iterations, an empty window, then a 3-iteration window in the same process. Ir per iteration is the window
  minus the empty window, divided by 3. **GC is included** and shown as its own bucket.
* **Three runs per mode** with different perf maps, which also serve as the A/A:
  * run a: `--zjit-perf=iseq` / `--yjit-perf=iseq`, JIT code by ISEQ;
  * run b: `--zjit-perf=hir` / `--yjit-perf=codegen`, ZJIT code by HIR instruction and YJIT code by codegen function;
  * run c: no perf map.

  A perf map only writes a file at compile time. Run c agrees with runs a and b within the A/A.
* **Attribution:** [`zjit_yjit_gap_cg.rb`](../../bench/upstream/zjit_yjit_gap_cg.rb) reads each dump and reports:
  * self Ir per C/Rust function;
  * self Ir of anonymous JIT code by perf-map symbol;
  * calls and inclusive Ir per call edge, where a caller in JIT code is named by its perf-map symbol.

  [`zjit_yjit_gap_report.rb`](../../bench/upstream/zjit_yjit_gap_report.rb) sorts functions into buckets by name
  ([`zjit_yjit_gap_buckets.rb`](../../bench/upstream/zjit_yjit_gap_buckets.rb)). It averages the three runs and
  prints bucket, function, ISEQ, HIR and call-edge tables. These are **self** costs, so each instruction counts
  once.
* **Per-site reasons:** [`zjit_yjit_gap_sites.rb`](../../bench/upstream/zjit_yjit_gap_sites.rb) joins two sources
  by `label@path`:
  * ZJIT's per-ISEQ fallback counters (`--zjit-stats-iseq`, thomasklemm/ruby `thomasklemm/zjit-stats-iseq`
    cherry-picked onto `a8b095a07e` without conflicts; see [zjit-iseq-leads](zjit-iseq-leads.md));
  * YJIT's generic calls from the same ISEQ's code in Callgrind run a. YJIT doesn't inline ISEQs.

  "Extra" means ZJIT fallbacks with no YJIT generic call of the same kind at that ISEQ, floored at 0. Megamorphic
  `Logger#level` on railsbench, for example, has none. The estimated Ir is extra × a per-call price taken from the
  bucket deltas: send and yield use Δ(dispatch + block + trampoline) / extra calls, and ivar uses Δ(ivar) / extra
  reads. **This price treats every extra call alike**, so read the per-reason Ir as an estimate. A `&block` call
  that builds a Proc costs more than a polymorphic `attr_reader` miss.
* **Interpreter time per ISEQ:** a measurement-only patch,
  [`zjit_yjit_gap_interp_iseq.patch`](../../bench/upstream/zjit_yjit_gap_interp_iseq.patch), counts the YARV
  instructions that `vm_exec_core` runs per ISEQ. It splits them by whether the ISEQ already had a `jit_entry`.
  It ran in a separate build with the stats-iseq commit, 15 warmup and 10 counted iterations, never under
  Callgrind.
* **Counters:** `--zjit-stats-quiet` / `--yjit-stats=quiet` on the plain build, 15 warmup and 10 measured
  iterations (`GAP_MODE=stats`).
* Runner: [`zjit_yjit_gap_run.sh`](../../bench/upstream/zjit_yjit_gap_run.sh). Receipts:
  [`data/zjit-yjit-gap/receipts.tar.gz`](data/zjit-yjit-gap/receipts.tar.gz). It contains every dump summary JSON,
  the stats and per-ISEQ JSONs, the full report and site tables per benchmark, and the combined table.

## Totals

Callgrind, M Ir per iteration, GC included:

| benchmark | ZJIT runs a / b / c | YJIT runs a / b / c | ZJIT − YJIT (means) | ZJIT − YJIT, GC excluded |
|---|---|---|---:|---:|
| railsbench | 4,943.3 / 4,940.5 / 4,945.6 (0.10%) | 4,762.2 / 4,753.2 / 4,762.3 (0.19%) | **+183.9 (+3.87%)** | +156.9 (+3.40%) |
| lobsters | 3,274.2 / 3,277.8 / 3,303.1 (0.88%) | 3,101.5 / 3,103.1 / 3,113.0 (0.37%) | **+179.1 (+5.77%)** | +170.3 (+5.58%) |
| shipit | 3,971.8 / 4,049.9 / 3,971.7 (1.96%) | 3,383.5 / 3,371.8 / 3,381.9 (0.35%) | **+618.7 (+18.31%)** | +542.1 (+17.17%) |

The larger spreads come from GC. Lobsters ZJIT run c had one more minor GC in its window, and shipit ZJIT run b had
one more major GC. Without GC, every mode's runs are within 0.27% of each other. The totals agree with Z1 on
`90dbced795` (+3.5% / +5.5% / +18%, [zjit-gap-census](zjit-gap-census.md)).

Counters per iteration:

| | railsbench | lobsters | shipit |
|---|---:|---:|---:|
| ZJIT dynamic sends / YJIT `num_send_dynamic` | 1,065,952 / 593,078 | 750,526 / 396,619 | 1,709,365 / 779,192 |
| generic send-family calls from JIT code, ZJIT / YJIT (Callgrind) | 724,951 / 515,107 | 585,485 / 318,944 | 1,306,600 / 553,565 |
| generic yields from JIT code (`rb_vm_invokeblock`, `rb_vm_yield_with_cfunc`), ZJIT / YJIT | 367,325 / 91,133 | 204,484 / 76,093 | 538,354 / 228,321 |
| side exits ZJIT / YJIT | 23,709 / 12,970 | 12,651 / 3,614 | 49,581 / 7,144 |
| interpreted YARV instructions ZJIT / YJIT | 975k / 1,688k | 423k / 821k | 892k / 375k |
| … of which in ISEQs without JIT code ZJIT / YJIT | 33k / 946k | 15k / 240k | 9k / 241k |
| objects allocated ZJIT / YJIT | 1,734,099 / 1,737,496 | 647,228 / 649,939 | 1,137,822 / 1,150,142 |
| GCs in the window ZJIT / YJIT (minor + major) | 10.7 / 10.7 | 0.7 / 0.7 | 4.0 / 3.3 |

## Buckets

ZJIT − YJIT self Ir by bucket, M per iteration (mean of three runs per mode), with the share of each benchmark's
gap. "ZJIT entry trampoline" is the JIT code that `jit_exec` enters from C (`rb_vm_exec`). It is split out of the
JIT-code row because almost every entry comes from a fallback: a generic send to an ISEQ with JIT code re-enters
through `rb_vm_exec` and the trampoline.

| bucket | railsbench | lobsters | shipit |
|---|---:|---:|---:|
| method dispatch (generic send path) | +87.4 (48%) | +88.4 (49%) | +294.5 (48%) |
| JIT code (without the entry trampoline) | +57.6 (31%) | +47.1 (26%) | +88.8 (14%) |
| ivar and attr access (generic) | +16.3 (9%) | +39.0 (22%) | +108.1 (17%) |
| GC (marking, sweeping, freeing) | +27.0 (15%) | +8.8 (5%) | +76.7 (12%) |
| block and proc invocation (generic) | +46.4 (25%) | +18.7 (10%) | +38.3 (6%) |
| ZJIT entry trampoline (C → JIT entry) | +29.3 (16%) | +17.3 (10%) | +40.1 (6%) |
| side exits and frame materialization | +14.7 (8%) | +4.9 (3%) | +13.1 (2%) |
| invalidation | +0.0 | +0.1 | +0.0 |
| compile and profiling (Rust compiler, `rb_zjit_profile_insn`, YJIT stubs) | −1.9 (−1%) | −9.4 (−5%) | +2.5 (0%) |
| other runtime (cfunc bodies, Hash, String, regexp) | −7.8 (−4%) | +5.7 (3%) | −10.3 (−2%) |
| write barriers | −13.0 (−7%) | −3.7 (−2%) | −4.8 (−1%) |
| interpreter (YARV loop and instruction helpers) | −29.8 (−16%) | −20.4 (−11%) | −1.0 (0%) |
| allocation (object and malloc) | −42.2 (−23%) | −17.3 (−10%) | −27.2 (−4%) |
| **ZJIT − YJIT** | **+183.9** | **+179.1** | **+618.7** |

Largest function differences (full lists in the receipts):

* railsbench:
  * `rb_vm_exec` +42.3 M, mostly `EC_PUSH_TAG`/setjmp in `vm_exec`, once per C → Ruby entry: 1.58 M entries
    against 1.18 M. The extra entries come from `rb_vm_invokeblock` (+276k) and `rb_vm_send` (+108k).
  * `vm_invoke_iseq_block` +26.7 M, `rb_vm_invokeblock` +19.7 M, `zjit_materialize_frames` +15.6 M,
    `rb_vm_send` +13.7 M.
  * `gc_mark` +13.4 M and `rb_gc_mark_movable` +10.6 M (JITFrame marking).
  * `CALLER_SETUP_ARG` +12.8 M, `rb_ivar_lookup` +11.7 M, `rb_shape_get_iv_index` +11.0 M.
* shipit: `rb_vm_exec` +83.3 M, `rb_vm_opt_send_without_block` +42.6 M, `rb_ivar_lookup` +40.6 M,
  `rb_shape_get_iv_index` +35.8 M, `setup_parameters_complex` +31.5 M, `vm_invoke_iseq_block` +31.0 M.
* ZJIT runs fewer instructions in `rb_class_allocate_instance`, `rb_ec_newobj_of`, `rb_gc_writebarrier`,
  `vm_exec_core` and `yjit_compile`. YJIT's `jit_exec` threshold check alone is 14.4 M on railsbench.

## 1. The generic send path after fallbacks (60–89% of the gap)

When ZJIT can't specialize a send or yield, it calls the interpreter's generic entry point from JIT code. That
path runs:

1. method lookup and the call cache (`vm_search_method_slowpath0`, `vm_lookup_cc`);
2. argument setup (`CALLER_SETUP_ARG`, `setup_parameters_complex`, `vm_callee_setup_arg`);
3. a VM frame push (`vm_push_frame`) and stack check (`rb_ec_stack_check`);
4. `rb_vm_exec` with a setjmp;
5. `jit_exec` → ZJIT's entry trampoline → the callee's JIT code.

YJIT also falls back at some of these sites. The cost is the **difference** in generic calls at the same ISEQ.

**Price per extra generic call:** **272 Ir** (railsbench), **285 Ir** (lobsters) and **350 Ir** (shipit). Each is
Δ(dispatch + block + trampoline) divided by the extra send and yield calls: 600k, 436k and 1,067k per iteration.
For ivar reads the price is 57, 102 and 119 Ir per extra read.

Extra generic operations by ZJIT fallback reason, compared with YJIT at the same ISEQ (per iteration;
estimated M Ir in brackets):

| reason | railsbench | lobsters | shipit | lead / owner |
|---|---:|---:|---:|---|
| `getivar_fallback_no_profile_missing_ic` | 218k (12.4) | 303k (30.8) | 706k (83.9) | 11, taken |
| `send_fallback_send_polymorphic_fallback` | 26.5k (7.2) | 148k (42.1) | 515k (180.1) | 3, free |
| `send_fallback_invokeblock_polymorphic_miss` | 154k (41.8) | 42k (11.9) | 161k (56.2) | 1, taken (Shopify/ruby#1093) |
| `send_fallback_invokeblock_not_specialized` | 105k (28.6) | 54k (15.3) | 13.5k (4.7) | 1, taken (Shopify/ruby#1093; ours ruby/ruby#19659) |
| `send_fallback_send_block_arg_not_nil` | 108k (29.4) | 88k (25.1) | 189k (66.0) | 7, free |
| `getivar_fallback_no_side_exits` | 68k (3.9) | 77k (7.8) | 202k (24.0) | 15, free (Shopify/ruby#1099 pattern 3) |
| `send_fallback_one_or_more_complex_arg_pass` | 72k (19.5) | 21k (6.1) | 37k (13.1) | 14, free |
| `send_fallback_send_not_optimized_need_permission` | 55k (14.9) | 16k (4.4) | 30k (10.6) | 4, taken (ours, ruby/ruby#19483) |
| `send_fallback_send_not_optimized_method_type_optimized` | 42k (11.3) | 16k (4.7) | 41k (14.3) | 5, taken (ruby/ruby#19583) |
| `send_fallback_send_megamorphic` | 2k (0.5) | 30k (8.6) | 28k (10.0) | YJIT is megamorphic at most of these sites too |
| `send_fallback_send_polymorphic` | 6k (1.6) | 9k (2.6) | 28k (9.9) | Shopify/ruby#1099 |
| `send_fallback_sendforward_not_specialized` | 5k (1.4) | 5k (1.4) | 12k (4.2) | 6, taken (ruby/ruby#18326). YJIT falls back at most of these sites too |
| `send_fallback_super_*` (complex args, polymorphic, from block) | 21k (5.7) | 5k (1.4) | 8k (2.7) | Shopify/ruby#1039 rows 45/46 |

Top sites (ZJIT fallbacks − YJIT generic calls, per iteration, estimated M Ir):

| benchmark | site | extra | M Ir | reason |
|---|---|---:|---:|---|
| railsbench | `Array#each` (`<internal:array>`) yield | 142k | 38.7 | `invokeblock_polymorphic_miss` |
| railsbench | `OrderedOptions` `block in initialize` (`@parent._get(k)`) | 42k | 11.4 | protected |
| railsbench | `Rack::Request#fetch_header` (`@env.fetch(name, &block)`) | 42k | 11.4 | `complex_arg_pass` (`&block` to a C method) |
| railsbench | `_read_attribute(name, &block)` | 36k | 9.7 | `send_block_arg_not_nil` |
| railsbench | `Array#map` yield | 32k | 8.7 | `invokeblock_not_specialized` |
| railsbench | Notifications `iterate_guarding_exceptions`, `mon_synchronize` | 42k | 11.4 | `send_block_arg_not_nil` |
| lobsters | `_read_attribute(name, &block)` | 58k | 16.7 | `send_block_arg_not_nil` |
| lobsters | `block in fetch_value` (attribute_set/builder.rb) | 42k | 4.3 | `no_profile_missing_ic` |
| lobsters | `Array#each` / `#map` yields | 70k | 20.1 | polymorphic / not specialized |
| lobsters | `Type::Value#hash` (`[self.class, precision, scale, limit].hash`) | 25k | 7.1 | `send_polymorphic_fallback` |
| lobsters | `Arel::Collectors::Composite#<<` (`left << str`), `Attribute#hash` | 56k | 5.8 | `no_profile_missing_ic` |
| shipit | `block in _load_from_sql` (`attribute_types` on the model class) | 114k | 39.7 | `send_polymorphic_fallback` |
| shipit | `Composite#<<` | 105k | 12.5 | `no_profile_missing_ic` |
| shipit | `Array#each` / `#map` yields | 145k | 50.8 | `invokeblock_polymorphic_miss` |
| shipit | `block in fetch_value` | 74k | 8.8 | `no_side_exits` |
| shipit | `Type::Value#hash` | 68k | 23.7 | `send_polymorphic_fallback` |
| shipit | `_read_attribute(name, &block)` | 68k | 23.6 | `send_block_arg_not_nil` |
| shipit | `Association#klass` (`reflection.klass`), `Attribute#hash`/`==`, `Type::Value#==` | 192k | 22.8 | `no_profile_missing_ic` |
| shipit | `Core.current_shard`/`current_role`, `association`, `Scoping.value_for` | 97k | 34.0 | polymorphic class-level sends |

The attr_reader sites (`left`, `precision`, `name`, `reflection`) are implicit-self calls in methods that many
subclasses or shapes share. YJIT guards up to 5 shapes or classes per site
(`SEND_MAX_DEPTH`; see `gen_get_ivar` in yjit/src/codegen.rs) and reads the slot. For a non-`T_OBJECT` receiver it
calls `rb_ivar_get_at_no_ractor_check` with the index: 668k calls on shipit at 53 Ir each. ZJIT has no shape
profile at these sites, so it calls `rb_ivar_get`, which looks the name up in the shape tree: 997k calls at 131 Ir
each (inclusive).

## 2. JIT code (14–31% of the gap)

ZJIT's JIT code is larger than YJIT's per operation. ZJIT code is attributed by HIR instruction (run b), YJIT code by
codegen function. Counts come from the stats runs:

| per operation (JIT code only) | railsbench | lobsters | shipit |
|---|---:|---:|---:|
| ZJIT cfunc call with a frame (`CCallWithFrame` + `CCallVariadic`) | **40.7 Ir** × 2.10 M | **40.7 Ir** × 0.97 M | **39.0 Ir** × 1.66 M |
| YJIT cfunc call with a frame (`gen_send_cfunc` + its `gen_push_frame`; the call tail is missing, see below) | **17.7 Ir** × 2.38 M | **17.8 Ir** × 1.01 M | **17.9 Ir** × 1.91 M |
| YJIT cfunc call with a frame, whole sequence through the call ([Lead 12](#lead-12-what-a-cfunc-call-with-a-frame-costs)) | **29.9 Ir** × 2.16 M | **30.1 Ir** × 0.91 M | **30.3 Ir** × 1.72 M |
| ZJIT inlined ISEQ call (`PushInlineFrame` + `PopInlineFrame`) | 22.0 Ir × 4.20 M | 20.6 Ir × 1.59 M | 21.6 Ir × 3.52 M |
| ZJIT direct ISEQ call (`SendDirect`; `EntryPoint`, `Return` extra) | 32.6 Ir × 1.71 M | 32.1 Ir × 0.98 M | 30.9 Ir × 1.91 M |
| YJIT ISEQ call (`gen_send_iseq` + its `gen_push_frame`; `leave` extra) | 18.6 Ir × 6.39 M | 18.1 Ir × 2.95 M | 19.1 Ir × 6.54 M |
| ZJIT `PatchPoint` (nop padding) | 31.7 M | 14.0 M | 27.9 M |
| ZJIT entry trampoline | 29.3 M | 17.3 M | 40.1 M |

* **cfunc calls with a frame** (lead 12) cost about **9–11 Ir** more per call in ZJIT, or 22.7 / 10.3 / 14.4 M Ir
  per iteration (12%, 6% and 2% of the gap). An earlier version of this page said 23 Ir and 48 / 22 / 35 M. That
  count missed the call tail, which YJIT charges to `opt_send_without_block`. Breakdown, disassembly and fixes:
  [Lead 12](#lead-12-what-a-cfunc-call-with-a-frame-costs).
* **Inlined calls** still cost 21 Ir each for `PushInlineFrame`. A full YJIT call costs about 19 Ir plus `leave`.
  Inlining doesn't add to the gap against YJIT, but it is where ZJIT could gain most beyond YJIT. Taken:
  Shopify/ruby#1023 (Virtual Inline Frames, nirvdrum) and Shopify/ruby#1008.
* **PatchPoint** ranges consist of the multi-byte nops that `patch_point_pad` inserts when patch points are too close
  together. Each nop counts as one Ir. They are 0.6–0.7% of ZJIT's Ir, but cheap in cycles. Lead 16, low priority:
  measure cycles before acting.
* **By ISEQ** (run a), the difference is spread out, and inlining moves callee code into the caller. The largest
  single ISEQ is `Array#each` (+10.8 / +5.3 / +16.2 M), where the polymorphic yield dispatch lives (lead 1, taken).

## 3. GC (5–15% of the gap)

| | railsbench | lobsters | shipit |
|---|---:|---:|---:|
| `rb_zjit_root_mark` inclusive, M Ir per iteration (run a) | 28.5 | 7.0 | 39.3 |
| `rb_yjit_root_mark` inclusive | 3.1 | 0.3 | 2.2 |
| JITFrames marked per GC (`jit_frame_count`) | 38,119 | 150,144 | 119,011 |
| `rb_zjit_iseq_mark` / `rb_yjit_iseq_mark` inclusive | 0 / 0 | 0 / 0 | 18.7 / 11.9 |

`rb_zjit_root_mark` (zjit/src/gc.rs) calls `rb_gc_mark_movable` on the ISEQ of every JITFrame on every GC, minor
ones too. There is one JITFrame per call site and frame state, so most of these ISEQ pointers are duplicates.
**Lead 13** (free, small): mark each distinct ISEQ once, for example from a set kept when JITFrames are allocated.
Size: 25.4 / 6.7 / 37.1 M Ir, 14%, 4% and 6% of the gap. The rest of the GC bucket follows the number of GCs in the
window.

Not a lead by Ir, recorded for wall time: `with_vm_lock` (zjit/src/cruby.rs) calls `rb_gc_disable()`, which runs
`gc_rest()` and finishes any incremental marking and lazy sweeping before returning. Shipit calls `extend` 297
times per iteration (`rb_mod_extend_object` → `rb_make_metaclass`). Each call runs
`rb_zjit_invalidate_no_singleton_class` under the lock. **114 M Ir of shipit's GC work per iteration runs inside
those calls.** That is GC work moved, not added: it turns incremental steps into a pause. The code comment
explains why GC must be off under the lock, so a change here needs care.

## 4. Side exits, throw and frame materialization (2–8%)

* **`throw` from blocks** (`break`, `next`, `return` in a block) goes through `rb_zjit_throw` → longjmp (20,357 /
  8,757 / 8,367 per iteration). `vm_exec_handle_exception` then jumps again. In total there are 56,020 / 19,622 /
  22,315 `rb_ec_tag_jump` per iteration, against YJIT's 1,305 / 986 / 5,853. Each longjmp calls
  `zjit_materialize_frames`: **15.6 / 5.3 / 13.2 M Ir**, plus `vm_exec_handle_exception`. Sites:
  * Journey `Visitors::…#evaluate` block (visitors.rb:42, 9,057 on railsbench);
  * `PathSet#find_all` block (path_set.rb:46, 6,000);
  * `Router#serve` block;
  * `SQLite3::Statement#each` block;
  * `Formatter#generate` blocks;
  * TZInfo `periods_for_local` block.

  Taken: Shopify/ruby#1093 (k0kubun) covers TAG_RETURN/TAG_BREAK, and ruby/ruby#18244 (luke-gruber, draft) avoids
  the side exit on `throw`.
* **Exception-handler exits:** 21,657 / 9,118 / 9,757 per iteration. These are `rescue`/`ensure` bodies in Rack
  and Action Pack middleware, which then run in the interpreter. The interpreted instructions after them are the
  "compiled" column below (`Rack::ETag#call` 126k per iteration on railsbench, `url_for` 59k, CSP middleware 58k).
  Taken: ruby/ruby#18759 (rafaelfranca).
* **Invalidated constant patch points** on shipit: `ConnectionHandling#connection_specification_name` exits 38,466
  times per iteration and then runs 270k interpreted instructions; `connection_pool` adds 111k. This is lead 9,
  taken (k0kubun, ruby/ruby#19617).

## 5. Interpreter, allocation, write barriers: ZJIT already does better

* **Interpreter:** ZJIT runs 33k / 15k / 9k instructions per iteration in ISEQs without JIT code. YJIT runs 946k /
  240k / 241k: it never compiles `build_handle`, `groups_for` and `_find_all` on railsbench, and TZInfo `period_for`
  and `TimeWithZone#initialize` elsewhere. ZJIT's interpreter time is almost all **after exits** in compiled ISEQs
  (942k / 408k / 883k). The interpreter bucket is still 30 / 20 / 1 M Ir lower for ZJIT.
* **Allocation:** ZJIT allocates 0.2–1.1% fewer objects per iteration. Its object allocation is also cheaper than
  YJIT's calls to `rb_class_allocate_instance` and `rb_ec_ary_new_from_values`: −42 / −17 / −27 M.
* **Write barriers:** ZJIT calls `rb_gc_writebarrier` far less often (49k against 477k from JIT code on shipit):
  −13 / −4 / −5 M.
* **Compile and invalidation in the window:** ZJIT compiles 0.1 / 2.6 / 0.5 ISEQs per iteration after warmup. Its
  compile inclusive is ≤ 10 M Ir (shipit `rb_zjit_iseq_gen_entry_point` 10.3 M), similar to YJIT's stubs and
  `branch_stub_hit`. As a bucket it is −1.9 / −9.4 / +2.5 M. Invalidation is < 0.1 M once the GC it triggers is
  excluded.

## Leads

The lead numbers continue [zjit-iseq-leads](zjit-iseq-leads.md#new-leads-from-the-zjit-yjit-gap-2026-11-03). The
queue has the ranked list with free/taken status, checked on 2026-11-03 against assignees, all 67 open ruby/ruby
PRs with "ZJIT" in the title, and keyword searches of Shopify/ruby issues and ruby/ruby PRs.

* **Free and new:** 12 (cfunc frame cost in JIT code, resized; free in part),
  13 (JITFrame root marking), 14 (`&block` to C methods / `complex_arg_pass`), 15 (getivar on final versions and
  singleton objects), 16 (PatchPoint nops), and 18 (`with_vm_lock` `gc_rest`, wall time only).
* **Existing, now sized:** 3 (class-polymorphic sends, the largest on shipit), 7 (`&block` forwarding), and 1, 4,
  5, 6, 9 (taken).
* **Taken, new:** 11 (attr_reader/getivar on shape-polymorphic receivers; tekknolagi's ruby/ruby#19443 and draft
  ruby/ruby#18616, see [Lead 11](#lead-11-why-there-is-no-profile)), 17 (`throw` unwinding and materialization,
  Shopify/ruby#1093 / ruby/ruby#18244 / #18759) and 19 (`PushInlineFrame`, Shopify/ruby#1023).

## Lead 11: why there is no profile

Follow-up of 2026-11-03 on lead 11, ruby/ruby master `a8b095a07e`. This was an investigation only: nothing was
built for upstream and nothing was posted. Repro scripts and dumps are in `~/w/l11` on the orb and were not
committed.

**Cause: the profile exists, but a polymorphic dispatch arm drops it.** Neither of the other suspected causes holds:
attr_reader dispatch does profile, and the profile slot is filled. The sites are not megamorphic either: 71–77% of
these sites see a single (class, shape) and two entries cover 88–96%. The loss happens in three steps (HIR dumps
with `--zjit-dump-hir`):

1. In `iseq_to_hir`, `opt_send_without_block` with a polymorphic receiver profile emits one `CondBranchHasType` arm
   per distinct class. Each arm takes a fresh Snapshot with `profiles.copy_entries_except(exit_id, snapshot,
   recv)`, which drops the receiver's profile entry. The arm's receiver is then only `StaticallyKnown` from the
   class refinement.
2. In `type_specialize`, the attr_reader (`VM_METHOD_TYPE_IVAR`) branch finds `profiled_type = None`. It emits
   `GetIvar` with `ic: null` and counts `getivar_fallback_no_profile_missing_ic`.
3. Codegen calls `rb_ivar_get`, a full shape-tree walk (`rb_ivar_lookup` + `rb_shape_get_iv_index`) of about
   130 Ir per call inclusive.

The same happens to an implicit-self reader inside a method that is inlined into such an arm: `PushInlineFrame :get`
is followed by `GetIvar v18, :@v` with no IC.

**Repro** (`r.rb`, 300 warmup calls, then 10,000 calls; fallbacks counted over the 10,000):

| case | master | with ruby/ruby#19443 |
|---|---|---|
| `box`: one class, two shapes, `o.v` (Shopify/ruby#1099 pattern 1) | 10,000 | 10,000 |
| `selfshape`: one class, two shapes, `def get = v` | 10,000 | 10,000 |
| `selfmono`: one class, one shape | 0 | 0 |
| `selfclasses`: two subclasses, reader in the base class (`Type::Value#hash`-like) | 10,000 | 0 |
| `selfmanyclasses`: six subclasses | 8,334 getivar + 3,332 `send_polymorphic_fallback` | 0 getivar + 3,332 `send_polymorphic_fallback` |

Callgrind micro-benchmark (ZJIT, per call, GC excluded):

| case | Ir per call |
|---|---|
| empty loop | 33 |
| attr_reader, one shape | 67 |
| attr_reader, two shapes | 181 |
| `@v` read, two shapes | 97 |

A two-shape attr_reader costs about 114 Ir more than a one-shape one; `rb_ivar_get` alone is 104 Ir.

**What ruby/ruby#19443 changes** (tekknolagi, "ZJIT: Specialize polymorphic class + monomorphic shape", open, approved by jacob-shops and k0kubun). It gives an
arm a monomorphic profile when exactly one bucket names the arm's class. That handles different classes with one
shape each, but not several shapes of one class. Its diff carries the TODO "Specialize for polymorphic shape within
a type". The hir.rs and distribution.rs parts were applied on `a8b095a07e`; opt_tests.rs was left out because of a
conflict. The runs used 512/1024 MiB with 0 `compile_error_out_of_memory`.

| per iteration | railsbench | lobsters | shipit |
|---|---|---|---|
| `getivar_fallback_no_profile_missing_ic`, master → #19443 (stats) | 221k → 197k (−11%) | 320k → 246k (−23%) | 837k → 587k (−30%) |
| `rb_ivar_get` calls, master → #19443 (Callgrind) | 243k → 219k | 354k → 306k | 1,001k → 785k |
| `rb_ivar_get` inclusive Ir, master → #19443 | 31.5 → 28.7 M | 48.7 → 41.7 M | 131.5 → 100.9 M |
| total Ir, master a / c → #19443 a / c | 4,943 / 4,946 → 4,935 / 4,941 M | 3,274 / 3,303 → 3,267 / 3,266 M | 3,972 / 3,972 → 3,936 / 3,935 M |

Shipit drops 0.9%, against an A/A of 0.03%. Railsbench and lobsters move less than their A/A spread in total Ir,
but the drop in `rb_ivar_get` is deterministic. `getivar_fallback_no_side_exits` rises on lobsters (154k → 178k)
and shipit (411k → 437k). That is lead 15's bucket, now reached by readers whose arm has a shape but whose final
version has no side exits.

Callgrind setup: 10 warmup and 3 measured iterations in two runs (a, c). Both runs of a build share the `a` perf
map, which only affects the per-symbol split, not totals or C functions.

**Remaining after #19443: 70–89% of the lead.** These are arms whose class was profiled with two or more shapes:
`Arel::Collectors::Composite#<<`, `ActiveModel::Attribute#hash`/`#==` and `Association#klass` all see
attribute-dependent shapes per class. The remaining gap against YJIT is about **11 / 24 / 59 M Ir per iteration**,
the old size scaled by the remaining count.

**Smallest exact fix.** Give each arm every profiled shape of its class, not only the shape when exactly one
exists. Then `GetIvar` in the arm becomes a shape-compare chain: compare the shape, load the field, and otherwise
fall through to `rb_ivar_get`, the generic helper. A miss must not side-exit, because the arm never promised a
shape, and must not re-profile, because that would discard the type profile the arms came from. This is exact: a
shape determines the ivar's index, and a miss goes through the same helper as today. An IC on the attr_reader's
`GetIvar` would be smaller, but `rb_vm_getinstancevariable`'s one-entry IC thrashes on these alternating shapes.
Implicit-self readers inlined into an arm need the same handoff, through the `self` of the inline frame.

**Ir estimate.** A shape compare plus a load is about 5–10 Ir against about 130. With up to two shapes per arm
covering about 90% of reads, the fix saves about **21 / 27 / 63 M Ir per iteration (0.4% / 0.8% / 1.6% of ZJIT's
total)** over #19443. That is more than the gap to YJIT above, because YJIT also pays `rb_ivar_get_at_no_ractor_check`
at some of these sites.

**Ownership: taken.**

* **ruby/ruby#18616** (tekknolagi, open draft, "ZJIT: Seed polymorphic type branches with shape data too", updated
  2026-09-04, no reviews). It does exactly this. In `specialize_polymorphic_send`, it groups the profile buckets of
  each class and emits a `LoadShape` + `IsBitEqual` + `CondBranch` chain over the arm's shapes "to optimize
  polymorphic attr_reader to field loads instead of generic getivar". Under the queue rule, an open PR makes the
  lead taken. The draft was missed in the first status check.
* **ruby/ruby#19443** (tekknolagi, open, approved) is the one-shape half of the lead, and its TODO is the
  multi-shape half.
* **Shopify/ruby#1039, rows 77 and 78** (k0kubun's lobsters branch, rows with no assignee): `a96d35362b` "Keep the
  profiled shape reachable through guards and dispatch arms" and `4857dd0ef5` "Branch on the ivar shape for
  attr_accessor sends in polymorphic arms".
  * They port upstream `zjit/all` commits `af5bc8f19d`, `98f1b7adbd`, `2f92871390`, `afe2f672d9` and `7ce7db7820`
    to this mechanism, including the inlined-callee leak and the no-reprofile miss path.
  * Row 77's message measures `zjit/all` at 338,599 `getivar_fallback_no_profile_missing_ic` against 5,204,190 on
    its base (whole lobsters run).
  * On lobsters, row 77 measures −0.69% and row 78 +0.00%, which is within the issue's ±0.5% noise.
* **Shopify/ruby#1099** has no assignee; lead 11 is its pattern 1. Our ruby/ruby#19558 covers sends, not getivar.

Recommendation: take lead 11 off the free list. Don't build it. The data above (per-site counts, the five-case
repro, and the measured #19443 effect) could later help tekknolagi's draft or rows 77/78, once posting is open
again.

No crash, wrong result or divergence turned up in this follow-up.

## Lead 12: what a cfunc call with a frame costs

Follow-up of 2026-11-03, ruby/ruby master `a8b095a07e`, investigation only: nothing was built for upstream and
nothing was posted. Scratch scripts and dumps are in `~/w/l12` on the orb and were not committed.

**Method.** One more Callgrind run per JIT and benchmark used the same setup as [Pins and method](#pins-and-method),
with `--zjit-perf=hir` and `--yjit-perf=codegen`. After the measured window, the harness copied the JIT code
region out of `/proc/self/mem`. Each executed instruction is then attributed by:

* its exec count, from `--dump-instr=yes`;
* its disassembly, from `objdump`;
* a class, assigned by a small classifier: frame push, spill, push/pop, and so on.

The two JITs delimit a call differently:

* **ZJIT:** a site is its `CCallWithFrame` or `CCallVariadic` range.
* **YJIT:** a site runs from the start of `gen_send_cfunc`, in address order, through the `call` and the
  `ec->cfp` store after it.

**Correction: the earlier "YJIT 18 Ir" was a partial count.** The perf-map ranges `gen_send_cfunc` and
`gen_push_frame` stop before the call. YJIT charges the rest of the sequence to `opt_send_without_block`: the
`ec->cfp` switch, register spills, argument setup, the call and the `ec->cfp` restore. Measured over the whole
sequence:

| per call | railsbench | lobsters | shipit |
|---|---:|---:|---:|
| ZJIT `CCallWithFrame` + `CCallVariadic` | 40.7 Ir × 2.11 M | 40.7 Ir × 0.97 M | 39.0 Ir × 1.66 M |
| YJIT, whole cfunc call sequence | 29.9 Ir × 2.16 M | 30.1 Ir × 0.91 M | 30.3 Ir × 1.72 M |
| difference | **+10.8 Ir** | **+10.6 Ir** | **+8.7 Ir** |
| lead 12 size (difference × ZJIT calls) | **22.7 M** (12% of the gap) | **10.3 M** (6%) | **14.4 M** (2%) |

That replaces the earlier 48 / 22 / 35 M. The ZJIT numbers match the first run to the decimal, which serves as the
A/A for this measurement. The YJIT ISEQ-call row in [JIT code](#2-jit-code-1431-of-the-gap) (18.6 Ir) likely
undercounts the same way; it was not re-measured.

End to end, the micro-benchmark `~/w/l12/m.rb` loops a single call, with Ir per call and GC excluded:

| case | ZJIT | YJIT |
|---|---:|---:|
| `h.key?(k)` | 239 | 245 |
| `h.fetch(k)` | 312 | 313 |
| `AR.include?(2)` | 173 | 164 |
| `RE.match?(S)` | 732 | 720 |
| `h.key?(k)` after four constant locals | 243 | 247 |

ZJIT and YJIT are within ±12 Ir. YJIT pays for its operand-stack writes and interrupt checks in other instructions,
so the +9–11 Ir is an upper bound on what lead 12 adds to the gap. What a fix saves in ZJIT is still real.

**Where the +9–11 Ir goes** (Ir per call, ZJIT / YJIT, with the difference in brackets):

| part | railsbench | lobsters | shipit |
|---|---|---|---|
| caller-saved push/pop around the call, and the result moves they force | 7.1 / 1.1 (+6.0) | 6.8 / 1.2 (+5.6) | 6.0 / 1.2 (+4.8) |
| spills before the call: locals, operand stack, and YJIT's register spills | 5.6 / 2.1 (+3.5) | 6.0 / 2.2 (+3.7) | 4.9 / 2.1 (+2.8) |
| of which receiver/argument stores that the frame push overwrites | 2.3 / 0 (+2.3) | 2.3 / 0 (+2.3) | 2.2 / 0 (+2.2) |
| SP/CFP register switch, frame push, stack overflow check | 18.9 / 16.5 (+2.4) | 18.7 / 16.3 (+2.5) | 18.8 / 16.5 (+2.3) |
| of which ZJIT moves `rbx`/`r13` (`add rbx`, `sub r13`, `add r13`, `sub rbx`) | 4.0 | 4.0 | 4.0 |
| variadic `argv` copied to the C stack | 0.9 / 0 (+0.9) | 1.0 / 0 (+1.0) | 1.1 / 0 (+1.1) |
| caller `cfp->sp`, `cfp->pc` and JITFrame writes | 3.0 / 1.7 (+1.4) | 3.0 / 1.7 (+1.3) | 3.0 / 1.7 (+1.3) |
| interrupt check (YJIT only) | 0 / 3.1 (−3.1) | 0 / 3.3 (−3.3) | 0 / 3.3 (−3.3) |
| `ec->cfp` stores, argument setup, call | 5.2 / 5.4 (−0.2) | 5.1 / 5.4 (−0.3) | 5.1 / 5.4 (−0.3) |

The hottest sites, Ir per call for ZJIT / YJIT:

* `Hash#fetch` (`rb_hash_fetch_m`, variadic): 46.1 / 32.0 on railsbench (145k calls per iteration), 44.6 / 32.7
  on lobsters (148k), 40.8 / 31.4 on shipit (410k);
* `Hash#key?`: 37.9 / 28.7 (railsbench, 141k);
* `Regexp#match?`: 41.6 / 29.4 (railsbench, 97k);
* `Hash#delete`: 40.0 / 28.7 (railsbench, 62k);
* `Array#any?`: 41.1 / 32.0 (railsbench, 58k).

The hottest lobsters `Hash#fetch` site (52.8k calls per iteration, 45 instructions) shows each part:

```text
lea r8,[rbx+0x80]; cmp r13,r8; jbe …            stack overflow check
mov [rbp-0x8],<JITFrame>                         JITFrame
lea r8,[rbx]; mov [r13+0x8],r8                   caller cfp->sp
mov [rbx+0x8],rsi; mov [rbx],rdi                 spill receiver and argument  <- dead
mov [rbx-0x30],rsi; mov [rbx-0x28],rdx; …        spill locals (3)
movabs rcx,<cme>; mov [rbx],rcx                  env data overwrites [rbx] …
mov [rbx+0x8],rdx; mov [rbx+0x10],0x55550083     … and [rbx+0x8]
… 6 callee CFP field stores …
add rbx,0x18; sub r13,0x38; mov [r12+0x10],r13   switch SP and CFP registers
mov rdx,rbp; sub rdx,0x18; mov [rdx],rsi         argv on the C stack
push rsi; push 0x0                               caller-saved (+ alignment)
mov rsi,rdx; mov rdx,rdi; mov edi,0x1; call rb_hash_fetch_m
mov r11,rax; pop rsi; pop rsi; mov rdi,r11
add r13,0x38; mov [r12+0x10],r13; sub rbx,0x18  restore CFP and SP
```

The previous hypothesis holds on every hot site, but it covers only part of the gap. The parts are:

1. **Caller-saved registers.** Values that live across the call stay in caller-saved registers and are pushed and
   popped, often with an alignment `push 0x0`. YJIT keeps them in VM stack memory.
2. **Dead receiver/argument spills.** `gen_spill_stack` writes the whole operand stack, receiver and arguments
   included. The frame push overlays its CME/specval/flags on the receiver slot and the next two. Slots beyond
   those lie above the C frame's `cfp->sp`, and variadic `argv` lives on the C stack. Nothing reads these stores.
3. **Locals spilled at every call,** including locals that hold constants or did not change.
4. **The SP and CFP registers are moved and restored around the call,** though nothing on the JIT side runs in
   between. YJIT computes the new CFP into a scratch register for `ec->cfp` and leaves `r13` alone.
5. **ZJIT has no interrupt check here,** which is 3 Ir in ZJIT's favour.

**Smallest exact fixes, and their ownership:**

| part | fix | Ir saved per call | M Ir per iteration | status |
|---|---|---:|---:|---|
| dead receiver/argument stores | Spill only the caller part of the stack in `gen_ccall_with_frame` and `gen_ccall_variadic`, that is `state` truncated to `caller_stack_size`. #18960 already builds its stack map for these calls from `state.with_stack_size(caller_stack_size)`. | 2.2–2.3 | 4.9 / 2.2 / 3.7 | **free**: no issue, PR or #1039 row. Same lines as XrXr's ruby/ruby#18960, so it belongs on top of #18960 or with him. |
| SP/CFP register switch | Keep `rbx` and `r13` fixed. Write `ec->cfp` from `lea tmp,[r13-0x38]`, and write back `r13` after the call. | ~3 (4 instructions → 1) | 6.3 / 2.9 / 5.0 | **free**: no issue, PR or row. |
| caller-saved push/pop | Allocate callee-saved registers (`r14`/`r15`) to values that live across a call. | up to 5–6 | up to 12.6 / 5.4 / 8.0 | Shopify/ruby#1039 row 58 `c309de9071` "Allocate callee-saved registers to call-crossing VRegs" (unassigned, +0.47% on lobsters; lir.rs +430 lines). Not small. It is next to our ruby/ruby#19681 and Shopify/ruby#1065/#1075. |
| locals spill | HIR local spills | 2.5–3.4 | 6.4 / 3.3 / 4.2 | **taken**: ruby/ruby#18960 (XrXr, open) deletes `gen_spill_locals` from both paths. #1039 row 80 "Skip redundant local spill stores" is the same idea. |
| caller `cfp->sp` | Skip a store that repeats the previous one | ≤1.3 | ≤2.7 / 1.3 / 2.2 | #1039 row 69 `854088e42f` (unassigned) |

The two free fixes save about **5.3 Ir per call: 11.2 / 5.1 / 8.7 M Ir per iteration**, roughly half of lead 12.

* **Dead stores.** The fix is exact for the following reasons:
  * no instruction between the spill and the frame push reads those slots;
  * GC marks the VM stack only up to the callee's `cfp->sp`, which sits above the env data;
  * the cfunc gets its receiver and arguments in registers, or in a C-stack `argv`;
  * an exception rebuilds the caller with `cfp->sp` = `caller_stack_size`.
* **SP/CFP switch.** The fix looks exact as far as I can tell:
  * JIT-spilled values are addressed from `rbp`, not `rbx`;
  * `argv` sits on the C stack;
  * the frame push computes its addresses before the switch;
  * the cfunc never sees `rbx` or `r13`.

  The ZJIT owners should still confirm that no codegen invariant ties the SP register to the top frame during a C
  call.

**Ownership checks** (2026-11-03):

* **XrXr's open PRs:**
  * ruby/ruby#18960 (open, not draft, updated today) touches exactly these lines, as shown in the table above.
  * #19432 (draft) encodes stack maps.
  * #19652 prints CCall stack maps in LIR dumps.
* **Other open ZJIT PRs in the area:**
  * our #19681 makes caller-saved survivor search faster at compile time and leaves the generated code unchanged;
  * #18949 and #18968 (rafaelfranca) are a refactor and a debug-only `PC_POISON` fix.
* **Shopify/ruby#1039:** there are no assignees on rows 58, 69 and 80, and no row for the dead stores or the
  register switch.
* **Shopify/ruby issues:** no open issue covers `CCallWithFrame` cost.

Recommendation: keep lead 12 free, resized to 22.7 / 10.3 / 14.4 M. If we build, the dead-store fix is a few lines
and exact, but it edits lines that #18960 rewrites, so ask XrXr or wait for #18960 to land. The register switch
is independent and slightly larger. No crash, wrong result or divergence turned up.

## Caveats

* Callgrind counts instructions, not cycles. Nops, setjmp and stores count the same as a cache miss, and wall time
  isn't measured here.
* The per-reason Ir uses one average price per benchmark for sends and yields. Order of magnitude is reliable;
  the second digit is not.
* ZJIT inlines ISEQs. Its JIT-code and call-edge attribution then names the caller, while `--zjit-stats-iseq`
  names the callee. The site table joins on the callee for ZJIT and on YJIT's own ISEQ, so the join is consistent,
  but the "by ISEQ" JIT-code table is not.
* ruby-bench pins Rails 8.1. Rails main changes some sites, for example `_read_attribute`'s block (see lead 7).
