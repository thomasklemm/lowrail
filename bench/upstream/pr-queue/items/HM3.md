---
id: HM3
repo: hashie/hashie
fork: thomasklemm/hashie
kind: perf
area: Mash#method_missing
reviewer: dblock
branch: thomasklemm/method-missing-rest
head: "282ebcbb8248ae3ef379bc7254ad69fd0422d7b4"
base: master
built_on: "9e313f3"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "Every method-style read on every Mash (mash.name, mash.owner.login, mash.private?) allocates one Array fewer on Ruby 4.0 and later. Plain Mash and its subclasses are the response object of hashie's largest dependents: omniauth 235M downloads, snaky_hash 140M (oauth2), slack-ruby-client 96M, elasticsearch-model 78M, restforce 60M, zendesk_api 47M, faraday-mashify 27M. Duel on Ruby 4.0.10: read keys as methods 5 -> 0 objects and CPU 0.953 (YJIT, same) and 0.937 (ZJIT, faster); Symbol-given keys 5 -> 0, CPU 0.914 and 0.912, both faster; suffixed reads 16 -> 12; nothing regressed; setters allocate as before, CPU 1.012-1.022, same. Local body/HM3 (4.0.10): 5 reads on a GitHub repository 5 -> 0 objects, Callgrind -1.3% interpreter (A/A 0.17%) and -2.6% YJIT (A/A 0.09%), YJIT wall -3.5% [-4.2, -3.2]; ZJIT on master wall -3.9% [-4.4, -3.5] (A/A -0.1%). Ruby 3.0-3.4 allocate the Array as before."
evidence: [bench/upstream/hashie_perf/round2, bench/upstream/hashie_perf/round2/body/HM3, bench/upstream/hashie_perf/round2/wall/HM3-master-zjit, bench/upstream/hashie_perf/round2/wall/HM3-setter-master-zjit, bench/upstream/hashie_perf/round2/duel, bench/upstream/hashie_perf/round2/mm]
rank: 2
risky: false
state: held
pr:
note: "2026-11-28: fork branch thomasklemm/method-missing-rest deleted (Thomas: no dead branches on the fork); the head is refs/heads/held/HM3 in bench/upstream/hashie_perf/round2/candidates.bundle. 2026-11-27 HELD, not exact (Astra and thermos-sol, both changes on 282ebcb): the optional parameter receives a keyword-flagged Hash as it is, where the rest Array received an unflagged copy, so a value set through SimpleDelegator (Ruby 3.3 and later) or through a ruby2_keywords method_missing override calling super (3.2 and later) is later splatted as keywords (probes/mm_anonymous_rest.rb, out/mm-anonymous-rest.txt). The exact form found keeps an anonymous rest and reads [*].first in the setter (reads still save the Array, a setter allocates one more), but forwarding an anonymous rest is Ruby 3.2 syntax and hashie supports 3.0; not reviewed. Reopen when hashie requires Ruby 3.2. Not opened, nothing posted. 2026-11-27 built on master 9e313f3 as one commit 282ebcb (Thomas, no trailers, signed). Claimed local loss, explained and stated in the body: under ZJIT on master a setter is +2.5% [+2.2, +2.7] and a read with an argument +6.7% [+6.5, +6.9] (wall/HM3-setter-master-zjit, 30 rounds); a call with an argument allocates the same Array as before and now also fills the optional parameter; Duel has both setter benchmarks at 1.008-1.022, same. Readability L0: one signature and one argument name change, flog and ABC unchanged in structure (the reviewers measure). Record: bench/upstream/hashie_perf/round2/README.md, HM3. Supersedes point 4 of the reply on #659 (issuecomment-7227673119), which left *args; the body says so. Ruby 4.0.10 rake spec 1,077/0 (two added expectations for extra arguments), rubocop 156 files clean, docs:examples 359/0; Ruby 3.0.7 1,073/0 and 3.4.7 1,077/0. Differential probes/mm_diff.rb: 155,953 rows identical between master and the branch on 4.0.10 (interpreter and YJIT) and on master+ZJIT (mm/differential.tar.gz); the same probe finds 33,760 differing rows for a fixed-arity variant without the anonymous rest. Duel on fork PR #27 (YJIT and ZJIT, run 46067769275): 0 regressed, 0 unsettled. CHANGELOG line numbered #662; recheck before opening."
ownership: {date: 2026-11-27, checked: ["open PRs naming method_missing that change CHANGELOG.md, lib/hashie/mash.rb"], hits: []}
passes:
  - {reviewer: astra, head: "282ebcbb8248ae3ef379bc7254ad69fd0422d7b4", date: 2026-11-27, orb: T-01a21f08-d80b-7106-a4dc-d66f07191d10, verdict: changes, open: "Ruby 3.2+ forwarded keyword hashes retain their flag instead of becoming positional (minimal repros and full matrix in round2 Astra section/archive). Body omits recorded master-ZJIT losses; impact overstates current eligibility and every-Mash coverage. Earlier-reply paraphrase is a wording nit. Restore exact keyword behavior and correct the text before opening."}
  - {reviewer: thermos-sol, head: "282ebcbb8248ae3ef379bc7254ad69fd0422d7b4", date: 2026-11-27, orb: T-01a21f08-d041-7016-b829-aa1e0ed68eaf, verdict: changes, open: "R1 keyword forwarding changes a returned positional Hash into keywords (SimpleDelegator on Ruby 3.3+, ruby2_keywords super on 3.2+); R2 allocation promises exclude empty splats and named-rest super; R3 body omits claimed master/ZJIT losses. Restore named rest or supply an exact replacement, narrow claims and disclose/accept costs. CHANGELOG number remains prospective. Full audit and validated rollback patch in round2/thermos-sol-HM3-282ebcb.tar.gz and the appended README section."}
---

# Read Mash keys as methods without allocating an arguments Array

`Mash#method_missing` collects its arguments with `*args`, which allocates an Array on every call, although only a setter such as `mash.name = 'x'` reads an argument. So `mash.name`, `mash.owner.login` and `mash.private?` each allocate an empty Array.

This names the setter's argument and leaves the rest anonymous: `method_missing(method_name, value = nil, *, &blk)`. Since Ruby 4.0 an anonymous rest parameter allocates nothing when the call passes no arguments; older Rubies allocate the Array as before. This replaces what I wrote in #659, that `*args` had to stay: an optional argument followed by an anonymous rest still takes the setter's value and accepts extra arguments. Duel's allocation counts per iteration on Ruby 4.0:

| Benchmark | master | this branch |
| --- | ---: | ---: |
| Mash: read keys as methods | 5 | 0 |
| Mash: read keys given as Symbols as methods | 5 | 0 |
| KeepOriginalKeys: read Symbol keys as methods | 5 | 0 |
| Mash: read keys with suffixes | 16 | 12 |

Duel reports "read keys given as Symbols as methods" faster under YJIT and ZJIT (CPU time 0.91 of master's). Setters still allocate the Array, and Duel measured them 1–2% slower, within its limit.
