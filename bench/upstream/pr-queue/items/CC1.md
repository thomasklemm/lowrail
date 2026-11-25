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
evidence: [bench/upstream/oss_profile_sweep_1/body/CC1, bench/upstream/oss_profile_sweep_1/cancancan/CC1-thermos-sol.tar.gz]
rank:
risky: false
state: in-review
pr:
note: "2026-11-25 thermos-sol: changes on the recorded head; attribute conversion runs too early and the index loses compact's detached snapshot (five demonstrated differences). Both base and head pass sqlite/postgres on Ruby 3.3.14 / AR 7.2.4 and 3.4.13 / AR 8.1.4.1, with identical per-example outcomes. Missing regression specs and CHANGELOG; body and commit call a five-rule measurement six rules and assert false equivalence. Smallest repair and exact wording below. Nothing upstream. Original build record: found by lowrail-profile on Solidus and openstreetmap-website (docs/upstream/oss-profile-sweep-1.md), built on main 021b13cf76 (3.7.1); 80 ordinary construction cases matched; sqlite passed on Ruby 3.4.13 / AR 8.1 and 3.3.14 / AR 7.2; builder did not run postgres. Body evidence has A/A 0.02% / 0.08% and JIT-flat in 6 windows. The impact and draft body below are the reviewed, uncorrected claims, not approved claims."
ownership: {date: 2026-11-25, checked: ["open PRs naming add_rule_to_index, initialize, parse_attributes_from_extra_args that change lib/cancan/ability/rules.rb, lib/cancan/rule.rb"], hits: []}
passes:
  - {reviewer: thermos-sol, head: "2a5e8c71d19569d43c7fec09dfb7012721f792e2", date: 2026-11-25, orb: "T-01a214c3-c62d-7481-8ea4-cb7c4ef33065", verdict: changes, open: "F1 conversion order; F2 lost index snapshot/new callbacks; F3 CHANGELOG; F4 body/commit/benchmark corrections. Both Thermos rubrics run directly by this reviewer, without subagents or other threads, as requested. Full report below."}
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

### Thermos-sol review, 2026-11-25 — changes

Reviewed fork head `2a5e8c71d19569d43c7fec09dfb7012721f792e2` against upstream main
`021b13cf762ba95784bf00a467c0ce86120fdf12` (3.7.1), in orb
`T-01a214c3-c62d-7481-8ea4-cb7c4ef33065`. Both correctness/security and maintainability rubrics were applied
by this reviewer in this thread; no independent second reviewer is claimed. The fork branch still points to that
head and upstream main still points to that base. No upstream PR, comment, push or other write was made.

#### F1 — must fix: preserve attribute-conversion order (P2)

`lib/cancan/rule.rb:25` moves `wrap(attributes)` before validation, action normalization and subject wrapping.
That calls a caller-provided attributes Array's `to_ary` earlier. This changes actual permissions, not just an
internal call count. With `Product` any ordinary class:

```ruby
ability = Object.new.extend(CanCan::Ability)
actions = [:read]
attributes = [:name]
attributes.define_singleton_method(:to_ary) { actions.replace([:destroy]); self }
ability.can(actions, Product, attributes)
[ability.can?(:read, Product), ability.can?(:destroy, Product)]
# base: [true, false]; head: [false, true]
```

It also changes an invalid hash-plus-block definition from `CanCan::BlockAndConditionsError` to an exception from
the attributes conversion, if `to_ary` raises. These are public argument overrides, not overrides of Rule's private
methods. Smallest fix: set `attributes = extra_args.shift if valid_attribute_param?(extra_args.first)` at line 25,
keep `extra_args = extra_args.shift`, and put `@attributes = wrap(attributes)` back immediately after
`@subjects = wrap(subject)`. This still eliminates the temporary pair without changing evaluation order. Keep one
public `can`/`can?` regression spec using the asymmetric read/destroy mutation above; no allocation assertion.

#### F2 — must fix: retain the index's detached subjects snapshot (P2)

`lib/cancan/ability/rules.rb:24-27` adds `subject == nil` callbacks through `include?` and sometimes iterates the
caller's Array directly. Base's `compact` produces a plain, detached Array even when nothing is nil. Three
separate public-API differential probes demonstrate the consequences on both Rubies:

