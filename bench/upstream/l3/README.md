# L3: `attributes_for_database` and `attributes_before_type_cast` after rails/rails#59141

Census 9's [lead 3](../../../docs/upstream/rails-main-census-9.md#marshal-and-messagepack-lead-3), investigated and
built 2026-11-14 in [thread T-01a1da35](https://ampcode.com/threads/T-01a1da35-808b-72d5-afdd-88fbe97771ac). Queue item:
[L3](../pr-queue/items/L3.md). Branch `thomasklemm/attrs-for-database-row` on thomasklemm/rails, head `52587b6f5d`,
built on rails/rails main `50c54eed06` ([patch](results/L3.patch), +24 in `attribute_set.rb`). Ruby 4.0.9,
PostgreSQL 17.

## Cause

`ActiveRecord::Marshalling#_marshal_dump_7_1` (`marshalling.rb:23`) and the MessagePack coder's `build_entry`
(`message_pack.rb:89`) call `attributes_for_database`, which is `@attributes.values_for_database`.
`attributes_before_type_cast` is `@attributes.values_before_type_cast`. Both are inherited from `AttributeSet`
(`attribute_set.rb:115/119`): `attributes.transform_values(&:value_…)`. For a `LazyIndexedAttributeSet`,
`attributes` (`:457`) runs `materialize` (once per set), then on **every** call copies the set's attribute Array into
a fresh `IndexedRow.unset_row` and wraps it in a new `IndexedRow::Mutable`, which `IndexedRow#transform_values` then
walks name by name, checking each slot again with `index_for`.

Measured directly (interpreter Ir per call on a warm record, [cause](results/raw/cause)), the protected
`attributes` call alone is the copy:

| | 30 cols: 8.1 | main (A/A) | 300 cols: 8.1 | main (A/A) |
|---|---:|---:|---:|---:|
| set's `attributes` | 794 (0 objects) | 32,820 / 32,820 (3 objects) | 794 | 281,509 / 281,504 |
| `attributes_for_database` | 71,995 (1) | 161,515 / 161,451 (4) | 715,250 | 1,564,549 / 1,564,907 |
| `attributes_before_type_cast` | 21,249 (1) | 123,523 / 123,460 (4) | 206,113 | 1,182,587 / 1,183,721 |

8.1's `LazyAttributeSet#attributes` returns the materialized Hash it keeps, so these are one C
`Hash#transform_values` there. On main the copy plus the second walk are 55k of `attributes_before_type_cast`'s
124k at 30 columns; the fix removes exactly that (below).

## Can the broken piece go?

* **The copy in `attributes`.** It is needed: `@attributes` marks unbuilt slots with `nil` and `IndexedRow` marks
  them with `UNSET`, and other callers (`each_value`, `values`, `accessed`, `cast_types`, `==`, `read_only`) use the
  row. Sharing the Array would need the set to switch to `UNSET`, which every reader checks with `&.`/truthiness.
  Not a small change, and not ours to make inside tenderlove's design.
* **`values_for_database`/`values_before_type_cast` on `AttributeSet`.** They can't go: they are the public
  `attributes_for_database`/`attributes_before_type_cast`. So the fix overrides them on `LazyIndexedAttributeSet`,
  like czj's `to_hash` (19022a4aa4, inside #59141).
* **`materialize`.** It can't go without changing output (the lead's open question, answered no):
  * Reading values from the row (`type.serialize(value_at(...))`, [variant](results/variant-row-read.diff)) is not
    exact. `Attribute#value_for_database` keeps what it returns, so main dumps the same ciphertext for a
    non-deterministically encrypted attribute on every call; the row read re-encrypts each time
    (`attributes_for_database` twice equal: main and fix true, row read false; `Marshal.dump(r) == Marshal.dump(r)`
    likewise). It also changes `accessed_fields`. Probe diff: 529 changed lines
    ([gz](results/probe-rowread-diff.txt.gz)). Nor is it faster on a record that is dumped more than once, since it
    serializes again on every call: at 30 columns `Marshal.dump` of a warm record is 427,955 Ir against main's
    362,232 and the fix's 306,514; only `find` then `Marshal.dump` is cheaper (989,072, fix 1,150,291), because it
    skips building the attributes ([raw](results/raw/shape/fixB-interp-w30.jsonl)).
  * Reading only `values_before_type_cast` from the row ([variant](results/variant-row-read-btc-only.diff)) still
    changes `accessed_fields` after `attributes` (35 lines, [gz](results/probe-rowread-btc-only-diff.txt.gz)): main
    builds every attribute, so `#attributes` reads each one, including those whose value is `nil`; without
    `materialize` those stay unread.

