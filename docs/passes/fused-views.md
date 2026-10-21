# Bet B: fused view bodies (exploration, 2026-10-21)

Branch `thomasklemm/fused-views`; not a registered pass, supported feature or
README price. Defaults, sealed admission and application code are unchanged.

## Decision: killed after the cheap screen

No speed gain. Do not widen Campfire, change form admission or run a pricing
cohort. The coordinator accepted the kill after the first fusion result; only
the already-running requested token/collection composition finished afterward.

The **unchanged shared native harness** from
[54d92f1](https://github.com/thomasklemm/lowrail/commit/54d92f1e1068eb4e0b1ba60d68f2fc776e08cd52)
ran three alternating off-A/off-B/on rounds, CPU 2, seed 41231, 200 warmup
requests per route and 100 measured requests per route/worker. Both routes
are in each worker; coverage has separate ten-request windows. Compiler
checkpoint is
[080c2bb](https://github.com/thomasklemm/lowrail/commit/080c2bb), with the adapter's
additional, unused untimed-validation hook included in the source pins.
`script/screen` became available later; there was no rerun to change harnesses.
[Machine evidence](fused-views-screen.json) retains both complete result
exports, including raw timings, A/A, source/runtime/artifact pins, coverage,
GC, RSS, boot and setup times. No round was excluded or repeated.

**A/A first** (paired-round 95% bootstrap bands):

| Comparison / route | Wall A/A band | Allocation A/A band |
|---|---:|---:|
| Fusion / show | −1.203%…+2.549% | −0.0123%…+0.0158% |
| Fusion / index | +0.151%…+10.451% | +0.0096%…+0.0444% |
| Fusion + token/collection / show | −0.643%…+5.052% | −0.0330%…+0.0154% |
| Fusion + token/collection / index | −3.930%…+2.082% | −0.0092%…−0.0042% |

**Effects versus each run's off-A**, not a paired comparison between the two
separate on arms. Objects are window-mean allocations/request, not a claim
that every request allocates an identical integer count.

| Arm / route | Wall Δ [95% band] | Mean median µs, off → on | Objects/request, off → on |
|---|---:|---:|---:|
| Fusion / show | **+24.530% [+10.229, +39.125]** | 1,736.62 → 2,161.11 | **2,271.32 → 2,384.46 (+113.14)** |
| Fusion / index | **+18.937% [+14.060, +23.615]** | 1,764.42 → 2,098.10 | **2,387.84 → 2,524.04 (+136.20)** |
| Fusion + token/collection / show | +6.400% [+1.519, +14.121], unresolved vs A/A | 1,859.27 → 1,976.31 | **2,271.34 → 2,378.35 (+107.01)** |
| Fusion + token/collection / index | +5.773% [−0.205, +16.455], unresolved vs A/A | 1,919.24 → 2,026.50 | **2,388.31 → 2,518.36 (+130.06)** |

Both arms increase allocations well beyond their A/A bands. The composition
coverage completes token/collection **40/10 per ten show requests** and
**30/10 per ten index requests**, with **10 show form fallbacks and zero form
completions in the measured coverage window**. Its one earlier form hit is
an original witness, not a fused completion.

First-class secondary metrics (off-A → on means, show/index order): fusion
GC time is **0.124/0.101 → 0.167/0.150 ms/request**, RSS
**190,813/190,998 → 183,889/184,417 KiB**; composition GC time
**0.577/0.380 → 0.154/0.158 ms/request**, RSS
**181,409/181,785 → 179,585/179,673 KiB**. GC A/A is very wide; composition
RSS is unresolved and fusion RSS A/A is biased. These are retained
observations, not credited causal memory/GC wins. Fusion boot is
**3,009.58 → 2,996.88 ms**, setup **94.57 → 124.76 ms**; composition boot
**3,056.48 → 3,144.84 ms**, setup **94.78 → 172.66 ms**. Setup includes natural
original witnesses and compilation, not just generated method execution.

The handwritten **−26%/−37%** endpoint ceilings and accepted sealed
**−15.225536%** show price are **interpreter instruction counts**, not these
short native YJIT latencies. This body-only prototype achieves neither a
wall-time nor an allocation win; no difference or additive saving against
those prices is inferred. It leaves most renderer/collection/helper work
live. **Unverified hypothesis:** reflected method-chain checks and per-region
scope/buffer plumbing contribute the extra allocations. No causal profile or
larger-method/YJIT attribution was attempted after the kill.

## What this prototype actually fuses

`bench/experiments/fused_views.rb` compiles one Ruby method per action/HTML
format from the booted app's actual resolver templates and ERB compiled
source. It uses the stock compiled-method container, preserving the view's
constant lookup context. The blog show method contains the application layout,
show body and comment body; index contains the layout, index and article body.
Lexical locals are renamed to keep the separate template scopes.

Helpers remain live. `capture`, `content_for` (including Turbo's append/provide
interaction), the shared `view_flow` and named/default layout yields remain
Rails operations. Each template has a separate output buffer and restores
`@current_template`, `@virtual_path` and the previous buffer on exit.

This is **body fusion, not elimination of the entire render pipeline**. Rails
still selects, preloads and iterates collections, builds render wrappers,
dispatches partials and sends notifications. A known partial dispatch calls
the inline body inside the generated method; unknown templates stay stock.
The explicit partial list is a prototype input, not a general dependency-graph
discovery algorithm. No rendered output or model result is cached.

The action-level seam is `TemplateRenderer#render_template`, after the real
action, filters and assigns. It does not replace `process_action`. Entry checks
cover template/layout/view identity, paths, variants, sources and framework
method chains. Each copied region rechecks actual public render/body methods;
body checks occur after notification start. A changed body continues locally
through the current stock method, rather than replaying the action. The
regression test suppresses `method_added`, redefines the partial during its
notification and checks exact output plus once-only action execution.

## Eligibility and correctness evidence

All results use Ruby 4.0.7 / Rails 8.1.4. The retained accepted blog, **not a
regenerated app**, has archive SHA256
`b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`,
production source pin
`86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`,
and lock SHA256
`570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
Fresh schema/rows come from `BlogShowGetOnly.prepare`, never existing pending
work deleted to make a gate pass. Corpus setup is dependency-only.

* Warm production gate: off A, off B, fusion, sealed form/token/collection,
  and their attempted stack have identical status, **all literal headers**,
  HTML bytes, observed render/controller event fields/order, SQL/binds and
  database state for both routes at entropy seeds 0 and 1. Show is 5,680 bytes;
  index is 6,967 bytes. Database state is unchanged. This is **warm-only**;
  an earlier cold-index attempt differed in compilation notifications.
* Blog own unit/integration suite: **21 tests / 54 assertions** pass off/on,
  per-test outcomes and SQL identical. Browser suite: **2 / 14** pass off/on,
  per-test outcomes and SQL identical. Both methods and their partial bodies
  have nonzero fusion hits, including in the browser suite.
* Campfire `campfire-r81` rooms#show **refuses** explicit-local render options
  and its `cached: true` collection. No cache policy is changed. Its suite is
  **234 / 671** off/on; browser **8 / 60** off/on, identical outcomes and zero
  fusion hits. Browser own-thread SQL digests match, but other-thread digests
  differ and one total count is 544 vs 547: not full SQL equivalence. No
  Campfire production byte/DB certificate or performance result is claimed.
* Synthetic public rendering regression: **1 test / 12 assertions**, covering
  asymmetric collection locals, escaping, capture/layout slots and mutation.

The sealed reference is a normal public `build --sealed --env production
--jit yjit`, with explicit denylist selection of only form/token/collection;
it is not a hand-pruned manifest. Its four-request gate completes units
0/1/2 **2/14/4** times without fallback. The stack completes token/collection
**14/4**, but the form falls back twice: relocating its block changes its
source site and the real certificate says **unknown form site/options**.
Fusion therefore does not currently stack with the principal sealed form
saving. No source-location spoofing or admission relaxation is used.

## Exact, generally applicable design still needed

1. Discover a closed graph from the actual resolver, including layouts,
   prefixes, formats/locales/variants, explicit/strict locals and heterogeneous
   collection `to_partial_path` decisions. A new/unknown edge must execute
   stock without repeating previous helpers or queries.
2. Preserve lexical scopes/CREF, buffer ownership, safety/encoding, capture,
   shared flow, layout yields, exceptions and live notifications. Helpers
   cannot be flattened merely because their names look familiar. Method,
   source-line, block-source and ISeq introspection need a refusal boundary.
3. Certify resolver/compiler/template/config and actual method facts at each
   live evaluation boundary, or establish a valid sealed contract; ordinary
   mutation hooks alone are insufficient. This prototype's finite checks and
   accepted no-introspection contract are not that general certificate.
4. Cached collection hits/misses, digest keys, instrumentation and cache
   writes must retain their exact ordering and behavior. Streaming requires
   a different lazy buffer/flow execution model. Both are refused here;
   strict locals, custom resolvers/non-ERB handlers, control-flow/introspection
   shapes and render options/blocks are also refused.
5. Teach the sealed form certificate about a trustworthy generated source
   map and block provenance if fusion is to compose with it. Retaining live
   helpers avoids reimplementing their semantics, but also leaves most of
   the handwritten endpoint ceiling's work untouched.

Reproduction entry points: `fused_views_gate.rb` is an untimed worker using
the existing source-pinned entropy companion; `fused_views_setup.rb` is an
own-suite preload that never forces controller autoloads. `fused_views_native.rb`
implements bet A's shared exploration setup/counters/untimed-validation
hooks; clocks and comparisons belong to the unchanged shared native harness,
not a fork. Its timed calls never use the untimed entropy hook. The optional
hook requires a fixed ordinary request-ID header, as in the independent exact
gate; the native screen here did not invoke that hook.
