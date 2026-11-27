# BT1 independent Astra review, 2026-11-27

Verdict: **changes**, for the proposed text and evidence claims, not a demonstrated defect in the C change.
Reviewed head `afb18cccd9da322700048f40467a1c6780123f8e` against its sole parent
`274cfe719ad275bcd66bd8c7201ff871e217c9a2`, independently built in
[the review orb](https://ampcode.com/threads/T-01a21dcc-1fab-7104-9ca4-c62537a6cf82).
No fork push or upstream post. This pass does not approve a revised commit or body in advance.

## Must fix before submission

1. **The body's exact example does not produce its annotated master output.** Running
   `ruby --disable-gems -e 'eval("raise '\''boom'\''", nil, "a\0b.rb")'` on master prints
   `-e: boom (RuntimeError)`, not `string contains null byte (ArgumentError)`. Ruby's uncaught-exception
   printer falls back when formatting fails. Smallest fix: explicitly rescue the exception and call
   `e.backtrace` in the example (or use `eval('caller(0, 1)', nil, "a\0b.rb")`). The new test already uses
   the latter failing operation correctly. See `bt1-example-base.err` and `bt1-nul-base.txt` in the archive.
2. **Do not call the instruction-count increase “25% slower” in the body or commit message.** The kept
   150-frame evidence measures Ir, not elapsed time. Independent runs confirm roughly 24% more instructions
   than the installed 4.0.9, and about 22% fewer instructions with this change on the same master pin.
   The new throughput benchmark is valid but measures `Location#to_s` on a different, 50-deep call shape.
   Smallest fix: remove the percentage from the commit message. Make this `kind: fix` body a short NUL
   correctness description, without the benchmark table or version-speed sentence, as DECISIONS requires.
   Keep the measured performance benefit in the internal record.
3. **Replace the claimed encoding differential coverage.** The existing `btdiff.rb` defines its block in
   that script and formats frame 0, so each purported filename/name case formats
   `.amp/in/orb-backup/btdiff.rb:10:in 'block (3 levels) in <main>'`. Its identical output is real but does
   not establish the advertised coverage. Use the independent oracle and results below instead; it defines
   actual Ruby methods with `class_eval(source, filename, 7)` and checks their frames. Also mark BT1 risky:
   DECISIONS classifies VM changes as critical. The current `risky: false` is incorrect.

## Behavior and safety

Both source trees were built from scratch with GCC 14.2.0, `-O3 -fno-fast-math`,
`./autogen.sh`, and out-of-tree `../configure --disable-install-doc --disable-yjit --disable-zjit; make -j2`.
Neither source tree has tracked modifications. Ruby 4.0.9 was the preinstalled release build, not rebuilt;
its build options differ, so it is historical context, not the controlled base/head pair.

The oracle covers 3,335 cases: twelve filename encodings (including UTF-16/32 LE/BE and ISO-2022-JP),
ASCII, non-ASCII, broken byte sequences, empty/long/NUL paths, valid method identifiers in multiple
encodings, cfunc frames, nested eval, `caller`, locations' path/label/to_s/inspect, exception backtraces and
`full_message(highlight: false)`. It also checks frozen String subclasses, singleton conversion overrides,
and a duck-typed path with its conversion count. A tiny C extension observes the actual result String's
coderange before Ruby queries it; the serializer records bytes, encoding, `valid_encoding?`, `ascii_only?`
and the resulting coderange. Expected comparisons come from the unmodified base executable.

Results: 194 cases identical including cached coderange; 2,739 differ only in the cached coderange;
402 replace the old NUL error with a result. **No other public-output differences.** The common cache change
is known-ASCII/valid/broken to unknown; queries rescan to the same result. It is not a validity bug.
Sixteen nested-eval NUL cases still raise on both builds during implicit eval-path construction, outside
the changed formatter. A selected 47-case repeat enables `GC.stress = true` around method execution:
31 cache-only differences, 14 identical cases, two intentional NUL fixes, no crash or other difference.

The standalone NUL probe confirms `Exception#backtrace`, `Location#to_s`, and `full_message` raise on master;
head preserves the full path, whereas 4.0.9 truncates it. This is a deliberate improvement, not restoration
of 4.0.9's exact NUL output. The existing re-raise probe preserves the exception class/message on all three.

Exactness checklist: source paths remain owned by the ISEQ; neither input is adopted or mutated; the accumulator is new.
String overrides do not add dispatch because the old `rb_obj_as_string` already bypasses `to_s` for Strings.
The path conversion occurs before formatting and remains once-only. Frozen inputs pass. No new user callback,
configuration, shared state or loading boundary is introduced. Fiber suspension during formatter callbacks
does not apply: there are no Ruby callbacks here. `RB_GC_GUARD(str)` protects a converted temporary and the
existing `RB_GC_GUARD(name)` remains. Thread/reloading races were not separately stress-tested.

## Suites and the added test

`make test-all TESTS='ruby/test_backtrace.rb ruby/test_exception.rb'`: base 131 tests / 4,630 assertions;
head 132 / 4,633; both zero failures/errors/skips. `make btest`: both `PASS all 2148 tests`; both report the
same `Fiber count: 10000 (skipping)` message. These are interpreter builds with JITs disabled.

The head's added test, run by absolute path with the base runner and a name filter, runs once and errors
with `ArgumentError: string contains null byte`. On head it runs once and passes. An earlier relative-path
attempt selected zero tests; it is not counted as validation. The kept test asserts a public caller string,
including the complete filename and surrounding format; it is behavior-only, not an internal-state or
allocation assertion. There are no added C, Ruby-test or benchmark comments to remove.

## Measurements

Raw Callgrind files and stderr are retained for every run in `raw.tar.gz`. `measure.sh` uses the existing
`bt.rb`, a fixed initial heap, `GC.disable` from that script, N=100 and N=300, then divides the instruction
difference by 200. Each executable has two independent repeats. Valgrind is 3.24.0. Absolute script paths
differ from the author's run, so identical counts are not expected.

| Instructions per operation | Base A | Base A/A | Head A | Head A/A | 4.0.9 A | 4.0.9 A/A |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| caller, depth 150 | 1,092,755 | 1,093,021 | 849,732 | 849,689 | 883,154 | 883,155 |
| raise + backtrace, depth 150 | 1,105,660 | 1,105,628 | 860,777 | 860,645 | 894,699 | 894,788 |
| raise without formatting | 44,872 | 44,720 | 44,825 | 44,724 | 44,227 | 44,268 |

The caller/backtrace A/A differences are at most 0.025%; the raise-only change is within its A/A.
This independently supports the mechanism and approximate instruction counts, not a precise elapsed-time
claim for caller/backtrace. The old evidence directory has summaries rather than raw Callgrind profiles;
this review adds retained raw profiles. The reported Rails-app measurements were not rerun.

`taskset -c 0 make benchmark ITEM=vm_backtrace_to_s COMPARE_RUBY=BASE OPTS='--repeat-count 10'` reports
30.760k vs 36.759k i/s (1.20x). A separate pinned-core four-way benchmark-driver run, also ten repeats,
reports 4.0.9 35.720k, base 30.297k, base again 30.001k, head 36.666k i/s. The direction and approximate
size agree with the supplied benchmark, outside this run's approximately 1% A/A. It times materialization
of already-captured locations, not capturing the stack or an end-to-end Rails request. Unknown coderange
can defer scanning to a later consumer; the benchmark intentionally measures `to_s` only.

The same four-way run adds 16-byte, 128-byte and 1 MiB filename sizes with non-ASCII absent, early and late.
No reversal was observed. The smallest head gain against the faster A/A baseline is typical/early:
1.416M vs 1.311M i/s (base A/A 1.228M vs 1.311M). Large/late gives head 1.859k vs base 1.536k/1.585k i/s.
These best-of-ten figures are a bounded sanity check, not confidence intervals or a general performance guarantee.

## Simplicity, attribution and overlap

Cold read: start the same encoded output; append each input by length, retaining compatible ASCII-compatible
encoding or the existing replacement conversion; append the line and label punctuation. The helper has one
coherent responsibility used twice. No correctness-motivated code change is requested.

`rb_str_dup(file)` is not equivalent when file/name encodings disagree. Plain `rb_str_buf_append` rejects
incompatible encodings instead of preserving the formatter's conversion fallback. Deleting `StringValueCStr`
from `ruby__sfvextra` is fewer lines but changes every PRIsVALUE consumer; that is a broader change requiring
its own review. A raw `%s` reversion reintroduces the terminator dependency this series fixed. None is a
demonstrably simpler, equally scoped substitute. Flog/RuboCop do not apply to this C formatter.

Opened the introducing commit via GitHub API: `b9ad19da120f3bfcec1e09c1e21e1e3c97908a69` changes exactly the
two `%s` sites to PRIsVALUE; PR 17882 is “Fix for String without terminators”, merged 2026-07-15.
Searched ruby/ruby PRs for `backtrace` in titles, `location_format`, and `"null byte" backtrace`, and Redmine
for `location_format`, `backtrace "null byte"`, and `backtrace performance`. No matching report/fix was found
in those searches; this is not proof that none exists. Open PR 17978 changes label ownership, not this
formatter. Closed Bug 16041 is a 2019 eval-path lifetime bug, not this regression. Bug 14099 is an older UAF.
The body names no external application/gem that needs a relevance citation. Ruby itself is active and
unarchived (API read: 23,871 stars, last push 2026-11-27); RubyGems download counts do not apply.

Not run: full test-all, sanitizers, JIT builds, hosted Ruby CI, Rails-app corpus, or other architectures.
The review archive contains scripts, raw outputs, configure/build/test logs, and search/attribution captures.

## Confirm pass on e75b1f0109, 2026-11-27

Verdict: **changes**, limited to the body and queue record. Reviewed Lowrail `61879acc` and fetched the
fork branch at `e75b1f0109959b3df53738e68c273f812b8283d1`. Both this head and `afb18cccd9` have tree
`6318b8b90f9a0a8fd8d4648f627eca84f5dbf3f3` and parent `274cfe719ad275bcd66bd8c7201ff871e217c9a2`;
`git diff afb18cccd9 e75b1f0109 --exit-code` exits 0. The revised commit message is acceptable. The
previous runtime evidence applies to the identical source tree; this confirm did not rebuild or rerun suites.

Extracted the revised body's Ruby code block verbatim and ran it with `ruby --disable-gems` on the installed
4.0.9, the independently built base, and the unchanged previously reviewed head binary. Results:

```text
4.0.9, exit 0, stdout: "a:1:in '<main>'"
master, exit 1, stderr: body-example.rb:4:in 'Exception#backtrace': string contains null byte (ArgumentError)
head, exit 0, stdout: "a\u0000b.rb:1:in '<main>'"
```

The master diagnostic above shortens only the scratch directory and omits the following main-frame line.
The new example is accurate. The corrected `btdiff.rb` coverage note, citation of the real-frame oracle,
and `risky: true` satisfy those findings.

The benchmark table remains a body blocker because two explicit rules apply to this correctness fix:

* DECISIONS, **PR descriptions**, Numbers: “a correctness PR has no numbers” (2026-11-15).
* DECISIONS, **Correctness fixes: readable first**: “Measure only to rule out a clear slowdown on a common
  path, never to choose between correct shapes; no numbers in the body.”

The **Benchmark tables in the project's own format** paragraph (2026-11-14) describes the format when
performance numbers belong in a body; it does not explicitly exempt ruby/ruby correctness fixes from the
more specific restrictions. This is not a finding that the table is false: its measurement and approximate
benefit were independently confirmed above. Smallest fix: keep the table and closing version-speed sentence
in the evidence record, not the proposed body. No C change, benchmark deletion, or new runtime pass is needed.

Two record corrections also remain: `impact` still calls instruction counts “25% slower” and says the output
returns to 4.0.9, although NUL paths deliberately retain bytes that 4.0.9 truncated. Describe the instruction
increase and the intended NUL difference instead. Also, `git show 61879acc -- BT1.md` (with the full queue
path) shows that the original Astra pass's `head` was rewritten from `afb18cccd9` to `e75b1f0109`; restore
that historical attribution and keep this confirm as a separate new-head pass. The confirm appends its
findings without overwriting the coordinator's edits.

## Final body approval on e75b1f0109, 2026-11-27

Verdict: **approve**, no open findings. Read the exact body and metadata at Lowrail `8d9d6857` and
confirmed the fork branch still points to `e75b1f0109959b3df53738e68c273f812b8283d1`.
All remaining requested changes are present: the body omits the benchmark table and closing speed
sentence, the evidence file remains, `impact` describes instructions rather than elapsed time and the
deliberate NUL output difference, and the first pass again names its actual reviewed head `afb18cccd9`.

The supplied body hash is confirmed as
`0043078758ad9a6b3833a484273efa9c4c321634de3a2b7b21a6bab4f4feb601`, for the body without its title
and with two trailing newlines. `PrQueue.parse(...).body`, the text the opening command actually sends,
has one trailing newline and SHA-256 `db9a3ad32c3c4e6006bc6d2b3afbb9117a6e3be00d99df75b8b8cd64d8d2286a`.
This approval binds that exact text and head; it does not authorize bypassing the other opening gates.

No runtime code or example changed in this final revision. The previously verified identical Git tree,
fresh-build suites, real-frame differential, GC.stress probe and corrected-example execution remain the
supporting evidence. No rebuild, suite rerun, or new performance measurement was needed for this text-only pass.

## Parser amendment and measurement-body confirm, 2026-11-27

Verdict: **nits**, no must-fix on head `5fc1871eec45270a068d2ecba6654eef979c5f6e` or the proposed
body parsed from Lowrail `3a0321b4`, SHA-256
`fc207bc11892025edb83ee493e558ebc74919942620c12a2b25314f3f9fcd48c`.
The earlier unfinished review of body `6754e885b4` was superseded and is not a queue pass.

Imported the unpublished commit from the coordinator's bundle (SHA-256
`d27b3bcce0a65a62b80f9b059f174865a29da3228966379ffce216d02a23c09c`) and verified its parent is
`274cfe719ad275bcd66bd8c7201ff871e217c9a2`. Compared with `e75b1f0109`, the only changes are the
test's `parser_support` require and Prism-only omit. The C code and benchmark are byte-identical;
the previous independent real-frame oracle, GC.stress and simplicity findings still apply.

