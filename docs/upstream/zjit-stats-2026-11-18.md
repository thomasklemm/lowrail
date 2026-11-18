# ZJIT stats on railsbench and lobsters, master `9de06831e3` (2026-11-18)

Which side exits, send fallbacks, not-inlined C methods and compile failures lead on ruby-bench's railsbench and
lobsters on current Ruby master, who owns each, and what is the next ZJIT fix worth building. Nothing was opened or
posted upstream.

**Result.** Compile failures are zero. Side exits are almost all `exception_handler` (99.9% / 88%), which is owned
upstream (rafaelfranca's ruby/ruby#18759, k0kubun's Shopify/ruby#1093). The large send fallbacks (polymorphic and
megamorphic sends and yields, `&block`, complex arguments, `...`) are all owned or held, as in Z13. The largest free
item by count is the not-inlined `Hash#key?` / `Regexp#match?` pair, but a frameless call saves only tens of
instructions per call (≈0.05% of an iteration). One new, small, free item came out of the side-exit sites:
**OTS1**, an `objtostring` type guard that never recompiles, so a String-profiled interpolation that also sees a
Symbol side-exits on every such call for good. It is built on the fork (2 files, production +4/−4), removes 538 of
lobsters' 677 `guard_type_failure` exits per iteration, and does not move `run_benchmarks.rb` times beyond A/A.

## Setup

