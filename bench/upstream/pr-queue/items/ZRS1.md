---
id: ZRS1
repo: ruby/ruby
fork: thomasklemm/ruby
kind: fix
area: ZJIT, super from a refined method
reviewer: "nirvdrum (original invokesuper specialization)"
branch: zjit-super-from-refinement-4
head: "a5ac62d1a22e8ffa9a2cc8e5ac4720ea5b191482"
base: master
built_on: "7db0202722a286011518bd291f51a15fb652dc02"
depends_on: []
stacked_on:
alternative_of:
impact: "Fixes Shopify/ruby#1128: compiled super can call a refinement activated only by the caller; +20 implementation lines (with a zjit.c helper and its binding), an HIR and a codegen test in a baseline commit plus the fix, no speed claim"
rank: 4
risky: false
state: ready
pr: 19976
note: "2026-11-18 ~21:00 UTC, fix round after thermos-sol (nits, a8c1ba4e) and thermos-opus (changes, 71cdaa34) on 7a1eed11f4; both found the source correct. Now two commits on master 7db0202722, as in tekknolagi's own ZJIT PRs (#19770, #19594, #19585): 61f275c7e5 'ZJIT: Add a test for super from a refined method' adds only the opt_tests.rs test with master's snapshot (R1#foo inlined via PushInlineFrame, inner InvokeSuper 'polymorphic call site'); a5ac62d1a2 is the fix with 7a1eed11f4's tree and message byte for byte, so its opt_tests.rs diff is exactly the before/after. Thomas author and committer, no trailers. Pushed only as fork branch zjit-super-from-refinement-4; PR branch -2 still 1d86986033, -3 left at 7a1eed11f4, nothing posted. Commit 1 alone: make zjit-test ZJIT_TESTS=test_invokesuper_from_refined 1/1 pass. Head: make zjit-test ZJIT_TESTS=invokesuper 48/48 (both new tests included); btest 2,148/2,148 at thresholds 1 and 2; test_refinement.rb + test_super.rb 245 tests, 4,139 assertions, no failures in interp, z1, z2 and zmv. Full zjit-test not rerun: the head tree equals 7a1eed11f4's. Body: suite-count/SIGPROF paragraph cut (DECISIONS Leave out); 'The VM helper preserves' is now 'The VM's super lookup preserves'. Replies rewritten on the Opus wording and checked against the head (three inline checks in yjit gen_invokesuper_specialized; RICLASS_FOR_REFINEMENT_P is static inline bool in internal/class.h, used by vm_search_normal_superclass; no wrap_static_fns in zjit/bindgen, so bindgen does not bind it). SIGPROF correction: both reviewers ran test_profile_frames_during_direct_jit_to_jit_entry alone 6/6 passing on master and head and saw it fail only in the full zjit-test run, on master and head alike; the earlier 'fails 5 of 6 alone on master' was this builder orb only, under concurrent load, and is not a property of the test. Needs confirm passes from both reviewers on a5ac62d1a2. Earlier: 2026-11-18 ~20:30 UTC: tekknolagi's two review comments (19:33 UTC) addressed as 7a1eed11f4, one commit on master 7db0202722, pushed only to the new fork branch zjit-super-from-refinement-3 (branch field now points there); the PR branch zjit-super-from-refinement-2 still has 1d86986033, nothing posted, PR body unchanged on GitHub. (1) HIR test test_invokesuper_from_refined_method_remains_invokesuper in hir/opt_tests.rs, right after test_invokesuper_to_iseq_optimizes (the ordinary super that specializes to an inlined frame); without the guard the new snapshot shows R2#foo inlining R1#foo (PushInlineFrame), with it a generic InvokeSuper with the refined-method fallback reason. (2) The check is now rb_zjit_iclass_for_refinement_p in zjit.c, wrapping RICLASS_FOR_REFINEMENT_P the way rb_zjit_singleton_class_p wraps RCLASS_SINGLETON_P; bindings regenerated with make zjit-bindgen (one added line). YJIT's inline copy in gen_invokesuper_specialized left alone (one concern per PR). Commit message gains one sentence on the helper. On this head: zjit-test 2,015 of 2,016 pass (test_profile_frames_during_direct_jit_to_jit_entry SIGABRT; on master 7db0202722 the same test run alone fails 5 of 6 completed runs, so it is not this change); both new tests fail without the guard; btest 2,148/2,148 at thresholds 1 and 2; test_refinement.rb + test_super.rb 245 tests, 4,139 assertions, no failures in interp, z1, z2 and zmv; repro R2 A 100/100 in interp, default, z1, z2 and zmv. Body: one sentence on the helper, the tests sentence names both tests, 'in this orb' dropped; needs a PATCH when the head is pushed to the PR. No review pass on this head yet; state stays ready (PR state), passes above are on older heads. Reply drafts under For Thomas. Earlier: 2026-11-18 15:08 UTC: Thomas marked the PR ready for review. 2026-11-18: thermos-sol confirm approves 1d86986033 with no must-fixes; state reviewed. The coordinator requested a short confirm because only hir.rs and the commit message changed after the detailed be791c1fb8 pass. Both rubrics applied directly in one thread, no delegated reviewers. T_MODULE matches the VM/YJIT predicate; old/new guard controls agree. The codegen regression and both Ruby test files at thresholds 1 and 2 pass. For Thomas now distinguishes caller-only from definition-site refinements and includes a runnable example with master/head outputs checked. No Ruby fork push or external post. Earlier builder note, 2026-11-18: Review nits applied as 1d86986033 on branch zjit-super-from-refinement-2, one commit on 7919a47d46; the old branch stays at be791c1fb8. The commit message is qualified to calls through `using` and names Shopify/ruby#1128 and 4a21b83693 (ruby/ruby#15816); the guard comment is one line; T_MODULE is checked before the refinement flag, as RICLASS_FOR_REFINEMENT_P and YJIT do. Rerun on this head: the codegen test fails without the guard (R2 R1 A) and passes with it; probe_refined_super.rb 100/100 correct in interp, default, z1, z2 and zmv (no guard: 71 wrong at default, 99 at z2 and zmv); test_refinement.rb and test_super.rb 245 tests, 4,133 assertions, no failures in interp, z1, z2 and zmv (no guard: test_super_not_chained fails at z2); zjit-test 2,014 passed, 1 failed (SIGPROF, test_profile_frames_during_direct_jit_to_jit_entry), 15 skipped; ZJIT_TESTS=invokesuper 47/47. Prepended-singleton, prepended-class and included-module controls give the interpreter's results and the same ZJIT counters with the old and the new guard. No C declarations touched, so no bindgen. Thomas approved submission once the nits are in; this head has no review pass yet, so the state is built. No PR opened, nothing posted. Earlier, 2026-11-18: thermos-sol nits on be791c1fb8, no correctness or maintainability must-fix. Both rubrics applied by one reviewer in the same thread, as requested; no delegated reviewers. Kept built because the separate claude-code submission gate is not satisfied. No Ruby fork changes, push or external post. Submission still needs Thomas's approval. Builder's record: docs/upstream/zjit-differential.md, Rerun on master 7919a47d46 (2026-11-18)."
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
  - reviewer: thermos-sol
    orb: T-01a1ed67-f8cf-72ac-bc39-22b3ba969028
    head: "1d86986033707d121a0a3a514bf15bd6afdfe203"
    date: 2026-11-18
    verdict: approve
    open: >-
      No must-fixes. Short confirm after the detailed be791c1fb8 pass; both Thermos rubrics loaded and
      applied by this reviewer directly, not independent agents, as requested. Exact fork head verified
      with git ls-remote; one commit on 7919a47d467ba961b8912fa61e0ee1fe0ff4ef0c. Only hir.rs and the
      commit message differ from the reviewed head; the full patch remains 42 insertions in three files.
      The T_MODULE check is between T_ICLASS and RMODULE_IS_REFINEMENT, exactly as in
      RICLASS_FOR_REFINEMENT_P (internal/class.h) and YJIT's gen_invokesuper_specialized. class_of wraps
      rb_class_of, so it reads the same klass as their RBASIC access, without Ruby calls. The extra check
      excludes the shared RUBY_FL_SINGLETON bit on classes, not genuine refinements. Placement remains
      before superclass computation and both ISeq/C-function target lookups. The original InvokeSuper,
      arguments and FrameState are retained for VM dispatch. No new abstraction or structural regression;
      the one-line guard comment explains the otherwise non-obvious wrong-target hazard. The enum and
      warmup comments remain necessary and match neighboring codegen tests.
      Commit message checked sentence by sentence against rb_using_refinement, complemented CMEs,
      profile_invokesuper, vm_search_normal_superclass and the YJIT refusal. The using-qualified opening,
      caller-specific chain, wrong R1 target and generic fallback are accurate. The VM skips the caller's
      refinement chain differently for refined classes and modules; it does not forbid lexical refinement
      chaining. git show confirms 4a21b83693 introduced the faulty lookup and names the quoted subject and
      ruby/ruby#15816; the previous pass already rebuilt it and its parent. gh api read Shopify/ruby#1128:
      open, same repro. ZJIT-prefixed imperative subject, technical terminology, wrapped body and closing
      Fixes issue URL match recent ruby/ruby ZJIT history, including 8b9dc082e7. Thomas author/committer,
      no trailers. No remaining comment or message nit.
      Independent x86_64 Linux build: bootstrap Ruby 4.0.7, Rust 1.100.0, autogen.sh, configure
      --enable-zjit=dev --disable-install-doc, make -j2. make -s zjit-test
      ZJIT_TESTS=test_invokesuper_from_refined_method_skips_other_refinements: 1/1 passes on head;
      on actual master 7919a47d46 with only that new test retained, it fails with R2 R1 A instead of R2 A.
      make -s test-all TESTS='test/ruby/test_refinement.rb test/ruby/test_super.rb'
      TESTOPTS='-q --tty=no --seed=41231', RUN_OPTS='--zjit --zjit-call-threshold=1' and threshold 2:
      each passes 245 tests, 4,133 assertions, 0 failures, errors or skips on exact head.
      Extracted and ran the For Thomas example on actual master and head, with 100 calls in interp,
      default ZJIT, z1, z2 and zmv. Master: interpreter/z1 give R2 A 100/100; default gives R2 A 29 and
      R2 R1 A 71; z2/zmv give R2 A 1 and R2 R1 A 99. Head: R2 A 100/100 in every mode. Head z2 records
      99 send_fallback_super_from_refinement hits. For Thomas now explains caller-only versus
      definition-site activation and scopes the refusal to a profiled refinement iclass, with the
      runnable example and checked outputs. Separate lexical-using control correctly returns R2 R1 A
      100/100. Prepended-singleton, prepended-class and included-module controls use asymmetric arguments
      and return the interpreter's exact nested values (105, 45 and 50 respectively), 100/100 each;
      old be791c1fb8 and new head outputs are byte-identical in interp, default, z1, z2 and zmv.
      Restored exact head and rebuilt: make -s zjit-test ZJIT_TESTS=invokesuper passes 47/47; the scratch
      Ruby tracked worktree is clean. Local PrQueue.problems and PrQueue.missing both return empty lists
      for ZRS1, state reviewed; the parser still excludes For Thomas from the public body.
      Logs and probes retained in this orb under .amp/in/orb-backup/zrs1-confirm. The full zjit-test result
      and known SIGPROF failure remain the builder's recorded run, not a new full-suite certification.
      Not rerun: full zjit-test, full test-all, hosted CI, arm64. No Ruby changes published or external post.
  - reviewer: thermos-sol
    orb: T-01a1f051-e70d-74df-8d5a-51990dfd4dbf
    head: "7a1eed11f443881206906acf4efc95ee7f8b7715"
    date: 2026-11-18
    verdict: nits
    open: >-
      No source must-fixes. Both Thermos rubrics loaded and applied directly by this reviewer, with no
      subagents, other reviewers or threads, as explicitly requested. Exact fork head verified, one commit
      on master 7db0202722a286011518bd291f51a15fb652dc02; 89 added lines in seven files, including 20
      implementation/binding lines. The canonical predicate, helper naming and position beside
      rb_zjit_singleton_class_p match ZJIT's existing shape. make zjit-bindgen reproduces the checked-in
      bindings byte for byte. Leaving YJIT unchanged is correct: its equivalent refusal already exists.
      Both new tests pass on head and fail after removing only the seven-line guard. The HIR failure shows
      PushInlineFrame instead of the refined-method InvokeSuper; the codegen failure returns R2 R1 A.
      Head full zjit-test: 2,015 passed, one failed, 15 skipped. Unmodified exact base full zjit-test:
      2,013 passed, the same one failed, 15 skipped. Both fail the profiling-test zero-samples assertion
      with SIGABRT. All six isolated base runs pass here: pre-existing and workload-sensitive, not a
      deterministic standalone failure. Four Ruby suite modes each pass 245 tests / 4,139 assertions.
      The 41-scenario differential matches the interpreter in default, z1, z2 and zmv on head; base has
      6/5/6/6 divergent scenarios. Full sentence-by-sentence text audit and commands are in
      docs/upstream/zjit-differential.md, ZRS1 follow-up review of 7a1eed11f4. Wording nits: the second reply
      calls RICLASS_FOR_REFINEMENT_P a macro, but it is a static inline function; say predicate. The first
      reply is accurate. Prefer VM lookup over VM helper in the body, and drop its suite-count paragraph
      under DECISIONS. The German explanation should say ZJIT no longer duplicates the predicate, not
      that only one definition exists globally while YJIT retains its copy. Drafts left unchanged for
      Thomas; no Ruby push or external post. Final exact-head invokesuper rerun and limitations in record.
  - reviewer: thermos-opus
    orb: T-01a1f051-f32b-7206-936f-08a375829cc1
    head: "7a1eed11f443881206906acf4efc95ee7f8b7715"
    date: 2026-11-18
    verdict: changes
    open: >-
      Source is correct; two must-fixes in how the PR answers the review. Both Thermos rubrics applied
      directly in this thread, no subagents or other threads, no contact with the Sol reviewer.
      (1) The PR does not show the before/after HIR tekknolagi asked for: the one commit adds only the
      after snapshot. His own ZJIT PRs put the current HIR in a first baseline-test commit and let the
      fix commit change it (ruby/ruby#19770 47557025d5 then f4e44fad2d, #19594 3b150a90ff, #19585
      9982455489). Smallest fix: split into two commits on 7db0202722. The first adds only
      test_invokesuper_from_refined_method_remains_invokesuper with master's snapshot (PatchPoint on
      Unknown@, PushInlineFrame of R1#foo, inner InvokeSuper). The second is today's tree, so its
      opt_tests.rs diff is exactly the before/after. Checked: the baseline passes on master and the
      head tree passes. Then reword the first reply and body sentence 4 to point at it.
      (2) The body keeps the suite-count and SIGPROF sentences, which DECISIONS lists under Leave out. Cut
      them when the body is patched. Nits: reply 2 and For Thomas call RICLASS_FOR_REFINEMENT_P a macro, but it
      is a static inline function that bindgen cannot bind, which is the real answer to "better API?".
      "The VM helper" right after "a small helper in zjit.c" has an unclear referent. The German "nur
      noch eine Definition" is false while YJIT keeps its copy. Optional: "refined method" means
      VM_METHOD_TYPE_REFINED elsewhere in ZJIT (cruby_methods.rs, super-target stats "refined"); Ruby's
      docs say "refinement method". Guard exact: outside RICLASS_FOR_REFINEMENT_P,
      vm_search_normal_superclass is ZJIT's RCLASS_SUPER(RCLASS_ORIGIN(klass)). A 14-scenario asymmetric
      probe matches the interpreter in default, z1, z2 and zmv on head. On master 7 diverge in every
      ZJIT mode, including z1. Covered: refined class, refined module, prepend/include under the refined
      class, send, Method, mixed callers. Lexical chaining, bind_call and controls are unchanged. Both new
      tests fail without the guard; make zjit-bindgen gives no diff. Helper name, location next to
      rb_zjit_singleton_class_p and the bindgen line are right; YJIT left alone is right (one concern
      per PR). The profiling SIGABRT also occurs in master's full run; alone it passes 6/6 on both, not
      the builder's 5 of 6 failures. Details: docs/upstream/zjit-differential.md, ZRS1 Opus review of
      7a1eed11f4. No Ruby push or external post.
  - reviewer: thermos-opus
    orb: T-01a1f051-f32b-7206-936f-08a375829cc1
    head: "a5ac62d1a22e8ffa9a2cc8e5ac4720ea5b191482"
    date: 2026-11-18
    verdict: approve
    open: >-
      Short confirm of the fix round for this reviewer's 7a1eed11f4 findings; both rubrics applied directly
      in this thread, no subagents or other threads. Both must-fixes resolved. git ls-remote: -4 at
      a5ac62d1a2, -2 still 1d86986033. Two commits on 7db0202722: 61f275c7e5 (only opt_tests.rs, +50) and
      a5ac62d1a2. Thomas author/committer on both, no trailers. Head tree 3052f43db8 equals 7a1eed11f4's,
      so the earlier source review, probe and suite runs carry over. Commit 1 built alone: make zjit-test
      ZJIT_TESTS=invokesuper 47/47, the new baseline test passes with master's snapshot. Head rebuilt:
      invokesuper 48/48, and the 14-scenario probe is byte-identical to the interpreter in default, z1, z2
      and zmv. git diff 61f275c7e5 a5ac62d1a2 -- opt_tests.rs is exactly what tekknolagi asked to see:
      nine lines out (the PatchPoint on Unknown@, the CME/specval guards, PushInlineFrame, the inner
      polymorphic InvokeSuper, PopInlineFrame), one in (InvokeSuper with 'call from a refined method').
      GitHub's combined Files view still shows only the after, so reply 1 rightly points at the commits.
      The body no longer has the suite-count/SIGPROF paragraph and says "The VM's super lookup".
      Read sentence by sentence against the code: accurate. Reply 1 is accurate. Reply 2 is accurate:
      YJIT checks T_ICLASS, T_MODULE and the flag; internal/class.h has the static inline function;
      vm_search_normal_superclass uses it. The German note is corrected (Funktion, not Makro; ZJIT no
      longer duplicates the check). Nits, not blocking: (a) the note says a5ac62d1a2 keeps 7a1eed11f4's
      message byte for byte, but its raw message has one extra trailing newline (git cat-file).
      git log and GitHub show the same text. (b) In commit 1 the test is named ..._remains_invokesuper
      while its snapshot shows inlining, so the name only becomes true in commit 2. tekknolagi's baseline
      tests have neutral names. Renaming it test_invokesuper_from_refined_method in both commits is
      optional. Not rerun: full zjit-test, test-all, btest, hosted CI, arm64. No Ruby push or post.
