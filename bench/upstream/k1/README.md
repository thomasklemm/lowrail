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
* One way to break it is a builder that changes between laying out a result and building a set from it (an
  `after_find` that declares an `attribute` mid-result). Then a type key has no index, reaches `keep_if` with `nil`
  and main raises (`TypeError` from `Array#[](nil)` or `NoMethodError` from `nil < size`) in `attribute_names`,
  `changed?`, `inspect` and serialization; the fix returns `keys == to_hash.keys`. The other is `instantiate` with an
  `IndexedRow` not laid out for the class (`ActiveModel::IndexedRow[...]` or `Result#indexed_rows`, both nodoc): main
  raises `NoMethodError` from `keys` and the fix returns the row's names, but that record is already broken on main
  (`#attributes` reads the wrong slots, `dup` raises `KeyError`). No working case returns a different list.
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

## Rebuild on main 8e097e9d81 (2026-11-18)

Bruno Costanzo's #59833 (opened 2026-11-17, after #59800; merged by byroot 2026-11-18 as af6081aeeb) removed
`| cached_names` and `cached_names` itself, which is K1's `cached_names` part. It is the only base commit since
`50c54eed06` that touches `attribute_set.rb` or `builder.rb`. It leaves `row_keys | @ctx.type_keys` in `#keys`,
materialize's `type_keys` walk and the `type_keys` readers, so K1 is still needed, only smaller.

Rebuilt as `af84ab1445` on fork branch `thomasklemm/lazy-indexed-keys-2` (PR branch not updated): the conflict in
`#keys` resolves to K1's `row_keys.keep_if`, and the `cached_names` hunk is already on main. The resulting
`attribute_set.rb` is blob `a737087860`, the same blob as at `bbdd9945d3`, and `builder.rb` is the same change, so
the tree is the same code as before on a newer base (+2/−8 against main instead of +2/−15). The message drops "and built
names" from the subject and the `cached_names` clause, and says the union built one more Array instead of two.
Author date 2026-11-14 kept, author and committer Thomas, no trailers. The commit adds no guard and no comment.

The proof above still holds without `cached_names`: every `type_keys` name is in `indexes`, so the union is `row_keys`.
Probes on main `8e097e9d81` against the rebuild (Ruby 4.0.9): `keys_probe.rb`'s diff is byte for byte
[probe-main-vs-fix.diff](results/probe-main-vs-fix.diff) (only the after_find mid-result case, main raising);
`edge_probe.rb` identical over 164 lines; `review_probe.rb` differs only in the eager_load mid-result, foreign
`IndexedRow` and `Result#indexed_rows` cases, as before.

Tests with `-w`, SQLite, Ruby 4.0.9: Active Model 1,271 runs, 0 failures, 0 errors; Active Record `rake test:sqlite3`
10,402 runs, 0 failures, 5 errors from the environment (4 in `sqlite_rake_test` without the `sqlite3` CLI, 1 because
`pg` was not in the bundle); 23 attribute, dirty, serialization, store, dup, inheritance and persistence files 1,399
runs, 0 failures, 0 errors; no warnings.

The numbers moved, because main no longer pays for `cached_names`. 30 columns, N=200, same harness; raw:
[rebuild-8e097e9d81](results/rebuild-8e097e9d81). These ran on stock Valgrind 3.24 with the old run.sh, which deleted
the Valgrind logs, so whether they hit a brk overflow is unverified; a stock run of main with the fixed run.sh
overflowed (below). They are superseded by the pinned-tool cohort below and are not evidence for the body.

| Ir per call, 30 cols | 4.0.9 main | A/A | fix | objects | master ZJIT main | A/A | fix | master interp main | A/A | fix |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `changed?` | 191,913 | −0.13% | **−13.0%** | 3 → 1 | 89,278 | +0.21% | **−21.8%** | 190,341 | −0.09% | **−10.3%** |
| `serializable_hash` | 203,291 | −0.18% | **−12.1%** | 35 → 33 | 143,825 | +0.12% | **−13.7%** | 200,110 | −0.03% | **−9.7%** |
| `update!` of one column | 1,376,572 | +0.02% | **−5.4%** | 189 → 183 | 670,368 | +0.13% | **−8.8%** | 1,401,171 | +0.00% | **−4.3%** |
| `find` then `save` | 1,530,210 | −0.05% | **−8.4%** | 169 → 163 | 709,382 | +0.47% | **−12.2%** | 1,548,971 | −0.01% | **−7.5%** |
| `find` then `dup` | 1,118,916 | −0.02% | **−5.0%** | 182 → 182 | 520,549 | +0.20% | **−5.4%** | 1,122,245 | +0.03% | **−4.9%** |
| `find` | 401,812 | +0.01% | −0.02% | 68 → 68 | 202,046 | +0.11% | +0.03% | 407,326 | +0.03% | +0.03% |
| `#attributes` | 621,563 | −0.00% | −0.04% | 83 → 83 | 290,601 | +0.13% | +0.07% | 628,323 | +0.04% | +0.12% |
| `new` | 55,183 | +0.04% | −0.16% | 9 → 9 | 19,739 | +0.44% | −0.08% | 56,475 | −0.03% | −0.54% |

