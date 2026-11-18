# ZSD1 Thermos review

**Verdict: changes.** The mutable-constant wrong-results bug is fixed on `f991b4aa33`, but this head introduces a large-object allocation-policy regression and loses allocation-tracing attribution. Fix both before publishing. No additional wrong-content, encoding, dispatch, GC-safety or Ractor defect was found in the executed probes.

Reviewer: `thermos-sol`, 2026-11-18, thread `T-01a1ec04-d888-7083-8490-875ee40d1eb6`. Two independent, read-only Task reviews loaded `thermo-nuclear-review` and `thermo-nuclear-code-quality-review` in parallel; their findings were checked directly and reproduced here. No other threads were created. No Ruby fork push or public comment was made.

## Exact scope and build

Cloned `https://github.com/ruby/ruby`, fetched `thomasklemm/zjit-string-dup-2` from `https://github.com/thomasklemm/ruby`, and reviewed exactly `3a19e2efcf133ee35daaeffc36633cd99a9f2c47..f991b4aa33b2f0f99b1c4eedcd399816f36cebd6`: one commit, 9 files, +154/-12. Both revisions were built in the same source/build directory with `./autogen.sh`, `./configure --enable-zjit=dev --disable-install-doc --without-jemalloc`, and `make -j2`. Toolchain: Linux x86-64, GCC 14.2.0, Rust 1.100.0, bootstrap Ruby 4.0.9, cargo-nextest 0.9.152. The checkout was restored to the reviewed head and rebuilt afterwards.

## Must-fix 1: preserve String#dup's allocation policy (P2)

At `zjit/src/cruby_methods.rs:365-367`, `StringCopy` substitutes `rb_ec_str_resurrect` for `str_duplicate`. These helpers deliberately have different policies: `string.c:284-288,2034-2046` limits copied embedded allocations to 256 bytes because larger slots hold fewer objects per GC page; `string.c:2077-2088` copies every embedded source instead.

Executed `thermos_allocation_probe.rb memory` on the interpreter, base ZJIT and head ZJIT. A frozen receiver passed as an argument stays embedded, so repeated copying cannot disguise the difference by changing the source's storage. Ten thousand retained copies give:

| Source bytes | Source embedded? | Interpreter/base bytes per copy | Head bytes per copy | Interpreter/base retained bytes | Head retained bytes |
| ---: | :---: | ---: | ---: | ---: | ---: |
| 231 | yes | 256 | 256 | 2,560,000 | 2,560,000 |
| 232 | yes | 40 | 512 | 400,000 | 5,120,000 |
| 300 | yes | 40 | 512 | 400,000 | 5,120,000 |
| 500 | yes | 40 | 640 | 400,000 | 6,400,000 |
| 1000 | no | 40 | 40 | 400,000 | 400,000 |

These are measured `ObjectSpace.memsize_of` totals for the returned strings, excluding the common array/source. At 300 bytes that is 12.8x the retained result memory; at 500 bytes, 16x. Contents, encoding and unfrozen status still match. This reproduces at thresholds 1 and 2 and threshold 2 with max-versions 1. Threshold 1/max-versions 1 takes generic dispatch in this probe and preserves the base policy.

**Smallest clean fix:** retain the exact-class/shape checks but lower duplication to an allocating-leaf call to the already-bound `rb_str_dup`, which preserves `str_duplicate`'s policy. A narrowly scoped `StringDup { val, state }` following existing allocating-leaf instructions is preferable to changing literal `StringCopy`, adding a mode flag, or generalizing all C calls. `Insn::CCall` alone does not carry allocating-call state/preparation. A conscious maintainer-approved policy change with representative larger-string measurements is an alternative, not something established by the 20-byte microbenchmark.

## Must-fix 2: preserve ObjectSpace allocation attribution (P2)

The same inliner at `cruby_methods.rs:365-367` removes the `String#dup` C frame. NEWOBJ still fires, but `ObjectSpace.allocation_class_path` and `allocation_method_id` can now identify the caller rather than `String#dup`. Source line and sourcefile presence remain correct; the existing probe checks only sourcefile presence and misses this.

Executed `thermos_allocation_probe.rb early` and `late`, with tracing enabled before or after warmup. Focused ZJIT options were `--zjit-call-threshold=1` or `=2`, `--zjit-num-profiles=1 --zjit-inline-threshold=0`, and each threshold again with `--zjit-max-versions=1`. Interpreter runs had **no ZJIT options**, including tuning options that implicitly enable it.

* Interpreter and base ZJIT: `["String", :dup, 6, true]` for the argument receiver; `["String", :dup, 7, true]` for the frozen constant, in every mode.
* Head t1 and t2: argument receiver becomes `["ThermosDupTrace", :copy, 6, true]` with early or late tracing.
* Frozen constant: head t1 becomes `["ThermosDupTrace", :constant_copy, 7, true]` with early or late tracing; head t2 does so with early tracing. Late t2 falls back correctly in this run.
* Head t2/max-versions 1 also reproduces. Head t1/max-versions 1 remains generic and correct in this probe.
* The independent broad probe, using only the requested default t1/t2 options, also finds two attribution differences at t1; base has none.

