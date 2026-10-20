# Sealed blog-show renderer: finite, behavior-matched experiment

2026-10-20. **Measurement only; no pass, runtime, default or tier change.**

**The specimen misses 2×.** Rails uses **8.744456 M Ir/request**; the final
behavior-matched specimen uses **6.120350 M**, **−30.016%**
[−30.038, −29.979], about **1.43×** less interpreter work. It remains
**1.72 M Ir above 4.4 M**, or 1.75 M above half this cohort's Rails cost.
This is not native throughput and not a mathematical lower bound on sealed
Rails. In particular, the historical **5.473809 M L2_events** anchor is
cheaper but not behavior-equivalent; restoring the contract is not free.

## Scope and equivalence gate

The handwritten [specimen](../../bench/experiments/sealed_renderer.rb) accepts
only unmounted, successful GET-shaped `/articles/1`, `/2`, `/3` requests
without Accept, User-Agent, query or conditional headers. Unknown shapes
use original Rails; missing records retain Rails' exception pipeline.
The generated `.corpus/real-blog-r4` is Rails **8.1.4**, Ruby **4.0.7**, with
three real Articles and 2/1/0 associated Comments. There is no response,
model, query-result, signed-stream-name or token cache.
Instruction cohorts price **stock `/articles/1` with two comments**. IDs 2/3
and the explicit empty-comments fixture are correctness cases, not additional
instruction cohorts; no performance claim is made for those cardinalities.

The existing [isolated endpoint comparator](../../bench/experiments/blog_endpoint_check.rb)
has an explicit opt-in specimen hook. Its original 144-case mode is retained.
Experimental mode adds an **empty-comments-only** fixture and subscriber
snapshots of actual article class/attributes/persistence/association-loaded
state, controller assign keys, transaction-open and query-cache state.
Each of five cumulative stages passes **192 isolated pairs**:

- Four paths, including the untouched index; six request shapes, including
  HTML/JSON Accept, browser UA and a query; absent/existing encrypted session.
- Stock, escaping/Unicode/long-text, empty database/404, and empty-comments
  fixtures. Changes are enclosed in real rolled-back AR transactions.
