# Combined effect, round 4 (2026-11-27)

Scripts and inputs for round 4 of [combined-effect](../../../docs/upstream/combined-effect.md#round-4-every-merged-pr-on-rails-main-2026-11-27).
Round 3's method, on new pins; results and receipts are recorded there.

## Trees

Rails, clone of rails/rails at main `088fc0cf61`:

```sh
git clone https://github.com/rails/rails.git rails-canon && cd rails-canon
git switch -c r4-without 088fc0cf61e4ba0c7987decafacc69adb3e22eec
```

then `git revert --no-edit -m 1 MERGE` for each merge in [`reverted.tsv`](reverted.tsv) marked `clean`, newest
first in main's first-parent order (#59316 is a single commit: no `-m`). The `resolved` rows were resolved by hand
as their row says (test and CHANGELOG conflicts keep main's file), in first-parent order with the clean ones; the
`Merger` resolutions are round 3's, and the resulting `merger.rb` is byte-identical to round 3's reverted file
(blob `262fa72045`). The result is local commit `20c835cf15` (78 reverts). A blobless clone works for the trees but
makes `attribute.rb`'s `git blame` fetch blobs one by one; refetch without the filter first.

Ruby, clone of ruby/ruby at master `e8167b0ddd`: `git revert --no-edit` of every commit by Thomas Klemm since
2026-10-01 (`git log --author='Thomas Klemm' --since=2026-10-01 --topo-order`, 17 commits, newest first). Two
conflicts: #19680's revert in the `use crate::payload` line of `zjit/src/codegen.rs` (master's later
`PendingJITFrame` import stays, `get_iseq_payload_ptr` goes), and #19484's in the test file
`zjit/src/hir/opt_tests.rs` (master's version kept). Result `4e222eb280`. Both built with
`./configure --enable-yjit --enable-zjit --disable-install-doc` (Rust 1.100.0).

## Runs

* [`run_4010.sh`](run_4010.sh): Ruby 4.0.10. Census ABBA (`r4w`, `r4wo`, `r4wo2`, `r4w2`), ruby-bench objects per
  iteration, ruby-bench instructions per iteration. Round 3's `run_409.sh` with the pin, the labels and an explicit
  `--ruby 4.0.10` (the census default is still 4.0.9).
* [`run_master.sh`](run_master.sh): Ruby master, the Rails axis (`r4zw`, `r4zwo`, `r4zwo2`, `r4zw2`) and the Ruby
  axis (`r4zw2`, `r4rwo`, `r4rwo2`, `r4zw3`), then the same ruby-bench measurements under ZJIT.
* Tables: [`../combined_r3/census_table.rb`](../combined_r3/census_table.rb),
  [`../combined_r3/zjit_alloc_table.rb`](../combined_r3/zjit_alloc_table.rb),
  [`../merged_sum/alloc_table.rb`](../merged_sum/alloc_table.rb) (`DIR main-a main-b without-a without-b`).
* Attribution: `LABELS=r4w,r4w2,r4wo,r4wo2 SPLIT=1 ruby ../merged_sum/attribute.rb CENSUS_OUT MAIN_TREE
  REVERTED_TREE PRS_TSV`, PRS_TSV being the reverted rows of `reverted.tsv` with full merge SHAs.
* ruby-bench `8083f57` with [`../combined_r3/ruby-bench.patch`](../combined_r3/ruby-bench.patch), its Rails paths
  rewritten to this round's worktrees, and shipit-engine 0.45.0 vendored with
  [`../index_with_ruby_bench/shipit-engine-review_stack.patch`](../index_with_ruby_bench/shipit-engine-review_stack.patch).
  Each variant lock is ruby-bench's lock re-resolved for the Rails path only; the `-b` locks are copies of the `-a`
  locks.
* Census copies: `script/census setup --ruby 4.0.10 --rails RAILS_CANON@088fc0cf61…` with the default overlays;
  Fizzy and Lobsters with the census-4 overlay plus [`fixtures/corpus/ce2/fizzy.patch`](../../../fixtures/corpus/ce2/fizzy.patch)
  and [`lobsters.patch`](../../../fixtures/corpus/ce2/lobsters.patch) appended, as in round 3.
