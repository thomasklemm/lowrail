# ZJIT: `!=` with more than one receiver class (bet ZNE1)

2026-11-15. skipkayhil closed rails/rails#59811 (TE2), which rewrote `type != :aria && type != :class` in Action
View's `tag_options` as `!(type == :aria || type == :class)`, with
["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59811#issuecomment-6895930722). ZNE1 is the
ZJIT fix, prepared as one ruby/ruby PR ([DECISIONS](../DECISIONS.md), ruby/ruby exception of 2026-11-15).

**Result: built, tested, measured and reviewed; nothing opened.** Branch
[`thomasklemm/ruby:zjit-opt-neq-polymorphic`](https://github.com/thomasklemm/ruby/tree/zjit-opt-neq-polymorphic),
head `18d33e8a24`, one commit on master `fc4cd8872b`. Queue item with the PR body:
[ZNE1](../../bench/upstream/pr-queue/items/ZNE1.md). Thomas opens it as a draft once the three review passes approve
this head; arm64 is green. The first reviewed head, `52d41cc992`, is on fork branch `zjit-polymorphic-neq`; the new
head differs by one test, one test comment and the commit message ([reviews](#reviews)).

* The premise of the brief was half out of date. Since ruby/ruby#19162 (nozomemein, merged) `BasicObject#!=` is a
  Ruby builtin under ZJIT and a `!=` whose call site sees **one** receiver class is already inlined.
* What was left: a `!=` whose call site sees **several** receiver classes stayed a dynamic send. `tag_options` is
  such a site (nil and Symbol), and so are the top Rails sites in lobsters and shipit.
* The fix is +4 −24 lines in `zjit/src/hir.rs`: `opt_neq` joins the arm the other `opt_*` instructions share, which
  dispatches on the profiled receiver classes. It adds no assumption of its own.
* Effect: about 5x on a `tag_options`-shaped micro. lobsters and shipit lose 10,323 and 30,074 polymorphic sends per
  iteration; their times stay within the master-against-master noise. railsbench has no such site.

## How `a != b` runs (master `fc4cd8872b`)

* **Bytecode.** `a != b`, `a.!=(b)` and `a&.!=(b)` compile to
  `opt_neq <calldata!mid:==, argc:1, ARGS_SIMPLE>, <calldata!mid:!=, argc:1, ARGS_SIMPLE>`: operand 0 is the call
  data for `==`, operand 1 the one for `!=`. Only `public_send(:!=, b)` and the like are a plain send.
* **Interpreter.** `vm_opt_neq` (`vm_insnhelper.c`) checks that `!=` on the receiver is the C function
  `rb_obj_not_equal`, then runs `opt_equality` with the `==` call data and negates by truthiness. Otherwise the
  instruction falls back to an ordinary send of `!=`.
* **`rb_obj_not_equal`** is `!RTEST(rb_funcall(a, :==, b))`: `==` is looked up on the receiver at run time.
* **With `--zjit`** `basic_object.rb` replaces it (`with_zjit`) with a Ruby builtin:
  `Primitive.attr! :c_trace, :always_inline; Primitive.rb_builtin_bool_negate(self == other)`. The method is then no
  longer `rb_obj_not_equal`, so the interpreter's `vm_opt_neq` shortcut is off and uncompiled code sends `!=`
  (accepted in #19162).
* **ZJIT, one receiver class.** `type_specialize` resolves `!=` for the profiled class, inlines the builtin
  (`PushInlineFrame`) and specializes the `==` inside it for the same class: `IsBitEqual` for nil, Symbols and
  `BasicObject#==`, `CCallWithFrame` for `String#==` and `Integer#==`, a direct send for a Ruby `==`. Each lookup is
  behind a `MethodRedefined` patch point, heap classes also behind `NoSingletonClass`.
* **ZJIT, several receiver classes (the gap).** `opt_neq` had its own arm in `add_iseq_to_hir`, because of the second
  call data. That arm pushed a plain `Send` and skipped the `CondBranchHasType` dispatch on profiled classes that
  the shared `opt_*` arm builds (tekknolagi's #15949, #18567, #19443). The send stayed
  `Send: polymorphic call site` (counter `send_fallback_send_polymorphic`) and called `BasicObject#!=` as its own
  compiled method. There `==` is specialized from one profile shared by every caller, so it often falls back too
  (`send_fallback_send_polymorphic_fallback`).

## Prior art (checked 2026-11-15)

* [ruby/ruby#19162](https://github.com/ruby/ruby/pull/19162) (nozomemein, merged; closes
  [Shopify/ruby#884](https://github.com/Shopify/ruby/issues/884)) made `BasicObject#!=` the builtin; tekknolagi's
  `f4c7ad48ce` followed up. Their `neq` branches are merged or closed.
* k0kubun's `zjit-lobsters7` (rows in Shopify/ruby#1039) does not touch `opt_neq`.
* No open ruby/ruby or Shopify/ruby PR or issue covers a polymorphic `!=`. There is nothing to build on beyond
  master, so the branch has no foreign commits; the body credits #19162 as the base.

## The change

In `add_iseq_to_hir` the `YARVINSN_opt_neq` arm is deleted and the opcode joins the shared arm, which takes the call
data from operand 1 for `opt_neq` and from operand 0 otherwise.

Said out loud: "For `opt_neq` the `!=` call data is the second operand; everything else is built like any other
send." Readability L0: the special case shrinks to one line.

With several profiled classes the HIR now is: a type check per class; in each arm the monomorphic path for that
class; a last arm with the original `Send` (`Send: polymorphic fallback`) for a class the profile has not seen.
`def test(type) = type != :aria` with nil and Symbols becomes `CondBranchHasType NilClass` and
`CondBranchHasType StaticSymbol`, each followed by `IsBitEqual` and `BoolNegate`
(snapshot `opt_neq_polymorphic_nil_and_symbol`).

### Why it is exact

Each arm is the path a monomorphic `!=` already takes on master, entered only for a receiver of that class.

| Condition | What covers it |
| --- | --- |
| `!=` redefined later | `MethodRedefined(class, !=)` patch point |
| class defines its own `!=` | direct send to it |
| `!=` refined, private or undefined | stays a dynamic send |
| singleton class with its own `!=` | exact class check, original `Send` |
| `==` redefined later | `MethodRedefined(class, ==)` patch point |
| `==` is `method_missing`, refined | `==` stays a dynamic send |
| `==` returns a non-boolean | `BoolNegate` tests truthiness |
| `!` redefined on the result | not called, as in C |
| `==` raises | propagates from the inlined frame |
| unprofiled class | original `Send` |
| BasicObject receiver | profiled by class like any other |
| TracePoint enabled | same events as master (probe) |

* Refinements: `BasicObject#!=` calls `==` from its own body, so a refinement of `==` active at the caller does not
  apply. That matches `rb_funcall` in the C version.
* Singleton classes: `CondBranchHasType` compares the exact class of a heap object, so an object with a singleton
  class misses its arm and takes the original `Send`. `NoSingletonClass` is still emitted in each arm, as on the
  monomorphic path, but nothing depends on it here (both reviewers removed it; only snapshots change).
* Cost: more code is specialized, so a redefinition of `==` or `!=` on a profiled class invalidates more. A script
  that redefines core `==` methods repeatedly takes 1,297 side exits on the branch against 201 on master (claude-code
  pass) or 247 against 52 (opus pass), with identical results; a steady polymorphic loop takes the same number on
  both.
* What differs between the interpreter and ZJIT is the same on master and on the branch: see the probe below.
* "No new assumption" means no new kind. A polymorphic site had no patch points on master and now has
  `MethodRedefined(class, !=)`, `MethodRedefined(class, ==)` and `NoSingletonClass(class)` per arm, so it can be
  invalidated where it could not before. The fable pass measured the worst case: 3,014,000 calls of
  `a != :aria && a != :class` on nil, Symbols and one user class, with six redefinition events between rounds.
  When an unrelated class with a subclass (or an unrelated included module) defines and removes `!=`, master
  compiles 2 ISEQs and takes 0 side exits; the branch compiles 5, reaches the version limit and then takes
  3,006,000 `patchpoint_method_redefined` exits, one per call. Results are identical. A monomorphic `!=` behaves
  the same way on master, so this is ZJIT's existing behaviour reaching more sites, not a defect of the change.

### Tests

`zjit/src/codegen_tests.rs` (the Ruby-level tests; `test/ruby/test_zjit.rb` was ported to Rust in `3beab86629`):
`test_opt_neq_polymorphic` and `_redefined_neq`, `_redefined_eq`, `_refined`, `_method_missing`, `_truthiness`,
`_basic_object`. HIR snapshots in `zjit/src/hir/opt_tests.rs`: `opt_neq_polymorphic_receiver` (renamed from
`…_falls_back`) and `opt_neq_polymorphic_nil_and_symbol`.

Each guard was removed in turn; every mutation fails at least one new test:

| Mutation | Failing new tests |
| --- | --- |
| no ISEQ `MethodRedefined` patch point | `redefined_neq` |
| no C-call patch point | `redefined_eq` |
| `==` call data used | all 9 |
| `!=` assumed to be BasicObject's | `refined`, `redefined_neq`, `method_missing` |
| negate by identity | `truthiness`, `method_missing` |
| `==` assumed to be identity | `truthiness`, `redefined_eq`, `basic_object`, `method_missing` |
| fallback `Send` unreachable (last arm unconditional) | `polymorphic`, both snapshots |

## Verification (x86_64 Linux)

* `make zjit-test`: 1,998 of 1,999 pass. The one failure, `test_profile_frames_during_direct_jit_to_jit_entry`, is
  a SIGPROF sampler test that also fails on master under load (branch 10 of 10 on rerun, master 9 of 10).
  `test_zjit_cli.rb`: 33 tests, 0 failures.
* **Differential probe** ([probe.rb](../../bench/upstream/zne1/probe.rb), run by
  [probe.sh](../../bench/upstream/zne1/probe.sh)): 506,872 lines, one per `!=` call at sites of every morphism,
  before and after redefinitions made while the sites are compiled. Master and branch print the same output in
  every configuration: interpreter md5 `37d0af681253`; `--zjit` at the default, threshold 1, 2 (1 profile), 6
  (5 profiles) and 12 (10 profiles) md5 `1a26f9dc4f77`. The probe reaches the change: at threshold 6
  `send_fallback_send_polymorphic` goes from 45,312 to 0 and `inline_method_count` from 11 to 229.
* **Interpreter against ZJIT differs in 1,485 lines, on master too.** 153 are TracePoint lines (`c_call` becomes
  `call` for `BasicObject#!=`, accepted in #19162). 1,332 are backtraces: under `--zjit` the C frame of `X#==`
  below `BasicObject#!=` is missing, compiled or not (`1 != E.new` with a raising `E#==` shows
  `E#== < BasicObject#!=` instead of `E#== < Integer#== < BasicObject#!=`). Both come from the builtin, not from
  this change; the second is not explained yet.
* **Rails main `8217632cf8`**, per-test outcomes with a fixed seed, branch without ZJIT against branch and master
  with `--zjit` (default, call threshold 1 and 2):

  | Suite | Tests | Differences |
  | --- | --- | --- |
  | Action View (templates) | 2,967 | 0 |
  | Action Pack | 4,521 | 0 |
  | Active Model | 1,272 | 0 |

  One test in each fails in every configuration, the interpreter included (two Ractor tests and
  `UrlForTest#test_protocol_encoding_is_preserved`). Active Support did not load here (redis gem missing).
* `make btest RUN_OPTS=--zjit-call-threshold=2` on the branch: PASS all 2,148 tests.
* `make test-all` over `test/ruby` with `RUN_OPTS=--zjit-call-threshold=1` on the branch: 11,572 tests, 1 failure,
  2 errors (`TestThread#test_handle_interrupt_masks_sigint`, `TestIO#test_seek`, `TestIO#test_seek_symwhence`). All
  three fail the same way on master and with `--zjit-disable`; they come from the orb (signals, `SEEK_DATA`).
* **arm64** (thread ARM1, A64 backend, M3, macOS 26.7.1): `make zjit-test` 2,241 of 2,241 on the branch and 2,233
  of 2,233 on master, the difference being the new tests; the probe prints the x86_64 md5s in all 12 runs, with
  release and with dev builds; `make btest RUN_OPTS=--zjit-call-threshold=2` passes 2,148 tests on both; Active
  Model on Rails main gives the same result with ZJIT off, on, and at call threshold 1 and 2 (1,272 runs, the one
  Ractor error in every mode).

## Reach

Rails main has 266 lines with `!=` in 166 files under its `*/lib` directories (`rg -c -g '*/lib/**/*.rb' ' != '`).


ZJIT stats per iteration (100 warmup iterations, 10 measured, ruby-bench `0e67be0`, Rails 8.1.4.1), master → branch:

| | railsbench | lobsters | shipit |
| --- | --- | --- | --- |
| `send_fallback_send_polymorphic` | 5,961 → 5,961 | 10,816 → 493 | 30,333 → 259 |
| `dynamic_send_count` | unchanged | −10,810 | −36,580 |
| `send_fallback_send_polymorphic_fallback` | unchanged | −486 | −6,509 |
| `side_exit_count` | unchanged | unchanged | unchanged |

Generic `!=` sends from compiled code that land in `BasicObject#!=`, per iteration, on a master build with
[neq_count.patch](../../bench/upstream/zne1/neq_count.patch):

| Site | lobsters | shipit |
| --- | --- | --- |
| `Association#stale_target?` association.rb:98 | 6,352 | 11,804 |
| `ScopeRegistry#value_for` scoping.rb:121 | 2,511 | 17,942 |
| `BelongsToAssociation#replace_keys` belongs_to_association.rb:147 | 898 | |
| all sites | 10,323 | 30,074 |

`stale_target?` compares an Integer or nil; `value_for` compares model singleton classes. railsbench: 0.

ZJIT stats diff, master → branch per iteration, printing a counter only when it moves by at least 1%, by 100 per
iteration and by 10 times what two master runs differ by ([stats_diff.rb](../../bench/upstream/zne1/stats_diff.rb)):
[lobsters](data/zne1/stats-lobsters.diff), [shipit](data/zne1/stats-shipit.diff); railsbench prints nothing. Between
two master runs the send counters are identical; what moves there are a few allocation counters and a swap between
`invokeblock_not_specialized` and `invokeblock_polymorphic_miss` (±10,462 on lobsters, ±21,879 on shipit).

## Numbers

`run_benchmarks.rb --no-sudo --interleave --pvalue` with master, master again (A/A) and the branch, all `--zjit`.
The run for the body is the one on the pushed head, with Callgrind paused:
[bench-micro3.txt](data/zne1/bench-micro3.txt), [bench-apps3.txt](data/zne1/bench-apps3.txt).

| bench | master (ms) | master-aa (ms) | branch (ms) | A/A | master/branch |
| --- | --- | --- | --- | --- | --- |
| `neq_nil_symbol` | 184.6 ± 17.5% | 157.2 ± 14.0% | 31.8 ± 17.1% | 1.175 | 5.810 |
| lobsters | 885.5 ± 5.2% | 939.8 ± 5.8% | 850.1 ± 9.4% | 0.942 | 1.042 |
| railsbench | 1793.6 ± 7.6% | 1800.6 ± 12.0% | 1706.0 ± 3.6% | 0.996 | 1.051 |
| shipit | 1474.7 ± 7.8% | 1395.1 ± 6.3% | 1417.7 ± 3.9% | 1.057 | 1.040 |

* The apps are within A/A (p 0.268, 0.104, 0.204). railsbench has no counter change, so its 1.051 is noise.
* Only the micro ([neq_nil_symbol.rb](../../bench/upstream/zne1/neq_nil_symbol.rb), the `tag_options` condition
  with nil and Symbol types) is outside A/A. The orb is noisy: two runs of the same master binary differ by 1.175
  (p < 0.001) on it. The iteration minima are 139, 137 and 28 ms for master, master again and branch, so the
  effect is about 5x either way.
* Earlier runs, kept for comparison: the same micro while Callgrind and the test suites ran
  ([bench-micro2.txt](data/zne1/bench-micro2.txt)): 153.8 → 31.7 ms, A/A 0.835. The first form of the micro, whose
  loop sat in a block that compiled only at iteration 30 ([bench-micro.txt](data/zne1/bench-micro.txt)):
  195.3 → 39.3 ms, A/A 0.976. The apps on the build before the commit, same tree
  ([bench-apps.txt](data/zne1/bench-apps.txt)): lobsters 0.956, railsbench 1.058, shipit 1.011, A/A 1.004,
  1.027, 0.918.
* A quiet machine would give a cleaner table. Thomas's Mac has both release builds and ruby-bench ready
  (thread ARM1), but the coordinator allows no speed claims from it for now.
* TE2's own benchmark-ips script on Rails main under ZJIT, 5 interleaved rounds, best of 5
  ([ips-tag.txt](data/zne1/ips-tag.txt)): `tag.a` 301.1k / 285.7k / 318.0k i/s for master / master again /
  branch (+5.6%, branch highest in all 5 rounds, each round ±9–15%); `content_tag` 516.1k / 510.6k / 561.0k
  (within the rounds' spread).

### Callgrind ceilings

Instructions per iteration inside generic `!=` sends from compiled code that land in `BasicObject#!=`, on the
measurement build (master with [neq_count.patch](../../bench/upstream/zne1/neq_count.patch)), fixed heap, after 100
warmup iterations and the JIT-flat gate (passed in every run). A ceiling counts the whole generic dispatch with the
`==` inside it; nothing is subtracted for what the specialized code still costs.

| | Whole iteration (Ir) | `!=` region (Ir) | Share | Calls | Ir per call |
| --- | --- | --- | --- | --- | --- |
| railsbench | 4,867,836,681 | 0 | 0.000% | 0 | |
| lobsters | 2,521,649,671 | 4,644,536 | 0.184% | 10,323 | 450 |
| shipit | 3,731,618,637 | 14,561,025 | 0.390% | 30,074 | 484 |

Data: [a-railsbench.json](data/zne1/a-railsbench.json), [a-lobsters.json](data/zne1/a-lobsters.json),
[a-shipit.json](data/zne1/a-shipit.json). A second run of each is pending.

## Which applies

The brief's rule: stop if the ceiling is under 0.3% everywhere and the change is not tiny; a small, clean, general
change may still be worth it. The ceiling is above 0.3% on shipit (0.390%) and below it on lobsters (0.184%) and
railsbench (0), so the stop rule does not apply; and the change is small and general anyway: it removes more lines
than it adds, brings `opt_neq` in line with every other `opt_*` instruction and makes the pattern Rails declined to
rewrite about 5x faster in isolation. The app times do not show it: they stay inside A/A.

## Reviews

Three independent Claude Code orbs on head `52d41cc992`; each rebuilt master and the branch, reran the probe (same
md5s) and tried to break a guard.

| Pass | Verdict | Must-fix |
| --- | --- | --- |
| claude-code | changes | body only |
| opus | changes | one test comment |
| fable (adversarial) | nits | none |

* **claude-code** (T-01a1e017-0b4b-7405-a5c9-6e381e0a03bb): 14 guard-breaking scripts in 6 configurations and 7
  mutations, no finding in code, tests or commit message. Body: over 150 words, two tables, and a sentence that
  contradicted the first table (railsbench 1.058 with p 0.012 against "within noise").
* **opus** (T-01a1e017-14c1-7599-8e9c-3e9b47151185): 13 scripts in 7 configurations and 7 mutations, no finding in
  the code. Must-fix: the first sentence of the comment in `test_opt_neq_polymorphic_refined` restated the code.
* **fable** (T-01a1e017-1db1-700f-a67e-f8584f45187d): 21 attack scripts in 9 configurations (189 pairs), a fuzzer
  (1,170 run pairs) and 26 `test/ruby` files at three thresholds: no difference between master and branch. Points:
  `test_opt_neq_polymorphic` passed with the fallback `Send` made unreachable; "no assumption" should be "no new
  kind"; the invalidation cost above.

Applied in `18d33e8a24`: the comment is one sentence; `test_opt_neq_polymorphic` calls an unprofiled class whose `==`
returns true, and now fails when the last arm is made unconditional; the commit message says "no new kind of
assumption", names the added patch points and their cost, and fixes two wordings. The body was cut and its
numbers replaced by one pinned run.

Found on the way, on master too, not part of this change:

* With a refinement of `Kernel#==` defined anywhere, even if never activated, `A.new != 1` raises `NoMethodError`
  in the interpreter (`rb_obj_not_equal` through `rb_funcall`; Ruby 4.0.7 too) and returns `true` under `--zjit`,
  compiled or not, because of the builtin. This is a third interpreter-against-ZJIT difference besides the two in
  the probe.
* `TestRefinement#test_module_inclusion2` fails under `--zjit --zjit-call-threshold=2` on master and branch.
* A `RUBY_DEBUG` assertion (`vm_method.c:508 clear_method_cache_by_id_in_class`, owner `T_MODULE`) fires on dev
  builds of master and branch, with and without `--zjit`, for a `define_method(:!=)` with `super` on a module.

## Reproduce

```sh
git clone https://github.com/ruby/ruby && cd ruby && git remote add fork https://github.com/thomasklemm/ruby
git fetch fork zjit-opt-neq-polymorphic      # head 18d33e8a24, base fc4cd8872b
./autogen.sh && ./configure --enable-zjit=dev && make -j && make zjit-test ZJIT_TESTS=opt_neq
bench/upstream/zne1/probe.sh MASTER_RUBY BRANCH_RUBY        # from a Lowrail checkout, release ZJIT builds
```
