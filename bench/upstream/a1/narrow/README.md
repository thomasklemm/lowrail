# A1 narrowed to `join_scope` (head `e6bfe76e95`)

The second Thermos review of `80daecf52a` ([review](../review-thermos-sol-80daecf52a/README.md)) found two
probes where the head gave a third answer, matching neither 8.1 nor main:
- a scoped reader with a hash- or context-dependent serializing type: head record 69, 8.1 44, main 35;
- a no-scope reader with an association extension: head 4, 8.1 3, main 2.

Fixing those boundaries would require reproducing 8.1's order of extension hooks, merges and serialization in
the reader. #59836's parent already differs from 8.1 there, so no small change restores it. A1 is therefore
narrowed to the case where the head matched 8.1: `join_scope` for an association without scope items.

## The change

One commit on rails/rails main `e30c36266b`, branch `thomasklemm/association-owner-conditions-unscoped`,
force-pushed with a lease on `80daecf52a` ([patch](../A1.patch)):

- `reflection.rb` (+5/−3): `join_scope` computes the fixed-value difference and calls `keep_owner_conditions` only
  when `join_scopes` returned scope items. Without scope items nothing is merged, so no condition can be removed.
  With scope items the code is unchanged, including the order of the difference and the merges.
- `association_scope.rb`: unchanged from main. The reader keeps main's behavior, including the earlier repro 1
  (`[1]`, as on main and unlike 8.1).
- `has_many_associations_test.rb`: one test. A join and a filtered `eager_load` with a target default scope of 17
  conditions, one of them `2**70`, return no records. One child row matching the owner key is seeded, so dropping
  the default scope fails the test.
- `CHANGELOG.md`: a short entry.

## Results

The reviewer's scripts ran unchanged on the new head (`narrow`), SQLite and PostgreSQL, both settings ([raw](raw/)).
Per section, compared with the reviewer's receipts using [`sections.rb`](sections.rb):

| Probe | Narrowed head equals |
| --- | --- |
| Every join probe at width 17: `join_serialization`, `range_join`, `range_plain`, `linear_join`, `range_paths` | 8.1 (and `80daecf52a`), not main |
| Earlier repro 1, reader composite key, width 17 | main (reader unchanged) |
| `scoped_join` and every width-16 control | 8.1, main and `80daecf52a` alike |
| `scoped`, `scoped-order`, `scoped-effects`, `scoped-hash` groups, including both third-answer cases | main, byte for byte |

`range_paths`: with an unrestricted `eager_load` or `includes.references`, 8.1 and the head return one parent
with zero children (an outer join), not an empty result; `preload` and the reader raise on all trees.

What stays broken, as on main since #59836: a reader or `preload` with an out-of-range owner key or default
condition, and a scoped join whose association scope `unscope`s an out-of-range default condition
(`scoped_join_removed.rb`). A1 does not claim them.

Targeted test, the test class run on its own ([raw](raw/)), both settings (8.1 has no setting):

| Tree | SQLite | PostgreSQL |
| --- | --- | --- |
| main `e30c36266b` | 1 error, `ActiveModel::RangeError` | same |
| 8-1-stable `aab611acd8` | pass, 4 assertions | same |
| head `e6bfe76e95` | pass, 4 assertions | same |
| head, default scope removed (mutation) | 1 failure, a joined parent returned | same |

Full suites on the head with `-w` ([`ar_tests.sh`](../ar_tests.sh)):
- SQLite: 3,271 runs, 10,741 assertions, 0 failures, 0 errors, 1 skip (the existing tuple-syntax skip).
- PostgreSQL: 3,276 runs, 10,754 assertions, 0 failures, 0 errors, 0 skips.
- MySQL: not run.

Cost: only the join cells of the earlier [body/a1](../body/a1/table.md) numbers still apply, about −3% of
instructions for `Author.joins(:posts)`. The reader savings are gone. These numbers are internal, not part of the
correctness body.
