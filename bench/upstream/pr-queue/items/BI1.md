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
state: closed
pr: 62
note: "closed by ankane 2026-11-05 22:54 UTC; he fixed it himself on master in ac61e54cf4 (\"Fixed FrozenError with Active Record 8.2 - resolves #62\"); reacted 👍"
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

On Rails main with Ruby 4.0, Active Record makes its table metadata Ractor-shareable, which freezes it, so `has_blind_indexes?` can no longer memoize on it. With blind_index loaded, even `User.find_by(id: 1)` raises `FrozenError`.

This keeps the memo where it can, and skips storing it only when the metadata is frozen. Released Rails behaves as before.

I'll keep this as a draft until the Rails 8.2 beta, since the freezing on main may still change, and update it then.

---
<sub>Found while running Lowrail's [Rails-main gem census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-side-candidates.md#bi1-blind_index-frozen-table-metadata).</sub>
