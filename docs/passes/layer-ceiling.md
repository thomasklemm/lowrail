# Route-layer ceiling specimens — Rails 8.1.4

2026-10-20. **Measurement only. No pass, generator, L4 gate or default change.**
The owner paused the component pilot to choose the replacement boundary first.
This study uses only `script/corpus real-blog real-blog-r4`, production,
Rails **8.1.4**, Ruby **4.0.7**, actual **YJIT off**. Campfire's 8.2 alpha is
excluded. The broader multi-app subsystem survey is deferred, not completed
by these two routes. Redprints' existing pin is 8.1.3, not the 8.1.4 target.

**Later correction:** the event-preserving handwritten specimen did not assign
`@articles`/`@article` on the real controller as Rails does. A render subscriber
can distinguish it, and a process-action subscriber that redefines `link_to`
produces ten markers in Rails but none in that specimen. Its −26/−37% numbers
are therefore **upper bounds with omitted observable behavior**, not supported
equivalence or a demonstrated generator target. "Accepted" below refers only
to measurement controls. The owner selected a conservative, real-controller
process-seam pilot; see [endpoint.md](endpoint.md). It preserves the real event
pipeline and uses isolated paired shadow, never request replay.

## What the layers actually replace

All handwritten code is in [`bench/experiments/`](../../bench/experiments/),
never `gem/lib`. Each specimen runs in a disposable copy of the exact app,
lock, production fixture database and built assets. It never changes the
baseline app or caches an HTML response, model value or query result.

- **L0:** unmodified Rails, no Lowrail setup. Independent `off_a` / `off_b`.
- **L1 / envelope:** one successful-path envelope selects the two routes,
  sets their path parameters and dispatches straight to ArticlesController.
  The action, controller callback chain and every template/helper are original.
  Session prepare/commit, CSRF, cookie encryption, remote IP, request ID, ETag,
  executor and local-cache lifetimes still execute. Logging and exception
  handlers remain live Rails calls, not flattened copies. GET-only, empty
  query string, unmounted paths, no Accept/User-Agent or conditional headers
  are the measured request shape; other shapes use the original stack.
- **L2 / endpoint:** L1 plus explicit filter ordering, the same AR queries,
  string-building index/show/article/comment/layout bodies, and expanded
  links, buttons and the new-comment form. Real AR objects, relation building,
  preload/query cache, escaping/truncation/pluralization, Turbo signing,
  token generation, session encryption and asset/importmap helpers remain
  dynamic residue. No direct SQLite adapter or replacement model runtime.
  Controller/render instrumentation dispatch is not reproduced: this is
  conditional on the measured logging/observer configuration, **not** a
  certificate for an app with arbitrary subscribers.
- **L3 / components:** the complete original request stack/action/views plus
  three small replacements: LazyAttributeSet reads with direct ivar access
  and explicit cached-nil handling; Journey Format's fixed structure compiled
  without parameter/child interpretation; an empty-list fast path in Fanout.
  Fanout still consults live subscribers and silence state. Attribute objects,
  custom type deserialization, dirty tracking and missing/default attributes
  remain Rails operations. No tag/form helper replacement is installed here.

These are **measured, conditional ceilings before a complete entry
certificate**, not mathematical maxima for each architecture. In particular,
L3 cannot bound all possible component designs, and L2 still contains the
dynamic residue listed above. A weak component prototype does not disprove
component replacement. The specimens have **no boot-fact invalidation** and
must never be installed as application optimizations.

## Controlled instruction results

Median interpreter instructions/request; percentages are **paired** round
ratios, not ratios of the displayed medians. Allocation counts are objects
per request, baseline → replacement. Each row has its own independent L0.

| Layer / route | L0 Ir/request | Replacement Ir/request | Δ% [nominal 95% CI] | Allocations L0 → replacement | Controls |
|---|---:|---:|---:|---:|---|
| L1 index | 9,123,552 | 8,915,925 | −2.266 [−2.301, −2.249] | 2358.28 → 2261.49 | accepted |
| L1 show /1 | 8,772,825 | 8,549,375 | −2.556 [−2.565, −2.501] | 2244.89 → 2142.83 | accepted |
| L2 index | 9,123,980 | 6,080,836 | −33.351 [−33.395, −33.324] | 2358.07 → 1481.32 | accepted |
| L2 show /1 | 8,770,572 | 5,185,774 | −40.879 [−40.911, −40.830] | 2244.09 → 1208.49 | accepted |
| L3 index | 9,124,758 | 9,135,297 | +0.100 [+0.044, +0.171], **diagnostic only** | 2358.95 → 2358.38 | **rejected A/A** |
| L3 show /1 | 8,769,911 | 8,781,754 | +0.128 [+0.083, +0.176] | 2244.34 → 2244.22 | accepted; regression |

