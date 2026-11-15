# ZJIT: `!=` with more than one receiver class (bet ZNE1)

2026-11-15. skipkayhil closed rails/rails#59811 (TE2), which rewrote `type != :aria && type != :class` in Action
View's `tag_options` as `!(type == :aria || type == :class)`, with
["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59811#issuecomment-6895930722). ZNE1 is the
ZJIT fix, prepared as one ruby/ruby PR ([DECISIONS](../DECISIONS.md), ruby/ruby exception of 2026-11-15).

**Result: built, tested, measured and reviewed; nothing opened.** Branch
[`thomasklemm/ruby:zjit-opt-neq-polymorphic`](https://github.com/thomasklemm/ruby/tree/zjit-opt-neq-polymorphic),
head `18d33e8a24`, one commit on master `fc4cd8872b`. Queue item with the PR body:
[ZNE1](../../bench/upstream/pr-queue/items/ZNE1.md). All three review passes have no must-fix on
this head and arm64 is green, so it is ready for Thomas to open as a draft, apart from the thermos gate for diffs
over 200 lines (pass or waiver, the coordinator's call). The first reviewed head, `52d41cc992`, is on fork branch `zjit-polymorphic-neq`; the new
head differs by one test, one test comment and the commit message ([reviews](#reviews)).

* The premise of the brief was half out of date. Since ruby/ruby#19162 (nozomemein, merged) `BasicObject#!=` is a
  Ruby builtin under ZJIT and a `!=` whose call site sees **one** receiver class is already inlined.
* What was left: a `!=` whose call site sees **several** receiver classes stayed a dynamic send. `tag_options` is
  such a site (nil and Symbol), and so are the top Rails sites in lobsters and shipit.
* The fix is +4 −24 lines in `zjit/src/hir.rs`: `opt_neq` joins the arm the other `opt_*` instructions share, which
  dispatches on the profiled receiver classes. It adds no assumption of its own.
* Effect: 4.4x to 5.1x on a `tag_options`-shaped micro in three pinned rounds. lobsters and shipit lose 10,323 and 30,074 polymorphic sends per
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
| singleton class with its own `!=` | exact class check; `NoSingletonClass` if folded |
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
  monomorphic path. While the class check runs, nothing depends on it (two passes removed it; only snapshots
  change). It is the only guard when the site is inlined into a caller that passes a constant object, because the
  class check folds away: with `def caller_k(b) = site(KOBJ, b)` and a later `def KOBJ.!=`, a build without the
  patch point returns `true` instead of `:singleton` (fable pass, second round). Master produces the same HIR for
  that caller, so this is not new exposure.
* Cost: more code is specialized, so a redefinition of `==` or `!=` on a profiled class invalidates more. A script
  that redefines core `==` methods repeatedly takes 1,297 side exits on the branch against 201 on master (claude-code
  pass) or 247 against 52 (opus pass), with identical results; a steady polymorphic loop takes the same number on
  both.
* What differs between the interpreter and ZJIT is the same on master and on the branch: see the probe below.
* "No new assumption" means no new kind. A polymorphic site had no patch points on master and now has
  `MethodRedefined(class, !=)`, `MethodRedefined(class, ==)` and `NoSingletonClass(class)` per arm, so it can be
  invalidated where it could not before. The fable pass measured one such case: 3,014,000 calls of
  `a != :aria && a != :class` on nil, Symbols and one user class, with six redefinition events between rounds.
  When an unrelated class with a subclass (or an unrelated included module) defines and removes `!=`, master
  compiles 2 ISEQs and takes 0 side exits; the branch compiles 5, reaches the version limit and then takes
  3,006,000 `patchpoint_method_redefined` exits, one per call. Results are identical. A monomorphic `!=` behaves
  the same way on master (measured: the same script with only nil receivers takes 3,006,000 exits and compiles 5
  ISEQs on master and branch alike), so this is ZJIT's existing behaviour reaching more sites, not a defect of the
  change. The trigger is wider than the profiled classes because all arms share the `BasicObject#!=` method entry.

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
  Ractor error in every mode). Those ran on `52d41cc992`; on the new head `18d33e8a24`, which changes only tests,
  `make zjit-test` again passes 2,241 of 2,241.

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
The stats runs used the build made before the commit (its version line reads `zjit-polymorphic-neq fc4cd8872b`);
`zjit/src/hir.rs` is identical at `18d33e8a24`. Raw files: `data/zne1/stats-{master,master2,branch}-*.json.gz`.
On lobsters `getivar_fallback_no_side_exits` also drops by 1,821 per iteration, 10 times more than between the two
master runs; why was not traced.

## Numbers

`run_benchmarks.rb --no-sudo --interleave --pvalue --force-pinning`, all `--zjit`: master, a second independent
build of master (`master-aa`, the A/A) and the branch at head `18d33e8a24`. The two master builds were configured
separately with the same options (`--enable-yjit --enable-zjit --disable-install-doc`) into the prefixes `~/w/rm`
and `~/w/rm2`; their `bin/ruby` files differ (77,100,520 and 77,099,936 bytes, sha256 `b432668c6955b091…` and
`3a042ba13995ea65…`) and print the same version line. Three rounds with nothing else running
(Callgrind paused), each pinned to one core by the tool: [rounds-1.txt](data/zne1/rounds-1.txt),
[rounds-2.txt](data/zne1/rounds-2.txt), [rounds-3.txt](data/zne1/rounds-3.txt),
summary by [rounds.rb](../../bench/upstream/zne1/rounds.rb) in [rounds-summary.txt](data/zne1/rounds-summary.txt).

The body shows the quietest round. It is chosen without looking at the branch: the round whose
master/master-aa ratios are closest to 1 (sum of the absolute logs over the four benchmarks: 0.181, 0.183, 0.023).
That is round 3:

| bench | master (ms) | master-aa (ms) | branch (ms) | A/A | master/branch |
| --- | --- | --- | --- | --- | --- |
| `neq_nil_symbol` | 144.9 ± 6.6% | 146.4 ± 8.9% | 31.6 ± 20.9% | 0.990 | 4.583 |
| lobsters | 787.7 ± 10.7% | 782.1 ± 5.7% | 785.9 ± 9.3% | 1.007 | 1.002 |
| railsbench | 1660.6 ± 4.0% | 1668.1 ± 2.6% | 1701.3 ± 3.9% | 0.995 | 0.976 |
| shipit | 1347.1 ± 3.3% | 1345.9 ± 6.1% | 1346.4 ± 4.8% | 1.001 | 1.000 |

All three rounds, master/master-aa and master/branch:

| bench | Round 1 | Round 2 | Round 3 | Best of 3 |
| --- | --- | --- | --- | --- |
| `neq_nil_symbol` | 1.030, 5.134 | 0.936, 4.357 | 0.990, 4.583 | 1.012, 4.847 |
| lobsters | 0.926, 0.956 | 0.931, 0.885 | 1.007, 1.002 | 1.026, 1.007 |
| railsbench | 1.020, 1.031 | 1.001, 1.044 | 0.995, 0.976 | 0.976, 0.994 |
| shipit | 0.946, 1.011 | 0.956, 0.921 | 1.001, 1.000 | 1.023, 0.961 |

* "Best of 3" compares the fastest iteration of each executable over all rounds: `neq_nil_symbol` 137.3, 135.6 and
  28.3 ms for master, master-aa and branch.
* The micro ([neq_nil_symbol.rb](../../bench/upstream/zne1/neq_nil_symbol.rb), the `tag_options` condition with
  nil and Symbol types) is 4.4x to 5.1x faster in every round; its A/A stays between 0.936 and 1.030.
* The apps do not move beyond A/A. In rounds 1 and 2 `master` is faster than both other executables on lobsters and
  shipit (master-aa is 5% to 8% slower than master there), so the cleaner comparison is the branch against the
  second master build, as time ratios (opus pass, recomputed from the raw files):

  | branch/master-aa time | Round 1 | Round 2 | Round 3 |
  | --- | --- | --- | --- |
  | lobsters | 0.969 | 1.052 | 1.005 |
  | shipit | 0.936 | 1.038 | 1.000 |

  The sign flips between rounds. Against `master` alone, round 2 reads 0.885 for lobsters (p 0.007) and 0.921 for
  shipit, next to A/A values of 0.931 and 0.956. railsbench reads 1.031 (p 0.049) and 1.044 (p 0.034) in rounds 1
  and 2 although no counter changes there, so those are noise as well. In the quiet round all three apps are
  within 2.4% with p above 0.2. The ZJIT counters say the same work runs apart from the removed sends, which fits
  ceilings of 0.18% and 0.39%.
* The round choice does not look at the branch, but it is not independent of the result: the A/A distance and
  master/branch share `master`, so a round where master is the noisy run is both rejected and shows the branch
  off. The body therefore says the table is the quietest of three rounds. A rerun elsewhere can look like round 2.
* Earlier runs on this orb while other jobs ran, not used: [bench-micro.txt](data/zne1/bench-micro.txt),
  [bench-micro2.txt](data/zne1/bench-micro2.txt), [bench-micro3.txt](data/zne1/bench-micro3.txt),
  [bench-apps.txt](data/zne1/bench-apps.txt), [bench-apps3.txt](data/zne1/bench-apps3.txt). Their A/A used the
  same master binary twice and reached 0.835 and 1.175 on the micro.
* Thomas's Mac stays functional-only (coordinator): its wall-time A/A was ±4.5% while in use.
* TE2's own benchmark-ips script on Rails main under ZJIT, 5 interleaved rounds, best of 5
  ([ips-tag.txt](data/zne1/ips-tag.txt), build before the commit, same code): `tag.a` 301.1k / 285.7k / 318.0k i/s
  for master / master again / branch (+5.6%, branch highest in all 5 rounds, each round ±9–15%); `content_tag`
  516.1k / 510.6k / 561.0k (within the rounds' spread).

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
[a-shipit.json](data/zne1/a-shipit.json). A second lobsters run ([b-lobsters.json](data/zne1/b-lobsters.json))
gives the same region, 4,644,536 Ir in 10,323 calls, in 2,520,766,832 Ir: 0.184% again.

## Which applies

The brief's rule: stop if the ceiling is under 0.3% everywhere and the change is not tiny; a small, clean, general
change may still be worth it. The ceiling is above 0.3% on shipit (0.390%) and below it on lobsters (0.184%) and
railsbench (0), so the stop rule does not apply; and the change is small and general anyway: it removes more lines
than it adds, brings `opt_neq` in line with every other `opt_*` instruction and makes the pattern Rails declined to
rewrite 4.4x to 5.1x faster in isolation. The app times do not show it: they stay inside A/A.

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

Second round, on head `18d33e8a24`:

| Pass | Verdict | Must-fix |
| --- | --- | --- |
| claude-code | nits | none |
| opus | nits | none |
| fable (adversarial) | approve | none |

* **fable**: reran its 12 mutations, 22 attack scripts (198 pairs) and 108 new fuzz pairs; no difference. It
  corrected this record on `NoSingletonClass` (see "Why it is exact") and measured the monomorphic invalidation
  case on master.
* **opus**: first `changes` for one body sentence (`master-aa` was called a second build while the numbers shown
  used one binary twice), then `nits` once the pinned rounds used a second build. It recomputed the round choice
  and the stats claims from the committed files; its three optional points are applied.
* **claude-code**: reproduced `rounds-summary.txt` and the stats-diff blocks byte for byte and checked every
  sentence of the body and the commit message. It withdrew its earlier point about one small table, because
  DECISIONS asks for the tools' own format in ZJIT PRs.

Open, optional, not applied because it would need a new head and new passes: the commit message's last paragraph
names redefining `!=` or `==` for a profiled class as what invalidates a site. Two more triggers exist, both the
same for a monomorphic `!=`: giving an instance of a profiled heap class a singleton class (claude-code) and
defining `!=` on an unrelated class with a subclass or on an included module (fable). The body is 169 words,
above the 150 DECISIONS names; every reviewer left that optional.

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
