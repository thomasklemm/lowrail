---
id: RA1
repo: activerecord-hackery/ransack
kind: fix
area: Correlated subquery SQL rendering
reviewer: scarroll32
branch: thomasklemm/correlated-subquery-arel-table
head: "1290b01fcb9a78717365968c791e75fa28a1016d"
base: main
built_on: "9bbadf13fc165ee5f195cd5b210e61ca37ffceed"
depends_on: []
impact: Keep Context#build_correlated_subquery(...).to_sql working on Rails main
rank: 16
risky: true
state: draft
pr: 1795
note: Prepared only; coordinator runs Sol and Astra; one unchanged Rails-main SQLite schema-case failure
passes:
  - {reviewer: skeptic, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: approve, open: "L0; direct-render scope and internal override boundary disclosed"}
  - {reviewer: sol, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: nits, open: "Body needs Rails pin, arel_table override boundary, commands and exact regression/failure names"}
  - {reviewer: astra, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: nits, open: "Same body clarifications; code unchanged"}
  - {reviewer: skeptic, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: approve, open: "Revised body approved; direct-render regression rerun 76/0 and disclosed case failure reproduced"}
  - {reviewer: sol, head: "1290b01fcb", date: 2026-11-05, verdict: approve, open: "confirm: earlier findings addressed, no new finding"}
  - {reviewer: astra, head: "1290b01fcb", date: 2026-11-05, verdict: approve, open: "confirm: earlier findings addressed"}
---

# Build correlated subqueries with the model's Arel table

`build_correlated_subquery` passes the model class to `Arel::SelectManager.new`, which expects a table. On Rails main, calling `to_sql` on that manager raises `NoMethodError`. This passes `arel_table` instead.

Normal searches aren't affected, since they render the subquery through `subquery_sql`.

---
<sub>Found in Lowrail's [Rails-main ecosystem tests](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md#gem-side-leads-not-filed).</sub>
