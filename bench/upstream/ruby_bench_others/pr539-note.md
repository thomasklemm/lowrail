Draft note for ruby/ruby-bench#539 (luke-gruber, approved by eightbitraptor). Thomas OK (2026-11-05): the coordinator reviews and posts it without showing it again, once #569/#570 are ready; recheck the fix on the then-current main first.
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
