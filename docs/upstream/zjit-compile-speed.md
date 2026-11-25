# ZJIT compile speed on large Rails apps (bet Z6)

Bet Z6 from the [shortlist](zjit-shortlist.md) (items 4, 6 and 9). Compile time matters for large Rails apps
because warmup is mostly compilation, and `RubyVM::ZJIT.max_compile_time_ns` (ruby/ruby#19184) caps it.

Measured on ruby/ruby master `0c404b09a0`, a release build (`--enable-zjit`, thin LTO), on an 8-core orb.
Neither Discourse nor Fizzy is set up here, so ruby-bench railsbench, lobsters and shipit at 3 iterations
stand in for boot-to-warm. Compile time comes from the zjit stats (`compile_time_ns`, `compile_hir_time_ns`,
`compile_lir_time_ns`) through a small harness,
[`bench/upstream/zjit_compile_time_harness.rb`](../../bench/upstream/zjit_compile_time_harness.rb). The
compiler profile comes from Callgrind on railsbench at 2 iterations.

## 1. Where compile time goes

At 3 iterations, compilation is a large share of each run:

| bench | compile | wall | share | ISEQs | side exits compiled |
|---|---:|---:|---:|---:|---:|
| railsbench | 1.65 s | 6.1 s | 27% | 2,425 | 61,940 |
| lobsters | 5.91 s | 7.9 s | 75% | 5,767 | 177,557 |
| shipit | 4.81 s | 8.3 s | 58% | 5,327 | 150,342 |

On railsbench at 25 iterations compilation takes 1.73 s of 41.7 s, and 1.64 s of that is already spent by
iteration 2.

**HIR vs LIR (stats, median of 12 runs).** LIR is 58%, 57% and 56% of compile time; HIR is 37%, 38% and
39%; compiling side exits is 3–4%. This matches the 30/70 split in Shopify/ruby#1074. The largest HIR
passes are build (6–8%), canonicalize (6–8%), strength_reduce (6–7%) and inline_methods (4%). Every other
pass is ≤2.4%.

**LIR, by Callgrind phase (railsbench, share of `Assembler::compile` Ir, 5.20G).**

| phase | Ir | share | notes |
|---|---:|---:|---|
| regalloc | 1.71G | 33% | `handle_caller_saved_regs` 0.56G, `build_intervals` 0.30G, `resolve_ssa` 0.29G, `analyze_liveness` 0.27G, `linear_scan` 0.14G |
| emit | 1.26G | 24% | `x86_emit` 1.20G, of which `write_byte` 0.69G |
| scratch_split | 0.94G | 18% | |
| compile_exits | 0.82G | 16% | 0.29G is the SipHash `HashMap` (`RandomState`) for side-exit dedup |
| split | 0.38G | 7% | |

Compilation is 7.24G Ir (`gen_iseq`), 28% of the run. Outside the backend, `JITFrame::new_iseq` costs 0.16G,
because it calls `iseq_may_write_block_code`, which rescans the ISEQ's bytecode on every call: 854k scans
through `rb_iseq_bare_opcode_at_pc`. That is Shopify/ruby#1064.

**Ranking of targets, by share of compile Ir and by how small the change is:**

1. `handle_caller_saved_regs` (#1065/#1075): 0.56G, 7.7% of compile. Quadratic in method size.
2. SipHash in `compile_exits` (#1049): up to 0.29G, 4%. Data for #1049; not built here (see 4).
3. `iseq_may_write_block_code` rescans (#1064): 0.16G, 2.2%. Also quadratic in method size, see below.
4. `x86_emit`/`write_byte` and `scratch_split`: large but spread out; no small exact change found.
5. HIR passes: each ≤8% of compile; nothing here is a small change.

Callgrind of lobsters and shipit did not start under valgrind ("brk segment overflow", empty output), so
their LIR breakdown is the stats split only.

## 2. Collision check

Open ruby/ruby PRs in this area: tekknolagi #16667 (`run_pass!`), #17569, #18015, #16563 (stubs without a full
Assembler); supervacuus #19430, #19649, #19653 (asm and virtualmem, for #1073). `git merge-tree` of each PR
against master and against each candidate gives the same conflict files. Those conflicts come from the PRs
being stale against master, not from our changes. Only #16667 mentions `handle_caller_saved_regs`, at the call
sites in `x86_64/mod.rs` and `arm64/mod.rs`, which neither candidate touches. Issues #1064, #1065, #1075 and
#1049 are unassigned and have no comments.

## 3. Candidates

Both candidates are pure compiler-speed changes: each computes the same values as before, faster.

* **c1, #1064**: [`thomasklemm/zjit-cache-may-write-block-code`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-cache-may-write-block-code),
  `4819e46698` (fix and test, squashed). Caches the bytecode scan as `may_write_block_code: Option<bool>` on
  `IseqPayload`. Diff: codegen.rs +9/−1, payload.rs +3, and a 15-line test.
* **c2, #1065 stopgap**: [`thomasklemm/zjit-caller-saved-regs-stopgap`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-caller-saved-regs-stopgap),
  `f7fc82f964`. Before the block loop, collects the sorted CCall positions once. Each register interval's
  live ranges are then mapped onto those positions with two `partition_point` searches. This gives, for each
  CCall, the register intervals covering it. Survivors are those, minus the CCall's own output, plus the
  register-allocated stack-map vregs, sorted and deduplicated. That is the same set, in the same ascending
  `VRegId` order, so the push/pop pairs and stack-map indices are unchanged. Cost goes from
  O(CCalls × intervals × ranges) to O(ranges × log CCalls + survivors). Diff: lir.rs +85/−15, of which 50 lines
  are the test.

Both apply on master independently. c1 cherry-picks cleanly onto c2.

### Tests

* c1 `test_iseq_may_write_block_code_per_iseq`: a `yield` ISEQ answers true and a leaf answers false, asked
  twice each. It fails if the cache is not kept per ISEQ (mutation checked).
* c2 `test_caller_saved_regs_per_call`: two CCalls with different live sets. v1 is live across the first CCall
  only, v2 across both, and v4 is defined between them. The test checks the exact `CPushPair` sequence. It
  fails if ranges are mapped past their end (mutation checked).
* `make zjit-test` (disasm, runtime_checks): c2 1940/1940; c1+c2 with both tests 1941 tests, all pass
  except the flaky one below, which passed 3/3 on rerun.
  `test_profile_frames_during_direct_jit_to_jit_entry` failed in the first c1 run. It fails on base too under
  CPU load (2 of 3 runs with 8 busy loops) and passed 30/30 on c1 when the orb was idle.
* `make btest RUN_OPTS=--zjit-call-threshold=1`: 2141/2141 on c1, on c2 and on the differential build.
* Differential build: c1 and c2 together, plus a check in each function that also runs the old code and
  aborts on any mismatch. It ran railsbench, lobsters and shipit (3 iterations each), btest at threshold 1, and
  test_proc/method/call/super/yield/iterator/backtrace/keyword at threshold 1 (581 tests). There was no
  mismatch. It checked at least 32k `iseq_may_write_block_code` calls and 16k survivor lists on railsbench,
  131k and 65k on lobsters, and 131k and 32k on shipit.

### Generated code is unchanged

Dumps are `--zjit-dump-lir=scratch_split` under `setarch -R`, compared with
[`bench/upstream/zjit_lir_identity.py`](../../bench/upstream/zjit_lir_identity.py). It masks addresses,
install prefixes, side-exit numbers, vreg numbers and `CodePtr` offsets. Side exits come out in `HashMap`
order, so it compares each compiled unit as a sorted line multiset.

| bench | units | base rerun differs | c1 differs | c2 differs |
|---|---:|---:|---:|---:|
| 30k_ifelse | 71,794 | 1 | 1 | 1 |
| 30k_methods | 9,149 | 1 | 1 | 1 |

On 30k_ifelse, the one differing unit is the same ISEQ in each run (`fun_l2_n433`), and it also differs
between two base runs. `code_region_bytes` and `compiled_iseq_count` match base on all three Rails benches.
The railsbench dump itself does not reproduce from base to base (947 of 8,575 units differ), so it is not
used for identity.

### Compile time, Rails benches

Median `compile_time_ns`, 6 runs per ruby per round, 3 iterations, interleaved in rotating order. Round 1
uses the same base binary twice as its A/A. Round 2 uses a second build of the same source (`base2`), which
also controls for code layout. Lobsters round 2 dropped one round of all four rubies because a cargo build
overlapped it.

| bench | A/A r1 | A/A r2 (layout) | c1 r1 | c1 r2 | c2 r1 | c2 r2 |
|---|---:|---:|---:|---:|---:|---:|
| railsbench | +0.5% | +0.6% | −1.7% | −1.5% | −2.2% | −1.2% |
| lobsters | −1.0% | −0.6% | −3.0% | −4.0% | −3.3% | −5.2% |
| shipit | +0.6% | −1.4% | −2.3% | −3.8% | −2.7% | −3.9% |

`compile_lir_time_ns`, round 2: c1 −2.4/−4.8/−4.5%, c2 −2.0/−7.2/−5.2% (A/A layout +0.4/−0.7/−1.4%).

Callgrind, railsbench: c1 cuts `JITFrame::new_iseq` plus the scan from 0.16G to 0.016G Ir. c2 cuts
`handle_caller_saved_regs` from 0.558G to 0.326G Ir (−42%).

**c1 and c2 together.** Callgrind on railsbench, compile Ir (`gen_iseq`) per compiled ISEQ:

| | gen_iseq Ir | ISEQs | per ISEQ |
|---|---:|---:|---:|
| base | 7.239G | 2,390 | — |
| c1 | 7.095G | 2,394 | −2.2% |
| c2 | 7.031G | 2,402 | −3.4% |
| c1+c2 | 6.851G | 2,394 | −5.5% |

A timing round of base against c1+c2 (4 rounds) was too noisy to use. Base's own railsbench runs spanned
1,659–1,892 ms (±7%), against ±1.4% in the A/A rounds above, so that round is inconclusive and not reported
as a result. It came out at railsbench +2.5%, lobsters −5.2% and shipit +1.1%.

### Compile time, one large method

[`bench/upstream/zjit_caller_saved_scaling.rb`](../../bench/upstream/zjit_caller_saved_scaling.rb) compiles one
method made of `s ^= o.hash` repeated N times, so the code size is linear in N:

| N | base | c1 | c2 | c1+c2 | code bytes (all equal) |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 0.30 s | 0.18 s | 0.20 s | 0.12 s | 430,080 |
| 2,000 | 0.92 s | 0.62 s | 0.54 s | 0.20 s | 856,064 |
| 4,000 | 3.58 s | 2.93 s | 1.76 s | 0.53 s | 1,712,128 |

Base grows about 4× per doubling. At N=2000, Callgrind on base has two quadratic terms: `handle_caller_saved_regs`
2.95G Ir (39%) and `JITFrame::new_iseq` rescanning the bytecode at every CCall's JIT frame 3.67G (49%).
Each candidate removes one of them; together compile time grows about 2.6× per doubling.

A related shape is not a compiler-speed problem: when N locals stay live across all N calls, side exits
write every live local. Code size then grows quadratically, and at N=500 the method fails with
`out_of_memory` after 0.7 s of compiling. That is generated code, so it is out of scope for this bet.

### Rebased on master `9aa0898240` (for the PRs)

After tekknolagi's go-ahead on both issues (#1064: "Go for it", assigned to us; #1065: "go for it", plus a
request to avoid an interstitial `Vec` per CCall), both candidates were rebased onto master `9aa0898240` as
one commit each, independent of each other:

* c1 [`97767f4d20`](https://github.com/thomasklemm/ruby/commit/97767f4d205c3f6614a97d6982f4465078767ecf):
  the squashed fix and test, unchanged.
* c2 [`dea97c3afa`](https://github.com/thomasklemm/ruby/commit/dea97c3afa0e3f4e2069968c45e26355247eca4a):
  reworked. The covering intervals are one flat `Vec<VRegId>` indexed by per-position offsets (a counting
  pass, then a fill pass), instead of a `Vec<Vec<VRegId>>` with one inner `Vec` per CCall position. Each
  CCall reads its slice into `survivors`/`survivor_regs` buffers that are cleared and reused, so the loop
  allocates nothing per CCall. Stack-map register vregs that are not in the slice are appended, and the
  buffer is sorted only if any were.

Checks on the rebased heads: zjit-test 1940/1940 on each (the load-flaky profile-frames test failed once on
c2 and passed 5/5 alone and in a full rerun); btest at `--zjit-call-threshold=1` 2141/2141 on each. The
cross-check build (c1 + c2, plus the old code run next to the new and an abort on any difference) found no
mismatch on railsbench, lobsters and shipit (at least 16k/65k/32k survivor lists and 32k/131k/131k block-code
answers), btest at threshold 1 and the 581 test-all tests. Normalized LIR dumps: 30k_ifelse and
30k_methods each differ from base in 1 unit, the same as a base rerun. The c2 test still fails on the
broken-span mutant.

`compile_time_ns`, median of 6 interleaved runs, 3 iterations, against base. `aa` reruns the base binary;
`base2` is a second build of the same source.

| bench | aa | base2 | c1 | c2 |
|---|---:|---:|---:|---:|
| railsbench (base 1,725 ms) | +0.0% | −0.6% | −2.3% | −2.9% |
| lobsters (base 5,926 ms) | −0.8% | +0.2% | −2.6% | −5.4% (LIR −7.7%) |
| shipit (base 4,922 ms) | +2.8% | +3.2% | +0.3% | +0.3% |

Shipit is inconclusive in this round: its two A/A controls are larger than either effect. Against all 18
base-equivalent runs pooled, c1 and c2 are both −1.7% there. The two rounds on `0c404b09a0` measured
−2.3/−3.8% (c1) and −2.7/−3.9% (c2).

Callgrind, railsbench, 2 iterations: c2 `handle_caller_saved_regs` 558M → 328M Ir (−41%), the same as the
`Vec<Vec>` version (326M). c1 `JITFrame::new_iseq` plus the scan 161M → 16M Ir.

Single method, [`zjit_caller_saved_scaling.rb`](../../bench/upstream/zjit_caller_saved_scaling.rb), two runs
each: N=2000 base 1.02/1.30 s, c1 0.70/0.69 s, c2 0.68/0.60 s; N=4000 base 3.53/3.48 s, c1 2.32/2.36 s,
c2 1.73/1.89 s. Code bytes are equal in all runs. (The scaling script on main before this commit was an
earlier draft with all results live; it now matches the method these tables use.)

## 4. Not built

* **FxHash (#1049).** The side-exit dedup `HashMap` in `compile_exits` costs up to 0.29G Ir, 4% of compile
  Ir on railsbench. That is data for #1049. Side exits are emitted in that map's iteration order, which
  `RandomState` already makes differ from run to run. So a fixed hasher would change only that order, and
  would make LIR dumps reproducible as a side benefit. Not built, because the bet allowed two candidates; it
  is the natural third.
* **Emit and scratch_split.** These are large (24% and 18% of backend Ir) but have no hotspot that a small
  change would remove.

## Leads (recorded, not built)

* **Side exits that write every live local make code size quadratic.** Followed up as bet Z9, see
  [section 6](#6-side-exit-code-size-bet-z9). XrXr's open ruby/ruby#18960 already makes it linear; Rails code
  does not reach it.
* **FxHash for the side-exit dedup map (#1049).** On railsbench it costs up to 0.29G Ir, 4% of compile Ir,
  inside `compile_exits`. Exit order is already `RandomState`-random from run to run, so a fixed hasher
  would not make generated code less exact; it would make LIR dumps reproducible. Measure it with the
  same A/A rounds as c1/c2 before proposing it.

## 5. Issue comment drafts (not posted)

**Shopify/ruby#1064**

> We'd like to take this one. We measured it on ruby-bench Rails workloads (master `0c404b09a0`, release
> build). `JITFrame::new_iseq` calls `iseq_may_write_block_code` once per JIT frame, i.e. once per CCall with a
> frame and once per side exit. That is 854k bytecode scans on railsbench at 2 iterations, 2.2% of compile Ir. In one
> large method it is quadratic: with 2,000 calls the rescans are half of the compile.
>
> A cached `Option<bool>` on `IseqPayload`
> ([branch](https://github.com/thomasklemm/ruby/compare/master...thomasklemm:ruby:thomasklemm/zjit-cache-may-write-block-code))
> gives `compile_time_ns` −1.5…−1.7% on railsbench, −3.0…−4.0% on lobsters and −2.3…−3.8% on shipit. Those are
> two rounds of 6 interleaved runs; the A/A was within ±1.4%. A cross-check build compared the cached and
> fresh answers on every call through all three benches and btest at threshold 1, and found no mismatch.
> Normalized LIR dumps of 30k_ifelse/30k_methods are identical to base. OK if we send a PR?

**Shopify/ruby#1065 (and #1075)**

> We'd like to take the stopgap. Before the block loop, it collects the sorted CCall positions once. Each
> register interval's live ranges are then mapped onto them with a binary search, which gives the covering
> intervals of every CCall. The survivor list per CCall is that, plus the stack-map vregs, in the same
> `VRegId` order as today, so the generated code doesn't change. It doesn't attempt interval splitting.
> [Branch](https://github.com/thomasklemm/ruby/compare/master...thomasklemm:ruby:thomasklemm/zjit-caller-saved-regs-stopgap).
>
> On railsbench (master `0c404b09a0`) `handle_caller_saved_regs` drops from 7.7% of compile Ir to 4.6% (−42%).
> `compile_time_ns`, two rounds of 6 interleaved runs (A/A within ±1.4%):
>
> * railsbench −1.2…−2.2%;
> * lobsters −3.3…−5.2%, LIR −5.3…−7.2%;
> * shipit −2.7…−3.9%.
>
> In a single method of N `s ^= o.hash` calls it halves the compile: 3.58 s → 1.76 s at N=4000. With #1064 also
> fixed it drops to 0.53 s.
>
> A cross-check build compared the old and new survivor lists on every CCall through railsbench, lobsters,
> shipit and btest at threshold 1, and found no difference. Normalized LIR dumps of 30k_ifelse/30k_methods are
> identical to base. OK if we send a PR?

## 6. Side-exit code size (bet Z9)

Follow-up to the Z6 side finding. Same base (master `0c404b09a0`, release build); ruby/ruby#18960 head
`0564799aa1` (merge base `b51db981f6`). Rails numbers are one run of 3 iterations each.

**Prior work.** No Shopify/ruby issue reports side-exit size or the out-of-memory case. Related issues:
#1056 (cold code region for exits, k0kubun's survey), #660 (shared epilogues), #718 (avoid re-spilling
locals), #1021 ("stack map for local variables"). The open fix is XrXr's ruby/ruby#18960, "Locals in stack
map; HIR local spills; always locals in exits" (updated 2026-11-03, built on alanwu's draft #17991). With
#18960, a side exit no longer stores locals or `cfp->pc`/`cfp->iseq`. It stores `cfp->sp`, captures register
values for the stack map, installs the JITFrame and jumps. So this is owned, and we file no issue.

**Repro.** [`bench/upstream/zjit_live_exits.rb`](../../bench/upstream/zjit_live_exits.rb) N: one method with
N `vI = o.hash` whose results all stay live until the end.

| N | master exits | master exit bytes | master code region | #18960 exit bytes | #18960 code region |
|---:|---:|---:|---:|---:|---:|
| 50 | 261 | 134 KB | 180 KB | 11 KB | 25 KB |
| 100 | 511 | 530 KB | 676 KB | 21 KB | 45 KB |
| 200 | 1,011 | 2.11 MB | 2.64 MB | 40 KB | 86 KB |
| 300 | 1,511 | 4.74 MB | 5.91 MB | 60 KB | 123 KB |
| 400 | 2,011 | fails: `out_of_memory` | | 80 KB | 164 KB |

On master each exit writes every live local (about 10 B per local), so exit code grows as N² and is 80% of
the method's code. N=400 fails under the default `--zjit-mem-size=128`, which counts compiler memory as well
as code. It compiles with `--zjit-mem-size=512`, to 10.5 MB. With #18960 an exit is about 33 B whatever N is.
Compile time stays super-linear (87 → 334 ms from N=200 to 400) because of the two Z6 quadratics, which
c1 and c2 address.

**Rails does not reach it.** A measurement-only patch,
[`bench/upstream/zjit_exit_footprint.patch`](../../bench/upstream/zjit_exit_footprint.patch), logs each
compile's exit bytes, unique exits and local/stack stores.
[`zjit_exit_footprint.py`](../../bench/upstream/zjit_exit_footprint.py) summarizes the log.

| bench | exits | exit bytes / code region | B/exit | locals per exit | max locals in one exit | largest compile's exits |
|---|---:|---:|---:|---:|---:|---:|
| railsbench | 66,969 | 4.65 / 7.79 MB (60%) | 69 | 2.1 | 22 | 42 KB, tzinfo `zoneinfo_reader.rb:345` |
| lobsters | 192,650 | 13.0 / 24.0 MB (54%) | 68 | 1.8 | 22 | 116 KB, `comments/_comment.html.erb` |
| shipit | 163,542 | 10.7 / 19.9 MB (54%) | 66 | 1.6 | 22 | 42 KB, tzinfo `zoneinfo_reader.rb:345` |

The largest compiles are big templates with about 1,000 exits of 5–8 locals each, not many locals. Across
compiles, exit bytes fit 42–44 B per exit + 8–10 B per local + 6–7 B per stack slot (R² 0.99). Fixed
per-exit stores (pc, sp, iseq, jump) are 61–66% of exit bytes, locals 22–28%, stack slots 13–14%. The
largest local count in any Rails exit is 22, so quadratic growth plays no role here. The large exit share
comes from the number of exits and their fixed cost.

**What #18960 does on Rails** (default counters, one run each; no A/A, so the compile-time column is
indicative only):

| bench | code region | exit bytes | exits | B/exit | stack-map data | compile time |
|---|---:|---:|---:|---:|---:|---:|
| railsbench | 7.79 → 6.25 MB (−20%) | 4.31 → 2.93 MB (−32%) | 61,940 → 82,928 | 70 → 35 | 0.07 → 0.66 MB | +3% |
| lobsters | 23.95 → 19.96 MB (−17%) | 12.00 → 8.65 MB (−28%) | 177,567 → 252,642 | 68 → 34 | 0.27 → 1.98 MB | +4% |
| shipit | 19.94 → 17.17 MB (−14%) | 9.86 → 7.49 MB (−24%) | 150,342 → 216,959 | 66 → 35 | 0.21 → 1.64 MB | +4% |

Exits halve in size but rise in number by 34–42%, probably because exits whose stack maps differ no longer
deduplicate (not verified). The stack maps move about 0.6–1.7 MB out of code into JITFrame data.

**Smallest fix.** It is #18960. Writing only the locals that differ from memory would be a smaller patch on
master, but it would collide with #18960, which deletes the locals list from `SideExit`. So no prototype was
built. After #18960 the fixed part of an exit is roughly a 14-byte JITFrame pointer store, an 8-byte sp store
and a 5-byte jump. Making that table-driven, as Cinder's return-address lookup in #1056 does, is the next step,
and it is k0kubun's and XrXr's area.

**F1 apps.** Mastodon and Discourse run in F1's orb (T-01a19e58), not here. `side_exit_size_bytes` and
`code_region_bytes` are default counters, so F1's ZJIT stats pass will report the share for them without a
new run.

**Draft comment for ruby/ruby#18960 (not posted).**

> Some data in case it helps this land. On master, a method with N locals live across N calls writes every
> live local at every side exit, so exit code grows as N²: 2.1 MB of 2.6 MB at N=200. At N=400 it fails with
> `out_of_memory` under the default `--zjit-mem-size`. With this PR's head (`0564799aa1`) exits are about 33 B
> each, and N=400 compiles to 164 KB. Repro: `def big(o) = (v0 = o.hash; …; v{N-1} = o.hash; s = 0;
> s ^= v0; …; s)`, called 3 times with `--zjit-call-threshold=2`.
>
> On ruby-bench (3 iterations), `code_region_bytes` drops 20% on railsbench, 17% on lobsters and 14% on
> shipit, and side-exit bytes drop 24–32%. Exits halve in size (about 69 → 35 B) but rise in number by
> 34–42%. Stack-map data grows by 0.6–1.7 MB.


## 7. Real workloads on master `f63048e942` (RUBY19681, 2026-11-25)

k0kubun asked on ruby/ruby#19681 (2026-11-25 00:51 UTC) what the change does on lobsters and other real workloads.
The PR body said `compile_time` on railsbench, lobsters and shipit "moved by less than run-to-run noise", while the
issue comment above and the ledger said lobsters −3…−5%. Measured again to settle it.

**Setup.** ruby/ruby master `f63048e942` and PR head `5df7fefa50` rebased onto it (scratch `f51c1353b2`, same
patch, nothing pushed), both `--enable-zjit` release builds (thin LTO, YJIT off), on a 2-core, 4 GB orb with
nothing else running. ruby-bench `c54da6e`, plain `--zjit`. Scripts:
[`bench/upstream/ruby19681/`](../../bench/upstream/ruby19681/).

**Timing.** [`rounds.sh`](../../bench/upstream/ruby19681/rounds.sh): 10 rounds, each one `run_benchmarks.rb
--interleave --turbo --no-sudo --zjit-stats=compile_time_ns,compile_lir_time_ns` per benchmark over three
executables, `master`, `aa` (the same master binary) and `head`, with the order rotated per round (ruby-bench's
default 15 warmup and 10 timed iterations; it pins to core 0). Pooled with ruby-bench's own `ResultsTableBuilder`
([`pooled_table.rb`](../../bench/upstream/ruby19681/pooled_table.rb)): iteration times of all rounds together, stats
the median over rounds.

```
bench         master (ms)  compile_time_ns  compile_lir_time_ns        aa (ms)  compile_time_ns  compile_lir_time_ns      head (ms)  compile_time_ns  compile_lir_time_ns  aa 1st itr  head 1st itr  master/aa  p-value       sig  master/head  p-value  sig
lobsters     788.9 ± 7.8%    5,117,946,763        3,163,929,397   803.7 ± 9.2%    5,147,785,856        3,171,935,703   797.8 ± 7.6%    4,774,260,682        2,809,971,602       1.023         1.025      0.982    0.127                  0.989    0.307
railsbench  1685.9 ± 5.9%    1,406,784,625          841,561,951  1655.7 ± 3.8%    1,396,819,547          835,607,417  1719.3 ± 8.2%    1,437,515,839          845,513,679       1.050         0.957  1.018 (*)    0.011  p < 0.05        0.981    0.056
shipit      1345.5 ± 8.8%    4,019,669,732        2,392,400,476  1328.1 ± 7.3%    4,042,925,926        2,408,709,523  1361.1 ± 7.7%    3,894,138,988        2,274,240,743       0.917         1.020      1.013    0.257                  0.989    0.325
```

Against master, median over rounds ([`summary.txt`](../../bench/upstream/ruby19681/summary.txt)); per round, head
against the mean of master and aa in the same round (mean ± standard error over 10 rounds):

| bench | compile_time A/A | compile_time head | per round | head below both | compile_lir_time A/A | compile_lir_time head | per round |
|---|---:|---:|---:|---:|---:|---:|---:|
| railsbench | −0.7% | +2.2% | +1.7 ± 1.4% | 4/10 | −0.7% | +0.5% | +0.0 ± 1.4% |
| lobsters | +0.6% | −6.7% | −4.7 ± 1.4% | 9/10 | +0.3% | −11.2% | −9.3 ± 1.3% |
| shipit | +0.6% | −3.1% | −3.7 ± 1.0% | 8/10 | +0.7% | −4.9% | −5.5 ± 1.0% |

Single-run A/A pairs spread up to ±7% (railsbench) and ±4–6% (lobsters, shipit), which is why one run each could not
resolve it. Head is faster on lobsters and shipit in every run position (lobsters mean compile_time 4,762, 4,935 and
4,960 ms when head ran first, second and third, against 5,053–5,179 ms for master and aa in any position).
`compiled_iseq_count` and `code_region_bytes` are equal within ±2 ISEQs and one 4 KiB page in every round.

**Run time** does not change: master/head 0.989, 0.981 and 0.989 (p 0.31, 0.06, 0.33), inside the A/A (master/aa
1.018 on railsbench, significant at p 0.011, which shows the run-time noise here). That is expected, since the
generated code is the same (section 3), but it is measured, not assumed.

**Callgrind.** [`cg.sh`](../../bench/upstream/ruby19681/cg.sh): pinned Valgrind 3.19 with the brk reservation,
fixed heap (`RUBY_GC_HEAP_INIT_BYTES=32 MiB`), ruby-bench default harness with 5 warmup and 1 timed iteration,
collection toggled on inside `zjit::stats::with_compile_time_stat` (the function whose wall time `compile_time_ns`
counts). One run each; no `brk segment overflow`, no failed ISEQs
([`callgrind.txt`](../../bench/upstream/ruby19681/callgrind.txt)).

| bench | compile Ir master | head | change | `handle_caller_saved_regs` master | head | share of compile, master → head | rest of compile |
|---|---:|---:|---:|---:|---:|---:|---:|
| railsbench | 7.716G | 7.397G | −4.1% | 639M | 314M | 8.3% → 4.2% | +0.08% |
| lobsters | 26.274G | 23.175G | −11.8% | 4,199M | 1,073M | 16.0% → 4.6% | +0.12% |
| shipit | 21.377G | 20.284G | −5.1% | 2,035M | 922M | 9.5% → 4.5% | +0.10% |

ISEQs compiled: 2,722/2,723, 6,627/6,624 and 6,327/6,326. The whole Ir difference is in `handle_caller_saved_regs`;
everything else in compilation agrees within 0.12%, which stands in for a Callgrind A/A. The regalloc phase
(`compile_with_regs::{closure#1}`) goes 1.66G → 1.33G, 7.60G → 4.47G and 4.99G → 3.88G.

**Conclusion.** The body's sentence was wrong for lobsters and shipit: lobsters compile_time −6.7% (LIR −11%), shipit
−3.1% (LIR −5%), both well outside the A/A, and Callgrind −11.8% and −5.1% of compile instructions. Railsbench doesn't
move outside wall-time noise (+2.2% against single-run A/A spreads of ±7%), though Callgrind counts −4.1% there. The
earlier −3…−5% on lobsters (master `0c404b09a0`, `9aa0898240`) was right in sign and somewhat low; the share of
`handle_caller_saved_regs` in lobsters' compile Ir is larger than the railsbench profile (7.7%) suggested. Run time
doesn't change.

**Receipts.** [`raw/rounds.tar.gz`](../../bench/upstream/ruby19681/raw/rounds.tar.gz): the 30 run_benchmarks JSON
files and their tables (the full stdout of each run was overwritten by its table file when copying; the JSON is
complete). [`raw/cg-logs.tar.gz`](../../bench/upstream/ruby19681/raw/cg-logs.tar.gz) and
[`raw/cg-annotate-top80.txt.gz`](../../bench/upstream/ruby19681/raw/cg-annotate-top80.txt.gz): Callgrind logs and the
top of `callgrind_annotate --inclusive=yes` per profile; the 15 MB profiles stay in the orb.

**Reply draft for ruby/ruby#19681 (not posted; Thomas approves):**

> On lobsters it cuts compile time by about 7% and on shipit by about 3%; railsbench doesn't move by more than noise.
>
> This is master `f63048e942` against this PR rebased onto it, release builds, with ruby-bench's railsbench,
> lobsters and shipit and `--zjit`. It's 10 rounds of `./run_benchmarks.rb -e "master::ruby --zjit" -e "aa::ruby
> --zjit" -e "head::ruby --zjit" --interleave --zjit-stats=compile_time_ns,compile_lir_time_ns <bench>`, rotating the
> order each round; `aa` is the master binary again. Times pool all rounds' iterations, and the stats are the median
> of the 10 rounds:
>
> ```
> bench         master (ms)  compile_time_ns  compile_lir_time_ns        aa (ms)  compile_time_ns  compile_lir_time_ns      head (ms)  compile_time_ns  compile_lir_time_ns  aa 1st itr  head 1st itr  master/aa  p-value       sig  master/head  p-value  sig
> lobsters     788.9 ± 7.8%    5,117,946,763        3,163,929,397   803.7 ± 9.2%    5,147,785,856        3,171,935,703   797.8 ± 7.6%    4,774,260,682        2,809,971,602       1.023         1.025      0.982    0.127                  0.989    0.307
> railsbench  1685.9 ± 5.9%    1,406,784,625          841,561,951  1655.7 ± 3.8%    1,396,819,547          835,607,417  1719.3 ± 8.2%    1,437,515,839          845,513,679       1.050         0.957  1.018 (*)    0.011  p < 0.05        0.981    0.056
> shipit      1345.5 ± 8.8%    4,019,669,732        2,392,400,476  1328.1 ± 7.3%    4,042,925,926        2,408,709,523  1361.1 ± 7.7%    3,894,138,988        2,274,240,743       0.917         1.020      1.013    0.257                  0.989    0.325
> ```
>
> Run time doesn't change, as expected, since the generated code is the same.
>
> Compile time varies by up to ±7% from run to run on this machine, so I also counted the instructions spent in
> compilation with Callgrind: 26.3G to 23.2G on lobsters (−11.8%), 21.4G to 20.3G on shipit (−5.1%) and 7.7G to 7.4G
> on railsbench (−4.1%). All of the difference is in `handle_caller_saved_regs`, which drops from 16% to 5% of
> compilation on lobsters. I've corrected the description, which said these didn't move.
