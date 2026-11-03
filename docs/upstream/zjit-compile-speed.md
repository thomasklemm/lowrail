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
  `2fbdceeda7` + test `63483773c1`. Caches the bytecode scan as `may_write_block_code: Option<bool>` on
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

## 4. Not built

* **FxHash (#1049).** The side-exit dedup `HashMap` in `compile_exits` costs up to 0.29G Ir, 4% of compile
  Ir on railsbench. That is data for #1049. Side exits are emitted in that map's iteration order, which
  `RandomState` already makes differ from run to run. So a fixed hasher would change only that order, and
  would make LIR dumps reproducible as a side benefit. Not built, because the bet allowed two candidates; it
  is the natural third.
* **Emit and scratch_split.** These are large (24% and 18% of backend Ir) but have no hotspot that a small
  change would remove.

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
