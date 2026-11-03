# ZJIT stats: correctness and attribution (bet Z8)

Bet Z8 from the [shortlist](zjit-shortlist.md) (item 7). It has two parts:

1. The `IncrCounter` double count across optimize iterations that nirvdrum reported in Shopify/ruby#995. Our
   numbers in Shopify/ruby#1099 rest on these counters, so this part is checked first.
2. Per-ISEQ attribution of stats, Shopify/ruby#746. This part is design only.

Source read on ruby/ruby master `0c404b09a0`. The runtime checks ran on the `90dbced795` build behind #1099
(probe build) and on `2bc6f9a60e`, with identical counts.

## 1. The `IncrCounter` double count (#995) is fixed on master

**Claim.** In June 2026, nirvdrum [wrote in #995](https://github.com/Shopify/ruby/issues/995) that each optimize
iteration ran `optimize_getivar` again and pushed another `IncrCounter`. With the inliner on, his A/B `read`
example therefore reported 2M dynamic ivar reads for 1M real reads. He suspected the same problem elsewhere.
Nobody filed it separately.

**What happened since.** Both causes are fixed on master:

* **getivar:** `optimize_getivar` is gone (`4949309e70` "ZJIT: Remove optimize_getivar", Max Bernstein,
  2026-06-23). Getivar fallback counters are now emitted once in two places: when HIR is built
  (`dispatch_getivar`), and in `type_specialize` only on the attr_reader path that replaces the `Send`.
  `type_specialize` doesn't revisit the replacement `GetIvar`.
* **sends:** [ruby/ruby#19485](https://github.com/ruby/ruby/pull/19485) (ours, merged 2026-10-29) records each
  send's counters in `send_counters` and drops them before a send that is still dynamic is retried. It covers
  argument features, caller-splat profiles, send/super fallback contexts and unannotated C methods.

**Reproduction.**

* The #19485 repro prints `[18, 18, 9]` on `1c29235c29`, which predates #19485, and `[9, 9, 9]` on master.
* nirvdrum's A/B `read` example has no getivar fallbacks left on master, because polymorphic getivar is
  specialized now.
* [`bench/upstream/zjit_stats_inline_counts.rb`](../../bench/upstream/zjit_stats_inline_counts.rb) runs a
  4-deep inline chain. The innermost callee does a kwrest send and a shape-polymorphic attr_reader. Every
  fallback counter reads exactly 1.00 per call, both with inlining (4.00 inlines per call) and without:

| counter per call (100k calls) | `--zjit-inline-threshold=0` | `=30` (default) |
|---|---|---|
| `complex_arg_pass_param_kwrest` | 1.00 | 1.00 |
| `send_direct_fallback_context_send` | 1.00 | 1.00 |
| `getivar_fallback_no_profile_missing_ic` | 1.00 | 1.00 |
| `inline_iseq_optimized_send_count` | – | 4.00 |

**Audit.** I checked every remaining `IncrCounter`/`IncrCounterPtr` emitter in `type_specialize`, the inliner,
`convert_no_profile_sends` and `eliminate_empty_inline_frames`. Each one either is tracked in `send_counters`
(`count_send`, `count_complex_call_features`, `count_caller_splat_profile`, `count_not_annotated_cfunc`,
`SendDirectFailure::record`), or is emitted only on the path that replaces the visited instruction:

* `caller_splat_optimized`;
* the attr_reader/attr_writer counters;
* `count_not_inlined_cfunc`;
* `inline_cfunc_optimized_send_count`;
* `inline_iseq_optimized_send_count`;
* `empty_inline_frame_count`.

In the second group, the replacement is a different instruction kind, so a later iteration can't emit the
counter again. The `send_fallback_*` and exit counters are emitted in codegen, once per instruction.

**Cross-check on Rails.** The polymorphism probe (`wip/zjit-poly-probe`) calls into C at every executed getivar,
send and invokeblock fallback, independently of `IncrCounter`. A duplicated `IncrCounter` would push `--zjit-stats`
above the probe's count. I compared the probe's 10-iteration totals with a separate stats-only run
(`receipts/np5-*.stats`):

| counter (10 itrs) | railsbench probe / stats | lobsters probe / stats | shipit probe / stats |
|---|---|---|---|
| `getivar_fallback_no_profile_missing_ic` | 2,210,980 / 2,210,980 | 3,203,079 / 3,203,079 | 8,368,571 / 8,368,569 |
| `getivar_fallback_no_side_exits` | 739,220 / 739,220 | 1,535,896 / 1,535,836 | 4,107,936 / 4,107,937 |
| `send_polymorphic_fallback` | 265,000 / 265,000 | 2,469,168 / 2,469,162 | 6,632,271 / 6,632,272 |
| `send_megamorphic` | 1,897,660 / 1,897,660 | 996,854 / 996,861 | 1,112,314 / 1,112,314 |
| invokeblock (not_specialized + polymorphic_miss) | 3,410,130 / 3,410,120 | 1,664,530 / 1,664,518 | 3,995,326 / 3,995,313 |

The largest difference is 60 in 1.5M (0.004%), and the differences go both ways. A double count would
double the stats side. Lobsters and shipit are not bit-deterministic across runs.

**Effect on #1099.** None of the counters we published in #1099 is double-counted. One caveat that is not a
double count: on shipit, the *split* of invokeblock fallbacks between `not_specialized` and `polymorphic_miss`
varies between runs, while the total stays fixed. The probe run we published has 301k + 98k per iteration; the
stats-only run has 381k + 18.6k. Which blocks get specialized depends on compile order. #1099's
`invokeblock_not_specialized` figure for shipit (301k) should be read as "400k invokeblock fallbacks, split
varies".

**No fix needed.** There is nothing left to fix, so no fork branch was cut. The #19485 runtime regression test
covers the send half, and the getivar half can't recur structurally.

### Draft comment for Shopify/ruby#995 (not posted)

> The `IncrCounter` double count across optimize iterations (nirvdrum's comment above) no longer reproduces on
> master (0c404b09a0). The getivar half went away with the removal of `optimize_getivar` (4949309e70), and the
> send half was fixed in ruby/ruby#19485: its repro prints `[18, 18, 9]` before and `[9, 9, 9]` after. A
> 4-deep inline chain with a kwrest send and a shape-polymorphic attr_reader in the innermost callee now
> reports exactly 1.00 fallback per call for each counter, with or without inlining.
>
> As a cross-check on Rails, I counted executed getivar/send/invokeblock fallbacks with a probe that calls into
> C at each fallback, independently of `IncrCounter`. On railsbench, lobsters and shipit (10 iterations each),
> the `--zjit-stats` counters match the probe within 0.004% (railsbench exactly: 2,210,980
> `getivar_fallback_no_profile_missing_ic`, 739,220 `no_side_exits`, 1,897,660 `send_megamorphic`). The
> remaining `IncrCounter` emitters in `type_specialize` are either tracked in `send_counters` or emitted only
> where the instruction is replaced, so I think this item can be ticked off.

## 2. Per-ISEQ attribution (#746): what exists, and the smallest useful version

**Thread.** tekknolagi opened #746 in 2025-09: "It's useful to know which methods are side-exiting, having large
numbers of dynamic sends". After the Perfetto tracer landed, k0kubun closed it on 2026-04-08 ("I think the
perfetto tracer solved this"). tekknolagi reopened it the same day: "It only does exits and patching stuff. I
still think it would be neat to have e.g. 'this method has 1MM memory loads' or 'this method does a lot of
writing to parent frame'". It has no assignee.

**What exists on master:**

| tool | what it records | per event |
|---|---|---|
| `--zjit-trace-exits[=counter]` | side exits, Perfetto/Fuchsia events | full Ruby backtrace |
| `--zjit-trace-fallbacks[-sample-rate=n]` ([#17896](https://github.com/ruby/ruby/pull/17896)) | send/invokeblock fallbacks with reason; getivar/setivar as just `"getivar"`/`"setivar"` | full Ruby backtrace |
| `--zjit-trace-compiles`, `--zjit-trace-invalidation` | compile phases, invalidations | – |
| `iseq_calls_count_<iseq>` (`--zjit-stats`) | JIT entries per ISEQ | one `inc` |
| `not_inlined_cfuncs_*`, `not_annotated_cfuncs_*`, `ccall_*` | per C method | one `inc` |
| XrXr's `Shopify:perfetto-trace-fallbacks` (shown in #995) | interpreter/JIT duration slices around fallbacks | unmerged; 2 commits, 3,842 behind master |

**What's missing:** an aggregate table of "counter X, by ISEQ". The trace tools record one event with a backtrace
per occurrence. At Rails rates that's expensive. On railsbench (master `2bc6f9a60e`, 10 warmup + 10 measured
iterations, single runs on an orb, so the times are rough):

| mode | measured itr avg | whole run | trace |
|---|---|---|---|
| `--zjit` | 1,547 ms | 41 s | – |
| `--zjit --zjit-stats-quiet` | 2,368 ms | 52 s | – |
| `--zjit-trace-fallbacks` | not reached | killed after 457 s, mid-run | 788 MB at kill |
| `--zjit-trace-fallbacks-sample-rate=100` | 3,272 ms | 71 s | 37 MB |

Even with sampling, the trace still has to be post-processed in SQL. It also doesn't cover:

* the HIR-side `IncrCounter` reasons (`getivar_fallback_no_profile_missing_ic` vs `no_side_exits`,
  `complex_arg_pass_*`);
* tekknolagi's code-shape counters (memory loads, parent-frame writes).

**Why per-ISEQ helps:** the fallbacks have a long tail. From our probe data, aggregated by ISEQ with
[`zjit_stats_iseq_concentration.rb`](../../bench/upstream/zjit_stats_iseq_concentration.rb):

| 10 itrs | railsbench | lobsters | shipit |
|---|---|---|---|
| getivar fallbacks: ISEQs / top-10 share | 54 / 58% | 638 / 41% | 343 / 46% |
| poly+mega send fallbacks: ISEQs / top-10 share | 29 / 79% | 692 / 30% | 520 / 43% |
| invokeblock fallbacks: ISEQs / top-10 share | 22 / 94% | 37 / 97% | 28 / 98% |
| top getivar ISEQ | `cookies.rb:537 request` (12%) | `read.rb:39 _read_attribute` (8%) | `attribute_registration.rb:38 attribute_types` (10%) |

Global counters say *what* happens. On lobsters and shipit, the *where* is spread over hundreds of methods, and
today the only way to see it is a trace or a custom probe.

**Smallest useful version (sketch):**

* **Flag:** `--zjit-stats-iseq`. It implies `--zjit-stats`, and nothing changes when it is off.
* **Cells:** a per-(ISEQ, `Counter`) `u64` cell, stored like the existing `iseq_calls_count` pointers (a map in
  `ZJITState` from the location string to `Box<u64>`). The location string is the key so that moved or freed
  ISEQs stay safe and the output stays readable. Each counted event does one extra `inc [cell]`, with no C
  call and no backtrace.
* **Attribution:** to the FrameState's ISEQ, which is the callee's for inlined code. This needs no new IR:
  * Send/invokeblock/invokesuper fallbacks: `gen_incr_send_fallback_counter` already has the state.
  * Side exits: the exit counter increment in the side-exit path has the exit's FrameState.
  * HIR `IncrCounter`: `Function::count(block, counter)` grows a `state` argument at its 28 call sites. They all
    have one, and it is the insn being specialized. With the flag on, it also pushes an `IncrCounterPtr` to the
    (ISEQ, counter) cell.
  * Counters on stateless instructions (a future "memory loads" counter on `LoadField`) fall back to the
    compiled function's ISEQ. Per-inline-frame attribution for those can come later.
* **Output:** `RubyVM::ZJIT.stats(:iseq)` returns `{ "label@path:line" => { counter => n } }`. The printed
  `--zjit-stats` gains "Top 20 ISEQs" sections for fallbacks and exits, like the existing not-inlined-cfunc
  sections.
* **Optional `=site`:** keys by (ISEQ, insn_idx) instead. That's the key our probe uses (898 getivar sites on
  lobsters), minus its receiver labelling.
* **Reuse from the probe:** the codegen hook placement (send, send_forward, send_without_block, invokeblock,
  invokesuper, getivar), the dump format and the ranking script. The receiver class/shape recording stays
  measurement-only.
* **Not in scope:** time attribution (XrXr's duration slices), receiver distributions, and new counters.
  tekknolagi's memory-load counter would be a one-line `IncrCounter` on top of this once the mechanism exists.
* **Test:** one Ruby test with two methods doing different fallbacks, asserting the per-ISEQ counts and their sum
  against the global counter. The sum check also catches a future double count.
* **Size estimate:** about 150 lines across `stats.rs`, `state.rs`, `codegen.rs`, `hir.rs` and `options.rs`.

### Draft comment for Shopify/ruby#746 (not posted)

> Some data for this from Rails. Per-ISEQ counts are what we've been missing in the Rails work. The fallbacks
> have a long tail: on lobsters (10 iterations), getivar fallbacks come from 638 ISEQs and poly/megamorphic
> send fallbacks from 692, and the top 10 ISEQs account for only 41% and 30% of them (shipit: 343 / 520 ISEQs,
> 46% / 43%).
>
> The Perfetto fallback tracer gets at the "where", but it records a backtrace per event. On railsbench,
> `--zjit-trace-fallbacks` hadn't finished 20 iterations after 457 s (a normal `--zjit` run takes 41 s) and had
> written 788 MB. With `-sample-rate=100` the iterations took 3.3 s against 2.4 s with `--zjit-stats-quiet`.
> It also reports getivar fallbacks only as `"getivar"`, and HIR `IncrCounter` reasons aren't covered.
>
> Smallest version I have in mind: `--zjit-stats-iseq` adds one `inc` to a per-(ISEQ, counter) cell next to
> each counted fallback, exit and HIR `IncrCounter`. It reuses the `iseq_calls_count` storage pattern and
> attributes to the FrameState's ISEQ, so inlined code is blamed on the callee. The output is
> `RubyVM::ZJIT.stats(:iseq)` plus a top-20 section in the stats print. A code-shape counter like "memory
> loads" would then be one `IncrCounter` on top. We'd like to take this if nobody has it in flight.
