# ZSV1 -2: fix round for the 2026-11-18 Thermos review

Head [`47b2ed7110`](https://github.com/thomasklemm/ruby/commit/47b2ed7110f84ca76cc7aa6e767a1119e62c09a3) on
`thomasklemm/zjit-setivar-real-class-2`: one commit on Ruby master `4414d3ea25` (2026-11-18 15:35 UTC), 2 files,
+100/−1 (`zjit/src/profile.rs` +18/−1). Author and committer Thomas Klemm, made with `/usr/bin/git`, no trailers
(`git log --format='%(trailers:only)' origin/master..HEAD` is empty). The old branch stays at `fe6ea9ef84`.

## What changed against fe6ea9ef84

1. **Comments.** The three test comment lines and the `ProfiledType::real_class` doc comment are gone. The
   three-line rationale above `profile_self_real_class` is one why-line:
   `/// Shape transitions use the real class (obj_get_owner_class()), so singletons can be recorded.`
   Code and tests are otherwise byte-identical to `fe6ea9ef84`'s diff against its base.
2. **Numbers.** The micro figures (475/475/392 Ir, 999,869 generic writes) are cut from the body and the
   comment draft; no time or instruction claim remains. The application evidence is replaced by a fresh
   ZJIT stats diff on this head (below), with raw data and an A/A.
3. **Wording.** Commit message and body say "an ordinary object with a singleton class" and that the shape
   guard stays subject to the existing layout, frozen and capacity checks. Test-history, A/A and methodology
   narration are cut from the body.
4. **Packaging.** The test-only scaffolding commit is squashed: one fix commit carrying the final tests,
   applied with `git apply --index` of the exact `7919a47d46..fe6ea9ef84` diff onto `4414d3ea25` (clean).

## Tests on 47b2ed7110

Linux x86-64, GCC 14.2.0, Rust 1.100.0, bootstrap Ruby 4.0.9, cargo-nextest 0.9.152;
`configure --enable-zjit=dev --disable-install-doc --without-jemalloc`, out of tree.

* `make zjit-test ZJIT_TESTS=-j1`: 2016 tests run: 2016 passed, 15 skipped (both new snapshots pass; the SIGPROF
  test that failed on the old base passed here, once, not retried).
* `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and `=2`: PASS all 2148 tests each
  ("Fiber count: 10000 (skipping)").
* `make test-all TESTOPTS=-j2 TESTS='ruby/test_zjit_cli ruby/test_optimization ruby/test_shapes ruby/test_object
  ruby/test_variable'` at thresholds 1 and 2: 323 tests, 15405 assertions, 0 failures, 0 errors, 0 skips each.

The differential probe and the guard trace of the review are not rerun: the production code is identical to the
reviewed head and none of the files it reads changed between the old base and `4414d3ea25` (review record).

## ZJIT stats diff (stats/)

Three release builds (`--enable-zjit`, same configure): master `4414d3ea25`, a second independent build of the
same commit (`master-aa`; binaries differ only in build-time bytes, same version line), and the branch. ruby-bench
`8083f57`, harness [`zne1/stats_harness.rb`](../zne1/stats_harness.rb) (100 warmup iterations, stats reset,
10 measured), `RUBY_GC_HEAP_INIT_BYTES=33554432`, one copy of ruby-bench per run, sequential
([run.sh](stats/run.sh)). Diff by [`zne1/stats_diff.rb`](../zne1/stats_diff.rb) `master branch master master-aa
--pct 1`: a counter prints only when it moves by 1%, 100 per iteration and 10 times the A/A change. Raw JSON:
`stats/stats-{master,master-aa,branch}-{lobsters,railsbench,shipit}.json.gz`; diffs `stats/stats-*.diff`, A/A
diffs `stats/stats-aa-*.diff`. Counts per iteration.

* **lobsters** ([diff](stats/stats-lobsters.diff)): `setivar_fallback_no_side_exits` 5,956 → 5,372,
  `dynamic_setivar_count` 11,405 → 10,821, `ccall_rb_vm_setinstancevariable` 11,345 → 10,761 (−584 each). Master and
  master-aa have identical setivar counters; the A/A moves only allocation counters (+143, +141). This reproduces
  the original −584.
* **railsbench**: setivar counters identical on all three (30 / 4,060 / not-T_OBJECT 4,030). One counter passes the
  filter: `ccall_rb_hash_new` 2,641 → 2,499 (−143; A/A +3). It is an allocation call, of the kind that moves up to
  303 between the two master builds here; not traced, not in the body.
* **shipit**: nothing passes the filter. `setivar_fallback_no_side_exits` 41,029 → 40,948 (−81) with
  `setivar_fallback_not_t_object` 7,891 → 7,972 (+81); `dynamic_setivar_count` unchanged at 48,920. Master and
  master-aa identical.

No time claim: these are counters, not a ruby-bench timing; current Ruby has no ZJIT `invalidation_count`, so the
JIT-flat gate cannot certify a timing either. The team asked for this change (#1122), which DECISIONS exempts
from the run_benchmarks.rb requirement.