* A subject class whose singleton `==` raises for nil builds a rule and authorizes its instance on base; head
  raises `RuntimeError: nil equality` during `can`.
* An Array subclass whose `each` omits Product but whose stored elements are `[Product, Order]` authorizes both
  classes on base and only Order on head. `compact` previously removed that iteration override.
* A subject class's `hash` appends Order to the ordinary subjects Array `[subject_class]` during indexing.
  Base keeps Order out of the index and `can?(:read, Order)` is false; head visits the appended element,
  indexes Order and returns true. This is the lost-copy case, without a private override or ObjectSpace.

Smallest safe fix: restore the two original lines:

```ruby
subjects = rule.subjects.compact
subjects << :all if subjects.empty?
```

Do not replace this with `compact!` on the rule/caller array or add a core-class-only guard: singleton methods
and mutation during hashing remain possible. Keep a public authorization regression spec for mutation during
hashing, and one for the newly introduced equality callback if the index optimization is attempted again.
The exact executable probes and proposed repair are in the receipts archive.

This is not a new post-return aliasing bug: base and head both retain the caller's subjects and attributes Arrays
and conditions Hash in the Rule, and both copy/normalize the actions Array. Ordinary caller mutation **after**
`can` returns, including a shared action/attribute Array, matched. The missing copy is the temporary snapshot
used **while** constructing the index.

#### F3 — must fix: follow the contribution rules

`CONTRIBUTING.md`, "Adding new Features or Bugfixes", requires a CHANGELOG entry and test coverage. Head changes
only the two library files. Add a new unreleased section above 3.7.1 (do not amend a released section), with this
entry for the reduced, safe parser-only change:

```markdown
## Unreleased

* Avoid a temporary array when parsing rule attributes and conditions. ([@thomasklemm][])
```

Add `[@thomasklemm]: https://github.com/thomasklemm` to the contributor definitions if absent. The existing
changelog spec checks contributor references and punctuation. Add the behavioral regressions described in F1/F2,
not object-count or private-helper expectations.

#### F4 — must fix: correct the body, commit and measurement claims

Sentence-by-sentence body check against DECISIONS' PR-description rules:

| Draft text | Verdict / smallest correction |
| --- | --- |
| Title, "Allocate less when a rule is defined" | Plain, accurate title for the intended change; keep. |
| "An ability is usually built per request, so each `can` and `cannot` runs on every request." | Overstates conditional rules and reused abilities. Replace with "Applications that build an ability per request pay the cost of defining its rules each time." |
| "Two of the objects a rule allocates are not needed:" | False in general: the subjects snapshot has observable semantics, and nil-containing/empty subjects do not save this allocation. After F1/F2, replace with "`Rule#initialize` returns the parsed attributes and conditions in a temporary two-element array, then immediately unpacks it." |
| First bullet, pair returned by `parse_attributes_from_extra_args` | Verified in base, but fold into the previous sentence; no bullet list is needed. |
| Second bullet, `compact` copies even without nil | Literally true, but that copy is needed for F2; cut the bullet and the optimization. |
| "The rules, their attributes and conditions, and the index they build are unchanged." | False on this head (F1/F2). After the fixes, replace with "Read those arguments directly instead, keeping validation and conversion in their existing order." |
| "An ability with six rules (... `:manage, :all` ...)" | False: the committed benchmark calls `Ability.new(1)`, and `can :manage, :all if user == 0` never executes. Replace with "An ability defining five rules (a class rule, an action list with conditions, a `cannot`, attributes with conditions and a block rule), Ruby 4.0.9:" if keeping this workload. |
| Object / instruction table | The numbers agree with the committed raw record for **five** rules, not six. Independently replayed 57 → 47 objects on Ruby 4.0.9, interpreter and YJIT. Instructions are not time; use a measurement caption saying "Objects and Callgrind instructions per ability, Ruby 4.0.9", not an unlabeled table. Remeasure every cell on the repaired head rather than carrying these numbers forward. |

The entire opening can be replaced, after F1/F2, with these two short paragraphs:

