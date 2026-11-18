---
id: OTS1
repo: ruby/ruby
kind: perf
area: ZJIT, objtostring guards
reviewer: "none asked; precedent k0kubun's #19603 (coerce_to guards recompile)"
branch: thomasklemm/zjit-objtostring-recompile
head: "2cc3e0de4d"
base: master
built_on: "9de06831e3"
depends_on: []
stacked_on:
alternative_of:
impact: "removes a permanent side exit: a String-profiled interpolation that also sees a Symbol exits on every such call; lobsters guard_type_failure 677 -> 139 per iteration (content_tag_string), side exits 10,167 -> 9,629, railsbench unchanged; run_benchmarks.rb within A/A (A/A spread up to 10% on the orb)"
rank: 3
risky: false
state: built
pr:
note: "2026-11-18 (Thomas): open as a ruby/ruby draft once the thermos-sol review on the head approves. 2026-11-18 thermos-sol: changes on 2cc3e0de4d. Recompiling the Integer/Module guards loses specialized conversions on mixed inputs; release-build reproducer adds 1,000,000 allocations per 600,000 calls. Cut the false frozen-string claim from body and commit message and the body's setup parenthesis. Review record and reproducer below. Independently run zjit-test 2,015/2,015 and btest t1/t2 2,148 each; new test fails on base production code. Built from docs/upstream/zjit-stats-2026-11-18.md, production +4/-4, one new HIR test, seven changed snapshots. Not opened: review must-fixes remain. The permanent-exit exception waives the timing-evidence gate only; the separate draft approval is conditional on a passing review."
passes:
  - {reviewer: thermos-sol, orb: T-01a1ee95-733f-70d2-80da-ed3434c4e36b, head: "2cc3e0de4d", date: 2026-11-18, verdict: changes, open: "P2: mixed Integer/Module interpolation loses specialized conversions after recompile (release allocation regression); narrow the change or preserve those conversions. Body and commit message overgeneralize frozen strings; cut that clause. Remove body pins/setup and unqualified two-runs claim. No semantic divergence found; both rubrics applied directly by one reviewer, as requested."}
---

# ZJIT: Recompile when an objtostring guard fails

When `objtostring` has a monomorphic profile, ZJIT guards the profiled type: a String goes straight into the concatenation, an Integer or a Module becomes its frozen string, and any other class sends `#to_s`. These guards didn't recompile, so a value of another type side-exited on every call for as long as that version stayed. They now recompile, like `coerce_to`'s since #19603.

On lobsters, Action View's `TagBuilder#content_tag_string` interpolates a tag name that is a String in most calls and a Symbol in about one in six:

```diff
-exit_guard_type_failure:      677
+exit_guard_type_failure:      139
-side_exit_count:           10,167
+side_exit_count:            9,629
```