L3 index's total-instruction A/A CI was [−0.050, −0.003]%, so it misses zero
despite fitting inside ±0.5%. Its GC-excluded A/A and all five heap controls
passed. **The rejected experiment is retained, not rerun to obtain green.**
L3 show is a small measured regression. No saving is credited to this trio.

All comparisons use **`lowrail bench --pass default` with the existing
`BENCH_VARIANT_APP` / `app_fix` arm**. The selection is needed to boot and
validate the baseline default build; it is *not* the experimental replacement.
The replacement arm always has **Lowrail off**. Compare `app_fix` with
`off_a`, never with the enabled `default` arm. The default arm's Lowrail
coverage counters say nothing about experimental coverage.

Six fresh-process rounds, 50 warmup requests, N=0/50 client windows in both
total and GC-excluded modes, alternating window order and seeded randomized
layer order. The five pool floors are 1,000,000 / 250,000 / 100,000 / 20,000 /
10,000 slots, with the existing sparse anchors and three pre-window full GCs.
GC remains enabled in requests. The existing independent A/A CI must contain
zero and fit within ±0.5%; no retry or tolerance adjustment. See
[`bench.md`](../bench.md) for interpretation of these software counts and
coarse nominal six-round confidence intervals. **No native YJIT speed claim.**

## L2 attribution and the event-preserving alternative

`blog_decompose.rb` calls the **same `RequestPairs.heap_instructions`** used
by `lowrail bench`, with independent off/off controls, six rounds, unchanged
heap floors/N−0 windows and A/A criteria. Extra measurement stages are not
registered Lowrail passes. Stages successively flatten filters, remove
controller/view events and runtime bookkeeping, replace rendering with the
handwritten strings, remove remaining controller dispatch, and omit show's
blank `Comment.new`. This is an **ordered ablation**, not a sum of nested
inclusive profile shares. Interactions are charged to the later stage.

The show ablation passes both A/A gates and all heap controls. The index
ablation **fails total-Ir A/A**: off/off CI **[+0.00196, +0.04335]%** does not
contain zero. Its no-GC A/A and heaps pass. Keep its decomposition and event
comparison **diagnostic only**; do not retry or borrow the standalone index
run's accepted control. The original standalone L2 index result above remains
accepted, but cannot validate these additional variants.

Savings below are **percentage points of L0**, from paired within-round
instruction differences. Index is diagnostic; show is accepted. Per-part
CIs, GC-excluded results, all six raw paired samples and both rejected
controls are in [`layer-ceiling-results.json`](layer-ceiling-results.json).
The individual medians need not sum exactly; every round's differences do.

| Successive removal | Index pp saved (diagnostic) | Show pp saved |
|---|---:|---:|
| Envelope: middleware/routing → direct dispatch | 2.213 | 2.521 |
| Filter-chain interpretation | 0.542 | 0.602 |
| Controller/render events, payloads and runtime bookkeeping | 3.639 | 2.845 |
| Rendering: templates/partials/layouts, buffers/capture, expanded helpers | 25.391 | 33.657 |
| Remaining controller/params/response dispatch | 1.546 | 0.744 |
| Blank `Comment.new` for the form | 0 (not present) | 0.490 |
| **Full L2**, paired total | **33.340** | **40.870** |

The template stage includes lookup, partial/collection/layout interpretation,
buffer/capture work and helper expansion, not just ERB bytecode execution.
The extra residual-controller category prevents attributing all remaining
work to templates. Query construction, SQL generation, association preloading
and row instantiation are unchanged at every stage. `Comment.new` is form
presentation setup, not removal of the query engine.

The additional **L2_events** endpoint emits the same controller/render
notification names, payload keys, order and nesting, including private
`!render_template.action_view` and one event for each collection element.
It retains live request/response objects and runtime/SQL-count payloads;
subscriber state is never cached or tested to skip emission. Metadata comes
from the fixed template paths, while payload hashes are fresh. In particular,
an empty comment collection reports `identifier: nil`, as Rails does.

