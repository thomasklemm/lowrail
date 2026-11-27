---
id: TO1
repo: rails/rails
kind: perf
area: Action View, tag helper
reviewer: "seanpdoyle"
branch: thomasklemm/tag-attributes-own-string
head: "7f1f0dce45"
base: main
built_on: "088fc0cf61"
depends_on: [K6]
stacked_on:
alternative_of:
impact: "tag() and void tag.* write their attributes into the tag's own String: 1 object fewer per tag with options (text_field_tag 9 -> 8, submit_tag 14 -> 13, tag.input 6 -> 5, f.check_box 20 -> 18). Callgrind per call, interp / YJIT / ZJIT on master: tag.input -2.2% / -3.8% / -2.0%, text_field_tag -1.1% / -1.6% / -0.9%; f.text_field -0.0% / -0.6% / +0.64% (ZJIT A/A 0.12%); 5-field form_with within noise in every mode. Rails main and Ruby master"
rank: 31
risky: false
state: held
pr:
note: "2026-11-27: rebuilt on main 088fc0cf61 after K6 merged (head 7f1f0dce45, fork branch thomasklemm/tag-attributes-own-string, Thomas, no trailers), and kept held: under ZJIT on Ruby master f3e180b5eb, f.text_field runs 0.64% more instructions (A/A 0.12%, cross-tree noise <= 0.3%), while text_field_tag on the same tag() path runs 0.89% fewer. Nothing explains it, and DECISIONS blocks a ZJIT loss until explained. No form moves outside noise in any mode either, so for rails/rails it is 1 object and about 1-2% per *_tag call. Equivalence: sweep_fuzz 86,726 lines identical, Action View green; only boundary: TagBuilder#tag_options overrides (nodoc) no longer see tag(). Ownership: rails/rails#57999 is about per-attribute strings, which main already appends; no overlap. Not reviewed. Record bench/upstream/revive-2026-11-27. Candidate O of bench/upstream/form_helper_stack (sweep_recommended.patch). Thomas 2026-11-17: remember for later. Build after K6 (#59804) merges, which edits the same line of tag(). An override of TagBuilder#tag_options (:nodoc:) no longer sees tag() calls."
ownership: {date: 2026-11-27, checked: ["open PRs naming tag_options, append_tag_options, self_closing_tag_string, tag that change actionview/lib/action_view/helpers/tag_helper.rb"], hits: ["names tag_options, changes its file (3 open PRs name it): rails/rails#59499 (PR, open, czj): Render `popover: true` as an auto popover in the tag helpers","names tag_options, changes its file (3 open PRs name it): rails/rails#56596 (PR, open, alxgsv): Allow non-boolean values for HTML boolean attributes","names tag_options, changes its file (3 open PRs name it): rails/rails#47163 (PR, open, seanpdoyle): Make `tag.attributes` token-list aware","names self_closing_tag_string, changes its file (1 open PRs name it): rails/rails#51646 (PR, open, ahukkanen): Remove trailing slash from void HTML elements","names tag, changes its file (124 open PRs name it): rails/rails#57999 (PR, open, ikraamg): Avoid intermediate strings for tag attributes","names tag, changes its file (124 open PRs name it): rails/rails#47159 (PR, open, seanpdoyle): `tag.attributes` accept variable number of `Hash`","names tag, changes its file (124 open PRs name it): rails/rails#54042 (PR, open, naofumi): Tag helper buffer for nested elements with multiple children","names tag, changes its file (124 open PRs name it): rails/rails#49377 (PR, open, seanpdoyle): Action View: Remove internal calls to `tag` with positional arguments","names tag, changes its file (124 open PRs name it): rails/rails#45236 (PR, open, amartinfraguas): Fix regression in XSS filtering of HTML characters"]}
evidence: ['bench/upstream/revive-2026-11-27/README.md', 'bench/upstream/revive-2026-11-27/results/']
passes: []
---

# Write tag attributes into the tag's own string
