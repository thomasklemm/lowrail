# ZJIT C-method fast paths on Rails (bet Z7)

Which C methods would ZJIT gain most from a fast path on Rails? This bet takes the unowned candidates from the
[ZJIT shortlist](zjit-shortlist.md) (Shopify/ruby [#1059](https://github.com/Shopify/ruby/issues/1059)
`String#match?`, [#1058](https://github.com/Shopify/ruby/issues/1058) `Kernel#dup`,
[#1060](https://github.com/Shopify/ruby/issues/1060) `Time#utc?`, [#808](https://github.com/Shopify/ruby/issues/808)
`String#length`, [#993](https://github.com/Shopify/ruby/issues/993) InvokeSuper from a block). It counts how ZJIT
dispatches each candidate on Rails, adds other C methods that ZJIT calls with a frame most often, and prices them.

**Result.** **`Kernel#dup` is the only candidate that pays**, and by a wide margin. Rails calls it 19–60k times per
ruby-bench iteration, almost all on `Hash` and `Array` (Active Record, Active Support options). Every call is a
`CCallWithFrame` of `rb_obj_dup`, which then makes two uncached `rb_funcall`s (`initialize_dup`, then
`initialize_copy`). About half of each `dup` is that re-entry. A measurement prototype, ZJIT calling the
copy hook directly under patch points, is exact on every case we tried and cuts **0.68% of instructions on
railsbench, 0.90% on shipit and 0.50% on lobsters** (GC excluded, A/A ≤ 0.12%). The other four candidates are
worth ≤ 0.05% each: `String#match?` is dominated by Onigmo, `Time#utc?` is cheap and rare, `String#length` is
already a frameless call, and InvokeSuper from a block falls back 1.4–6k times per iteration. No other
unowned C method in the top 20 comes close to `dup`, because their per-call overhead is one frame (~43 instructions),
not two method calls through `rb_funcall`.

An unposted comment for #1058 is at the end. Nothing was opened upstream.

## Pins and method

* **Ruby:** ruby/ruby master [`9f2e54518e`](https://github.com/ruby/ruby/commit/9f2e54518e) (2026-11-03), release
  build (`-O3 -fno-omit-frame-pointer`), `--enable-zjit --enable-yjit`, Rust 1.99.1. Three builds from it, all on
  the fork:
  * **master:** unchanged.
  * **stats:** [`thomasklemm/zjit-cfunc-dispatch-stats`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-cfunc-dispatch-stats)
    ([`c9e589a222`](https://github.com/thomasklemm/ruby/commit/c9e589a222)). It adds `--zjit-stats` counters per
    C method: `inlined_cfuncs_` (inlined into HIR), `leaf_cfuncs_` (frameless `CCall`) and `fallback_cfuncs_ "M
    (reason)"` (a dynamic send that reached the C method, read from the call cache after the call), next to the
    existing `not_inlined_cfuncs_` (`CCallWithFrame`/`CCallVariadic`). Without `--zjit-stats` it emits the same code.
  * **prototype:** [`thomasklemm/zjit-dup-proto`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-dup-proto)
    ([`292cc979e5`](https://github.com/thomasklemm/ruby/commit/292cc979e5)), below. It is for measurement and is
    not a PR branch.
* **ruby-bench** [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2): railsbench, lobsters, shipit.
  Harnesses (copied into `harness/`, selected with `HARNESS=`):
  * [`ruby_bench_jit_stats.rb`](../../bench/upstream/ruby_bench_jit_stats.rb) (as in Z1): 15 warmup iterations,
    `reset_stats!`, counters over 10.
  * [`ruby_bench_cfunc_calls.rb`](../../bench/upstream/ruby_bench_cfunc_calls.rb) (new): every C method call per
    iteration in the interpreter, by `:c_call` TracePoint, over 3 iterations after 15 warmup. This is the
    denominator: it also counts calls made from C and from not-yet-compiled code.
  * [`ruby_bench_dup_receivers.rb`](../../bench/upstream/ruby_bench_dup_receivers.rb) (new): receivers of
    `Kernel#dup` by class, with the owners their `initialize_dup` and `initialize_copy` resolve to.
  * [`ruby_bench_callgrind.rb`](../../bench/upstream/ruby_bench_callgrind.rb) (as in Z1): Valgrind 3.19,
    `--smc-check=all-non-file`, 15 warmup iterations, then an empty and a 3-iteration window in the same process.
    Totals here are **GC-excluded** (`CG_NO_GC=1`): GC-included runs moved by up to 75 M Ir in `gc_mark` alone
    between builds, depending on where a major GC lands. Each build ran twice. Lobsters runs are sequential,
    because parallel lobsters copies share `tmp/cache` and raise HTTP 500s.
* **Apps:** Fizzy (SQLite), Lobsters and Campfire through `script/census` on Rails main
  [`b10c3acfe9`](https://github.com/rails/rails/commit/b10c3acfe9) (as in Z1), corpus `censusz7`; Lobsters and
  Campfire with the `jit-parity-census` overlays. `script/census run --stats=--zjit-exec-mem-size=128` on the stats
  build: 50 warmup operations per workload, then counters over 20 operations each (128 MiB so that Fizzy does not
  run out of code memory under `--zjit-stats`, see Z1).
* Dispatch tables: [`zjit_cfunc_dispatch.rb`](../../bench/upstream/zjit_cfunc_dispatch.rb) (new). Function diffs:
  [`callgrind_fn_diff.rb`](../../bench/upstream/callgrind_fn_diff.rb).
* Per-call costs: a microbenchmark that calls one method in a `while` loop 20,000 times, under Callgrind client
  requests, ZJIT with `--zjit-call-threshold=2`, minus the empty loop.
* Receipts (stats and call-count JSONs, Callgrind totals, microbenchmark script):
  [`data/zjit-cfunc-paths/receipts.tar.gz`](data/zjit-cfunc-paths/receipts.tar.gz). Callgrind dumps stay on the orb.

## The five candidates

Calls per iteration (ruby-bench) or per operation (apps), and how ZJIT dispatches them:

| Candidate | railsbench | lobsters | shipit | Fizzy / Lobsters / Campfire | ZJIT dispatch | Ir per call (micro) |
| --- | ---: | ---: | ---: | --- | --- | ---: |
| `Kernel#dup` ([#1058](https://github.com/Shopify/ruby/issues/1058)) | 60,215 | 19,232 | 50,053 | 226 / 183 / 153 | `CCallWithFrame`, 100% of non-immediates; immediates already inline ([#18872](https://github.com/ruby/ruby/pull/18872)) | 1,212–1,309 |
| `String#match?` ([#1059](https://github.com/Shopify/ruby/issues/1059)) | 32,105 | 19,508 | 1,762 | 378 / 506 / 57 | `CCallWithFrame`, 100% | 750 |
| `Time#utc?` ([#1060](https://github.com/Shopify/ruby/issues/1060)) | 5,200 | 11,855 | 9,810 | 36 / 195 / 24 | `CCallWithFrame`, 100% | 74 |
| `String#length` ([#808](https://github.com/Shopify/ruby/issues/808)) | 11,961 | 11,911 | 2,928 | 32 / 176 / 90 | frameless `CCall` (leaf, no GC), 100% | 5 |
| `super` from a block ([#993](https://github.com/Shopify/ruby/issues/993)) | 6,000 | 1,397 | 2,717 | 53 / 31 / 18 | `send_fallback_super_from_block` (interpreter dispatch) | — |

What a fast path could save, per iteration:

* **`Kernel#dup`.** Inclusive cost of `rb_obj_dup` on master (Callgrind, GC included): 95 M Ir per iteration on
  railsbench (1.9%), 27 M on lobsters (0.8%), 70 M on shipit (1.7%). In the microbenchmark, half of every call is
  the two `rb_funcall`s and their frames (`rb_funcallv_scope`, `vm_call0_body`, `vm_call0_cc`, `vm_push_frame`).
  Measured below: **−0.68% / −0.50% / −0.90%**.
* **`String#match?`.** 1,100 Ir per call inclusive on lobsters, almost all Onigmo (`onig_search`). The C coercion
  (`rb_str_match_m_p` + `get_pat_quoted`) is 25 Ir per call. Moving it to Ruby, as nirvdrum describes for TruffleRuby,
  saves at most that plus one frame (~70 Ir per call): ≤ 2.2 M / 1.4 M / 0.1 M Ir (≤ 0.05%). `Regexp#match?`
  itself (100k / 28k / 23k calls) stays a `CCallWithFrame`: Onigmo can raise `Regexp::TimeoutError` and recompile
  a pattern for another encoding, so it is neither leaf nor no-GC.
* **`Time#utc?`.** `time_utc_p` costs 31 Ir per call, the frame about 43: ≤ 0.5 M Ir (0.015%) on lobsters.
* **`String#length`.** Already a frameless `CCall` (5 Ir per call). An inline load for single-byte strings saves a
  few instructions: ~0.
* **`super` from a block.** 1.4–6k interpreter dispatches per iteration. Even at several hundred extra Ir each,
  that is ≤ 0.05%. It also sits next to k0kubun's rows 45–46 on [#1039](https://github.com/Shopify/ruby/issues/1039),
  so it stays held, as in the shortlist.

## Other C methods ZJIT calls with a frame

The top 20 by `CCallWithFrame` plus fallback calls per iteration on the stats build, with every interpreter call
of the method for comparison (`other` = calls ZJIT did not make: from C or from uncompiled code):

| Method | railsbench | lobsters | shipit | dispatch | owner / note |
| --- | ---: | ---: | ---: | --- | --- |
| `Hash#fetch` | 145,474 + 41,805 fb | 147,536 + 6,533 fb | 409,571 + 11,946 fb | frame; fallbacks are `complex_arg_pass` (`Env#fetch_header(&block)`) | [Shopify/ruby#1086](https://github.com/Shopify/ruby/issues/1086) (nithya4005, two-argument case) |
| `Hash#key?` | 125,384 | 45,122 | 169,055 | frame | unowned; [#16019](https://github.com/ruby/ruby/pull/16019) (StringExact keys) closed unmerged over `default`/`default_proc` |
| `Regexp#match?` | 96,612 | 27,197 | 17,736 | frame | not leaf (timeouts, recompiles) |
| `Hash#[]` (non-inlined part) | 63,892 | 10,429 | — | frame for polymorphic receivers | Z3 |
| `Hash#delete` | 62,027 | 28,226 | 52,698 | frame | can call `#hash`/`#eql?` |
| `Kernel#dup` | 60,215 | 19,232 | 49,533 | frame | **this bet** |
| `Array#any?`, `#all?` | 57,553, 28,000 | 17,402 | 65,200 | frame | block → Ruby code |
| `Symbol#end_with?` | 47,844 | 10,186 | — | frame | |
| `ERB::Util.html_escape` | 42,172 | 22,774 | — | frame | allocates |
| `Hash#[]=` (non-inlined part) | 41,870 | — | — | frame | |
| `ActiveSupport::OrderedOptions#_get` | 41,805 fb | 278 fb (Lobsters app) | — | fallback: private method without FCALL | not a C-path issue |
| `String.new`, `String#include?`, `Array#join`, `MatchData#[]`, `String#b`, `String#sub!`, `Set#include?`, `Array#include?`, `Kernel#instance_of?` | 10–40k each | | | frame | |
| `ObjectSpace::WeakKeyMap#[]`, `Array#reverse_each`, `Array#|`, `Kernel#Array`, `Enumerable#flat_map`, `Kernel#__method__`, `Process.clock_gettime` | | | 16–49k each (shipit) | frame | |

The census apps have the same leaders (Hash#fetch, Hash#key?, String#<<, String#include?, String#match?,
html_escape, `MatchData#[]` on Campfire). For an ordinary C method the saving from a frameless call is the frame:
about 43 Ir per call (`Time#utc?`: 74 Ir per call, 31 of them `time_utc_p`). `Hash#key?` would be the next best at
5.4 M / 1.9 M / 7.3 M Ir per iteration (0.11% / 0.06% / 0.19%), and only for keys whose `hash`/`eql?` cannot call
Ruby. `Hash#fetch` is larger but owned. **`Kernel#dup` saves ~650 Ir per call**: fifteen times what a frame is
worth, because its cost is two method calls made through `rb_funcall`, not its own frame.

Full tables: `ruby bench/upstream/zjit_cfunc_dispatch.rb railsbench=STATS.json,CALLS.json …` over the receipts.

## Who receives `dup`

`ruby_bench_dup_receivers.rb`, per iteration:

| Receiver class | `initialize_dup` | `initialize_copy` | railsbench | lobsters | shipit |
| --- | --- | --- | ---: | ---: | ---: |
| `Hash` | Kernel (C) | Hash (C) | 28,231 | 9,756 | 28,088 |
| `Array` | Kernel (C) | Array (C) | 29,984 | 8,124 | 16,755 |
| `ActiveRecord::Result` | Kernel (C) | Result (Ruby) | 2,000 | 1,003 | 4,275 |
| `ActiveRecord::PredicateBuilder` | Kernel (C) | Kernel (C) | — | 192 | 881 |
| `ActiveModel::Attribute::FromDatabase` | Attribute (Ruby) | Kernel (C) | — | 145 | — |

90–97% of calls go to `Hash` and `Array`, whose two hooks are both builtin C methods.

## Prior work

* **`Kernel#dup`:** [#18872](https://github.com/ruby/ruby/pull/18872) (tekknolagi, merged) returns immediates and
  other special objects without a call. Nothing else: no ruby/ruby PR mentions `rb_obj_dup`, `initialize_copy` or
  `initialize_dup` with ZJIT, and no row of k0kubun's 83-row lobsters burndown
  ([#1039](https://github.com/Shopify/ruby/issues/1039)) touches `dup`, copy hooks or C method dispatch for them
  (closest: row 13 *Retry inlining annotated builtins after type inference*, row 63 *Elide inline frames around
  leaf builtin calls*). #1058 has no assignee or comments.
* **Open inline-cfunc PRs** for the pattern: [#18753](https://github.com/ruby/ruby/pull/18753) (rafaelfranca,
  `String#force_encoding`, a new HIR instruction with an exit for unsupported cases),
  [#19434](https://github.com/ruby/ruby/pull/19434) (tenderlove, `Array#fetch` with two arguments),
  [#18959](https://github.com/ruby/ruby/pull/18959) (swebb, `Array#first`/`#last` moved to Ruby builtins). None of
  them touches `dup` or `match?`.
* **`String#match?`:** only nirvdrum's comment on #1059. No PR.

## Measurement prototype: `Kernel#dup` with builtin copy hooks

**What `rb_obj_dup` does.** It skips special objects, then allocates (`rb_hash_alloc_copy` for `T_HASH`, else
`rb_obj_alloc(rb_obj_class(obj))`), copies type bits, ivars and GC attributes (`init_copy`), then calls
`rb_funcall(dup, :initialize_dup, obj)`. Kernel's `initialize_dup` calls `rb_funcall(dup, :initialize_copy, obj)`.

**Design (prototype B, [`292cc979e5`](https://github.com/thomasklemm/ruby/commit/292cc979e5)).**

* At the point where ZJIT would emit `CCallWithFrame Kernel#dup`, it asks a new C helper,
  `rb_jit_obj_dup_func(dup_cme, recv_class, …)`, whether a direct path applies. It applies when:
  * the `dup` entry is the basic C `rb_obj_dup`;
  * `recv_class` is a class (not a singleton class);
  * `initialize_dup` resolves to Kernel's basic C entry (`rb_obj_init_dup_clone`);
  * `initialize_copy` resolves to the basic C entry of exactly one of Kernel (`rb_obj_init_copy`), Hash or Array
    (`rb_ary_replace`). Each is checked by owner, the basic flag, arity and function pointer.
* If it applies, ZJIT emits `PatchPoint MethodRedefined(recv_class, initialize_dup)` and
  `PatchPoint MethodRedefined(recv_class, initialize_copy)`, then the same `CCallWithFrame` with the cfunc swapped
  for one of three helpers. Each helper does what `rb_obj_dup` does but calls that copy function directly.
* The receiver is already guarded to the profiled class, and the singleton-class and redefinition guards for `dup`
  are unchanged.
* **No new HIR instruction.** The patch is about 60 lines of C and 20 of Rust.

**Why it stays exact.**

* **Flags, ivars and singleton classes:** allocation and `init_copy` are `rb_obj_dup`'s own code. `dup` never
  copies a singleton class or frozen state, and neither does the prototype (tested: frozen Object/Hash/Array/Struct
  receivers give unfrozen copies with the ivars; a singleton method is not copied).
* **Overrides:** any Ruby or C override of either hook, in the class, a subclass, a prepended or included module,
  or by reopening Kernel/Hash/Array, resolves to another method entry. The direct path then does not apply at
  compile time. If the override comes after compilation, the patch point invalidates the code. Refinements do not
  apply to `rb_funcall`, so they do not apply here either.
* **TracePoint:** enabling a C-call hook invalidates ZJIT code. The helpers also check `ruby_vm_c_events_enabled`
  and then call the hooks as methods, so `c_call`/`c_return` events for `initialize_dup`/`initialize_copy` are
  identical.
* **Backtraces:** the `Kernel#dup` frame is still pushed by `CCallWithFrame`. The two hook frames are skipped. Those
  three hooks cannot raise on a fresh, unfrozen copy of the same class, apart from memory errors. Only interrupt
  checks inside the two skipped calls move, as with any ZJIT inlining.

**Checks.**

* Two scripts compare output with master (interpreter and `--zjit-call-threshold=1`/`2`), and every output is
  identical:
  * `Hash` with `default_proc` and `compare_by_identity`, a frozen Array, ivars, a singleton method, a Hash
    subclass, a prepended `initialize_copy`, a user `initialize_dup`, an Array subclass `initialize_copy`, a
    refinement, TracePoint `c_call` events, `Object.prepend` of a copy hook, a reopened `Hash#initialize_copy` and
    `Array#initialize_dup`, and `BasicObject#dup` (NoMethodError);
  * the same changes made after the call site was compiled: `Hash.prepend`, `SubA.include`, a reopened `SubA`, a
    reopened `Object#initialize_dup`, a reopened `Array#initialize_copy`.
* The HIR shows the two patch points before `CCallWithFrame :Kernel#dup` for Hash, Array and Object receivers.
* `test_object`, `test_hash`, `test_array`, `test_clone`, `test_settracefunc` and `test_refinement` with
  `--zjit-call-threshold=1`: 1,172 tests, 0 failures. `make btest RUN_OPTS=--zjit-call-threshold=1`: PASS all 2,141 tests.

**Numbers.** Microbenchmark, Ir per `dup` call:

| receiver | master | prototype B | change |
| --- | ---: | ---: | ---: |
| `{a:, b:, c:}` | 1,309 | 643 | −51% |
| `[1, 2, 3]` | 1,212 | 546 | −55% |
| `Object` with 2 ivars | 1,279 | 613 | −52% |
| `String` (own `dup`, control) | 247 | 248 | 0 |

ruby-bench, Callgrind, GC-excluded Ir per iteration (millions), two runs each:

| Benchmark | master a / b | prototype B a / b | change (means) | master A/A |
| --- | ---: | ---: | ---: | ---: |
| railsbench | 4,828.1 / 4,822.5 | 4,789.1 / 4,796.1 | **−0.68%** | 0.12% |
| lobsters | 3,271.0 / 3,273.3 | 3,256.2 / 3,255.2 | **−0.50%** | 0.07% |
| shipit | 3,777.2 / 3,774.8 | 3,740.5 / 3,743.8 | **−0.90%** | 0.06% |

The railsbench function diff (−39.1 M per 3 iterations) is the two skipped calls: `rb_funcallv_scope` −9.8 M,
`vm_call0_body` −9.0 M, `vm_call0_cc` −7.1 M, `vm_push_frame` −4.9 M, `rb_obj_dup`/`rb_obj_init_dup_clone` −3.5 M.
The new helpers add 2.4 M.

**Prototype A**, rejected: the same direct call in C inside `rb_obj_dup_setup`, which helps the interpreter and both
JITs ([`201100143c`](https://github.com/thomasklemm/ruby/commit/201100143c)). It has to look up both hooks on
every call, which costs back about 40% of the saving (`callable_method_entry_or_negative` +12.9 M,
`rb_callable_method_entry` +4.8 M on shipit). It came to −0.49% on railsbench and −0.41% on shipit, one run each.
A per-class cache would close the gap but needs its own invalidation. ZJIT's patch points already provide that.

**Toward a PR (not started).** The hook table could cover more classes (`Set`, `Struct`, `Data`) with the same
check. Tests would be HIR snapshots for the patch points and codegen tests for each redefinition case above. Per
the shortlist, the comment comes first.

## Comment draft for Shopify/ruby#1058 (not posted)

> We measured `Kernel#dup` on Rails and would like to take this one, unless it is already on someone's branch.
>
> On master 9f2e54518e, ZJIT calls `Kernel#dup` as a `CCallWithFrame` 60k / 19k / 50k times per iteration on
> railsbench / lobsters / shipit (and 150–230 times per operation in Fizzy, Lobsters and Campfire). 90–97% of the
> receivers are `Hash` and `Array`, whose `initialize_dup` and `initialize_copy` are the builtin C methods. About
> half of each call is `rb_obj_dup` re-entering the VM twice through `rb_funcall` (`initialize_dup`, then
> `initialize_copy`): `rb_obj_dup` is 1.9% / 0.8% / 1.7% of instructions inclusive.
>
> Prototype (measurement only): when the profiled class resolves `initialize_dup` to Kernel's and
> `initialize_copy` to Kernel's, Hash's or Array's builtin, ZJIT emits `MethodRedefined` patch points for both
> lookups and swaps the cfunc of the same `CCallWithFrame` for a helper that does `rb_obj_dup`'s allocation and
> `init_copy`, then calls the copy function directly. It falls back to `rb_funcall` while C call hooks are enabled.
> Prepend/include/reopen of either hook, before or after compilation, refinements, TracePoint and frozen receivers
> give the same results as master.
>
> | | master | prototype |
> | --- | ---: | ---: |
> | Ir per `{a:, b:, c:}.dup` | 1,309 | 643 |
> | Ir per `[1, 2, 3].dup` | 1,212 | 546 |
> | railsbench Ir/iteration (GC excluded) | 4,825 M | −0.68% |
> | lobsters Ir/iteration | 3,272 M | −0.50% |
> | shipit Ir/iteration | 3,776 M | −0.90% |
>
> (Callgrind, A/A ≤ 0.12%.) Branch: thomasklemm/ruby `zjit-dup-proto`. If this shape is OK (patch points plus a
> swapped cfunc, rather than a new HIR instruction or moving `dup` into Ruby), we would open a PR with HIR snapshot
> and redefinition tests.
>
> For comparison, the other unowned C paths we priced on the same runs: `String#match?` (#1059) ≤ 0.05% (Onigmo
> dominates; the coercion is ~25 instructions), `Time#utc?` (#1060) ~0.015%, `String#length` (#808) is already a
> frameless call.

## Not done or not claimed

* No wall-time claim, only instruction counts.
* No YJIT comparison.
* The stats build's fallback counter reads the call cache after the fallback returns. A call that raises is not
  counted, and the count is "reached a C method", not "would have inlined".
* `Hash#key?` (next best, ~0.1–0.2%) is recorded, not built.
