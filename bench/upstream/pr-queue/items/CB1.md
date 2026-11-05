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
note: "Do not open. Exact-head skeptic found a direct keyword-splat coercion difference; independently reproduced. No Sol review requested."
passes:
  - {reviewer: skeptic, head: "22a3d41d8db5ba1aad8b86de5229336148080bca", date: 2026-11-05, verdict: changes, open: "Forwarding suppresses to_hash side effects and exceptions for direct calls; unpermitted Parameters no longer raises. Rejected, not waived."}
---

# Do not open: nil.try forwarding skips keyword conversion

**Rejected after skeptical review.** Replacing `NilClass#try(*, &)` and `try!(*, &)` with `(...)` avoids collecting discarded arguments, but changes supported direct-call behavior. It is not an exact candidate.

For both methods, `nil.try(:upload, **object)` invokes `object.to_hash` on main, preserving its side effects, errors and type checks. The forwarding variant ignores that conversion. With `ActionController::Parameters.new(upload: "example")`, main raises `ActionController::UnfilteredParameters`; the candidate returns nil. Verified independently on Ruby 4.0.9 interpreter and YJIT. The original differential passed actual Hashes through `public_send`, which hid this difference; the revised `refresh_exact.rb` includes direct calls and the four coercion outcomes.

The rejected variant measured the following on Ruby 4.0.9 interpreter; these numbers are retained, not promoted:

| | main | this PR |
| --- | ---: | ---: |
| `nil.try(:upload)`, instructions | 1,399 | 957 (−31.6%) |
| Objects | 1 | 0 |

Main against itself gives identical instructions. A SQLite Active Storage dirty update saves one object (194 → 193), but its instructions are within A/A. A leading optional argument restores keyword conversion but still allocates one rest Array; it is not a cheap rescue of this optimization. Keep the original Rails signatures.

<details><summary>Method</summary>

Rails main [`1e235cee11`](https://github.com/rails/rails/commit/1e235cee11b0a7aecb189d8837534807626287aa), a second checkout of the same commit, and this branch at [`22a3d41d8d`](https://github.com/thomasklemm/rails/commit/22a3d41d8db5ba1aad8b86de5229336148080bca). Ruby 4.0.9 revision `3e93b23afc`, JITs off, GC disabled, fixed heap, three runs per tree. `bench/upstream/perf_round/percall.sh` with `bench/upstream/census_backlog/refresh_cases.rb`: case `nil_try`, 3,000 calls after 2,000 warmups; case `attachment_update`, 1,000 updates after 500 warmups with `WORKLOADS=1`. Counts include the method and everything it calls plus the same loop overhead on both sides. Active Support: 6,901 tests, no failures or errors, 60 skips, identical to main.

</details>

---
<sub>Negative result from the allocation census for my research project Lowrail ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/census-backlog.md#refresh-on-main-1e235cee11-2026-11-05-night)); never posted upstream.</sub>
