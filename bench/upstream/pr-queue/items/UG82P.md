---
id: UG82P
repo: rails/rails
kind: docs
area: "Guides: Rails 8.2 upgrade guide, PostgreSQL"
reviewer: "yahonda (#57378)"
branch: thomasklemm/upgrade-guide-pg-fixture-locks
head: "91280311612ae0a1f864e7498824f9de4559b72b"
base: main
built_on: "224f5b1563"
depends_on: []
stacked_on:
alternative_of:
impact: "parallel test workers loading fixtures on PostgreSQL 18.4+ can fail with out of shared memory; the guide doesn't say so or how to size max_locks_per_transaction"
rank: 6
risky: false
state: built
note: "split out of UG82 (#59675) 2026-11-10 at Thomas's request; cherry-picked from cbcac181b3 unchanged (patch-id equal). Planned to open as a draft first, with UG82H, after a Claude Code pass."
passes: []
---

# Note in the upgrade guide that PostgreSQL 18.4+ fixture loading acquires more locks

This adds a section to "Upgrading from Rails 8.1 to Rails 8.2" for a change on main that breaks existing apps and that the guide doesn't mention yet. Loading fixtures on PostgreSQL 18.4+ acquires more locks (#57378), so parallel test workers loading fixtures into databases with a few hundred foreign keys can fail with `out of shared memory`.

---

<sub>Found by running the test suites of Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/c7893f5d5b509a2514303c84459f74bb0499d6fc/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
