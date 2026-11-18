# Combined effect, round 3 (2026-11-17)

Scripts and inputs for round 3 of [combined-effect](../../../docs/upstream/combined-effect.md#round-3-every-merged-pr-on-rails-main-2026-11-17).
Results and receipts are recorded there.

## Trees

Rails, blobless clone of rails/rails at main `4500a94c34`:

```sh
git clone --filter=blob:none https://github.com/rails/rails.git rails-canon && cd rails-canon
git switch -c r3-without 4500a94c34d7052b84f81f6d7fd44f5bb8af3fff
```

then `git revert --no-edit -m 1 MERGE` for each merge in [`reverted.tsv`](reverted.tsv) marked `clean`, newest
first in main's first-parent order (#59316 is a single commit: no `-m`). The `resolved` rows were resolved by hand
as their row says (test and CHANGELOG conflicts keep main's file), in this order after the clean pass: #59642,
#59576, #59533, #59556, #59551, #59554, #59543. The result is local commit `bb283c942f` (56 reverts).

Ruby, blobless clone of ruby/ruby at master `7919a47d46`: `git revert --no-edit` of every commit by Thomas Klemm
since 2026-10-01 (`git log --author='Thomas Klemm' --since=2026-10-01 --topo-order`, 14 commits, newest first). Only
#19484's revert conflicts, in the test file `zjit/src/hir/opt_tests.rs`, which keeps master's version. Result
`854f34bbac`. Both built with `./configure --enable-yjit --enable-zjit --disable-install-doc` (Rust 1.100.0).

## Runs

* [`run_409.sh`](run_409.sh): Ruby 4.0.9. Census ABBA (`r3w`, `r3wo`, `r3wo2`, `r3w2`), ruby-bench objects per
  iteration, ruby-bench instructions per iteration.
* [`run_master.sh`](run_master.sh): Ruby master, the Rails axis (`r3zw`, `r3zwo`, `r3zwo2`, `r3zw2`) and the Ruby
  axis (`r3zw2`, `r3rwo`, `r3rwo2`, `r3zw3`), then the same ruby-bench measurements under ZJIT.
* [`census_table.rb`](census_table.rb): the census tables.
* ruby-bench `8083f57` with [`ruby-bench.patch`](ruby-bench.patch): a `Gemfile.VARIANT` per tree (Rails by path;
  `main-b` and `without-b` are copies of the `-a` files), the Rails 8.2 config lines from
  [index_with_ruby_bench](../index_with_ruby_bench/README.md), its shipit-engine `ReviewStack` patch, and round 2's
  [typedstore initializer](../../../fixtures/corpus/ruby-master-round-2/census_typedstore_rails_main.rb) for lobsters.
  Each variant lock is ruby-bench's lock re-resolved for the Rails path only.
* Census copies: `script/census setup --rails RAILS_CANON@4500a94c34…` with the default overlays; Fizzy and Lobsters
  with the census-4 overlay plus [`fixtures/corpus/ce2/fizzy.patch`](../../../fixtures/corpus/ce2/fizzy.patch) and
  [`lobsters.patch`](../../../fixtures/corpus/ce2/lobsters.patch) appended (`--overlays` pointing at a copy of
  `rails-main-census-4` with those two files combined).
