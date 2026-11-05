# Signed TZif transition decoding: refresh of TZInfo 171

2026-11-05. **Worth updating as a small simplification with allocation savings, not as an app-speed claim.**
Reading a signed integer directly is clearer than rebuilding one from two unsigned words. The saving occurs
when loading zoneinfo files, not on every timezone lookup. There is no measured whole-boot or request benefit.
No maintainer has responded to the original PR; this is evidence for Thomas's update, not a reason to ping.

## Exact code and delivery boundary

* Upstream master: `1207d6098d7f4a9f294a40801154990850f09bf1`, seven commits after the old base.
* Refreshed commit: [`57056ddd7f46f9c292e46687821636e812102c85`](https://github.com/thomasklemm/tzinfo/commit/57056ddd7f46f9c292e46687821636e812102c85),
  pushed only to `thomasklemm/signed-zoneinfo-transitions-refresh` on `thomasklemm/tzinfo`.
* The diff remains **+1/−14 in one library file**. The eight-byte `check_read` is unchanged. Only the unused
  private `make_signed_int64` disappears. No `unpack1` or minimum-Ruby change is introduced.
* Read aloud: “Read exactly eight bytes, decode one signed big-endian 64-bit integer, and store its timestamp.”
  Format 1 still decodes signed 32-bit values through its existing path. Readability: L0.
* Flog 4.9.4: `parse` **168.7 → 167.6**; deleted `make_signed_int64` **5.5 → absent**; file total
  **373.7 → 367.1**. RuboCop 1.92.2 (`TargetRubyVersion: 2.3`, the three Metrics maxima set to zero for reporting):
  `parse` ABC **123.2 → 122.2**, cyclomatic **31 → 31**, perceived **37 → 37**. The deleted helper's ABC was
  **3.74**, cyclomatic **2**, perceived **2**. No complexity increase in a surviving touched method.
* The live PR branch remains `57c9c3ad35c3fa08bb4d0310cf3f0e52ae01f961`. No upstream body edit, comment,
  issue edit or push to that branch was made. TZ2 contains the proposed body; Sol and moving the live PR are
  the coordinator's next steps.

## Correctness and platform evidence

The unmodified fork [Tests workflow](https://github.com/thomasklemm/tzinfo/actions/runs/42121909175) ran on
the exact refreshed head: **39/39 jobs passed**, including all five experimental jobs (none merely ignored).
It runs all three data-source suites per job. The matrix is:

* MRI 2.3, 2.4, 2.5, 2.6, 2.7, 3.0, 3.1, 3.2, 3.3, 3.4 and 4.0 on Ubuntu 24.04 and Windows 2022;
* JRuby 9.1, 9.2, 9.3, 9.4, 10.0 and 10.1 on both operating systems;
* experimental MRI head and JRuby head on both, and TruffleRuby 40 on Ubuntu.

The [separate differential run](https://github.com/thomasklemm/tzinfo/actions/runs/42122136308) passed the
same 39 configurations. Its extra job labelled x86 actually ran x64: `ruby/setup-ruby` ignores an
`architecture` input. It is **not 32-bit evidence**. A first corrected x86-only attempt using
`philr/setup-ruby` [failed at setup](https://github.com/thomasklemm/tzinfo/actions/runs/42122700125)
because that action has no Ruby 2.3 entry for this runner. The subsequent
[32-bit run](https://github.com/thomasklemm/tzinfo/actions/runs/42122881130) **passed**, using the published
`ruby-2.3.3-i386-mingw32.7z` and concurrent-ruby 1.3.8. It asserts a four-byte pointer before running the
differential; both reader invocations report `i386-mingw32; 32-bit`. This is a differential, not a full
32-bit suite run.

The evidence-only branch adds a workflow and a copy of
[`tzinfo_signed_check.rb`](../../bench/upstream/tzinfo_signed_check.rb); it is **not the PR head**.
Each job verifies that `lib`, `test`, `Gemfile` and the gemspec are identical to the refreshed commit,
loads the exact master reader in one process and the refreshed reader in another, and compares their JSON.
It also checks both integer-decoding expressions against the independently chosen expected integers.
The corpus preserves the original 16 signed boundaries plus 256 seeded random values (seed 1729),
including −2⁶³ and 2⁶³−1; complete TZif v2 and v3 reads, Unicode abbreviations, independent returned graphs,
frozen reader/path, reader/path subclasses, unsorted input, a truncated header and an invalid signature.
For portable real-zone coverage it uses the repository's London, New York and Melbourne TZif fixtures,
rather than depending on system zoneinfo files on Windows. These finite checks are not a proof over all bytes.
The retained checker differs from the CI copy only in removing a bit-width suffix from stderr: old JRuby's
unsupported `pack('J')` printed a meaningless zero. Decoding checks and JSON are unchanged; the genuine x86
workflow has its own explicit four-byte-pointer assertion on MRI.

Locally, Ruby 4.0.9 (`3e93b23afc`, x86_64 Linux), concurrent-ruby 1.3.8, minitest 5.27.0,
`bundle exec rake test TESTOPTS='--verbose --seed=1729'`, both master and head:

| Suite | Runs | Assertions | Failures / errors | Skips |
|---|---:|---:|---:|---:|
| Ruby data format 1 | 1,867 | 13,260 | 0 / 0 | 22 |
| Ruby data format 2 | 1,865 | 13,258 | 0 / 0 | 22 |
| Zoneinfo | 1,865 | 13,258 | 0 / 0 | 22 |

All **5,597 ordered, named outcomes match** with suite boundaries retained. The skips concern removed
taint APIs and unsupported `Time#succ`.
Outcome-list SHA-256: `bfb34c178655ca70984642bd6efafeddf99b80ac0afc77b32713ffb285685da9`.

## Allocations

Ruby 4.0.9, interpreter, concurrent-ruby 1.3.8, complete synthetic-file reads. The restored
[`tzinfo_signed_bench.rb`](../../bench/upstream/tzinfo_signed_bench.rb) uses the same fixture bytes,
3,000 warmups and 2,000 measured reads as the original public reproducer at Lowrail `0636db9979`.
Two separate master worktrees give the A/A control. Fixture creation, validation and explicit GC are outside
the window; normal GC is enabled during allocation counting. Both reader source hashes still match the original
benchmark's pins, despite the intervening master changes.

| File | Master A | Master B | Refreshed head | Objects saved per read |
|---|---:|---:|---:|---:|
| Three format-1 transitions | 37.0005 | 37.0005 | 37.0005 | 0 |
| 32 positive transitions | 160 | 160 | 160 | 0 |
| 32 negative transitions | 288 | 288 | 160 | 128 |
| Six signed boundaries | 72 | 72 | 60 | 12 |
| Empty format 2 | 30 | 30 | 30 | 0 |

## Instruction-count protocol

One finite cohort, not retry-until-green: the same three worktrees and five files, two repetitions, separate
N=0 and N=1,000 workers, `(Ir(1000) − Ir(0)) / 1000`. Ruby 4.0.9 interpreter with ASLR disabled,
the repository's `script/bench-valgrind` build of Valgrind 3.19.0 with a 512 MiB brk reservation,
`--collect-atstart=no --toggle-collect=rb_ary_cycle`, 3,000 warmups outside the window. All five Ruby heap
floors are fixed at 1,000,000 / 250,000 / 100,000 / 20,000 / 10,000 slots. GC is disabled only for instruction
windows; the harness rejects heap growth or a GC count change, and worker logs are checked for brk overflow.
The A/A rule is at most ±0.1% in every case/repetition; any failing pair rejects the whole cohort, not just that row.

**Result: rejected, no instruction-saving or speed claim.** Maximum absolute A/A difference is **0.1537%**
(positive transitions, second repetition). Both format-1 pairs fail too (−0.1095% and −0.1177%), as does the
first empty-file pair (+0.1109%). All 60 workers pass the heap/GC checks with no brk overflow. No rerun was made.
The following are diagnostic means of two repetitions, not accepted performance evidence:

| File | Master A Ir/read | Master B Ir/read | Head Ir/read |
|---|---:|---:|---:|
| Three format-1 transitions | 77,280 | 77,192 | 77,235 |
| 32 positive transitions | 436,926 | 436,606 | 396,639 |
| 32 negative transitions | 498,008 | 498,029 | 397,184 |
| Six signed boundaries | 141,865 | 141,879 | 128,277 |
| Empty format 2 | 59,075 | 59,121 | 59,138 |

The [machine-readable receipt](data/tzinfo-signed-refresh.json) retains both repetitions, raw N=0/N=1,000
instruction totals, heap/GC observations, allocations, actual CI runtime descriptions and the tool manifest.
The allocation result is independently valid; this rejected instruction cohort neither promotes nor rejects
the allocation-only L0 simplification.

## Skeptical review

The independent skeptical subagent approved the exact `57056ddd7f46f9c292e46687821636e812102c85` head and
the shortened TZ2 body, with no must-fixes or body nits. It independently verified the CI job conclusions,
local outcomes, actual x86 log, source diff and absent helper references. Its additional 18 in-memory probes
covered v2/v3 timestamp truncations of zero through seven bytes and a complete timestamp followed by an invalid
offset index: errors, read/seek calls and final positions matched. Cold read: “In the TZif v2/v3 branch, each
transition still gets one checked eight-byte read, but those bytes now decode directly as a signed big-endian
64-bit integer.” Recommendation: update once for simpler code and measured file-load allocations, not further
performance campaigning. Sol is still pending; no upstream action is authorized from this worker.

## Reproduction

The benchmark needs only concurrent-ruby 1.3.8 and the two public checkouts. The checker also uses TZInfo's
committed zoneinfo fixtures. Use Ruby 4.0.9 for the benchmark; the checker itself supports Ruby 2.3.

```sh
git clone https://github.com/thomasklemm/tzinfo.git tzinfo-signed
git -C tzinfo-signed worktree add --detach ../tzinfo-master 1207d6098d7f4a9f294a40801154990850f09bf1
git -C tzinfo-signed worktree add --detach ../tzinfo-refresh 57056ddd7f46f9c292e46687821636e812102c85
gem install concurrent-ruby -v 1.3.8 --no-document
TZINFO_SOURCE="$PWD/tzinfo-master" ruby bench/upstream/tzinfo_signed_bench.rb
TZINFO_SOURCE="$PWD/tzinfo-refresh" ruby bench/upstream/tzinfo_signed_bench.rb
TZINFO_SOURCE="$PWD/tzinfo-master" ruby bench/upstream/tzinfo_signed_check.rb > baseline.json
TZINFO_SOURCE="$PWD/tzinfo-refresh" ruby bench/upstream/tzinfo_signed_check.rb > head.json
cmp baseline.json head.json
```

For instruction workers, set the five heap floors above and wrap
`ruby bench/upstream/tzinfo_signed_bench.rb CASE N` in the Callgrind invocation above; use N=0 and 1000.
The JSON confirms the mode, reader hash, unchanged heap page count and zero GC delta. The reported Ir excludes
GC and cannot establish latency, throughput or a boot-time effect.
