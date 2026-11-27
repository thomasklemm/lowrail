---
id: HD2
repo: hashie/hashie
fork: thomasklemm/hashie
kind: feature
area: CI, Duel under ZJIT next to YJIT (.github/workflows/perf.yml, CONTRIBUTING.md, CHANGELOG.md, .spellcheck.txt)
reviewer: dblock
branch: thomasklemm/duel-zjit
head: "f6545d1dd34c3905fb4c8fa25764f209cb65274f"
base: master
built_on: "9e313f3"
tracker: []
depends_on: [HD1]
stacked_on:
alternative_of:
impact: "Every hashie PR that touches lib/ gets a second Duel check under ZJIT next to the YJIT one, same benchmarks and settings, in parallel. Calibrated on the fork: A/A 20 runs, 0 failed under either JIT (unsettled YJIT 16/540, ZJIT 2/540); both plants regressed the same benchmark sets under both JITs; #656's change never slower. Renames the YJIT check to yjit / Duel (yjit)."
evidence: [bench/upstream/hashie_duel/zjit]
rank:
risky: false
state: built
pr:
note: "2026-11-27 built after #659 merged (squash 9e313f3): follow-up commit b060244 replayed as one commit on 9e313f3, CHANGELOG line numbered #660 (next number; recheck before opening), Amp trailer removed with script/commit --amend: f6545d1, tree = b060244 plus the CHANGELOG number. The job key duel -> yjit is our choice; the coordinator asked for report: yjit, and keeping the key would name the check duel / Duel (yjit). Ruby 4.0.9 rake spec 1,076/0, rubocop 124 + 156 files clean. Perf Comment with two reports tested on the fork (b060244 as default branch): one comment with yjit and zjit sections on the CPU plant, none on A/A (zjit/README.md). Coordinator: open ready under the two-approvals rule. Ownership 2026-11-27: no hashie PR or issue, open or closed, mentions ZJIT; latest numbers #657-#659 are closed (#658 issue, #659 HD1 merged)."
ownership: {date: 2026-11-27, checked: ["hashie/hashie PRs and issues, open and closed, mentioning zjit", "latest hashie issues and PRs #657-#659"], hits: []}
passes: []
---

# Run Duel under ZJIT next to YJIT

A change can be faster under one JIT and slower under the other, so Perf now runs the same Duel benchmarks and settings under ZJIT as well as YJIT, as two jobs in parallel. Each job names its report, so the YJIT check is now `yjit / Duel (yjit)` instead of `duel / Duel`; a required status check under the old name would need updating.

On a fork, 20 runs on identical code failed neither job. Two planted regressions failed the same benchmarks under both JITs, #656's change was never reported slower, and Perf Comment posted both reports in one comment. Each job takes about two minutes.
