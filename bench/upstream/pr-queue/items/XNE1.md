---
id: XNE1
repo: rails/rails
kind: perf
area: Active Support, ERB::Util.xml_name_escape (tag attribute keys)
reviewer: amatsuda
branch:
head:
base: main
built_on: "521bd1cf3f"
tracker: [rails/rails#59117]
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/hotline_candidates/README.md, bench/upstream/hotline_candidates/xne_probe-4.0.9.txt]
impact: "Nothing left on Rails main: the one Rails caller, TagBuilder#append_tag_option, already passes Symbol#name since 49580d1d04 (merged 2026-10-16, unreleased), so xml_name_escape's name.to_s allocates 0 objects in tag rendering on main (8.1.4: 30 Strings over 10 tag.div calls with 3 Symbol keys, 0 on main). Reach on 8.1: 16 of 18 census apps, 0.22% of request objects on average (Sure 0.86%, 1,132 objects per request that runs it); that goes away with 8.2 without a change of ours. Direct Symbol callers outside Rails: none in the census apps or in GitHub code search."
rank:
risky: false
state: superseded
pr:
note: "2026-11-26: not built. Lead from bench/upstream/profile_hotlines_census (Suggested items 1), whose captures ran Rails 8.1.x, where tag_option passed the Symbol key to xml_name_escape. On main 521bd1cf3f, amatsuda's rails/rails#59117 (49580d1d04, 'Append tag attributes without a string per attribute') reads Symbol keys with Symbol#name before the escape, and append_prefix_tag_option builds a String key, so xml_name_escape only ever gets a String from Rails and name.to_s returns it. Changing xml_name_escape itself to Symbol#name would save 0 objects per request on main and would hand external Symbol callers a frozen String instead of a fresh one (a public method; a caller that appends to the result would raise FrozenError). Callers: Rails main has one (actionview tag_helper.rb:1641); the 17 census app repositories have none (gh code search, 2026-11-26); global code search finds no outside caller of ERB::Util.xml_name_escape at all: the other hits are vendored Rails copies or own reimplementations (roundhouse, ree, eskimo, zigapagos). rails/rails PRs naming xml_name_escape: #45836 and #45845 (iancanderson, 2022, merged: allocation and fast-path work); open PRs on tag_option(s): #57999 (ikraamg; its single attribute buffer is on main through #59117, docs/upstream/actionview-cpu.md), #52365, #59499, #56596, #47163, none touching xml_name_escape; issues naming it: none. No request-level lowrail bench run: there is no change to measure on main. DECISIONS bar (moves whole requests, room under the cap): not met, nothing to open."
ownership: {date: 2026-11-26, checked: ["rails/rails#59117 and what references it", "rails/rails PRs and issues naming xml_name_escape, open and closed", "open rails/rails PRs naming tag_option or tag_options", "git log of activesupport/lib/active_support/core_ext/erb/util.rb and of append_tag_option", "callers in Rails main and in the 17 census app repositories"], hits: ["tracker: rails/rails#59117 (merged): Append tag attributes without a string per attribute"]}
passes: []
---

# Read Symbol attribute keys with Symbol#name in xml_name_escape

Not posted; superseded on main by rails/rails#59117 before a branch was built.

## For Thomas

On Rails 8.1, every Symbol attribute key in `tag.div(class: …)` goes through `xml_name_escape`, whose first line
`name.to_s` copies the Symbol into a new String. Akira's merged rewrite of the tag attribute code on main already
converts the key with `Symbol#name` (a shared frozen String) before it calls the escape, so on main that line
copies nothing. Apps get it with Rails 8.2; there is nothing left for us to change.
