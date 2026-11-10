---
id: UG82P
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, PostgreSQL"
reviewer: "yahonda (#57378)"
branch: thomasklemm/upgrade-guide-pg-fixture-locks
head: "3036f925aadb66b1c4bcd98a0d34f09a545478da"
base: main
built_on: "224f5b1563"
depends_on: []
stacked_on:
alternative_of:
impact: "parallel test workers loading fixtures on PostgreSQL 18.4+ can fail with out of shared memory; the guide doesn't say so or how to size max_locks_per_transaction"
rank: 6
risky: false
state: built
pr:
note: "2026-11-10 (Sol): precision fix plus the optional sentence applied, amended 9128031161 -> 3036f925aa (force-with-lease), mdl clean, no trailers. split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from cbcac181b3 unchanged (patch-id equal). Planned to open as a draft first, with UG82H, after a Claude Code pass."
passes:
  - {reviewer: claude-code, head: "91280311612ae0a1f864e7498824f9de4559b72b", date: 2026-11-10, verdict: approve, open: "Reran bench/upstream/app_suites/fk_fixture_locks.rb on main 224f5b1563, PostgreSQL 18.6: one insert_fixtures_set holds 3,310 locks; 8 workers x 3 rounds at default 64: 16 of 24 out of shared memory (server logs the quoted ERROR and HINT; PG::OutOfMemory is SQLSTATE 53200); max_locks_per_transaction = 256 plus restart: 24/24 ok. Ownership/current-schemas wording matches enforced_foreign_keys; truncate_tables and insert_fixtures_set both go through it. Placement in the Active Record group fine. No changes."}
  - {reviewer: sol, head: "91280311612ae0a1f864e7498824f9de4559b72b", date: 2026-11-10, verdict: changes, open: "Wording only, no factual errors. Applied in 3036f925aa: the final sentence says the value depends on the schema, mostly its number of foreign keys, and on the number of workers loading fixtures at once, not suite size (matches fk_fixture_locks.rb and the pg_locks breakdown: trigger and constraint locks per foreign key); the exhaustion sentence reworded as Sol's optional suggestion. Stylistic rewrites skipped; no further round (Thomas)."}
---

# Note in the upgrade guide that PostgreSQL 18.4+ fixture loading acquires more locks

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. Loading fixtures on PostgreSQL 18.4+ acquires more locks (#57378), so parallel test workers loading fixtures into databases with a few hundred foreign keys can fail with `out of shared memory`.

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c7893f5d5b509a2514303c84459f74bb0499d6fc/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