Rebuilt this exact head with `make -j2`, then ran:

```sh
make test-all RUN_OPTS='--parser=prism' TESTS='ruby/test_backtrace.rb ruby/test_exception.rb'
make test-all RUN_OPTS='--parser=parse.y' TESTS='ruby/test_backtrace.rb ruby/test_exception.rb'
make btest
```

Prism: 132 tests, 4,633 assertions, no failures/errors/skips. parse.y: 132 tests, 4,632 assertions,
no failures/errors and the one intended skip. btest: `PASS all 2148 tests`, with the same fiber-count skip
as base. Also ran the exact amended regression test alone with both base and head, using each parser;
the base runner received the absolute path to the head test file:

| Build | Prism | parse.y |
| --- | --- | --- |
| Base | 1 test, 2 assertions, 1 error: `ArgumentError: string contains null byte` | 1 test, 2 assertions, 1 skip |
| Head | 1 test, 3 assertions, no failure/error/skip | 1 test, 2 assertions, 1 skip |

The omit checks the current parser via the repository's existing helper, not the build default. Direct
eval probes on both builds confirmed that parse.y rejects the filename before formatting, whereas Prism
accepts it. The old unguarded test fails under parse.y at eval even with the C fix. Skipping that parser
therefore reflects the boundary of this fixture rather than hiding an unfixed formatter regression. The
test remains behavior-only. There are no new code comments. The commit message remains accurate and short;
its eval statement describes the reachable Prism case, now made explicit in the body. No simpler equally
scoped C fix emerged.

