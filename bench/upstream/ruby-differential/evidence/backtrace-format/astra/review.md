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