- Literal status/body/**all headers**, including ETag, Set-Cookie and
  X-Runtime; full ordered SQL with bind names/values and cached flags.
- Controller/render event start/finish traces: names, order, nesting, payload
  keys and stable values, plus live controller state at each boundary.

A further **192-pair** final-stage run passes with a fixed render subscriber
that writes a response header. No listeners are suppressed. Only correctness
workers seed entropy and freeze clocks, symmetrically; measurements use real
clocks, entropy, CSRF masking/signing and encrypted-cookie operations.
This is finite behavior evidence, **not universal certification**, a
`lowrail verify` support claim or enforcement of [the sealed contract](../sealed.md).
Source/receiver/config inventories and admissibility would still be needed
for a generator. No arbitrary post-seal mutation is supported or normalized.

## Ordered ablation

Start with the unchanged historical L2_events, then explicitly price the
chosen restoration before further composition. All following stages retain
real controller/view objects, assigns, AR relations/associations, query cache,
transactions, session/CSRF/cookies and every original notification subscriber.
There is no per-request singleton-method installation, unlike old L2_events.

| Cumulative stage | Total M Ir/request | GC-excluded M Ir | Objects/request | Paired Δ Ir from preceding stage [95% CI] |
|---|---:|---:|---:|---:|
| Rails off-A | 8.744456 | 8.745129 | 2,244.30 | reference |
| Historical L2_events — **non-equivalent** | 5.473809 | 5.474416 | 1,277.24 | −37.395% vs Rails; diagnostic semantics |
| `restored`: real dispatch/render stack, handwritten show/comment/layout, real form builder | 7.759960 | 7.759905 | 1,954.31 | +2,286,271 [+2,283,863, +2,288,023] |
| `form`: expand the fixed blank-comment form scaffold | 6.464274 | 6.463673 | 1,563.31 | −1,295,675 [−1,297,383, −1,294,379] |
| `filters`: flatten the fixed stock callback chain | 6.418705 | 6.418729 | 1,548.12 | −45,154 [−49,197, −43,112] |
| `tokens`: expand hidden-input tag composition, not token generation | 6.336521 | 6.336668 | 1,528.37 | −81,417 [−84,531, −77,370] |
| `collection`: fixed collection plan; remove dispatcher/wrapper intermediates | **6.120350** | **6.119476** | **1,465.73** | −217,108 [−219,653, −215,270] |

Intervals resample six whole rounds, seed 41231; they are nominal and coarse.
Paired deltas need not equal subtraction of displayed medians. The final
absolute interval is **[6.117768, 6.122004] M Ir**. No measured request window
collects a minor or major GC. This is the fixed large-heap slice, not a
production GC-cost claim. Objects are counts, not bytes or retained memory.

The form step is the large additional win. It keeps `Comment.new` in its
original position, checks its stock blank state, and keeps real token
generation and fresh output. Filters retain GET CSRF, ActionText/Turbo around
bodies, `set_article`, same-origin verification and the downstream real action
machinery. Collection fusion retains `PartialIteration`, real locals and
`Template#render`, hence Rails' buffer/template-stack/error/event boundary.
The real render pipeline sets rendered format and view-flow layout state.
Asset/importmap/CSP, Turbo signing, escaping and real URL helpers remain live.

**This is not a minimal restoration tax.** The conservative restoration also
retains controller/render scaffolding and URL helpers which historical L2
expanded. Its net final cost above L2_events must not be attributed solely to
assigns or treated as an unavoidable observer price. Nor does this finite
specimen exhaust every composition allowed by sealed.md.

## Remaining real-Rails residual: separate boundary counters

Interpreter-only diagnostic arms execute the same final endpoint, with
[native collection gates](../../bench/experiments/sealed_residual.c) around
[named live boundaries](../../bench/experiments/sealed_residual.rb).
They use the same pinned Callgrind, not a timer or Ruby source inference from
C interpreter frames. Nested selected boundaries count once; N=0 subtracts
the gate seam. Scope export requires GC-free windows; the reporter refuses
otherwise, because the shared GC-exclusion toggle is not a nested scope API.
An asymmetric 0/10,000/30,000-loop check, with 80,000 unselected
iterations in every window, gives ratio **3.0088** versus independently
expected 3 and retains balanced collection after an exception.

| Retained boundary, inclusive | Total M Ir/request [95% CI] | GC-excluded M Ir |
|---|---:|---:|
| AR: Article find/new, Comment new, association load_target, attribute reads | **1.285804 [1.285537, 1.286229]** | 1.285800 |
| Security: session prepare/commit, cookie writes, CSRF callbacks/token generation/meta tags | **1.120258 [1.119181, 1.120735]** | 1.119202 |
| Events: live Fanout listening/build-handle/start/finish, including subscriber work | **0.269958 [0.269933, 0.270007]** | 0.269979 |

**These are diagnostic prices, not an accepted self-cost decomposition.**
Wrappers raise the whole request from 6.120350 to **6.325909 M Ir**:
paired **+206,355 [202,298, 208,969] Ir**, about +3.37%, outside the hotspot
map's ±0.5% fidelity criterion. Allocations in these workers describe the
whole wrapped request, not the selected boundary. Events can nest inside AR
or security; these rows are **not additive**, exhaustive or removable budgets.
They do not establish an irreducible 2.68 M floor.

The blocking area in this specimen is the **remaining Rails request/render
integration and live helper work, on top of real AR/security**, not a missing
last template-dispatch trick. Neither SQL alone nor event fanout alone is
shown to make 2× impossible. The baseline [hotspot map](hotspots.md) agrees
that work is distributed across AS utilities, Rack/request, rendering,
queries and security; its original-source percentages cannot be transplanted
onto this specimen or added to these inclusive prices.

## Protocol, controls and retained failures

The measured base is
[`c843f7e`](https://github.com/thomasklemm/lowrail/commit/c843f7efb569059f504715fa7efad6c731d81440)
plus the exported exact specimen/harness digests. It is not merely a HEAD
claim. The [shared fixed-heap protocol](../bench.md) is unchanged: six fresh
randomized rounds; N=0/50 total and GC-excluded windows; five floors
1,000,000/250,000/100,000/20,000/10,000; exact observer warmup; three full GCs
and one settling request before every window. GC stays enabled in requests.
There are at most **four** Callgrind workers, interpreter first, YJIT second.
No Lowrail setup, passes, statistics or outcome hooks run in measurements.

Pinned Valgrind 3.19.0 uses the
[`d7d62ba`](https://github.com/thomasklemm/lowrail/commit/d7d62ba) 512-MiB reservation patch:
source SHA `dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02`,
tool SHA `ba5604c65a1c44d3aef270d5dcb66daf119160a9b0597e451ec435c407d7c98c`.

The interpreter comparison **passes** total A/A
**[−0.0070, +0.0446]%**, GC-excluded A/A **[−0.0067, +0.0509]%**, all five
actual pool-capacity gates, actual interpreter-state checks and overflow
checks. There are 48 ordinary request workers and 24 diagnostic scope
workers in its six rounds; scope workers are not optimization arms.

An initial setup launch failed all four first-wave workers **before warmup
or instruction windows**, collecting zero Ir: the after_initialize hook
issued requests before the route-loading finisher. Installation was moved
after completed `initialize!`. That failed launch remains recorded; no
completed round, failed A/A or unfavorable measurement was replaced.

### YJIT: entire comparison rejected

All 48 workers reach flat warmup, but **5/48** change compiler counters in
measured N=50 windows: `0-collection` +16 blocks, `1-restored` +15,
`2-off_a` +7, `3-collection` +9, and `5-collection` +1 ISeq/+1 block.
Invalidation counts stay unchanged. The responsible compilation sites are
unattributed; no assumed observer or AR cause is substituted for evidence.
Total A/A passes **[−0.12744, +0.00882]%**; GC-excluded A/A fails
**[−0.24369, −0.00406]%**, because it excludes zero. Heaps, actual YJIT
state and overflow checks pass. No windows collect a minor/major GC.
No retry or clean-arm salvage; **every cell below is diagnostic only**.

| Stage | Total M Ir/request, rejected | GC-excluded M Ir, rejected | Objects/request, diagnostic |
|---|---:|---:|---:|
| Rails off-A | 5.416651 | 5.416860 | 2,254.64 |
| Historical L2_events, also non-equivalent | 3.504628 | 3.505300 | 1,282.21 |
| restored | 4.792486 | 4.792984 | 1,964.63 |
| form | 4.042792 | 4.043409 | 1,572.28 |
| filters | 4.017437 | 4.014821 | 1,557.52 |
| tokens | 3.957953 | 3.958548 | 1,537.28 |
| collection | 3.854847 | 3.855955 | 1,473.25 |

Final diagnostic Δ is −28.822% [−28.862, −28.772], **not an accepted YJIT
gain**. Its 3.85 M must not be compared against an interpreter's 4.4 M target:
this YJIT cohort's own baseline is 5.42 M, not 8.74 M. No native serving-speed
conclusion follows from either mode.

## Recommendation

**Do not promote a third mini-runtime/bridge tier from this experiment.**
The finite fully compared specimen demonstrates approximately 1.43× reduced
interpreter work, not the requested 2× and not 2–3× native serving speed.
Reaching half Rails' cost still needs about **1.75 M additional Ir**, roughly
**29% of this final endpoint**, while retaining all listed observables.

A bridge must deliver real controller/view state and buffers, ordered
subscriber boundaries/payloads, real AR associations/query cache/transaction
lifetimes, the real encrypted session and CSRF/cookie pipeline, and correct
Rack/body-close/exception behavior. Restoring only returned AR objects is
insufficient. Those obligations should remain the target, not be waived to
recover Roundhouse's replacement-runtime ratio. Keep the existing two-tier
design and quarantine/default decisions unchanged. This negative finite
result does **not** prove every more aggressive sealed renderer incapable
of 2×; it provides no evidence to justify building that new tier now.

## Reproduction and evidence

Prepare `script/corpus real-blog real-blog-r4`, production database and assets
as in [the calibration](roundhouse-calibration.md). Build the pinned tool
before measuring. Each output directory must be new:

```sh
bash script/bench-valgrind /tmp/vg
ulimit -d unlimited
export PATH=/tmp/vg/bin:$PATH CPATH=/tmp/vg/include BENCH_JOBS=4
BENCH_JIT=0 mise exec -- ruby bench/experiments/sealed_renderer_study.rb /tmp/NEW-sealed-interpreter
BENCH_JIT=1 mise exec -- ruby bench/experiments/sealed_renderer_study.rb /tmp/NEW-sealed-yjit
# Additional fixed, side-effecting observer check:
SEALED_RENDERER_STAGE=collection mise exec -- ruby bench/experiments/blog_endpoint_check.rb \
  .corpus/real-blog-r4 /tmp/NEW-sealed-observer-check render_subscriber
mise exec -- ruby bench/experiments/sealed_renderer_report.rb \
  /tmp/NEW-sealed-interpreter /tmp/NEW-sealed-yjit /tmp/NEW-sealed-results.json \
  /tmp/NEW-sealed-observer-check
```

[The numeric export](sealed-renderer-results.json) retains all window/GC/heap/
JIT endpoints, failed controls, instruction totals, estimates, equality
digests and provenance. Duplicate window copies are checked then stored once
under `raw.workers[round-arm].windows`, not discarded or summarized away.
Raw HTML, SQL, encrypted cookies and correctness-worker logs stay private.
The shared benchmark tests pass **12 tests / 130 assertions**, including the
counter/GC/JIT/brk rejection regressions. No runtime/framework support gate
or native speed claim is inferred from these measurement-only changes.
