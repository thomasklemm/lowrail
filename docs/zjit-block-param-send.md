# Z3 follow-up: direct Proc sends to explicit block parameters

2026-10-22. **Owner-admitted candidate; fork published, no upstream post by
this research thread.** This is the second and last prototype in the Z3
two-prototype budget. [Ranked census](zjit-fallbacks-2.md).

- Clean standalone-master Ruby commit:
  [`5953e97320`](https://github.com/thomasklemm/ruby/commit/5953e97320a70c8e881df7e2fda6aec77a80b015),
  branch `thomasklemm/zjit-block-param-send-master`.
- Parent is upstream master
  [`8ff4ae135d`](https://github.com/ruby/ruby/commit/8ff4ae135d438314090f0dc23916601ef9c444d5).
  **No dependency on #19478, literal kwrest, or protected sends.**
- Thomas Klemm <github@tklemm.eu> is author and committer; no trailers.
  `/usr/bin/git -c core.hooksPath=/dev/null` was used. Normal fork push
  followed `pull --rebase upstream master`; no force or main write.
- [Raw evidence](zjit-block-param-send.json) contains all 90 timing workers,
  both seeded request comparisons, site counters, semantic source/results,
  instruction windows, diagnostic HIR and test receipts.
- [Dedicated PR preparation thread](https://ampcode.com/threads/T-01a164a8-bc01-7402-b844-209c98cf248d)
  owns independent reviews and any upstream publication.

## Exact change and boundaries

Remove the callee-`&block` refusal from `can_direct_send`. The existing
exact-Proc guard, receiver/CME guard, pre-call snapshots, block-argument
stripping and frame `specval` setup already handle this case. Reading the
block parameter converts the handler with `rb_vm_bh_to_procval`, which returns
the original Proc; it does not copy it. No new code generator or runtime
helper is introduced. The executable diff is three removed lines in
`zjit/src/hir.rs`; the other changes update existing tests/snapshots.

Inlining Proc block handlers, generic C-function block passing, non-Proc
coercion, `&nil` rejection, unused-block warnings, kwrest and forwarding
restrictions are not broadened. The historical block-refusal stats key is
retained, now zero, for direct diagnostic comparison.

## Request impact and corrected site attribution

Measurements reuse the Z2 fixtures/bundles and Z3 harness at Ruby
[`46631773`](https://github.com/thomasklemm/ruby/commit/46631773dd402e769190decb23ea44f64cd69dfc),
**without** the protected-send patch. The same source delta was then
transplanted onto master and its own suites rerun. No master-alone timing or
whole-request speed claim is made.

At seeds 0 and 1, all full response digests and 300-response sequence digests
match base/A/A/patch. Blog changes no send counters. Fizzy removes **27 final
send fallbacks/request**, not 36. Side exits remain blog 36.02/36.15 and
Fizzy 48.03/48.15. These are diagnostic, not JIT-flat request windows.

| Fizzy site, instruction offset | Planner before -> after | Final fallback before -> after |
|---|---:|---:|
| `visit_ActiveModel_Attribute`, `to_sql.rb:747`, PC 7, `add_bind` | 18 -> 0 | 9 -> 0 complex sends |
| `Composite#add_bind`, `composite.rb:27`, PC 8, left `add_bind` | 9 -> 0 | 9 -> 0 complex sends |
| `Composite#add_bind`, `composite.rb:28`, PC 20, right `add_bind` | 9 -> 0 | 9 -> 0 complex sends |
| `SQLString#add_bind`, `sql_string.rb:16`, PC 4, `yield` | — | 9 -> 9 `invokeblock_not_specialized` |

**Correction to an early progress message:** there are no nine surviving
Bind sends for unused-block warnings. That attribution was wrong; the
unused-block counter is zero. The remaining nine add-bind-related fallbacks
are the unchanged SQLString **yield** above. The actual optimized HIR has
two consecutive block-refusal/planner/context counter triples before one
visitor `Send :add_bind`: the fixed-point optimizer revisits that send after
inlining `bind_block`. Thus planner 36 versus final sends 27 is duplicated
planner instrumentation, not nine additional calls. Both seeded site
censuses and the actual HIR excerpt are retained. Planner counters must not
be interpreted as distinct runtime calls.

## One retained timing cohort

[Micro](../bench/experiments/jit_block_param_send.rb): Arel-style forwarding
to an explicit block parameter, 100 × 2,000 warmup iterations followed by
2,000,000 measured iterations. Ten serial, CPU-2-pinned, rotated base/base/
patch rounds per mode, using the existing paired-round estimator. No timing
cohort was rerun. All 90 workers return 112,000,000 and allocate seven objects.

| Mode | Patch wall change [95%] | A/A wall change [95%] |
|---|---|---|
| Interpreter | **+1.75% [+0.03%, +3.67%]** | +1.65% [-1.35%, +5.47%] |
| YJIT | -3.11% [-22.19%, +19.06%] | **+6.06% [-20.01%, +36.71%]** |
| ZJIT | **-61.41% [-63.78%, -59.53%]** | **-3.50% [-9.64%, +1.40%]** |

The owner admitted this cohort: the ZJIT A/A contains zero and its roughly
11-point width is far below the effect size. The noisy YJIT A/A and resolved
interpreter wall increase remain explicit caveats; walls are informational.
No claim of a precise YJIT latency improvement is supported.

A separate 2,000-iteration stats window removes 6,000 complex-send
fallbacks, with unchanged 4,000 generic yields, zero compilation/side exits,
and seven allocations in each binary.

## Fixed-seed Callgrind controls

The unchanged client extension brackets the same micro with GC disabled.
The fixed-getrandom startup shim is used **only** in these disposable Ir
controls, never app/stats/timing runs. Base, A/A and patch are exactly equal,
including N=0; there is no +14 layout delta for this candidate.

| Mode, all three arms | N=0 | N=5,000 | N=10,000 |
|---|---:|---:|---:|
| Interpreter Ir | 2,974 | 13,742,974 | 27,482,974 |
| YJIT Ir | 882,610 | 6,824,712 | 12,479,712 |

All executable changes are in ZJIT compilation, not interpreter or YJIT
execution. These equal instruction windows establish no added work in this
micro, not universal equal wall time or a proven cause of its elapsed noise.

## Correctness and project checks

Standalone master: `make zjit-check ZJIT_TEST_FEATURES=disasm
ZJIT_TESTS='-j 4'` passes **1,883 Rust tests, 15 skipped; 27 CLI tests / 7,394
assertions**. The measured stacked variant passes 1,891 Rust tests, 15
skipped, and the same CLI suite. Existing snapshots were updated to expect
direct sends; the existing rest/optional/keyword test now checks captured
Proc identity as well as its result.

`make test-all RUN_OPTS=MODE TESTS='test/ruby/test_keyword.rb
test/ruby/test_call.rb test/ruby/test_method.rb test/ruby/test_proc.rb'`
passes **454 tests / 7,750 assertions** in interpreter, YJIT, ZJIT and
no-inline ZJIT on both variants. Twelve base/stacked-patch/master-patch ×
mode semantic outputs have identical SHA256
`4f4875602cc4b33b413a7c53e6d97153fd4a73ed253d00d098e4723f136693c0`.
They cover exact Proc identity, closure retention, block reassignment versus
yield, aliases after redefinition, Unicode payloads, optional/rest/keyword
and stack-passed arguments, strict lambda arity, nonlocal return/break,
nil/Symbol/Proc-subclass/coercible transitions, once-only `to_proc`, escaped
bindings, numeric side exits and GC compaction.

Initial failures are disclosed in JSON: two stale expected-fallback
snapshots, an invalid test-runner flag, and a context-reduced transplant
misplacing a repeated snapshot hunk. Only snapshots were affected by the
transplant mistake; they were corrected and all master suites rerun green.

## Upstream and next-ranked investigation

Default branch `master` and open/closed PRs were rechecked. Master and broad
RFC [#19389](https://github.com/ruby/ruby/pull/19389) retain this exact
refusal. Merged [#18180](https://github.com/ruby/ruby/pull/18180) explicitly
lists explicit block parameters as future work.
[#19077](https://github.com/ruby/ruby/pull/19077) handles inlining Proc-block
calls, not this admission; no focused duplicate was found.
`CONTRIBUTING.md`, `doc/contributing/contributing.md` and
`making_changes_to_ruby.md` were read. No AGENTS/PR template or AI/LLM ban
was found in those contribution docs and `.github`; this is a scoped check.

The next high-count avenues still have larger boundaries: Proc/IFUNC yield
dispatch (including the remaining nine) overlaps #19389; C-function `&block`
needs block-handler/frame/keyword setup, not removal of this check; dynamic
`send` (21 blog / 89 Fizzy, including 61 Arel visitor calls) needs method-name
value profiling/guards, target lookup, stack reshaping and permission rules.
Ordinary argument profiles currently retain class/shape rather than the
dynamic method symbol value, so the Arel case is not a small literal-symbol
rewrite. These are deferred, not claimed fixed or prototyped a third time.