On 4.0.9 the largest A/A over all 19 cases is 0.22%; `attribute_names` −27%, partial `changed?` −29%, partial
`as_json` −26%, and every load, reader and `#attributes` case is within the A/A. Every ZJIT window compiled 0 ISEQs
and 0 side exits and spent 0 ns invalidating, on all three trees; no ZJIT loss. Objects: 2 fewer per `#keys` call at
30 columns (the union's Array and the Hash `Array#|` builds above 16 names), 6 per save. Master interpreter
controls over three runs (`master/rep1`, `master/rep2`): `find` fix +0.02% to +0.04% (A/A up to +0.12%),
`#attributes` −0.05% to +0.12% (A/A −0.09% to +0.10%), `new` −0.54% to −0.67% in every run (fix 56,018–56,168
against main 56,394–56,475 and main2 56,459–56,733). `new` calls neither `#keys` nor `materialize`; the 2026-11-14
pass saw the same cell move the other way (+0.43%), so this reads as the ID-table layout shift recorded there (a
hypothesis), and it is a gain, not a loss.

### Pinned-tool cohort (2026-11-18, after the thermos-sol confirm)

The confirm on `af84ab1445` (thermos-sol, thread T-01a1ee42-22c6-70af-9a1a-6a1138a03083) found that run.sh accepted a
zero Valgrind exit without reading its log and then deleted the log and dumps. Its fresh stock Valgrind 3.24.0 cohort
(Ruby 4.0.9, width 30, N=200, WARM=100, all 19 cases, census heap floors) logged `brk segment overflow` in main,
main2 and fix while exiting 0, with A/A up to 1.887%. That cohort is **rejected** under
[docs/bench.md](../../../docs/bench.md) (Valgrind brk reservation correction) and is not rerun; its dumps and logs are
in that review's orb under `.amp/in/orb-backup/k1-confirm/bench`.

run.sh now runs Valgrind with `--verbose`, records the tool path, version and `ulimit -d` in `TREE-MODE-wWIDTH/tool`,
keeps stdout, stderr and the Callgrind dumps in `TREE-MODE-wWIDTH/` next to the JSONL, refuses an existing output
directory, and exits 3 (rejecting the run) when the log has a brk overflow, whatever Valgrind returned. Check: a stock
3.24.0 run of main with it was refused with exit 3 (`brk segment overflow in thread #1: can't grow to 0x4844000`);
retained as [rejected-stock-3.24-8e097e9d81](results/rejected-stock-3.24-8e097e9d81).

Declared cohort [brk512-8e097e9d81](results/brk512-8e097e9d81) (manifest written before the first run; one run per
arm, not retried): Valgrind 3.19.0 built by `script/bench-valgrind` with the 512 MiB brk reservation
(`valgrind.json`: tool SHA-256 `d11018bd…`, patch `ab95c4a3…`, glibc 2.41), `ulimit -d unlimited`, irwin built
against its headers, Ruby 4.0.9, main and main2 at `8e097e9d81`, fix at `af84ab1445`, Gemfile.lock identical apart
from the tree path, the same harness, cases, heap floors and window protocol. All three arms exited 0 and **no log has
a brk overflow**. Logs and dumps (`callgrind.tar.xz`) are kept.

Ir per window is each Callgrind dump's trailing `totals:` line (docs/bench.md: Valgrind 3.19 can wrap `summary:` after
repeated zero/dump requests). The first export of this cohort read `summary:`, which differed from `totals:` in 99 of
the 114 measured windows and made `new` look like a main-arm outlier (A/A −1.33%); after the measurement confirm
(Lowrail 6342156f) run.sh exports through [export.rb](export.rb), which reads only `totals:` and fails without it
([export_test.rb](export_test.rb) covers a dump whose `summary:` differs and one without `totals:`). The same retained
dumps were re-exported; the summary-based exports are kept as `*.summary.jsonl`. All other fields are identical. No
new cohort was run. The earlier stock-tool exports in this record were also summary-based and have no dumps left.

