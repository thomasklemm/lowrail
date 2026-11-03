# JIT parity census: where YJIT and ZJIT allocate more than the interpreter

Bet L2. The census-4 harness (nine apps, 97 request, job and mailer workloads on Rails main) ran on a fresh
ruby/ruby master build under the interpreter, YJIT and ZJIT. Per-site allocation differences (JIT minus
interpreter) were attributed to source lines and ranked by apps and workloads reached.

**On master, YJIT allocates 15 to 17 more objects than the interpreter in the median workload, and ZJIT 6 to 7
more.** Four exact changes account for all of YJIT's Rails-side difference. Together they leave the median YJIT
workload one object *below* the interpreter. One is the already-open #19655; three are new YJIT fixes, each one
commit on master in the fork. After Codex Astra reviews, A is open as
[#19664](https://github.com/ruby/ruby/pull/19664) and B as [#19665](https://github.com/ruby/ruby/pull/19665)
(2026-11-03); C is reviewed and waiting to be opened. See [Review rounds](#review-rounds).

| # | Branch | Commit | Pattern (Rails site) | YJIT per call, interp / master / fix | ruby-bench YJIT allocations |
| --- | --- | --- | --- | --- | --- |
| A | [`thomasklemm/yjit-splat-rest-subseq`](https://github.com/thomasklemm/ruby/tree/thomasklemm/yjit-splat-rest-subseq) | [`d531b19421`](https://github.com/thomasklemm/ruby/commit/d531b19421621777ef3a4767917771439903c28f), [#19664](https://github.com/ruby/ruby/pull/19664) | splat into lead + rest: every `where(...)` → `where!(opts, *rest)` (`query_methods.rb:1284`) | `where(h)` 2 / 3 / 2 | railsbench −0.07%, lobsters −0.10%, shipit −0.13% |
| B | [`thomasklemm/yjit-objtostring-fixnum-module`](https://github.com/thomasklemm/ruby/tree/thomasklemm/yjit-objtostring-fixnum-module) | [`89472a2a77`](https://github.com/thomasklemm/ruby/commit/89472a2a771790112feef19127862e714b4b769c), [#19665](https://github.com/ruby/ruby/pull/19665) | interpolating an Integer or Module: `"#{self} Update"`/`"#{self} Create"` (`persistence.rb:236/229`), `"t#{i}_r#{j}"` (`join_dependency.rb:188`) | `"t#{i}_r#{j}"` 1 / 3 / 1, `"#{klass} Update"` 1 / 2 / 1 | shipit −0.21%, lobsters −0.03%, railsbench 0.00% |
| C | [`thomasklemm/yjit-splat-rest-reuse`](https://github.com/thomasklemm/ruby/tree/thomasklemm/yjit-splat-rest-reuse) | [`70b8e23a8f`](https://github.com/thomasklemm/ruby/commit/70b8e23a8f64e4c435874584d12136308df07519) | splat the rest parameter can own: `def process_action(*) = super` chain (`params_wrapper.rb:264`, `instrumentation.rb:74`), `touch_later(*)` (`optimistic.rb:72`), `f(*a, b)` | controller `process_action` chain 2 / 5 / 3 (2 with #19655) | railsbench −0.23%, lobsters −0.03%, shipit −0.01% |
| — | open [#19655](https://github.com/ruby/ruby/pull/19655) | `3db46445ca` | empty anonymous rest: `Relation.create(model, ...)` (`core.rb:481`), `SQLString#initialize(*)` (Arel collectors, `abstract_adapter.rb:1426/1432`), `capture(*, **, &)` | `Post.connection.send(:collector)` lead | railsbench −0.12%, lobsters −0.55%, shipit −1.10% |

All four stacked: railsbench **−0.42%**, lobsters **−0.71%**, shipit **−1.45%** objects per iteration, against an
A/A difference of at most 0.004%. Allocation counts only; no timing claim (see [Limits](#limits)).

ZJIT keeps two broad differences that these changes do not address: interpolation (Shopify/ruby#1091, a regression
from #17499) and `URI.for(*split(uri), self)` in the uri gem, which is +18 objects per operation on average and
accounts for nearly all of ZJIT's remaining mean. Both are root-caused [below](#zjit-remaining).

## Pins and method

* **Ruby:** ruby/ruby master [`b51db981f6`](https://github.com/ruby/ruby/commit/b51db981f642115e0d77f4a926c7f0209f4871ab),
  checked with `git ls-remote` on 2026-11-03 (still master when the fix branches were pushed). Release build,
  `configure --enable-yjit --enable-zjit`, Rust 1.99.1. Fix branches are built the same way.
* **Rails:** canonical main [`5810776eec`](https://github.com/rails/rails/commit/5810776eecc5b2e50b58e81ee0c26c02c718fdf0)
  (main after the census-4 merges, #59544), bundled as a `github:` ref in every app.
* **Harness:** census 4 unchanged ([`rails_main_census_4.rb`](../../bench/upstream/rails_main_census_4.rb),
  [`census_4_workloads.rb`](../../bench/upstream/census_4_workloads.rb)), plus a `zjit` mode and a `stats` command.
  Every workload gets 50 warmup operations, three GC-enabled windows of 20, then 10 traced operations attributed by
  allocation file and line. Runner: [`script/jit-parity-census`](../../script/jit-parity-census).
* **Apps:** the census-4 nine (Fizzy on SQLite and MySQL 8.4.10, CodeTriage and PingCRM on PostgreSQL 15), at the
  census-4 source pins. Overlays for Ruby master and the new Rails pin are dependency-only
  ([fixtures/corpus/jit-parity-census](../../fixtures/corpus/jit-parity-census)): `.ruby-version` 4.1.0.dev,
  Writebook redcarpet 3.6.0 → 3.6.1 (3.6.0 uses `Data_Get_Struct`, which master removed), Lobsters commonmarker
  2.6.3 → 2.10.1 and stackprof 0.2.27 → 0.2.28 (native builds fail on master). CodeTriage's CI `database.yml`
  gained a `production` entry for a local `triage_production` database. Campfire and Writebook need Redis and
  CodeTriage memcached, run as orb services.
* **Modes:** interpreter, `--yjit`, `--zjit`, each run twice (`base`, `base2`) for A/A.
* **Ranking:** [`jit_parity_rank.rb`](../../bench/upstream/jit_parity_rank.rb) subtracts the interpreter's
  objects per operation from the JIT's for every source line in every workload (any file: Rails, gems, app, Ruby).
  A line *reaches* a workload when the JIT allocates at least 0.5 more objects per operation there. Lines are
  tiered by apps reached (≥ 7, 5–6, 3–4, 2, 1) and ranked by mean extra objects per operation over all 97.
* **Counters:** after warming every workload, `RubyVM::YJIT.reset_stats!`/`RubyVM::ZJIT.reset_stats!`, then 20
  operations of each workload ([`jit_parity_stats.rb`](../../bench/upstream/jit_parity_stats.rb)). ZJIT fallback
  and side-exit sites come from `--zjit-trace-fallbacks-sample-rate=20 --zjit-trace-exits-sample-rate=20`, parsed
  from the Fuchsia trace by [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb).
* **ruby-bench** [`73918b2`](https://github.com/ruby/ruby-bench/commit/73918b2), headline railsbench, lobsters and
  shipit, YJIT, with an allocation harness ([`ruby_bench_allocs.rb`](../../bench/upstream/ruby_bench_allocs.rb):
  10 warmup iterations, median objects allocated over 5). Runs are sequential and interleaved, two rounds of
  every build on every benchmark, master twice per round. Running them in parallel was discarded: the lobsters
  copies share `tmp/cache` and raised HTTP 500s.

### A/A

| | Median workload delta | ≥ +1 / ≤ −1 objects (of 97) |
| --- | ---: | --- |
| interpreter, base2 − base | +0.0 | 13 / 24 |
| YJIT, base2 − base | +0.1 | 37 / 16 |
| ZJIT, base2 − base | +0.0 | 23 / 18 |
| **YJIT − interpreter (base / base2)** | **+14.8 / +17.0** | 86 / 6 · 93 / 2 |
| **ZJIT − interpreter (base / base2)** | **+6.0 / +6.8** | 76 / 12 · 79 / 9 |

No site in the JIT-vs-JIT A/A reaches more than four apps with a mean above 0.25 objects per operation; the uri
`common.rb:456/465` lines move in every comparison and are noise.

## Ranked divergences on master

`<internal:array>` lines (`:245`, `:271`, `:227`, `:247`, `:223`, `:241`) top both JIT rankings with up to +90
objects per operation, but they are an **attribution shift**, not extra work. With `with_jit`, `Array#each`, `#map`
and `#select` run as Ruby, so the result Arrays and block values they allocate are attributed to `array.rb` instead
of the caller's line. With all four changes, YJIT keeps these lines at the same size, yet its median workload is 1.0
object *below* the interpreter (mean −4.5). They are left out of the tables below.

### YJIT (base; base2 identical in order)

| Rank | Site | Apps / workloads | Extra objects/op | Cause | Disposition |
| ---: | --- | --- | ---: | --- | --- |
| 1 | AR `core.rb:481` `Relation.create(self)` → `create(model, ...)` | 9 / 86 | +22.7 | empty anonymous rest | #19655 |
| 2, 9 | AR `abstract_adapter.rb:1426/1432` collector, Arel `to_sql.rb:18` | 8 / 56, 3 / 27, 4 / 13 | +4.1, +4.1, +0.4 | `SQLString#initialize(*) = super` with no arguments: empty anonymous rest | #19655 (both JITs; the census-4 "collector 5 → 23" lead) |
| 3 | AR `query_methods.rb:1284` `spawn.where!(*args)` | 7 / 60 | +2.7 | splat to `where!(opts, *rest)`: dup, then slice | **A** |
| 4 | AP `instrumentation.rb:74` `super` in `process_action(*)` | 9 / 78 | +0.8 | splat into the next anonymous `process_action(*)`: dup | **C** |
| 5 | AP `params_wrapper.rb:264` `def process_action(*) = super` | 9 / 69 | +0.7 | same | **C** |
| 6 | AR `persistence.rb:236` `"#{self} Update"` | 6 / 18 | +0.8 | `objtostring` calls `Module#to_s` | **B** |
| 7 | AR `locking/optimistic.rb:72` `touch_later(*)` zsuper | 3 / 13 | +1.2 | splat into anonymous rest: dup | **C** |
| 8 | AR `persistence.rb:229` `"#{self} Create"` | 4 / 10 | +0.2 | `objtostring` | **B** |
| 10 | AV `capture_helper.rb:213` `capture(&block)` → `capture(*, **, &block)` | 4 / 15 | +0.4 | empty anonymous rest | #19655 |
| 11 | AV `tags/text_field.rb:17` | 4 / 8 | +0.1 | gone with C | **C** |
| 12 | AR `builder/belongs_to.rb:87` `record.touch_later(touch)` | 2–3 / 11–13 | +1.1 | touch_later chain | gone with the stack |
| — | AR `relation.rb:528` `"#{size}-…"`, `structured_event_subscriber.rb:63`, AT `rendering.rb:28`, warden `manager.rb:52` | 2 each | ≤ 0.4 | interpolation / anonymous rest | gone with the stack |
| — | `join_dependency.rb:188` `"t#{i}_r#{j}"` | 1 / 1 | +0.4 | `objtostring` on small Integers | **B** |

### ZJIT (base)

| Rank | Site | Apps / workloads | Extra objects/op | Cause | Disposition |
| ---: | --- | --- | ---: | --- | --- |
| 1 | AR `abstract_adapter.rb:1426/1432`, Arel `to_sql.rb:18` | 7 / 49, 3 / 27, 4 / 8 | +3.6, +4.1, +0.2 | empty anonymous rest | #19655 (ZJIT commit) |
| 2 | AR `persistence.rb:236`/`229` `"#{self} Update"` | **9** / 23 | +0.8 | `objtostring` became `Send :to_s` in #17499 | [ZJIT remaining](#zjit-remaining); Shopify/ruby#1091 open |
| 3 | uri `rfc3986_parser.rb:135` `URI.for(*self.split(uri), self)` | 5 / 26 | **+18.5** | fresh splat array (`SPLAT_MUT`) into `for(scheme, *arguments, default:)`: ZJIT builds a new rest Array, the interpreter beheads the caller's | [ZJIT remaining](#zjit-remaining) |
| 4 | AV `tags/text_field.rb:17` | 5 / 9 | +0.1 | | gone with #19655 |
| — | `join_dependency.rb:188`, `structured_event_subscriber.rb:63`, `relation.rb:528` | 1–2 | ≤ 0.4 | interpolation | Shopify/ruby#1091 |

`where!(*args)` does not diverge under ZJIT: it takes the splat elements with `ArrayAref` and packs only the
rest. The `process_action` chain diverges by one object, the empty anonymous rest that #19655 fixes; its `super`
hops are not direct-sent.

### After the changes

[`rank-stack-*.tsv`](data/jit-parity-census/receipts.tar.gz) is master + #19655 + A + B + C (local branch, not
pushed; it only stacks the four pushed commits). **YJIT: no site reaching two or more apps remains** apart from
`<internal:array>` and uri A/A noise. Median workload −1.0 versus the interpreter (21 workloads ≥ +1, 50 ≤ −1).
ZJIT (only #19655 applies): median +1.9, mean +18.2, almost all of it `rfc3986_parser.rb:135`.

Census effect of each change alone under YJIT (median workload delta against master, workloads with ≥ 1 object
fewer; A/A 16):

| Change | Median | ≤ −1 / ≥ +1 | Apps reached |
| --- | ---: | --- | ---: |
| #19655 | −11.0 | 82 / 7 | 9 |
| A | −1.0 | 50 / 18 | 8 |
| B | +0.0 | 36 / 33 | 8 |
| C | −0.5 | 45 / 33 | 8 |
| all four | **−17.3** | **92 / 4** | 9 |

B is small per request: one String per insert, update or join alias. Its shipit drop is clearer than any census
median.

## The census-4 and census-5 leads

* **`Class#new` with optional/rest `initialize`, 2 extra (4 with zsuper): not reproduced, a measurement artifact.**
  The census-4 probe measured one call at a `yield` site executed for the first time after the warmup loop. On
  both Ruby 4.0.7 and master, `Kw.new(1)` allocates 3 objects on that first execution under YJIT and 1 on the
  second, exactly as the interpreter does from the start. The extra objects belong to compiling the new site,
  not to the call. Measured over 10 or 100 calls, every shape matches the interpreter in YJIT and ZJIT. No
  `Class#new` line diverges in the census.
* **Arel collectors 5 → 23 under YJIT:** it is the empty anonymous rest of
  `Arel::Collectors::SQLString#initialize(*)` + `super` (`abstract_adapter.rb:1426/1432`), fixed by #19655 in both
  JITs. The probe's model classes had a different shape (`send(:collector)` is 7 / 7 / 7 on master).
* **`where!(opts, *rest)` called as `where!(*args)`, 2 Arrays vs 1:** fix A.
* **Interpolated Integer or Module (census 5):** fix B for YJIT. ZJIT has the same difference (`"t#{i}_r#{j}"`
  1 → 3, `"#{klass} Update"` 1 → 2 on master). Integer parity holds only for 0..9, which `rb_fix_to_s` returns
  from a static table; larger Integers allocate in every mode.

## Root causes and fixes

### A: YJIT duplicated a splat array before slicing it

`gen_send_iseq` with a splat call into a callee with a rest parameter always did
`rb_ary_dup(splat)`. When the splat also fills leading or optional parameters, it then took
`rb_yjit_rb_ary_subseq_length(copy, n)`, which is a new Array anyway. So `where!(*[h])` allocated 2 Arrays where
`vm_args.c` allocates 1. The fix skips the dup on that path; the slice reads the caller's array without modifying
it.

Tests: `test_splat_to_lead_and_rest` in `test/ruby/test_yjit.rb`: allocation counts for take-rest and
take-optional-rest, results for lead/optional/rest mixes, a `SubArray` splat that still yields an `Array` rest,
mutation of the rest not reaching the caller's array, and a 20-element heap array. It fails on master
(`[2, 2, 2]` allocations instead of `[1, 1, 1]`).

### C: YJIT duplicated splat arrays that the interpreter reuses

`setup_parameters_complex` sets `rest_dupped`, and then uses the splat array as the rest parameter without a copy,
in two cases. In the first, the caller built the array for this call (`VM_CALL_ARGS_SPLAT_MUT`, as in
`f(*a, b)`). In the second, an anonymous rest parameter receives exactly the splat elements, with no optional or
post parameters, no keywords and no `ruby2_keywords`, and can only pass them on as a splat. YJIT duplicated in
both cases. The fix mirrors the same conditions. A kwsplat reaching this point is always `**nil` (YJIT exits on
any other), so `f(*a, **nil)` reuses the array too, as vm_args.c does. A `**nil` method called without a kwsplat
still copies, like the interpreter.

Rails' controller stack forwards every action through `def process_action(*) = super`
(ParamsWrapper → Instrumentation, with `super` inside the instrumentation block → Rescue → Rendering →
`AbstractController::Base#process_action(...)`). Without Rails, that chain allocates 2 objects in the interpreter,
5 in YJIT, 3 with C, 4 with #19655, and 2 with both.

Tests, split after the second review:

* `test_splat_to_rest_without_dup` requires compiled calls: no side exits and `no_send_fallbacks`. That way a
  case cannot pass by falling back to the interpreter, which also allocates 0. It reads the allocation counter in
  a straight line, because one `yield` site would go megamorphic. Allocations:
  * an anonymous rest receiving a plain, frozen or `**nil` splat: 0;
  * a `**nil` method called with `**nil`: 0;
  * `f(*a, 3)`, an anonymous rest forwarded into a named rest, and a leading parameter: 1;
  * copies kept like the interpreter: a `**nil` method called without a kwsplat 1, an optional parameter 2,
    `ruby2_keywords` 2.

  It also checks results: callee mutation doesn't reach the caller's array (prepend and `SPLAT_MUT` paths), frozen
  splats, a `SubArray` that arrives as an `Array`, and a ruby2_keywords hash that stays the same object. Expected
  `[0,0,0,0,1,1,1,1,2,2]`. Master gives `[1,1,1,1,2,2,2,1,2,2]`. The pre-review head `e999828fc6`'s codegen gives
  `[0,0,1,1,…]`.
* `test_splat_to_rest_with_block_or_flagged_hash` keeps `exits: :any` and checks results and allocations only.
  It covers the cases YJIT doesn't compile here: block forwarding (`&block`, `yield(*)`) and an incoming
  ruby2_keywords-flagged hash at the end of the splat (it side-exits in `opt_send_without_block` on master and
  on C). Passes on both.

The two overlap in one `if` in `gen_send_iseq` and with #19655's `rb_get_iseq_flags_anon_rest` accessor (C adds
the same function, so whichever lands second drops that hunk). Resolving the overlap is mechanical: the local stack
uses `reuse_array || non_rest_arg_count < required_num + opt_num`.

### B: YJIT's `objtostring` called `to_s` on Integers and Modules

`vm_objtostring` interpolates a Fixnum with `rb_fix_to_s`, which returns a shared frozen String for 0..9, and a
Module with `rb_mod_name`, when the resolved `to_s` is the original `Integer#to_s`/`Module#to_s`. YJIT specialized
only Strings and Symbols, so everything else went through `gen_send_general` to a `to_s` that allocates a new
mutable String. The fix adds a branch with `jit_guard_known_klass` plus `assume_expected_cfunc` that `to_s` resolves
to `rb_int_to_s` (Fixnum) or `rb_mod_to_s` (Module). That is `vm_objtostring`'s `check_cfunc`. The first version
used `assume_method_basic_definition`, which accepts refined entries because `make_method_entry_refined` keeps
the basic flag, so `using R` with a refined `Integer#to_s` was skipped (review P1). It calls `rb_fix_to_s` as a
leaf call that may allocate, or a new `rb_yjit_mod_objtostring` helper (`rb_mod_name`, else `rb_mod_to_s`) as a
non-leaf call, since a singleton class's `to_s` may call `#inspect`.

Tests: `test_string_interpolation_integer_and_module`: allocations for `"t#{3}_r#{4}"` (1), `"t#{12}_r#{4}"` (2),
a named class (1) and a module (1). Results for negative and large Integers, an overridden singleton `to_s`, an
anonymous class and a singleton class, and `Integer#to_s` redefined after compilation. It fails on master with
`[3, 3, 2, 2]`. `test_string_interpolation_refined_to_s` refines `Integer#to_s` and `Module#to_s` and expects
`["int!","mod!","mod!","7","M"]`. It fails on the pre-review head `623e39a1f7` (`["7","M","#<Class…>","7","M"]`)
and passes on master and on the branch.

The Symbol branch has the same refinement gap, but it doesn't diverge: `vm_objtostring` also checks Symbol with
`check_method_basic_definition`, so with a refined `Symbol#to_s` the interpreter, YJIT and ZJIT all print `"a"`.
That is pre-existing interpreter behaviour and is not changed here.

### Verification (each branch)

* The new test fails on master and passes on the branch, and the master build was used to run the branch's test
  file to show that.
* `make btest RUN_OPTS=--yjit-call-threshold=1`: PASS all 2,138 tests on A, B and C.
* `test/ruby/test_yjit.rb`: 151 tests, 0 failures, 1 skip on each branch. YJIT `cargo test --release`: 372 passed.
  The review heads were rechecked: B `89472a2a77` btest 2,138 PASS, test_yjit 152 tests, 0 failures, cargo 372; C
  `70b8e23a8f` btest 2,138 PASS, test_yjit 152 tests, 0 failures, 1 skip.
* The stack (master + #19655 + A + B + C) passes `test/ruby/test_yjit.rb` (154 tests) and runs the whole
  `test/ruby` with `--yjit-call-threshold=1` (11,515 tests). The only failures are
  `TestThread#test_handle_interrupt_masks_sigint`, `TestIO#test_seek` and `#test_seek_symwhence`, which fail the
  same way on unmodified master in this orb.
* `yjit-bindgen` could not run here (libclang 14 output does not match what the bindgen post-processor expects).
  The added bindings follow bindgen's naming and `yjit.c` declaration order by hand.
* ZJIT is untouched by A, B and C. `zjit-test` was not rerun.

### ruby-bench, YJIT objects per iteration

Two interleaved rounds, mean per build; master is the mean of `base` and `base2`.

| Change | railsbench | lobsters | shipit |
| --- | ---: | ---: | ---: |
| master (base, base2 mean) | 1737334 | 650065 | 1150004 |
| A/A (base2 − base) | -38 (-0.002%) | +22 (+0.003%) | -6 (-0.001%) |
| #19655 | -2086 (-0.12%) | -3580 (-0.55%) | -12599 (-1.10%) |
| A | -1224 (-0.07%) | -623 (-0.10%) | -1530 (-0.13%) |
| B | -72 (-0.00%) | -217 (-0.03%) | -2469 (-0.21%) |
| C | -3940 (-0.23%) | -220 (-0.03%) | -123 (-0.01%) |
| #19655 + A + B + C | -7332 (-0.42%) | -4629 (-0.71%) | -16701 (-1.45%) |

### PR description drafts (not published)

**A — YJIT: Don't dup a splat array before slicing it for a rest parameter**

> When a splat fills leading or optional parameters and the remainder goes to a rest parameter, YJIT duplicated
> the splat array and then sliced the copy with `rb_ary_subseq()`. The slice is a new Array either way, so the
> copy is not needed; the interpreter allocates one Array for these calls and YJIT allocated two.
>
> Rails hits this on every `where(...)`, which calls `where!(opts, *rest)` as `spawn.where!(*args)`.
>
> YJIT objects per iteration on ruby-bench: railsbench −0.07%, lobsters −0.10%, shipit −0.13% (A/A within
> 0.004%). Allocation counts only.

**B — YJIT: Interpolate Integers and Modules without calling to_s**

> `vm_objtostring()` interpolates a Fixnum with `rb_fix_to_s()` (a shared frozen string for 0..9) and a Module
> with its frozen name when `#to_s` is the original method. YJIT only specialized Strings and Symbols and called
> `#to_s` otherwise, which allocates: `"t#{i}_r#{j}"` allocated three strings instead of one and
> `"#{klass} Update"` two instead of one.
>
> Like `vm_objtostring()`'s `check_cfunc()`, the new branch guards that `#to_s` resolves to `rb_int_to_s()` or
> `rb_mod_to_s()` with `assume_expected_cfunc`, so a refined or redefined `#to_s` still goes through the send path.
>
> Rails interpolates the model class into the name of every insert and update (`"#{self} Update"`) and small
> integers into join aliases. YJIT objects per iteration: shipit −0.21%, lobsters −0.03%, railsbench unchanged.

**C — YJIT: Don't dup a splat array the rest parameter can own**

> Like `rest_dupped` in vm_args.c, the interpreter uses a splat array as the rest parameter without a copy when
> nothing else can reference it: the caller built it for this call (`VM_CALL_ARGS_SPLAT_MUT`, as in
> `f(*a, b)`), or an anonymous rest parameter receives exactly the splat elements (`def f(*) = g(*)`). YJIT
> always duplicated the array. It now reuses it in the same cases, including `f(*a, **nil)`. It still copies for
> optional or post parameters, `ruby2_keywords` methods, and `**nil` methods called without a kwsplat; calls that
> splat with a block argument still use the existing fallback.
>
> Rails forwards every controller action through a chain of `def process_action(*) = super`; that chain
> allocates 5 objects under YJIT and 2 in the interpreter (3 with this change, 2 together with #19655). YJIT
> objects per iteration: railsbench −0.23%, lobsters −0.03%, shipit −0.01%.
>
> This touches the same `if` in `gen_send_iseq` as #19664; whichever lands second resolves it as
> `reuse_array || non_rest_arg_count < required_num + opt_num`. Independent of #19655.

### Review rounds

Codex Astra reviewed each branch on a correctness and a quality rubric (2026-11-03).

| # | Round 1 | Fix | Round 2 | State |
| --- | --- | --- | --- | --- |
| A | approve, approve | — | — | open as [#19664](https://github.com/ruby/ruby/pull/19664), head `d531b19421` |
| B | request changes (P1, refined `to_s` skipped) | `assume_expected_cfunc` and a refinement test, `623e39a1f7` → `89472a2a77` | approve, approve | open as [#19665](https://github.com/ruby/ruby/pull/19665), head `89472a2a77` |
| C | approve with nits (test gaps, `**nil`) | tests added, `**nil` reuse, `e999828fc6` → `cbc29b57be` | approve; quality P3: the reuse cases could pass via the interpreter | split into a strict and a permissive test, `70b8e23a8f`; not opened yet |

CI on ruby/ruby, last read 2026-11-03:
* #19664: two jobs fail. Both are pre-existing on master and unrelated:
  * SHSTK AMD64 `make check`: 4 `JSONGeneratorTest#test_rfc8785_*` failures, also failing on master run 41522893499.
  * ModGC mmtk `make check`: "failed to re-disable GC after GC", also failing on master run 41522777008.
* #19665: no failures so far.

Master moved to `13c3f56bb8` (ZJIT GH-19484) after these heads. That commit doesn't touch `yjit/` or
`test_yjit.rb`, and A, B and C each merge into it without conflicts.

## ZJIT remaining

Remeasured on master `90dbced795` (2026-11-03), with exits and fallbacks by reason, owners and Callgrind ZJIT vs
YJIT gaps: [zjit-gap-census.md](zjit-gap-census.md).

* **`URI.for(*self.split(uri), self)` (uri `rfc3986_parser.rb:135`, 5 apps, mean +18.5/op; Campfire 182 → 362
  Arrays per request).** The caller builds a fresh array (`splatarray true` + `pushtoarray`, `SPLAT_MUT`) and the
  callee is `for(scheme, *arguments, default:)`. The interpreter beheads the caller's array in place
  (`rest_dupped`, `rb_ary_behead`). ZJIT expands the splat into `ArrayAref`s and packs the rest into a
  `NewArray`. The same holds without keywords (`u(*x, 4)` into `u(s, *a)`: 1 / 2) and for exact-length `SPLAT_MUT`
  splats (`e(*x, 4)` into `e(*a)`: 1 / 2). **Not fixed:** an in-place behead is not safe in ZJIT as it stands.
  `gen_send_iseq_direct`'s stack overflow check side-exits with the *original* send's stack (`exit_state`,
  #19538), and the interpreter would then replay the send with an already beheaded array. Passing the array
  through unchanged is safe for the exact-length case, but nothing in the census needs it. No issue or PR
  found. This is the largest remaining ZJIT allocation divergence and worth an issue for the ZJIT team.
* **Interpolation:** `objtostring` called `rb_vm_objtostring` before #17499 ("ZJIT: Move objtostring
  specialization to HIR build", June 2026), which replaced it with `Send :to_s`. #19587 restored `nil`, `true`
  and `false` by folding their `to_s`. Integer and Module still allocate. tekknolagi tracks this in
  Shopify/ruby#1091 (open, no PR), so it was not duplicated. The census adds breadth: `persistence.rb:236/229`
  reaches all nine apps.

## Exit and fallback reasons (task 2)

Per operation after warmup, mean over ten runs ([receipts](data/jit-parity-census/receipts.tar.gz),
`stats/*.json`). Side exits per operation, YJIT: Blog 7, Campfire 22, CodeTriage 20, Fizzy 79 / 65 (MySQL),
Lobsters 73, PingCRM 8, starter kit 5, Redprints 7, Writebook 41. ZJIT: 32, 207, 126, 1,170 / 993, 560, 25, 21,
38, 472. Dynamic sends per operation are 1.6–4.2× higher under ZJIT (Fizzy 10,029 YJIT vs 15,759 ZJIT, PingCRM 572 vs
2,390).

### YJIT (all reach nine apps)

YJIT does not trace fallback sites, so the Rails column names the pattern each counter's condition matches; the
sites in parentheses are where ZJIT's trace shows the same pattern.

| Counter | Mean/op | Rails pattern |
| --- | ---: | --- |
| `send_megamorphic` | 2,055 | call sites with more receiver classes than the cache holds (`attribute_aliases`, `connection_specification_name`, `tag_options`) |
| `send_forwarding` | 337 | calls *passing* `...`: every method generated by `Module#delegate` (`def empty?(...) = predicates.empty?(...)` in `WhereClause`, `current_transaction`, `ScopeRegistry`). YJIT refuses forwarding call sites ("no good way to support without inlining"). |
| `invokesuper_singleton_class`, `send_singleton_class` | 249, 160 | `super`/sends on class-level receivers with singleton classes (model class methods, `connection_specification_name`). Open #19487 covers Class/Module receivers. |
| `invokeblock_symbol` | 163 | `map(&:name)`-style blocks |
| `send_cfunc_block_arg` | 129 | `&block` into C methods (`each(&block)`, `synchronize(&block)`) |
| `send_iseq_kw_splat_non_nil` | 78 | `**options` forwarding (tag and URL helpers) |
| `send_iseq_arity_error` | 74 | arity mismatches at polymorphic sites |
| `send_iseq_block_arg_type`, `send_iseq_missing_optional_kw` | 64, 60 | non-Proc block args; optional positional plus keywords |

### ZJIT, with traced call sites (`trace/summary.tsv`)

| Reason | Mean/op | Top sites (apps) |
| --- | ---: | --- |
| polymorphic `getivar` | (top traced reason) | Arel `Composite#<<` (8), `IsolatedExecutionState.[]` (9), `WhereClause#empty?` (9), `schema_loaded?` (6) |
| `send_polymorphic_fallback` | 2,562 | `BasicObject#!=` (9), `Base._reflections` (9), `schema_context` (8), `current_role`/`current_shard` (8) |
| `invokeblock_polymorphic_miss` / `not_specialized` | 1,092 / 535 | `Array#each`/`#map`/`#find` blocks (9) |
| `send_megamorphic` | 1,209 | `attribute_aliases`, `connection_specification_name`, `association_instance_get` |
| `sendforward_not_specialized` | 312 | `delegate`-generated `(...)` methods: `WhereClause#empty?`, `current_transaction`, `ScopeRegistry.current_scope` (9). Open #18326 specializes monomorphic `sendforward`. |
| `send_block_arg_not_nil` | 331 | `MonitorMixin#mon_synchronize`, notification `Fanout`, pool `Queue#synchronize` (9). Open #19484 / Shopify/ruby#1014. |
| `send_not_optimized_method_type_optimized` (`Kernel#send`) | 183 | Arel `Visitor#visit` (one `send` per SQL node), TZInfo `Timestamp.new!`, Journey visitors (9). Open draft #19583 covers constant names; Arel and Journey use non-constant names ([zjit-send](zjit-send.md)). |
| `send_not_optimized_need_permission` | 186 | `InheritableOptions#initialize` (protected `@parent._get`), `WhereClause#merge` (protected `other.extract_attributes`) (9). Open #19483 covers protected sends. |
| super complex args / from block | 36 / 22 | `SQLString#initialize(*)`, `touch_later(*)`; `QueryCache#select_all` |

These are send and dispatch costs, not allocations, and most already have open work. Not submitted here (bet L2
targets allocation parity). The new lead is ZJIT `Kernel#send` specialization (Arel visits every node through
`send`); it would need a ruby-bench headline effect to qualify.

## Rejected, deferred and not submitted

* **`Class#new` leads:** measurement artifact (above).
* **ZJIT interpolation:** Shopify/ruby#1091 owns it (tekknolagi, open); not duplicated.
* **ZJIT `SPLAT_MUT` rest (`URI.for`):** root-caused, no small exact fix because of the exit-state replay.
* **YJIT `SPLAT_MUT` with leading parameters** (`u(*x, 4)` into `u(s, *a)`): still 2 vs 1 after A and C, because
  YJIT slices where the interpreter beheads in place. It could call `rb_ary_behead` (all YJIT side exits come
  before the rest array is built), but no Rails site in the census needs it.
* **Shopify/ruby#1094** (ZJIT yield with extra arguments): owned by another thread; not touched.
* **ZJIT `Kernel#send`, `sendforward`, `getivar` and block-arg fallbacks:** performance, mostly owned by open PRs
  (#18326, #19484, #19483, #19558); see above.

## Limits

* No timing claim. The fixes remove allocations; ruby-bench timing on this orb has A/A swings of several percent
  per benchmark (#19655's runs), far above the expected effect. These are interpreter-parity fixes with
  allocation evidence, the precedent of #9972 and #19655.
* One run of the whole census per build (two for master). Single write workloads move by tens of objects in A/A;
  the tables use breadth and medians.
* `yjit-bindgen` and `zjit-test` were not run (see Verification).
* The ZJIT stats run for Fizzy on MySQL failed once with an HTTP 404 on the comment PATCH workload and passed
  unchanged on rerun; the counters are from the rerun. The failure was not reproduced.
* Receipts: [data/jit-parity-census/receipts.tar.gz](data/jit-parity-census/receipts.tar.gz) holds the ranking
  TSVs for base, base2 and the stack, the stats JSONs, the ZJIT trace summary, the ruby-bench logs and summary, and
  every run's JSON trimmed to the top 200 sites per workload. Full receipts stay under
  `.lowrail/private/jit-parity-census/`.
