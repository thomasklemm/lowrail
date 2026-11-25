# ZJIT gap census, round 2: headline2 against YJIT on real apps (bet Z1-2)

How far is ZJIT from YJIT on real Rails apps, once k0kubun's burndown branch lands, and which gaps are still
unowned? Round 1 ([zjit-gap-census.md](zjit-gap-census.md), 2026-11-03) measured master only. Since then k0kubun
tracks the ZJIT perf work in [Shopify/ruby#1030](https://github.com/Shopify/ruby/issues/1030), a burndown over his
branch [`k0kubun/ruby zjit-headline2`](https://github.com/k0kubun/ruby/tree/zjit-headline2). After the gap closed
there, the bet turned to correctness: does headline2 run the census apps' own test suites the same as the
interpreter, before its commits land on master?

**Result.** On headline2 `f2c3f457ff`, **ZJIT runs fewer instructions than YJIT on every measured workload**,
by 5.9% to 10.6%. On master `e8167b0ddd`, ZJIT is still 3.3% to 14.3% behind on the same workloads. Callgrind
Ir per iteration (ruby-bench) or per operation (census apps), ZJIT vs YJIT on the same build, A/A ≤ 0.37%
except Blog (≤ 3.1%, below):

| Workload | master ZJIT vs YJIT | headline2 ZJIT vs YJIT |
| --- | ---: | ---: |
| railsbench | +3.3% | **−9.1%** |
| lobsters (ruby-bench) | +6.8% | **−9.2%** |
| shipit | +14.3% | **−10.6%** |
| Campfire | +7.3% | **−6.9%** |
| Writebook | +10.8% | **−9.8%** |
| Blog | +8.6% | **−5.9%** |

**Ownership.** Where ZJIT still spends more than YJIT on headline2 (GC root marking, generic ivar reads after a
shape-chain miss, the ZJIT entry trampoline, env escapes, `Hash#fetch`, a class-attribute patch point), every item
is already owned: by later commits on k0kubun's own branches (`zjit-dev`, `zjit-headline-exp/rails`), by an open
ruby/ruby PR, or by our own merged PR. **No measured, unowned gap is left, so this round has no issue drafts.**
The census apps show the same picture: on headline2, ZJIT dispatches fewer sends dynamically and side-exits
less than YJIT in Campfire, Writebook and Blog, and only the JIT-code bucket costs more.

**Differential.** On headline2, the census apps' own suites at `--zjit-call-threshold=1` match the interpreter
test by test: Campfire (634 tests), Writebook (310) and Fizzy (1,787), in 9, 6 and 3 ZJIT modes. Only
difference: Campfire's known 1-second wall-clock flake ([Z11](zjit-app-differential.md#campfire-timing-flake-not-a-divergence)).
Ruby's own btest (2,149) and test-all (39,562) pass at threshold 1, and the 51 + 37 + 13 yield probes and ZS1's
probe match the interpreter. **No divergence, nothing to bisect.**

## Pins and method

* **Ruby, release builds** with `--enable-zjit --enable-yjit`, one binary per tree for YJIT and ZJIT:
  * master [`e8167b0ddd`](https://github.com/ruby/ruby/commit/e8167b0ddd) (2026-11-25);
  * headline2 [`f2c3f457ff`](https://github.com/k0kubun/ruby/commit/f2c3f457ff): 104 commits on master
    [`4abea25ab0`](https://github.com/ruby/ruby/commit/4abea25ab0) (2026-11-24), 103 by k0kubun and one of ours
    (`a842958d9c`, "Guard protected sends with the runtime caller self").
* **ruby-bench** [`c54da6e`](https://github.com/ruby/ruby-bench/commit/c54da6e) with `reaping_frequency: 0` and
  `verify_timeout: 1000000` (so no connection reaper thread or verify call lands in some windows), and
  [`zjit_yjit_gap_harness.rb`](../../bench/upstream/zjit_yjit_gap_harness.rb) as the harness. Z13's method
  ([zjit-yjit-gap.md](zjit-yjit-gap.md)), queued by [`zjit-gap-2/cg_queue.sh`](../../bench/upstream/zjit-gap-2/cg_queue.sh): Valgrind
  3.19 with the brk reservation, fixed heap (`RUBY_GC_HEAP_INIT_BYTES=32 MiB`), 150 warmup iterations, then warm
  windows of 3 iterations until 2 in a row are JIT-flat, then the measured window. ZJIT with
  `--zjit-exec-mem-size=512 --zjit-mem-size=1024` (`compile_error_out_of_memory` is 0 in every run). Every
  ruby-bench row passed the JIT-flat gate. activerecord and erubi-rails were not run: their YJIT/ZJIT gap is
  not a real-app question, and they are on #1030's own table.
* **Census apps** through `script/census` on Rails main [`cf0325a832`](https://github.com/rails/rails/commit/cf0325a832),
  corpus `censusz2`, with F1's master overlays (`--ruby-overlays fixtures/corpus/frontier-master`). New
  `script/census run --callgrind` and harness command `callgrind`
  ([harness.rb](../../bench/upstream/census/harness.rb)): 60 warmup operations per workload, then 15 windows of 2
  cycles over the app's workload mix, same count in every run (workloads that write rows do more work in later
  cycles, so a variable count is not comparable). Ir per operation is the last window minus the empty window,
  divided by its operations. Both JITs keep compiling a few ISEQs per window in the apps (lead F1-c,
  [zjit-iseq-leads.md](zjit-iseq-leads.md)), so app windows fail the JIT-flat gate; the table
  ([`census_cg_table.rb`](../../bench/upstream/zjit-gap-2/census_cg_table.rb)) reports Ir without the compile and
  invalidation entry points (inclusive), and next to it the total.
* **Attribution:** [`zjit_yjit_gap_cg.rb`](../../bench/upstream/zjit_yjit_gap_cg.rb) and
  [`zjit_yjit_gap_report.rb`](../../bench/upstream/zjit_yjit_gap_report.rb) (Z13's buckets) on the perf-map runs
  `a`. Stats: `--zjit-stats-quiet` / `--yjit-stats=quiet` over 10 iterations after warmup; traces with
  `--zjit-trace-exits --zjit-trace-exits-sample-rate=20 --zjit-trace-fallbacks-sample-rate=20`, summarized by
  [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb).
* **Ownership sources:** `git log` of every `k0kubun/ruby` `zjit*` branch (839 commits), open Shopify/ruby issues
  (130), open ruby/ruby ZJIT PRs (59) and our queue ([pr-queue](../../bench/upstream/pr-queue/)).

### Not measured

* **Fizzy** fails to boot on Rails main `cf0325a832` (and `69c6c55e86`): `SystemStackError` in its
  `uuid_primary_keys` initializer. Not a ZJIT effect (same on the interpreter); dropped from the Ir table. Its
  test suite does run on Rails 8.2 and is in the differential.
* **Lobsters (census app)** fails `prepare` on Rails main: `User has no attribute prefers_color_scheme` from
  activerecord-typedstore 1.6.0. Same on the interpreter; the ruby-bench lobsters is measured instead.

### Rejected cohorts (kept, not used)

* `census-rejected-v1`: windows ran until the JIT-flat gate passed, so runs had different cycle counts and
  measured different database sizes.
* `census-rejected-v2`: two lanes shared the census apps' SQLite databases; Campfire answered 404 in some
  windows. Blog's ZJIT A/A there was **6.45%** (5.043 / 4.728 M Ir per operation; headline2 −4.2% vs YJIT,
  master +7.1%).

  Rerun in a quiet window (one lane, own databases): Blog ZJIT A/A **3.07%** without compilation, **25.6%** on
  total Ir (run `b` was still compiling, see the per-app table), YJIT 2.15%; headline2 **−5.9%**, master **+8.6%**.
  Round 2 also replaced the steady-state measure: v2 subtracted the compile buckets' self Ir, which leaves the
  compiler's own `malloc`, `free` and `memcpy` in the runtime buckets; the table now subtracts the inclusive Ir of
  the compile, profiling and invalidation entry points (`COMPILE_ROOTS` in `census_cg_table.rb`).

## Per-app comparison

Callgrind M Ir per iteration (ruby-bench, total including GC) or per operation (census apps, without
compilation, profiling and invalidation), runs `a` / `c` (ruby-bench) or `a` / `b` (apps):

| benchmark | build | YJIT runs | ZJIT runs | A/A YJIT, ZJIT | ZJIT vs YJIT |
| --- | --- | ---: | ---: | ---: | ---: |
| lobsters | headline2 | a 2312.6 @174, c 2314.7 @177 | a 2103.2 @186, c 2100.3 @186 | 0.09%, 0.14% | **-9.2%** |
| lobsters | master | c 2316.4 @198 ×3 | c 2473.7 @174, d 2474.7 @174 | –, 0.04% | **+6.8%** |
| railsbench | headline2 | a 4873.6 @174, c 4871.6 @174 | a 4432.5 @174, c 4421.9 @174 | 0.04%, 0.24% | **-9.1%** |
| railsbench | master | c 4863.8 @174 | c 5026.4 @174, d 5025.3 @174 | –, 0.02% | **+3.3%** |
| shipit | headline2 | a 3181.6 @192 ×2, c 3183.4 @177 | a 2845.1 @174, c 2846.6 @174 | 0.05%, 0.05% | **-10.6%** |
| shipit | master | c 3183.0 @255 ×2 | c 3637.5 @174 | –, – | **+14.3%** |

`@N` is the first measured iteration (after 150 warmup iterations and the JIT-flat windows); `×N` the number of
measured attempts. Master's ZJIT A/A is 0.02% (railsbench) and 0.04% (lobsters). Master's YJIT twins (`d`) and
shipit's ZJIT twin were stopped unfinished, so their A/A is not measured; the same harness and pins give
0.04–0.09% YJIT A/A on headline2, and master YJIT is within 0.2% of headline2 YJIT on all three. Round 1 (master `90dbced795`) measured
+3.5% / +5.5% / +18%, Z13 (`3be2b028a7`) +3.4% / +6.4% / +16.3%.

| app | build | YJIT a / b | ZJIT a / b | A/A YJIT, ZJIT | ZJIT vs YJIT | with compile | gates |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| blog | headline2 | 4.534 / 4.633 | 4.248 / 4.381 | 2.15%, 3.07% | **-5.9%** | +43.7% | yjita fail, yjitb fail, zjita fail, zjitb fail |
| blog | master | 4.535 / 4.451 | 4.894 / 4.863 | 1.87%, 0.65% | **+8.6%** | +6.1% | yjita fail, yjitb fail, zjita fail, zjitb fail |
| campfire | headline2 | 34.262 / 34.253 | 31.845 / 31.964 | 0.03%, 0.37% | **-6.9%** | -6.8% | yjita fail, yjitb fail, zjita fail, zjitb fail |
| campfire | master | 34.232 / 34.339 | 36.784 / 36.781 | 0.31%, 0.01% | **+7.3%** | +7.8% | yjita fail, yjitb fail, zjita fail, zjitb fail |
| writebook | headline2 | 82.851 / 82.742 | 74.698 / 74.661 | 0.13%, 0.05% | **-9.8%** | -9.8% | yjita fail, yjitb fail, zjita fail, zjitb fail |
| writebook | master | 82.955 / 82.790 | 91.750 / 91.821 | 0.20%, 0.08% | **+10.8%** | +11.2% | yjita fail, yjitb fail, zjita fail, zjitb fail |

`with compile` is the same comparison on total Ir. It only matters for Blog on headline2: ZJIT run `b` compiled
35 ISEQs inside its measured window (run `a`: 2); `rb_zjit_compile_iseq` alone is 75 M Ir inclusive, 43% of
that dump. Without compilation the
two ZJIT runs agree within 3.1%; with it they differ by 26%. This is warmup that the window did not finish, not
steady-state cost (compile speed: [zjit-compile-speed.md](zjit-compile-speed.md), Z6; k0kubun's adaptive
compilation, [Shopify/ruby#1031](https://github.com/Shopify/ruby/issues/1031)). Blog's operations are small
(4.5 M Ir, 20 per window), so its YJIT A/A is also 1.9–2.2%. Campfire and Writebook move by at most 0.5 points between
the two measures.

Counters per iteration after warmup (ZJIT `--zjit-stats`, YJIT `--yjit-stats`; YJIT dynamic is
`num_send_dynamic`). Headline2 dispatches 2.1–2.6× fewer sends dynamically than YJIT; master dispatches 1.5–2.0×
more:

| Benchmark | build | ZJIT sends | ZJIT dynamic | YJIT dynamic | ZJIT side exits | YJIT side exits |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| railsbench | master | 15,348,392 | 867,972 | 595,051 | 21,687 | 12,970 |
| railsbench | headline2 | 15,519,683 | 285,523 | 595,051 | 0 | 12,970 |
| lobsters | master | 7,206,289 | 682,119 | 398,424 | 9,605 | 3,605 |
| lobsters | headline2 | 7,185,143 | 126,453 | 398,425 | 1,252 | 3,605 |
| shipit | master | 14,850,097 | 1,567,643 | 798,232 | 50,223 | 7,147 |
| shipit | headline2 | 14,870,628 | 301,618 | 798,249 | 82 | 7,144 |

Master railsbench's side exits are mostly `exit_exception_handler` (21,657 per iteration); headline2 has none.

## Where headline2 still spends more than YJIT

Self Ir by bucket, ZJIT − YJIT on headline2, M per iteration (railsbench / lobsters / shipit). ZJIT's lead comes
from generic method dispatch (−192 / −129 / −234), the interpreter (−68 / −30 / −29), block invocation
(−39 / −23 / −53) and allocation (−54 / −20 / −39). Only two buckets cost more:

| Bucket | railsbench | lobsters | shipit | Main functions |
| --- | ---: | ---: | ---: | --- |
| JIT code | +3.0 | +25.6 | +52.9 | ZJIT's own code, which now does work YJIT leaves to C (inlined sends, ivar and block paths) |
| GC (marking, sweeping) | +6.6 | +10.4 | +24.3 | `rb_zjit_root_mark` (about 350k JITFrame ISEQs marked per GC), `gc_sweep_page` |

Within buckets that ZJIT wins overall, these functions cost more than YJIT's counterparts:

* **ZJIT entry** `vm_exec_zjit_func`: +38.6 / +19.8 / +40.0, against `vm_exec_with_jit` −56.3 / −31.0 / −61.4,
  so the entry path nets −17.7 / −11.2 / −21.4.
* **Generic ivar reads** `rb_zjit_getivar`, `rb_vm_getinstancevariable`, `rb_zjit_getinstancevariable_on_cache_miss`:
  up to +50 on shipit, against `rb_obj_fields`, `rb_shape_get_iv_index` and `rb_ivar_lookup` (−48). The ivar
  bucket is −20 / −20 / −27. Stats: `getivar_fallback_shape_chain_miss` 203k / 172k / 499k per iteration. Shipit's
  sites are led by `ActiveModel::AttributeRegistration::ClassMethods#attribute_types` (`querying.rb:89`) and the
  class-level ivars behind `primary_key`, `connection_specification_name` and `arel_table`; railsbench's by
  `Rack::Request::Env#get_header` (`@env`) from a dozen callers.
* **Env escape** `zjit_frame_write_stack` from `vm_make_env_each`: +8.6 on railsbench.
* **`Hash#fetch` not inlined**: 187k / 153k / 415k calls per iteration (`not_inlined_cfuncs_Hash#fetch`).
* **Lobsters side exits** (1,252 per iteration; the side-exit bucket is +0.4): `PatchPoint(MethodRedefined
  __class_attr_attribute_aliases)` in `ActiveRecord::Base.attribute_aliases` (5,176 samples at rate 20), and
  `GuardType(String)` in `ActionView::Helpers::TagHelper#content_tag_string`.

### Ownership map

| ZJIT-only cost on headline2 | Measured | Owner |
| --- | --- | --- |
| GC root marking of JITFrame ISEQs | GC +6.6 / +10.4 / +24.3 M | k0kubun, `zjit-dev`: `5cab45a617` "Mark the distinct ISEQs of JITFrames as GC roots", `4319a272fe` "Mark an ISEQ once for consecutive JITFrames and exit descriptors" (not in headline2) |
| Generic ivar reads after a shape-chain miss, class-level ivars | 172k–499k fallbacks per iteration; bucket still −20 to −27 M vs YJIT | k0kubun: `63c81707c3` "Read attr_reader ivars through an inline cache on a shape chain miss", `ff7e8adbe8` "Cache ivar indexes by shape for unspecialized ivar reads" (`zjit-dev`), `4f16d32c13` "Back ivar shape-chain misses with a per-name shape table" (`zjit-lobsters`), `61327ecd80` "Read class instance variables through the (shape, name) cache" (`zjit-headline-exp/rails`, 2026-11-21) |
| Env escape (`zjit_frame_write_stack`) | +8.6 M railsbench | k0kubun stack-map work: `91b3dbd5ea` "Add SKIP_VM_ENV_DATA and PREV_FRAME stack map opcodes" (`zjit-dev`) |
| `Hash#fetch` not inlined | 153k–415k calls per iteration | nithya4005: [Shopify/ruby#1086](https://github.com/Shopify/ruby/issues/1086), [ruby/ruby#19949](https://github.com/ruby/ruby/pull/19949) |
| `PatchPoint(MethodRedefined)` exits from `class_attribute` | lobsters 1,252 exits per iteration, +0.4 M | k0kubun: [ruby/ruby#19617](https://github.com/ruby/ruby/pull/19617) "Recompile final versions invalidated by PatchPoint", [Shopify/ruby#914](https://github.com/Shopify/ruby/issues/914) |
| `GuardType(String)` in `content_tag_string` | lobsters exit site | ours, OTS1: [ruby/ruby#19982](https://github.com/ruby/ruby/pull/19982), merged 2026-11-25 as `a17b9f22fd` (after headline2's base) |
| JIT code itself | +3 / +26 / +53 M | not a single item: it is the code that replaced the generic dispatch above, which ZJIT wins by 129–234 M |

The ivar row was checked against YJIT directly: [`repro_getivar_shapes.rb`](../../bench/upstream/zjit-gap-2/repro_getivar_shapes.rb)
reads `@env` from 5 to 8 receiver shapes (the `Rack::Request::Env#get_header` case). At 6 or more shapes ZJIT
takes the shape-chain-miss fallback, and is still 325–339 Ir per call against YJIT's 647–731. A fallback that
beats YJIT is not a gap against YJIT; k0kubun's commits above make it cheaper still.

### Census apps on headline2

Counters per operation (`script/census run --stats`, 60 warmup operations per workload, then 20 each):

| App | ZJIT sends | ZJIT dynamic | YJIT dynamic | ZJIT side exits | YJIT side exits |
| --- | ---: | ---: | ---: | ---: | ---: |
| Campfire | 66,705 | 1,605 | 2,910 | 6.8 | 38.4 |
| Writebook | 99,312 | 2,022 | 4,890 | 17.9 | 45.4 |
| Blog | 21,203 | 301 | 420 | 4.5 | 6.8 |

Self Ir by bucket in the census windows, ZJIT − YJIT, M per operation (Campfire / Writebook / Blog): method
dispatch −1.48 / −5.86 / −0.21, allocation −0.43 / −0.85 / +0.07 (Blog: the compiler's `malloc`, above),
block invocation −0.19 / −0.70 / −0.04, interpreter −0.18 / −0.57 / −0.05, and JIT code **+0.33 / +1.33 / +0.01**,
the only bucket that costs more. GC is equal (fixed heap, few GCs per window). The functions that cost more are
the ones from the ruby-bench rows: `vm_exec_zjit_func`, `rb_zjit_getivar`,
`rb_zjit_getinstancevariable_on_cache_miss`, `zjit_frame_write_stack`.

The top ZJIT fallbacks per operation are the owned items above: `getivar_fallback_shape_chain_miss` 1,541 /
3,397 / 216 and `not_inlined_cfuncs_Hash#fetch` 617 / 1,555 / 146. The other not-inlined C methods
(`MatchData#[]` 1,079 in Campfire, `Array#fetch`, `String#match?`, `Hash#key?`) have no specialized codegen
in YJIT either (`yjit/src/codegen.rs` at headline2), so they are not a gap against YJIT but speedups beyond it,
outside this round; `Array#fetch` is tenderlove's [ruby/ruby#19434](https://github.com/ruby/ruby/pull/19434).

## Differential on headline2 (Z11's method)

Each app's own suite on headline2 `f2c3f457ff`, once on the interpreter and once per ZJIT mode, outcomes compared
per test ([Z11](zjit-app-differential.md) setup: `PARALLEL_WORKERS=1`, `TZ=UTC`, `CI=1`, `--seed 41231`, Redis DB
11, apps on Rails 8.2 at the pins of [zjit-differential.md](zjit-differential.md)). The interpreter ran twice;
a test that differs between those two runs would count as flaky (none did). Every difference was rerun alone in
each mode and at the default threshold.

ZJIT modes (all with `--zjit`): `z1` threshold 1; `z1ni` threshold 1, `--zjit-inline-threshold=0`; `z2`
threshold 2, `--zjit-num-profiles=1`; `zinl` threshold 1, `--zjit-inline-threshold=500`; `zinb` as `zinl` plus
`--zjit-inline-budget=2000`; `zinv` threshold 2, 1 profile, `--zjit-num-exits-until-invalidate=1`; `zc`
threshold 3, 2 profiles, `GC.auto_compact = true`; `zmem` threshold 1, `--zjit-mem-size=4`; `z30` the default
threshold.

| App | Tests | Failing in both | Modes | Differ |
| --- | ---: | --- | --- | ---: |
| Campfire (`af4dd9f`) | 634 | 0 | z1, z1ni, z2, z30, zc, zinl, zinb, zinv, zmem | 0, except the flake below |
| Writebook (`7478e2c`) | 310 | 1 E (`URI::Generic#request_uri`, Rails main) | z1, z2, z30, zc (twice), zinl, zinv | 0 |
| Fizzy (`77eada1`) | 1,787 | 4 E, the same tests in every run | z1, z2, z30 | 0 |
| Ruby btest | 2,149 | 0 | `--zjit-call-threshold=1` | 0 |
| Ruby test-all | 39,562 (ZJIT) / 39,560 (interpreter) | 0 | `--zjit --zjit-call-threshold=1`, `-j4` | 0 |

**Campfire: the known timing flake.** `SqliteWalCheckpointTest` (one test in `z2`, two in `zinl` and `zinb`):
"condition not met within 1s". The test spawns `RbConfig.ruby` as a lock holder that inherits `RUBYOPT` and
waits 1 s for it. Alone, both pass on the interpreter, in `z2` and at the default threshold; in `zinl` they fail
3 of 3 at the 1 s deadline and pass 2 of 2 with the deadline at 10 s. A child that compiles everything with a
500-instruction inline threshold starts slower; this is the same flake as Z11's, not a divergence.

**Probes.** On the interpreter and with ZJIT at threshold 1, 2 and the default, identical output:
[`probes.rb`](../../bench/upstream/ruby19659/probes.rb) (51 yield shapes),
[`probes-fable.rb`](../../bench/upstream/ruby19659/probes-fable.rb) (37),
[`probes-astra.rb`](../../bench/upstream/ruby19659/probes-astra.rb) (13) and ZS1's
[`zs1_probe.rb`](../../bench/upstream/zs1_probe.rb). Two differences are by construction: `probes-fable.rb`
prints a stats line (`direct=… invokeblock_not_specialized=…`) only when ZJIT is enabled, and `zs1_probe.rb`
prints `Thread` object addresses.

**Not run here:** the eight Z11 apps that need PostgreSQL or MySQL services and their own setup (Sure, Mastodon,
Loomio, CASA, Hackatime, CodeTriage, Discourse) and Lobsters, whose suite fails before the first example on Rails
main (`before(:suite)`: `User has no attribute prefers_color_scheme`, activerecord-typedstore 1.6.0), on the
interpreter as well. The master rerun of 2026-11-18 covered the same three apps.

## Reproduce

```sh
# ruby-bench Callgrind cohort, one lane per job list (lock directories let several lanes share it)
bench/upstream/zjit-gap-2/cg_queue.sh ~/z2/cg h2:zjit:railsbench:a h2:yjit:railsbench:a ...
ruby bench/upstream/zjit-gap-2/rb_cg_table.rb ~/z2/cg
# census apps, per build and app, with A/A
CGEXT=~/w/cgext-h2 script/census run --label z2cg-h2-campfire --aa --corpus censusz2 --ruby ~/rubies/h2 \
  --modes zjit,yjit --apps campfire --callgrind="--zjit-exec-mem-size=512 --zjit-mem-size=1024" --out ~/z2/census
ruby bench/upstream/zjit-gap-2/census_cg_table.rb ~/z2/census
# attribution
ruby bench/upstream/zjit_yjit_gap_report.rb ~/z2/cg/railsbench/h2 totals buckets functions
```

Environment for the census runs: `RUBY_GC_HEAP_INIT_BYTES=33554432 CENSUS_WARMUP=60 CENSUS_CG_CYCLES=2
CENSUS_CG_MIN_WINDOWS=15 CENSUS_CG_MAX_WINDOWS=15 CENSUS_CG_ATTEMPTS=1`, one lane at a time (the census copies
share their databases).
