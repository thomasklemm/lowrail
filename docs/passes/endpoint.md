# Endpoint/action: conservative generated slice

Opt-in only: `--passes default,+endpoint/action` (alias `endpoint`). Target:
`RealBlogR4::Application`, Rails **8.1.4**, `ArticlesController#index/show`.
Other applications/versions refuse at build time with a ledger reason. This
is the first reviewable slice of layer D, **not** the whole-route handwritten
ceiling, and it is not promoted to default.

## What is generated, and what stays live

The runtime builder runs in an off, booted application. It obtains Rails'
compiled template Ruby, including the partial-locals prologue, for the two
pages, article/comment collection partials and application layout. It emits
one method scope per template, and a controller `process` wrapper, into the
endpoint manifest payload. The compiler produces a fingerprinted ISeq factory.
There is no handwritten application HTML in the runtime gem.

The generated template body executes on the **real view context**, with the
same output buffer, virtual path, current template and block. Only the audited
stock, non-block, two/three-argument `link_to` body is expanded. Arguments run
once, in order, before its effective-method check. All its nested calls
(`convert_options_to_data_attributes`, `url_target`, `content_tag`) stay live.
Unsupported/custom helper implementations stay live, rather than refusing
the endpoint. Strict/unknown locals and lexical-scope-dependent template bodies
remain with Rails. In particular, the show template's unqualified `Comment`
must retain Rails' compiled-method constant scope: moving it to a generated
module would ignore a constant installed on the original compilation container
by a subscriber. Constant/class-variable reads, nested definitions, source
pseudo-variables and scope introspection therefore refuse per template. The
other four bodies are eligible; show still hits through its layout/partials.
Collection and single-partial locals are distinct shapes; this slice only
inlines the certified collection shape.

**Everything outside those bodies stays Rails:** Rack, routing, session,
cookies, flash, CSRF, logging, exception handling, callbacks, action methods,
assignments, AR queries/objects, `Comment.new`, resolver, collection/layout
renderers, assets, forms, tags and translations. Instrumentation is not
re-created: the original Rails instrument calls execute in their original
nesting and order with their original payloads and live controller/view state.
There is no subscriber-absence certificate.

For eligible templates the delivery seam invokes the actual handler once
and checks its exact generated code before accepting the original body. This
supersedes overlapping default template splices so that a second lowerer
cannot silently change the body being certified. The stacked benchmark must
account for this lost default-pass opportunity, not just the new helper sites.

## Entry and local continuation

The process wrapper grants permission once before callbacks/action execution:

| Entry fact | Current exact check |
|---|---|
| Request | GET, resolved HTML, no variant, exactly controller/action keys (+ id for show) |
| Controller | captured core class lookup; named constant resolves to that exact class |
| Callback chain | same chain object as activation; callbacks themselves remain live |
| Helper | effective view-class `link_to` definition identity |
| Locale | same locale as build; I18n operations/backend reads remain live |
| Sources | runtime/process/helper fingerprints at activation; eligible template SHA-256s at entry |
| Permission cache | existing K slot, with counting mode using normal validation |

No Accept/User-Agent/cookie absence is required. In particular the app's
integration-test Accept header and absent UA/cookie enter the generated path.
Extra params and explicit format keys conservatively use the original path.

This is **not** a claimed cheap unified epoch. Four file hashes and residual
lookups still execute per request. RubyVM constant-cache invalidation statistics
are not used. The 4,470-Ir synthetic residual micro is not this guard's cost.

At each template/partial boundary, compare the effective compiled method's
ISeq against the boot body, its locals, public visibility and the underlying
`_run` definition. Only parser-location metadata and process-local template
labels are excluded from that fingerprint. Subsequent uses still compare the
effective UnboundMethod, including hidden singleton/prepend replacements.
The resolver is never cached or bypassed: `clear_cache`/`DetailsKey.clear`
therefore cannot select a stale generated template. A changed/unrecognized
compiled body uses Rails' original `_run` before that body starts.

Before **each expanded helper**, after argument evaluation, recheck the
effective receiver method and visibility using captured core reflection.
Suppressed `method_added`/singleton hooks, conditional-super hooks and own
visibility changes cannot authorize a stale expansion. If it differs, call
the **live helper with the original arity/keyword shape** at that point.
Already-running template code continues, just as Rails' already-running method
would. Nothing restarts process, callbacks, action, SQL or previous output.
No filter/action deopt boundary is removed in this slice: those sections run
unchanged and every later inlined use checks its own facts.

