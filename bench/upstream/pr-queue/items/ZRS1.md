---
id: ZRS1
repo: ruby/ruby
fork: thomasklemm/ruby
kind: fix
area: ZJIT, super from a refined method
reviewer: "nirvdrum (original invokesuper specialization)"
branch: zjit-super-from-refinement
head: "be791c1fb825885912dec8a4f78e1481e9ad026b"
base: master
built_on: "7919a47d467ba961b8912fa61e0ee1fe0ff4ef0c"
depends_on: []
stacked_on:
alternative_of:
impact: "Fixes Shopify/ruby#1128: compiled super can call a refinement activated only by the caller; +15 implementation lines and one codegen test, no speed claim"
rank: 4
risky: false
state: reviewed
pr:
note: "2026-11-18: thermos-sol nits on be791c1fb8, no correctness or maintainability must-fix. Both rubrics applied by one reviewer in the same thread, as requested; no delegated reviewers. Kept built because the separate claude-code submission gate is not satisfied. No Ruby fork changes, push or external post. Submission still needs Thomas's approval. Builder's record: docs/upstream/zjit-differential.md, Rerun on master 7919a47d46 (2026-11-18)."
passes:
  - reviewer: thermos-sol
    orb: T-01a1eccf-a5a0-70bc-9626-78d1a8f81e0b
    head: "be791c1fb825885912dec8a4f78e1481e9ad026b"
    date: 2026-11-18
    verdict: nits
    open: >-
      No must-fixes. Correctness/security and maintainability rubrics loaded and applied directly by this
      reviewer, not two independent agents (explicit request). Verified the fork branch still points to
      be791c1fb825885912dec8a4f78e1481e9ad026b, one commit on 7919a47d467ba961b8912fa61e0ee1fe0ff4ef0c;
      Thomas is author and committer, no trailers. The diff is 42 insertions in three files: 15 implementation
      lines, 27 test lines. Shopify/ruby#1128 read through gh api: open, same repro.
      Diagnosis confirmed: profile_invokesuper records rb_vm_frame_method_entry; using builds refinement
      iclasses in rb_using_refinement, with complemented CMEs carrying the iclass as defined_class.
      type_specialize formerly used RCLASS_SUPER(RCLASS_ORIGIN(defined_class)), which can select the previous
      caller-activated refinement. The new refusal is before both the ISeq and C-function target lookup paths.
      vm_search_normal_superclass distinguishes class refinements (restart through the refinement module's
      own origin/super) from module refinements (walk past refinement iclasses and return the normal module
      iclass). Merely advancing one iclass, or skipping the chain then taking super again, is not equivalent.
      A correct specialized version would also have to preserve definition-site refinements and the existing
      CME/invalidation assumptions; dynamic fallback is the smallest conservative fix, not a new abstraction.
      The intended rule is not that super never calls another refinement: lexical using R1 inside R2 still
      calls R1, as the interpreter requires. Both class and module lexical cases pass on the fix.
      Generic InvokeSuper retains effects::Any and its FrameState/arguments; codegen spills the operand stack,
      prepares the live frame and calls rb_vm_invokesuper, which searches with the live CME and normal VM
      cache invalidation. No static super target is retained. Literal blocks, block-level super, complex
      argument passing, missing/polymorphic profiles and profiled incoming blocks already refuse specialization;
      InvokeSuperForward is separately generic. Inlining only consumes SendDirect; later type_specialize
      passes use each instruction's frame_state_iseq/profile, so there is no separate unguarded inliner path.
      Existing specialized paths still have GuardSuperMethodEntry for a different live CME. Side exits resume
      the ordinary opcode. Mutation, TracePoint and GC probes found no new invalidation or frame-state gap.
      Maintainability: the refusal belongs beside the existing super refusals, reuses push_insn_id and
      set_dynamic_send_reason, and adds the exhaustive Display/counter mappings. No new helper or layer needed;
      the already-large files cross no new 1,000-line boundary. The codegen test follows neighboring
      test_invokesuper_to_iseq conventions: Rust test, inspect/assert_snapshot, isolated VM, two calls, threshold
      2 set by boot_rubyvm. The warmup comments explain the otherwise duplicate calls. It demonstrably fails
      without the guard, so this is not an interpreter-only assertion. The enum comment explains its reason;
      the guard comment explains the non-obvious lookup boundary rather than narrating the branch.
      Commit message: ZJIT-prefixed imperative subject, explains the wrong target and conservative fallback;
      no unsupported speed or universal-refinement claim. Optional wording nits only: qualify its opening as
      a call through using, add Shopify/ruby#1128 and regression attribution to 4a21b83693, and replace the
      two-line guard comment with one short why-line. Optionally mirror RICLASS_FOR_REFINEMENT_P/YJIT's
      T_MODULE check before testing RMODULE_IS_REFINEMENT (that bit is also RUBY_FL_SINGLETON on classes);
      the ordinary/singleton-origin controls showed no behavioral regression, so this is not a proven defect.
      Independent builds: x86_64 Linux orb, Rust 1.100.0, bootstrap Ruby 4.0.7; autogen.sh, configure
      --enable-zjit=dev --disable-install-doc, make -j2. Exact head first, then restored only hir.rs and
      stats.rs to HEAD^ and rebuilt in the same build directory, retaining the new regression test as a
      negative control. The Ruby version banner of that control still says be791c1fb8; its runtime sources
      are master 7919a47d46. Restored the exact head afterwards; final scratch source worktree clean.
      Repro probe_refined_super.rb 100 on master: 71 wrong at default --zjit, 99 at threshold 2 and zmv,
      0 in the interpreter and threshold 1. Head: 100/100 correct in all five modes. Rebuilt the historical
      first-bad commit and its parent with --enable-zjit --disable-yjit --disable-install-doc and make -j2
      miniruby: at threshold 2, cdb2b0eed5 is correct 20/20; 4a21b83693 is wrong 19/20. Both interpreter
      controls are correct 20/20. git show confirms 4a21b83693 introduced the specialization in ruby/ruby#15816.
      make -s test-all TESTS='../ruby/test/ruby/test_refinement.rb ../ruby/test/ruby/test_super.rb'
      TESTOPTS='-q --tty=no --seed=41231', with RUN_OPTS empty, --zjit --zjit-call-threshold=1,
      --zjit --zjit-call-threshold=2, and --zjit --zjit-call-threshold=2 --zjit-num-profiles=1
      --zjit-max-versions=1 (zmv): head passes 245 tests / 4,133 assertions in every mode, no failures,
      errors or skips. Master passes interpreter/z1 and fails test_super_not_chained in z2/zmv (245 tests,
      4,132 assertions, one failure each). make -s zjit-test on head: 2,014 passed, 1 failed, 15 skipped;
      on master plus the retained new test: 2,013 passed, 2 failed, 15 skipped. The extra master failure is
      the new snapshot, actual R2 R1 A instead of R2 A. The shared failure is
      test_profile_frames_during_direct_jit_to_jit_entry, rb_profile_frames was not called from SIGPROF
      handler, SIGABRT. It passes when run alone on master, so record it as workload-sensitive, not an
      unconditional orb failure. After restoring head, make -s zjit-test ZJIT_TESTS=invokesuper passes 47/47.
      Adversarial probes: 107 generated scenarios plus 9 advanced scenarios; every scenario has 100 warm
      calls, the generated ones also use a second using scope and mix both callers. Six target layouts
      (class, inherited class, included module, nested included module, class with included original method,
      prepended class) by 16 call forms, plus refined C target, redefine/remove/undef original, prepend after
      warmup, redefine/remove refinement, GC.compact, TracePoint, mutation during argument evaluation and
      duck-typed to_a/to_hash/to_proc. Advanced cases cover lexical refinement chaining, import_methods,
      alias, exceptions/ensure, block break, method_missing and ordinary instance/singleton-origin controls.
      Forms include asymmetric explicit arguments, zsuper with modified locals, empty super, literal,
      implicit, explicit and nil blocks, rest/keywords, forwarding, nested blocks/lambdas, define_method,
      Method/UnboundMethod and Integer-to-Float side exits. Compared complete value/exception-result tallies
      byte for byte with the interpreter of the same build in default, z1, z2, z2 no-inlining, z2 HIR-opt-off,
      zmv and z2 inline-threshold=100/inline-budget=2000. Head: 0/116 divergent in every mode; master:
      43/116 divergent in default/z2/no-inlining/zmv/high-inlining, 13/116 in z1, 0 with HIR opts disabled.
      Thus threshold 1 is not a general workaround even though the original repro is correct there.
      Fallback counters are nonzero (z2 generated probe: 9,218 super_from_refinement; high-inlining advanced
      probe: 693, with 11 inline_method_count and 136 side exits). These are coverage observations, not speed
      claims or proof every refined body was inlined. Baseline/head interpreter output is identical.
      Probes and logs retained in this review orb under .amp/in/orb-backup/zrs1 (probe.rb, advanced.rb,
      head-*/base-*, advanced-*, tests-*, zjit-*, repro-*). script/pr-queue status exits 0: ZRS1 built,
      exact fork head, 42 lines, clean merge, 0 base-file commits moved, thermos-sol:nits, next review:
      claude-code on this head. Not run: full test-all, hosted CI, arm64.
---

# ZJIT: Don't specialize super from a refined method

Fixes Shopify/ruby#1128, introduced by 4a21b83693 ("ZJIT: Optimize common `invokesuper` cases", ruby/ruby#15816).

For a method reached through `using`, the profiled CME's `defined_class` can be a refinement iclass. Taking the superclass of its origin can select another refinement activated by the caller, even though that refinement is not active at the `super` call site. In the reported example, compiled `R2#foo` returns `"R2 R1 A"` instead of `"R2 A"`.

Fall back to the VM's super dispatch for these calls, as YJIT already does. ZJIT leaves them as generic `InvokeSuper`, with a `SuperFromRefinement` fallback reason. The VM helper preserves the distinction between refined classes and modules and honors refinements active at the `super` call site.

The new codegen test fails without the fix and passes with it. `test_refinement.rb` and `test_super.rb` pass all 245 tests in the interpreter and at ZJIT thresholds 1 and 2. The full `zjit-test` run has one SIGPROF profiling-test failure that also occurs on the unmodified base in this orb.