**Smallest robust fix:** decline dup inlining while NEWOBJ tracing is active and register a `NoNewObjHook` invalidating assumption for every accepted dup inline, including mutable/dynamic receivers. Do not change literal-copy behavior. The current `gen_string_copy` dynamic path returns before the inline allocator installs its `NoNewObjHook` patchpoint; selecting `rb_ec_str_resurrect` alone preserves the event but not its context. A new `StringDup` leaf operation still needs this protection.

This is newly introduced for ZJIT String#dup, not a memory-safety issue. Existing YJIT also misattributes these calls; a YJIT control reproduced that. That limits any claim of a Ruby-wide new problem, but does not make the ZJIT base/head difference disappear.

## Differential probes and suites

The new `thermos_probe.rb` emits 113 result lines. It covers twenty string-size boundaries on mutable and frozen constant receivers; post-compilation replacement, sharing and encoding changes; readers and frozen array/hash elements folding to mutable Const Values; late, removed and many ivars; singleton classes and hooks; all 103 installed encodings; chilled/false/true frozen-string-literal modes; allocation tracing and C-call TracePoints; GC compaction and stress both before and after tracing; subclass copy hooks; refinements; prepend/removal; redefinition/restoration; and a real Ractor copying a shareable constant.

All three probes ran on both exact revisions in five modes: interpreter, ZJIT t1, ZJIT t2, t1/max-versions 1, t2/max-versions 1. There were no process failures.

| Probe | Base differential | Head differential |
| --- | --- | --- |
| Existing `probe.rb`, 62 output lines | Only allocation count 305 vs 303 at t1/max-versions 1 | Same pre-existing count difference; otherwise identical |
| Existing `const_probe.rb`, 29 output lines | Identical in all four ZJIT modes | Identical in all four ZJIT modes |
| New `thermos_probe.rb`, 113 output lines | Identical in all four ZJIT modes | Two allocation-attribution lines differ at t1; otherwise identical |

| Executed check | Result |
| --- | --- |
| `make zjit-test`, head | 2,019 passed, 15 skipped |
| `make zjit-test`, exact base | 2,013 passed, 1 failed, 15 skipped |
| Base failure | `test_profile_frames_during_direct_jit_to_jit_entry`: `rb_profile_frames was not called from SIGPROF handler`, SIGABRT; confirmed independently of this change |
| `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` | PASS all 2,148 |
| Same btest at threshold 2 | PASS all 2,148 |
| `test_zjit*`, `test_string*`, `test_optimization`, t1 and t2 | 657 tests, 39,844 assertions, no failures/errors/skips at each threshold |
| Supplement overriding make's default memory-leak exclusion, t1 and t2 | 16 tests, 194 assertions, no failures/errors/skips at each threshold |
| `git diff --check 3a19e2efcf..f991b4aa33` | Clean |

The SIGPROF test passed on this head run and failed on base; it was not rerun until green. This does not establish that the patch fixes that unrelated test. The fifteen Rust skips were reported, not treated as passes.

The Ruby suite invocation was `make test-all RUN_OPTS="--zjit --zjit-call-threshold=$t" TESTS='ruby/test_zjit_cli.rb ruby/test_string.rb ruby/test_string_memory.rb ruby/test_stringchar.rb ruby/test_optimization.rb' TESTOPTS='-j2'`. The supplement used the same files with `TEST_EXCLUDES='--excludes-dir=./test/.excludes' TESTOPTS='-j2 --name=/memory_leak/'`.

For probes from the uninstalled Ruby build, set `RUBYLIB="$PWD/lib:$PWD/.ext/common:$PWD/.ext/x86_64-linux"`, then run `./ruby --disable-gems [JIT options] /path/to/lowrail/bench/upstream/zsd1/thermos_probe.rb`, or `thermos_allocation_probe.rb early|late|memory`. Omit **all** JIT options for the interpreter. The focused probe logs are retained verbatim in `thermos-base-allocations.txt` and `thermos-head-allocations.txt`. Full build/test/probe logs remain in this thread's orb scratch directory or `/tmp/zsd1-*`; the results above are the durable summary.

## Commit message: sentence-by-sentence audit

| Sentence/claim, in order | Assessment |
| --- | --- |
| Title: inline String#dup on bare Strings | Accurate HIR description; does not promise machine-level inline allocation for runtime sources. |
| `rb_str_dup_m` copies exact String/no ivars using `str_duplicate`, without `initialize_copy` | Matches `BARE_STRING_P` and the C implementation. |
| Do the same as dupstring: two guards then StringCopy calling `rb_ec_str_resurrect` frameless | Describes runtime-valued receivers, but "the same" hides the measured allocation-policy change. Frozen embedded constants can allocate inline instead of calling C. |
| Other receivers keep the C call | Correct shorthand for the inherited-method fallback, not for arbitrary Ruby overrides. |
| Allocation now fires `RUBY_DTRACE_CREATE_HOOK(STRING)` | True on the C resurrection path, not unconditional: frozen-constant inline allocation does not call that hook. Qualify it if this path remains. |
| Ivar-profiled receivers are not inlined, avoiding an exit every call there | True for the compilation profile. Late ivars can still cause repeated exits; this is an optional performance follow-up. |
| Constant fast path bakes bytes/flags and requires a frozen source | Correct. |
| A mutable constant receiver requires restricting the fast path to frozen constants | Correct; the canonical-layer filter fixes the previous wrong-results bug. |
| Fixes the issue | Reasonable linkage; the live issue asks for cheaper allocation/setup on exact/no-ivar Strings, not a particular HIR design. |

