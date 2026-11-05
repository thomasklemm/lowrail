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
state: in-review
pr:
note: "Queue only; no upstream action. Skeptic nits applied; coordinator Sol pending. Master ZJIT symbol/block/object Ir lower with flat windows."
passes:
  - {reviewer: skeptic, head: "ced306c8a8b827f538b4b6f0fbeefc1264e94f8f", date: 2026-11-05, verdict: nits, open: "No correctness blockers; medians, harness links and marginal block row wording applied. Additional 201 public-API differential cases identical."}
---

# Keep around callback arguments in the call tuple

`run_callbacks` collects the trailing entries of its internal call tuple into an argument Array before calling each around callback. This puts the argument list in the fourth tuple entry instead. Symbol callbacks and zero-argument blocks leave that entry absent; splatting nil supplies no arguments without creating an empty Array. Templates with arguments supply an Array there. The `send` stays in `run_callbacks`, so no frame is added around user code.

Ruby 4.0.9 interpreter, median Callgrind instructions per callback run, three runs per tree:

| Around callback | main | this PR | Objects |
| --- | ---: | ---: | ---: |
| Symbol method | 14,400 | 14,233 (−1.2%) | 7 → 6 |
| Two-argument block | 15,371 | 15,348 (−0.15%) | 8 → 8 |
| Object | 14,672 | 14,686 (+0.10%) | 7 → 7 |

The symbol row's main-against-main control differs by at most 0.024%. The block improvement is marginal (A/A up to 0.133%); the object regression is retained. A minimal controller action with one symbol `around_action` saves one object, but its instruction change is within A/A; this is not a request-speed claim.

<details><summary>Method</summary>

Rails main [`1e235cee11`](https://github.com/rails/rails/commit/1e235cee11b0a7aecb189d8837534807626287aa), a second checkout of that commit, and this branch at [`ced306c8a8`](https://github.com/thomasklemm/rails/commit/ced306c8a8b827f538b4b6f0fbeefc1264e94f8f).
Ruby 4.0.9 revision `3e93b23afc`, JITs off, GC disabled, fixed heap.
Lowrail's [`percall.sh`](https://github.com/thomasklemm/lowrail/blob/5b9c878577970eaeb02b69d614b7e4a6bd7eea87/bench/upstream/perf_round/percall.sh)
with [`refresh_cases.rb`](https://github.com/thomasklemm/lowrail/blob/5b9c878577970eaeb02b69d614b7e4a6bd7eea87/bench/upstream/census_backlog/refresh_cases.rb):
`symbol`, `block`, `object`, 3,000 calls after 2,000 warmups. Workload case `action`, 1,000 calls after 500 warmups, `WORKLOADS=1`.
All instruction counts include the loop overhead, equal on both sides.
Active Support: 6,901 tests, no failures or errors, 60 skips, the same totals as main.
Differential checks cover public callback APIs, method-missing dispatch, overridden `send`/`instance_exec`, subclasses, frozen receivers, conditions, aborts, exceptions and fiber suspension.
The nodoc call-template representation changes; overrides of those internals must follow it.

```
WARMUP=2000 RUBY=path/to/ruby-4.0.9/bin/ruby bash bench/upstream/perf_round/percall.sh bench/upstream/census_backlog/refresh_cases.rb symbol 3000 3 path/to/main path/to/main-2 path/to/branch
WORKLOADS=1 WARMUP=500 RUBY=path/to/ruby-4.0.9/bin/ruby bash bench/upstream/perf_round/percall.sh bench/upstream/census_backlog/refresh_cases.rb action 1000 3 path/to/main path/to/main-2 path/to/branch
```

</details>

---
<sub>Found in the allocation census for my research project Lowrail ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/census-backlog.md#refresh-on-main-1e235cee11-2026-11-05-night)).</sub>
