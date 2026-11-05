Draft note for ruby/ruby-bench#562 (XrXr, draft). Not posted; needs Thomas's OK (DECISIONS: no comments on
others' PRs without approval). Diagnosis and verification: [README](README.md#562-zjit_diff-gc-time-removed).

---

Heads-up in case it's useful: The second commit breaks CI: harness/gc.rb:86 calls `RubyVM::ZJIT.stats(:side_exit_count)` on every iteration. It returns nil while ZJIT is off (the NoMethodError), Rubies built without ZJIT (the Windows jobs here) and TruffleRuby have no `RubyVM::ZJIT`, and on 4.0 it is nil even with `--zjit` unless `--zjit-stats` is on. The delta also subtracts the previous delta instead of the previous total: on 4.0.9 with `--zjit-stats`, gcbench records 95, 1, 96, 2, 98 instead of 95, 1, 1, 1, 2. The change below also reads the counter before the first iteration, leaving out boot (0, 1, 1, 1, 2). With it, gcbench runs on 4.0.9 and master with and without ZJIT, and CI passes on my fork (current main plus #566): https://github.com/thomasklemm/ruby-bench/actions/runs/42079217004

```diff
   has_global_gc = GCStats.stat_available?(:global_gc_invocation_count)
+  last_side_exit_count = RubyVM::ZJIT.stats(:side_exit_count) if defined?(RubyVM::ZJIT.enabled?) && RubyVM::ZJIT.enabled?
@@
-    last_side_exit_count = side_exit_counts.last || 0
-    side_exit_counts << RubyVM::ZJIT.stats(:side_exit_count) - last_side_exit_count
+    if last_side_exit_count
+      side_exit_count = RubyVM::ZJIT.stats(:side_exit_count)
+      side_exit_counts << side_exit_count - last_side_exit_count
+      last_side_exit_count = side_exit_count
+    end
@@
-  extra["side_exit_count_warmup"] = side_exit_counts[warmup_range]
-  extra["side_exit_count_bench"] = side_exit_counts[bench_range]
+  unless side_exit_counts.empty?
+    extra["side_exit_count_warmup"] = side_exit_counts[warmup_range]
+    extra["side_exit_count_bench"] = side_exit_counts[bench_range]
+  end
```