| Route / same-run variant | Ir/request | Δ% vs L0 [nominal 95% CI] | Objects/request | Controls |
|---|---:|---:|---:|---|
| Index L0 | 9,121,107 | — | 2358.18 | index comparison rejected |
| Index L2, events omitted | 6,080,826 | −33.340 [−33.354, −33.325] | 1481.26 | diagnostic only |
| Index L2_events, events retained | 6,737,825 | −26.138 [−26.186, −26.083] | 1674.55 | diagnostic only |
| Show L0 | 8,772,276 | — | 2244.60 | accepted |
| Show L2, events omitted | 5,187,989 | −40.870 [−40.902, −40.808] | 1208.22 | accepted |
| Show L2_events, events retained | 5,501,627 | −37.287 [−37.316, −37.247] | 1277.36 | accepted |

Preserving events retains about **78% / 91%** of the index/show L2 saving
(index still diagnostic). The 7.20 / 3.58 pp restoration costs include this
endpoint's event/payload/collection wrappers and their interaction with the
lowered renderer; they are **not** the 3.64 / 2.84 pp ordered-removal deltas.
Do not sum or interchange them. The evidence favors retaining events rather
than pursuing an absence certificate. Likewise, keeping the blank model
would avoid a separate initialization/defaults certificate for only ~0.49 pp
on show. The owner still chooses the generator boundary; none is built here.

`blog_events_check.rb` attaches a real evented subscriber and compares all
start/finish boundaries and stable payload values on index and show IDs
1/2/3: **20 / 18 / 16 / 14 boundaries, identical**. Runtime fields are checked
as numeric, not asserted equal across executions. The body/header/SQL checker
also passes its eight pairs for L2_events. This is a trace-contract check,
not a certificate for arbitrary observers inspecting omitted controller or
view internals, mutating state, raising exceptions, or concurrent execution.
Preserving instrumentation avoids the *event-elision* subscriber fact; it
does not waive other endpoint semantics.

## Response and SQL equivalence

`blog_check.rb` compares the original before installing any global component
patch. For each layer it checks `/articles` and show IDs **1, 2, 3**, first
without a cookie and then with the real encrypted session cookie. This covers
zero, one and two comments, not just one symmetric fixture.

Every comparison requires HTTP 200, **byte-for-byte body equality**, equality
of **all** response headers (including ETag and Set-Cookie), and ordered SQL
text, bind names/values and cached flags. The reusable comparator excludes
SCHEMA/TRANSACTION events; a separate warmed four-path check **without those
exclusions** passes on all eight specimens (32 full SQL-trace pairs).
Separate correctness workers supply
the same seeded entropy to SecureRandom/OpenSSL and fix `Rack::Utils.clock_time`
on both arms; the request ID is a fixed input header. No such overrides load
in instruction workers. No CSRF/nonce/ETag string normalization is used.

Additional transactional, rolled-back probes change title/body/commenter to
asymmetric HTML-special, Unicode and long/truncated text, and check an empty
index. This gives **18 paired checks per layer / 54 total**. All pass. A
planted SQL annotation is rejected with **identical body and headers but
different SQL**, proving the SQL check is independent. Earlier specimens with
a missing ETag and a one-byte newline difference were rejected before timing.

The five new ablation stages (filters, events, templates, endpoint_comment,
L2_events) each pass the same 18 fixture/adversarial/empty-index pairs, giving
**144 pairs across eight distinct specimens**, excluding repeated checks.
A planted wrong template virtual path also makes the event comparator exit 1.

This proves these request observations on these fixtures, not universal
Ruby observability: object identity, subscribers, custom helpers, locale
changes, errors and concurrency still need the certificates below.

## What a real entry guard must certify

