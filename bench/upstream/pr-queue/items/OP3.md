---
id: OP3
repo: rails/rails
kind: restore
area:
reviewer:
branch: thomasklemm/validation-context-writer
head: "0ba3dad80b"
base: main
built_on:
depends_on: []
stacked_on:
alternative_of:
impact: see docs/upstream/contributions.md
rank:
risky: false
state: ready
pr: 59660
note: opened 2026-11-05
passes:
  - {reviewer: skeptic, head: "0ba3dad80b", date: 2026-11-05, verdict: nits, open: nits applied}
  - {reviewer: sol, head: "0ba3dad80b", date: 2026-11-05, verdict: approve, open: "body claim dropped, privacy assert added"}
---

# Restore the private `validation_context=` writer