Ran the exact revised `<NUL>` example again: installed 4.0.9 prints `"a:1:in '<main>'"`; base exits 1
from `Exception#backtrace` with `ArgumentError`; head prints `"a<NUL>b.rb:1:in '<main>'"`. The example's
Prism qualification is correct. `RubyVM::InstructionSequence.compile` rejects a NUL filename under both
parsers and is not an alternative fixture. The observed old GitHub body contains `\^@`; this review does
not endorse the queue note's attribution of that transformation to GitHub, since no request-byte evidence
was available. That attribution is not in the proposed upstream body.

The coordinator relayed Thomas's later explicit instruction to retain the Callgrind figures and say this
is faster, treating BT1 as both a performance regression and a correctness fix. This supersedes the
numbers-free-body objection for this item; it does not turn instruction counts into elapsed time. The
qualitative throughput direction is supported by the independently executed benchmark recorded above.

Audited all twelve per-call entries in `callgrind-body-line.txt`: they round to the proposed values and
their largest paired drift is 0.024158%. They are per-call summaries, not the underlying Callgrind profiles.
An additional independent fixed-heap, two-repeat N=100/300 run retained those profiles and confirms the
direction (Ir per call, `(Ir300 - Ir100) / 200`):

| Operation/build | Repeat A | Repeat B |
| --- | ---: | ---: |
| caller/base | 1,076,785.545 | 1,076,854.130 |
| caller/head | 845,038.470 | 845,068.460 |
| caller/4.0.9 | 880,931.645 | 880,896.715 |
| backtrace/base | 1,089,416.190 | 1,089,415.505 |
| backtrace/head | 856,281.385 | 856,338.100 |
| backtrace/4.0.9 | 892,473.590 | 892,483.420 |

