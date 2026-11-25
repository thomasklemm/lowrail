---
id: CC1
repo: CanCanCommunity/cancancan
fork: thomasklemm/cancancan
kind: perf
area: Rule#initialize, Ability#add_rule_to_index
reviewer: coorasse
branch: thomasklemm/rule-construction-allocations
head: "2a5e8c71d19569d43c7fec09dfb7012721f792e2"
base: main
built_on: "021b13cf76"
depends_on: []
stacked_on:
alternative_of:
impact: "Every can/cannot allocates two objects fewer: an ability of six rules built per request goes from 57 to 47 objects on Ruby 4.0 (62 to 52 on 3.3), -2.9% instructions (interpreter) and -4.4% (YJIT, JIT-flat); Rule construction is 1.8% of request objects in Solidus's API suite and 0.9% in openstreetmap-website's"
rank:
risky: false
state: built
pr:
note: "2026-11-25 (oss-profile-sweep-1): found by lowrail-profile on Solidus and openstreetmap-website (docs/upstream/oss-profile-sweep-1.md). Ownership: no open PR in CanCanCommunity/cancancan; merged #920/#887 (can? speed-up) and #843/#798 (rule compression) do not touch parse_attributes_from_extra_args or subjects.compact; the 4.x branch has the same two lines; not in the queue or the bundled ledger. Built on main 021b13cf76 (3.7.1): DB=sqlite rspec 716 examples, 0 failures, 3 pending on Ruby 3.4.13 / AR 8.1 and Ruby 3.3.14 / AR 7.2, as on main; rubocop 60 files, no offenses. 20 can/cannot shapes x can/cannot x block (80 cases) give the same actions, subjects, attributes, conditions, block, match_all and rules index on main and branch (orb backup sweep/cancan/diff.rb). Not run: DB=postgres (the spec helper's fixed password differs from this orb's). Body numbers: script/upstream-bench, bench/upstream/oss_profile_sweep_1/body/CC1, A/A 0.02% / 0.08%, JIT-flat in 6 windows. Applies to 4.x with the same change if the maintainer wants it there. No pass yet."
passes: []
---

# Allocate less when a rule is defined

An ability is usually built per request, so each `can` and `cannot` runs on every request. Two of the objects a rule allocates are not needed:

* `Rule#initialize` took the attributes and conditions from the two-element array that `parse_attributes_from_extra_args` returned;
* `add_rule_to_index` copied the subjects with `compact` even when none is `nil`.

The rules, their attributes and conditions, and the index they build are unchanged.

An ability with six rules (a class rule, an action list with conditions, `:manage, :all`, a `cannot`, attributes with conditions and a block rule), Ruby 4.0.9:

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| no JIT | 57 | 47 | 82,787 | 80,391 | −2.9% |
| YJIT | 57 | 47 | 42,893 | 40,991 | −4.4% |

## For Thomas

Seen in Solidus's API suite (Spree::Api::BaseController#current_ability, 929 warm objects per request below it, cancancan lines 1-3 of its top lines outside the app) and in openstreetmap-website's. The bigger cost there is the apps' own rule count; this only trims cancancan's per-rule overhead.