Permission/accounting lives in a weak-key map, not controller ivars that would
leak into `view_assigns`. A hit means a certified generated template body was
entered, counted at most once per endpoint request. A helper deopt is counted
at most once per request too; such a request can have both a hit and fallback.
Entry rejection is one fallback. An admitted request raising before rendering
is neither a generated-body hit nor a helper deopt. Counts are not helper-call
counts or a claim that all rendering machinery was removed.

## Strict shadow means isolation, never replay

`LOWRAIL_SHADOW=strict` does **not** execute an authoritative endpoint twice.
The endpoint gate consists of the existing two-process `lowrail verify` plus
`bench/experiments/blog_endpoint_check.rb`'s two fresh worker processes.

The latter uses the same database snapshot, rolls fixture changes back, seeds
SecureRandom/OpenSSL entropy identically, fixes clock readings during each
request, fixes request ID and uses the same disposable session/CSRF secret.
It compares status, body and **all headers literally**: no stripping ETag,
Set-Cookie or X-Runtime. Ordered SQL includes binds and cache markers. The
event trace retains names, nesting, payload keys/scalars and assign-presence
observations; non-scalar framework objects have stable class/request/response
summaries, not cross-process object identities. It is not a certificate for
arbitrary object/ISeq/stack introspection.

The 144 cases are four routes (index and three asymmetric comment counts),
six Accept/UA/query shapes, absent/existing session and stock/escaped/empty
data. Empty data includes real 404 responses. An authoritative request always
runs once. The harness never loads into a deployed application.

## First-slice gates

- real-blog app suite: **21 identical outcomes, 125 ordered queries**;
  **index 1 hit / 0 fallbacks; show 1 / 0** from its own controller tests.
- Baseline **144 isolated pairs** identical. Including warmups, endpoint
  request H/F is **31/14 index, 60/42 show**. Negative format/query shapes
  deliberately fall back.
- Nine mutation cohorts, **144 pairs each**, identical: changed template plus
  both cache clears; helper redefine; added before_action; new render subscriber;
  locale switch; process-action-start helper mutation; fully suppressed hook;
  conditional-super hook; own-private visibility. A new subscriber keeps the
  baseline hits. Template/helper/filter/locale changes yield zero generated
  hits; the mid-request mutation first hits then continues with live helpers.
- Permanent regression: **90 assertions**, including ten mutated link markers,
  narrowed two-argument fallback, hidden singleton replacement, private helper,
  changed template, callbacks exactly once, assigns visible to subscribers and
  a compilation-container constant changed mid-request.
- Gem suite: **92 tests / 1,654 assertions**, zero failures/errors, six optional
  skips. Rust: **31 unit + three integration** tests pass. Benchmark driver:
  **13 tests / 110 assertions** pass after integrating main's new budget seam.
- Other corpus apps, pass selected but **no endpoint units**:

| App / actual Rails | Identical outcomes | Ordered queries | Endpoint refusal |
|---|---:|---:|---|
| PingCRM / 8.1.4 | 26 | 809 | application |
| Redprints / 8.1.3 | 50 + 12 system | 692 + 260 | rails_version |
| Starter Kit / 8.1.4 | 36 | 264 | application |
| Campfire / 8.2 alpha, supplementary | 634 (2 matching skips) | 15,108 | rails_version |

PingCRM retains **nine advisory other-thread SQL differences** (the same names
as the speculation study); do not mistake these for an ordered SQL gate.
Campfire's separate 30 browser tests were not rerun for this refusal gate.

Rails 8.1.4, unchanged source pin, L1/L2/L3: Action Pack **4,095** and Action
View **2,747 + 242 + 173** identical in every layer, no shadow mismatches and
all exits zero. AV/AR L3 has 123 existing-pass hits / 2 fallbacks; this is
compatibility evidence, **not endpoint coverage in the framework suite**.
Private evidence: `.lowrail/endpoint-framework-publish/`, `/tmp/endpoint-publish-*`,
`/tmp/endpoint-*-verify.log`. Raw responses/cookies are deliberately untracked.

## Reproduction and next measurements

