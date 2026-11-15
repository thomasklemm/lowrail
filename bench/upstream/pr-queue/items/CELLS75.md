---
id: CELLS75
repo: trailblazer/cells-rails
kind: fix
area: Rails 8.2 helpers
reviewer:
branch: thomasklemm/navigation-helper
head: "6ba587cce668bb823022cd1416ee9a9c48152e68"
base: master
built_on: "77ff22ae8f94472cf477672ca2f0c86757d627d8"
depends_on: []
stacked_on:
alternative_of:
impact:
rank:
risky: false
state: ready
pr: 75
note: "Opened before the queue tracked it; item added 2026-11-14 so status watches it. built_on is the merge base GitHub reports for head. Passes and record: docs/upstream/contributions.md."
passes:
  - {reviewer: claude-code, head: "6ba587cce668bb823022cd1416ee9a9c48152e68", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: nits, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Clause backed by app-suites.md DC2. Nit applied: 'as Decidim's cells do' -> 'as its cells do'."}
---

# Include NavigationHelper in cells on Rails 8.2
