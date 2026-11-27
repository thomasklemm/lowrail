---
id: HM5
repo: hashie/hashie
fork: thomasklemm/hashie
kind: perf
area: Hashie::Hash#to_hash (Mash#to_hash, Mash#to_json)
reviewer: dblock
branch: thomasklemm/to-hash-read-once
head: "e10dce085d72226edf869eb871c9fda74cd8fe31"
base: master
built_on: "9e313f3"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "Mash#to_hash and Mash#to_json (which calls it) read every value once instead of twice; in a Mash each read converts the key and checks for a default proc. Reach: every Mash that is serialized again, e.g. OmniAuth's AuthHash and InfoHash#to_hash (omniauth 235M downloads) and any API response passed on as JSON. Duel on Ruby 4.0.10, Mash#to_hash of the nested fixture: CPU 0.862 [0.858, 0.866] under YJIT and 0.687 [0.682, 0.694] under ZJIT, both faster, allocations unchanged (10), nothing regressed."
evidence: [bench/upstream/hashie_perf/round2, bench/upstream/hashie_perf/round2/duel, bench/upstream/hashie_perf/round2/to_hash]
rank: 3
risky: false
state: built
pr:
note: "2026-11-27 built on master 9e313f3 as one commit e10dce0 (Thomas, no trailers, signed). Ruby 4.0.10 rake spec 1,076/0, rubocop clean, docs:examples 359/0; Ruby 3.0.7 1,072/0 and 3.4.7 1,076/0. Differential probes/to_hash_diff.rb: 2,340 rows identical between master and the branch on 4.0.10 and master+ZJIT; the two expected differences are recorded by the probe: a subclass's [] is called once per key instead of twice, and a [] that alternates its result between calls no longer mixes two results. Duel on fork PR #29 (run 46068675920, lib of 39db98d, same tree as e10dce0 apart from the commit message). CHANGELOG line numbered #664; renumber before opening. Queued behind HM3 and HM4: at most two new hashie PRs at a time."
ownership: {date: 2026-11-27, checked: ["open PRs naming to_hash that change CHANGELOG.md, lib/hashie/hash.rb"], hits: []}
passes: []
---

# Read each value once in Hashie::Hash#to_hash

`Hashie::Hash#to_hash` reads every value twice through `self[k]`: once to see whether it is an Array, and again to convert it. In a Mash each read converts the key and looks for a default proc, so `to_hash`, and `to_json`, which calls it, did that work twice per key.

This reads the value once and converts what was read. A subclass that overrides `[]` now sees one read per key instead of two. Duel's "Mash#to_hash: a nested Mash" on Ruby 4.0, CPU time relative to master:

| | this branch |
| --- | ---: |
| YJIT | 0.86 |
| ZJIT | 0.69 |

Allocations are unchanged.
