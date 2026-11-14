---
id: DATE199
repo: ruby/date
kind: fix
area: Date#<=>
reviewer:
branch: thomasklemm/cmp-nan
head: "f1d893f8348fa31153ec625776d81edced301c15"
base: master
built_on: "7afe30c0a6556c377107b7a501b20594230006c6"
depends_on: []
stacked_on:
alternative_of:
impact:
rank:
risky: false
state: ready
pr: 199
note: "Opened before the queue tracked it; item added 2026-11-14 so status watches it. built_on is the merge base GitHub reports for head. Passes and record: docs/upstream/contributions.md."
passes: []
---

# Return nil from Date#<=> for a NaN