Largest paired drift: 0.006624%. These runs used the earlier, identical formatter binary, not the rebuilt
test-only amendment. Different script paths and executable/build choices affect the absolute figures;
they confirm the instruction reduction, not an exact independent reproduction of the author's absolute
counts. The installed release remains historical context, not an identically configured release build.

**Optional body nit:** drop the final wall-time sentence, retaining the qualitative faster statement and
the requested Callgrind line. The quoted five-of-seven range is true after rounding, and the explicit A/A
caveat makes it a rough sign rather than a precise speed claim. But the full seven-run range is
1.045133–1.416468, not 1.19–1.21; the ten A/A pairs range 1.000170–1.162954. Selecting the middle five is
less informative than giving the whole spread, and the sentence pushes the body to 201 words. Deleting
it is smaller and clearer than expanding it. The benchmark itself correctly measures already-captured
locations' `to_s`, not caller stack capture or an app request. Any replacement based on new measurements
needs its own text/evidence confirm; this pass does not approve an unseen replacement.

Supplemental raw profiles, command script, arithmetic audit, exact-head build/suite/btest logs and example
outputs are retained in `parser-confirm-raw.tar.gz`. Earlier `raw.tar.gz` retains the full oracle, search,
base suites and original build evidence. No full test-all, new JIT/sanitizer builds, or hosted CI was run by
this reviewer for this confirm; the coordinator's pending full-suite work is separate. No upstream post,
body PATCH or Ruby-fork push was performed. The queue's top-level head remains coordinator-owned until
publication; this pass names the exact unpublished commit rather than rewriting older passes.