| Layer | Boot facts and live/request checks needed | Existing app-suite relationship |
|---|---|---|
| L1 | Exact middleware inventory/order/arguments/method bodies; no public-file collision; empty dispatch callbacks; nil CSP; stock session/cookie/ETag settings; routes/constraints/controller identity; executor/cache lifetimes; route shape, HTTP method, body/query/Accept/User-Agent/conditional headers, mount and response-finished protocol. Keep original error/cleanup behavior. | `ArticlesControllerTest` index/show assertions name the relevant actions, but the existing integration Session sends a nonempty Accept header: **the present specimen falls back**, so a green app suite would not prove L1 fast-path coverage. Add exact-shape Rack cases plus Accept/UA/HEAD/conditional/error fallbacks for a real pass. |
| L2 | All L1 facts plus callbacks/filters/around ordering and effective observers; source/templates/handler/whitespace; route and polymorphic helpers, base `to_param`; AR schema/types/reflections/query shapes and scopes; Comment initialization callbacks/defaults; helper methods and safe-string rules; default form builder/config; I18n/inflections mutation epoch; asset/importmap config and request-dependent token/crypto inputs. | The index/show tests assert useful content, but neither checks exact HTML/headers/SQL, escaped text, locale, CSRF/session continuity or subscriber events. They currently fall back for the same Accept reason. Create/update/delete/comment tests exercise adjacent behavior and must remain original. The dedicated byte/SQL comparator exercises the measured endpoint branches now. |
| L3 | Exact Rails minor and source; LazyAttributeSet/value/default/cast Hash contracts, method/type overrides; format parts/parameter escapers/children and route-table mutation epoch; Fanout implementation and live subscription/silence behavior. New/changed format structures must fall back before evaluation. | Article/Comment model tests cover validation, associations and destruction; controller tests use AR reads and route helpers. They are relevant to components without going through the envelope guard, but are not a substitute for Rails' attribute, Journey and notifications framework tests in a future L4 gate. |

**No §4 promotion decision follows from this study.** The remaining
certificate work, nonzero verified coverage and full corpus/L4 gates are
not supplied by a hand-lowered response match.

### Cheapest exact facts, by removed responsibility

Use source digests at build/boot, not on every request. At entry, a coherent
generation token may amortize those checks **only if all relevant mutations
invalidate it**, including method replacement/prepend/reload. These are
required certificates, not invalidation machinery implemented in specimens.

| Removed work | Cheapest exact fact / retained live operation |
|---|---|
| Middleware/routing/controller envelope | Boot inventory of stack/order/arguments and route target; exact method-lookup identities/config plus middleware/route/reload generation. Live GET/path/query/mount/body/header predicates. Retain executor, cache, session/crypto, ETag, exception and close lifetimes rather than certify them away. |
| Filter-chain interpretation | Ordered callback-chain identity, kinds, conditions and method/Proc bodies plus set/skip/reset callback generation. Retain verification and both ActionText/Turbo around bodies; show's `set_article` query still executes. The allow-browser callback is inert only for the measured absent-UA shape; browser tests need a real modern-UA check. Preserve halting, after/ensure and error paths, or refuse before side effects. |
| Template/partial/layout interpretation | Source digests for index, show, article/comment partials and layout; exact ERB handler/buffer/capture contracts and resolver generation (including cache clears), locale/formats/variants/locals shape. Reject unknown layouts, streaming or details. A source digest alone cannot prove unchanged lookup. |
| Expanded helpers | Lookup identities for the omitted `link_to`, `button_to`, `form_with`, builder/label/input/tag/URL methods and their called hooks; route/default-URL generation; stock model naming/numeric `to_param` contract; exact builder/form defaults. Expanded labels/submit text need locale/translation/inflection state plus mutation invalidation. Dynamic escaping, truncation, pluralization, tokens, assets/importmaps and Turbo signing remain calls: do not certify their results constant. |
| Controller/render event dispatch | Conservative fact: `!notifier.listening?(name)` for **every omitted name**, recomputed live or under complete subscription/notifier/silence/log-level generations. A subscription epoch alone misses mutable logger levels and custom `silenced?` delegates. Retaining events is preferable if cheap enough; see below. |
| Remaining controller/params/response dispatch | Original action/controller method lookup and body facts, request wrapper/format/strong-param config, fixed success/HTML shape; no custom render/response hooks. Keep live response/session/flash semantics. Execution context, runtime registry and instance/view state are observable and must be retained when observers can inspect them, or separately certified unused. |
| Show form's blank model | `Comment.new`/initialize method identity, schema/defaults and **empty initialize callback chain**, no custom builder/model inspection or effectful default. Simpler exact choice: keep the original construction; its isolated cost is priced separately. Other AR queries/readers/type casts remain Rails and do not need a replacement-AR certificate. |

The omitted event names are `start_processing.action_controller`,
`process_action.action_controller`, `render_template.action_view`,
`render_layout.action_view`, `render_collection.action_view`,
`!render_template.action_view` (and `render_partial.action_view` wherever an
individual partial occurs; these two measured routes use collections).

**8.1.4 counterexample to “no subscribers at WARN”:** `listening?` is false
for the controller/partial/collection/private-template events here, but true
for render-template and render-layout. Both have an unsilenceable stock
`ActionView::StructuredEventSubscriber::Start`. Its `start` calls
`ActiveSupport.event_reporter.debug`; emission is inert only when
`debug_mode?` is false. That predicate includes **fiber-local debug mode**, not
just boot config. Widening the conservative fact therefore needs exact stock
delegate/debug method identities, no other effective subscribers, and a live
debug-mode check. Do not remove a subscriber, change logger settings or
silence events to manufacture eligibility. Keeping the calls avoids this.

