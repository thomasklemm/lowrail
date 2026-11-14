# K1: `LazyIndexedAttributeSet#keys` after rails/rails#59141

Census 9's lead K1, proved and built 2026-11-14 in
[thread T-01a1d9f3](https://ampcode.com/threads/T-01a1d9f3-f8cb-70e7-a506-5330739dadb7). Queue item:
[K1](../pr-queue/items/K1.md). Branch `thomasklemm/lazy-indexed-keys` on thomasklemm/rails, head `bbdd9945d3`, built on
rails/rails main `50c54eed06`. Ruby 4.0.9, PostgreSQL 17.

## The change

```diff
     def keys
-      keys = row_keys | @ctx.type_keys | cached_names
-      keys.keep_if do |name|
+      row_keys.keep_if do |name|
 ...
       def materialize
         unless @materialized
           row_keys.each { |key| self[key] }
-          @ctx.type_keys.each { |key| self[key] }
           @materialized = true
 ...
-      def cached_names
-        names = []
-        indexes.each_key { |name| names << name if lookup(index_for_name(name)) }
-        names
-      end
```

plus the then-unused `type_keys` reader and ivar in `Builder::TypeTable` and `Builder::Context` (+2/−15 in
`attribute_set.rb` and `attribute_set/builder.rb`). Census 9's local 5e34cc61f8 was the same change without the
`builder.rb` cleanup.

## Proof that the union is always `row_keys`

* `row_keys` is `indexes.keys` since 62a5e6c670 ("reduce diff, rename attribute reader", inside #59141); before that
  it listed only the names the row had a value for, and the two unions were needed. Neither was released (8.1 has no
  `Builder::Context`).
* `cached_names` iterates `indexes`, so it is a subset of `row_keys` in the same order.
* Every set's `indexes` starts from the builder's `@indexes = indexes_for(types, default_attributes.indexes)`, which
  appends every key of `types` the defaults lack. Everything else that builds a set's indexes only appends names after
  them: `Result::RowLayout` (pending columns), `IndexedRow::Remapper` (with `column_map` = the builder's indexes),
  `ExtendedIndexes.add`, `Builder#row_from_hash`, `#relayout`, `#typed_indexes`. `with_types` only overrides names
  already in `@indexes`. So every `type_keys` name is in `indexes`, and the union equals `row_keys`.
* The one way to break it is a builder that changes between laying out a result and building a set from it (an
  `after_find` that declares an `attribute` mid-result). Then a type key has no index, reaches `keep_if` with `nil`
  and main raises (`TypeError` from `Array#[](nil)` or `NoMethodError` from `nil < size`) in `attribute_names`,
  `changed?`, `inspect` and serialization; the fix returns `keys == to_hash.keys`. No case returns a different list.
* `materialize`'s second pass called `self[key]` on names the first pass already built (idempotent) or on names with
  no index (`Attribute.null`, nothing stored).

Checks:

* [keys_probe.rb](keys_probe.rb): 54 cases (attribute without column, with default, virtual and ignored columns,
  partial selects, `SELECT … AS extra`, `find_by_sql`, `instantiate` with column types, legacy `build_from_database`,
  eager_load, `becomes`/`becomes!`, STI relayout and subclass query, dup/clone, freeze, `reset`, reload,
  save/update/create, Marshal 7.1 and 6.1 format (new and loaded), YAML, `init_with`, `deep_dup`, `write_attribute`
  and `write_from_user` of unknown and extra names, `ActiveModel::Attributes` without Active Record, an attribute
  declared after load). For each it dumps `keys`, `to_hash`, `each_value`, `key?`, `accessed`, `#attributes`,
  `attribute_names`, `attributes_before_type_cast`, `changed?`, `changes`, `changed_attributes`,
  `serializable_hash`, `as_json` and `inspect`. 53 cases are identical on main and the fix and all have
  `keys == to_hash.keys` and the initialized `each_value` names; the mid-result case is the only diff
  ([probe-main-vs-fix.diff](results/probe-main-vs-fix.diff)).
* Main instrumented to log any set whose type keys miss its indexes or whose union differs from `row_keys`
  ([invariant-check.patch](results/invariant-check.patch)): the full Active Model, Active Record SQLite and
  PostgreSQL suites logged nothing (about 98k sets and 16–17k `keys` calls per main test process). Positive control:
  the probe on that tree logs only the mid-result case ([invariant-check.txt](results/invariant-check.txt)).
* Narrowing `row_keys` back to the row's names fails two existing tests ("keys follow the attribute layout, then
  extra columns of the database row", "the primary_key is always initialized"), so no new test was added.

## Tests on the fix

* Active Model: 1,269 runs, 0 failures, 0 errors (same as main).
* Active Record SQLite: 10,375 runs, 0 failures; 4 errors in `sqlite_rake_test` from a missing `sqlite3` CLI, 15/15
  once installed.
* Active Record PostgreSQL 17: 11,298 runs, 40,954 assertions, 0 failures, 0 errors.
* RuboCop 1.90.0 (Rails' config): both files clean. GitHub Actions on the fork (devcontainer, rails-new-docker) green.
* With kamipo's #58380 cherry-picked under it: Active Model and the store/dirty/attribute/serialization AR files pass.

## Measurement

[attr_bench.rb](attr_bench.rb) under [run.sh](run.sh): one process per tree, width and mode, stock Valgrind 3.24
Callgrind with client requests ([irwin.c](irwin.c)) zeroing and dumping around each window of N=200 calls (100 warmup;
under YJIT until three warm windows compile nothing), `GC.start` then `GC.disable` around the window, census fixed
heap (`RUBY_GC_HEAP_*_INIT_SLOTS`), the `_empty` window subtracted. Trees: main and main2 (A/A, both `50c54eed06`),
fix, 8-1-stable `71e963ed1b`. Table of `id`, `type` and width−2 string/integer columns. Full tables:
[tables.md](results/tables.md); raw: [results/bench](results/bench).

Fix against main, interpreter Ir per call ([sweep-interp.md](results/sweep-interp.md)); A/A is the largest
|main2 − main| over cases above 2,000 Ir:

| interp | 5 cols (A/A ≤ 0.63%) | 30 cols (A/A ≤ 0.27%) | 100 cols (A/A ≤ 0.17%) | 300 cols (A/A ≤ 0.23%) |
|---|---:|---:|---:|---:|
| load1 | +0.1% | +0.0% | +0.1% | -0.0% |
| reader_warm | -0.1% | +0.0% | +0.0% | +0.0% |
| load1_attributes | +0.2% | +0.0% | +0.0% | -0.0% |
| attribute_names_warm | -54.3% | -55.0% | -54.8% | -54.8% |
| changed?_warm | -35.4% | -36.6% | -36.6% | -36.7% |
| load1_changed? | -4.0% | -10.0% | -12.7% | -13.8% |
| load1_assign_changes | -3.7% | -9.7% | -12.5% | -13.6% |
| load1_save | -8.8% | -18.9% | -22.6% | -24.0% |
| update1 | -5.1% | -18.2% | -29.5% | -36.0% |
| load1_update1 | -4.2% | -13.5% | -20.5% | -24.1% |
| load1_dup | -2.0% | -4.9% | -5.9% | -6.3% |
| serializable_hash_warm | -36.5% | -35.2% | -34.9% | -35.0% |
| load1_as_json | -3.9% | -9.5% | -11.8% | -12.8% |
| partial_changed? | -46.5% | -61.7% | -64.7% | -65.5% |
| partial_as_json | -35.4% | -57.8% | -63.2% | -65.1% |
| sti_load1_changed? | -4.4% | -9.9% | -12.7% | -13.7% |
| sti_load1_attributes | +0.2% | +0.0% | +0.1% | -0.0% |
| new | +0.4% | -0.1% | -0.7% | -0.1% |
| new_changed? | -11.9% | -23.8% | -27.7% | -29.0% |

Objects: 5 fewer per `keys` call at 30+ columns (3 at 5 columns), 15 fewer per save or `update!`.

No case gets worse: the only positive cells (+0.1% to +0.4%, all at 5 columns) are inside that width's A/A. Three
repeats of the 5-column controls ([results/repeats](results/repeats)) give medians of fix against main: load +0.02%,
`#attributes` +0.01%, STI `#attributes` −0.01%, `new` −0.53% (A/A −0.48%), reader −0.09%; and `changed?` −36.2%,
`update!` −5.2%, so the single-run cells reproduce.

YJIT ([sweep-yjit.md](results/sweep-yjit.md)): cells where main, main2 or the fix compiled in the measured window are
marked `rej` and not counted. JIT-flat cells: `changed?` −54%, `attribute_names` −66%, `serializable_hash` −28% to
−40%, `update!` −8% (5 cols) to −48% (300), `dup` −2.5% (5) and −6% (100, 300); load, readers, `#attributes`, STI
`#attributes` and `new` within the A/A (≤ 0.78% at 5 columns, 0.18% at 300). Ruby master × ZJIT: next section.

### Ruby master × ZJIT (opus review, 2026-11-14)

Measured in the second review ([thread T-01a1da1c](https://ampcode.com/threads/T-01a1da1c-7c8f-75af-9394-a6cb9d83d777))
on Ruby master `9aa0898240` (`--enable-yjit --enable-zjit`, `-O3`), the pin the other Rails candidates use; same
harness, census heap variables, N=200, width 30, trees main, main2 (A/A) and the fix. Under ZJIT the warmup waits for
three windows in a row with no new compiled ISEQ or side exit. Master has no invalidation count, so these are
observations, not gated claims: every measured window below compiled 0 ISEQs and 0 side exits and spent 0 ns
invalidating, on all three trees. Raw: [results/master](results/master) (one run, then `rep1`/`rep2` of the controls).

| Ir per call, 30 cols | ZJIT main | A/A | fix | interp main | A/A | fix | objects main → fix (interp) |
|---|---:|---:|---:|---:|---:|---:|---:|
| `changed?` | 142,486 | +0.15% | **−50.7%** | 262,983 | −0.44% | **−34.1%** | 6 → 1 |
| `serializable_hash` | 195,653 | +0.19% | **−36.9%** | 269,640 | −0.44% | **−33.4%** | 38 → 33 |
| `update!` of one column | 834,866 | +0.15% | **−26.1%** | 1,608,653 | −0.19% | **−16.7%** | 205 → 190 |
| `find` then `save` | 851,672 | +0.19% | **−27.2%** | 1,745,098 | −0.23% | **−17.8%** | 180 → 165 |
| `find` (3 runs, median) | 202,332 | −0.10% | −0.02% | 407,123 | −0.17% | +0.01% | 69 → 69 |
| `#attributes` (3 runs) | 292,453 | −0.27% | −0.15% | 628,359 | −0.03% | −0.01% | 84 → 84 |
| `new` (3 runs) | 18,942 | −0.58% | −0.48% | 55,772 | +0.06% | +0.43% | 9 → 9 |

The larger ZJIT percentages come from a smaller base: `changed?` saves 72k Ir per call under ZJIT against 90k in
the interpreter. No ZJIT loss. One master-interpreter cell is outside its A/A: `new`
at +0.43% (all three fix runs 56,010–56,126 against main 55,752–55,899), although `new` calls neither `#keys` nor
`materialize` ([reach](results/reach-main.txt)). Per-function self Ir of one `new` window puts the whole +274 Ir per
call in `rb_managed_id_table_lookup` (+288) and `st.c:find_table_entry_ind` (+48), offset by `rb_concurrent_set_find`
(−48); no `vm_exec_core` or `insns.def` line differs, so the Ruby code run is the same. That points at hash-table
probe lengths shifted by the IDs the fix no longer interns (`type_keys`, `@type_keys`, `cached_names`), not at the
change's code path (a hypothesis; not traced to the table). It does not show on 4.0.9 (`new` −0.1% at 30 columns) or
under ZJIT.

Against 8-1-stable ([vs-8-1.md](results/vs-8-1.md)), the fix recovers part of main's regression on these paths, not
all: at 30 columns `changed?` goes from main +28% to −19% against 8.1, `serializable_hash` from +7% to −31%, find +
save from +11% to −10%, but `update!` stays +24% (main +51%) and find + dup +6% (main +12%).

## Reach

[reach.rb](reach.rb) on main ([reach-main.txt](results/reach-main.txt)): `#keys` runs once per `changed?`,
`changes`, `attribute_names`, `inspect`, `serializable_hash` and `as_json`, three times per save or `update!` and once
per create and destroy (all via `AttributeMutationTracker#attr_names` or `AttributeMethods#attribute_names`);
`materialize` once per save, update, create, `dup` and destroy (twice). Load, readers, assignment, `#attributes`,
`new`, partial and STI loads, and reload call neither. Census 9's allocation census found `#keys`, `row_keys` and
`cached_names` on main in all 8 apps (24–25 workloads).

## Overlap (2026-11-14)

* No open rails/rails PR or issue mentions `LazyIndexedAttributeSet`, `type_keys` or `cached_names` (GitHub search),
  and among the file lists of 1,000 of the 1,288 open PRs (`gh pr list --limit 1000`) only the four below touch
  `attribute_set.rb`, `builder.rb`, `indexed_row.rb` or `attribute_mutation_tracker.rb` (plus Kazakbai's #55533 in the
  mutation tracker, unrelated).
* Those PRs: kamipo's #58380 (StoreAttribute; edits `attribute_set.rb` and `builder.rb` but not
  `keys`, `materialize` or `type_keys`), tenderlove's #59249 (remove 6.1 marshal), ikraamg's #58002 (the old
  `LazyAttributeSet#keys` in `builder.rb`, already conflicting with main), tenderlove's draft #53344. `git merge-tree`
  of each with the fix conflicts in exactly the files it already conflicts in with main.
* #59141's thread: tenderlove's announced follow-ups are removing `IndexedRow` for ORM queries, a width-based backing
  strategy, decoupling `becomes`, and the 6.1 marshal removal; none covers `keys`. czj's `#to_hash` went in through
  that thread before the merge.

## Rerun

```
RAILS trees under ~/k1 (git worktree add --detach), bundles in ~/k1/suite-TREE (copies of .lowrail/rails-suite
pointed at the tree, plus argon2); irwin.so built from irwin.c into ~/k1/ext.
N=200 WARM=100 bench/upstream/k1/run.sh OUT TREE WIDTH interp|yjit [CASE...]
ruby bench/upstream/k1/table.rb OUT; ruby bench/upstream/k1/sweep.rb OUT interp
BUNDLE_GEMFILE=~/k1/suite-TREE/Gemfile ruby bench/upstream/k1/keys_probe.rb > TREE.txt
BUNDLE_GEMFILE=~/k1/suite-TREE/Gemfile ruby bench/upstream/k1/edge_probe.rb > edge-TREE.txt
Master: Ruby 9aa0898240 in ~/w/ruby-master, bundles in ~/k1/suiteM-TREE (activesupport, activemodel, activerecord,
sqlite3; BUNDLE_PATH=~/k1/gemsM), irwin.so built for it in ~/k1/extM:
PATH=~/w/ruby-master/bin:$PATH RUBY_BIN=~/w/ruby-master/bin SUITE=suiteM BUNDLE_PATH=~/k1/gemsM IRWIN_DIR=~/k1/extM \
  N=200 WARM=100 bench/upstream/k1/run.sh OUT TREE 30 zjit|interp [CASE...]
```