## Final paragraph delta confirm, 2026-11-27

Verdict: **approve**, no open findings. Head remains `5fc1871eec45270a068d2ecba6654eef979c5f6e`.
Verified the exact outgoing `PrQueue.parse(...).body` at Lowrail `2c618012` hashes to
`b1ab8a6ba7c9d2860daa0139dc47630c37e5d8a8b0befc39fe687c78a8fb898b` and equals `body-proposed.md`.
Only the last paragraph differs from the preceding reviewed body; the example and code are unchanged.

Read the new DECISIONS rule in `b8bb21a0`: a correctness fix closing a performance regression shows
numbers, using a Callgrind line with A/A when wall time is too noisy, with the older release in one sentence.
The revised paragraph follows it. Master/head counts come first, remain explicitly instructions, and
round correctly from the already-audited measurements. The separate 4.0.9 sentence's "back to 4.0's cost"
means approximately the earlier instruction cost in this context, not exact equality or elapsed time.
The selected five-of-seven wall-time range is gone, resolving the nit. The final sentence accurately
describes the retained noisy A/A evidence without claiming a wall-time result or promising a clean one.
No further text change is required. This is a text-only confirm: no rebuild, suite/oracle rerun, or new
measurement; all prior exact-head validation and its limitations remain in force. No upstream action.

## Large-orb benchmark body delta, 2026-11-27

Verdict: **changes**, one small caption correction. Reviewed head `5fc1871eec45270a068d2ecba6654eef979c5f6e`
and the exact outgoing body at Lowrail `492931e8`, SHA-256
`411777fb5b39c31e762c3df95aa00ce38420ff369f0fce327c6e900417d580b2`. Verified the parsed body equals
`body-proposed.md`; only the final performance section differs from `body-posted.md`.