### App-suite entry shapes, one row per test

Actual controller-suite observation, off, seed 41231:
`BLOG_TEST_SHAPES_OUT=/tmp/shapes.jsonl LOWRAIL=0 mise exec -- ruby
../../bench/experiments/blog_test_shapes.rb --seed 41231`, run in the app.
**12 runs, 42 assertions, zero failures/errors/skips.** Every row below sends
the same Integration::Session Accept header **A**, resolves HTML, has no
User-Agent, XHR, format extension, query string, incoming cookie or CSRF token.
Test config disables forgery protection. Flash below is **outgoing**, not a
follow-up GET: none of these tests calls `follow_redirect!`.

`A = text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5`

| Controller test | Request | Status | Flash set | A future index/show entry can execute? |
|---|---|---:|---|---|
| Articles: should get index | GET /articles | 200 | none | yes, after exact Accept/HTML negotiation is admitted |
| Articles: should show article | GET /articles/:fixture_id | 200 | none | yes, same; fixture ID is 980190962, not seed ID 1 |
| Articles: should get new | GET /articles/new | 200 | none | no; retain original |
| Articles: should get edit | GET /articles/:id/edit | 200 | none | no; retain original |
| Articles: should create article | POST /articles, valid form params | 302 | notice | no; redirect target is not requested |
| Articles: should not create article with invalid params | POST /articles, invalid form params | 422 | none | no; original new-form rendering |
| Articles: should update article | PATCH /articles/:id, valid form params | 303 | notice | no; redirect target is not requested |
| Articles: should not update article with invalid params | PATCH /articles/:id, invalid form params | 422 | none | no; original edit-form rendering |
| Articles: should destroy article | DELETE /articles/:id | 303 | notice | no; redirect target is not requested |
| Comments: should create comment | POST /articles/:id/comments, valid params | 302 | notice | no; redirect target is not requested |
| Comments: should not create comment with invalid params | POST /articles/:id/comments, invalid params | 302 | alert | no; redirect target is not requested |
| Comments: should destroy comment | DELETE /articles/:id/comments/:comment_id | 302 | notice | no; redirect target is not requested |

System-test source adds these two scenarios. **Not browser-executed in this
study**; exact raw browser/Turbo Accept values remain unobserved, unlike A.
The configured driver is Selenium headless Chrome. They require modern-UA
acceptance, HTML/Turbo navigation and session/flash continuity. Forgery
protection remains disabled in test; passing them cannot certify production
CSRF. No JSON, explicit format, XHR, HEAD or conditional-request test is present.

| System test | Index/show entries in source | Extra shape needed |
|---|---|---|
| full article lifecycle | Initial index; show after create; index via Back; show via title; show after update; index after delete | Browser Accept/UA, cookies, notice on redirect-follow GETs; form writes and invalid new form remain original |
| article with comments | Initial index; show after article create and comment create/delete | Browser Accept/UA, cookies, notice, live Turbo DOM updates versus navigation; same original write paths |

`test/system/articles_test.rb` has only a commented-out example, not another
executed scenario. Model tests exercise validation/associations/destruction,
not HTTP entry shapes. **Current specimens reject A and Chrome UA**, so the
app suite currently contributes no envelope/endpoint fast-path coverage.
An eventual pass needs counted index/show hits under the widened, exact
negotiation predicate, plus separate fresh/existing-session, escaped text,
flash, enabled-CSRF, non-HTML and error/fallback checks.

### Component survey boundary notes (not a cross-app ranking)

The off-only StackProf captures on this blog were discovery, not removable
cost estimates. Index has only 397 raw-stack samples: middleware is 96.98%
inclusive and Notifications 77.58%, but both wrap the unchanged application.
Attribute storage/casting is 2.02%, buffers 1.51% and Journey Format 0.50%
inclusive; these are **loose upper bounds, not credited savings**. JSON encoding
has no sampled frame in this HTML capture, not proof of zero calls. L3 prices
its three concrete edits together; it does not assign the whole wrapper
shares to them. The deferred survey still needs higher-resolution off-only
captures, per-operation instruction prices and the other eligible corpus apps.