| Ir per call, 30 cols, Ruby 4.0.9 | main | A/A | fix | objects |
|---|---:|---:|---:|---:|
| `changed?` | 191,805 | −0.29% | **−12.99%** | 3 → 1 |
| `serializable_hash` | 203,514 | −0.51% | **−12.43%** | 35 → 33 |
| `update!` of one column | 1,375,929 | −0.07% | **−5.40%** | 189 → 183 |
| `find` then `save` | 1,530,171 | −0.12% | **−8.36%** | 169 → 163 |
| `find` then `dup` | 1,118,770 | −0.05% | **−5.00%** | 182 → 182 |
| `attribute_names` | 90,150 | −0.48% | −27.19% | 3 → 1 |
| partial `changed?` | 84,204 | −0.52% | −29.25% | 3 → 1 |
| `find` | 401,438 | +0.01% | −0.01% | 68 → 68 |
| `#attributes` | 621,280 | −0.03% | −0.02% | 83 → 83 |
| STI `#attributes` | 651,274 | −0.03% | −0.04% | 88 → 88 |
| `new` | 54,973 | −0.00% | −0.21% | 9 → 9 |

The largest A/A over all 19 cases is 0.52% (partial `changed?`); load, readers, `#attributes` and `new` are within it.
The body table uses this cohort.

Diagnostic cohort [brk512-8e097e9d81/master](results/brk512-8e097e9d81/master), same pinned tool, Ruby master
`9aa0898240`, eight cases, ZJIT then interpreter, declared and run once, same `totals:` re-export: no brk overflow in
any of the six arms, every ZJIT window 0 compiled ISEQs, 0 side exits, 0 ns invalidating. ZJIT: `changed?` −22.2%,
`serializable_hash` −13.6%, `update!` −8.5%, `find` then `save` −12.1%, `find` then `dup` −5.6% (A/A ≤ 0.56%);
`find` −0.16%, `#attributes` −0.10%, `new` −0.10% (A/A −0.04%, −0.06%, +0.02%). Master interpreter: −10.4%, −10.0%,
−4.4%, −7.5%, −5.0% (A/A ≤ 0.10%), `find` and `#attributes` within 0.03%, `new` −0.54% (A/A +0.06%). No ZJIT loss.
Diagnostic only: master has no invalidation count.

## Rerun

```
RAILS trees under ~/k1 (git worktree add --detach), bundles in ~/k1/suite-TREE (copies of .lowrail/rails-suite
pointed at the tree, plus argon2); irwin.so built from irwin.c into ~/k1/ext.
N=200 WARM=100 bench/upstream/k1/run.sh OUT TREE WIDTH interp|yjit [CASE...]
Since 2026-11-18 on the pinned tool only: script/bench-valgrind NEW_PREFIX, ulimit -d unlimited, PATH=NEW_PREFIX/bin:$PATH,
irwin rebuilt with CPATH=NEW_PREFIX/include into IRWIN_DIR; keep NEW_PREFIX/share/lowrail/valgrind.json with the cohort.
OUT must be new; run.sh exits 3 on a brk overflow, which rejects the whole cohort.
run.sh exports with export.rb (Callgrind `totals:` only); re-export kept dumps with ruby bench/upstream/k1/export.rb DIR TREE MODE.
ruby bench/upstream/k1/table.rb OUT; ruby bench/upstream/k1/sweep.rb OUT interp
BUNDLE_GEMFILE=~/k1/suite-TREE/Gemfile ruby bench/upstream/k1/keys_probe.rb > TREE.txt
BUNDLE_GEMFILE=~/k1/suite-TREE/Gemfile ruby bench/upstream/k1/edge_probe.rb > edge-TREE.txt
Master: Ruby 9aa0898240 in ~/w/ruby-master, bundles in ~/k1/suiteM-TREE (activesupport, activemodel, activerecord,
sqlite3; BUNDLE_PATH=~/k1/gemsM), irwin.so built for it in ~/k1/extM:
PATH=~/w/ruby-master/bin:$PATH RUBY_BIN=~/w/ruby-master/bin SUITE=suiteM BUNDLE_PATH=~/k1/gemsM IRWIN_DIR=~/k1/extM \
  N=200 WARM=100 bench/upstream/k1/run.sh OUT TREE 30 zjit|interp [CASE...]
```