## PR body and comment draft: sentence-by-sentence audit

The body is the Markdown after the frontmatter in `bench/upstream/pr-queue/items/ZSD1.md`; the comment draft is the #1106 section of `docs/upstream/zjit-shortlist.md`. These drafts were reviewed, not silently rewritten.

| Body sentence/claim, in order | Assessment |
| --- | --- |
| Bare String copies with `str_duplicate` and no `initialize_copy` | Correct. |
| ZJIT called it with a frame | Correct for the normal inherited C method. |
| Now two guards and the StringCopy used by dupstring, calling resurrection without a frame | Correct for runtime-valued receivers; qualify frozen-constant inline allocation. |
| Other receivers keep the C call; ivar-profiled receivers are not inlined | Correct fallback/profile summary, with the same late-ivar and override qualifications above. |
| Fixes the issue | Reasonable, not a guarantee of maintainer acceptance. |
| Two differences, neither visible to Ruby code; above 256 bytes; contents/encoding/flags the same; DTrace hook fires | **Must correct before publication.** `ObjectSpace.memsize_of` exposes the memory change and attribution also changes. The threshold is requested embedded allocation size, not string length: 232 content bytes already cross it here. Storage flags differ. DTrace is C-path-only. |
| Compile-time fast path bakes source bytes/flags, valid only when frozen | Correct. |
| Mutable constant receivers therefore require the frozen filter | Correct and covered by regression/probes. |
| 20-byte loop, Callgrind, threshold 2, 200,000-call slope, 388/388/359 | Workload/slope match the script; durable evidence supports a -29 delta, not these particular absolute values/build provenance. See below. |
| App stats per iteration, filtered against a second master build | Supplied summary corroborates railsbench's 25,218 to 0 C calls; exact displayed resurrection counts and lobsters/shipit/A-A filtering lack raw evidence in this directory. |

| Comment sentence/claim, in order | Assessment |
| --- | --- |
| Bare String can use StringCopy under the exact/no-ivars guards matching BARE_STRING_P | Guard equivalence is correct; address the allocation-policy regression first. |
| Everything else keeps the C call | Prefer "falls back normally" for overridden Ruby methods. |
| Removes 25k/4.2k/5.6k framed calls and 388 to 359 instructions per micro call | Same evidence/provenance qualifications as the body. |
| Allocation is still `rb_ec_str_resurrect`; runtime inline allocation is separate | Add "for runtime-valued receivers"; frozen constants can already allocate inline. |
| Branch link and permission question | Correct reviewed SHA; nothing was posted. |

Also correct the shortlist's "not observable", 256-content-byte cutoff and "same flags" wording, and its claim that redefined Ruby `dup` specifically keeps `CCallWithFrame` rather than normal Ruby dispatch.

### Benchmark provenance is incomplete, not proven false

`results.txt` records old candidate `c71669b114` versus `7919a47d46`: default-heap micro 397 to 368, fixed-heap 250 to 221, and railsbench resurrection counts 558.5/496.7 to 25,779.7. It supports the -29 delta but not the body's 388/359 or 625/25,852 absolutes. The raw original micro and lobsters/shipit runs are not in `bench/upstream/zsd1/`. Before publishing, attach the original evidence with measured revisions/build configuration or limit the body to supported results. These numbers were not rebenchmarked in this review. The assertion that no app receiver is constant cannot be established from aggregate counters alone.

## Maintainer shape and remaining limits

The current fifteen-line inliner, shared shape-mask guard, profile lookup and binding allowlist are idiomatic; no unrelated abstraction/file split is warranted. The mask matches CRuby, including complex shapes and excluding object-id-only transitions. The frozen-source check belongs at `gen_string_copy` and is not an outstanding bug. The larger-embedded allocation policy is the reason to choose a different allocating leaf, not line-count aesthetics. Add a tracing guard independently, then keep the issue comment short: eligibility, measured supported gain, and the remaining runtime-allocation limitation.

Late-ivar recompilation is optional without evidence of material traffic. The existing allocation-only HIR effect description was inspected, but no second wrong-result input was found; it is not a finding. No new memory-safety flaw was established. This pass did not execute DTrace probes, nondefault GC backends, AArch64 builds, a release benchmark, or new app-level measurements. Binding constants were compared with canonical C definitions and compiled, not regenerated in this pass. A changed Ruby head requires a new review; this pass applies only to `f991b4aa33`.
