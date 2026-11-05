Posted on ruby/ruby-bench#539 on 2026-11-05: https://github.com/ruby/ruby-bench/pull/539#issuecomment-6668466562 (last paragraph shortened to one sentence before posting).
Diagnosis and verification: [README](README.md#539-gc_balloon).

---

Heads-up in case it's useful: gc_balloon fails on Ruby 4.0 and TruffleRuby with `GC.start: unknown keyword: :global`; only Ruby master accepts that keyword. Also, main renamed the harnesses after this branch was created (a1c61f6, bcee592), so on main `default_harness: harness-gc` and `../harness/loader` now raise LoadError. The change below checks for the keyword the way `harness/ractor.rb` does. With it, gc_balloon runs with the gc and ractor harnesses on 4.0.9 and master, and on master with YJIT and ZJIT. Fork CI: https://github.com/thomasklemm/ruby-bench/actions/runs/42081299470

```diff
--- a/benchmarks.yml
-  default_harness: harness-gc
+  default_harness: gc
--- a/benchmarks/gc_balloon.rb
-require_relative '../harness/loader'
+require_relative '../lib/harness/loader'
@@
-  LOCAL_MAJOR_ONLY = true
+  LOCAL_MAJOR_ONLY = GC.method(:start).parameters.include?([:key, :global])
```

With #569 and #570, the gc harness on Ruby master also reports gc_balloon's marking time per collection: about 9.2–9.3 ms per minor GC and 1.6 ms per major GC. The majors are the four `GC.start(global: false)` calls per iteration, which run at the low-water mark and so mark little (two runs of 10 iterations; the per-collection lists record exactly four majors in every iteration). On 4.0.9 there are no per-collection columns, and the printed average marking time is 148.3 ms, where main prints a truncated 148.0 ms.
