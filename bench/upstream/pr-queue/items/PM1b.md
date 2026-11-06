---
id: PM1b
repo: rails/rails
kind: perf
area: Active Record, query requests and execution
reviewer: matthewd
branch: thomasklemm/query-intent-request
head: "3510f6e1513ce9315795d5fda0b70c7ca6042583"
base: main
built_on: "cadf0fc8d6d48cefaa07e4bd6cc5dcd8347821b2"
depends_on: []
stacked_on:
alternative_of: PM1
impact: separates compiled query data from execution state and reuses the request across the Ractor boundary; snapshot allocation and interpreter instructions increase
rank: 11
risky: true
state: held
pr:
note: "Architectural prototype, not a performance improvement. Frozen snapshot churn needs a better lifecycle before proposing it; final independent Claude Code review is pending with the coordinator. No PR or comments. Record: docs/upstream/perf-round-main.md#pm1b-queryrequest-holds-query-data-2026-11-06"
passes:
  - {reviewer: skeptic, head: "691ed26986d692a4866991a97f73d8159cf0dd24", date: 2026-11-06, verdict: nits, open: "P3: with loses binds after transport, unreachable through current public paths; fixed in 3510f6e151"}
  - {reviewer: skeptic, head: "3510f6e1513ce9315795d5fda0b70c7ca6042583", date: 2026-11-06, verdict: approve, open: "Code review and real-worker retry/warning probes; one-line fix verified; no remaining findings. Body and final review remain for Claude Code."}
---

# Separate query request data from intent execution state

Following [matthewd's suggestion on rails/rails#59673](https://github.com/rails/rails/pull/59673#issuecomment-6681165414), this promotes the Ractor proxy's `QueryRequest` to the connection-adapter level. It holds the SQL, binds and execution options, while `QueryIntent` holds the adapter, preparation caches, result, retries, synchronization and instrumentation. The proxy passes the same shareable request to the physical-side intent instead of rebuilding its parameters.

Preparation remains lazy: compilation and query transformers replace frozen request snapshots, so RETURNING, transaction checks and async scheduling keep their existing order. Ordinary snapshots retain caller-owned bind objects; only transport snapshots are deeply shareable. This is an architectural refactor, not a speed improvement: replacing snapshots allocates more objects and increases interpreter instructions in the measured ordinary queries. No public API or documented query behavior changes, and no deprecation aliases are added for the internal classes.
