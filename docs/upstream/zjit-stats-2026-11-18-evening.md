# ZJIT stats after the forced `inline_block` inlining, master `825d71e673` (2026-11-18, evening)

**Kurz für Thomas.** tekknolagis ruby/ruby#17864 (seit 21:40 UTC auf master) wirkt wie erwartet und genau dort, wo
die Morgen-Rangliste ihre größten Yield-Posten hatte: generische `yield`-Aufrufe fallen je Iteration um 54 % bis 66 %
(railsbench 349k → 135k, lobsters 167k → 77k, shipit 415k → 139k), dynamische Sends insgesamt um 12 % bis 20 %; die
A/A-Kontrolle (zweiter Build desselben master) bewegt sich bei diesen Zählern um höchstens 3. `invokeblock_polymorphic_miss`
fällt auf railsbench von Platz 1 auf Platz 7. Nennenswerte Seiteneffekte gibt es nicht; Ausstiege bleiben gleich, Compile-Fehler bei 0.
Was an Yields übrig bleibt, ist fast vollständig vergeben: Blöcke mit `break`/`return` (k0kubun), `&block`-Weitergabe
(k0kubun, Zeile 7), `&:sym` (unser #19912) und Yields mit überzähligen Argumenten (unser #19659). Neu sichtbar und frei
sind nur zwei kleine Folgeschritte zu unseren eigenen offenen PRs: Auto-Splat (`detect { |klass, _| }`, nach #19659) und
der `yield` an einen Symbol-Block in der eingebetteten Schleife (`columns.each(&:-@)`, nach #19912). **Jetzt lohnt
sich kein freier Lead zum Bauen**; beide warten auf die Merges, auf denen sie aufbauen. Nichts upstream gepostet.

The morning record is [zjit-stats-2026-11-18.md](zjit-stats-2026-11-18.md) (master `9de06831e3`, railsbench and
lobsters). This pass reuses its harness and counters and adds shipit.

## Setup

* Builds, all release `--enable-zjit --disable-install-doc --without-jemalloc`, GCC 14.2, Rust 1.100, out of tree:
  **new** = master [`825d71e673`](https://github.com/ruby/ruby/commit/825d71e673c2257f3952eb8059a7fe14e2320332)
  (the merge of #17864, still the tip at 22:00 UTC), **parent** = [`e5e6cd45db`](https://github.com/ruby/ruby/commit/e5e6cd45db),
  **new-aa** = a second, separate build of `825d71e673` (different build directory and prefix; the binaries differ).
* ruby-bench [`8083f57`](https://github.com/ruby/ruby-bench/commit/8083f572bb7f4691a764dd424f63cc14cf3367dc) (the
  morning's pin and #17864's), Rails 8.1.4.1. Benchmarks railsbench, lobsters, shipit.
* The morning's [`harness.rb`](../../bench/upstream/zjit-stats/harness.rb) and [`run.sh`](../../bench/upstream/zjit-stats/run.sh)
  unchanged: `--zjit --zjit-stats-quiet --zjit-exec-mem-size=512 --zjit-mem-size=1024`, 15 warmup iterations, stats
  reset, 10 measured; every counter is per measured iteration. One run per build and benchmark
  ([evening/runs.sh](../../bench/upstream/zjit-stats/evening/runs.sh)); new-aa is the A/A.
* Diffs: [`diff.rb`](../../bench/upstream/zjit-stats/diff.rb) prints a counter only if it moved by at least 10 per
  iteration and by more than three times its new/new-aa difference. Per-ISEQ call counts and `*_time_ns` are left out.
* Sites: one traced run of new per benchmark (`--zjit-trace-exits-sample-rate=5 --zjit-trace-fallbacks-sample-rate=50`,
  boot included), summarized with [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb) `--depth 2`. Per-site
  "≈ per iteration" figures below scale the samples by the run's own invokeblock counters
  ([shapes_scan.rb](../../bench/upstream/zjit-stats/evening/shapes_scan.rb)); they are estimates.
* Compile failures: 0 `failed_iseq_count`, 0 `compile_error_*` in all nine runs, boot through the end.
* The 2-CPU orb ran builds, gem installs and runs side by side, so `ms_per_itr` is not comparable and no time is
  claimed. The counters are deterministic: parent reproduces the morning's railsbench and lobsters counters to the unit
  (e.g. dynamic sends 1,083,890 vs 1,083,892, `invokeblock_polymorphic_miss` 215,912 both).

Data: raw JSON in [evening/raw](../../bench/upstream/zjit-stats/evening/raw), sites in
[evening/sites](../../bench/upstream/zjit-stats/evening/sites), full table [rank-evening.txt](../../bench/upstream/zjit-stats/evening/rank-evening.txt),
diffs [railsbench](../../bench/upstream/zjit-stats/evening/diff-railsbench.txt),
[lobsters](../../bench/upstream/zjit-stats/evening/diff-lobsters.txt),
[shipit](../../bench/upstream/zjit-stats/evening/diff-shipit.txt).

## What moved (parent → new, A/A-filtered)

```diff
 railsbench
-dynamic_send_count                              1,083,890
+dynamic_send_count                                869,975   (-213,914, -19.7%, A/A 0.0)
-ccall_rb_vm_invokeblock                           348,974
+ccall_rb_vm_invokeblock                           135,057   (-213,917, -61.3%, A/A 0.0)
-send_fallback_invokeblock_polymorphic_miss        215,912
+send_fallback_invokeblock_polymorphic_miss         50,235   (-165,677, -76.7%, A/A 0.0)
-send_fallback_invokeblock_not_specialized         133,062
+send_fallback_invokeblock_not_specialized          84,822   (-48,240, -36.3%, A/A 0.0)
-block_iseq_direct_optimized_send_count             67,222
+block_iseq_direct_optimized_send_count            281,139   (+213,917, A/A 0.0)
-not_inlined_cfuncs_Hash#delete                     62,027
+not_inlined_cfuncs_Hash#delete                     52,970   (-9,057, -14.6%, A/A 0.0)
-not_inlined_cfuncs_Array#join                      39,236
+not_inlined_cfuncs_Array#join                      30,179   (-9,057, -23.1%, A/A 0.1)
-zjit_insn_count                                71,609,224
+zjit_insn_count                                71,108,667   (-500,557, -0.7%, A/A 1.5)
 lobsters
-dynamic_send_count                                772,267
+dynamic_send_count                                681,142   (-91,124, -11.8%, A/A 1.9)
-ccall_rb_vm_invokeblock                           166,882
+ccall_rb_vm_invokeblock                            77,151   (-89,731, -53.8%, A/A 2.6)
-send_fallback_invokeblock_polymorphic_miss        100,887
+send_fallback_invokeblock_polymorphic_miss         43,424   (-57,463, -57.0%, A/A 0.1)
-send_fallback_invokeblock_not_specialized          65,995
+send_fallback_invokeblock_not_specialized          33,727   (-32,268, -48.9%, A/A 2.5)
-send_fallback_send_polymorphic_fallback           259,141
+send_fallback_send_polymorphic_fallback           256,648   (-2,493, -1.0%, A/A 0.0)
-send_fallback_send_megamorphic                    118,319
+send_fallback_send_megamorphic                    119,418   (+1,099, +0.9%, A/A 0.0)
-exit_guard_type_failure                               677
+exit_guard_type_failure                               663   (-14, A/A 0.0)
 shipit
-dynamic_send_count                              1,841,464
+dynamic_send_count                              1,567,641   (-273,823, -14.9%, A/A 0.4)
-ccall_rb_vm_invokeblock                           415,397
+ccall_rb_vm_invokeblock                           139,371   (-276,026, -66.4%, A/A 2.6)
-send_fallback_invokeblock_polymorphic_miss        310,206
+send_fallback_invokeblock_polymorphic_miss        101,458   (-208,749, -67.3%, A/A 2.4)
-send_fallback_invokeblock_not_specialized         105,191
+send_fallback_invokeblock_not_specialized          37,913   (-67,278, -64.0%, A/A 0.2)
```

Every generic `invokeblock` that went away became a direct block call (`block_iseq_direct` rises by the same count).
No side-exit counter, compile counter or other fallback family moves beyond a few thousand; the largest side effect is
`send_polymorphic_fallback` −2.5k and `send_megamorphic` +1.1k on lobsters. The equal −9,057 (railsbench) and −2,134
(lobsters) on `Hash#delete`, `Array#join`, `rb_optimized_call` and `rb_hash_aref` belong to one code path that
now runs fewer times or outside JIT code; it was not traced.

By site (trace samples, morning master → new): railsbench's `Array#each` in `RouteSet#url_for` 13,720 → 3,
`Journey::Format#evaluate`'s second loop 6,303 → 0, `CallbackSequence#invoke_before` 5,694 → 0 and 4,097 → 1,
`Integer#times` in `parameterize_args` 3,343 → 1; lobsters' `Relation::Merger#merge` 8,299 → 6 and `perform_query`'s
`Array#map` 8,237 → 14. All InvokeBlock samples: railsbench 181,039 → 68,838, lobsters 102,074 → 47,800.

## Ranking now (new, per iteration, railsbench / lobsters / shipit)

| family | counter | railsbench | lobsters | shipit |
| --- | --- | ---: | ---: | ---: |
| side exits | total | 21,688 | 10,153 | 50,232 |
| | `exception_handler` | 21,657 | 8,962 | 9,757 |
| | `patchpoint_stable_constant_names` | 0 | 0 | 39,633 |
| | `guard_type_failure` | 0.4 | 663 | 826 |
| | `patchpoint_method_redefined` | 0 | 483 | 0 |
| send fallbacks | dynamic sends total | 869,975 | 681,142 | 1,567,641 |
| | `send_polymorphic_fallback` | 30,483 | 256,648 | 777,236 |
| | `send_megamorphic` | 189,766 | 119,418 | 126,770 |
| | `send_block_arg_not_nil` | 121,987 | 95,270 | 208,849 |
| | `invokeblock_polymorphic_miss` | 50,235 | 43,424 | 101,458 |
| | `one_or_more_complex_arg_pass` | 106,495 | 41,239 | 85,788 |
| | `sendforward_not_specialized` | 75,134 | 31,847 | 100,882 |
| | `invokeblock_not_specialized` | 84,822 | 33,727 | 37,913 |
| | `send_not_optimized_method_type_optimized` (`Kernel#send`) | 41,673 | 25,646 | 67,050 |
| | `send_not_optimized_need_permission` (protected) | 54,836 | 15,959 | 30,469 |
| not-inlined C methods | `Hash#fetch` | 145,474 | 147,097 | 402,869 |
| | `Hash#key?` | 125,384 | 45,124 | 169,449 |
| | `Regexp#match?` | 137,174 | 41,710 | 23,032 |
| generic ivar reads | `getivar_fallback_no_profile_missing_ic` | 201,419 | 205,513 | 601,847 |
| | `getivar_fallback_no_side_exits` | 0 | 140,956 | 335,050 |
| compile failures | all reasons | 0 | 0 | 0 |

Compared with the morning, the two yield families drop from 1st and 3rd place on railsbench to 7th and 4th; the
send-side families (`send_megamorphic`, `&block`, complex arguments, `...`) now lead everywhere, and shipit adds
`send_polymorphic_fallback` 777k (lead 3) and 40k constant PatchPoint exits.

## The yields that are left, and who has them

Probe [yield_shapes_probe.rb](../../bench/upstream/zjit-stats/evening/yield_shapes_probe.rb)
([output](../../bench/upstream/zjit-stats/evening/yield_shapes_probe.txt)): with `Array#each` made polymorphic out of
line first, a plain `{ |x| }` or destructuring `{ |(x, y)| }` block goes from 30,000 generic yields on parent to 0 on
new. Still generic on new: blocks with `break` or `return`, `each(&:sym)`, `each(&blk)`, and `find { |k, _| }`.
Shares of the remaining InvokeBlock samples, by the shape of the block at the iterator's caller line:

| shape | railsbench | lobsters | shipit | top sites | owner |
| --- | ---: | ---: | ---: | --- | --- |
| `yield` in a Ruby method (block elsewhere; mostly blocks with non-local `return`) | 44% | 14% | 25% | `each_precompressed_filepath`, `search_combinations` (morning: `return` blocks), `Notifications.instrument`'s `{ yield payload if block_given? }` | `return`: k0kubun's Shopify/ruby#1093 (assigned); the surplus-argument yield into `{ yield … }`: our ruby/ruby#19659 |
| block argument `&blk` / `&:sym` | 29% | 37% | 58% | `columns.each(&:-@)` in `Result#initialize` (shipit ≈75k/itr), `collection.each(&block)` in `iterate_guarding_exceptions` | `&block`: #1039 row 7 (k0kubun); `&:sym` send: our ruby/ruby#19912 |
| `break`/`return` inside the block | 21% | 34% | 8% | `Journey::Format#evaluate` (`return ""`), `apply_inflections` (`break`), SQLite3 `Statement#each` (`loop … break`) | Shopify/ruby#1093 (k0kubun); luke-gruber's draft ruby/ruby#18244 |
| auto-splat (one value into `\|a, b\|`) | 3.5% (≈4.7k/itr) | 9% (≈6.7k/itr) | 7% (≈9.9k/itr) | `PredicateBuilder#handler_for` (`detect { \|klass, _\| }`), `RequestId#call` (`tap { \|_status, headers, _body\| }`) | free, see below |

The auto-splat yields are counted as `invokeblock_polymorphic_miss`, not `not_specialized`
([autosplat_probe.rb](../../bench/upstream/zjit-stats/evening/autosplat_probe.rb),
[output](../../bench/upstream/zjit-stats/evening/autosplat_probe.txt)). `Array#find` is now inlined with the known
block, but `can_direct_invoke_block_iseq` rejects a 1-argument yield into a 2-parameter block, so the inlined
`invokeblock` falls back to the shared `Array#find` profile, which other callers made polymorphic. With `|k|` the same
call is direct on new (40,000 → 0).

## Ownership of the top entries (checked 2026-11-18 22:30 UTC)

* `exception_handler`: rafaelfranca's ruby/ruby#18759 (open), Shopify/ruby#966, k0kubun's Shopify/ruby#1093. Unchanged.
* `patchpoint_stable_constant_names` (shipit only, `StableConstantNames(Base)` in `ConnectionHandling#connection_specification_name`):
  k0kubun's ruby/ruby#19617 (open, approved by XrXr), whose body shows shipit's 35,747 such exits going to 0 after the
  `require "useragent"` invalidation. `--zjit-max-versions=16` on new does not remove them (39,601,
  [raw](../../bench/upstream/zjit-stats/evening/raw/shipit-new-mv16.json.gz)); #19617's effect on current master was not rebuilt here.
* `send_polymorphic_fallback`: lead 3 (our ZL3, held at a design question on Shopify/ruby#776).
* `send_megamorphic`: Shopify/ruby#1120 (design, unassigned) and #1039 rows 24–27.
* `send_block_arg_not_nil`: #1039 row 7 (k0kubun) for `&block`; our ruby/ruby#19912 for `&:sym` (open, no maintainer
  response yet). Its body says the callee's `yield` is unchanged, so `columns.each(&:-@)` would become a direct send
  with a generic yield inside.
* `one_or_more_complex_arg_pass`, `sendforward_not_specialized`: lead 14 rows as in the morning; nozomemein's draft
  ruby/ruby#18326 for `...`.
* `Kernel#send`: tekknolagi's draft ruby/ruby#19583, #1039 row 11.
* `Hash#fetch`: nithya4005's ruby/ruby#19949 (open, approved), Shopify/ruby#1086 assigned to her.
* `Hash#key?`, `Regexp#match?`: free and small, unchanged from the morning (≈0.03–0.08% of an iteration).
* Generic ivar reads: tekknolagi's draft ruby/ruby#18616 and k0kubun's #19617/Shopify/ruby#1031, as in the morning;
  ZSV1 (held) for lobsters' 584 generic writes.
* Our open ZJIT PRs: #19659, #19912, #19976, #19982 (OTS1; on the morning master it took lobsters' `guard_type_failure` from 677 to 139), #19680,
  #19681, all open; ZSV1 held. Only #19659 and #19912 touch the yields that are left. One new open ZJIT PR since the
  morning: our #19982; #17864 merged. No new Shopify/ruby issue on yields.

## Free leads

None worth building now. Two new free items follow directly from #17864 and each builds on one of our open PRs, so
under "never stack on an open PR" they wait for that merge:

1. **YS1, `yield` to a Symbol block inside an inlined iterator** (after ruby/ruby#19912). Once `columns.each(&:-@)` is a
   direct send, the inlined `Array#each` knows its block is `:-@` and can compile the `yield` as the send it stands for.
   It is #1039 row 17 (`ed1c0f97b2`, "Compile a `yield` to a Symbol block as the send it stands for"), which has no assignee.
   Largest remaining yield site on shipit: ≈75k per iteration (two `Result#initialize` sites, 22,892 samples), lobsters ≈15k,
   railsbench ≈11k. Size medium: about 60–100 production lines in the inlined `invokeblock` path, plus the refinement
   question #19912 already answers for the send (the Symbol's method must be looked up with the refinements of the
   `&:sym` site). Gain unmeasured; at ≈100–200 instructions saved per yield it would be ≈10 M Ir per shipit iteration.
2. **AS1, auto-splat yields into an inlined iterator** (after ruby/ruby#19659). Shopify/ruby#1094 (unassigned; tekknolagi:
   "To consider: auto-splat") is the issue #19659 resolves, and #19659 deliberately leaves auto-splat out. k0kubun's
   branch has it as #1039 rows 30–31, no assignee. ≈4.7k / 6.7k / 9.9k yields per iteration. Size small to medium
   (guard a plain Array, load its length, take `lead_num` elements with nil padding; ≈60–100 lines). At the ≈20 ns per
   yield #19659 measured for a generic yield, ≈0.2 ms per shipit iteration, below what `run_benchmarks.rb` resolves.

Not leads: the throw blocks and `&block` forwarding (owned, above), `Hash#key?`/`Regexp#match?` (small, unchanged),
shipit's 826 `guard_type_failure` exits (`GuardType(SQLite3Integer)` in `Attribute::FromDatabase#type_cast` and a class
guard in `_order_columns`; final-version exits, the version cap's design), and the misleading `polymorphic_miss` label on
auto-splat yields (a counter detail, nothing to fix on its own).
