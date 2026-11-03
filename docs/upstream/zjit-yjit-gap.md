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
* **JIT code** adds 31%, 26% and 14%. ZJIT's code for a cfunc call with a frame costs about **40 Ir per call
  against YJIT's 18**. That accounts for most of the JIT-code bucket on railsbench.
* **GC** adds 15%, 5% and 12%. Most of it is `rb_zjit_root_mark`, which marks the ISEQ of every JITFrame on every
  GC, minor ones too: 38k, 150k and 119k JITFrames.
* **ZJIT does better than YJIT** on allocation (−42 / −17 / −27 M), the interpreter (−30 / −20 / −1 M: ZJIT
  compiles more ISEQs) and write barriers (−13 / −4 / −5 M).
* Side exits and frame materialization are 8%, 3% and 2%. Compile and invalidation inside the window are ≤ 0.3% of
  Ir either way.

Ranked by size, the leads are (M Ir per iteration, railsbench / lobsters / shipit, and share of each gap):

| # | lead | M Ir | share of gap | status |
|---|---|---|---|---|
| 11 | attr_reader/getivar on shape-polymorphic receivers without a shape profile (`getivar_fallback_no_profile_missing_ic`) | 12.4 / 30.8 / 83.9 | 7% / 17% / 14% | **free** (Shopify/ruby#1099 pattern 1, unassigned) |
| 3 | class-polymorphic sends to one method entry (`send_polymorphic_fallback`) | 7.2 / 42.1 / 180.1 | 4% / 24% / 29% | **free** (Shopify/ruby#1099 pattern 2; slot granted) |
| 1 | polymorphic or unspecialized yields in `Array#each`/`#map` | 70.4 / 27.2 / 60.9 | 38% / 15% / 10% | taken (k0kubun, Shopify/ruby#1093) |
| 12 | cfunc calls with a frame: ~40 Ir of JIT code against YJIT's ~18 | 48 / 22 / 35 | 26% / 12% / 6% | **free**, mechanism not confirmed |
| 7 | `&block` forwarding (`send_block_arg_not_nil`) | 29.4 / 25.1 / 66.0 | 16% / 14% / 11% | **free** (Shopify/ruby#1014; slot granted) |
| 13 | `rb_zjit_root_mark` marks every JITFrame's ISEQ on every GC | 25.4 / 6.7 / 37.1 | 14% / 4% / 6% | **free** |
| 14 | `&block` passed to a C method (`Rack::Request#fetch_header`) and other `complex_arg_pass` | 19.5 / 6.1 / 13.1 | 11% / 3% / 2% | **free** (Shopify/ruby#1039 row 42, unassigned) |
| 4 | protected calls | 14.9 / 4.4 / 10.6 | 8% / 2% / 2% | taken (ours, ruby/ruby#19483) |
| 5 | `Kernel#send` | 11.3 / 4.7 / 14.3 | 6% / 3% / 2% | taken (tekknolagi, ruby/ruby#19583) |
| 15 | getivar on final versions and long-lived singleton objects (`getivar_fallback_no_side_exits`) | 3.9 / 7.8 / 24.0 | 2% / 4% / 4% | **free** (Shopify/ruby#1099 pattern 3) |
| 17 | `throw` from blocks and exception handlers unwind by longjmp and materialize frames | 15.6+ / 5.3+ / 13.2+ | 8% / 3% / 2% | taken (Shopify/ruby#1093, ruby/ruby#18759, ruby/ruby#18244) |
| 16 | PatchPoint nop padding executed inline | 31.7 / 14.0 / 27.9 | Ir only, not cycles | free, low priority |

Lead 11 and lead 3 are the largest free leads on lobsters and shipit, and lead 12 is the largest free lead on
railsbench. The full list with sites is in [Leads](#leads). No crash, wrong result or divergence turned up. The
only failed run was a lobsters 500 caused by two processes sharing one `tmp/cache`, not by a JIT. After that,
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
| `getivar_fallback_no_profile_missing_ic` | 218k (12.4) | 303k (30.8) | 706k (83.9) | 11, free |
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
| YJIT cfunc call with a frame (`gen_send_cfunc` + its `gen_push_frame`) | **17.7 Ir** × 2.38 M | **17.8 Ir** × 1.01 M | **17.9 Ir** × 1.91 M |
| ZJIT inlined ISEQ call (`PushInlineFrame` + `PopInlineFrame`) | 22.0 Ir × 4.20 M | 20.6 Ir × 1.59 M | 21.6 Ir × 3.52 M |
| ZJIT direct ISEQ call (`SendDirect`; `EntryPoint`, `Return` extra) | 32.6 Ir × 1.71 M | 32.1 Ir × 0.98 M | 30.9 Ir × 1.91 M |
| YJIT ISEQ call (`gen_send_iseq` + its `gen_push_frame`; `leave` extra) | 18.6 Ir × 6.39 M | 18.1 Ir × 2.95 M | 19.1 Ir × 6.54 M |
| ZJIT `PatchPoint` (nop padding) | 31.7 M | 14.0 M | 27.9 M |
| ZJIT entry trampoline | 29.3 M | 17.3 M | 40.1 M |

* **cfunc calls with a frame** (lead 12) cost about 23 Ir more per call in ZJIT. That is about **48 / 22 / 35 M Ir**
  per iteration: 26%, 12% and 6% of the gap. The comparison is not exact, because YJIT charges part of its send
  setup to `opt_send_without_block` (55 M on railsbench) and to `jit_guard_known_klass` (65 M). ZJIT charges the
  matching work to `GuardType` (50 M) and `PatchPoint`. A gdb disassembly of a `CCallWithFrame` for
  `Array#include?` (35 instructions) shows the following:
  * the receiver and argument are stored to the VM stack at `sp[0]` and `sp[1]`, and the frame push overwrites
    them with the CME and specval before the call;
  * caller-saved values are pushed and popped around the call;
  * `ec->cfp` is restored twice after the call.

  This is one sample on a release build, so treat it as a hypothesis until a build with disasm confirms it.
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

* **Free and new:** 11 (attr_reader/getivar on shape-polymorphic receivers), 12 (cfunc frame cost in JIT code),
  13 (JITFrame root marking), 14 (`&block` to C methods / `complex_arg_pass`), 15 (getivar on final versions and
  singleton objects), 16 (PatchPoint nops), and 18 (`with_vm_lock` `gc_rest`, wall time only).
* **Existing, now sized:** 3 (class-polymorphic sends, the largest on shipit), 7 (`&block` forwarding), and 1, 4,
  5, 6, 9 (taken).
* **Taken, new:** 17 (`throw` unwinding and materialization, Shopify/ruby#1093 / ruby/ruby#18244 / #18759) and 19
  (`PushInlineFrame`, Shopify/ruby#1023).

## Caveats

* Callgrind counts instructions, not cycles. Nops, setjmp and stores count the same as a cache miss, and wall time
  isn't measured here.
* The per-reason Ir uses one average price per benchmark for sends and yields. Order of magnitude is reliable;
  the second digit is not.
* ZJIT inlines ISEQs. Its JIT-code and call-edge attribution then names the caller, while `--zjit-stats-iseq`
  names the callee. The site table joins on the callee for ZJIT and on YJIT's own ISEQ, so the join is consistent,
  but the "by ISEQ" JIT-code table is not.
* ruby-bench pins Rails 8.1. Rails main changes some sites, for example `_read_attribute`'s block (see lead 7).