So the fix keeps `materialize` and the attributes it builds, and drops only the per-call row copy and the second
`index_for` walk. Laziness is the same as main's: these calls built every attribute on main, and still do.

## The change

```ruby
def values_before_type_cast    # values_for_database the same, with value_for_database
  materialize
  hash = {}
  indexes.each_key do |name|
    if attribute = lookup(index_for_name(name))
      hash[name] = attribute.value_before_type_cast
    end
  end
  hash
end
```

Same keys in the same order as `IndexedRow#transform_values` over the copy: it walks `indexes.each_key` and keeps
the names whose slot `attributes` filled, which are exactly the slots with a built attribute. Same method on the
same attribute objects, so the values and every attribute's state afterwards are the same.

Shapes tried at 30 columns ([raw](results/raw/shape)): a shared private helper with a block
([diff](results/variant-shared-helper.diff)) costs 15k Ir more per call; reading `@attributes[indexes[name]]` inline
([diff](results/variant-inline-lookup.diff)) saves 10k more but bypasses `lookup`'s nil guard for a set with no
attributes stored. The branch keeps the two plain methods.

## Exactness

[probe.rb](probe.rb) prints, per scenario and sequence of operations, `attributes_for_database` (twice, compared),
`attributes_before_type_cast`, reads, writes, in-place mutation, `name_for_database`/`read_attribute_before_type_cast`,
`#attributes`, `changes`, `accessed_fields`, `new_record?`, `frozen?`, a Marshal round trip (dump stable, copy
state, copy's `attributes_for_database`, cached association), a MessagePack round trip with
`ActiveRecord::MessagePack::Extensions`, and `save` (then both Hashes, `changed?`, `previous_changes`, `reload`).

* 17 scenarios × 12 sequences: loaded, loaded with nil columns, `new` (full, empty, by alias), `create!`, partial
  select, partial select with `AS` extras, `select(:id, :full_name)`, STI subclass and via parent, `becomes`,
  `find_by_sql` with an extra column, `readonly`, `includes(:notes)`, `dup`, `freeze`. The model has string,
  integer, boolean, datetime with µs, date, decimal, float, JSON-serialized text, YAML `Array` text, `json`, a
  non-deterministic and a deterministic encrypted attribute, binary, an enum, `alias_attribute`, two virtual
  attributes with defaults (one a proc), and an STI subclass with its own attribute.
* Payloads: Marshal (7.1 format, and 6.1 format from 8.1) and MessagePack, clean and dirty, of loaded, new, partial,
  STI, `includes` and created records, dumped by **8.1** (`71e963ed1b`), **main** and the **fix**, then loaded and run
  through every sequence on each tree. 66 payload files per adapter.
* SQLite and PostgreSQL 17. Time frozen with `travel_to`, ciphertext shown decrypted, object addresses masked.

Result ([sha256](results/probe-sha256.txt), main's output [SQLite](results/probe-sqlite-main.txt.gz),
[PG](results/probe-pg-main.txt.gz)): main, main2 and the fix print byte-identical output on both adapters (8,274 and
8,295 lines).

Unrelated finding, same on main and the fix: records dumped by 8.1.4.1 in the **6.1 format** fail on main. A loaded
record raises `ArgumentError: undefined class/module ActiveRecord::Result::IndexedRow` on `Marshal.load`; a new
record loads, but `save` raises `NoMethodError: undefined method 'transform_row' for an instance of Hash`
([repro](marshal_6_1_repro.rb); 8.1 loads and saves both). Main's 6.1 fixtures were dumped by Rails 6.1 and pass.
tenderlove's open #59249 removes 6.1 loading. Not part of this change. Investigated afterwards: intended and
documented, not built ([census 9](../../../docs/upstream/rails-main-census-9.md#records-in-the-61-marshal-format-from-81-not-a-lead)).

## Tests on the fix

* Active Model: 1,269 runs, 5,633 assertions, 0 failures, 0 errors.
* Active Record SQLite: 10,375 runs, 0 failures, 4 errors in `sqlite_rake_test` from a missing `sqlite3` CLI;
  15/15 once installed.
* Active Record PostgreSQL 17: 11,298 runs, 40,907 assertions, 0 failures, 0 errors, 31 skips.
* RuboCop 1.90.0 (Rails' config) on `attribute_set.rb`: no offenses. `git diff --check` clean. No comments added.
* GitHub Actions on the fork (devcontainer smoke test, rails-new-docker): green on `52587b6f5d`.
* No new test: the contract (same Hash, same attribute state) is covered by the existing marshal, MessagePack,
  before-type-cast and encryption tests, and a plausible regression (dropping `materialize`) is what the probe
  above catches; a unit test for it would have to assert on internal state.
* Merged with K1 (`thomasklemm/lazy-indexed-keys`, `bbdd9945d3`): no conflict; Active Model 1,269 runs and the AR
  marshal, MessagePack, dirty, attribute-methods, serialized-attribute and encryption files (563 runs) pass.

## Measurement

[attr_bench.rb](attr_bench.rb) under [run.sh](run.sh), the K1 harness: one process per tree, width and mode, stock
Valgrind 3.24 Callgrind client requests (`bench/upstream/k1/irwin.c`) around each window of N=200 calls after 100
warmup calls (under YJIT, until three warm windows compile nothing), `GC.start` then `GC.disable` around the window,
census fixed heap (`RUBY_GC_HEAP_{0..4}_INIT_SLOTS`), the `_empty` window subtracted. Table as census 9's
`attr_micro.rb`: `id`, `type`, data columns cycling string, integer, boolean, datetime, float, text, and timestamps;
Marshal format 7.1 on every tree. Trees: 8.1 (`71e963ed1b`), main and main2 (A/A, both `50c54eed06`), fix.
Tables: [interp](results/sweep-interp.md), [yjit](results/sweep-yjit.md) ([table.rb](table.rb)); raw:
[results/raw/sweep](results/raw/sweep).

Interpreter, fix against main (A/A = largest |main2 − main| of these rows at that width):

| interp | 6 cols | 30 cols | 100 cols | 300 cols |
|---|---:|---:|---:|---:|
| `Marshal.dump(record)` | −15.9% | −15.4% | −15.2% | −15.3% |
| `find` then `Marshal.dump` | −3.2% | −4.6% | −5.2% | −5.4% |
| MessagePack dump | −25.1% | −27.1% | −27.7% | −28.1% |
| `attributes_for_database` | −42.2% | −34.3% | −33.1% | −32.7% |
| `attributes_before_type_cast` | −53.2% | −44.4% | −43.1% | −42.7% |
| `find`, dump, `save` | −1.8% | −2.3% | −2.4% | −2.5% |
| `find`, reader, `#attributes`, `Marshal.load` | ±0.1% | ±0.1% | ±0.1% | ±0.1% |
| A/A | ≤ 0.21% | ≤ 0.26% | ≤ 0.08% | ≤ 0.05% |

Objects: 3 fewer per call (4 → 1 for each Hash; 28 → 25 per `Marshal.dump` at 30 columns).

Against 8.1, the fix recovers 60–70% of main's regression on a warm record, not all of it:
`Marshal.dump` main +29.6% / +33.3% / +34.0% / +33.9% vs 8.1 at 6/30/100/300 columns, fix +9.1% / +12.8% / +13.7% /
+13.5%; MessagePack dump main +52% to +87%, fix +14% to +35%. What remains is the walk itself: 8.1 runs one C
`Hash#transform_values`, main (with or without the fix) a Ruby loop over the indexes. `find` then `Marshal.dump` is
+21.2% / +3.7% / −2.0% / −4.3% on main against 8.1 and +17.3% / −1.0% / −7.1% / −9.5% with the fix, since loading is
much cheaper on main.

YJIT, fix against main, only cells where main, main2 and the fix all compiled nothing in the measured window
(the others are `rej` in [sweep-yjit.md](results/sweep-yjit.md)):

| yjit | 6 cols | 30 cols | 100 cols | 300 cols |
|---|---:|---:|---:|---:|
| `Marshal.dump(record)` | −15.8% | −15.7% | −16.1% | −15.8% |
| MessagePack dump | rej | −34.8% | −36.2% | −36.8% |
| `attributes_for_database` | −56.7% | −46.1% | −45.4% | −44.6% |
| `attributes_before_type_cast` | −58.8% | −48.3% | −47.3% | −46.9% |
| `find` then MessagePack dump | −7.6% | −7.8% | rej | −9.4% |
| `find`, reader, `#attributes`, `Marshal.load` (flat cells) | −0.3% to +0.1% | ±0.1% | ±0.1% | ±0.0% |
| A/A | ≤ 1.67% | ≤ 0.41% | ≤ 0.84% | ≤ 0.40% |

At 6 columns the A/A reaches 1.67% (`find` then MessagePack dump); the warm-record rows are far outside it.

Not measured: Ruby master × ZJIT (DECISIONS asks for it before opening; the review pass should run it, as K1's
did).

## Overlap (2026-11-14)

* #59141's thread (body, 24 comments, 18 reviews, 24 review comments, read in full): tenderlove's announced follow-ups are removing `IndexedRow`
  for ORM queries (byroot: keep it for `exec_query`), a width-based backing strategy, decoupling `becomes`,
  index-based generated writers and other generated methods, and removing 6.1 Marshal (#59249). On `#attributes`
  he suggested a Hash-like wrapper; czj's row-reading `to_hash` went in instead. Nobody mentions
  `values_for_database`, `values_before_type_cast`, `attributes_for_database`, MessagePack or the cost of dumping;
  Marshal comes up only as restoring and later removing 6.1 support, and whether the `UNSET` sentinel leaks into Marshal or YAML dumps.
* Open PRs touching these files: kamipo's #58380 (`StoreAttribute`, edits `attribute_set.rb` but not these methods),
  tenderlove's #59249 (6.1 Marshal loading; `builder.rb` and tests), tenderlove's draft #53344 (old refactoring,
  already conflicts with main in six files), ikraamg's #58002 (`builder.rb`). `git merge-tree` of each with the fix
  conflicts in exactly the files it already conflicts in with main. hasannadeem's #59684 only adds a PG MessagePack
  test.
* GitHub search of open rails/rails PRs and issues for `values_for_database`, `attributes_for_database` and
  `attributes_before_type_cast`: #51420 (`Model` type), #58614 (bytea), #59684 and issue #59682 (PG arrays in
  MessagePack); none touches this path.
* If tenderlove removes `IndexedRow` from ORM loads or changes `@attributes`' `nil` convention, `attributes` gets
  cheaper by itself and this override becomes unnecessary. Neither is in an open PR.

## Rerun

```
Trees under ~/l3 (git worktree add --detach from a blobless rails clone), bundles ~/l3/suite-TREE (BUNDLE_PATH=~/l3/gems),
irwin.so built from bench/upstream/k1/irwin.c into ~/l3/ext.
N=200 WARM=100 bench/upstream/l3/run.sh OUT TREE WIDTH interp|yjit [CASE...]
FIX=fixA ruby bench/upstream/l3/table.rb OUT interp|yjit
RAILS=~/l3/TREE BUNDLE_GEMFILE=~/l3/suite-TREE/Gemfile [ADAPTER=postgresql] ruby bench/upstream/l3/probe.rb dump DIR
RAILS=~/l3/TREE BUNDLE_GEMFILE=~/l3/suite-TREE/Gemfile [ADAPTER=postgresql] ruby bench/upstream/l3/probe.rb probe DIR...
```
