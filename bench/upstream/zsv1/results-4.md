# ZSV1 rebase onto master 274cfe719a (2026-11-27)

`script/pr-queue status` reported BASE-MOVED 3 for ZSV1: three master commits since `3b188d0dd5` touch
`zjit/src/hir/opt_tests.rs` (`bef83e4008` inline block bodies on invokeblock, `4535fe0d9f` frozen objects and
object layout, `15190918f0` opt_getconstantpath segments). They were not merge conflicts: `git merge-tree` against
master was clean and GitHub reported the PR mergeable. The PR was rebased anyway so that its head is tested on
current master, because `4535fe0d9f` changes the setivar guards next to the new HIR tests.

## Rebase

`ca3ea90482` rebased onto master `274cfe719a` (128 commits later) with `/usr/bin/git rebase`, committer Thomas
Klemm; result `d0f0dc2da5`, author and author date kept, no trailers. `git range-diff` is `=`. No snapshot
needed regenerating: both new HIR tests pass unchanged on the new base.

## Tests on d0f0dc2da5

Linux x86-64 (2 cores), Rust 1.100.0, bootstrap Ruby 4.0.9, cargo-nextest 0.9.152;
`configure --enable-zjit=dev --disable-install-doc --without-jemalloc`, out of tree.

* `make zjit-test ZJIT_TESTS=-j1`: 2048 tests run: 2048 passed, 15 skipped ([log](stats-4/zjit-test.log)).
* `make zjit-test "ZJIT_TESTS=-j1 -E 'test(test_setivar_singleton_receiver)'"`: both tests pass.
* `make btest RUN_OPTS='--zjit --zjit-call-threshold=1'` and `=2`: PASS all 2148 tests each.
* [probe.rb](probe.rb): 33 rows identical with the interpreter, `--zjit --zjit-call-threshold=1` and `=2`, and both
  with `--zjit-max-versions=1`; the interpreter rows also match Ruby 4.0.9.

## ZJIT stats on lobsters (stats-4/)

Method of [results-3.md](results-3.md), lobsters only (the body's one benchmark): three release builds, master
`274cfe719a`, an independent second build of it (`master-aa`) and the branch `d0f0dc2da5`; ruby-bench `8083f57`,
[`zne1/stats_harness.rb`](../zne1/stats_harness.rb) (100 warmup iterations, 10 measured),
`RUBY_GC_HEAP_INIT_BYTES=33554432` ([stats/run.sh](stats/run.sh)). Diff by
[`zne1/stats_diff.rb`](../zne1/stats_diff.rb) `master branch master master-aa --pct 1`.

* [Branch diff](stats-4/stats-lobsters.diff): `dynamic_setivar_count` 11,462 → 10,878,
  `setivar_fallback_no_side_exits` 6,013 → 5,429, `ccall_rb_vm_setinstancevariable` 11,402 → 10,818 (−584 each),
  nothing else passes the filter. The absolutes are 57 higher than on `3b188d0dd5`; the difference is unchanged.
* [A/A diff](stats-4/stats-aa-lobsters.diff) is empty at `--pct 1`; the three setivar counters are identical.

railsbench and shipit were not rerun; their results in results-3.md are on `3b188d0dd5`. No time claim.
