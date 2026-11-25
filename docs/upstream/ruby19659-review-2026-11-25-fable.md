# RUBY19659: thermos-fable review of the argument-planner candidate (2026-11-25)

Reviewed head: [`2f73e7b80a`](https://github.com/thomasklemm/ruby/commit/2f73e7b80adbb5b4353f9ef684e8982280fdfb0f)
on `thomasklemm/zjit-yield-surplus-args-5`, one commit on ruby master `f70ba2530d`. Both Thermos rubrics
(correctness and maintainability) applied by one reviewer on Claude Fable 5.2, without subagents. The parallel
thermos-sol pass was read only after the audit and the runs below were finished. Built with `--enable-zjit=dev`
in the review orb. Nothing was pushed to Ruby and nothing was posted.

**Verdict: changes**, for one sentence of the live body and, following thermos-sol, one doc comment. The
executable code has no must-fix, and the design is what XrXr asked for as far as his written positions show.

## Design: is this what XrXr meant?

His review, on `c65c6f4c49`, in full: "This shouldn't be done adhoc the way it is and should be made as changes
to the argument planner." ([review](https://github.com/ruby/ruby/pull/19659#pullrequestreview-6046725784)). It has
no inline comments. "Argument planner" appears nowhere else on ruby/ruby or Shopify/ruby; it is his name for the
SendDirect argument planning (`build_send_direct_args`, `SendDirectCall`, `emit_send_direct_args`), which
[#18288](https://github.com/ruby/ruby/pull/18288) split out under the title "Split SendDirect argument planning
from HIR emission".

Judgment: **the head meets the request.** The evidence, in order of weight:

1. **His own design for block calls** ([Shopify/ruby#803](https://github.com/Shopify/ruby/issues/803#issuecomment-3411600332),
   2025-10-16): "The number of passed args must match the callee's parameter at this point. Fancy
   argument-parameter negotiations happen before this opcode. This is flexible enough to handle sends and yields
   and supers." `c65c6f4c49` broke exactly this: `InvokeBlockIseqDirect` carried `argc` next to `args`, and codegen
   used both. On the head the instruction gets exactly `lead_num` args and the negotiation (the drop) happens
   before it, in the planner's types.
2. **Block parameter setup may be its own part.** Same issue, [first comment](https://github.com/Shopify/ruby/issues/803#issuecomment-3411405899):
   "Blocks have different parameter setup features than methods, so `SendWithoutBlock` needs to take on an
   extended feature set for this, or we need to split `SendWithoutBlock` into parameter setup and frame push so
   the parameter setup part could be substituted as fit." On 2026-01-29 he called putting blocks into `SendDirect`
   itself possible but "messy", because it "is first and foremost designed for calling into methods"
   ([comment](https://github.com/Shopify/ruby/issues/803#issuecomment-3819660044)). A block-specific plan function
   that feeds the shared emission is the "substituted" setup. Teaching `can_direct_send` the block rules is closer
   to what he called messy.
3. **What he approved 18 minutes earlier.** [#19889](https://github.com/ruby/ruby/pull/19889#pullrequestreview-5908438373)
   (tekknolagi, approved by XrXr 2026-11-24 20:02 UTC; our review came at 20:20) removes `kw_bits` as a side field
   of `SendDirectCall` and `SendDirect` and makes it an ordinary planned argument: "Don't special-case it all over
   the place; treat it as any other argument." `argc` on `InvokeBlockIseqDirect` was the same kind of side field.
4. **The two frame states.** On [#18983](https://github.com/ruby/ruby/pull/18983#pullrequestreview-5296085617) he
   described "the pre-send state (`exit_state` here), the during-send state (`send_frame_state` here)". The head
   gives `InvokeBlockIseqDirect` both, built by the same `with_replaced_args` call as for `SendDirect`.
5. **It fits what is landing next.** [#20137](https://github.com/ruby/ruby/pull/20137) (k0kubun, opened two hours
   after the review) inlines blocks by mapping `InvokeBlockIseqDirect` onto the `SendDirect` inliner as
   `(…, kw_bits 0, jit_entry_idx 0, state, state, args.len())` and computes the caller's stack as
   `call_state.stack_size() - args_len`. With `argc` that subtraction would be wrong for surplus args; with the
   head's normalized `state` it is right as written, and `exit_state` slots in where it passes `state` twice.
6. **The same shape exists unpublished.** k0kubun's branch has auto-splat for `yield`
   ([`b9b4165329`](https://github.com/k0kubun/ruby/commit/b9b4165329), 2026-11-01) as `setup_block_args` plus a
   `stack_argc` field on the instruction, with `can_direct_invoke_block_iseq` as a separate gate. That is the shape
   XrXr rejected on our PR. Through the planner, auto-splat is `SendDirectArg` elements from the Array and nil
   padding is `SendDirectArg::Constant(Qnil)`, both in `plan_block_iseq_direct_args`, with no extra field.

What the head does not do: eligibility stays in `can_direct_invoke_block_iseq`, called from `add_iseq_to_hir`, and
`plan_block_iseq_direct_args` runs later inside the emit helper and relies on that gate (`args[..lead_num]` would
panic without it). For sends, `build_send_direct_args` validates and plans in one fallible call, and #18288's body
describes the planner as "eligibility and argument setup checks → SendDirectPlan". His sentence can also be read as
"change `build_send_direct_args` itself". I rate that reading at roughly one in four, because of points 1 and 2.

### If he asks for more

Not built. Two steps, smallest first:

* **One block function that validates and plans** (about +20/−15 on the head, no snapshot change). Fold the body
  of `can_direct_invoke_block_iseq` into the plan function, returning
  `Result<SendDirectCall, SendFallbackReason>`, and call it where the gate is called today (the two
  `can_direct_invoke_block_iseq` sites in the `invokeblock` arm of `add_iseq_to_hir`). `direct_iseqs` becomes
  `Vec<(IseqPtr, SendDirectCall)>`; `dispatch_invoke_block_iseqs`, `push_invoke_block_iseq_direct` and
  `push_invoke_block_iseq_direct_insn` take the plan instead of re-planning. This is the planner's own pattern
  (one validated plan per profiled shape, emitted in its branch) and removes the hidden precondition.
* **A block mode in the send planner** (about +45/−30). `can_direct_send` gets the argument-setup kind, like
  `arg_setup_type` in `vm_args.c`: for a block, `positional_ok` accepts more args than parameters (YJIT's rule in
  `exit_if_wrong_number_arguments`: `too_many = … && !(iseq_has_rest || args_setup_block)`), and a single arg into
  lead params that is not `|a|` is refused. `build_send_direct_args` truncates the positional args for a block after
  `plan_send_direct_rest_parameter`. `can_direct_invoke_block_iseq` keeps only `rb_simple_iseq_p` and
  `block_iseq_may_throw` and loses its `argc` parameter. The `invokeblock` arm builds `CallerArguments::new(&args, ci)`
  from the instruction's call data and maps a `SendDirectFailure` to `InvokeBlockNotSpecialized` without
  `failure.record` (its counters are send-specific). `plan_block_iseq_direct_args` goes away.

Recommendation: keep the head's design, with the body and comment fixes below. Don't pre-build either step.

### Other PRs that touch the same lines

Neither changes the judgment; whichever lands second needs a small rebase.

* #19889 removes `kw_bits` from `SendDirectCall`: our `kw_bits: 0` line in `plan_block_iseq_direct_args` then
  doesn't compile and is deleted.
* #20137 destructures `InvokeBlockIseqDirect { iseq, captured, ref args, state }`: with our `exit_state` field its
  tuple becomes `(…, state, exit_state, args.len())`.

`git merge-tree` of the head against master `3b188d0dd5` is clean.

## Correctness

No defect found. Read against `vm_callee_setup_block_arg` and `vm_invoke_iseq_block_with_cref`:

* `argc < lead_num` refuses (the VM pads with nil). `argc == 1 && lead_num > 0 && !ambiguous_param0` refuses (the
  VM calls `to_ary` on the argument and may splat it). With `lead_num == 0` the VM does neither, so one arg into
  `{ }` is direct. Two or more args are never splatted. These are the only two guards the change adds or alters;
  `rb_simple_iseq_p`, the call-flag check and `block_iseq_may_throw` are master's.
* Codegen is master's except that the stack overflow check exits with `exit_state`. With the planned snapshot,
  `stack_size = state.stack().len() - args.len()` is the slot below all yielded args, so the saved SP, the stack
  map and the block frame match the interpreter's `rsp = GET_SP() - calling->argc`.
* `exit_state` at the overflow check is needed, not only tidy: the exit re-runs `invokeblock`, whose call info still
  says the original argc, so the planned snapshot would hand it a stack that is too short.

Runs in the review orb (2 CPUs), head `2f73e7b80a`:

| Check | Result |
| --- | --- |
| `make zjit-test` | 2043/2044, 15 skipped. The one failure is `test_profile_frames_during_direct_jit_to_jit_entry` ("rb_profile_frames was not called from SIGPROF handler"); it passes 3/3 alone. The builder's run had 2044/2044. |
| Selected zjit-tests | `yield` 51/51, `getblockparamproxy` 20/20, `invokeblock` 16/16, `times` 2/2 |
| `make btest RUN_OPTS=--zjit-call-threshold=1` | 2148/2148 |
| `make btest RUN_OPTS=--zjit-call-threshold=2` | 2148/2148 |
| Builder's 51 probes | identical in the interpreter, threshold 1, threshold 2, and threshold 2 with `--zjit-inline-threshold=0`; identical to both recorded outputs |
| 37 new probes ([probes-fable.rb](../../bench/upstream/ruby19659/probes-fable.rb), [output](../../bench/upstream/ruby19659/probes-fable-out-2f73e7b80a.txt)) | identical in the same four modes; `block_iseq_direct_optimized_send_count` 23,110 / 23,285 / 10,728; the stack overflow exit is taken |

The new probes aim at the two snapshots: ISEQ guard misses that must re-run the `yield` with every arg, exits
inside the block with live values below the args, `raise`/`ensure`/`break`/non-local `return`, `binding` and
block-local variables in a frame laid over the dropped slots, GC and `GC.stress`, deep recursion and
`SystemStackError` through a surplus `yield`, ten args into 0, 1, 8 and 10 parameters, a Fiber switch, and one
yielder per call site so the call stays direct without inlining.

Mutations, each restored afterwards:

* Planned args with the `yield`'s original snapshot as `state`: `test_yield_surplus_args_block_side_exit_keeps_caller_stack`
  aborts with `[BUG] Stack consistency error (sp: 20, bp: 19)` and `test_getblockparamproxy_polymorphic_none_and_iseq`
  with `(sp: 24, bp: 23)`. The test pins the normalized snapshot.
* Overflow check exiting with `state` instead of `exit_state`: the full suite still passes (2044/2045 with a
  temporary overflow test, only the SIGPROF test failing; a second temporary test that checks the re-run `yield`'s
  first arg passes too). No test pins `exit_state`: in these runs the interpreter raised
  `SystemStackError` on the re-run `yield` before the block saw its args, so the short stack wasn't observed. The
  head is correct by construction, as `SendDirect` is.
* `with_block(1)` called once in the polymorphic getblockparamproxy test: "Program side-exited". The commit
  message's reason for calling it twice holds.
* The parent's `hir.rs` and `codegen.rs` under the head's tests: the four new HIR tests fail and show
  `InvokeBlock … # SendFallbackReason: InvokeBlock: not yet specialized`; every codegen test passes. This backs
  "Until now …" in the body.

Raw commit: one commit, parent `f70ba2530d` (an ancestor of master), Thomas as author and committer, author date
`1793661856 +0000` kept, no trailers, +286/−19 in four files under `zjit/src`.

## Maintainability

No structural regression. The diff to non-test code is +38/−13: one plan function, one emit helper used at all
three sites, two fields.

All ten added or changed comments were checked against the comment rule. My own reading let them stand as the
file's style: the two field comments copy `SendDirectData`'s and `PushInlineFrame`'s wording, the plan function's
states the precondition and the VM function it mirrors, and the three test comments each stop a plausible
"simplification". After finishing I read the thermos-sol pass on this head, which requires deleting the helper's
doc line (`hir.rs:3383`) and narrowing the plan function's (`hir.rs:4446-4447`) to its precondition. I agree on
3383: "Emit an `InvokeBlockIseqDirect` with the args planned by `plan_block_iseq_direct_args`" restates the
three-line body, DECISIONS makes such a comment a required change, and the same kind of line was deleted between
candidates -3 and -4 of this PR. On 4446-4447 one line with the precondition is enough, because the gate's doc
comment already names `vm_callee_setup_block_arg`; I would not have required it alone. Both are comment-only and
need a new head with a text-only confirm.

Optional:

1. `push_invoke_block_iseq_direct` and `push_invoke_block_iseq_direct_insn` differ by a suffix, and the plan
   function's precondition is only a comment. The first step under "If he asks for more" removes both.
2. `codegen.rs` still says the block "is gated to simple + lead-only + exact arity". The gate no longer requires
   exact arity; the planned args have it. Master's text, so leaving it keeps the diff smaller.

## Texts

### Body: one must-fix

"Two cases stay on `invokeblock`: … and too few arguments, which are padded with nil **(YJIT also leaves these
out)**." Read as "both cases", this is not true for `|a,|`. Earlier passes checked only the too-few half.
[yjit-block-args.rb](../../bench/upstream/ruby19659/yjit-block-args.rb) on Ruby 4.0.9 with
`--yjit --yjit-call-threshold=2 --yjit-stats=quiet`, 5,000 calls each
([output](../../bench/upstream/ruby19659/yjit-block-args-out-4.0.9.txt)):

| Call | YJIT |
| --- | --- |
| `yield [1, 2]` into `\|a, b\|` | falls back every call (`send_iseq_arity_error`, `num_send_dynamic`) |
| `yield [3]` into `\|a,\|` | direct, no fallback or exit counter moves |
| `yield [3, 4]` or `yield 3` into `\|a,\|` | side exit every call (`invokeblock_iseq_arg0_wrong_len`, `…_not_array`) |
| `yield` into `\|a\|` | falls back every call (`send_iseq_arity_error`) |
| `yield 1, 2` into `\|a\|` | direct |

The head's `yjit/src/codegen.rs` has the same order: the arity check (`exit_if_wrong_number_arguments`, line 7663)
runs before the arg0 splat (lines 7742 and 8162), so `|a, b|` never reaches it and `|a,|` does. Smallest fix, by
cutting: delete " (YJIT also leaves these out)". The sentence before already cites YJIT for the drop itself.

Every other body sentence holds on this head: the "Until now" claim by the parent-sources run above, "a side exit
before the call keeps all of them" by the guard-miss probes, the lambda sentence by
`test_yield_surplus_args_to_lambda_raises`. The timing sentences are marked as earlier measurements and were not
re-measured (the build here is a dev build). The live body equals the item's.

### Commit message: accurate, two optional wordings

* Last paragraph: "a snapshot whose stack holds only the block's args" also holds whatever was below the args
  (`[0, yield(x, 2)]`). "a snapshot with the block's args in place of the yield's" is exact. Its first clause, "The
  drop is a plan for the existing SendDirect argument emission", reads better as "The drop is planned as a
  SendDirectCall and emitted by emit_send_direct_args".
* The third paragraph explains the change to the polymorphic getblockparamproxy test; `test_getblockparamproxy`
  changed for the related reason given in its comment and isn't mentioned.

The commit is rebuilt for the comment fix anyway, so both wordings can go in with it.

### Reply draft: accurate

Checked clause by clause against the head: the plan function and its type, all three sites through
`emit_send_direct_args`, the planned snapshot, `exit_state`, and no `argc` field left (it exists on the PR branch
today, so the reply is true once the head is there). Optional, same precision as above:

> Moved it into the argument planner: `plan_block_iseq_direct_args` plans the block's lead args as a `SendDirectCall`,
> and `InvokeBlockIseqDirect` goes through `emit_send_direct_args` like `SendDirect`, so its snapshot has the block's
> args in place of the `yield`'s and the original stays as `exit_state`. The `argc` field is gone.

## Candidate -6 text-only confirm (2c54ad31f3)

Head [`2c54ad31f3`](https://github.com/thomasklemm/ruby/commit/2c54ad31f38328477b5e0be3eeecc5e554313134) on
`thomasklemm/zjit-yield-surplus-args-6`, fetched from the fork. **Verdict: approve.** Both must-fixes are resolved
and nothing new is required.

* **Commit.** One commit, parent `f70ba2530d`, Thomas as author and committer, author date `1793661856 +0000`
  kept, no trailers.
* **Tree diff.** `git diff 2f73e7b80a 2c54ad31f3` is `zjit/src/hir.rs` +1/−3, comments only. The doc line above
  `push_invoke_block_iseq_direct_insn` is deleted. The one above `plan_block_iseq_direct_args` now reads "Requires
  can_direct_invoke_block_iseq to have accepted this call."; it states a precondition the signature doesn't show
  (the slice would panic without the gate), in one line, so it stays. Executable code and tests are unchanged, so
  the runs on `2f73e7b80a` above apply. On the -6 sources: `yield` 51/51, `getblockparamproxy` 20/20.
* **Commit message**, sentence by sentence: accurate. "Simple non-lambda blocks" matches the gate
  (`rb_simple_iseq_p`), and the snapshot wording is the exact one. The one new claim is "test_getblockparamproxy
  now passes the same block ISEQ on every call, so the yield in Kernel#then doesn't miss its ISEQ guard". Run
  here: with master's test body (`test { 1 }` in the setup and again in the assertion) the test fails on -6 with
  "Program side-exited". The same shape as a script at `--zjit-call-threshold=2 --zjit-stats` shows 6 side exits,
  all `invoke_block_iseq_changed`; with one block ISEQ (`def with_block = test { 1 }`) it shows none.
* **Body.** The item's body differs from the live body only by the deleted " (YJIT also leaves these out)". The
  YJIT clause that remains ("and YJIT does the same", for the surplus drop) is backed by the surplus row of the
  YJIT table above.
* **Reply.** "Moved argument normalization into the planner": the plan function sits with the other
  `plan_send_direct_*` functions and returns their type. "builds a `SendDirectCall` for the block's lead args":
  `args[..lead_num]` as `SendDirectArg::Existing`. "uses `emit_send_direct_args` like `SendDirect`": all three
  construction sites go through the one helper that calls it. "Its snapshot has the block's args in place of the
  `yield`'s": `with_replaced_args`. "`exit_state` keeps the original yield snapshot for exits before the call":
  the stack overflow check, the instruction's only exit before the call, exits with it. "The `argc` field is
  gone": true on -6; the PR head `c65c6f4c49` still has it, so the reply is true only once -6 is pushed there.