> Applications that build an ability per request pay the cost of defining its rules each time.
> `Rule#initialize` returns the parsed attributes and conditions in a temporary two-element array, then
> immediately unpacks it.
>
> Read those arguments directly instead, keeping validation and conversion in their existing order.
> For an ability with a class rule, an action list with conditions, a `cannot`, attributes with conditions
> and a block rule, this removes one temporary array per rule.

Then provide a small benchmark-ips (or benchmark-driver) script and before/after output, as DECISIONS requires
for gem performance bodies. The existing `results.json` has `"ips": {}`: there is no wall-time evidence to lead
with. Retain only a supporting allocation table if it adds information; keep A/A, other Rubies, suite counts,
commands, pins, review history and this report out of the upstream body. The one Ruby version identifying the
measurement is appropriate. No Lowrail footer or link is present; keep it that way. There is no need for more
prose to explain the rejected index optimization upstream.

The commit message has the same five-versus-six and false-equivalence defects: its mechanism sentences are
verified, but "every can and cannot paid both", "10 of 62 objects for six rules", "the same 10 of 57" as a
six-rule claim, and the final unchanged-index assertion are not acceptable as written. After applying F1/F2,
replace the message with:

```text
Allocate less when a rule is defined

Read the optional attributes and conditions directly in Rule#initialize instead
of returning them in a temporary pair. Keep validation and the wrapping of
actions, subjects and attributes in their original order.

The subjects copy used while building the index is still needed: hashing a
subject can change the caller's array during iteration.
```

Correct `impact` and the benchmark's misleading comments at the same time: say five rules, and do not claim two
objects saved for every rule shape. If six rules including `:manage, :all` are desired instead, actually invoke
that branch and make a fresh measurement. The scratch parser-only repair allocates 52 rather than 47 objects on
the existing five-rule Ruby 4.0.9 workload; that is a diagnostic check, not evidence for an unpublished new head.
The existing instructions and percentages cannot certify that repair.

#### Executed checks and test strength

On **both base and exact head**, `DB=sqlite bundle exec rspec --seed 1234` and
`DB=postgres PGPORT=55432 bundle exec rspec --seed 1234`:

| Ruby / Active Record | SQLite | PostgreSQL 17 |
| --- | --- | --- |
| 3.3.14 / 7.2.4 | 716 examples, 0 failures, 3 pending | 716 examples, 0 failures, 2 pending |
| 3.4.13 / 8.1.4.1 | 716 examples, 0 failures, 3 pending | 716 examples, 0 failures, 2 pending |

Compared JSON results by example ID, status, pending message and exception class/message: identical within each
base/head cell, not just equal totals. All cells use seed 1234 and byte-identical dependency locks per pair.
PostgreSQL uses a disposable UTF-8, local trust-authenticated cluster, so the helper's fixed password requires
no source change. An initial SQL_ASCII template error was diagnosed and the cluster reinitialized as UTF-8 before
these successful runs. An attempted Ruby 4.0 suite load encountered a pre-existing missing bundled `ostruct`; the required
newer matrix was instead completed on the upstream-supported Ruby 3.4, without patching either tested tree.

`differential.rb` checks 30 shapes × can/cannot × block/no block = 120 cases, plus 7 mutation/override probes,
on Ruby 3.3/AR 7.2 and 3.4/AR 8.1. It records rule fields, match_all, index, public `can?`, `accessible_by` and
permissions, including Hash/scope/SQL/block conditions, aliases, `:all`, duplicate/empty/nil-bearing subject
Arrays, attributes versus String conditions, frozen arguments, ordinary later mutation and shared Arrays.
Five differences are the F1/F2 probes above; all other cases agree. Applying only the proposed repair in a
disposable worktree makes **all 127 cases** agree with base on both Rubies, and the Ruby 3.3/SQLite full suite
still passes (716/0/3). This does not approve a changed upstream head; it validates the suggested repair.

The suite catches simple wrong implementations: dropping all conditions fails 21 of 110 Ability examples;
omitting empty-subject rules from the index fails 2 of 110. Both mutants were executed through the public suite.
But unchanged head passes despite F1/F2, and the builder's original 80 shapes also miss them: conversion order,
new equality calls and snapshot ownership need the regression coverage requested above.

`bundle exec rubocop --format simple` on head: 64 files inspected, no offenses, exit 0; four existing
rubocop-ast deprecation warnings print stacks. A focused run on the two changed files also reports 0 offenses.
No added code comments exist, so there is no new-comment blocker. Removing the private parsing helper is not a
compatibility finding; overrides of private/nodoc methods are outside the adopted exactness boundary.