```sh
RAILS_ENV=test mise exec -- target/debug/lowrail build .corpus/real-blog-r4 \
  --env test --passes default,+endpoint/action
RAILS_ENV=test PARALLEL_WORKERS=1 LOWRAIL_SEED=41231 LOWRAIL_SQL_TRACE=full \
  mise exec -- target/debug/lowrail verify .corpus/real-blog-r4 -- \
  bin/rails test --seed 41231
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 mise exec -- target/debug/lowrail \
  build .corpus/real-blog-r4 --env production --passes default,+endpoint/action
mise exec -- ruby bench/experiments/blog_endpoint_check.rb \
  .corpus/real-blog-r4 /tmp/NEW-endpoint-pairs
# Optional third argument: template/helper/filter/render_subscriber/locale/
# subscriber/suppressed/invokesuper/private. Always use a NEW output directory.
```

Fixed-heap benchmark of this exact slice against a separately built default
reference follows publication. No saving is claimed yet. The old eventful
−26/−37% specimen is an **upper bound with missing observable assigns**, not
a supported semantic target. Widen in separate measured, paired-gated steps:
helpers, partial/collection dispatch, layout, then filter dispatch. Each needs
its own new facts/local continuation; none is implied by this slice.

## Exact-slice measurement and rejected composition

The published conservative slice's index benchmark passed the fixed-heap and
A/A gates, but **regressed** against a separate default build: 8.574259 →
10.170184 M Ir/request, paired **+1,593,364 Ir, +18.565% [18.534, 18.646]**.
Allocations were 2,235.14 → 2,689.86. This is not the handwritten ceiling.

An inclusive-caller diagnostic explains the budget below. Inclusive deltas
are not independent causal ablations; notably `Endpoint.current` overlaps
its callers. No double counting is intended.

| Cost | Net Ir/request | Interpretation |
|---|---:|---|
| Entry | 415,186 | Includes 370,696 for four request-time SHA computations |
| Template checks | 165,064 | 14 calls |
| Helper checks | 106,806 | 10 calls |
| Lost default view/route source splices | 549,861 | Raw handler bodies superseded the default lowerings |
| Remainder | 356,447 | Includes 139,331 from 24 `Endpoint.current` lookups; not another additive row |

Unpublished composition work removes request-time file hashing, pins selected
runtime Template identities, passes the execution as a local, and starts from
post-source-pass bodies. Its descriptive index result was 9.052005 versus
8.574968 M Ir (**+5.56%**), with ten route completions and one endpoint hit.
**Rejected:** off/off A/A excludes zero ([+0.004, +0.069]%), and the warmed
suppressed-hook specimen renders stale output. It is neither a published
performance result nor a semantically certified implementation.

Pricing only effective `link_to` receiver identity plus public visibility
costs about **10,830–10,836 Ir/hit**, leaving diagnostic per-hit savings
34,075 and 26,062 on two view units (nine and one invocations per request).
Those two units pass their controls, but the experiment as a whole fails
route-unit A/A. More importantly this is **not the complete source-arm
certificate**. Neither these numbers nor the composition result licenses
shipping a residual or reactivating a pass.

## Source-arm quarantine

The owner chose quarantine before a continuation/body-certificate rewrite.
Both `view/link_to` and `route/path` are unavailable in default, explicit
`+name`/aliases and `all-opt-in`. Every new build records a pass-level
`quarantined` refusal. Runtime rejects an old artifact containing either
pass **as a whole**, including otherwise safe units and template entries,
before installing delivery hooks. The reason is retained as
`Lowrail.refusal_reason` and emitted in a boot warning. Direct guard validation
and binary lookup also refuse it; installing such a guard withdraws G/V/K
authorizations. No repaired accelerated-arm support is claimed.

Three independently executed Rails 8.1.4 fixtures establish the boundary:

| Mutation | Original Rails | Previous default source arm |
|---|---|---|
| Warm guard; process-action subscriber suppresses `method_added`, redefines `link_to` | Ten live-helper markers | Zero markers |
| `link_to` name expression changes actual `tag_builder.content_tag_string` | `<!-- changed builder -->` | Old anchor |
| Route argument's `to_param` installs singleton `route.format` returning `/changed` | `/changed`, one conversion | `/widgets/7`, one conversion |

The last two mutations occur **after** entry authorization. Even checking the
actual receiver and its visibility at entry is insufficient; the route's
class method fact also cannot describe a singleton override on the captured
route object. A whole-helper fallback after conversion would repeat effects.
The permanent regressions keep the observable outputs and once-only name /
conversion assertions; quarantine makes them green by refusal, not by
silently removing mutation coverage.

