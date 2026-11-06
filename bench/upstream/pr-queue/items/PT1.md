---
id: PT1
repo: rails/rails
fork: thomasklemm/rails
kind: perf
area: Active Record, transactional test fixtures
reviewer: matthewd
branch: thomasklemm/skip-unused-fixture-pool-scan
head: "31058914ccf2e4f7b36c3d3d815f9f756b628819"
base: main
built_on: "1e235cee11b0a7aecb189d8837534807626287aa"
depends_on: []
stacked_on:
alternative_of:
impact: "Transactional examples using ActiveRecord::TestFixtures, including rspec-rails integrations, scan all pool configs after every example even when no saved role/shard mapping disappeared. The guard saves 1.23% of an empty Campfire model test's interpreter instructions and 1.90% under YJIT, with 14 fewer objects; max paired A/A 0.113%/0.117%. No accepted whole-suite benefit: all three full-suite arms fail the same checkpoint test and same-base instruction drift is 7.50%. Broad reach alone does not clear the impact gate."
rank: 25
risky: true
state: held
pr:
note: "parked idea; branch kept, not to open as-is. Corrected head keeps main's ordering and passed skeptical review. Four-app controls and full-suite A/A/candidate cohort finished; full-suite comparison rejected for the same checkpoint-test failure in every arm. No Sol/Astra on this head or Ruby master/ZJIT pass requested without sufficient impact. No upstream action authorized. Record: docs/upstream/test-overhead.md."
passes:
  - {reviewer: skeptic, head: "75ff72edf42381d97398281399c0878c5e8cb08a", date: 2026-11-05, verdict: nits, open: "No demonstrated blockers; 13 graph scenarios, 500 mutation traces, live SQLite/thread/self-proxy and pin-failure probes. Optional reach wording applied; private map shape and return values intentionally differ."}
  - {reviewer: sol, head: "75ff72edf42381d97398281399c0878c5e8cb08a", date: 2026-11-05, verdict: changes, open: "Lazy shard insertion reverses restoration and orphan disconnection when a reader is added on an earlier writing-only shard mid-test."}
  - {reviewer: astra, head: "75ff72edf42381d97398281399c0878c5e8cb08a", date: 2026-11-05, verdict: changes, open: "Independently reproduced the same late-reader restoration/disconnection order defect over two cycles."}
  - {reviewer: skeptic, head: "43b20e75ca98e2f776eee19e5fef8cad9cdc0e65", date: 2026-11-05, verdict: nits, open: "Production diff has no demonstrated blocker; ordered traces and late-reader tests match main. Test should restore original isolated-execution-state override, not resolved handler. Fixed in current head; exact-head recheck pending."}
  - {reviewer: skeptic, head: "31058914ccf2e4f7b36c3d3d815f9f756b628819", date: 2026-11-06, verdict: nits, open: "No blockers. Raw handler override restored under unset/nil/direct/Ractor and failure/repeat probes. Ordered production and live transaction probes carry via empty production diff. Body clarified to saved role/shard mappings; record updated to withdraw lazy variant. Performance approval not implied."}
---

# Skip the fixture pool scan when no saved role/shard mapping disappeared

Transactional fixture teardown scans all pool configs to find surviving references before disconnecting removed replica configurations. Most tests leave every saved role/shard mapping in place, so this scan has nothing to check.

Skip the scan when no saved role/shard mapping disappeared. Keep pool restoration and orphan disconnection in their existing order, including when a reader is added mid-test.

Objects and interpreter Callgrind instructions per empty Campfire model test, Ruby 4.0.9:

| Per test | Before | After |
| --- | ---: | ---: |
| Allocated objects | 339 | 325 |
| Callgrind instructions | 1,279,555 | 1,263,806 (−1.23%) |