* Ruby master [`9de06831e3`](https://github.com/ruby/ruby/commit/9de06831e37534f8a163e598cc0c6903c7687430)
  (2026-11-18 09:28 UTC), release build `--enable-zjit --disable-install-doc --without-jemalloc`, GCC 14.2, Rust 1.100.
* ruby-bench [`8083f57`](https://github.com/ruby/ruby-bench/commit/8083f572bb7f4691a764dd424f63cc14cf3367dc), Rails
  8.1.4.1 in both apps.
* `--zjit --zjit-stats-quiet --zjit-exec-mem-size=512 --zjit-mem-size=1024`, harness
  [`harness.rb`](../../bench/upstream/zjit-stats/harness.rb) via [`run.sh`](../../bench/upstream/zjit-stats/run.sh):
  15 warmup iterations, stats reset, 10 measured; counters below are per measured iteration. Two runs per benchmark
  agree to the unit on every counter that matters (the `-2` columns in [rank-master.txt](../../bench/upstream/zjit-stats/rank-master.txt)).
* `compile_error_out_of_memory` 0, `failed_iseq_count` 0 and no `compile_error_*` counter in any run, from boot
  through the end (2,597 / 6,303 ISEQs compiled during boot and warmup).
* Sites: separate runs with `--zjit-trace-exits-sample-rate=5 --zjit-trace-fallbacks-sample-rate=50`, summarized
  with [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb) `--depth 2`
  ([sites/](../../bench/upstream/zjit-stats/sites)). The tracer covers boot too, so samples rank sites, they are not
  per-iteration counts.

Raw JSON in [bench/upstream/zjit-stats/raw](../../bench/upstream/zjit-stats/raw), ranking tool
[`rank.rb`](../../bench/upstream/zjit-stats/rank.rb).

## Ranking (per iteration, railsbench / lobsters)

| family | counter | railsbench | lobsters |
| --- | --- | ---: | ---: |
| side exits | total | 21,687 | 10,167 |
| | `exception_handler` | 21,657 | 8,962 |
| | `guard_type_failure` | 0.4 | 677 |
| | `patchpoint_method_redefined` | 0 | 483 |
| | `guard_shape_failure` | 30 | 20 |
| send fallbacks | dynamic sends total | 1,083,892 | 772,268 |
| | `invokeblock_polymorphic_miss` | 215,912 | 100,887 |
| | `send_megamorphic` | 189,766 | 118,318 |
| | `send_polymorphic_fallback` | 30,483 | 259,141 |
| | `invokeblock_not_specialized` | 133,062 | 65,996 |
| | `send_block_arg_not_nil` | 121,987 | 95,271 |
| | `one_or_more_complex_arg_pass` | 106,495 | 41,239 |
| | `sendforward_not_specialized` | 75,134 | 31,847 |
| | `send_not_optimized_need_permission` (protected) | 54,836 | 15,959 |
| | `send_not_optimized_method_type_optimized` (`Kernel#send`) | 41,673 | 25,646 |
| | `super_complex_args_pass` | 39,252 | 3,125 |
| not-inlined C methods | `Hash#fetch` | 145,474 | 147,097 |
| | `Regexp#match?` | 137,174 | 41,710 |
| | `Hash#key?` | 125,384 | 45,124 |
| | `Hash#delete` | 62,027 | 28,338 |
| | `Kernel#dup` | 60,215 | 20,819 |
| | `String#<<` | 54,111 | 59,197 |
| generic ivar reads | `getivar_fallback_no_profile_missing_ic` | 201,419 | 205,400 |
| | `getivar_fallback_no_side_exits` | 0 | 142,653 |
| compile failures | all reasons | 0 | 0 |

Full tables: [rank-master.txt](../../bench/upstream/zjit-stats/rank-master.txt).

## The leading causes

### 1. `exception_handler` side exits: owned, large

21,657 / 8,962 exits, 99.9% / 88% of all side exits. ZJIT doesn't compile entries for `jit_exec_exception()`
(`gen_iseq_entry_point` returns the counter stub). These are not raised exceptions: a `TracePoint(:raise)` run
([raise_harness.rb](../../bench/upstream/zjit-stats/raise_harness.rb)) sees 0 raises per railsbench iteration and 38
per lobsters iteration. They come from non-local control flow through catch tables; railsbench's hottest
`invokeblock_not_specialized` sites are blocks with a non-local `return` (`try_precompressed_files` →
`each_precompressed_filepath`, `PathSet#find` → `search_combinations`), which is the same mechanism. That link is a
hypothesis: the exit counter carries no site.

* **Owner:** Shopify/ruby#966 (k0kubun's design notes: per-PC exception entries plus some OSR for the caller frames),
  rafaelfranca's ruby/ruby#18759 "Compile exception handlers" (open since 09-15), k0kubun's TAG_RETURN/TAG_BREAK work
  in Shopify/ruby#1093, luke-gruber's draft ruby/ruby#18244 (`throw`). Row 14 of Shopify/ruby#1039 measured
  +0.34% on lobsters for #18759.
* **Size:** large, a design change. **For us:** nothing to build.

### 2. Polymorphic and megamorphic sends and yields: owned or held

`invokeblock_polymorphic_miss` (`Array#each` in `RouteSet#url_for`, `FanoutIteration#iterate_guarding_exceptions`,
`Journey::Format#evaluate`), `invokeblock_not_specialized` (blocks with `return`/`break`, `Array#map` and `#select`
blocks), `send_megamorphic` (the `extend`ed logger: `Logger#level` 25.6k samples, `local_level`, `debug?`, `info?`)
and `send_polymorphic_fallback` (lead 3, lobsters 259k).

* **Owner:** yields are k0kubun's (Shopify/ruby#1093, #1039 rows 26–33); the logger's singleton receivers are
  Shopify/ruby#1120 (design, unassigned) and #1039 rows 24–27; lead 3 is our ZL3, held at a design question on
  Shopify/ruby#776. Unchanged since [Z13](zjit-yjit-gap.md).
* **For us:** nothing new.

### 3. `&block`, complex arguments and `...`: owned

`send_block_arg_not_nil` (`_read_attribute(name, &block)` on Rails 8.1, `iterate_guarding_exceptions`,
`mon_synchronize`), `one_or_more_complex_arg_pass` (Rack `fetch_header(&block)` into a C method, HWIA
`update_with_single_argument`), `sendforward_not_specialized` (`delegate`'s `...`).

* **Owner:** lead 7 is #1039 row 7 (k0kubun); ZS1 (ruby/ruby#19912, ours, open) covers `&:sym`; lead 14a/14b waits
  for row 7/42; `...` is nozomemein's ruby/ruby#18326. Lead 14c (`**rest` callees) and 14d (`nil` `&blk` to a C
  method, 0.8 M Ir on railsbench) stay free and small, unchanged from the [lead queue](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03).

### 4. Not-inlined C methods: partly owned, free part is small

* `Hash#fetch` 145k / 147k: nithya4005's ruby/ruby#19949 (open, approved by tekknolagi 11-17, Shopify/ruby#1086
  assigned to her) adds `HashFetch` for the two-argument form; the one-argument and block forms stay calls. The
  split of the 145k between the forms is unmeasured.
* `Regexp#match?` 137k / 42k and `Hash#key?` 125k / 45k: free. No ruby/ruby PR; Shopify/ruby#1059 is `String#match?`
  only (open, unassigned). Neither is leaf in general (`Hash#key?` can call `#hash`/`#eql?` on arbitrary keys, `Regexp#match?`
  can allocate and raise), so a fix is a guarded HIR instruction per method,
  #19949's shape (≈180 lines each). It would turn a `CCallWithFrame` into a frameless call: at the ~10–30 Ir per
  call that frame costs (lead 12), 125k calls are 1.3–3.8 M Ir, 0.03–0.08% of a railsbench iteration. Below what
  `run_benchmarks.rb` can show.
* `Kernel#dup` stays blocked ([zjit-shortlist](zjit-shortlist.md)); `String#dup` is ZSD1 (parked).

### 5. Generic ivar reads: owned

`getivar_fallback_no_profile_missing_ic` 201k / 205k (`url_options`, `optimize_routes_generation?`, `performed?`):
lead 11, tekknolagi's draft ruby/ruby#18616. `getivar_fallback_no_side_exits` 0 / 143k: final versions; the rest is
k0kubun's #1031/#19617. The attr_reader piece was our lead 15a (built 11-03 on
`thomasklemm/zjit-final-attr-reader-shape`, −0.60% Ir on shipit); checked later the same day, #18616's 11-16 head
covers it too: a monomorphic attr_reader in a final version branches on class and shape and loads the field, so 15a
is taken ([lead queue](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03)).

