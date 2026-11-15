---
id: DS1
repo: discourse/discourse
kind: fix
area: "chat plugin, Category associations"
reviewer:
branch: thomasklemm/category-channels-association
head: "75526aa95c"
base: main
built_on:
depends_on: []
stacked_on:
alternative_of:
impact: see docs/upstream/contributions.md
rank:
risky: false
state: ready
pr: 45658
note: opened 2026-11-05; the Queue table still listed it as blocked on the CLA
passes:
  - {reviewer: claude-code, head: "75526aa95c", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: approve, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Added clause backed by app-suites.md DS1."}
---

# FIX: Scope Category#category_channels to the category's channels
