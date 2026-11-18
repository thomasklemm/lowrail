---
id: OTS1
repo: ruby/ruby
kind: perf
area: ZJIT, objtostring guards
reviewer: "none asked; precedent k0kubun's #19603 (coerce_to guards recompile)"
branch: thomasklemm/zjit-objtostring-recompile
head: "2cc3e0de4d"
base: master
built_on: "9de06831e3"
depends_on: []
stacked_on:
alternative_of:
impact: "removes a permanent side exit: a String-profiled interpolation that also sees a Symbol exits on every such call; lobsters guard_type_failure 677 -> 139 per iteration (content_tag_string), side exits 10,167 -> 9,629, railsbench unchanged; run_benchmarks.rb within A/A (A/A spread up to 10% on the orb)"
rank: 3
risky: false
state: built
pr:
note: "2026-11-18 (Thomas): open as a ruby/ruby draft once the thermos-sol review on the head approves. Built 2026-11-18 from the ZJIT stats pass (docs/upstream/zjit-stats-2026-11-18.md). Production +4/-4 in zjit/src/hir.rs, one new HIR test, seven snapshots gain `recompile`. zjit-test 2,014/2,015 (the profiler-signal test test_profile_frames_during_direct_jit_to_jit_entry, also failing before the change, passes alone), btest t1/t2 all 2,148. Not opened: needs Thomas's explain-first step and review passes. Opens under the permanent-exit exception (DECISIONS, Playbook), not for a time win."
passes: []
---

# ZJIT: Recompile when an objtostring guard fails

When `objtostring` has a monomorphic profile, ZJIT guards the profiled type: a String goes straight into the concatenation, an Integer or a Module becomes its frozen string, and any other class sends `#to_s`. These guards didn't recompile, so a value of another type side-exited on every call for as long as that version stayed. They now recompile, like `coerce_to`'s since #19603.

On lobsters, Action View's `TagBuilder#content_tag_string` interpolates a tag name that is a String in most calls and a Symbol in about one in six:

```diff
-exit_guard_type_failure:      677
+exit_guard_type_failure:      139
-side_exit_count:           10,167
+side_exit_count:            9,629
```

(ZJIT stats per iteration, ruby-bench `8083f57`, 15 warmup + 10 measured iterations, two runs per build agree; railsbench doesn't move.)