(ZJIT stats per iteration, ruby-bench `8083f57`, 15 warmup + 10 measured iterations, two runs per build agree; railsbench doesn't move.)

## For Thomas

### thermos-sol review, 2026-11-18

Verdict: **changes** on exact head `2cc3e0de4d63abe7e307d3cc8d6b216fe5be55c9`,
one commit on `9de06831e37534f8a163e598cc0c6903c7687430`. This reviewer applied both
Thermos rubrics directly, without another reviewer, subagent or thread. The proposed
body above and the fork commit were not edited.

**Must fix: the Integer/Module guard changes discard useful conversion fast paths.**
At [hir.rs:4709](https://github.com/thomasklemm/ruby/blob/2cc3e0de4d63abe7e307d3cc8d6b216fe5be55c9/zjit/src/hir.rs#L4709)
and [hir.rs:4717](https://github.com/thomasklemm/ruby/blob/2cc3e0de4d63abe7e307d3cc8d6b216fe5be55c9/zjit/src/hir.rs#L4717),
letting a mixed site recompile changes more than its exit count. After an Integer-only
warmup, `[1, 2, 3, 4, 5, ""]` makes the old version retain `FixnumToString` on Integers
and interpret the String calls. The new version instead branches on String and sends
`to_s` for the Integers. For 0..9 this loses the shared frozen conversions and adds two
allocations on each Integer call in the tag-shaped probe. The named-module case also
loses the allocation-saving `rb_mod_name` path. Narrow the candidate to the demonstrated
String case or preserve these conversions after recompilation, then remeasure the
changed scope. This is a performance regression, not a Ruby return-value difference.

[Reproducer](../../zjit-stats/ots1_review_cost.rb), with
[raw counts and controls](../../zjit-stats/raw/ots1-review-sol-cost.json). Both release
builds use `--enable-zjit --disable-yjit --disable-install-doc --without-jemalloc`, GCC
14.2 and Rust 1.100.0, on x86_64 Linux. Each process warms 200 monomorphic calls, then
1,000 mixed calls, and runs GC before measuring. For example, run each binary with
`MODE=integer_string N=600000 ruby --zjit --zjit-stats-quiet bench/upstream/zjit-stats/ots1_review_cost.rb`.

| Input cycle | Allocations, base / head, 600,000 calls | Extra dynamic sends on head |
| --- | ---: | ---: |
| String only | 1,200,014 / 1,200,014 | 0 |
| Five Strings, one Symbol | 1,200,014 / 1,200,014 | 200,000 |
| Five small Integers, one String | 1,200,014 / 2,200,014 | 1,000,000 |
| Five named classes, one Symbol | 1,200,014 / 2,200,014 | 1,200,000 |

The Integer/String allocation result repeated exactly. HIR dumps independently show
`FixnumToString` in base and the first head version, then polymorphic `Send :to_s` in
the second head version. All measured probe regions have zero compiles,
`invalidation_time_ns` and `zjit_alloc_bytes` deltas.

Two diagnostic Callgrind rounds on core 0, comparing the whole-process instruction
slope between N=1,000 and N=10,000, give String-only −0.24% to +0.12%, String/Symbol
−2.16% to −1.68%, Integer/String +35.04% to +35.34%, and named-class/Symbol +12.84% to
+13.17%. Largest same-binary A/A slope difference: 0.49%. GC is enabled and the heap
is the default, not fixed or certified, so these are diagnostic micros, not admitted
performance prices or lobsters speed estimates. Native times are not claimed.

For the requested String/Symbol shape, the extra sends therefore do not outweigh the
saved exits in this diagnostic. That does not price the actual lobsters request. The
committed `run_benchmarks/round1.txt` and `round2.txt` still show no effect outside A/A,
in either direction; the record's estimated 0.05% saving has no measured cost model.
The wider Integer/Module change cannot be justified just by showing fewer exits.

**Must fix: cut inaccurate and process-heavy upstream text.** Sentence-by-sentence:

* Title: accurately names the change.
* First body sentence, also the commit message's first sentence: “an Integer or a
  Module becomes its frozen string” is false as a general description. `rb_fix_to_s`
  reuses frozen strings only for 0..9; larger Fixnums allocate, Bignums and custom
  `to_s` methods take sends, and anonymous modules need the fallback. Verified by
  reading `numeric.c:4106`, `vm_insnhelper.c:6552` and `try_objtostring_cfunc`. Cut the
  Integer/Module overview rather than adding all those qualifications.
* Second body sentence and the corresponding commit sentence: correct. The base
  guards have no recompile metadata; the probe below observes permanent exits while
  the old version remains installed.
* Third body sentence and the commit's final sentence: the existing helper and
  recompilation lifecycle support them. Opened the merged
  [coerce_to precedent](https://github.com/ruby/ruby/pull/19603) and inspected its
  `f91fd23296` change; no new recompile policy or state is introduced here.
* Lobsters sentence, also the commit's middle paragraph: supported by the class
  counts and sampled `content_tag_string` exit in the committed raw files. The class
  file actually sums to 538 Symbol calls and 2,500 String calls, not the supporting
  record's 533 Symbols; “about one in six” remains accurate.
* Four stats lines: recomputed directly from `lob1.json.gz`, `lob2.json.gz`,
  `lob-ots1.json.gz` and `lob-ots2.json.gz`; the rounded values are correct. No timing
  claim is implied by showing only a clearly labeled exit diff.
* Final parenthesis: remove the pin and setup details under DECISIONS' body rules.
  Its unqualified “two runs per build agree” also overstates railsbench coverage:
  only one head railsbench raw run is committed. Keep “ZJIT stats per iteration” as
  the label for the diff. Railsbench's measured counters are materially unchanged,
  but that is not a claim about throughput.

The permanent-exit exception explicitly permits exit evidence without an
outside-A/A `run_benchmarks.rb` win. It does not turn an exit decrease into a speed
claim or waive a demonstrated regression. It does not itself override the ruby/ruby
moratorium; Thomas's separate draft approval, retained above from concurrent main,
requires a passing review and this pass does not approve. The narrow existing-helper
change follows the merged precedent; new polymorphic lowering or a new recompile
policy would need a fresh design check.

**Correctness and invalidation.** The helper preserves the same guard types and
frame states, adds `Recompile`, and updates inferred types through the canonical
path. Traced lowering through `side_exit_with_recompile`, the LIR exit-state save,
`exit_recompile`, the exit budget, `invalidate_iseq_version`, incoming-call re-stubs
and accumulated/re-enabled profiles. It invalidates the compiled owner, including an
inlined site's owner; it does not resume midway through stale machine code. At the
version limit, `exit_recompile` returns without invalidation; the added metadata does
not create unbounded versions. The resulting fallback still handles arbitrary
receivers and `anytostring` results.

An interpreter/base/head differential probe produced identical 137-row output for
each of six configurations: thresholds 1, 2 and 30, threshold 2 without inlining,
threshold 2 with max-versions 1, and threshold 2 with max-versions 2 / exit budget 1.
It seeded separate sites with String, Integer, named Module and a custom object,
then changed receivers through String, Symbol, nil, booleans, negative/0/9/10 and big
Integers, Float, named/anonymous modules/classes, String subclasses and singleton
methods, frozen/binary/UTF-8 Strings, private/custom/missing `to_s`, String-subclass
and non-String conversion results, exceptions and wrong arity. It compared results,
encoding, mutability, exception class/message and conversion-call counts, and checked
singleton addition/removal, `extend`, prepend/redefinition, GC compaction and a fiber
suspended inside `to_s`. Release base/head also matched the interpreter. No semantic
or security defect was demonstrated. ARM64 and app suites were not run.

**Guards and comments.** All four changed guards have a contract reason: String
protects direct concatenation; Fixnum protects `rb_fix_to_s`; the profiled Module
class protects `rb_mod_name`; the other receiver guard supplies a sound type to send
specialization. Their recompile helper is the file's canonical idiom. Existing
original-C-function and no-singleton checks preserve redefined/refined/singleton
`to_s`; Module ancestry/immediate checks protect the C argument; its final-version
policy and String-result guard handle anonymous names. The String singleton
patchpoint's existing TODO is unchanged. No guard is new or widened, and none is
added for arbitrary objects outside Ruby's contract. No production comment was
added. The five new test phase annotations explain why repeated identical calls are
not redundant, in the exact style of `test_coerce_to_guard_failure_recompiles`; keep
them. The `SendFallbackReason` text is generated snapshot output, not prose added to
explain the patch. Both files were already far over 1,000 lines. No new layer,
wrapper, state, branch or structural regression; readability L0.

**Executed checks and identity.** Built exact head with `--enable-zjit=dev` and ran
`make zjit-test`: **2,015 passed**, 15 platform/configuration skips, including a pass
of `test_profile_frames_during_direct_jit_to_jit_entry`. Rust tests set their own
thresholds; `RUN_OPTS` applies to btest, not to the Rust harness. Independently ran
`make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and the same at threshold 2:
**2,148 passed at each threshold**. The known signal flake did not occur in this run.

Replaced only production `hir.rs` with its byte-identical base version, keeping the
new test: `make zjit-test ZJIT_TESTS=test_objtostring_guard_failure_recompiles` fails
at `opt_tests.rs:10419`, expected 2 versions, actual 1, before checking the snapshot.
The unchanged test passed on head. The committed `ots1_probe.rb` reports 10,000
type-guard exits / no new version on base versus 5 exits / one new version on head,
on both dev and release builds. Restored the candidate source and confirmed a clean
fork worktree at the exact reviewed head. `/usr/bin/git cat-file commit HEAD`
confirms Thomas Klemm `<github@tklemm.eu>` as author and committer, exactly one
parent (the stated base), and no trailers; `/usr/bin/git log -1 --format='%(trailers:only)' HEAD`
is empty. No fork push, PR, comment or other upstream mutation was made.
