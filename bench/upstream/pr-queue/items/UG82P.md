---
id: UG82P
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, PostgreSQL"
reviewer: "yahonda (#57378)"
branch: thomasklemm/upgrade-guide-pg-fixture-locks
head: "7ddc0d8abbc9a368a37bf37edfa6e0a96be9df5d"
base: main
built_on: "224f5b1563"
depends_on: []
stacked_on:
alternative_of:
impact: "parallel test workers loading fixtures on PostgreSQL 18.4+ can fail with out of shared memory; the guide doesn't say so or how to size max_locks_per_transaction"
rank: 6
risky: false
state: draft
pr: 59735
note: "2026-11-14 (claude-code full review): the guide's list of locked objects missed triggers, the largest group; amended 3036f925aa -> 7ddc0d8abb (force-with-lease, same base 224f5b1563, still a draft), body unchanged; needs a Sol confirm on 7ddc0d8abb before ready. 2026-11-10 (Sol): precision fix plus the optional sentence applied, amended 9128031161 -> 3036f925aa (force-with-lease), mdl clean, no trailers. split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from cbcac181b3 unchanged (patch-id equal). Planned to open as a draft first, with UG82H, after a Claude Code pass."
passes:
  - {reviewer: claude-code, head: "91280311612ae0a1f864e7498824f9de4559b72b", date: 2026-11-10, verdict: approve, open: "Reran bench/upstream/app_suites/fk_fixture_locks.rb on main 224f5b1563, PostgreSQL 18.6: one insert_fixtures_set holds 3,310 locks; 8 workers x 3 rounds at default 64: 16 of 24 out of shared memory (server logs the quoted ERROR and HINT; PG::OutOfMemory is SQLSTATE 53200); max_locks_per_transaction = 256 plus restart: 24/24 ok. Ownership/current-schemas wording matches enforced_foreign_keys; truncate_tables and insert_fixtures_set both go through it. Placement in the Active Record group fine. No changes."}
  - {reviewer: sol, head: "91280311612ae0a1f864e7498824f9de4559b72b", date: 2026-11-10, verdict: changes, open: "Wording only, no factual errors. Applied in 3036f925aa: the final sentence says the value depends on the schema, mostly its number of foreign keys, and on the number of workers loading fixtures at once, not suite size (matches fk_fixture_locks.rb and the pg_locks breakdown: trigger and constraint locks per foreign key); the exhaustion sentence reworded as Sol's optional suggestion. Stylistic rewrites skipped; no further round (Thomas)."}
  - {reviewer: claude-code, head: "3036f925aadb66b1c4bcd98a0d34f09a545478da", date: 2026-11-10, verdict: approve, open: "Confirm pass: range-diff against 9128031161 is wording only. The new \"mostly its number of foreign keys\" claim is backed by the recorded pg_locks breakdown (1,200 trigger and 300 constraint locks of about 2,558 for 300 foreign keys), so no rerun; \"intermittent failures such as\" matches the 16/24 run. Body unchanged and accurate. Author/committer Thomas, no trailers, still on 224f5b1563."}
  - {reviewer: sol, head: "3036f925aadb66b1c4bcd98a0d34f09a545478da", date: 2026-11-10, verdict: approve, open: "Confirm on the range-diff: the amend correctly ties intermittent failures to concurrent fixture loading and sizing needs to schema foreign keys and concurrent workers; the revised wording reads clearly and introduces no new unsupported claim."}
  - {reviewer: claude-code, head: "3036f925aadb66b1c4bcd98a0d34f09a545478da", date: 2026-11-14, verdict: changes, open: "Full review against main 50c54eed06, PostgreSQL 18.7 (PGDG), Ruby 4.0.7. Mechanism unchanged since 224f5b1563 (referential_integrity.rb identical; 18_00_04 gate; truncate_tables and insert_fixtures_set still go through disable_referential_integrity; #57378 = 7051ca8a45, not in 8-1-stable). fk_fixture_locks.rb at default 64: one disable_referential_integrity 2,558 locks, one insert_fixtures_set 3,310, 16/24 and 13/24 out of shared memory; max_locks_per_transaction = 256 plus restart: 24/24 ok. Client error is ActiveRecord::StatementInvalid wrapping exactly the quoted PG::OutOfMemory ERROR and HINT lines. Old DISABLE TRIGGER ALL path: 154 locks. Must-fix: after one toggle pg_locks holds 1,200 pg_trigger object locks, 607 index, 456 table and 300 pg_constraint locks; internal triggers 1,200 -> 0 -> 1,200, so drop/recreate holds, but the guide listed only constraints, tables and indexes, omitting triggers (about 47%). Fixed in 7ddc0d8abb by adding triggers to the list. Everything else verified: superuser, ownership/current schemas, lock-table capacity matches the PG 18 docs, restart (postmaster setting). mdl 0.12.0 with .mdlrc clean, diff --check clean. Title and body accurate (the body's shared opening 'breaks existing apps' read as the app's test suite; left consistent with #59675/#59734); record link 200. Merges cleanly with main and with #59675 and #59734 (also stacked); #59675 and #59734 conflict with each other, not with this PR. Worth a maintainer's time: an intermittent CI failure after upgrading, not in the CHANGELOG, a cheap docs fix."}
  - {reviewer: claude-code, head: "7ddc0d8abbc9a368a37bf37edfa6e0a96be9df5d", date: 2026-11-14, verdict: approve, open: "Range-diff against 3036f925aa: one sentence, triggers added to the list of locked objects, rewrapped; matches the pg_locks breakdown above. mdl clean, merges cleanly with main and with #59675 and #59734, Thomas author and committer, no trailers, parent 224f5b1563."}
---

# Note in the upgrade guide that PostgreSQL 18.4+ fixture loading acquires more locks

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. Loading fixtures on PostgreSQL 18.4+ acquires more locks (#57378), so parallel test workers loading fixtures into databases with a few hundred foreign keys can fail with `out of shared memory`.

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c7893f5d5b509a2514303c84459f74bb0499d6fc/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