| Subsystem | App extension points | Evidence needed before removing interpretation |
|---|---|---|
| Rack/envelope | Insert/delete/reorder middleware; middleware arguments, callbacks, sessions, CSP, host/proxy/static policies, response-finished/body-close behavior | Exact stack/config/source inventory plus mutation invalidation; live request shape. The no-op path of a security middleware is not permission to omit its other paths. |
| Request/params | Parameter parsers, custom encoders, deep-munge config, wrapped/strong params, query/body/path merge precedence, method overrides | Parser/config/method facts and live body/content-type/query/encoding checks; retain errors and memoized object/mutation behavior. These GETs do not price write-heavy parsing. |
| Journey | Route reloads, engines/mounts/constraints/default options, `to_param`, escaping and helper overrides | Route/format structure and method facts with a reload epoch; preserve parameter-before-child evaluation and missing-key short circuit, not just the final URL. |
| Attributes/casting | `attribute` types, serialization/encryption, aliases/store accessors, generated/custom readers, defaults, dirty tracking, schema/connection changes | Exact model/schema/type/method identities, AR epoch and row shape. Keep current values, assigned Attribute objects, cached nils, missing/default behavior and custom `deserialize` calls. |
| Notifications | Custom notifier, exact/regexp/temporary subscribers, monotonic/evented listeners, unsubscribe and silencing | Use live Fanout or a complete subscription/silence epoch. Boot-time absence alone cannot justify suppressing later listeners. Rails already avoids event allocation with no listeners. |
| AS JSON | `as_json`/`to_json`, custom encoder, per-call options, HTML/JS escaping policy, time precision/format | Encoder/config/method facts plus actual input types/options; retain live hooks and side effects. No native-JSON shortcut is priced here. |
| SafeBuffer/OutputBuffer | Subclasses, `html_safe?`/`to_s`, unsafe mutation, custom handlers, capture/streaming, encoding | Exact buffer/helper/method contracts and live value safety/encoding. Returning the same bytes is not enough if capture ownership or mutation safety changes. No buffer replacement is priced here. |

## Roundhouse reference and the replacement boundary

Read `rubys/roundhouse` at
[`74dec12`](https://github.com/rubys/roundhouse/commit/74dec12e287afae9ce50586c3bab709ec320f824).
Its [Ruby overlay dispatcher](https://github.com/rubys/roundhouse/blob/74dec12e287afae9ce50586c3bab709ec320f824/runtime/spinel/scaffold/ruby_overlay/main.rb)
separates the envelope from generated controller/view methods; generated views
append literal markup and live values into strings. That is the L2 style
reference, **not an equivalent Rails implementation copied into Lowrail**.
Roundhouse's lowered queries can drop `includes` and change SELECT shape;
this study explicitly retains the original queries instead.

The library survey found no drop-in `runtime/ruby/` substitute: request params
and routing omit middleware/extension behavior; AR uses typed slots rather
than AttributeSet; JSON omits encoder/options/as_json hooks; SafeString lacks
the full SafeBuffer/OutputBuffer mutation/capture contract. Its Notifications
implementation even walks subscribers and reads time when none exist, whereas
Rails already skips instrumentation. Those are useful implementation
references, not permission to remove Rails behavior. Boot facts and fallback
remain necessary at every replacement boundary.

## Reproduction

```sh
mise exec -- script/corpus real-blog real-blog-r4
# In .corpus/real-blog-r4, prepare production assets/database with the same
# SECRET_KEY_BASE_DUMMY=1 used by all workers.
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 mise exec -- \
  target/debug/lowrail build .corpus/real-blog-r4 --env production
mise exec -- ruby bench/experiments/blog_study.rb /tmp/NEW-layer-study
```

`blog_study.rb` checks equivalence first, creates/disposes each app copy, then
runs the real CLI twice for that layer. All results, including a rejection,
are retained. `specimens.json` binds source checksums; each CLI retains its
raw Callgrind dumps, windows, actual JIT/heap metadata and paired samples.
Raw logs/cookies/HTML stay private. The portable numeric export contains no
cookies or local app-copy paths.

For the ordered ablation/event alternative, in a fresh output directory:

```sh
mise exec -- ruby bench/experiments/blog_decompose.rb /tmp/NEW-ablation
# From .corpus/real-blog-r4:
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 mise exec -- ruby \
  ../../bench/experiments/blog_events_check.rb /tmp/NEW-events.json
```

The portable export records the measured revision and specimen/harness hashes.
Later main changes do not retroactively widen the observations. No production
runtime file, framework-suite gate or generator is changed by this study.
