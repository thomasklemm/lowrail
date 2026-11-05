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
state: in-review
note: Prepared only; coordinator runs Sol and Astra; one unchanged Rails-main SQLite schema-case failure
passes:
  - {reviewer: skeptic, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: approve, open: "L0; direct-render scope and internal override boundary disclosed"}
---

# Build correlated subqueries with the model's Arel table

Pass the model's Arel table to `Arel::SelectManager.new` when building a correlated subquery. Rails main resolves the SQL connection through that table's `klass`, so passing the model class now raises `NoMethodError` when callers render the returned manager with `to_sql`.

The subquery's FROM table, joins, projections and conditions stay unchanged. Normal search execution already renders through `subquery_sql`; this fixes direct rendering of the manager returned by `Context#build_correlated_subquery`, not search results generally.

On Ruby 4.0.9, all 1,146 PostgreSQL examples pass on Rails main, and all 1,145 SQLite examples pass on Rails 8.1.4. On main, the existing negative-collection file passes all 76 examples; the full SQLite suite retains one unrelated schema-case failure that also fails before this change.

---
<sub>Found in Lowrail's [Rails-main ecosystem tests](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md#gem-side-leads-not-filed).</sub>