### 6. `guard_type_failure` on lobsters: new, free, small (OTS1)

677 exits per lobsters iteration, almost all at one site:
`ActionView::Helpers::TagHelper::TagBuilder#content_tag_string` (tag_helper.rb:232, 11,787 of the 12,162
`GuardType(String)` samples):

```ruby
"<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name}>".html_safe
```

`name` is a String in 2,500 calls and a Symbol in 533 per iteration
([lobsters-content-tag-string-classes.json](../../bench/upstream/zjit-stats/raw/lobsters-content-tag-string-classes.json)).
`objtostring` with a monomorphic String profile emits `GuardType v, String` with `recompile: None`, so once the
profile saw only Strings, every Symbol call side-exits, for as long as the ISEQ lives. A 10-line repro
([ots1_probe.rb](../../bench/upstream/zjit-stats/ots1_probe.rb)): after a String warmup, 10,000 calls with `nil`
take 10,000 exits on master. The Fixnum, Module and other-class guards in the same instruction have the same flaw.

* **Ownership:** no open ruby/ruby PR on `objtostring` (the only one, casperisfine's #6335, is unrelated); no
  Shopify/ruby issue; no #1039 row. The guards come from tekknolagi's #17499 (June) and our #19678. k0kubun's
  merged #19603 made `coerce_to`'s guard recompile the same way, so the shape has a precedent.
* **Size:** production +4/−4 lines in `zjit/src/hir.rs`.

The remaining 139 lobsters exits are mostly `GuardType(ArrayExact)` in `expandarray` at
`JoinAssociation#join_constraints` (also `recompile: None`; k0kubun's #1039 row 18 profiles `expandarray`, so it is
left alone). `patchpoint_method_redefined` 483 is final versions invalidated by `class_attribute :attribute_aliases`:
with `--zjit-max-versions=16` it drops to 0 ([rank-max-versions.txt](../../bench/upstream/zjit-stats/rank-max-versions.txt)),
which is k0kubun's ruby/ruby#19617.

## OTS1: the build

Branch [`thomasklemm/zjit-objtostring-recompile`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-objtostring-recompile)
@ [`2cc3e0de4d`](https://github.com/thomasklemm/ruby/commit/2cc3e0de4d63abe7e307d3cc8d6b216fe5be55c9), one commit on
master `9de06831e3`, 2 files, +95/−11 (production +4/−4, [ots1.diff](../../bench/upstream/zjit-stats/ots1.diff)).
Queue item [OTS1](../../bench/upstream/pr-queue/items/OTS1.md).

```diff
                         if profiled_type.is_string() {
                             fun.push_insn(block, Insn::PatchPoint { invariant: Invariant::NoSingletonClass { klass: profiled_type.class() }, state: exit_id });
-                            fun.push_insn(block, Insn::GuardType { val: recv, guard_type: types::String, state: exit_id, recompile: None })
+                            fun.guard_type_recompile(block, recv, types::String, exit_id, Recompile)
```

The same change for the Fixnum and Module guards in `try_objtostring_cfunc` and the other-class guard before the
`to_s` send. A final version behaves as before: `exit_recompile` returns early once the ISEQ is out of versions, so
the guard is a plain side exit there. A recompiled version whose profile has seen the other type takes the existing
polymorphic path (`CondBranchHasType` plus a `to_s` send). Checked with [ots1_skew_probe.rb](../../bench/upstream/zjit-stats/ots1_skew_probe.rb):
a String/Symbol mix profiles polymorphic and compiles the same HIR on master and the branch; a skewed 9:1 profile
still guards and recompiles after five exits.

* **Test:** `test_objtostring_guard_failure_recompiles` (HIR snapshots of version 1 with `GuardType … recompile`
  and version 2, compiled after Symbol calls, without the String guard), modeled on `test_coerce_to_guard_failure_recompiles`;
  seven existing snapshots gain `recompile`.
* **Checks** (`--enable-zjit=dev`): `make zjit-test` 2,014 of 2,015; the one failure is
  `test_profile_frames_during_direct_jit_to_jit_entry` (SIGABRT, a profiler-signal test), which passes 3 of 3 alone
  and failed the same way before the change. btest at `--zjit-call-threshold=1` and `=2`: all 2,148 pass.
* **Stats** (per iteration, master run 1 / run 2 / branch run 1 / run 2):

```diff
 lobsters
-exit_guard_type_failure:              677.2      677.2
+exit_guard_type_failure:              139.2      139.2
-side_exit_count:                   10,167.3   10,167.0
+side_exit_count:                    9,628.6    9,628.8
-ccall_rb_zjit_materialize_frames:   1,205.3    1,205.0
+ccall_rb_zjit_materialize_frames:     666.6      666.8
-send_fallback_send_polymorphic:       493.0      493.0
+send_fallback_send_polymorphic:     1,574.0    1,574.0
```

  The recompiled `content_tag_string` sends `Symbol#to_s` (533 per iteration) where it exited before, so dynamic
  sends rise by 1,072. railsbench: no counter moves (its `guard_type_failure` is 0.4).
* **`run_benchmarks.rb`** (master, master again, branch; `--interleave --pvalue`, default harness with 15 warmup and 10 measured iterations,
  2-CPU orb without sudo, so no CPU isolation): round 1 lobsters master/master-aa **1.097 (p 0.003)**, master/branch
  1.089 (p 0.013); round 2 0.980 and 0.952 (both not significant); railsbench 1.025/1.017 and 0.987/0.978, none
  significant ([round1.txt](../../bench/upstream/zjit-stats/run_benchmarks/round1.txt),
  [round2.txt](../../bench/upstream/zjit-stats/run_benchmarks/round2.txt)). The A/A spread on this orb is up to 10%,
  so there is no time effect to claim in either direction. By count, 538 exits at a few thousand instructions each
  are about 1–2 M Ir per lobsters iteration, ≈0.05%; no Callgrind run was made.

## Recommendation

1. **Next fix: OTS1.** It is exact, 4 production lines, has a merged precedent (#19603), and removes a permanent
   exit, which is the one case where Lowrail's rules let a ZJIT PR go up without a `run_benchmarks.rb` effect
   outside A/A. Expected gain on these two benchmarks is ≈0.05% of lobsters and 0 on railsbench, so the body should
   say exactly that and show the exit diff, not a time. Before opening: Thomas's "can explain it first" step, a
   Callgrind A/A on lobsters if a number is wanted, and the usual review passes. Not opened.
2. ~~Larger and also free: rebase 15a.~~ Taken (checked later on 11-18): tekknolagi's draft ruby/ruby#18616, refreshed
   on 11-16, gives a monomorphic attr_reader in a final version a class and shape branch with a field load, which is
   15a's change. On the 15a probe the final version's 1,002 generic reads on master drop to 0 on #18616's head.
3. **Not worth it now:** frameless `Hash#key?`/`Regexp#match?` (≈0.03–0.08%, ~180 lines each), and everything in
   causes 1–3 and 5, which is owned. Old leads not reopened: ZSD1 stays parked (`String#dup` 25k calls, ≈0.005%),
   ZS1 is open as ruby/ruby#19912, VB1 is closed Rails-side and answered by ZS1.
