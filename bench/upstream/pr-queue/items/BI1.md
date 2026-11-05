---
id: BI1
repo: ankane/blind_index
kind: fix
area: Active Record queries
reviewer: ankane
branch: thomasklemm/frozen-table-metadata
head: "b7d3502ea98aee5b8f1d9153828df88728d5b6fe"
base: master
built_on: "ddbf0240fe600b589ce1cacdc4a2277533b20c66"
depends_on: []
impact: Restore queries on Rails main when Active Record freezes table metadata
rank: 14
risky: true
state: draft
pr: 62
note: Prepared only; coordinator runs Sol and Astra; no upstream submission authorized in this worker
passes:
  - {reviewer: skeptic, head: "e296933106ce3619b26af46f936aea95b087c0ec", date: 2026-11-05, verdict: approve, open: "L0; live capability-check boundary disclosed; no speed claim"}
  - {reviewer: sol, head: "e296933106ce3619b26af46f936aea95b087c0ec", date: 2026-11-05, verdict: changes, open: "P2; preserve cached false across late blind_index declarations on mutable metadata"}
  - {reviewer: astra, head: "e296933106ce3619b26af46f936aea95b087c0ec", date: 2026-11-05, verdict: changes, open: "P2; subclass warmed before parent declaration changes query results"}
  - {reviewer: skeptic, head: "45d5ff0a720a684e8cab6def932705f360c4cb06", date: 2026-11-05, verdict: nits, open: "No correctness blocker; strengthen frozen-query fixture with different plaintext/index targets"}
  - {reviewer: skeptic, head: "b7d3502ea98aee5b8f1d9153828df88728d5b6fe", date: 2026-11-05, verdict: approve, open: "Asymmetric frozen fixture rejects always-false mutant; revised body approved; no remaining nits"}
  - {reviewer: sol, head: "b7d3502ea9", date: 2026-11-05, verdict: approve, open: "confirm: earlier findings addressed, no new finding"}
  - {reviewer: astra, head: "b7d3502ea9", date: 2026-11-05, verdict: approve, open: "confirm: earlier findings addressed"}
---

# Avoid memoizing on frozen Active Record table metadata

Keep the capability memo on mutable table metadata, and skip its assignment only when the metadata is frozen. With Ruby 4.0.9 and Rails main at `1e235cee11b0a7aecb189d8837534807626287aa`, the model's predicate-builder metadata is frozen, so even `User.find_by(id: 1)` raises `FrozenError` with blind_index loaded.

Existing cached values, including false, are reused even after freezing. Queries warmed before a late `blind_index` declaration therefore keep their released-Rails behavior. Index generation and predicate transformation after the capability check are unchanged. Overrides of private `TableMetadata#klass` or the model's `respond_to?` see repeated checks only on uncached frozen metadata.

`bundle exec rake test` passes on Active Record 8.1.4.1: 52 runs, 98 assertions, one existing skip. With the same dependencies switched to the pinned Rails main: 52 runs, 92 assertions, two skips (dynamic finder and mutable-metadata-only case). The two new tests cover late declarations, including on a subclass's parent, cached values retained after freezing, and initially frozen metadata. The original main suite had 28 errors.

---
<sub>Found while running Lowrail's [Rails-main gem census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-side-candidates.md#bi1-blind_index-frozen-table-metadata).</sub>
