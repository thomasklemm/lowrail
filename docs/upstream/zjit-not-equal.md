# ZJIT: `!=` with more than one receiver class (bet ZNE1)

2026-11-15. skipkayhil closed rails/rails#59811 (TE2), which rewrote `type != :aria && type != :class` in Action
View's `tag_options` as `!(type == :aria || type == :class)`, with
["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59811#issuecomment-6895930722). ZNE1 is the
ZJIT fix, prepared as one ruby/ruby PR ([DECISIONS](../DECISIONS.md), ruby/ruby exception of 2026-11-15).

**Result: built, tested and measured; nothing opened.** Branch
[`thomasklemm/ruby:zjit-polymorphic-neq`](https://github.com/thomasklemm/ruby/tree/zjit-polymorphic-neq), head
`52d41cc992`, one commit on master `fc4cd8872b`. Queue item with the PR body:
[ZNE1](../../bench/upstream/pr-queue/items/ZNE1.md). Thomas opens it as a draft after the three review passes and
the arm64 run.

* The premise of the brief was half out of date. Since ruby/ruby#19162 (nozomemein, merged) `BasicObject#!=` is a
  Ruby builtin under ZJIT and a `!=` whose call site sees **one** receiver class is already inlined.
* What was left: a `!=` whose call site sees **several** receiver classes stayed a dynamic send. `tag_options` is
  such a site (nil and Symbol), and so are the top Rails sites in lobsters and shipit.
* The fix is +4 −24 lines in `zjit/src/hir.rs`: `opt_neq` joins the arm the other `opt_*` instructions share, which
  dispatches on the profiled receiver classes. It adds no assumption of its own.
* Effect: 4.8x on a `tag_options`-shaped micro. lobsters and shipit lose 10,323 and 30,074 polymorphic sends per
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
| singleton class with its own `!=` | `NoSingletonClass` patch point |
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
* What differs between the interpreter and ZJIT is the same on master and on the branch: see the probe below.

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
* arm64: thread ARM1 runs `make zjit-test` and the probe on the A64 backend; result pending.
* `make btest` and `test-all` with the ZJIT run options: pending.

## Reach

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

## Numbers

`run_benchmarks.rb --no-sudo --interleave --pvalue` with master, master again (A/A) and the branch, all `--zjit`.
Raw output: [bench-apps.txt](data/zne1/bench-apps.txt), [bench-micro2.txt](data/zne1/bench-micro2.txt).

| bench | master (ms) | master-aa (ms) | branch (ms) | A/A | master/branch |
| --- | --- | --- | --- | --- | --- |
| `neq_nil_symbol` | 153.8 ± 12.1% | 184.3 ± 28.1% | 31.7 ± 17.8% | 0.835 | 4.849 |
| lobsters | 778.6 ± 3.9% | 775.2 ± 6.9% | 814.2 ± 8.7% | 1.004 | 0.956 |
| railsbench | 1732.6 ± 4.7% | 1687.5 ± 4.1% | 1638.0 ± 3.6% | 1.027 | 1.058 |
| shipit | 1460.2 ± 7.2% | 1590.9 ± 11.0% | 1443.9 ± 4.1% | 0.918 | 1.011 |

* The apps are within A/A. railsbench has no counter change, so its 1.058 (p 0.012) is noise.
* Only the micro ([neq_nil_symbol.rb](../../bench/upstream/zne1/neq_nil_symbol.rb), the `tag_options` condition
  with nil and Symbol types) is outside A/A. This run shared the machine with Callgrind and test suites, hence the
  A/A of 0.835; the first form of the micro, on a quiet machine, gave 195.3 → 39.3 ms with A/A 0.976
  ([bench-micro.txt](data/zne1/bench-micro.txt); its loop sat in a block that compiled only at iteration 30).
* TE2's own benchmark-ips script on Rails main under ZJIT, 5 interleaved rounds, best of 5
  ([ips-tag.txt](data/zne1/ips-tag.txt)): `tag.a` 301.1k / 285.7k / 318.0k i/s for master / master again /
  branch (+5.6%, branch highest in all 5 rounds, each round ±9–15%); `content_tag` 516.1k / 510.6k / 561.0k
  (within the rounds' spread).

Callgrind ceilings (fixed heap, JIT-flat windows): pending.

## Which applies

The brief's rule: stop if the ceiling is under 0.3% everywhere and the change is not tiny; a small, clean, general
change may still be worth it. The second applies. The app effect is inside A/A, but the change removes more lines
than it adds, brings `opt_neq` in line with every other `opt_*` instruction and makes the pattern Rails declined to
rewrite 4.8x faster in isolation.

## Reproduce

```sh
git clone https://github.com/ruby/ruby && cd ruby && git remote add fork https://github.com/thomasklemm/ruby
git fetch fork zjit-polymorphic-neq          # head 52d41cc992, base fc4cd8872b
./autogen.sh && ./configure --enable-zjit=dev && make -j && make zjit-test ZJIT_TESTS=opt_neq
bench/upstream/zne1/probe.sh MASTER_RUBY BRANCH_RUBY        # from a Lowrail checkout, release ZJIT builds
```
