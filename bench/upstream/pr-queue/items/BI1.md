---
id: BI1
repo: ankane/blind_index
kind: fix
area: Active Record queries
reviewer: ankane
branch: thomasklemm/frozen-table-metadata
head: "e296933106ce3619b26af46f936aea95b087c0ec"
base: master
built_on: "ddbf0240fe600b589ce1cacdc4a2277533b20c66"
depends_on: []
impact: Restore queries on Rails main when Active Record freezes table metadata
rank: 14
risky: true
state: in-review
note: Prepared only; coordinator runs Sol and Astra; no upstream submission authorized in this worker
passes:
  - {reviewer: skeptic, head: "e296933106ce3619b26af46f936aea95b087c0ec", date: 2026-11-05, verdict: approve, open: "L0; live capability-check boundary disclosed; no speed claim"}
---

# Avoid memoizing on frozen Active Record table metadata

Check whether the model supports blind indexes without writing to its table metadata. Rails main now freezes the metadata used by a model's predicate builder, so even `User.find_by(id: 1)` raises `FrozenError` with blind_index loaded.

The query transformation and index generation stay unchanged. The internal `has_blind_indexes?` helper now checks the model on each call instead of caching that check.

On Ruby 4.0.9, the existing SQLite suite goes from 28 errors to none on Rails main: 50 runs, 89 assertions, one existing skip. It also passes on Active Record 8.1.4.1 with the same counts. Existing tests cover indexed and ordinary columns, arrays, negation, normalization, associations and uniqueness validation.

---
<sub>Found while running Lowrail's [Rails-main gem census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-side-candidates.md#bi1-blind_index-frozen-table-metadata).</sub>
