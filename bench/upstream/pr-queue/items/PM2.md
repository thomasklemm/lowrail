---
id: PM2
repo: rails/rails
kind: perf
area: Action View tag helper
reviewer: unknown
branch: thomasklemm/tag-options-blank-once
head: "2dc1231b26"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: "-2.2% Ir per tag call with String keys; railsbench tag_options -6.4M Ir per iteration"
rank: 12
risky: false
state: held
pr:
note: "fix first (Sol 20:09): not exact for a frozen String with singleton blank?, to_s or equal?; smallest exact fix drops the shortcut; perf method not reproducible from the body; P2 is on it"
passes:
  - {reviewer: sol, head: "02f567ab81", date: 2026-11-05, verdict: changes, open: "skipped key.blank? and Symbol#blank?; rewritten"}
  - {reviewer: skeptic, head: "2dc1231b26", date: 2026-11-05, verdict: approve, open: "third pass on the final version: ship"}
  - {reviewer: sol, head: "2dc1231b26", date: 2026-11-05, verdict: changes, open: "20:09: not exact; don't open in this form"}
---

# Skip the second blank check when a tag attribute's name is its key

Since [99a3247ebc](https://github.com/rails/rails/commit/99a3247ebc02de86c5fdc9a5fd7c1ce0143c5d14), `tag_options` checks [the raw key with `blank?` and then the name it converts the key to](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/actionview/lib/action_view/helpers/tag_helper.rb#L1548-L1551). A plain String's `to_s` returns the String itself, so for String keys the second check asks the same object the same question.

This keeps both checks in the same order and skips the second only when `to_s` returned the key itself. Symbol keys, keys with a singleton `to_s`, String subclasses and nested `data`/`aria` keys are checked as before. The new tests cover whitespace String keys and String keys whose `blank?` or `to_s` differs from a plain String's. A comparison of 48 kinds of keys, each with 9 values, renders the same markup and raises the same errors as main.

Callgrind instructions per call, Ruby 4.0.9 interpreter, in the railsbench app (main against itself within 0.1%):

| | main | this PR |
| --- | ---: | ---: |
| `content_tag` with String keys | 59,411 | 58,104 (−2.2%) |
| `tag.a` with Symbol keys | 57,596 | 57,484 (−0.2%) |

`link_to` stringifies its html options, so in railsbench `tag_options` runs 6.4M fewer instructions per iteration (A/A 0.38M). 8-1-stable has the same double check ([9190210606](https://github.com/rails/rails/commit/9190210606ffe52f92fdc75637f8ff69404f22c8)).

---
<sub>Found by comparing Rails 8.1.1 and 8.1.4.1 on ruby-bench with Callgrind ([record](https://github.com/thomasklemm/lowrail/blob/d08c2967ba89b663180133ebbe97e873f3746c8a/docs/upstream/perf-round-main.md), part of my research project Lowrail).</sub>