**Must fix:** the displayed table is not the "median of 10 runs". `hb2-6.txt` is a real, correctly copied
run: 44.957k versus 54.089k i/s, ratio 1.203127433. That ratio ranks fourth of ten, not fifth or sixth.
The two central ratios are `hb2-3` (1.203877971) and `hb2-2` (1.213065877); their median is 1.208471924,
which rounds to 1.21x, not 1.20x. Smallest fix: change "median of 10 runs" to "one representative run".
Keep the raw table and full-spread sentence; no new benchmark, invented median table or code change is needed.

Read `README.md`, both benchmark scripts, build script, machine record and all 50 raw driver outputs in
`body-bench-xxlarge-2026-11-27/make-benchmark/`. Independently parsed each throughput row and divided the
built-ruby column by compare-ruby, checking both version lines and the ten-repeat driver argument. Results:

| Cohort | Runs | Recomputed ratio range | Body conclusion |
| --- | ---: | --- | --- |
| `hb2-*`, head/base | 10 | 1.180680813–1.226719913 | 1.18x–1.23x is correct |
| `aa-*` and `aa2-*`, faster/slower base pair | 20 | 1.000022591–1.055674217 | 1.00x–1.06x is correct |
| `vh-*`, earlier head/4.0.9 | 10 | 0.983136752–1.048528762 | 4.0.9 up to 1.02x faster; head up to 1.05x faster |
| `hb-*`, earlier head/base | 10 | 1.192037315–1.228568243 | Consistent supporting cohort, not substituted for `hb2` |

The quoted table and both version lines match `hb2-6.txt` verbatim. All `hb2` logs name base `274cfe719a`
and head `5fc1871eec`; all A/A logs name the base twice. The release comparison uses `e75b1f0109` as disclosed;
rechecked its two-test-line diff against the current head, with no runtime or benchmark difference. "About
the same speed" is reasonable for these release/head results; it is not a claim of statistical equivalence.
The spread includes the slow A/A run, rather than hiding it, and all head/base ratios remain outside it.
The Callgrind sentence is unchanged apart from removing the release comparison and retains its prior audit.

Nonblocking internal-record precision: the evidence README says 19/20 A/A pairs are within 2%, but it is
18/20 before rounding: `aa2-5` is 1.021486511, in addition to `aa-5` at 1.055674217. The proposed body does
not repeat that claim; its 1.00x–1.06x range is unaffected. Prefer "18/20 within 2%" if editing the README.

The project-format table with the complete spread and A/A is allowed by the current DECISIONS regression
rule. This is a raw-evidence audit, not an independent rerun of the large-orb measurements. No build, suite,
oracle or GC.stress rerun was needed for the unchanged code. Prior exact-head validation still applies;
the caption is the only body blocker. No upstream post or Ruby-fork push.

## Representative-run caption confirm, 2026-11-27

Verdict: **approve**, no remaining body findings. At Lowrail `1682d8a9`, verified outgoing body SHA-256
`05fff894a630389800fcccad1b1f94521e8bb3a82f755f5485e27885c8041909`, byte-identical to `body-proposed.md`.
An exact string comparison against the previous reviewed body confirms that the only change is
"median of 10 runs" to "one representative run". This resolves the sole body blocker without changing
the measured table, version lines or full-spread claims already checked against all 50 raw logs.
Head remains `5fc1871eec45270a068d2ecba6654eef979c5f6e`; prior exact-head runtime verification applies.
No rebuild, test rerun or new measurements for this caption-only confirm. No ZJIT sentence is present or
approved in advance; a later addition needs its own evidence/text confirm. The earlier internal README
rounding nit is not a finding against this body. No upstream post or Ruby-fork push.

## ZJIT/YJIT sentence confirm, 2026-11-27

Verdict: **approve**, no open findings on the added sentence. Verified outgoing body SHA-256
`a692d5851fda15e4eb9b1249146198a95a6b9ef1f27c5dce087d0d83922bb879` at Lowrail `4a889cf6`, identical
to `body-proposed.md`. The only delta from posted `05fff894a6` is the supplied JIT sentence. Ruby head
remains `5fc1871eec45270a068d2ecba6654eef979c5f6e` against base `274cfe719a`.