#### Maintainability rubric and worst-input check

Cold read: the initializer takes optional attributes, then conditions, validates, normalizes actions, wraps
subjects and attributes, and stores the conditions and block. The index branch scans for nil to choose between
compacting subjects and reusing them, substitutes `:all` for an empty list, then appends the rule position under
each subject. That new reuse condition is the unsafe assumption, not a missing abstraction. The clean solution
is to drop it, not add guard machinery. The current index optimization is L1; the proposed parser-only repair is
L0. The helper removal earns its keep; no larger refactor, new helper or decomposition is warranted. Rule shrinks
141 → 135 lines; Rules stays 123. No file-size or architecture-boundary concern.

Metrics are signals, not the basis of rejection (flog 4.10.0; RuboCop 1.31.2, zero thresholds to expose values):

| Method | flog, base → head | ABC | Cyclomatic | Perceived |
| --- | --- | --- | --- | --- |
| Rule#initialize | 17.5 → 20.1 | 14.35 → 16.4 | 6 → 7 | 6 → 7 |
| Rule#parse_attributes_from_extra_args | 5.3 → removed | 4.58 → removed | 2 → removed | 2 → removed |
| Ability::Rules#add_rule_to_index | 8.4 → 11.2 | 9.8 → 12.25 | 5 → 6 | 5 → 6 |

Inlining accounts for the initializer's local rise and reduces total helper indirection. The index rise buys a
second possible scan and an ownership-sensitive branch; F2 makes that tradeoff unacceptable.

Constructed a slow input for that new scan: repeated Symbol subjects, with nil absent, first or last, at
1, 10, 1,000 and 150,000 entries (last Array's slots exceed 1 MB). Ran base/head/base on Ruby 4.0.9 without JIT,
pinned to core 1, best of 3 per row. Diagnostic wall-time ratios: 1,000/no-nil head +13.9% (A/A 0.72%);
150,000/no-nil +11.0% (A/A 1.66%); 150,000/late-nil +7.5% (A/A 0.38%). Small rows are noisy. These are
non-fixed-heap stress diagnostics, not gated speed claims or realistic upstream table rows. They reinforce
removing the extra scan; the proposed safe repair removes it. Raw samples are retained, not rerun until green.

#### Ownership, evidence and limits

After the independent code audit, `script/ownership CC1` checked open PRs naming `add_rule_to_index`,
`initialize`, and `parse_attributes_from_extra_args` in the changed files: no hits. Direct GitHub REST lists
for open PRs and open issues both return `[]`, and repository metadata reports `open_issues_count: 0`.
GitHub search rejects the repository query with HTTP 422, so the direct complete lists, not that failed
search, establish there is no current owner. This is longstanding allocation work, not one introducing
regression PR; no `introduced_by` or tracker is invented. Main and 4.x both still contain the original pair
parser and `compact` copy; 4.x has additional differences, so backport equivalence is not certified here.
The contributor guide requires main for compatible changes, CHANGELOG and tests; the repo's workflow runs
both databases and RuboCop. No open candidate PR exists whose review discussion needs reconciling.

The original committed body record has matching full pins, A/A 0.02% interpreter / 0.08% YJIT and unchanged
compile/invalidation counters in all six YJIT instruction windows. Its raw arithmetic and rounded body cells
were checked; object counts were independently rerun. The Callgrind instruction cohort was **not rerun** in
this orb, so this is a record audit, not an independent instruction replication. No whole-request speedup,
Ruby master run, exploit, or exhaustive Ruby-object compatibility is claimed.

Receipts: `bench/upstream/oss_profile_sweep_1/cancancan/CC1-thermos-sol.tar.gz` contains the differential harness
and outputs, per-example suite JSON/logs and locks, mutant scripts/results, proposed repair/diff check,
metrics, ownership lists, allocation replays and stress samples. The original body numbers remain in
`bench/upstream/oss_profile_sweep_1/body/CC1`. Verdict remains **changes** until the branch is repaired,
regression specs and CHANGELOG are added, claims are remeasured/reworded, and the new exact head is reviewed.