The rewrite is a separate opt-in pilot. It must certify actual method bodies
and receiver provenance, preserve argument evaluation once and in order, and
continue locally after every application-code boundary (name, arguments,
`to_param`, builder). Each such point needs a mutation probe, paired isolated
response/header/SQL/event gates, and fixed-heap cost ≤ the new default.
The pending endpoint composition is not published or reactivated on unsafe
source arms. The old eventful −26/−37% handwritten results remain upper bounds
missing observable assigns and mutation behavior.

### Quarantine cost and gates

This deliberately **loses** the previous source-pass instruction saving.
Six fresh fixed-heap interpreter Callgrind rounds per route, 50 requests per
worker, no YJIT, use the shared `bench/request_pairs.rb` protocol. The
`before` layer uses archived pre-quarantine runtime sources from
[fecd033](https://github.com/thomasklemm/lowrail/commit/fecd033) and its
production default artifact. The current `default` layer refuses that same
artifact at boot; it is an original-Rails path, **not successful activation**.
The independent `empty` layer agrees within noise. No production bypass was
added, and the blog was restored to a fresh test/default build afterwards.
The harness is also pinned to that pre-quarantine revision: these cohorts
precede the later heap-observer warmup/post-GC settling refinement in
[c9d2397](https://github.com/thomasklemm/lowrail/commit/c9d2397). They are not
a measurement under that newer protocol.

| GET | Off M Ir/request | Former unsafe default M Ir (Δ vs off, 95% CI) | Quarantined M Ir (Δ vs off, 95% CI) | Loss vs former default, paired 95% CI |
|---|---:|---:|---:|---:|
| `/articles` | 9.122639 | 8.575382 (−5.995% [−6.012, −5.966]) | 9.120766 (−0.006% [−0.037, +0.013]) | +6.367% [+6.333, +6.386] |
| `/articles/1` | 8.771261 | 8.684129 (−0.987% [−1.040, −0.977]) | 8.769938 (−0.004% [−0.033, +0.046]) | +0.998% [+0.960, +1.086] |

Both total/GC-excluded A/A controls include zero and pass the fixed 0.5%
tolerance. Total-Ir A/A is +0.003% [−0.012, +0.014] index and +0.001%
[−0.028, +0.039] show; heap capacities match and all warmup/window JIT checks
pass. These are instruction losses, **not native YJIT throughput claims**.
Private evidence: `/tmp/lowrail-quarantine-{index,show}-cost/{samples,summary}.json`.

Runtime/build gates after quarantine:

- Gem: **97 runs / 1,733 assertions**, zero failures/errors, six optional
  dependency skips. Includes the previously red warmed-subscriber test and
  the name-expression/builder and conversion/formatter regressions.
- `cargo test`: **34 unit + 3 integration tests** pass. Benchmark contract:
  **16 runs / 157 assertions**, zero failures/errors/skips. Explicit build
  and bench selectors reject both names and aliases; old/mixed artifacts
  reject rather than silently producing inactive performance results.
  After integrating the newer harness, all benchmark tests pass:
  **30 runs / 262 assertions**, zero failures/errors/skips.
- AP L3: **4,095** identical. AV L3: **2,747 + 242 + 173** identical;
  zero differences/shadow mismatches. AV/AR retains **123 hits / 2 fallbacks**
  from other runtime passes, not source-arm coverage.
- Five-app default verify has identical outcomes and own-thread SQL digests:
  blog **21**; Campfire **634** (two matching skips); PingCRM **26**;
  Redprints **50** plus **12** browser-system examples; Starter **36**.
  Every app's unit-hit and unit-fallback maps are **`{}`**, with **zero
  emitted route units and no executable source completion arms**. This is
  quarantine compatibility evidence, not accelerated coverage. Other-thread
  SQL differences remain advisory: one Campfire and nine PingCRM cases.

Campfire's query totals are 15,109 off / 15,108 on because the concurrent
repair test records 41 / 40 including other threads; its own-thread digest
is identical. PingCRM totals are 812 / 812. No advisory was suppressed and
neither these totals nor green outcomes certify the disabled source arms.
Earlier browser runs without Chrome had matching failures; those were not
counted as passing. The completed Redprints browser gate uses `BROWSER_PATH`
pointing to the installed Chrome. PingCRM uses the existing private PostgreSQL
socket. Final evidence is in `/tmp/lowrail-quarantine-corpus-final/` and
`/tmp/lowrail-quarantine-framework-final/`; request secrets stay private.
