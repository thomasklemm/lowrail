---
id: TO1
repo: rails/rails
kind: perf
area: Action View, tag helper
reviewer: "seanpdoyle"
branch:
head:
base: main
built_on: "a5203b3d4d"
depends_on: [K6]
stacked_on:
alternative_of:
impact: "tag() and void tag.* write their attributes into the tag's own String through a new :nodoc: TagBuilder#append_tag_options: 1 object per tag() with options (*_field_tag, submit_tag, button_to, CSRF and _method inputs)"
rank: 31
risky: false
state: held
pr:
note: "Candidate O of bench/upstream/form_helper_stack (sweep_recommended.patch). Thomas 2026-11-17: remember for later. Build after K6 (#59804) merges, which edits the same line of tag(). An override of TagBuilder#tag_options (:nodoc:) no longer sees tag() calls."
passes: []
---

# Write tag attributes into the tag's own string