---

# ZJIT: Don't specialize super from a refined method

Fixes Shopify/ruby#1128, introduced by 4a21b83693 ("ZJIT: Optimize common `invokesuper` cases", ruby/ruby#15816).

For a method reached through `using`, the profiled CME's `defined_class` can be a refinement iclass. Taking the superclass of its origin can select another refinement activated by the caller, even though that refinement is not active at the `super` call site. In the reported example, compiled `R2#foo` returns `"R2 R1 A"` instead of `"R2 A"`.

Fall back to the VM's super dispatch for these calls, as YJIT already does. ZJIT leaves them as generic `InvokeSuper`, with a `SuperFromRefinement` fallback reason. The check is the interpreter's own `RICLASS_FOR_REFINEMENT_P`, exposed through a small helper in `zjit.c`. The VM's super lookup preserves the distinction between refined classes and modules and honors refinements active at the `super` call site.

## For Thomas

The caller's `using R1; using R2` selects `R2#foo`, but it must not also make `R1#foo` part of that method's `super` call. Refinements active where `super` is written still count. Since ZJIT's `invokesuper` optimization (4a21b83693), the specialization takes its target from the profiled method entry's caller-specific refinement chain. Once compiled, `R2#foo` below therefore returns `"R2 R1 A"` instead of `"R2 A"`:

```ruby
class A; def foo = "A"; end
module R1; refine(A) { def foo = "R1 " + super }; end
module R2; refine(A) { def foo = "R2 " + super }; end
module Client
  using R1
  using R2
  def self.test(a) = a.foo
end

a = A.new
p Array.new(100) { Client.test(a) }.tally
```

On master `7919a47d46` (before the fix), the interpreter prints `{"R2 A" => 100}`. Default `--zjit` prints `{"R2 A" => 29, "R2 R1 A" => 71}`; with `--zjit --zjit-call-threshold=2`, it prints `{"R2 A" => 1, "R2 R1 A" => 99}`. Threshold 1 happens to give the right answer for this example, not for every affected case. With the fix, all 100 calls return `"R2 A"` in every mode we ran.

The fix leaves `super` calls whose profiled method entry belongs to a refinement iclass on the VM's normal dispatch path, as YJIT already does. It gives up specialization for these calls rather than adding a second refinement-aware lookup implementation. The new HIR and codegen tests fail without the fix, and Ruby's refinement and `super` tests pass in every ZJIT mode we ran.

### Reply drafts to tekknolagi (2026-11-18 review, not posted)

On `zjit/src/codegen_tests.rs` (HIR test):

> Added `test_invokesuper_from_refined_method_remains_invokesuper` in `hir/opt_tests.rs` as a separate first commit with the current HIR, so the fix commit shows the change: before, `R2#foo` inlines `R1#foo` (`PushInlineFrame`); after, it stays `InvokeSuper` with `SuperFromRefinement`.

