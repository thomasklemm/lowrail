# YJIT `sendforward` (bet J2)

**Result: it pays, and a small exact design exists.** YJIT refuses every call site that *passes* `...`
(`send_forwarding`) and falls back to `rb_vm_sendforward`. On ruby-bench headline benchmarks this costs 0.14–0.59% of
compiled sends and 3–13% of dynamic sends. The candidate specializes the common shape, where the forwarding method's
caller passed **no arguments** (`relation.where_clause.empty?`, `connection.current_transaction`). It removes
**0.47% / 1.08% / 0.43%** of YJIT instructions on railsbench / shipit / lobsters, every candidate sample below every
A/A sample. erubi-rails is a null (−0.03%, A/A spread 0.25%). Wall time on this orb: see [below](#wall-time).

One commit on master [`90dbced795`](https://github.com/ruby/ruby/commit/90dbced795) (measured on `2bc6f9a60e`; the rebase was clean):
[`thomasklemm/yjit-sendforward`](https://github.com/thomasklemm/ruby/tree/thomasklemm/yjit-sendforward),
[`38c5103ba6`](https://github.com/thomasklemm/ruby/commit/38c5103ba6912235815b214d3bac24167a91bf43) (was `3f40995f60`; the code is unchanged, only tests were added). Not opened;
nothing posted on GitHub.

## Prior work

* **ruby/ruby#18326** (nozomemein, open, ZJIT): profiles the caller callinfo at `sendforward` sites and specializes
  monomorphic simple positional forwarding into direct ISEQ sends. The only comment is its author's railsbench
  profile: 91.5% of `sendforward` caller callinfos are monomorphic. ZJIT only, so this does not duplicate it; the YJIT
  design uses the same observation (one caller callinfo per site).
* **ruby/ruby#18606** (k0kubun, closed, ZJIT): direct sends *to* forwardable callees (`def foo(...)`); the callee's
  `sendforward` still falls back. "Is this something the inliner could handle?" "Yes, it should be."
* YJIT already compiles calls *to* forwardable callees (#11041, #11074, #12660, #17972); `send_iseq_forwarding` was
  renamed `send_forwarding` in #12550. No YJIT attempt at the forwarding *call site* was found in ruby/ruby or
  Shopify/ruby (Shopify/ruby#734 is the closed ZJIT `sendforward` issue). The only maintainer statement is the
  source comment, "Dynamic stack layout. No good way to support without inlining."

## What blocks it

`def empty?(...) = predicates.empty?(...)` compiles to `getlocal ...` (the caller's callinfo, which
`vm_callee_setup_arg` stored as the method's only local) followed by `sendforward <mid:empty?, argc:0,
FCALL|FORWARDING>`. At runtime `vm_caller_setup_fwd_args` reads the caller callinfo from the stack top,
`vm_adjust_stack_forwarding` overwrites it with `caller_argc` values memcpy'd from below the method's EP (plus a splat
array's elements if the site splats), and builds a stack callinfo merging site and caller flags, argc and kwargs. So
the number of values the call consumes, and their kinds, depend on a value only known at runtime. That is the
"dynamic stack layout" the comment means.

YJIT does not need inlining for this: it specializes on runtime values with guards everywhere. Guarding the caller
callinfo pointer (callinfos are interned or embedded, so one site sees one value per caller shape, as #18326
measured) makes the layout static. The smallest exact case is `vm_ci_argc(caller_ci) == 0` without kwargs: nothing
is copied, the site's own arguments are already in place, and the call is the site's call minus the callinfo slot.

## Numbers on master (YJIT, per iteration after 10 warmups)

| | railsbench | lobsters | shipit | erubi-rails |
| --- | ---: | ---: | ---: | ---: |
| `send_forwarding` | 75,134 | 31,790 | 100,648 | 20,000 |
| share of `num_send` | 0.59% | 0.40% | 0.57% | 0.14% |
| share of `num_send_dynamic` | 12.7% | 8.0% | 12.9% | 2.6% |
| specialized by the candidate | 56,534 (75%) | 20,894 (66%) | 71,829 (71%) | 10,000 (50%) |
| left: caller passed arguments (`send_forwarding_caller_args`) | 18,600 | 10,325 | 26,825 | 10,000 |
| left: site shape (`send_forwarding`) | 0 | 555 | 1,994 | 0 |

`num_send_dynamic` falls by 30.6k / 19.3k / 71.6k / 10.0k per iteration. A temporary interpreter probe (not
committed) agreed: 75% / 68% / 72% / 50% of `rb_vm_sendforward` calls had an argc-0 caller, no splat at any site,
none in an escaped environment.

Micro (`--yjit`, best of 5, 10M calls, ns/call, master → candidate; non-forwarding equivalent in brackets): ISEQ
callee 55.4 → 18.8 [18.5]; `attr_reader` 45.0 → 19.8 [17.6]; `Array#empty?` 43.3 → 19.0 [4.0]; caller passing one
argument 61.1 → 54.3 [18.5] (still the fallback).

## Design

In `gen_send_general`, a `FORWARDING` site goes through `jit_forward_args` instead of returning `None`:

1. Refuse unless the site's flags are only `FCALL|FORWARDING` (no site splat, kwargs or block argument), there is no
   block ISEQ, and the ISEQ is a method (so the forwarded block and locals are in this frame). Megamorphic sites fall
   back as before.
2. Peek the caller callinfo at stack top; refuse (counted `send_forwarding_caller_args`) unless argc 0, no kwargs and
   flags within `ARGS_SIMPLE|FCALL|VCALL|FORWARDING`.
3. Guard the callinfo pointer and, if no block was given at compile time, the method's block handler being none (both
   chain guards). Otherwise pass `BlockHandler::FindFromCurrentFrame`, the method's block, as `invokesuper` does.
4. Spill and pop the callinfo slot, clear `FORWARDING` and continue as an ordinary send. Side exits and chain guards
   rewind to the instruction's stack size, so the callinfo stays in memory for the interpreter. `peek_at_stack` now
   accounts for values popped since the start of the instruction (it reads `cfp->sp`, which is the start).

Exactness boundaries: the caller's `VCALL` flag is dropped together with `FORWARDING`, as in the interpreter
(`MISSING_VCALL` is only set without `FORWARDING`, Bug #21535); a missing method falls back to `rb_vm_sendforward`
(`send_cme_not_found`) and raises the same `NoMethodError`. A forwardable callee receives the site callinfo, whose
argc equals the values on the stack, as in `vm_callee_setup_arg`.

## Tests

In `test/ruby/test_yjit.rb`:

* `test_send_forwarding_without_caller_args` (`no_send_fallbacks: true`): ISEQ, `attr_reader` and cfunc callees,
  `self.` and FCALL callers, with and without a block (`block_given?` through `...`). **Fails on master:**
  `<0> expected but was <7>` dynamic sends.
* `test_send_forwarding_leading_args_blocks_and_nesting` (`no_send_fallbacks: true`, added after review): sites with
  their own leading arguments (`lead(7, ...)`, `lead(@lead, ...)`, so receiver and argument peeks go through the
  adjusted `peek_at_stack`), a target that `yield`s and one that materializes `&block` and calls it, block-absent →
  present → absent and present → absent → present at one site, and `outer → middle → inner → lead` forwarding.
  **Fails on master:** `<0> expected but was <13>`.
* `test_send_forwarding_with_caller_args`: positional, keyword, splat and empty callers through one site (guard
  chain and fallback), plus `forward(8, ...)` into a forwarding method, whose inner site then falls back. Passes on
  master; protects the refusals.
* `test_send_forwarding_side_exits`: eight receiver classes (megamorphic), method_missing → `NoMethodError`, stack
  overflow through `def recurse(...) = recurse(...)`. Passes on master; protects the exit paths.

`make yjit-check` with release `--enable-yjit` and with `--enable-yjit=dev`: cargo 374 passed, btest at
`--yjit-call-threshold=1` all 2,138 passed, test_yjit 153 tests, 0 failures (1 pre-existing skip). At `38c5103ba6`
(rebased, dev build): cargo 374, btest 2,138/2,138, test_yjit 154 tests, 0 failures, 1 skip. Also
test_method/call/syntax/keyword/super/backtrace at threshold 1 on the dev build: 538 tests, 0 failures.
Because `peek_at_stack` is shared, a temporary assertion (not committed) panicked if any instruction other than
`sendforward` peeked with a stack size different from the instruction start. btest at threshold 1 (2,138) and
test_yjit/method/call/keyword/super/proc/array/hash/string at threshold 1 (1,958 tests) passed without tripping it,
so the adjustment changes no existing caller.

**Review:** Codex Thermos (GPT-6 Astra) approve-with-nits on both rubrics on `3f40995f60`. Neither review found a behavior defect. The shared nit was test coverage, addressed by the tests added in `38c5103ba6`.

## Instructions (primary)

Callgrind (Valgrind 3.19.0 with the 512 MiB brk patch, `script/bench-valgrind`, tool sha256 `3a477405…`),
`setarch -R`, YJIT, ruby-bench harness `irwin`: 10 warmup iterations, `GC.start`, then 3 iterations with GC disabled,
bracketed by `RubyVM.stat` (`--dump-before=vm_stat`). Two independently built master binaries from the same commit
(`master`, `master2`) form the A/A control; two samples per arm (master three on railsbench, shipit and
erubi-rails).

| Ir, 3 iterations | railsbench | shipit | lobsters | erubi-rails |
| --- | ---: | ---: | ---: | ---: |
| control mean (master + master2) | 13,820.6M | 9,658.2M | 9,203.9M | 12,587.3M |
| control spread (max − min) | 0.16% | 0.17% | 0.21% | 0.25% |
| candidate | 13,770.0M, 13,742.0M | 9,551.0M, 9,557.8M | 9,165.6M, 9,163.6M | 12,593.5M, 12,573.9M |
| **candidate vs control mean** | **−0.47%** | **−1.08%** | **−0.43%** | −0.03% (null) |
| worst candidate vs best control | −0.29% | −0.97% | −0.34% | overlaps |

About 380–630 instructions per specialized call (railsbench 21.5M / 56.5k, shipit 34.6M / 71.8k, lobsters
13.1M / 20.9k), more than the dispatch alone: the callees are now compiled as direct sends.

## Wall time

**Rejected cohort: the A/A control fails, so no timing claim.** Six rounds of `run_benchmarks.rb --interleave
--no-sudo --warmup=15 --bench=25` with the three executables in rotating order, one 8-vCPU orb, pinned to one core.
Per round the median iteration; mean of log ratios over rounds, t 95% intervals.

| | railsbench | lobsters | shipit | erubi-rails |
| --- | ---: | ---: | ---: | ---: |
| A/A master2 / master | +1.98% [−0.80, +4.84] | +1.10% [−4.54, +7.08] | −4.16% [−8.24, +0.09] | **+6.66% [+0.75, +12.92]** |
| candidate / both masters | −0.44% [−3.34, +2.56] | +0.81% [−2.58, +4.33] | −0.06% [−3.46, +3.46] | +0.91% [−3.52, +5.55] |

Two builds of the same commit differ by up to 6.7%, an order of magnitude above the instruction effect, so this orb
cannot resolve the change in wall time. Not rerun until green. A maintainer run on bare-metal ruby-bench is needed for
a timing number.

## PR draft (not opened)

Decision: submit without a wall-time number.

> **YJIT: Specialize sendforward when the caller passed no arguments**
>
> YJIT falls back to `rb_vm_sendforward` at every site that passes `...`, including every method `Module#delegate`
> generates in Rails. When the forwarding method's caller passed no arguments, nothing needs copying. This guards
> the caller's callinfo and the method's block handler, drops the callinfo slot and compiles a regular send with the
> method's block. Callers passing arguments still fall back.
>
> | ruby-bench YJIT, per iteration | railsbench | shipit | lobsters | erubi-rails |
> | --- | ---: | ---: | ---: | ---: |
> | `send_forwarding` | 75,134 → 0 | 100,648 → 1,994 | 31,790 → 555 | 20,000 → 0 |
> | `num_send_dynamic` | −5.2% | −9.2% | −4.9% | −1.3% |
> | instructions (Callgrind, A/A ≤ 0.25%) | −0.47% | −1.08% | −0.43% | −0.03% |
>
> I could not measure wall time reliably on my machine.
