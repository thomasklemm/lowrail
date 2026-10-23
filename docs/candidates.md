# Next lowerings: measured research shortlist

2026-10-20. **Research, not a pass implementation or a request-speedup claim.**
Production, Lowrail absent, Ruby 4.0.7 +YJIT, the five `script/corpus` pins.
Read with [the pass contract](ARCHITECTURE.md), [PLAN §9](PLAN.md#9-strategy-after-m0-2026-10-20)
and [the benchmark cautions](bench.md). No application, `src/`, or `gem/lib/`
implementation was changed for this research.

## Recommendation

Start with **Inertia configuration binding**, then a deliberately narrow
**whole compiled-ERB variant**, not another single route helper. Keep the
other candidates as small experiments, not promises of material gains.

Follow-up: [the ERB investigation](passes/erb.md) rejected literal-run fusion
(2 sites across five apps) and found no certifiable I18n epoch or completed
Campfire URL lowering on the profiled room. No compiled-template pass was
retained; [template lookup (#3)](passes/template-lookup.md) is now surveyed
and parked: cache clears defeat identity-only guards, and the small ceiling
does not justify a new resolver epoch. The original budgets below remain
hypotheses, not achieved savings. [Candidate #4](passes/tag-options.md) was
surveyed as one tag/form component and parked as upstream-solved by Rails
[49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b).
Estimated pre-guard saving is only ~0.3–0.45% blog edit / ~0.2–0.3% Campfire;
the broader 4.46% / 2.90% envelopes are costs, not savings. No guarded
backport was built. It remains the cheapest later component-pass pilot.

The ranking uses the sum of the best measured-route opportunity in each
app, divided by guard complexity. This equals mean effect on covered apps ×
breadth ÷ complexity; it does **not** assume a production traffic mix.
Complexity is an explicit engineering judgment, not a measured duration.
Ranges start at zero where eligibility or full guard costs remain unproved.
Numbers are **reduced request time**, not throughput increases.

| Rank | Candidate | Best per-app request budget | Objects saved/request | Breadth; complexity; score |
|---|---|---|---|---|
| 1 | `inertia/config_bind`: copy live options without reinterpreting the fixed option schema | PingCRM **0.65%**, Redprints JSON **1.49%**, starter JSON **3.93%** | **10 / 18 / 22**, respectively | 3/5; 2; **3.03** |
| 2 | `view/compiled_template`: specialize an entire compiled ERB body, known helpers/locals, dynamic values retained | Blog edit **0–2.79%**, from two field groups, not the whole rendering share | **0–194** | 1/5 demonstrated helper coverage; 5; **0.56** ceiling |
| 3 | `view/template_lookup`: constant-target lookup plans, retaining Rails rendering | Blog edit **0–0.42%**, Campfire uncached room **0–0.24%**, Ping HTML **0–0.08%**, Redprints HTML **0–0.23%** | approximately **0–14 / 247 / 14 / 32**; see allocation cap below | 4/5; 4; **0.24** ceiling |
| 4 | `view/tag_attributes`: fold literal attribute fragments, keep dynamic attributes/escaping | Blog index **0–0.21%**, Campfire uncached room **0–0.08%** on the narrower, non-`link_to` census | **0–12 / 30** | 2/5; 2; **0.15** ceiling |
| 5 | `serialization/fixed_shape`: Jbuilder row extraction; **do not ship the measured Alba key-plan prototype** | PingCRM **0–0.18%**; Alba prototype instead costs Redprints about **0.29%** | Ping **0–10**; Alba **adds 20** | 1/5 positive; 3; **0.06** ceiling |
| 6 | `callbacks/empty_chain`: eliminate a proven-empty callback dispatch | **<0.006% on every app** | **0** | 5/5; 3; **0.004** |
| 7 | `active_record/app_chain`: full, escaping query-chain/SQL plans, beyond the existing reader pass | **0 credited**: no exact full-controller-chain prototype. Diagnostic ceilings are **21.11–22.18 µs/hit**, not eligible request hits | **0 credited**; diagnostic **38–44/hit** | 0 certified / 5 surveyed; 10; **0 credited** |

Score inputs use unrounded numbers. In rank 3, use the blog edit route rather
than adding its index route; likewise do not add HTML and JSON as if they
were different apps. The first two deserve exploration against the ≥2%
promotion criterion. Only rank 1 presently has a relatively direct,
guard-inclusive micro suggesting that threshold. **None has a Lowrail
request comparison or a `lowrail verify` support certificate here.**

The complexity weights charge separate fact/guard responsibilities: binding
has constructor/schema facts plus per-call storage shape (2); compiled ERB
adds compiler delivery, helper dispatch, local/buffer shape, I18n and form
state (5); lookup has source, resolvers/paths, details and locals (4); tags
have helper and attribute-shape contracts (2); serialization has descriptors,
getters and encoding policy (3); callbacks have chain definitions, mutation
and control-flow semantics (3). General AR plans combine source, methods,
schema/adapter, reflections/scopes, relation shape, connection/shard, current
scope, binds, terminal semantics and escaping-plan invalidation (10).

The large excluded target is Campfire CSP URL processing: **33.27% StackProf /
37.67% Vernier** on the response-cached room, approximately **4,528 objects**
inside that frame per request. It is not rank 1 because the straightforward
memo changes timeout semantics. Its exact, currently admissible budget is
**zero**, not a 33–38% win.

## 1. What actually transfers from Roundhouse

Surveyed public Roundhouse at
[`3ccc4a7`](https://github.com/rubys/roundhouse/commit/3ccc4a777d3f3369c01ef627ea69476e02575b81).
The source authorities are the
[ordered lowering pipeline](https://github.com/rubys/roundhouse/blob/3ccc4a777d3f3369c01ef627ea69476e02575b81/src/lower/mod.rs),
[specialization experiments](https://github.com/rubys/roundhouse/blob/3ccc4a777d3f3369c01ef627ea69476e02575b81/docs/pipeline/specialization.md),
[Fractal contract](https://github.com/rubys/roundhouse/blob/3ccc4a777d3f3369c01ef627ea69476e02575b81/docs/pipeline/fractal.md),
[analysis](https://github.com/rubys/roundhouse/blob/3ccc4a777d3f3369c01ef627ea69476e02575b81/docs/pipeline/analyze.md)
and [runtime](https://github.com/rubys/roundhouse/blob/3ccc4a777d3f3369c01ef627ea69476e02575b81/docs/pipeline/runtime.md).
The following groups cover the relevant lowering families, not every tiny
normalization module in that directory.

| Roundhouse lowering / experiment | What becomes static; required knowledge | Inside real Rails, exactly? |
|---|---|---|
| `arel/`, `scope_chain`, `chain`, association/persistence/model lowerers | SQL algebra, predicates, scopes, association targets, validation and model bodies; schema, adapter, receiver and bind types, reflection/DSL facts | **Partly.** Keep real relations, rows, callbacks, query cache, lazy loading and authorization. Static SQL/planning can transfer; emitted replacement models and direct row slots cannot simply be installed. Rank 7; existing preload/reader/instantiate experiments are controls, not fresh opportunities. |
| `view_to_library`, `form_with`, `form_builder`, `tag_builder`, `capture_inline`, `partial_qualify` | Fully lowered template functions; eliminate FormBuilder interpretation, resolve partial calls, build strings directly; view locals/ivars, helper dispatch, options, output-safety facts | **Yes in a restricted body.** Keep ActionView's outer render/instrumentation/buffer contract and dynamic helper calls as residue. Guard compiled source, receiver methods, locals, locale/config. Form state, CSRF, rich text and custom builders cannot be boot constants. Ranks 2–4. |
| `jbuilder_to_library`, `as_json_shape`, `as_json_writer`, `as_json_poro`, `to_json` | Known field names and direct getters, sometimes direct JSON string output; object/reader types and serializer DSL | **Yes for closed shapes**, retaining getter order, conditions, null behavior, key formatting, JSON encoding and exceptions. Direct JSON-string output is not a drop-in replacement for a Hash-returning Inertia prop. Rank 5; measured Alba key-only version loses. |
| `config_reader`, importmap lowering, literal/constant folds | App configuration readers and static importmap functions; initializer assignments, config schema and values | **Shape specialization transfers**, not freezing arbitrary config or caching personalized values. Rank 1. App URL resolvers/procs remain live. URI timeout blocks the tempting CSP memo. |
| `send_dispatch`, forwarding/delegation, `try_guard` | Finite method-name sets become direct branches; receiver types, complete name set and method resolution | **Conditionally.** Unknown names must call the original `send`/`public_send`, not Roundhouse's emitted error arm. Preserve visibility, singleton overrides and `method_missing`. Jbuilder extraction is a measured instance; a standalone dispatch win beyond YJIT is not established. |
| controller/filter dispatch, model validations/callback hooks | Declarative chains become straight-line calls; ordering, conditions, action applicability, callbacks and inheritance | **Conditionally.** Must preserve halt/around/ensure/error behavior, callback recompilation and gem hooks. Empty-chain subset is measurable but negligible (rank 6); 85–94% inclusive `run_callbacks` is the action body, not removable dispatcher cost. |
| routes / URL options | Named helpers and dispatch tables become string operations/direct dispatch; route table, defaults, parameterization, host/config facts | **Named helpers already transfer** in Lowrail. Generic recognition and complete dispatch are different: middleware, constraints, engines, authorization and request state stay live. Existing ~2× helper micros do not establish a new request-sized opportunity. |
| ActiveSupport, I18n, strong params, time/duration, booleans, rich-text/storage APIs | Typed utility operations and Rails dialect become replacement-runtime calls; exact types, locale/backend/config/API semantics | **Selective only.** Literal label/tag work is included in rank 2; casting, sanitization and dynamic formatting still run. Strong-param writes are not exercised by these GET workloads: zero measured hits/budget, not zero possible cost in write-heavy apps. No independent positive micro supports another utility pass here. |

### Runtime and the replacement boundary

Strict language targets consume the lowered typed IR and call Roundhouse's
runtime, not Rails. `runtime/ruby/` is the shared framework implementation
(AR, controllers, views, dispatch, etc.), paired with RBS; most targets
transpile it, while Ruby-family targets copy/tree-shake that Ruby source.
Per-target primitives supply DB/server/cable integration. Eliminating an
entire FormBuilder or replacing AR objects there is not evidence that the
same saving is possible while every real gem hook remains observable.

Futamura runs analysis **without** the strict post-analysis lowerings. Its
own query specializer emits Rails `StatementCache` plans and real Rails
preload operations, retaining unsupported residue and original fallbacks.
Fractal provides a useful whole-method delivery shape: normal `def`, own
ISeq/JIT profile, lexical nesting/file/line/visibility preserved, install-time
definition guards. **At the surveyed revision Fractal registers zero passes
and emits nothing. There is no measured Fractal speedup to borrow.** Its
effect-based replay verifier is not itself a proof of arbitrary purity.

### Published experiment results, with their actual scope

| Experiment | Measured result in Roundhouse's documentation | Interpretation for Lowrail |
|---|---|---|
| Futamura query chains | Campfire chain **4.83 → 4.61 ms**; whole page **40.97 → 41.07 ms**; Lobsters pass **1,353 → 1,358 ms** | Null request result. Removing relation/SQL interpretation is not removing preloads or database/model work. |
| Planned preloads | Campfire chain **4.78 → 3.82 ms**; page **40.99–41.39 → 39.84–40.19 ms**; `Session.find_by` **115 → 104 µs**, `Account.first` **167 → 98 µs** | Real evidence for planning, not a guarantee on a different Rails/app pin. The lookup gains are not all preload-only. Lowrail's own guarded preload pass subsequently regressed uncached room **10.2%** and presentation **19.3%**. |
| Both in-Rails specializations | Lobsters **1,167 → 1,149 ms**, about **1.02×**, versus replacement Ruby about **4.2×** | The cited roughly **2× ceiling** is a workload-derived estimate with real Rails objects, not a universal bound. |
| Whole-route replacement in `Ruby::Box` | Eligible routes **2.3–4.7×**; full visit sequence **1,264 → 1,085 ms**, **1.17×**; in-Rails-only **1,249 → 1,490 ms** with `RUBY_BOX=1`, about **19% tax** | **Not Lowrail's base contract.** Ruby 4.1+, currently SQLite/GET only; separate model object graph and cache. Session, flash and lent DB connection cross the boundary, not model instances. Rails cache invalidation is not shared. |
| Earlier every-GET prototype | **377 ms**, about **3.3×** | Different eligibility/coverage; not the measured partially eligible system above, nor evidence for exact partial replacement of arbitrary gem-backed Rails behavior. |

### Type inference: useful candidate discovery, not a certificate

Schema seeds column types; associations seed `Relation[T]` and model readers;
controller/filter ivars flow to views and collection elements to partial
locals. RBS/core catalogs and Rubydex lexical constant resolution fill dispatch
registries. Whole-program return harvesting and call-site parameter unification
iterate to a fingerprint fixpoint, capped at **12** rounds; carried types are
bounded at **512 nodes / 16 container levels**, widening cuts to `untyped`.
Effects are collected after typing. At this pin the effect recognizers mostly
cover DB reads/writes and controller response IO; time/random/network/log/raise
effect classes are dormant, and unknown AR effects do not imply purity.
An observed `String`, finite name set or empty effect set therefore cannot
justify suppressing a proc, mutation, timeout or gem hook. Lowrail needs boot
facts plus invalidation and per-call shape checks, with original residue.

## 2. Measurements and denominators

Pins and fixtures are those of `script/corpus`, [blog M0](m0/real-blog.md),
[Campfire M0](m0/campfire.md) and [Inertia M0](m0/inertia.md). Campfire is
Rails 8.2 alpha; the other apps use Rails 8.1.3/8.1.4. Inertia versions are
3.23.0 / 3.21.2 / 3.22.0. Redis, disposable PostgreSQL and the starter's real
Node SSR server ran locally in supervised services. Setup probes checked
authentication, intended content, JSON, healthy SSR HTML, unsigned 302 and
stale-version 409. No private app data was used.

For each case: fresh production process, eager load, assert Lowrail absent and
YJIT enabled, **400 warmups**, then **five × 500 requests** without profiler,
GC enabled throughout. Report median block means, not latency percentiles or
independent-process confidence intervals. Baseline CPU/wall, objects and GC
use monotonic/process clocks and `GC.stat` deltas. All requests returned 200;
the Rack body was consumed. No native benchmark/build jobs overlapped these
final timing blocks. StackProf 0.2.28 then captured 500 requests, **wall mode,
100 µs, raw stacks**. Vernier 1.11.0 captured a separate fresh process after
the same warmup, **1 ms / every 100th allocation, 500 requests**. Earlier
combined-process blog/cache captures were replaced, not mixed into the table.
An independent 20-request TracePoint probe supplies call counts; another
untimed probe distinguishes empty callbacks and non-link string-class tags.

| Case | Wall µs/req | CPU µs/req | Objects/req | Unprofiled GC µs/req | StackProf raw samples | Vernier weighted samples |
|---|---:|---:|---:|---:|---:|---:|
| Blog index `/articles` | 1,983.37 | 1,983.14 | 2,378.19 | 138 | 17,989 | 1,223 |
| Blog edit `/articles/1/edit` | 1,341.81 | 1,340.86 | 1,716.17 | 98 | 13,242 | 886 |
| Campfire room, response cached | 2,755.41 | 2,761.31 | 6,158.94 | 306 | 28,093 | 1,622 |
| Campfire room, response cache off | 15,570.95 | 15,593.41 | 22,672.64 | 1,468 | 174,750 | unavailable |
| Campfire stream, response cache off | 10,458.08 | 10,475.18 | 16,277.67 | 870 | 100,466 | unavailable |
| PingCRM organizations JSON | 3,361.16 | 2,627.12 | 2,529.66 | 144 | 31,464 | 1,723 |
| PingCRM organizations HTML | 3,603.07 | 2,874.59 | 2,943.71 | 174 | 32,662 | 1,954 |
| Redprints proposals JSON | 1,962.99 | 1,962.67 | 2,896.40 | 122 | 20,549 | 1,071 |
| Redprints proposals HTML | 2,413.28 | 2,412.69 | 3,424.52 | 186 | 23,580 | 1,470 |
| Starter dashboard JSON | 1,140.35 | 1,140.16 | 1,242.54 | 78 | 14,193 | 855 |
| Starter dashboard HTML + SSR | 5,133.25 | 3,190.07 | 1,974.80 | 392 | 33,506 | 2,538 |

These are local cost denominators, not replacements for the independently
booted off/off controls required by `bench/request_pairs.rb` before a pass
speed claim. Existing M0 StackProf results are retained for comparability:
Inertia JSON binding shares were **2.14 / 3.13 / 6.94%** (Ping/Redprints/starter,
two-route aggregates); here they are **1.99 / 2.81 / 5.77%** (one route each).
Differences in route mix, GC phase and sampling preclude treating these as a
before/after performance comparison.

### Target frames, not framework-area totals

Entries are **StackProf inclusive % / Vernier inclusive % / Vernier objects
per request inside the frame**. Union stacks once per category; never sum
overlapping parents and children. They are target budgets, **not savings**.

| Target | Blog | Campfire | PingCRM | Redprints | Starter |
|---|---|---|---|---|---|
| Configuration binding, JSON | 0 | 0 | **1.99 / 1.86 / 21.8** | **2.81 / 4.39 / 47.2** | **5.77 / 6.08 / 53.6** |
| Compiled-template rendering, HTML | edit **47.36 / 47.40 / 1,046.8** | uncached room **70.06 / n/a / n/a**; cached **0** | **9.23 / 7.47 / 299.8** | **43.99 / 45.65 / 2,100.2** | **5.34 / 4.53 / 241.0** |
| Label/text-field/textarea helpers | edit **12.48 / 12.53 / 347.4** | no matching simple field groups credited | 0 | 0 | 0 |
| Template lookup, HTML | edit **0.61 / 0.45 / 14.0** | uncached room **0.56 / n/a / n/a**; cached **0** | **0.40 / 0.56 / 13.8** | **1.36 / 1.43 / 32.4** | 0 |
| `TagBuilder#tag_options`, HTML | index **5.14 / 4.58 / 189.8** | uncached room **3.85 / n/a / n/a**; cached **0** | **1.29 / 0.82 / 53.6** | **1.87 / 2.11 / 43.0** | **0.68 / 0.75 / 38.6** |
| Jbuilder fixed row getters, JSON | 0 on measured HTML | 0 on measured routes | **0.95 / 0.99 / 40.0** | 0 | 0 |
| Alba key/attribute dispatch, JSON | 0 | 0 | 0 | **17.88 / 17.55 / 1,089.4** | 0 |
| Arel construction/visitors | index **2.72 / 3.11 / 91.4** | uncached room **3.73 / n/a / n/a** | JSON **3.46 / 2.44 / 104.2** | JSON **1.43 / 1.03 / 30.0** | no samples |

Template lookup includes `LookupContext::ViewPaths#find` and `PathSet#find`;
aliases are reported under their defining module/method, not `find_template`.
The templates already have compiled ISeqs: **compiling ERB again is not the
optimization**. The opportunity is removing interpretation of known helpers
and descriptions inside that compiled method. In particular Redprints' HTML
template total includes dynamic Alba/JSON prop evaluation. It is not 44%
static markup that can disappear.

### Vernier GC and GVL observations

| Case | GC pause % of profiled main-thread span | Voluntarily GVL-released % | Waiting-for-GVL % |
|---|---:|---:|---:|
| Blog index / edit | 6.32 / 13.23 | 0.74 / 0.92 | 0.21 / 0.28 |
| Campfire cached | 10.33 | 0.54 | 0.18 |
| PingCRM JSON / HTML | 10.51 / 12.83 | 17.34 / 15.33 | 0.22 / 0.19 |
| Redprints JSON / HTML | 7.88 / 8.11 | 0.71 / 0.57 | 0.21 / 0.16 |
| Starter JSON / HTML | 5.76 / 7.29 | 1.02 / **40.57** | 0.31 / 0.19 |

These percentages come from Vernier marker durations, not CPU samples;
GC is a nested activity, so do not add these columns as disjoint states.
Allocation sampling totals reproduce native objects/request to about one
object, but frame attribution is sampled and much less precise. These are
Ruby objects, not bytes, retained heap, or Node allocations. Profile overhead
and fresh-heap phase change GC: these GC shares must **not** be applied to
native latency as a second additive gain. Starter HTML mostly releases the
GVL for SSR IPC; optimizing Ruby cannot remove Node's personalized rendering.
No contention/throughput conclusion follows from one request-driving thread.

**Vernier limitation retained:** uncached Campfire room and stream hung in
the native collector. A separate fresh 100-request room attempt hung too;
reducing allocation sampling to every 1,000 objects did not produce a profile
before its bounded timeout. GDB found main thread in
`TimeCollector::record_newobj` waiting on the collector mutex, with sampler
and AR reaper also waiting there. Hung processes were terminated; no GC was
disabled, threads removed, or app code modified to obtain a successful file.
The successful cached Campfire profile covers that app, but **uncached
Vernier allocations/GC/GVL remain unavailable**, not zero. Use native GC.stat
and StackProf for those routes; uncached allocation-saving estimates below
come from the isolated micro and hit census, not a fabricated Vernier sample.

## 3. Isolated savings and request arithmetic

Scratch prototypes booted the real apps, retained fresh return objects and
checked outputs/classes (configuration also checked controller identity and
unshared options). Five alternating-order rounds of **50,000 calls**, after
2,000 warmups per arm; CSP used 2,000 calls/round. GC stayed enabled. These
are single-process medians, not multi-cohort uncertainty estimates. `G[0]`
models an already-valid method-fact guard; relevant per-call checks are
included, but complete invalidation machinery/certificates were not built.

| Micro | Original → prototype µs/call | Original → prototype objects/call | Qualification |
|---|---:|---:|---|
| Inertia bind, PingCRM | **5.226 → 0.873** | **5 → 3** | Config class + Hash + default/identity policy + exact ordered-key check; fresh Configuration, fresh options copy, live values |
| Inertia bind, Redprints | **4.066 → 0.818** | **5 → 3** | Same; neither app's source configuration was frozen |
| Inertia bind, starter | **5.028 → 0.951** | **5 → 3** | Same checks; source options happened to be frozen, no new freezing |
| Compiled label + text field, blog | **21.017 → 1.396** | **106 → 8** | Entire compiled fragment variant; Rails-oracle envelope, dynamic local escaping + locale check |
| Compiled label + textarea, blog | **18.983 → 1.207** | **104 → 8** | Same; checked special characters, empty value, leading newline and `</textarea>` |
| Warm partial lookup, blog | **2.866 → 0.047** | **19 → 0** | Details-key + view-path identity checks; **not** complete resolver invalidation |
| Mixed literal class / dynamic id attributes, blog / Campfire | **1.361 → 0.659 / 1.611 → 0.743** | **7 → 5** | Preserve dynamic `tag_option` escaping; full literal/source certificate not implemented |
| Entire literal class + data attributes, blog / Campfire | **2.665 → 0.146 / 2.972 → 0.171** | **14 → 2** | Fresh string; **not** used as the price for every corpus tag call |
| Jbuilder row, PingCRM | **0.877 → 0.286** | **2 → 1** | Existing builder's real `_scope { extract! ... }` versus fresh Hash of the same five live getters |
| Alba key-plan row, Redprints | **6.063 → 6.352** | **24 → 25** | Keep fetch/proc/error paths, compare descriptor metadata; **negative** |
| Empty callbacks, five apps | saving **0.0198–0.0225** | **0 → 0** | Rails already has an empty-chain fast path |
| Campfire CSP memo, **inadmissible** | **992.866 → 0.167** | **5,334 → 2** | Counterfactual only: would suppress timeout-sensitive URI work; input shape differs from request capture |

Configuration controls matched for changed live option values, a callable
that must not be evaluated while binding, fresh copies, and unknown-key
fallback with the same ArgumentError. Hash default values, default procs and
identity-comparison policy also matched through fallback: `dup` alone would
preserve policies the original keyword extraction discards. Final binding
micros include those three checks. Freezing mutable global configuration
would have manufactured eligibility and was **not** done. The initial
frozen-only prototype would have had zero PingCRM/Redprints hits and was
discarded in favor of the measured shape check.

One bracketed YJIT Callgrind diagnostic of the **earlier ordered-key-only
variant** reused **`bench/callgrind.c`** as it stood at
[`035dce3`](https://github.com/thomasklemm/lowrail/commit/035dce3613d5e44a9f1df1db8f81182374e807e7) and its
`--instr-atstart=no --smc-check=all-non-file` flags for PingCRM binding.
N=0 client dumps were **2,752 Ir** in both arms; N=50,000 dumps were
**3,560,201,456 / 355,133,537 Ir**. After seam subtraction: **71,203.97 →
7,102.62 instructions/bind**, about **90.0% less software-executed work**.
GC during the bracket remained included: **5 / 3 minor collections**, no
major collections. This is one diagnostic pair, no off/off confidence gate,
not a request or PMU result, nor an instruction measurement of the later
default/identity-policy checks. As [bench.md](bench.md) warns, instruction counts
still reflect GC phase and YJIT work; do not treat this as a 90% request win.

For the following table,
`saved_us_per_hit × hits_per_request / wall_us_per_request × 100`
is the expected request-time reduction; allocations use the analogous
per-hit difference. Values are optimistic opportunity estimates unless
explicitly described as the guarded binding micro. **Do not add rows**:
template, tag and lookup specializations overlap, and existing `link_to`
already removes some tag work when enabled.

| Candidate | Blog | Campfire | PingCRM | Redprints | Starter |
|---|---|---|---|---|---|
| Config bind | 0 hits; **0 / 0 objects** | 0; **0 / 0** | **5 hits**, 21.76 µs; **0.65% JSON / 0.60% HTML**, **10 objects** | **9 JSON / 4 HTML**, 29.23 / 12.99 µs; **1.49% / 0.54%**, **18 / 8 objects** | **11 JSON / 5 HTML**, 44.85 / 20.39 µs; **3.93% / 0.40%**, **22 / 10 objects** |
| Whole compiled ERB helper specialization | Edit: **1 text-field + 1 textarea group**, 37.40 µs; **0–2.79%**, **0–194 objects**. Index: no matching groups, **0 credited** | **0 credited**: rich-text builder is not either simple-field prototype; cached body not rendered | **0 credited** beyond separately priced lookup/tags; no matching field groups | **0 credited**: dynamic JSON/Alba evaluation retained, no matching field groups | **0 credited**: dynamic SSR retained, no matching field groups |
| Template lookup | **2 finds**, 5.64 µs; **0–0.28% index / 0–0.42% edit**, sampled allocation budget **0–15 / 14** | Cached **0**; uncached room **13 finds**, 36.65 µs, **0–0.24% / 247 objects**; stream **5**, 14.09 µs, **0–0.13% / 95 objects** | JSON **0**; HTML **1**, 2.82 µs, **0–0.08% / 14 objects** | JSON **0**; HTML **2**, 5.64 µs, **0–0.23% / 32 objects** | **0 exact finds** in census; **0 credited / 0 objects**; `find_all` is not the priced operation |
| Literal attribute fragment | Index **≤6 non-link string-class calls**, 4.21 µs; **0–0.21% / 12 objects**; edit **≤2**, **0–0.10% / 4 objects** | Cached **0**; room **≤15**, 13.03 µs, **0–0.08% / 30 objects** | HTML **11 total tag calls but 0 matching class shapes**; JSON **0**; **0 credited / 0 objects** | HTML **7 total but 0 matching shapes**; JSON **0**; **0 credited / 0 objects** | HTML **8 total but 0 matching shapes**; JSON **0**; **0 credited / 0 objects** |
| Serializer shape | **0 / 0** on measured HTML | **0 / 0** on measured room/stream | **10 Jbuilder rows**, 5.91 µs; **0–0.18% JSON / 0–0.16% HTML**, **0–10 objects** | **20 matching proposal rows** among 22 resource hashes; measured key-plan **adds 5.78 µs / 20 objects**, about **0.29% slower JSON / 0.24% HTML**; accept **0 savings**, refuse this prototype | No matching serializer; **0 / 0** |
| Empty callbacks | **1 hit**, **≤0.0017% / 0 objects** | **2** uncached, **≤0.0003% / 0** | **2**, **≤0.0013% / 0** | **3**, **≤0.0035% / 0** | **3**, **≤0.0053% / 0** |
| App query-chain plan | **0 certified hits, 0 credited µs/objects**; simpler `includes.order` exists | **0 certified**; diagnostic price 21.11 µs / 38 objects. Even assigning it to all **14 row-load calls** would be only **1.90% / 532 objects**, not actual eligible coverage | **0 certified**; 22.18 µs / 44 objects. All **3 row-load calls** would imply **1.98% / 132 objects**, again not chain eligibility | **0 certified / 0 credited**; 2 row loads and 1.43% Arel share do not establish a transferable per-hit price | **0 certified / 0 credited**; 2 row loads, no observed Arel samples; Rails' existing find cache already does planning |

Lookup allocation budgets are **min(micro difference × finds, sampled
inclusive objects)** where Vernier exists, rounded. The micro's 19 objects
include synthetic argument/lookup setup not identical to every real caller;
do not promise 38 saved objects when the observed frame owns about 14.
Uncached Campfire lacks that cross-check, hence its much weaker ceilings.
Likewise a string-valued class observed at runtime is **not proof it is a
literal in source**: the tag hit counts are upper bounds after excluding
existing `link_to`, not a completed eligibility ledger.

The ERB fragments are actual `ActionView::Template` compilations with known
locals in the blog app, **not a rewritten production `_form`**. Its real form
has FormBuilder options, errors and model state not present in those little
fragments. Two observed field groups price the hypothesis; the range starts
at zero until those semantics and their guard cost are covered. Campfire's
175 total tag calls are emphatically not 175 eligible hits at the 2.8 µs
fully-literal price. This narrower census materially changes its priority.

## 4. Top-three sketches in the pass contract

### 1. `inertia/config_bind`

- **Current boundary:** sealed-only after the [suppressed-hook audit](passes/suppressed-hooks.md);
  the guarded sketch below is historical, not permission to select `+inertia_config`.
- **Kind/default/needs:** runtime, sealed opt-in; `booted_app` + method facts;
  `Configuration#bind_controller` normal method variant, fresh result.
- **Facts:** gem/Ruby/compiler identity; `Configuration.new`, `allocate`,
  `initialize`, `bind_controller`; Hash extraction/copy behavior and the
  ordered `OPTION_NAMES` schema. Build records the supported ordered key set,
  not user option values or controller instances.
- **Guard:** method variant under shared invalidation; per call require the
  exact Configuration/Hash classes, ordinary Hash defaults/comparison policy
  and canonical ordered keys. Copy **current**
  options into a fresh mutable Hash and attach **this** controller. Neither
  dynamic option proc evaluation nor the output of that evaluation is cached.
  An options object/key change must fall back unless it matches the supported
  schema. No change to app freezing policy. Preserve original body/visibility.
- **Refusals:** `configuration_subclass`, `noncanonical_options`, `hash_policy`,
  `constructor_override`, `schema_changed`, `unsupported_gem_version`.
  Verify mutation, unknown keys, callable options, controller-specific reads,
  fresh identities and method redefinition; record hits for each app/version.
- **Bench:** three app-specific bind micros above; next measure paired real
  requests with guard/stat machinery off during timing. Do not enlarge the
  target to all shared props based on their inclusive wrapper time.

### 2. `view/compiled_template`

- **Kind/default/needs:** source/template unit, opt-in;
  `facts` + compiled-template source/compiler recipe + `oracle`, optionally
  `observed` to prioritize locals/types. Deliver through the existing template
  seam; **one body variant/guard per template**, not dozens of tiny guards.
- **Facts:** source and compiled-handler digests, helper owners/bodies including
  singleton view overrides, local names/shapes, safe-string behavior, literal
  option order/encoding, relevant I18n backend/locale/config and builder facts.
  Build-time probes derive constant envelopes and escaping from real Rails.
- **Guard:** view-class-aware `call_site`/template-body guard plus cheap local
  type/state checks; use a method variant only if its own ISeq can be delivered
  with the original signature. Keep the outer render, instrumentation, buffer
  ownership, `content_for`, dynamic arguments/getters and their evaluation
  order. Guard *before* side effects; never restart the whole template after
  a partial fast-path execution. Unsupported inner expressions stay original
  residue; invalidate the unit when helper/I18n/template facts change.
- **Refusals:** `dynamic_locals`, `custom_builder`, `uncertified_helper`,
  `mutable_i18n_without_epoch`, `dynamic_capture`, `escaping_mismatch`,
  `rich_text_semantics`, `compiler_recipe_changed`. CSRF/session values,
  errors, IDs, record state, rich text and SSR output remain dynamic. If their
  operations cannot be preserved, refuse that region rather than the app.
- **Bench:** exact real `_form` next, success and validation-error states,
  special characters, SafeBuffer/subclasses, newline/encoding, locale/helper
  changes and cold/warm fragment caches. The 37.40 µs / 194-object envelope
  hypothesis must survive these guards and `lowrail verify`; the 47% template
  total is not its expected saving.

### 3. `view/template_lookup`

- **Kind/default/needs:** source call-site plan or narrow runtime lookup
  variant, opt-in; `facts` + `booted_app` + oracle resolution of constant
  target, prefixes, format/locale/variant and local-name signature.
- **Facts:** template/source digests, view paths and resolver implementations,
  compiled-template identity, all resolution details and local keys. Custom
  mutable resolver state needs an actual invalidation source; object identity
  alone is not enough. `find_all`, `exists?`, dynamic polymorphic partials and
  collection rendering are separate operations, not presumed hits.
- **Guard:** `call_site`/method variant with resolver/path/details epoch and
  cheap per-call details/local signature checks. Return the real Template;
  Rails still renders and instruments it. Preserve missing-template errors,
  strict locals and fresh per-render state. No rendered HTML cache.
- **Refusals:** `dynamic_partial`, `mutable_resolver_without_epoch`,
  `details_mismatch`, `locals_mismatch`, `reloading`, `template_changed`.
  Test view-path replacement, resolver mutation, locale/format/variant and
  missing templates. The identity-only scratch micro is **not** this complete
  guard design. With <0.5% opportunity, abandon it if full checks eat the gain.

## 5. Why not chase the largest-looking frames first?

- **CSP/importmap URI memo:** the measured near-1 ms counterfactual is enticing,
  but Rails sets `Regexp.timeout = 1`; reusing a result can suppress an exception
  the original regex/URI work could raise. Request base URL, host/port,
  relative root, asset prefix and input bytes/encoding also remain inputs.
  Guarding timeout to `nil` yields **zero eligible hits in these unchanged
  apps**, not permission to turn it off. See [memo refusals](passes/memo.md).
  The [parallel importmap investigation](passes/importmap.md), now on main,
  independently confirms the ownership and refusal. Its boundary probe at
  `1e-9` seconds makes the difference concrete; it does not claim the ordinary
  90 URLs time out at Rails' default one second. Its application-owned cache
  draft has different semantics and failed native/instruction A/A controls;
  neither that draft nor its request deltas are a new exact Lowrail candidate.
- **Asset digests:** all three public Inertia apps use eagerly computed String
  versions, **zero request-time digest calls in the existing 400-request
  positive-controlled traces**. The historical −14% page in
  [Private Rails app with Inertia Rails](m0/private-inertia-app.md) is not an
  opportunity measured in these five apps. Do not change their initializers to create one.
- **Preload/instantiate/attribute slots:** repeat the existing negative controls,
  not Roundhouse's older positive pin. Preload regressions are real; Rails 8.1
  already caches the builder that helped the 8.2 alpha load-only micro;
  guarded direct attribute access cost more than the ~0.03–0.05 µs it removed.
- **Message fragment keys:** uncached room/stream show **13.62 / 19.49%**
  inclusive key construction, but that contains live association traversal,
  timestamps and cache invalidation dependencies. A key string cannot be a
  boot constant. No exact prototype justified crediting that whole share.
- **General props/Alba:** deep prop traversal totals wrap callable evaluation;
  Redprints' 17.9% attribute dispatcher wraps model getters/formatting. The
  conservative key-plan actually regressed. A full generated serializer could
  be a later variant, but needs a better micro than this measured failure.

## 6. Reproduction recipe and evidence limits

Use the production/fixture/service commands in the linked M0 documents and
their existing `bench/*_setup.rb` scripts. Keep mode-0600 cookie/version
headers private. Do not put profile/heap files or credentials in Git.

The research drivers were scratch scripts, not added framework instrumentation.
The essential collection loop below can be saved **outside the app** and run
from each app root. Add profiler gem load paths before Bundler loads the app,
as `bench/requests.rb` does. Use separate processes for timing, StackProf and
Vernier, identical headers/path/data, and discard no failed captures silently.

```ruby
%w[stackprof vernier].each do |name|
  $LOAD_PATH.unshift(*Gem::Specification.find_by_name(name).full_require_paths)
end
require File.expand_path("config/environment", Dir.pwd)
require "json"
require "rack/mock"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "Lowrail loaded" if defined?(Lowrail)
abort "YJIT off" unless RubyVM::YJIT.enabled?
headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on"}.
  merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
client = Rack::MockRequest.new(Rails.application)
request = -> {
  response = client.get(ENV.fetch("ROUTE"), headers)
  raise response.status.to_s unless response.status == 200
  response.body
}
400.times { request.call }
n = 500
case ENV.fetch("PHASE")
when "stackprof"
  require "stackprof"
  profile = StackProf.run(mode: :wall, raw: true, interval: 100) {
    n.times { request.call }
  }
  File.write(ENV.fetch("OUT"), JSON.generate(profile))
when "vernier"
  require "vernier"
  Vernier.profile(out: ENV.fetch("OUT"), interval: 1000,
    allocation_interval: 100) { n.times { request.call } }
when "timing"
  rows = 5.times.map do
    before = GC.stat
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { request.call }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu
    after = GC.stat
    {wall_us: elapsed * 1e6 / n, cpu_us: cpu * 1e6 / n,
     objects: (after[:total_allocated_objects] - before[:total_allocated_objects]).fdiv(n),
     gc_us: (after[:time] - before[:time]) * 1000.0 / n,
     minor: after[:minor_gc_count] - before[:minor_gc_count],
     major: after[:major_gc_count] - before[:major_gc_count]}
  end
  File.write(ENV.fetch("OUT"), JSON.pretty_generate(rows))
end
```

Run with `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 LOWRAIL=0
RAILS_LOG_LEVEL=error ruby --yjit /absolute/scratch/profile.rb`; supply
`PHASE`, `OUT`, `ROUTE`, private `BENCH_HEADERS`, PingCRM's PG/host variables,
and `CAMPFIRE_RESPONSE_CACHE_MB=0` only for the uncached cases. The actual
StackProf capture followed the five timing blocks in that process; the loop
above permits isolated captures too, but do not assume identical heap phase.

For StackProf, decode `raw` as `[depth, frame_ids..., sample_weight]` records;
union target membership over each stack and divide by all raw-stack weights.
Reported totals/missed samples differ from that denominator. For Vernier,
select `isMainThread`, resolve `stringArray → funcTable → frameTable →
stackTable`, union targets over stack prefixes, then weight `samples`.
Sampled `jsAllocations.weight` here is an object-event count: multiply by
100/500 for estimated objects/request, not by object byte size. Sum main-thread
`GC_PAUSE`, `THREAD_SUSPENDED`, `THREAD_STALLED` marker intervals separately.
Do not sum inclusive parent/child allocation attribution.

To recreate the micro residue, use the **same full original operations**:
configuration `Configuration.new(**options, controller:)` versus
`Configuration.allocate` + fresh `options.dup` + controller assignment after
exact class/default/default-proc/identity-policy/ordered-key checks; template handler compilation on both sides,
with marker-derived literal prefix/suffix and `<%= value %>` residue; cached
`lookup.find_template("articles/article", [], true, [:article])` versus the
same real Template behind details/path checks; literal `tag_options` fragments
versus `static.dup`, or prefix + the real dynamic `tag_option`; existing
Jbuilder `_scope { extract!(record, :id, :name, :phone, :city, :deleted_at) }`
versus the five getters into a fresh String-key Hash. Never charge repeated
Jbuilder construction to each row: the real collection reuses its builder.
The Alba failure retained `fetch_attribute`, removal/error handling and
compared metadata while iterating pretransformed keys. A different generated
serializer is a new experiment, not the result reported here.

Next implementation gates remain the architecture's own: reason-coded
eligibility ledger, complete invalidation/fallback tests, `lowrail verify`
with real hits and identical outcomes/SQL, then independent-process
off/off-controlled request pairs. A positive micro or a successful profile
alone does not meet any of those support or speed-claim gates.
