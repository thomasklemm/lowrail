# ZJIT gap census on Rails (bet Z1)

Where is ZJIT slower than YJIT on Rails, and which gaps does nobody own yet? This is the ZJIT team's goal for
Ruby 4.1 (k0kubun on [ruby#19671](https://github.com/ruby/ruby/pull/19671#issuecomment-6596469897); see
[DECISIONS.md](../DECISIONS.md), 2026-11-03). It remeasures the ZJIT part of the
[JIT parity census](jit-parity-census.md#exit-and-fallback-reasons-task-2) on current master and checks ownership
for each item.

**Result.** ZJIT executes 3.5% (railsbench), 5.5% (lobsters) and 18% (shipit) more instructions per iteration than
YJIT on the same master build. Almost every gap behind that is already owned: by open ruby/ruby PRs, by
Shopify/ruby issues, or by the 83-commit ZJIT lobsters branch that k0kubun is upstreaming
([Shopify/ruby#1039](https://github.com/Shopify/ruby/issues/1039)). Polymorphism (getivar, polymorphic sends) is
the largest reason by far and is design-level work; it is named here and measured by L2 (Z3).

One exact, unowned candidate was built: **ZJIT does not inline `String#<<` when the argument profiles as String plus
a String subclass** (Action View's `SafeBuffer`, Arel's `SqlLiteral`), on
[`thomasklemm/zjit-poly-likely-a`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-poly-likely-a) at
[`8b8d24ff0d`](https://github.com/thomasklemm/ruby/commit/8b8d24ff0d626543c122ffa3d2aa7321e4960a5f). It removes
every non-inlined `String#<<` call but **does not pay**: −0.26% Ir on lobsters, +0.13% on railsbench and +0.20% on
shipit (GC excluded, A/A ≤ 0.19%). It is **not submitted**. No second candidate cleared the bar, so Z1 proposes
**no PR**.

## Pins and method

* **Ruby:** master [`90dbced795`](https://github.com/ruby/ruby/commit/90dbced795) (2026-11-03), release build,
  `--enable-zjit --enable-yjit`. Interpreter, YJIT and ZJIT all use this one build.
* **ruby-bench** [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2): railsbench, lobsters, shipit.
  Local harnesses, copied into `harness/` and selected with `HARNESS=`:
  * [`ruby_bench_jit_stats.rb`](../../bench/upstream/ruby_bench_jit_stats.rb): 15 warmup iterations,
    `reset_stats!`, every counter over 10 iterations (`--zjit-stats-quiet` / `--yjit-stats=quiet`).
  * [`ruby_bench_callgrind.rb`](../../bench/upstream/ruby_bench_callgrind.rb): Callgrind client requests
    ([`bench/callgrind.c`](../../bench/callgrind.c)), 15 warmup iterations, then an empty window and a
    3-iteration window in the same process; Ir per iteration is their difference / 3. `CG_NO_GC=1` stops counting
    inside GC segments. Valgrind 3.19 with `--smc-check=all-non-file` (needed for JIT code). Each build and mode ran
    twice (A/A).
  * [`ruby_bench_allocs.rb`](../../bench/upstream/ruby_bench_allocs.rb) (objects per iteration, two rounds) and
    [`ruby_bench_alloc_sites.rb`](../../bench/upstream/ruby_bench_alloc_sites.rb) (objects by line, ZJIT vs
    interpreter, two rounds).
  * ZJIT exit and fallback sites: `--zjit-trace-exits --zjit-trace-exits-sample-rate=20
    --zjit-trace-fallbacks-sample-rate=20`, summarized by [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb).
* **Apps:** Fizzy (SQLite), Lobsters and Campfire through `script/census` on Rails main
  [`b10c3acfe9`](https://github.com/rails/rails/commit/b10c3acfe9), corpus `censusz1`
  (`setup --rails main --ruby ~/rubies/m2 --corpus censusz1`; Lobsters and Campfire with the
  `jit-parity-census` overlays because stackprof 0.2.27 does not build on master). `script/census run --stats`
  (new, below) writes JIT counters per operation: 50 warmup operations per workload, `reset_stats!`, 20 operations
  each. `--stats="--zjit-trace-…"` adds traces. Allocations use `run --aa --modes interp,zjit`.
* Summary tables: [`zjit_gap_table.rb`](../../bench/upstream/zjit_gap_table.rb). Callgrind function diffs:
  [`callgrind_fn_diff.rb`](../../bench/upstream/callgrind_fn_diff.rb).

## Headline: instructions, sends and exits

Callgrind, Ir per iteration (millions), total including GC, A/A runs `a / b`:

| Benchmark | interpreter | YJIT | ZJIT | ZJIT vs YJIT |
| --- | ---: | ---: | ---: | ---: |
| railsbench | 7,388.5 / 7,386.9 | 4,761.6 / 4,760.1 | 4,932.7 / 4,924.4 | **+3.5%** |
| lobsters | 4,352.6 / 4,349.6 | 3,098.4 / 3,098.7 | 3,270.2 / 3,265.3 | **+5.5%** |
| shipit | 6,181.6 / 6,170.7 | 3,380.7 / 3,384.1 | 3,956.1 / 4,039.7 | **+18%** |

ZJIT's own A/A is 0.2% on railsbench and lobsters and 2.1% on shipit: shipit has a phase change in its first
iterations (`require "useragent"` invalidating constants; see #19617 below), so its ZJIT runs differ in what was
recompiled.

Counters per iteration (ZJIT `--zjit-stats`, YJIT `--yjit-stats`; YJIT dynamic = `num_send_dynamic`):

| Benchmark | ZJIT sends | ZJIT dynamic | YJIT dynamic | ZJIT side exits | YJIT side exits | ZJIT ISEQs compiled |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| railsbench | 15,190,349 | 1,065,951 | 593,078 | 23,710 | 12,970 | 0.1 |
| lobsters | 7,115,548 | 750,514 | 397,502 | 12,650 | 3,614 | 2.6 |
| shipit | 14,620,947 | 1,709,365 | 780,448 | 49,582 | 7,143 | 0.4 |

Census apps, per operation:

| App | ZJIT sends | ZJIT dynamic | YJIT dynamic | ZJIT side exits | YJIT side exits | ZJIT ISEQs compiled |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Fizzy | 110,267 | 16,224 | 10,022 | 1,092 (623 at 128 MB, below) | 79 | 0.0 |
| Lobsters | 155,397 | 16,079 | 7,038 | 516 | 73 | 0.4 |
| Campfire | 66,348 | 7,650 | 2,914 | 206 | 22 | 1.9 |

ZJIT dispatches 1.6–2.6× more sends dynamically than YJIT and side-exits 4–10× more often.

**Recompiles and invalidations.** After warmup ZJIT compiles 0–2.6 ISEQs per iteration or operation, and
`invalidation_time_ns` is 0 in every measured window. No site recompiles repeatedly in steady state;
`IsolatedExecutionState.[]` shows up as a getivar fallback (polymorphic receiver), not as a recompile. The
steady-state cost of invalidation is the other way round: a *final* version that a patch point invalidated keeps
side-exiting (the constant exits below).

**Where the instructions go** (Callgrind self Ir, ZJIT − YJIT per iteration, railsbench +171 M):
JIT code +80 M; interpreter re-entry from fallbacks and exits (`rb_vm_exec`) +38 M; generic `yield`
(`vm_invoke_iseq_block`, `rb_vm_invokeblock`) +38 M; `zjit_materialize_frames` +13 M; GC marking of ZJIT roots
(`gc_mark`, `rb_gc_mark_movable`) +18 M; generic sends (`rb_vm_send`, `rb_vm_opt_send_without_block`) +16 M;
generic ivar reads (`rb_ivar_lookup`, `rb_shape_get_iv_index`) +18 M; `rb_ec_stack_check` +9 M. Shipit (+575 M)
has the same shape, larger: `rb_vm_exec` +61 M, `rb_ivar_lookup` +33 M, `setup_parameters_complex` +30 M. Lobsters
additionally shows `rb_str_concat` and coderange scans, which is the candidate below.

## Side exits by reason

Per iteration (ruby-bench) or operation (apps), with the top sites from the traces:

| Reason | railsbench | lobsters | shipit | Fizzy / Lobsters / Campfire | Top Rails sites | Owner |
| --- | ---: | ---: | ---: | --- | --- | --- |
| `exception_handler` | 21,657 | 9,117 | 9,757 | 51 / 132 / 16 | `rescue`/`ensure` in Rack and Action Pack middleware, every request | [#18759](https://github.com/ruby/ruby/pull/18759) (rafaelfranca, open): compile exception handlers |
| `patchpoint_stable_constant_names` | 0 | 0 | 38,498 | 354 / 0 / 82 | shipit `ConnectionHandling#connection_specification_name` (`Base`); Fizzy/Campfire `WhereClause.empty`, `FromClause.empty` (`EMPTY`) | [#19617](https://github.com/ruby/ruby/pull/19617) (k0kubun, open): recompile final versions invalidated by a patch point. Shipit is its motivating case; the Fizzy sites have the same signature (exit on every call after warmup, unchanged at 128 MB) but were not run against #19617 |
| `guard_type_failure` | 0 | 2,800 | 1,264 | 144 / 330 / 30 | `LazyAttributeSet#fetch_value!`, `Core#init_internals`, `Association#scope`, `instantiate_instance_of` | polymorphism (Z3) |
| `unhandled_block_arg`, `guard_super_method_entry` | 2,052 | 341 | 57 | 60 / 15 / 68 | `AssociationRoute::Cache#fetch_or_store` (`super` in a method called with a block), Fizzy `Uuid#serialize` | k0kubun's lobsters branch, `7b373cdb14` "Stop side-exiting forever at unstable super sites" (Shopify/ruby#1039 row 45) |
| `compile_error` (`out_of_memory`) | 0 | 0 | 0 | 480 / 0 / 0 | Fizzy only | a `--zjit-stats` artifact: with stats, Fizzy fills the 64 MiB code region; without stats it uses 52.9 MB (`code_region_bytes`), and at `--zjit-exec-mem-size=128` these exits are gone. Not a production gap |

## Send fallbacks by reason

Per iteration on ruby-bench (ZJIT, `send_fallback_*`), with the census apps' order in brackets:

| Reason | railsbench | lobsters | shipit | Top sites | Owner |
| --- | ---: | ---: | ---: | --- | --- |
| getivar fallback (`no_profile_missing_ic` / `no_side_exits`) | 295,020 | 473,962 | 1,247,652 | `attribute_types`, `IsolatedExecutionState.[]`, `Composite#<<`, `_read_attribute`, `LazyAttributeSet#fetch_value`, `Attribute#hash` | polymorphism (Z3): [#19443](https://github.com/ruby/ruby/pull/19443) (tekknolagi), [#19558](https://github.com/ruby/ruby/pull/19558) (ours), Shopify/ruby#1039 rows 5, 6, 10, 52 |
| `send_polymorphic_fallback` | 26,500 | 246,908 | 682,000 | `Querying#_load_from_sql`, `BasicObject#!=` (6 of 6), `Type::Value#hash` | polymorphism (Z3): [Shopify/ruby#776](https://github.com/Shopify/ruby/issues/776), #19443 |
| `invokeblock_not_specialized` | 329,725 | 153,581 | 359,056 | `Array#each`, `#map`, `#select` blocks that are not simple, have another arity, or `break` | [#19659](https://github.com/ruby/ruby/pull/19659) (ours, surplus args); Shopify/ruby#1039 rows 29–33, 40, 55; [Shopify/ruby#1093](https://github.com/Shopify/ruby/issues/1093) |
| `send_megamorphic` | 189,766 | 99,676 | 80,978 | `Logger#level`, `LoggerThreadSafeLevel#local_level` (5 of 6) | Shopify/ruby#1039 rows 24, 25, 27, 35, 38 |
| `send_block_arg_not_nil` | 120,000 | 95,131 | 201,311 | `_read_attribute`, `MonitorMixin#mon_synchronize` (6 of 6) | [Shopify/ruby#1014](https://github.com/Shopify/ruby/issues/1014); #19484 merged at `13c3f56bb8`; Shopify/ruby#1039 row 7 |
| `one_or_more_complex_arg_pass` | 104,508 | 41,377 | 82,761 | `Env#fetch_header(&block)`, `resolve_attribute_name`, `Core.relation`, `Arel.sql(**)` | Shopify/ruby#1039 rows 36, 42, 43 (`**rest`, `&blk` to C, `**`) |
| `sendforward_not_specialized` | 75,134 | 31,883 | 100,847 | `WhereClause#empty?`, `ScopeRegistry.current_scope` | [#18326](https://github.com/ruby/ruby/pull/18326) (nozomemein, draft); Shopify/ruby#1039 rows 20, 22 |
| `Kernel#send` (`method_type_optimized`) | 41,673 | 25,774 | 70,380 | TZInfo `Timestamp.new!` (6 of 6), Arel `Visitor#visit`, AMS serializers | [#19583](https://github.com/ruby/ruby/pull/19583) (tekknolagi, draft); profiled names: Shopify/ruby#1039 row 11 ([zjit-send](zjit-send.md)) |
| `need_permission` | 54,836 | 15,959 | 30,469 | `InheritableOptions#initialize`, `WhereClause#merge` | [#19483](https://github.com/ruby/ruby/pull/19483) (ours) |
| super complex args / from block | 45,252 | 5,502 | 10,034 | `SafeInitialization#new`, `QueryCache#select_all` | Shopify/ruby#1039 rows 45, 46 (partly) |

## Allocations beyond the interpreter

ruby-bench, median objects per iteration over two rounds:

| | interpreter | ZJIT | YJIT |
| --- | ---: | ---: | ---: |
| railsbench | 1,729,918 | 1,734,061 (+0.24%) | 1,737,271 |
| lobsters | 645,546 | 647,231 (+0.26%) | 650,062 |
| shipit | 1,133,864 | 1,137,700 (+0.34%) | 1,150,011 |

ZJIT allocates less than YJIT everywhere. By line, most of the remainder is attribution: `Array#map`/`#select`
are Ruby code under ZJIT (`<internal:array>:289/315`), so their result Arrays move away from the calling line, with
matching negatives elsewhere. The real extra objects are owned:

* `URI.for(*split(uri), self)` (`rfc3986_parser.rb:135`, +2,000/itr on railsbench, +37/op on two apps):
  [Shopify/ruby#1095](https://github.com/Shopify/ruby/issues/1095) / [#1097](https://github.com/Shopify/ruby/issues/1097).
* Integer interpolation (`"t#{i}_r#{j}"` in `JoinDependency`, +2,350/itr shipit; Lobsters `time_ago_in_words`):
  [Shopify/ruby#1091](https://github.com/Shopify/ruby/issues/1091).
* `Arel::Collectors::SQLString.new` in `AbstractAdapter#collector` (+817 lobsters, +1,826 shipit): the `(*)`
  rest Array for `initialize(*) = super`; [#19655](https://github.com/ruby/ruby/pull/19655) (ours).

The census apps agree (ZJIT − interpreter, median workload +16.9 objects, 28 of 34 workloads ≥ +1), led by the same
`URI.for` line.

## Candidate (built, not submitted): inline `String#<<` for String-subclass arguments

`inline_string_append` turns `String#<<` into `StringAppend` when `likely_a(other, String)`. `likely_a` only
accepted monomorphic or skewed profiles. A buffer that receives plain Strings and `SafeBuffer`s, or Strings and
`SqlLiteral`s, profiles as polymorphic, so the call stays a `CCallWithFrame` of `String#<<` (`rb_str_concat`,
which also rescans the argument's coderange). Both profiled types pass `GuardType String`, and `StringAppend`
handles any `T_STRING` argument, as `vm_opt_ltlt` does. YJIT checks `RB_TYPE_P(arg, T_STRING)` and inlines these
sites.

Sites: Action View `OutputBuffer#<<` and `#safe_concat` (`buffers.rb:45/57`), Arel `PlainString#<<`
(`plain_string.rb:15`), Erubi `add_code`.

**Change** ([`8b8d24ff0d`](https://github.com/thomasklemm/ruby/commit/8b8d24ff0d626543c122ffa3d2aa7321e4960a5f),
`hir.rs` +9/−4): `likely_a` also returns true for a polymorphic profile whose every type is a subtype of the
requested type. The guards that follow are unchanged (`coerce_to` emits `GuardType ty` with recompile). The other
31 callers of `likely_a` get the same rule. No existing HIR snapshot changes, and on the benchmarks only
`String#<<` (and 1,536 `Class#superclass` calls per lobsters iteration) move.

**Counters** (per iteration, master → branch):

| | railsbench | lobsters | shipit |
| --- | ---: | ---: | ---: |
| `String#<<` not inlined | 34,815 → 0 | 58,685 → 0 | 8,656 → 0 |
| side exits | 23,710 → 23,709 | 12,650 → 12,650 | 49,582 → 49,581 |

**Callgrind, GC-excluded Ir per iteration (millions), A/A runs:**

| Benchmark | master a / b | branch a / b | branch vs master (means) |
| --- | ---: | ---: | ---: |
| railsbench | 4,685.9 / 4,686.0 | 4,696.4 / 4,687.8 | +0.13% |
| lobsters | 3,201.5 / 3,205.2 | 3,194.7 / 3,195.4 | −0.26% |
| shipit | 3,657.6 / 3,660.5 | 3,666.7 / 3,665.7 | +0.20% |

A/A: master 0.002% / 0.12% / 0.08%, branch 0.19% / 0.02% / 0.03%. The total-Ir runs (GC included) agree: +0.1%,
+0.5% and noise.

**Why it does not pay.** The function diff (b runs) shows the intended saving: `rb_str_concat`,
`rb_str_buf_append`, `search_nonascii` and `coderange_scan` fall by 3.7 M on railsbench and 1.0 M on shipit. But
JIT code grows by 7.0 M and 9.2 M per iteration, more than the C savings. That is about 200 instructions of
JIT code per newly inlined call on railsbench. A plausible cause, not verified, is the inline `StringAppend`
sequence (type guard plus the HIR encoding check from Shopify/ruby#1051) and the larger compiled blocks around it.
Lobsters, where `String#<<` is the most frequent (58,685/itr), is the only win, and it is −0.26% against a 0.12%
A/A. Under [DECISIONS.md](../DECISIONS.md) that is neither a consistent nor a headline effect, so the branch stays
on the fork as a lead. It becomes worth submitting only if `StringAppend` codegen gets cheaper.

**Tests:**

* `hir::opt_tests::test_optimize_string_append_polymorphic_string_arg` (HIR snapshot, call threshold 3 so both
  types are profiled): fails on master, which emits `CCallWithFrame v31, :String#<<`, and passes on the branch with
  `GuardType v13, String` + `StringAppend`.
* `codegen::tests::test_string_append_polymorphic_string_arg` (no side exits, result and encoding) and
  `…_then_other` (a codepoint and a Symbol after compilation fail the guard and keep interpreter behavior,
  including `TypeError`). These are behavior guards and pass on master too.
* `make zjit-test` (cargo-nextest 0.9.151): 1,942 run, 1,941 passed. The one failure,
  `test_profile_frames_during_direct_jit_to_jit_entry`, is a SIGPROF sampling test that failed under parallel load
  and passes in isolation on the branch (3 of 3) and on master.
* `make btest RUN_OPTS=--zjit-call-threshold=1`: PASS all 2,141 tests.

**Coverage check:** no ruby/ruby PR or Shopify/ruby issue for polymorphic `String#<<` arguments or for `likely_a`
(searched `ZJIT String#<<`, `StringAppend`, `string append`, `likely_a`, `polymorphic argument`; closed
Shopify/ruby#1051 moved the encoding check into HIR). k0kubun's lobsters branch has no commit touching
`String#<<` or `likely_a`. #19443 (polymorphic class + monomorphic shape) splits *receiver* dispatch, not argument
type checks.

### PR draft (held, kept for a later round)

**ZJIT: Treat polymorphic profiles as likely a type when every type is one**

> `likely_a()` only accepted monomorphic and skewed profiles. A `String#<<` site whose argument is a String or a
> String subclass, such as Action View's `OutputBuffer#safe_concat` (String and `SafeBuffer`) and Arel's
> `PlainString#<<` (String and `SqlLiteral`), profiles as polymorphic and falls back to a `CCallWithFrame` of
> `String#<<`, although `GuardType String` covers both types and `StringAppend` handles any `T_STRING`, like
> `vm_opt_ltlt`.
>
> This accepts a polymorphic profile when every profiled type is a subtype of the requested type.
>
> | per iteration | railsbench | lobsters | shipit |
> | --- | ---: | ---: | ---: |
> | `String#<<` not inlined | 34,815 → 0 | 58,685 → 0 | 8,656 → 0 |
> | Ir, GC excluded | +0.13% | −0.26% | +0.20% |
>
> (Held: the last row is why.)

## Not done or not claimed

* No wall-time claim. Instruction counts only; wall time on these orbs swings by several percent in A/A.
* Polymorphism (classes and shapes per site) is Z3's measurement; the sites are named, not measured, here.
* Exception-handler exits, `Kernel#send`, sendforward, block args, megamorphic sends, complex arguments and
  final-version recompiles are owned (tables above); nothing was built for them.
* Kernel#instance_of?, String#+@ and String#dup have YJIT codegen but no ZJIT inline. Each is ≤ 0.02% of Ir
  (≤ 11k calls per iteration), below the bar.
* No receipts are committed. The stats JSONs, traces and Callgrind dumps stay on the orb (`~/z1`) and under
  `.lowrail/private/census/z1*`.

## Tooling added

* `script/census run --stats[=FLAGS]` runs `harness.rb stats`: JIT counters per operation after warmup, with
  extra ruby flags for traces. `CENSUS_DEFAULT_COUNTERS=1` runs ZJIT without `--zjit-stats` and keeps only the
  default counters (memory, compiled ISEQs).
* `jit_parity_fxt.rb --categories compile,invalidation` counts `--zjit-trace-compiles` and
  `--zjit-trace-invalidation` events. Duration-end events are skipped.
