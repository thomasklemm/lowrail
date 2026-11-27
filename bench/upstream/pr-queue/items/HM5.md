---
id: HM5
repo: hashie/hashie
fork: thomasklemm/hashie
kind: perf
area: Hashie::Hash#to_hash (Mash#to_hash, Mash#to_json)
reviewer: dblock
branch: thomasklemm/to-hash-read-once
head: "6b6f67b39c4f839154209f4d94ceadb416f82ddb"
base: master
built_on: "277e88e"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "Mash#to_hash and Mash#to_json (which calls it) read every value once instead of twice; in a Mash each read converts the key and checks for a default proc. Reach: every Mash or Hashie::Hash that is serialized again through the inherited Hashie::Hash#to_hash (IndifferentAccess, Dash and Trash have their own to_hash and do not gain), e.g. OmniAuth's AuthHash and InfoHash#to_hash (omniauth 235M downloads) and any API response passed on as JSON. Duel on Ruby 4.0.10, Mash#to_hash of the nested fixture: CPU 0.838 [0.833, 0.842] under YJIT and 0.688 [0.680, 0.694] under ZJIT on the exact head (run 46077588957), both faster, allocations unchanged (10); 27 benchmarks, 0 regressed, 0 unsettled."
evidence: [bench/upstream/hashie_perf/round2, bench/upstream/hashie_perf/round2/duel, bench/upstream/hashie_perf/round2/to_hash]
rank: 3
risky: false
state: held
pr:
note: "2026-11-27 HELD, needs Thomas (Astra and thermos-sol, both changes on 6b6f67b): results differ when a callback changes the receiver between master's two reads, without any [] override: a value whose is_a? replaces or deletes its entry (master converts the replacement, the branch the value it read), a key whose hash clears the receiver while the output key is written (master raises NoMethodError, the branch returns the Array), and a fiber or thread that replaces the entry while to_hash is suspended (probes/to_hash_reentrant.rb, out/to-hash-reentrant.txt; the reviewers' sections and archives in the round2 README). This is checklist item 6 (mutation during conversion). No dependent was found doing it; ordinary inputs agree in 33,000 and 35,280 independent rows per side on 8 and 16 Ruby and JIT cells. The only exact fix restores the two reads and with them the cost. Opens only if Thomas accepts reading each value once as outside the contract, with one more body sentence saying that a value changed by a callback during to_hash is converted as it was read. Not opened, nothing posted. 2026-11-27 rebased by hand onto master 277e88e as 6b6f67b (the CHANGELOG conflicted with the two entries merged since; code diff and message unchanged, CHANGELOG line now #662; Thomas, no trailers, signed; forced over e10dce0 on the fork, no PR was open). Duel judged the exact head on fork PR #33 (run 46077588957). Rerun on 6b6f67b: Ruby 4.0.10 rake spec 1,076/0, rubocop clean, docs:examples 359/0; 3.0.7 1,072/0; 3.4.7 1,076/0; differential against 277e88e identical apart from the two expected differences (to_hash/differential-6b6f67b.tar.gz). Earlier: built on master 9e313f3 as one commit e10dce0 (Thomas, no trailers, signed). Ruby 4.0.10 rake spec 1,076/0, rubocop clean, docs:examples 359/0; Ruby 3.0.7 1,072/0 and 3.4.7 1,076/0. Differential probes/to_hash_diff.rb: 2,340 rows identical between master and the branch on 4.0.10 and master+ZJIT; the two expected differences are recorded by the probe: a subclass's [] is called once per key instead of twice, and a [] that alternates its result between calls no longer mixes two results. Duel on fork PR #29 (run 46068675920, lib of 39db98d, same tree as e10dce0 apart from the commit message). First in line now that HM3 is held; recheck that #662 is still the next number before opening."
ownership: {date: 2026-11-27, checked: ["open PRs naming to_hash that change CHANGELOG.md, lib/hashie/hash.rb"], hits: []}
passes:
  - {reviewer: astra, head: "6b6f67b39c4f839154209f4d94ceadb416f82ddb", date: 2026-11-27, orb: T-01a21f3c-2ef1-726e-be84-05ebf5389576, verdict: changes, open: "Public value/key callbacks and synchronized mutation change results or exceptions without overriding []; copying readers expose first-copy state. Restore the reads for exactness, or explicitly accept the broader snapshot contract. Repros, claim audit and reach checks in round2 README and astra-HM5-6b6f67b.tar.gz."}
  - {reviewer: thermos-sol, head: "6b6f67b39c4f839154209f4d94ceadb416f82ddb", date: 2026-11-27, orb: T-01a21f3c-226a-77d4-8978-cd852e1e46ae, verdict: changes, open: "R1 reentrant public callbacks change results without a [] override; restore two reads or explicitly accept the broader contract. R2 qualify every-Mash reach; IndifferentAccess bypasses the helper. Performance follow-up: repeat the diagnostic large-Array master/ZJIT loss on a1.xxlarge. Record and raw archive in hashie_perf/round2. Both rubrics applied here without delegation."}
---

# Read each value once in Hashie::Hash#to_hash

`Hashie::Hash#to_hash` reads every value twice through `self[k]`: once to see whether it is an Array, and again to convert it. In a Mash each read converts the key and looks for a default proc, so `to_hash`, and `to_json`, which calls it, did that work twice per key.

This reads the value once and converts what was read. A subclass that overrides `[]` now sees one read per key instead of two. Duel's "Mash#to_hash: a nested Mash" on Ruby 4.0, CPU time relative to master:

| | this branch |
| --- | ---: |
| YJIT | 0.84 |
| ZJIT | 0.69 |

Allocations are unchanged.