Read the fixture, saved commands, results, raw logs and `script/upstream-bench`'s timing/statistical gates.
For each JIT, parsed all 90 measured process logs and verified their CPU/monotonic arrays match every
stored round in results.json. Each process has 30 windows for each of three cases. Independently recomputed
the log-ratio median estimates in Python from the raw CPU samples (fourth-smallest of 30 per process,
divided by calibrated call count), then reproduced the exact seeded 5,000-resample bootstrap intervals
with the inspected Ruby analysis functions. All six estimates, intervals and gate decisions match:

| Mode/case | Change | 95% change interval | 95% A/A interval |
| --- | ---: | --- | --- |
| ZJIT caller | −18.3909% | −19.4634% to −17.7212% | −7.9887% to +0.3294% |
| ZJIT backtrace | −17.8319% | −19.6437% to −17.3651% | −8.7176% to +0.4158% |
| ZJIT locations | −18.5857% | −19.7582% to −18.0708% | −6.6339% to +0.2980% |
| YJIT caller | −19.3371% | −19.7828% to −18.8709% | −0.3698% to +3.6332% |
| YJIT backtrace | −18.4845% | −19.4490% to −17.8510% | −0.4384% to +3.3146% |
| YJIT locations | −18.5220% | −18.9897% to −18.0440% | −0.5488% to +1.7645% |

All A/A intervals include zero, all change intervals exclude zero, and none overlaps its A/A interval.
Every raw JIT line has all required counters and zero accumulated absolute movement across the measured
windows: 90 processes and 8,100 case-windows per JIT. The printed `0>0` records accumulated movement,
not a claim that nothing compiled during warmup. All 90 timed commands per mode use the named JIT flag
and core 1. Saved Ruby descriptions identify the expected base/head; copied fixtures are identical.

The fixture recurses 50 levels inside caller and raise-plus-backtrace operations; the location case formats
the already-captured collection with `locations.each(&:to_s)`. Thus the sentence describes these stack
benchmarks, not isolated single-frame formatter latency or an application speedup. The estimator measures
thread CPU time with GC disabled, not end-to-end request latency. The six point estimates round to about
18–19% less time; this is not an 18–19% confidence interval. ZJIT's noisier control still passes the stated
gate. The current DECISIONS rule allows a one-sentence JIT result showing that the improvement holds.

Evidence: `jit-wall-2026-11-27/{zjit,yjit}/{results.json,commands.sh,raw/}`. This was an audit/recalculation
of retained measurements, not a fresh JIT build or benchmark run. Prior exact-head correctness validation
remains applicable. No code change requested, no upstream post and no Ruby-fork push.

## JIT spread and A/A text confirm, 2026-11-27

Verdict: **approve**, no open findings. Verified exact outgoing body SHA-256
`67ceebdfb89bff59f67180cc481466f6824ebcd46d5959a60e711358ef58e3e8`, introduced at Lowrail `d4337183`
and unchanged at inspected main `514f733e`, equals `body-proposed.md`. Only the JIT sentence differs from
the preceding reviewed body; Ruby head remains `5fc1871eec45270a068d2ecba6654eef979c5f6e`.

My preceding approval accepted the timing evidence but missed the explicit requirement to include its
spread and A/A alongside the numerical JIT claim. The general permission for a one-sentence JIT result
does not waive that requirement. This revision supplies both and resolves the text omission.

Recomputed extrema from the six previously raw-verified results: reductions 17.831902%–19.337104%; change
interval endpoints −19.782831% to −17.365084%; A/A estimates −1.090636% to +0.472239%; A/A interval endpoints
−8.717567% to +3.633162%. Every body figure rounds correctly to one decimal place and matches the two
tables. Each case has 30 rounds. The descending change endpoints in the sentence give the same envelope;
the plural "intervals" describes extrema across six intervals, not a newly computed pooled 95% interval.
The actual intervals, noisy ZJIT control and JIT-flat verification remain documented in the previous pass.

No further text or code change is required. This was a text/summary arithmetic confirm, not a new build,
test run or measurement. Prior 180-process raw audit and exact-head correctness evidence still apply.
No upstream post or Ruby-fork push.
