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

The #1058 comment was posted on 2026-11-03 with the patch-point shape
([comment](https://github.com/Shopify/ruby/issues/1058#issuecomment-6601903455)). tekknolagi answered that it needs
more design work: "figuring out what stops us from moving everything to just Ruby code". That question is answered
in [`Kernel#dup` in Ruby](#kerneldup-in-ruby-tekknolagis-question): it works and is exact apart from the observable
changes that `Array#each` under a JIT already has. It must stay C in the interpreter, it needs `send(:sym)` support
in ZJIT ([#19583](https://github.com/ruby/ruby/pull/19583)), and on two of three benchmarks its inlined patch points
cost more than they save until ZJIT recompiles invalidated code.

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

## Comment for Shopify/ruby#1058 (posted 2026-11-03 without the last paragraph)

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

## `Kernel#dup` in Ruby (tekknolagi's question)

*2026-11-03, after tekknolagi's reply on #1058.* What stops `Kernel#dup` from being plain Ruby, so that ZJIT sees
ordinary sends instead of a special case?

**Answer.** It can be written in Ruby and nothing semantic blocks it. Three conditions decide whether it pays:

1. **Keep the C method in the interpreter.** In the interpreter the Ruby version costs +27% per call and +0.25% to
   +0.54% instructions on Rails. It should therefore be defined only under a JIT (`with_jit`), as `Array#each`,
   `#map` and `Integer#downto` already are.
2. **ZJIT has to compile `__send__(:initialize_dup, ...)`.** `initialize_dup` is private, and Ruby can call a
   private method on another object only through `__send__`. ZJIT on master sends every `send`/`__send__` through
   the dynamic fallback, so the Ruby version makes ZJIT slower (+0.06% to +0.56%). With tekknolagi's
   [#19583](https://github.com/ruby/ruby/pull/19583) (`send(:symbol)`), ZJIT inlines `dup` and `initialize_dup` into
   the caller. `initialize_copy` then becomes a monomorphic `CCallWithFrame :Hash#initialize_copy` at each call site,
   which is the shape we hand-built in prototype B, here produced by ZJIT's existing machinery.
3. **Inlined patch points must survive invalidation.** On top of #19583, railsbench gains a further −0.76%, better
   than prototype B. Lobsters only gains −0.08% and shipit loses +0.58%: once the app `include`s a module that
   defines `initialize_dup` (lobsters: `Search` includes ActiveModel), the `MethodRedefined(…, initialize_dup)` patch
   points inlined into hot callers (`url_options`, `url_for`) are invalidated. Their final versions then side-exit
   on every call: +3.2k exits per iteration on lobsters, +3.8k on shipit. This needs ZJIT to recompile invalidated
   final versions (k0kubun's [#19617](https://github.com/ruby/ruby/pull/19617), Shopify/ruby#1039 row 19).

YJIT gets the gain without changes: it already compiles `__send__(:sym)`, and `Hash#dup` drops from 1,296 to
743 Ir per call.

### Prototype

On the fork, both based on master [`9f2e54518e`](https://github.com/ruby/ruby/commit/9f2e54518e) like the rest of
this page:

* **R:** [`thomasklemm/zjit-dup-ruby`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-dup-ruby)
  ([`98505eed26`](https://github.com/thomasklemm/ruby/commit/98505eed26)), `kernel.rb` +38 and `object.c` +17
  lines.
* **R + #19583:** [`thomasklemm/zjit-dup-ruby-send`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-dup-ruby-send)
  ([`57c03453e0`](https://github.com/thomasklemm/ruby/commit/57c03453e0)): R plus #19583's two commits, with
  conflicts resolved against master's `lookup_cme` change. The control build P is the same #19583 commits without R.

```ruby
module Kernel                       # a separate module body (see below)
  with_jit do                       # Z7_DUP_RUBY=1 also installs it in the interpreter, for pricing
    undef :dup
    def dup
      Primitive.attr! :c_trace
      return self if Primitive.cexpr!('RBOOL(special_object_p(self))')
      copy = Primitive.rb_obj_dup_alloc_copy   # rb_obj_dup's allocation + init_copy (shape, ivars, flags)
      copy.__send__(:initialize_dup, self)     # private: rb_funcall ignores visibility, __send__ is the Ruby spelling
      copy
    end

    undef :initialize_dup
    private def initialize_dup(orig)
      Primitive.attr! :c_trace
      initialize_copy(orig)
      self
    end
  end
end
```

* `Primitive.rb_obj_dup_alloc_copy` is the first half of `rb_obj_dup` (`rb_hash_alloc_copy` for `T_HASH`, else
  `rb_obj_alloc(rb_obj_class(obj))`, then `init_copy`). It copies no singleton class and no frozen state. `rb_obj_dup`
  stays as is for C callers and for the interpreter.
* **Pitfall:** the definitions must live in their own `module Kernel` body. `kernel.rb` ends in `module_function`
  scope, and a `with_jit` block runs later with that scope's visibility. The first build made `dup` a private module
  function under `--zjit`.
* **`clone` is not done.** It shares `init_copy`, but `initialize_clone` takes `freeze:` and the singleton class is
  copied, so it is not free. It is 2–8k calls per iteration, against 19–60k for `dup`.

### What changes, and what blocks

[`obs.rb`](data/zjit-cfunc-paths/dup-in-ruby.tar.gz) prints 33 observations. Master gives the same output in the
interpreter, under YJIT and under ZJIT. R gives the same output in all three modes (Ruby version active), and R in
the interpreter without `Z7_DUP_RUBY` matches master. Differences from master:

| Area | Master (C) | Ruby version | Precedent / verdict |
| --- | --- | --- | --- |
| TracePoint | `c_call`/`c_return` for `dup`, `initialize_dup`, `initialize_copy`, path = caller's file | `call`/`return` for `dup` and `initialize_dup` with path `<internal:kernel>`; `c_call initialize_copy` with path `<internal:kernel>` | same as `Array#each` under `--zjit` today (`[:call, :each, "<internal:array>"]`); `:c_trace` no longer changes events, only sets the basic flag |
| `TracePoint#enable(target: Kernel.instance_method(:dup))` | `ArgumentError: specified target is not supported` | works | new capability |
| `Method#source_location` | `nil` | `["<internal:kernel>", N]` | same as `Array#each` under a JIT |
| `Method#parameters` of `initialize_dup` | `[[:req]]` | `[[:req, :orig]]` | cosmetic; owner and arity unchanged |
| Backtrace / `caller` from inside `initialize_copy` | `…'Kernel#initialize_dup'`, `…'Kernel#dup'` | only `…'Kernel#dup'` | an internal frame called from an internal frame is dropped; all paths still show the caller's file and line |
| Class that redefines `__send__` | `dup` unaffected | `dup` calls the user's `__send__` | the only semantic difference; Ruby already warns \"redefining '__send__' may cause serious problems\" |

Identical in every mode: refinements of `initialize_copy`/`initialize_dup` in the caller (not applied, as with
`rb_funcall`); special constants (Integer, Symbol, nil, true, Float, Bignum, Rational, Complex, dynamic Symbol);
frozen receivers, which give unfrozen copies with their ivars; singleton methods and `extend`ed modules, which are
not copied; chilled strings; a custom `self.allocate`, which is not called; T_DATA and builtin copy hooks (Time with
offset, Random, Set, Struct, Data, Enumerator, Regexp, Range, UnboundMethod); Hash `default`, `default_proc`,
`compare_by_identity`; Array subclasses; user `initialize_dup`/`initialize_copy` with `super`; `undef_method
:initialize_dup` (same NoMethodError message); `method_missing`; a public `initialize_dup`; `super` from a user
`dup`; a prepended `dup`; `clone`; `BasicObject` via `bind_call`; inside a Ractor; and Ractor-shareable receivers.

**Tests:**

* `test_object`, `test_clone`, `test_hash`, `test_array`, `test_settracefunc`, `test_refinement` and
  `test_backtrace` in three configurations (interpreter with C `dup`, `--zjit-call-threshold=1`, and the Ruby
  version forced into the interpreter): 1,204 tests, 36,816 assertions, 0 failures on both R and R + #19583.
* ruby/spec `core/kernel/{dup,clone,initialize_dup,initialize_copy}_spec.rb`: 54 examples, 0 failures in each
  configuration.
* `make btest RUN_OPTS=--zjit-call-threshold=1` on R + #19583: PASS all 2,141.
* None of these tests notices the differences in the table above.

### Cost

**Per call**, Callgrind Ir per call, net of the empty loop, 20,000 calls after warmup, call threshold 2. Master's
repeat run gives identical numbers (±1).

| `dup` of | master interp / YJIT / ZJIT | B (patch points) ZJIT | R interp¹ / YJIT / ZJIT | R + #19583 ZJIT |
| --- | --- | ---: | --- | ---: |
| `{a: 1, b: 2, c: 3}` | 1,487 / 1,296 / 1,309 | 643 | 1,889 / 743 / 1,555 | 742 |
| `[1, 2, 3]` | 1,390 / 1,199 / 1,211 | 546 | 1,782 / 636 / 1,448 | 635 |
| `Object.new` | 1,245 / 1,107 / 1,111 | 445 | 1,637 / 547 / 1,348 | 530 |
| `String` (own `dup`, control) | 426 / 227 / 247 | 248 | 426 / 227 / 248 | 247 |

¹ Ruby version forced into the interpreter (`Z7_DUP_RUBY=1`). Under `with_jit`, the interpreter keeps the C method
and R gives master's numbers (1,487 / 1,390 / 1,245).

**HIR**, R + #19583, `def d(x) = x.dup` with a Hash, call threshold 2. Everything is inlined into `d`:

```
PatchPoint MethodRedefined(Hash, dup)
v42:HashExact = GuardType v12, HashExact recompile
v50 = InvokeBuiltin <inline_expr>, v42                      # special_object_p
v67 = InvokeBuiltin rb_obj_dup_alloc_copy, v42
PatchPoint MethodRedefined(Hash, __send__)                   # #19583's rewrite
PatchPoint NoSingletonClass(Hash)
PatchPoint MethodRedefined(Hash, initialize_dup)
v95:HashExact = GuardType v67, HashExact recompile           # the copy's type is not known statically
PatchPoint MethodRedefined(Hash, initialize_copy)
v122 = CCallWithFrame v95, :Hash#initialize_copy, v42
```

Without #19583 the same site keeps `Send v67, :__send__ … # Send: unsupported optimized method type Send`, and
`initialize_dup` is compiled as a separate function whose `initialize_copy` call sees every receiver class in the
app.

The remaining ~100 Ir per call against B is the guard on the copy, which `rb_obj_dup_alloc_copy` could type as the
receiver's class, and the inline frames for `dup` and `initialize_dup` (`vm_write_jit_frame` +34k per lobsters
iteration).

**Rails**, ruby-bench railsbench / lobsters / shipit, Callgrind, GC-excluded Ir per iteration (millions), two runs
per build, harness as above. The master and B rows are the runs above (same builds, same orb):

| Build | railsbench | lobsters | shipit | A/A |
| --- | ---: | ---: | ---: | ---: |
| master, ZJIT | 4,828.1 / 4,822.5 | 3,271.0 / 3,273.3 | 3,777.2 / 3,774.8 | ≤ 0.12% |
| B (patch points) | −0.68% | −0.50% | −0.90% | ≤ 0.15% |
| R (Ruby `dup`, master ZJIT) | **+0.56%** | +0.06% | **+0.38%** | ≤ 0.14% |
| P (master + #19583, control) | −0.66% | −0.42% | −0.59% | ≤ 0.09% |
| R + #19583 | −1.42% | −0.50% | −0.01% | ≤ 0.20% |
| *R + #19583 vs P (the `dup` effect)* | ***−0.76%*** | ***−0.08%*** | ***+0.58%*** | |
| master, interpreter | 7,365.9 / 7,360.0 | 4,374.6 / 4,374.6 | 6,106.5 / 6,110.3 | ≤ 0.08% |
| Ruby `dup` forced into the interpreter | **+0.54%** | **+0.25%** | **+0.45%** | ≤ 0.18% |

**Why lobsters and shipit do not pay** (`--zjit-stats`, per iteration):

| | master | B | P | R + #19583 |
| --- | ---: | ---: | ---: | ---: |
| lobsters `exit_patchpoint_method_redefined` | 382 | 382 | 382 | **3,624** |
| lobsters `exit_patchpoint_no_singleton_class` | 0 | 0 | 0 | **492** |
| shipit `exit_patchpoint_method_redefined` | 0 | 0 | 0 | **3,817** |
| shipit dynamic sends | 1,709,365 | 1,709,365 | 1,686,572 | 1,734,553 |

* **Where the exits are:** with `--zjit-trace-exits --zjit-trace-invalidation` on lobsters, the extra exits are
  `PatchPoint(MethodRedefined(Hash, initialize_dup))` in the inlined `Kernel#dup` of
  `ActionController::UrlFor#url_options` and `RouteSet#url_for`. A smaller set is `NoSingletonClass(Array)` in
  `Relation#to_ary` and `build_join_buckets`.
* **What invalidated them:** that CME was invalidated once, by `Module#append_features` under
  `ActiveSupport::Concern#append_features` from `class Search` (lobsters `app/models/search.rb:2`, which includes
  ActiveModel modules that define `initialize_dup`).
* **Why it costs every iteration:** the invalidated versions are final and keep side-exiting into the
  interpreter. On lobsters, the function diff against P shows the intended saving (`rb_funcallv_scope`, `vm_call0_*`,
  `vm_push_frame`, `rb_obj_dup` −11 M per iteration), offset by `vm_exec_core` +3.9 M, `malloc` +2.1 M and frame
  materialization.
* **Why B does not hit it:** B guards the same two lookups, but its exit counts equal master's. That is plausibly
  because its patch points sit in fewer compiled versions, but it was not verified.
* **Shipit has the same signature, plus a second cost:** a trace shows the same
  `MethodRedefined(Hash|Array, initialize_dup)` exits in `url_for`, `url_options` and `Relation#to_ary` (the
  invalidations come from `ActiveSupport::Concern#append_features`). Where a `dup` call site is itself megamorphic
  (`Relation#values`, `Journey::Format#evaluate`, `QueryCache#cache_sql`), `Kernel#dup` is not inlined. Its one
  shared ISEQ then sees every receiver class, so its `__send__` is a megamorphic fallback and `initialize_dup`'s
  `initialize_copy` is a polymorphic fallback: +48k dynamic sends per iteration against P. The C method has neither
  problem, because it looks the hooks up per call.
* **Not reproduced in isolation:** a standalone script that includes `ActiveModel::Validations` after compiling a
  `dup` site does not exit, on any build. The mechanism above is observed in the traces, not reduced.

### Which shape to propose

Ruby `dup` under `with_jit`, after #19583, is the cleaner design:

* no special case in ZJIT;
* YJIT benefits too;
* per call it comes within 15% of B.

As measured today it does not pay on two of three Rails benchmarks, because inlining the hooks' patch points into hot
callers makes them depend on recompiling invalidated code. Our proposal is:

* land the Ruby version behind `with_jit` once #19583 is in;
* re-measure it with #19617 (or another way to recompile invalidated final versions);
* keep B as the fallback if ZJIT should not depend on that.

### Reply draft for tekknolagi (not posted)

> Tried it: `dup` in kernel.rb (alloc + `init_copy` as a Primitive, then `copy.__send__(:initialize_dup, self)`;
> `initialize_dup` calls `initialize_copy`). It passes ruby/spec and the related test-all files; the visible changes
> are those `Array#each` already has under a JIT, plus calling a user-redefined `__send__`. What stops it:
>
> 1. The interpreter must keep C (`with_jit`): +27% per call, +0.25–0.54% Rails Ir otherwise.
> 2. It needs #19583 (`initialize_dup` is private). Then ZJIT inlines both into one monomorphic
>    `CCallWithFrame Hash#initialize_copy` per site.
> 3. Rails `include`s of modules defining `initialize_dup` invalidate those inlined patch points, final versions keep
>    exiting, and non-inlined `dup` goes megamorphic.
>
> | Ir | master | patch points | Ruby + #19583 |
> | --- | ---: | ---: | ---: |
> | `{a:,b:,c:}.dup` | 1,309 | 643 | 742 |
> | railsbench | | −0.68% | −0.76%¹ |
> | lobsters / shipit | | −0.50% / −0.90% | −0.08% / +0.58%¹ |
>
> ¹ vs master+#19583. Ruby version once #19583 and recompiling invalidated versions land? Branch: thomasklemm/ruby
> `zjit-dup-ruby-send`.

## Not done or not claimed

* No wall-time claim, only instruction counts.
* YJIT is compared only for the Ruby version (per call).
* The stats build's fallback counter reads the call cache after the fallback returns. A call that raises is not
  counted, and the count is "reached a C method", not "would have inlined".
* `Hash#key?` (next best, ~0.1–0.2%) is recorded, not built.
