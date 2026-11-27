---
id: HM2
repo: hashie/hashie
fork: thomasklemm/hashie
kind: perf
area: Mash#_method_name_and_suffix (method_missing, DefineAccessors, StrictKeyAccess)
reviewer: dblock
branch: thomasklemm/suffix-name
head: "eae505a846f162e743b65261a7cda01d32e84f85"
base: master
built_on: "9e313f3"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "Candidate 1 of the leads dblock listed after #659 merged (issuecomment-7226612359). Every suffixed Mash method call (private?, owner!, name=) allocates one String fewer. Duel: read keys with suffixes 16 -> 13 objects, write new keys 5 -> 4, overwrite 6 -> 5, CPU same under YJIT and ZJIT. body/HM2 on Ruby 4.0.10: YJIT Callgrind -4.1% (A/A 0.18%) for suffixed reads and -2.3% for a new key; interpreter within A/A for reads, +0.2% for a new key. Local wall: YJIT -4.0% and -3.3%, ZJIT on master within noise and -1.1%. Hashie: 506M downloads; Mash is the API-response object of many clients. Small per call, but dblock asked for it."
evidence: [bench/upstream/hashie_perf, bench/upstream/hashie_perf/body/HM2, bench/upstream/hashie_perf/c1, bench/upstream/hashie_perf/duel]
rank:
risky: false
state: built
pr:
note: "2026-11-27 Astra (T-01a21ea6-c103) must-fix on d1f403e, reproduced: DefineAccessors passed the now-frozen unsuffixed name to a public default_proc, so `default_proc = proc { |h, k| h[k.upcase!] = 7 }; m.missing` raised FrozenError where master returned 7. Fixed as eae505a (amend, force-pushed with lease on d1f403e; fork branch only, no PR): the suffix is found in Symbol#name, the unsuffixed branch returns method_name.to_s as master did. c1_diff.rb extended with mutating default procs on Mash, DefineAccessors and StrictKeyAccess: 10,400 rows identical to master on 4.0.9 and master+ZJIT; the same probe shows 16 differing rows on d1f403e (c1/differential-eae505a.tar.gz). Ruby 4.0.9 rake spec 1,076/0, rubocop clean; suffixed-path allocations unchanged (13/5/5). Body numbers rerun on eae505a: body/HM2-eae505a, c1/wall-4.0.10-yjit-eae505a. Earlier: built on master 9e313f3 as one commit d1f403e (Thomas, no trailers, signed). CHANGELOG line numbered #661 under Changed (#660 is HD2, open); recheck the number before opening. Ruby 4.0.9 rake spec 1,076/0, rubocop 124 + 156 files clean. Differential c1_diff.rb: 8,528 rows identical on 4.0.9 and master+ZJIT. Duel on fork PRs #20 (YJIT) and #23 (YJIT+ZJIT on HD2's workflow): 0 regressed. Candidates 2-4 of dblock's list recorded in bench/upstream/hashie_perf/README.md, not opened. Coordinator: opens ready under the two-approvals rule."
ownership: {date: 2026-11-27, checked: ["open PRs naming _method_name_and_suffix that change CHANGELOG.md, lib/hashie/mash.rb"], hits: []}
passes: []
---

# Read suffixed Mash method names without copying the Symbol

A suffixed method call on a `Mash`, such as `mash.private?`, `mash.owner!` or `mash.name = 'x'`, splits the method name into a key and a suffix. The split started from `Symbol#to_s`, which copies the name on every call.

This looks for the suffix in `Symbol#name` instead, the Symbol's own frozen String, as `_method_suffix` already does since #656. A name without a suffix is still returned as a new String, since `DefineAccessors` can pass it to a default proc that modifies it. Each suffixed call allocates one object fewer, in Duel's allocation counts per iteration:

| Benchmark | master | this branch |
| --- | ---: | ---: |
| Mash: read keys with suffixes | 16 | 13 |
| Mash: write new keys as methods | 5 | 4 |
| Mash: overwrite a key as a method | 6 | 5 |

Duel reports CPU time the same under YJIT and ZJIT. In a local benchmark on Ruby 4.0 with YJIT, the suffixed reads take about 4% less time.
