# ZSV1 -3: rebase onto master 3b188d0dd5 for the draft PR

Head [`ca3ea90482`](https://github.com/thomasklemm/ruby/commit/ca3ea90482994c9cf369d4ce0efa9c4194f3b5c5) on
`thomasklemm/zjit-setivar-real-class-3`: `47b2ed7110` cherry-picked onto Ruby master
[`3b188d0dd5`](https://github.com/ruby/ruby/commit/3b188d0dd5b23bbf94831a890ca907b92420c22d) (2026-11-25 09:40 UTC),
435 commits after the old base `4414d3ea25`. Clean, no conflict. Author and author date kept (Thomas Klemm,
2026-11-18 16:34:20 UTC), committer Thomas Klemm via `/usr/bin/git`, no trailers
(`git log --format='%(trailers:only)' origin/master..HEAD` is empty). The `-2` branch stays at `47b2ed7110`.

```text
$ git range-diff 4414d3ea25..47b2ed7110 3b188d0dd5..ca3ea90482
1:  47b2ed7110 = 1:  ca3ea90482 ZJIT: Profile the real class for setinstancevariable
```

## Not fixed or replaced upstream (2026-11-25)

* Master `3b188d0dd5` still profiles `setinstancevariable` with `profile_self` (`zjit/src/profile.rs:89`); no
  commit since `4414d3ea25` touches `profile.rs`, and none mentions setivar/setinstancevariable or #1122.
* Shopify/ruby#1122 is open with no comments. Shopify/ruby#1126 (efegokdemir, the same idea) was closed on
  2026-11-13 by tekknolagi asking for ruby/ruby PRs; nothing followed on ruby/ruby.
* Of the open ruby/ruby ZJIT PRs, only #18326 (sendforward) touches `profile.rs`, and not setinstancevariable.
* Files the review's guard trace reads: `profile.rs` and `shape.c` unchanged; the `hir.rs` and `codegen.rs`
  changes (#19976, #19982, #20113, #19902, #19859, #19680 and others) touch no ivar or shape code; `object.c`
  changes only class allocation (#19907), not `rb_obj_class()`; `gc.rs` gains one SAFETY comment.
* The hold condition in the item ("open once tekknolagi approves or merges #19976 or #19659") is met: #19976
  merged on 2026-11-25 02:24 UTC (and #19982 at 03:00), both merged by k0kubun.

## Tests on ca3ea90482

Linux x86-64 (2 cores), GCC 14.2.0, Rust 1.100.0, bootstrap Ruby 4.0.9, cargo-nextest 0.9.152;
`configure --enable-zjit=dev --disable-install-doc --without-jemalloc`, out of tree.

* `make zjit-test ZJIT_TESTS=-j1`: 2036 tests run: 2036 passed, 15 skipped
  (`test_profile_frames_during_direct_jit_to_jit_entry` passed, once, not retried).
* `make zjit-test "ZJIT_TESTS=-j1 -E 'test(test_setivar_singleton_receiver)'"`: both
  `test_setivar_singleton_receiver_monomorphic_shape` and `..._shape_transition` pass (2 run, 2049 skipped).
* `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and `=2`: PASS all 2148 tests each
  ("Fiber count: 10000 (skipping)").
* Probe ([probe.rb](probe.rb)): 33 rows, identical with `./ruby` (interpreter), `--zjit --zjit-call-threshold=1`
  and `=2`, and both with `--zjit-max-versions=1`; all five exit 0. The interpreter rows also match Ruby 4.0.9.

  The review's `probe.rb` (SHA-256 `fde3f5de…`) stayed in the archived review orb and could not be downloaded,
  so this one is rebuilt from the review's row list (assignment values, existing/new/removed ivars, extended
  before first profile, ordinary/subclass/mixed, raising singleton `class`, late extend and prepend,
  0/1/3/10/70/150 extra ivars, 180 class-shape branches, minor GC, compaction, anonymous-class GC, frozen
  cold/late/new-ivar, freezing and growing during the RHS, String subclass, non-T_OBJECT, immediates, fiber,
  thread, non-owner Ractor class write) and is now kept here. It reaches the change: with
  `--zjit --zjit-call-threshold=1 --zjit-stats` on the release builds below, `dynamic_setivar_count` is 10,900
  on master and 9,879 on the branch.

The selected test-all suites of `results-2.md` were not rerun.

## ZJIT stats diff (stats-3/)

Same method as [results-2.md](results-2.md): three release builds (`--enable-zjit --disable-install-doc
--without-jemalloc`), master `3b188d0dd5`, a second independent build of it (`master-aa`, separate build
directory, same version line) and the branch; ruby-bench `8083f57` with harness
[`zne1/stats_harness.rb`](../zne1/stats_harness.rb) (100 warmup iterations, stats reset, 10 measured),
`RUBY_GC_HEAP_INIT_BYTES=33554432`, one copy of ruby-bench per run, sequential ([stats/run.sh](stats/run.sh)).
Diff by [`zne1/stats_diff.rb`](../zne1/stats_diff.rb) `master branch master master-aa --pct 1`. Raw JSON:
`stats-3/stats-{master,master-aa,branch}-{lobsters,railsbench,shipit}.json.gz`; diffs `stats-3/stats-*.diff`,
A/A diffs `stats-3/stats-aa-*.diff` (A/A diffs without the A/A filter, `--pct 1`). Counts per iteration.

* **lobsters** ([diff](stats-3/stats-lobsters.diff)): `setivar_fallback_no_side_exits` 5,956 → 5,372,
  `dynamic_setivar_count` 11,405 → 10,821, `ccall_rb_vm_setinstancevariable` 11,345 → 10,761 (−584 each), the
  same absolutes as on `4414d3ea25`. Master and master-aa have identical setivar counters; the A/A moves
  only `ccall_rb_ec_str_resurrect` (−127). The body's −584 holds unchanged.
* **railsbench**: setivar counters identical on all three (30 / 4,060 / not-T_OBJECT 4,030); nothing passes the
  filter. The A/A moves only allocation calls (`ccall_rb_hash_new` +232, `ccall_rb_ec_ary_new_from_values` +204).
* **shipit**: `dynamic_setivar_count` unchanged at 48,920; `setivar_fallback_no_side_exits` 41,029 → 40,948 (−81)
  with `setivar_fallback_not_t_object` 7,891 → 7,972 (+81), as on the old base; master and master-aa identical.
  One counter passes the filter: `ccall_rb_ec_ary_new_from_values` 8,233 → 7,900 (−333; A/A −2), an allocation
  call of the kind the railsbench A/A moves by 204; not traced, not in the body. The A/A also moves
  `ccall_rb_class_allocate_instance` +747.

No time claim, as before: these are counters, not a ruby-bench timing.
