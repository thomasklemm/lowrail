---
id: CB1
repo: rails/rails
kind: perf
area: Active Support, NilClass try
reviewer: amatsuda
branch: thomasklemm/nil-try-forwarding
head: "22a3d41d8db5ba1aad8b86de5229336148080bca"
base: main
built_on: "1e235cee11b0a7aecb189d8837534807626287aa"
depends_on: []
stacked_on:
alternative_of:
impact: "Rejected: forwarding skips keyword conversion, including ActionController::UnfilteredParameters"
rank: 15
risky: false
state: held
pr:
note: "Do not open. Exact-head skeptic found a direct keyword-splat coercion difference; independently reproduced on interpreter and YJIT. Original signatures stay. Benchmarks, coercion outputs, suite totals, pins and reproduction are in docs/upstream/census-backlog.md, 2026-11-05 night refresh. No Sol review requested."
passes:
  - {reviewer: skeptic, head: "22a3d41d8db5ba1aad8b86de5229336148080bca", date: 2026-11-05, verdict: changes, open: "Forwarding suppresses to_hash side effects and exceptions for direct calls; unpermitted Parameters no longer raises. Rejected, not waived."}
---

# Do not open: nil.try forwarding skips keyword conversion

Changing nil's `try` and `try!` to forwarding signatures skips keyword conversion on direct calls. With unpermitted controller parameters, the current methods raise `ActionController::UnfilteredParameters`; the trial returns nil instead.

Do not open this change: keep the original signatures and their conversion behavior. The measured saving below, per `nil.try(:upload)` on the Ruby 4.0.9 interpreter, does not justify changing what callers observe.

| | Before | Rejected variant |
| --- | ---: | ---: |
| Callgrind instructions | 1,399 | 957 (−31.6%) |
| Objects | 1 | 0 |
