---
id: CB2
repo: rails/rails
kind: perf
area: Active Support, around callbacks
reviewer: amatsuda
branch: thomasklemm/around-callback-arguments
head: "ced306c8a8b827f538b4b6f0fbeefc1264e94f8f"
base: main
built_on: "1e235cee11b0a7aecb189d8837534807626287aa"
depends_on: []
stacked_on:
alternative_of:
impact: one Array fewer per symbol around callback; 1.2% fewer interpreter instructions per callback run on Ruby 4.0.9
rank: 14
risky: false
state: draft
pr: 59677
note: "Queue only; coordinator Sol pending. Nodoc call-template tuple changes, so internal overrides must adapt. Block interpreter result is marginal versus A/A; object interpreter Ir is +0.10%. JIT controls, test totals, pins and reproduction: docs/upstream/census-backlog.md, 2026-11-05 night refresh. Body shortened under the new rule; no upstream action."
passes:
  - {reviewer: skeptic, head: "ced306c8a8b827f538b4b6f0fbeefc1264e94f8f", date: 2026-11-05, verdict: nits, open: "No correctness blockers; medians, harness links and marginal block row wording applied. Additional 201 public-API differential cases identical."}
  - {reviewer: sol, head: "ced306c8a8", date: 2026-11-05, verdict: nits, open: "no public behaviour difference (83 + 58 probes); table scope and headings clarified in the body, applied"}
---

# Keep around callback arguments in the call tuple

Around callbacks collect an argument Array before invoking the callback, even for a symbol method that takes no arguments. This happens in model callbacks and controller filters.

This keeps the argument list in the existing call tuple instead, leaving that entry absent when there are no arguments. Invocation stays at the same call site: callers run the same callbacks with the same arguments and ordering. Running a chain with one around callback, Ruby 4.0.9 without a JIT:

| Around callback | Allocated objects per run | Callgrind instructions per run |
| --- | ---: | ---: |
| Symbol method | 7 → 6 | 14,400 → 14,233 (−1.2%) |
| Two-argument block | 8 → 8 | 15,371 → 15,348 (−0.15%) |
| Object | 7 → 7 | 14,672 → 14,686 (+0.10%) |
