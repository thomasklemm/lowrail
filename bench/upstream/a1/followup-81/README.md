# A1 follow-up: the review's counterexamples against Rails 8.1

**Superseded in part, 2026-11-18** ([second review](../review-thermos-sol-80daecf52a/README.md),
[narrowed head](../narrow/README.md)). The matrix below holds for these probes only. Two later probes show
`80daecf52a`'s reader departing from both 8.1 and main, so "A1 restores 8.1" and "8.1 gives the branch's answer"
do not hold in general. A1 is now narrowed to unscoped `join_scope`.

Thermos asked for changes ([review](../review-thermos-sol/README.md)): `WhereClause#-` can hash predicates, which
serializes bind values, so computing the differences later than main gives different SQL and records. This
follow-up reran those repros on Rails 8.1 and on #59836's parent, added five more probes, and added regression tests
to the branch (head `80daecf52a`).

Ruby 4.0.9, SQLite 3.54.1 and PostgreSQL 17.12. Trees: 8-1-stable `aab611acd8`, #59836's parent `f0c9373b05` (after
#59825), #59836's merge `ff53633d52`, main `e30c36266b`, branch head `80daecf52a`.

## Result

**8.1 gives the branch's answer in every case, and main's answers first appear at #59836's merge.** For
these probes, #59836 changed *when* bind values are serialized compared with 8.1, and `80daecf52a` gave 8.1's
answer. Raw output is one file per tree in [raw/](raw/). 8.1, #59836's parent and the
head are byte-identical (34 lines). Main and #59836's merge are byte-identical too, and differ from 8.1 on 14 lines.
On PostgreSQL, 8.1 and the head are identical, and main differs from SQLite only in the adapter class named in
error messages.

| Probe | 8.1 | main | head |
| --- | --- | --- | --- |
| [composite_serialization.rb](composite_serialization.rb): review repro 1, 17-column key, the scope changes the serializer | `[2]` | `[1]` | `[2]` |
| [join_serialization.rb](join_serialization.rb): review repro 2, unscoped `as:` join, 17 target default-scope conditions | `k0=101` | `k0=1` | `k0=101` |
| both at width 16 | same as head | same as head | same |
| [linear_join.rb](linear_join.rb): **two** conditions, a context-dependent type on `parent_type` and a target default scope on the same column | `ParentX` | `Parent` | `ParentX` |
| [range_join.rb](range_join.rb) / [range_plain.rb](range_plain.rb): **built-in integer**, 17 default-scope conditions, one out of range, `joins` (`as:` and plain `has_many`) | no rows (`1=0`) | **`ActiveModel::RangeError`** | `[]` |
| [range_paths.rb](range_paths.rb): the same through `preload`, `eager_load`, `includes.references`, a reader | `eager_load` and `includes.references` return one parent with zero children (outer join); `preload` and the reader raise | all four raise | same as 8.1 |
| [scoped_join.rb](scoped_join.rb): repro 2 with a scope on the joined association | `k0=1` | `k0=1` | `k0=1` |

All rows are the same with `association_scope_keeps_owner_conditions` false and true. 8.1 has no such setting, so
the scripts set it only where it exists.

## Is there an exact fast path against main?

**No.** The comparisons that main runs and A1 skips (no association scope merged) are what call user code:
- **Hash path.** `Array#-` hashes both sides once each has more than 16 elements, and `QueryAttribute#hash` serializes.
- **Linear path.** `QueryAttribute#==` serializes too, for two predicates on the same column. `linear_join.rb` shows
  this with two conditions.

So no size boundary separates the cases. A type boundary does not hold either, because `range_join.rb` uses the
built-in integer type. A guard that proved no user code runs would have to walk every predicate against an allowlist
of node, type and value classes. It would also have to range-check every value, and handle decorated built-in types
such as time zone, encrypted and serialized ones. That is not a provable boundary; it is a second implementation of
serialization.

## What the head claims instead

* **No scope merged** (`add_constraints` when the chain has no scope item, and `join_scope` when `join_scopes` is
  empty): no difference is computed, so nothing is compared or serialized there, as on 8.1. Without merges or
  `unscope`, every owner condition is still in the where clause as the same object. `Array#-` matches identical
  elements before calling `eql?` (in `rb_eql` and in the hash lookup), so main's result here is always empty. The
  skip changes no SQL, records or warnings. It does change calls into user types, and those calls match 8.1.
* **A scope merged:** `add_constraints` computes the same differences after the scope ran, not before. This can
  differ from main (repro 1) and matched 8.1 in every probe. `join_scope` computes them at the same points as main.
* **Not claimed:** identity with 8.1 for every custom type in the scoped path. A type whose serialization changes
  between the end of `add_constraints` and query compilation would see it serialized earlier than on 8.1, on main
  and on the head alike.

## Tests

Branch commit `80daecf52a` adds `HasManyOwnerConditionsSerializationTest` (2 tests, 5 assertions, its own tables,
non-transactional). It covers the out-of-range join and repro 1 through `association(:children).scope`; the
reader's statement cache does not show it. Both tests fail on main (one `RangeError`, one `[1]` instead of `[2]`)
and pass on the head and on 8.1, using a copy of the class in the 8.1 tree, on SQLite and PostgreSQL. Full suites on
the head with `-w`, using [`ar_tests.sh`](../ar_tests.sh):
- SQLite: 3,272 runs, 10,742 assertions, 0 failures, 0 errors, 1 skip (the existing tuple-syntax skip).
- PostgreSQL: 3,277 runs, 10,755 assertions, 0 failures, 0 errors, 0 skips.
- MySQL: not run.

The library code is unchanged from `9877a852dd`. Thermos's extended probe (118 cases) and the census probes therefore
still apply, and so do the instruction and object numbers.

Run: `./run.sh NAME=/abs/rails/tree ...`; add `ADAPTER=postgresql DATABASE=<disposable database>` for PostgreSQL.