On `zjit/src/hir.rs` (existing check, better API):

> YJIT has the same three checks inline in `gen_invokesuper_specialized`. The interpreter's version is `RICLASS_FOR_REFINEMENT_P` in `internal/class.h`, which `vm_search_normal_superclass` uses, but it is `static inline`, so bindgen can't reach it. ZJIT now calls it through `rb_zjit_iclass_for_refinement_p` in `zjit.c`, like `rb_zjit_singleton_class_p`. I left YJIT's copy alone to keep this PR to ZJIT.

### Für Thomas (Review von tekknolagi)

tekknolagi wollte zwei Dinge: das HIR vorher und nachher sehen, und eine bessere API für die dreiteilige Bedingung. Beides ist auf dem Fork-Branch `zjit-super-from-refinement-4` (`a5ac62d1a2`, auf master `7db0202722`). Der PR-Branch ist unverändert, nichts gepostet.

Zum HIR-Test: Der PR hat jetzt zwei Commits, so wie tekknolagi es in seinen eigenen ZJIT-PRs macht. Der erste fügt nur den HIR-Test hinzu, mit dem HIR von heute: ZJIT setzt `R1#foo` inline in `R2#foo` ein (`PushInlineFrame`), das ist der Fehler. Der zweite ist der Fix; sein Diff im Test zeigt genau vorher und nachher: statt des Inlinings bleibt ein generisches `InvokeSuper` mit dem Grund „call from a refined method“.

Zur API: Der Interpreter prüft genau das mit `RICLASS_FOR_REFINEMENT_P` aus `internal/class.h`. Das ist kein Makro, sondern eine `static inline`-Funktion, und die kann bindgen nicht direkt nach Rust holen. Deshalb ruft ZJIT solche Funktionen über kleine Wrapper in `zjit.c` auf, z. B. `rb_zjit_singleton_class_p` für `RCLASS_SINGLETON_P`. Genau so gibt es jetzt `rb_zjit_iclass_for_refinement_p`. Damit ist die Bedingung in `hir.rs` ein Aufruf, und ZJIT nutzt dieselbe Prüfung wie der Interpreter, statt sie nachzubauen. YJIT hat seine eigene Kopie inline; die bleibt, damit dieser PR bei ZJIT bleibt.

Vor dem Push auf den PR-Branch braucht es dein OK (nach den Bestätigungs-Reviews); danach den Body aktualisieren und die zwei Antworten oben posten.
