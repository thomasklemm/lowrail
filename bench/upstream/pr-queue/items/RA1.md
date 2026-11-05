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
  - {reviewer: sol, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: nits, open: "Body needs Rails pin, arel_table override boundary, commands and exact regression/failure names"}
  - {reviewer: astra, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: nits, open: "Same body clarifications; code unchanged"}
  - {reviewer: skeptic, head: "1290b01fcb9a78717365968c791e75fa28a1016d", date: 2026-11-05, verdict: approve, open: "Revised body approved; direct-render regression rerun 76/0 and disclosed case failure reproduced"}
---

# Build correlated subqueries with the model's Arel table

Pass the model's Arel table to `Arel::SelectManager.new` when building a correlated subquery. On Ruby 4.0.9 with Rails main at `1e235cee11b0a7aecb189d8837534807626287aa`, direct `to_sql` resolves the connection through the table's `klass`; passing the model class raises `NoMethodError`.

FROM, joins, projections and conditions stay unchanged. This fixes direct rendering of `Context#build_correlated_subquery`'s manager, not normal searches, which already render through `subquery_sql`. An override of the undocumented association `base_klass` must now return an object with `arel_table`; overriding the model's `arel_table` also affects this path.

`RAILS=/path/to/rails-main bundle exec rake spec` with `DB=pg DATABASE_USERNAME=user DATABASE_HOST=/var/run/postgresql` passes 1,146 examples; SQLite with Rails 8.1.4 passes 1,145. On main, `bundle exec rspec spec/ransack/active_record/negative_collection_spec.rb` with the same `RAILS` pin passes 76 examples, including `keeps the subquery buildable after an evaluation`, which directly calls `to_sql`.

The full main SQLite suite retains one unchanged failure: `context_spec.rb:80`, `a table whose name differs only in case / can be searched like Active Record queries it` (the `Widgets`/`widgets` schema-cache case).

---
<sub>Found in Lowrail's [Rails-main ecosystem tests](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md#gem-side-leads-not-filed).</sub>
