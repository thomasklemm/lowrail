# Rails 8.1.4 allocation survey

2026-10-20. **Measurement only: no tracked runtime, pass, application or default
changes.**
This is a request-allocation census and conditional micro study, not a
`lowrail verify` support certificate or a native YJIT speed claim. Read with
[bench.md](../bench.md), [the candidate survey](../candidates.md), and the
[corrected layer ceiling](layer-ceiling.md). In particular, `L2_events` is an
upper bound that omits observable controller state/helper mutation, not an
allocation-saving implementation we can install.

The largest concrete discovery pools are Redprints' scalar CFP lookups
(conditional 300 objects/list request) and StoreModel scalar-read forwarding
(203 Arrays/list request). Neither is certified. The three primary micros save
26 / 13 / 15 objects/call under their stated assumptions; only the Inertia
micro has an accepted instruction result in **both** execution modes. Most
enumerated objects are temporary churn, not retained application data.

## Scope and method

- Production Ruby **4.0.7**, actual YJIT **on** for the request census,
  Rails **8.1.4** for all four apps. Each route/format/arm is a fresh process;
  Lowrail off has **no Lowrail setup loaded**. Default loads the real default
  build at measured library revision
  [`8df58ed`](https://github.com/thomasklemm/lowrail/commit/8df58edf5b6ff81857933d0d1d0b9a6785bc4998),
  with exact runtime/manifests fingerprinted in the export. This is a snapshot,
  not a claim about concurrent later runtime changes on main. **Default is
  historical experimental cost**: the unsafe view/link and route source
  passes were quarantined by
  [`45fd07a`](https://github.com/thomasklemm/lowrail/commit/45fd07a851da4ecee8856a1fc2ea41c4843934d4).
  Fresh default builds now have zero units and correctly fail the benchmark's
  activation requirement. Historical hits/allocations are not semantic
  certification or current-default support.
- `script/corpus real-blog real-blog-r4`: `/articles`, `/articles/1`,
  `/articles/1/edit`, three seeded articles and three comments. This generated
  lock uses sqlite3 **2.10.1**; do not combine its totals with the earlier layer
  ceiling's different lock. Starter: dashboard/profile, HTML (real Node SSR)
  and Inertia JSON. Redprints: proposals/proposal, HTML/JSON. PingCRM:
  organizations/contacts, HTML/JSON; **it does run on 8.1.4**.
- Redprints' corpus pin still uses Rails 8.1.3. A **disposable copy** named
  `redprints-alloc-r4`, with only framework gems patch-updated to 8.1.4,
  supplies this survey. Its Inertia 3.21.2 and Freezolite are retained. Starter
  has Inertia 3.22.0; PingCRM 3.23.0. Locks/manifests/runtime hashes are in the
  [numeric export](allocations-results.json). The corpus pin was not changed.
- After 400 successful requests, record three GC-enabled, tracing-off
  100-request totals. Then enable `ObjectSpace.trace_object_allocations` for
  **N=20** requests with GC disabled so short-lived objects cannot vanish
  before enumeration. Attribute each enumerable object to file:line and its
  actual class, including SafeBuffer separately in the callsite tables but
  under String in the type totals. This is allocation provenance, **not a
  dynamic call stack**. Generated-code source attribution is not evidence that
  code generation runs per request.
- Retained means objects from that exact allocation generation surviving
  three full GCs after the response reference is dropped. FREEOBJ tracing
  stays active across those GCs: stopped tracing leaves stale reused-address
  metadata and gives false survivors. An asymmetric control (64 each of
  String/Hash/Array/Proc, retain 7/5/3/2) recovered exactly those counts.
  Retained objects are not necessarily leaks; garbage = allocated − retained.
- VM-internal objects cannot all be enumerated with `ObjectSpace.each_object`.
  The GC-stat/trace residual is explicitly reported, not mislabeled `other`.
  GC-enabled totals and bounded trace types are separate windows, not an
  exact accounting identity or an allocation-profiler overhead correction.
  Tracing changes execution; these are **not timing measurements**. The request
  census's fixed warmup is not a JIT-compilation-flat instruction certificate;
  only the instruction micros below use that stronger gate.
- The envelope includes Rack::MockRequest/MockResponse/client allocations.
  Those are explicitly `a/rack-client`, not app optimization credit. Headers,
  cookies and object contents are never exported. A separate strict default
  activation probe ran for every route. Only blog has completed hits
  (index/show/edit: 20/4/4 source hits, including 10/2/2 route completions).
  Starter/Ping/Redprints have **zero hits**; Redprints also has a require-hook
  warning. These are safe no-op/no-coverage results, not optimization claims.
  The request processes do not enable Stats, so counting overhead is outside
  the census. Small off/default differences outside blog are descriptive
  window variation, not evidence of a Lowrail benefit with zero completed hits.

## Classification: what could actually remove the objects?

`a` = required data/result or no demonstrated behavior-preserving removal;
it does **not** mean a mathematical lower bound. `b` = a concrete conditional
lowering opportunity, not an implemented certificate. `c` = the relevant
allocation machinery was changed on Rails main (links below); output objects
may still be necessary, so a `c` row is not a 100% savings budget. Bounds below
start at zero until complete eligibility and guard costs are established.
Overlapping mechanisms must not be added together.

| b key | Exact Lowrail mechanism, not a global cache | Certification and live behavior that must remain |
|---|---|---|
| form | Source pass over a whole known compiled-template/form fragment (or endpoint/component body): emit literal markup and directly escape live field values, avoiding helper option Hashes, `stringify_keys`, tag-option `dup`, name/XML normalization and temporary SafeBuffers | Exact template/compiler/locals/resolver and effective helper/TagBuilder methods, I18n/locale/backend generation, builder/form object/error/config state, value class/encoding/safety. Keep CSRF, nonce, IDs, accessibility/error wrapping, fresh output and evaluation/exception order. **Not** arbitrary literal freezing; not the upstream attribute-append row a second time |
| config-bind | Existing opt-in Inertia configuration method variant copies live options directly instead of reconstructing Configuration and extracting option categories into intermediate Hashes | Configuration source/schema/method facts and controller binding; preserve live Proc options, mutation/override precedence and fresh storage. Separate call trace confirmed the `hash/slice.rb:25` Hashes here come from `Configuration#initialize` through `bind_controller`; overlap the existing config-bind backlog, not a new gain |
| tuple | Source or runtime method variant: change ordinary Hash `each_with_object` tuple destructuring into `each_pair` plus an explicit fresh accumulator | Exact Hash class, iteration methods/order and gem source/method/ancestors. Retain live Inertia partial/once/deferred metadata, lazy/Proc evaluation, recursion, rescue/errors and fresh result Hashes. CurrentAttributes additionally needs exact defaults/reset methods, fresh `dup` and default Proc execution; never memoize a request's defaults |
| frozen-lookup | Source variant for the exact `CFP.find_by(id: string)` call: scan `CFP.load_records` directly, removing Scope/matcher/criteria/iteration wrappers | Exact class/source/readers/comparison methods, current unscoped Scope, index definitions, where/not/order/limit/offset state, loading/reload generation and live max-scan policy. Preserve result object identity, misses, order and exceptions; no cached lookup result |
| store-read | Source-callsite/endpoint devirtualization of scalar generated AR getters through StoreModel 4.6.0's `_read_attribute(*)` wrapper; emit the certified scalar read without its rest-Array dispatch | Generated body and effective getter/visibility/singleton method, StoreModel/AR `_read_attribute` ancestors/methods and parent-assignment contract, schema/type/enum mapping and mutations, missing/cached-nil/default behavior. Preserve StoreModel parent assignment for any non-scalar result or refuse. Keep original method signature/body as fallback, not a signature-changing runtime replacement |
| event-path | Runtime variant/component precomputes the boot-fixed template-root prefix recipe, not the notification or its final payload | Root/template/source generation, exact String operations and subscriber semantics. Keep events, live subscriptions and fresh per-event path/payload objects. At most one intermediate prefix per event, not all observed Strings |
| preload-tags | Compiled source/component streams known importmap preload-tag iteration into the output buffer instead of map/safe_join Arrays | Exact importmap/helper/compiler methods and order/safety/buffer contract; resolver, nonce and URL/regexp-timeout behavior remain live. No cached personalized URL or timeout-bypassing memo |
| url-residue | Existing route source-plan boundary: specialize fixed empty-prefix/chomp/path-building intermediates | Routes/mount/script-name/defaults generation, method/escaper/to_param facts, exact input shapes, output freshness and parameter evaluation order. Overlaps route/Journey work, not an independent full route budget |
| ssr-setup | Net::HTTP runtime variant uses a certified setter list instead of `methods.grep`/regexp captures at each connection | Exact Net::HTTP/setter methods and extension set/order; dynamic connection/proxy/TLS/environment values, IO, failures and resource cleanup stay live. Only fixed dispatch interpretation disappears |
| ssr-headers | Net::HTTP-header component writes capitalization directly instead of split/map/join intermediate Strings | Exact header methods/input shape/encoding and order; preserve live header values, case rules, fresh final String and HTTP/IO semantics |
| prop-path / prop-dispatch | Inertia source variant preplans known prop-key path/metadata dispatch instead of repeated `to_s`/split/`respond_to?` scaffolding | Exact source/key shape, metadata methods/partials/once/deferred/rescue configuration and mutation; all values, lazy methods, getters, exclusions and exceptions remain live. **Not** covered by the tuple micro |
| attribute-keys | AttributeSet component iterates a certified fixed schema key plan without temporary key/union Arrays | Schema/type/default/missing/extra-attribute behavior and mutation, exact AttributeSet methods; preserve fresh returned Array, ordering and dynamic membership |
| inflection | Source pass specializes a literal naming site with a certified inflection plan | Exact input/caller and inflector/locale rules generation, methods/encoding; no global cache for arbitrary dynamic Strings, and no reuse of an observable mutable result |
| pg-types | Adapter/schema component preplans known scalar OID/type dispatch instead of tuple-key lookup Arrays | Connection/shard/schema/OID/type registry epochs, exact adapter/type-map methods, extension/custom type registration and errors. Rows/casts and connection state remain real Rails/PG |
| query | Component/endpoint specializes a fixed query shape: direct predicate dispatch, known relation-option plan and placeholder fragments | Schema/adapter/connection/current scope, registered predicate handlers, effective methods and SQL/bind/quote ordering; all live authorization, binds, values and SQL/notification hooks remain. No cached row/result or skipped query |
| authorization | Endpoint source plan unrolls a proven finite CanCan rule shape, avoiding scalar-to-rule Array wrappers | Rule DSL/method/order/alias/condition generations and complete endpoint eligibility; current user/permissions/conditions and SQL remain live. High-burden follow-up, not permission-result memoization |

`a/data` includes real AR rows/attribute Hashes, returned serializer row Hashes,
live date/time formatting and escaping/output. `a/io` includes URI/network and
token/crypto output. `a/opaque` includes VM pseudo-source attributed allocations
without a demonstrated public-class removal. No saving is assigned to them.

## Rails-main cross-check (category c)

Checked authoritative `rails/rails` history and changed code, not just PR titles,
at main [`3f0b6751`](https://github.com/rails/rails/commit/3f0b675158e8284241bb1213c00375bc1fb9c52f).
These changes are absent from the measured 8.1.4 code. They reduce the indicated
machinery, not necessarily every object attributed to the source line.

| c key | Upstream change | Survey interpretation |
|---|---|---|
| tag | [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b) | Fuse attribute appends instead of building an intermediate attribute String; already parked as upstream-solved in Lowrail |
| callback | [7a2033c9](https://github.com/rails/rails/commit/7a2033c9b88b4eb4ff5c50fcc2bf68b5d50c70e4) | Remove the known-terminator Proc thunk, not callback bodies |
| static | [bac124be](https://github.com/rails/rails/commit/bac124beceb2d899340647718f1eef68a9c9cbec), [ef95eda7](https://github.com/rails/rails/commit/ef95eda7b74a7888432ea36bff7e0bf9a7fa8d4e) | Static-file miss candidates/path handling; output/actual file reads remain |
| param | [a3319707](https://github.com/rails/rails/commit/a331970705be25cc338854490fbd05144c810555) | Avoid the scalar primary-key Array/join path in AR `to_param`; dynamic String output remains |
| route | [938d6069](https://github.com/rails/rails/commit/938d6069a8c1ad03fe7baa6d86572b8e2e3852a5) | Remove Journey parts duplication/intermediate construction; not all final route Strings |
| url-options | [042e0851](https://github.com/rails/rails/commit/042e0851acbb17b375f23af58214139fdef637d8) | Cache the controller URL-options construction; retain live script-name comparison and recycle invalidation, not blind local memoization |
| keys | [fafab17b](https://github.com/rails/rails/commit/fafab17bfc40812a794c2492845deb519ab1f387) | Scalar association-key fast paths; not every key/result Array disappears |

The `active_model/attribute_methods.rb:273` Arrays are **generated method
invocation** allocations, not generation on every request. Inspecting actual
ISeqs/owners found Redprints' `StoreModel::Base#_read_attribute(*)` wrapper
(store_model 4.6.0), **not** a rest parameter on Rails' generated getter.
An isolated warmed 1,000-call trace attributes exactly one Array per
`Proposal#cfp_id`, `#status`, `#submitted_at` call to line 273; the unrelated
forwarding `CFP#open_at`/`#deadline` calls allocate zero there. This prevents a
false generic-AR optimization claim. Upstream
[`63dc3dd0`](https://github.com/rails/rails/commit/63dc3dd0691577582389df58a9f5342e32ca56a8)
addresses boot-time generation, not this wrapper; it is not marked `c`. The
historical empty-hash builder fix
[`dc7935b2`](https://github.com/rails/rails/commit/dc7935b226f634be59e839e533f191f400bc1af8)
already predates 8.1.4 and is not a new opportunity.

## Guarded micros and request-budget boundary

`bench/experiments/allocations_micro.rb` contains three primary conditional
specimens: compiled simple form fragment, Inertia tuple iteration, FrozenRecord
lookup; a scalar `dom_id` specimen is an extra small control. They never install
methods into Rails. `FACTS[0]` models an already-valid invalidatable certificate;
**it does not implement certificate construction or invalidation**. Dynamic
shape checks and that token are measured; a complete certificate's extra cost
is unpriced. Therefore these are conditional per-call budgets, not production
guarded-pass gains or request-speedup claims.

The shared `RequestPairs.heap_instructions` / `HeapWindows` budget seam uses
six fresh randomized off-A/off-B/variant rounds, fixed five-pool heap floors,
N=0 subtraction from N=1000, total and GC-excluded Callgrind windows, zero
measured GC, matched heap anchors and per-operation ±0.5% A/A gates. Both actual
interpreter and actual YJIT states are checked. Controls and rejected cohorts
are retained, not rerun just to obtain green.

The form control includes nil, Unicode, newline, quotes/HTML entities,
SafeBuffer and false-certificate fallback. DOM includes nil/negative/asymmetric
IDs. Props includes nested/lazy/partial/excluded/dotted props and fresh results.
FrozenRecord includes existing/missing/nil/Array IDs, false-certificate fallback
and **identity**, not just value equality. None of these finite controls closes
the mutation certificate or constitutes app support.

### Interpreter micro results

Objects and instructions/call, off-A → variant. Saved Ir is the paired
median and nominal bootstrap 95% CI, not subtraction of displayed medians.
All heap gates pass and measured minor/major collections are zero. The
FrozenRecord **instruction** cohort is rejected: A/A total/no-GC CIs extend
to −0.797%, beyond ±0.5%. It is not rerun to obtain acceptance.

| Operation | Objects/call | Total Ir/call | Saved total Ir [95% CI] | No-GC Ir/call | Gate |
|---|---:|---:|---:|---:|---|
| Simple compiled label + text input | 34.000 → 8.000 | 120,627 → 22,133 | 98,484 [98,430, 98,553] | 120,652 → 22,150 | accepted |
| Inertia nested/Proc props (13 keys visited) | 73.997 → 60.997 | 160,386 → 154,935 | 5,426 [5,426, 5,452] | 160,386 → 154,935 | accepted |
| CFP scalar ID lookup | 14.997 → −0.003 | 31,841 → 9,926 | 21,939 [21,721, 22,124] | 31,841 → 9,929 | **rejected A/A; diagnostic Ir only** |
| Extra: Article integer `dom_id` | 3.997 → 0.997 | 16,550 → 4,107 | 12,443 [12,441, 12,445] | 16,549 → 4,107 | accepted |

The −0.003 object estimate is signed N=0 subtraction overhead (raw on=0 in
some rounds), not negative physical allocations; do not clamp the estimator.
Object differences are exactly **26 / 13 / 15 / 3** in every paired round.
Full signed samples, controls, actual JIT state and specimen hashes are in
[allocations-micros.json](allocations-micros.json). Interpreter Ir is never
relabeled YJIT time.

### YJIT micro results and rejected controls

One final finite run of all three groups uses the published shared observer
prewarm at `c9d2397`, **without** the local prewarm workaround or request
settling in operation workers. All 54 fresh workers prove actual YJIT on,
warm-to-flat and unchanged compiler counters through their 288 measured
windows. Measured GC is zero. Same units/estimator as above; the run exits 2
because blog and FrozenRecord are rejected, not because any worker crashed.

| Operation | Objects/call | Total Ir/call | Saved total Ir [95% CI] | No-GC Ir/call | Gate |
|---|---:|---:|---:|---:|---|
| Simple compiled label + text input | 34.000 → 8.000 | 79,807 → 12,011 | 67,797 [67,665, 67,881] | 79,783 → 12,006 | **rejected heap; diagnostic Ir only** |
| Inertia nested/Proc props (13 keys visited) | 70.9975 → 57.9975 | 51,905 → 46,036 | 5,894 [5,841, 5,924] | 51,906 → 46,037 | accepted |
| CFP scalar ID lookup | 14.9975 → −0.0025 | 18,839 → 4,959 | 13,916 [13,660, 14,101] | 18,840 → 4,959 | **rejected A/A; diagnostic Ir only** |
| Extra: Article integer `dom_id` | 3.9975 → 1.9975 | 9,232 → 2,230 | 7,002 [7,000, 7,006] | 9,232 → 2,231 | **rejected heap; diagnostic Ir only** |

Final `jit-published-props` passes all gates. `jit-published-blog` passes
aggregate and both per-operation A/A gates but fails heap matching: pool-0
capacity **1,000,439–1,002,105**, a 1,666-slot spread exceeding the allowed
one-page rounding of 1,639 slots. `jit-published-frozen` passes heap/JIT but
its total-Ir A/A CI **[−1.3072%, +0.6813%]** exceeds ±0.5% (no-GC likewise).
Neither failure is retried. DOM saves **2** objects/call under YJIT, versus
**3** under the interpreter. Primary form/props/FrozenRecord differences
remain exactly **26 / 13 / 15**; −0.0025 has the same signed N=0-estimator
explanation as the interpreter's −0.003, not negative physical allocation.

The original blog YJIT cohort is also retained (`jit-initial-blog`), rejected
for observer self-compilation despite passing A/A/heap gates. Operation warmup
alone did not warm the adjacent two-argument `GC.stat_heap(pool, existing_hash)`
endpoint; a YJIT compilation log identified `stat_heap@<internal:gc>:390`.
The local diagnostic correction (`jit-observer-warm-blog`) primed that exact
signature outside counters and passed heap/JIT, but its DOM A/A CI
**[+0.0109%, +0.0433%] excludes zero**, so that whole earlier batch remains
rejected too. Before the shared correction, `jit-props` passed, while
`jit-frozen` failed A/A **[−0.6590%, +0.4761%]**. All earlier cohorts remain in
the export with their original worker/seam hashes; none is relabeled as a
published-seam result. The only reruns are these documented protocol
corrections, including the explicitly requested final finite published run,
not retries until A/A or heap gates turn green.

Callgrind instructions under YJIT are diagnostic native-instruction budgets,
not elapsed time or an app-level GC/throughput claim. Certificate validation
and eligibility costs remain unpriced in both modes.

### Request estimates: discovery pools, not a sum of savings

These are per-request **conditional ceilings for the named pools**. They are
not all necessarily removable, not complete subsystem costs and not a traffic
mix. Bounds include zero for unclosed certificates. The backlog groups related
callsites by their coherent mechanism instead of creating 120 tiny passes.

| Mechanism | Observed pool / conditional objects saved per request | Eligibility / overlap caveat |
|---|---|---|
| form | Blog edit: 0–44 in just I18n option Hashes (18), stringify option Hashes (14), tag-name Strings (12); more SafeBuffer/markup pools remain unpriced | The 26-object micro is **simple tag helpers**, not blog's FormBuilder; zero completed real-form lowering/frequency credit. Also covers literal-tag scaffolding in HTML shells, not only forms |
| tuple: props | Starter 0–11 Arrays; Redprints list/show 0–11/13; Ping 0–22, HTML and JSON | One tuple/visited key; micro's 13-key shape is not a whole-request price |
| tuple: CurrentAttributes | Starter 0–10 Arrays; Redprints 0–6; Ping 0–4 | A separate loop/certificate, not Inertia prop tuple hits; reset/default results remain fresh |
| frozen-lookup | Redprints proposals **0–300**, proposal **0–15**, both formats | Independent 20-request call trace: **20 / 1** `FrozenRecord::Scope#find_by` calls with CFP `{:id => String}` per request. 15 saved/call is conditional; do not apply it to `CFP.primary`, active-scope enumeration or all Matcher objects. Instruction expectation remains diagnostic after rejected A/A |
| store-read | Redprints list/show 0–203/19 Arrays | Actual StoreModel wrapper, not generic Rails generated-reader cost. Disjoint from CFP's no-allocation forwarding; complete scalar eligibility not built |
| event-path | Blog 0–5 prefix Strings (10 Strings attributed to line 61) | Keep five fresh final event path Strings; never elide notifications |
| preload-tags | Blog 0–8 Arrays at importmap helper line 42 | Stream only certified map/safe_join intermediates; no URL/timeout cache |
| url-residue | Blog 0–7.33 Strings, equal-route mean | Only with a fresh owned path buffer; output cannot alias/mutate script-name input. Overlaps route plans |
| ssr-setup / ssr-headers | Starter HTML 0–34 / 0–26 Strings; JSON 0 | Captured setter names and capitalization intermediates; final header output and network remain. Separate, not counted as form savings |
| prop-path | Starter 0–11 Strings; Redprints 0–11/13; Ping 0–22 | Some path Strings escape into metadata and must stay fresh; only proven nonescaping paths removable |
| prop-dispatch | Starter 0–28 Arrays, Redprints list/show 0–28/34, Ping 0–40 in the three top `try`-dispatch pools | Specialized live metadata predicates; not measured by the tuple-only micro |
| config-bind | Starter 0–8 extraction Hashes at `hash/slice.rb:25` | Subset of the existing config-bind opportunity, **not** eight more on top of its earlier budget |
| attribute-keys | Starter 0–8 Arrays | Returned key Array remains fresh; upper bound includes objects that may be required |
| inflection | Starter 0–16 Strings, equal-route mean (profile 32 both formats, dashboard 0) | Literal-name sites and rules generation still need certifying; not a dynamic-string cache |
| pg-types | Ping 0–38.5 Arrays, equal-route mean | Adapter/OID registry closure not built |
| query | Ping mean pools: 15 handler Arrays, 14.5 relation-option Hashes, 18 placeholder Strings, 15 sanitization Strings (0–62.5 combined discovery cap) | Component/query-shape specialization only; output/quote/bind requirements lower the true removable part. Other query rows unpriced, overlaps endpoint/authorization |
| authorization | Ping 0–14 rule Arrays, equal-route mean | Entire live finite rule/SQL pipeline must be certified; not a local Array deletion |
| Extra dom_id | 0 credited/request; **3 interpreter / 2 YJIT objects/certified integer-Article call** in micro | No independently counted eligible request sites; Comment/prefix cases cannot borrow Article's price |

Category-c pools remain upstream-solved/parked, not new Lowrail passes: tag
attribute Strings (blog mean 79.67); known-terminator Procs (app means
10.67/14.5/15.5/15); static miss Strings/Arrays (45/request all apps); scalar
`to_param` (blog mean 14 Strings + 7 Arrays, but fresh final output required);
Journey parts/result intermediates (blog mean 14.67 Arrays + 7.33 Strings);
controller URL-options (blog mean 7.33 Hashes); scalar association-key handling
(Redprints mean 32 Arrays at line 373). These are observed pools, not promised
removal counts; all overlap their existing route/callback/tag components.

The only traced survivors are PingCRM's last RequestStore Hash
(`request_store.rb:15`) and one adapter's empty warnings-queue Array
(`postgresql/database_statements.rb:211`) per 20-request window. All other
enumerated objects are garbage after the drain. This finite result says
**temporary churn dominates this workload**, not that the apps have no leaks.

## Validation and limitations

- Thirty request profiles cover all fifteen route/format pairs in both arms;
  callsite/type totals and retained counts reconcile within each traced window.
  The independent asymmetric trace/retention control passes. The unenumerable
  VM residual is not assigned invented callsites or user-visible types.
- Six randomized fixed-heap rounds per micro cohort retain raw signed samples,
  A/A, heap and JIT decisions. Rejected cohorts remain in the export. No
  request speedup, additive savings total or completed support is claimed.
- After integrating the source quarantine, `mise exec -- cargo test --locked`:
  **34 unit + 3 integration tests pass**. `mise exec -- rake test` from `gem/`:
  **97 runs, 1,703 assertions, zero failures/errors, nine skips**.
  The earlier pre-quarantine run had 94 runs/1,647 assertions, exactly the
  known `ViewTest` suppressed-`method_added`/redefined-`link_to` stale-output
  failure, zero errors and nine skips. That failure was observed and reported,
  not silently excluded; the separately owned quarantine closes it.
- Shared seam checks: `mise exec -- ruby bench/request_pairs_test.rb` passes
  10 tests/70 assertions; `mise exec -- ruby bench/pass_test.rb` passes
  16 tests/157 assertions. Neither has failures, errors or skips.
- Ruby syntax checks pass for all five new experiment drivers and
  `git diff --check` passes. No runtime, pass or application sources changed.

## Reproduction

Follow [bench.md](../bench.md) production database/assets/auth prerequisites
first, using `mise exec` and `SECRET_KEY_BASE_DUMMY=1`, including PostgreSQL and
the Starter SSR service. Keep private `tmp/m0/headers-{html,json}.json` and
`paths.json` from `bench/inertia_setup.rb` out of the report. Rebuild every
default manifest after a runtime-source change with `RAILS_LOG_LEVEL=error`
and `LOWRAIL_BUILD_JIT=0`; never reuse an endpoint build after certified files
change. For Redprints, copy `.corpus/redprints-cfp` to a **new**
`.corpus/redprints-alloc-r4` and run `mise exec -- bundle update rails
--conservative --patch` there, checking that only framework gems change from
8.1.3 to 8.1.4. Do not silently update unrelated lock dependencies.

The commands below run a **new study of the checked-out revision**. To
reproduce the historical default snapshot, use an isolated checkout of
`8df58ed` with these allocation census drivers copied in, prepare the same
locks/fixtures and rebuild there; do not undo the source quarantine on main.
The micros load no Lowrail and use the published measurement seam at
[`c9d2397`](https://github.com/thomasklemm/lowrail/commit/c9d2397f1748579b04f6bddff48bc3bfc53d79b0)
for the final finite YJIT batch. Historical cohorts keep their original seam
and worker hashes rather than being relabeled as new-seam results.

```sh
# Fresh output directories; these scripts do not build or modify the apps.
for app in real-blog-r4 react-starter-kit redprints-alloc-r4 pingcrm; do
  RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 LOWRAIL_BUILD_JIT=0 mise exec -- \
    target/debug/lowrail build ".corpus/$app" --env production --passes default
done
mise exec -- ruby bench/experiments/allocations_study.rb /tmp/alloc-census
BENCH_JIT=0 mise exec -- ruby bench/experiments/allocations_micro_study.rb /tmp/alloc-micro-int
# YJIT requires the shared warm-to-flat / per-window counter proof as well.
BENCH_JIT=1 mise exec -- ruby bench/experiments/allocations_micro_study.rb /tmp/alloc-micro-jit
mise exec -- ruby bench/experiments/allocations_report.rb /tmp/alloc-census \
  int-blog=/tmp/alloc-micro-int/blog int-props=/tmp/alloc-micro-int/props \
  int-frozen=/tmp/alloc-micro-int/frozen jit-blog=/tmp/alloc-micro-jit/blog \
  jit-props=/tmp/alloc-micro-jit/props jit-frozen=/tmp/alloc-micro-jit/frozen
```

The report generator preserves this explanatory header and replaces only the
tables below; a new study also needs its provenance and micro narrative
updated, rather than relabeling historical results. Numeric exports contain
allocation counts and fingerprints, not heap contents, authentication or
response bodies. To avoid repeating long
file/class paths 20,000 times, `allocations-results.json` declares dictionaries
and `callsite_columns`; a row's first/third fields index `files`/`classes`, and
its last two are allocated/retained counts for the whole N-request window.

<!-- generated allocation tables -->

## Request allocation census

All values are objects/request. GC total is the median of three 100-request blocks. S/H/A/P/O = String (including SafeBuffer subclasses), Hash, Array, Proc, other **enumerable** objects; residual is GC total minus the bounded trace's enumerable count. Retained is after three full GCs, divided by N=20, not an extrapolated leak rate.

| App / route / arm | GC total | S | H | A | P | O | Trace residual | Retained |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| blog-edit-html-default | 1691.24 | 655.90 | 280.00 | 391.00 | 23.00 | 165.00 | 177.45 | 0.00 |
| blog-edit-html-off | 1715.56 | 662.50 | 286.00 | 399.00 | 23.00 | 165.00 | 180.45 | 0.00 |
| blog-index-html-default | 2254.14 | 842.95 | 288.00 | 623.00 | 23.00 | 256.00 | 221.45 | 0.00 |
| blog-index-html-off | 2377.61 | 875.10 | 318.00 | 665.00 | 23.00 | 256.00 | 240.45 | 0.00 |
| blog-show-html-default | 2233.62 | 882.70 | 355.00 | 528.00 | 23.00 | 237.00 | 207.45 | 0.00 |
| blog-show-html-off | 2253.10 | 889.70 | 361.00 | 534.00 | 23.00 | 237.00 | 210.45 | 0.00 |
| pingcrm-contacts-html-default | 3473.15 | 901.95 | 485.00 | 1149.00 | 36.00 | 540.00 | 362.45 | 0.10 |
| pingcrm-contacts-html-off | 3473.65 | 903.35 | 485.00 | 1149.00 | 36.00 | 540.00 | 362.45 | 0.10 |
| pingcrm-contacts-json-default | 3059.69 | 703.65 | 419.00 | 1051.00 | 33.00 | 521.00 | 332.45 | 0.10 |
| pingcrm-contacts-json-off | 3060.00 | 703.55 | 419.00 | 1051.00 | 33.00 | 521.00 | 332.45 | 0.10 |
| pingcrm-organizations-html-default | 2945.99 | 793.55 | 419.00 | 948.00 | 35.00 | 436.00 | 315.45 | 0.10 |
| pingcrm-organizations-html-off | 2945.14 | 791.90 | 419.00 | 948.00 | 35.00 | 436.00 | 315.45 | 0.10 |
| pingcrm-organizations-json-default | 2532.01 | 595.00 | 353.00 | 850.00 | 32.00 | 417.00 | 285.45 | 0.10 |
| pingcrm-organizations-json-off | 2531.65 | 595.05 | 353.00 | 850.00 | 32.00 | 417.00 | 285.45 | 0.10 |
| redprints-proposal-html-default | 2408.33 | 634.90 | 342.00 | 769.00 | 34.00 | 370.00 | 259.50 | 0.00 |
| redprints-proposal-html-off | 2408.44 | 633.80 | 342.00 | 769.00 | 34.00 | 370.00 | 259.50 | 0.00 |
| redprints-proposal-json-default | 1878.45 | 403.70 | 262.00 | 605.00 | 31.00 | 349.00 | 228.50 | 0.00 |
| redprints-proposal-json-off | 1878.40 | 403.45 | 262.00 | 605.00 | 31.00 | 349.00 | 228.50 | 0.00 |
| redprints-proposals-html-default | 3494.51 | 1028.50 | 372.00 | 1066.00 | 33.00 | 711.00 | 285.50 | 0.00 |
| redprints-proposals-html-off | 3494.63 | 1027.80 | 372.00 | 1066.00 | 33.00 | 711.00 | 285.50 | 0.00 |
| redprints-proposals-json-default | 2966.24 | 797.85 | 292.00 | 902.00 | 30.00 | 690.00 | 254.50 | 0.00 |
| redprints-proposals-json-off | 2966.48 | 797.80 | 292.00 | 902.00 | 30.00 | 690.00 | 254.50 | 0.00 |
| starter-dashboard-html-default | 1979.85 | 787.85 | 237.00 | 484.00 | 29.00 | 252.00 | 190.45 | 0.00 |
| starter-dashboard-html-off | 1979.62 | 788.10 | 237.00 | 484.00 | 29.00 | 252.00 | 190.45 | 0.00 |
| starter-dashboard-json-default | 1246.99 | 348.50 | 189.00 | 335.00 | 26.00 | 201.00 | 147.45 | 0.00 |
| starter-dashboard-json-off | 1246.30 | 348.60 | 189.00 | 335.00 | 26.00 | 201.00 | 147.45 | 0.00 |
| starter-profile-html-default | 2053.05 | 840.45 | 237.00 | 487.00 | 30.00 | 260.00 | 199.45 | 0.00 |
| starter-profile-html-off | 2052.59 | 841.65 | 237.00 | 487.00 | 30.00 | 260.00 | 199.45 | 0.00 |
| starter-profile-json-default | 1313.64 | 396.00 | 189.00 | 337.00 | 27.00 | 209.00 | 156.45 | 0.00 |
| starter-profile-json-off | 1313.80 | 396.05 | 189.00 | 337.00 | 27.00 | 209.00 | 156.45 | 0.00 |

### Retained by type

Counts are **objects in the whole 20-request window**, not per request. Every unlisted app/route/arm has zero traced survivors of all five types. All remaining enumerated objects were garbage; no heap graph or retained-byte claim is made.

| Profile | String | Hash | Array | Proc | Other |
|---|---:|---:|---:|---:|---:|
| pingcrm-contacts-html-default | 0 | 1 | 1 | 0 | 0 |
| pingcrm-contacts-html-off | 0 | 1 | 1 | 0 | 0 |
| pingcrm-contacts-json-default | 0 | 1 | 1 | 0 | 0 |
| pingcrm-contacts-json-off | 0 | 1 | 1 | 0 | 0 |
| pingcrm-organizations-html-default | 0 | 1 | 1 | 0 | 0 |
| pingcrm-organizations-html-off | 0 | 1 | 1 | 0 | 0 |
| pingcrm-organizations-json-default | 0 | 1 | 1 | 0 | 0 |
| pingcrm-organizations-json-off | 0 | 1 | 1 | 0 | 0 |

## blog: top 30 allocating file:line + class pairs

Equal-weight mean across this app's measured routes/formats, **not a traffic mix**. Off selects the ranking; Default is the same callsite/class in the paired default process. Different classes on the same line are separate rows. Classifications and their exact mechanisms/certificates are defined above; `a/opaque` is deliberately not credited as removable. Full per-route counts are in the numeric export.

| Allocating file:line | Class | Off | Default | Class / mechanism |
|---|---|---:|---:|---|
| `GEM/actionview-8.1.4/lib/action_view/helpers/tag_helper.rb:309` | `String` | 79.67 | 70.33 | c/tag |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/string/output_safety.rb:242` | `ActiveSupport::SafeBuffer` | 50.00 | 50.00 | b/form |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/string/output_safety.rb:71` | `String` | 48.00 | 48.00 | b/form |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/erb/util.rb:143` | `String` | 44.67 | 44.67 | b/form |
| `<internal:array>:246` | `Array` | 38.00 | 38.00 | a/opaque |
| `GEM/actionview-8.1.4/lib/action_view/helpers/tag_helper.rb:237` | `String` | 32.00 | 27.33 | b/form |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/hash/keys.rb:11` | `Hash` | 19.00 | 14.33 | b/form |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:145` | `String` | 18.00 | 18.00 | c/static |
| `<internal:array>:271` | `Array` | 15.67 | 15.67 | a/opaque |
| `GEM/uri-1.1.2/lib/uri/common.rb:456` | `String` | 15.62 | 15.03 | a/io |
| `GEM/actionpack-8.1.4/lib/action_dispatch/journey/visitors.rb:40` | `Array` | 14.67 | 5.33 | c/route |
| `GEM/actionview-8.1.4/lib/action_view/helpers/tag_helper.rb:232` | `String` | 14.00 | 9.33 | b/form |
| `GEM/activerecord-8.1.4/lib/active_record/integration.rb:59` | `String` | 14.00 | 14.00 | c/param |
| `GEM/sqlite3-2.10.1-x86_64-linux-gnu/lib/sqlite3/statement.rb:143` | `String` | 13.33 | 13.33 | a/data |
| `GEM/activesupport-8.1.4/lib/active_support/callbacks.rb:179` | `Proc` | 10.67 | 10.67 | c/callback |
| `GEM/actionview-8.1.4/lib/action_view/helpers/tag_helper.rb:484` | `String` | 10.33 | 10.33 | b/form |
| `<internal:pathname_builtin>:360` | `String` | 10.00 | 10.00 | a/opaque |
| `GEM/actionview-8.1.4/lib/action_view/structured_event_subscriber.rb:61` | `String` | 10.00 | 10.00 | b/event-path |
| `GEM/i18n-1.15.2/lib/i18n/utils.rb:8` | `Hash` | 10.00 | 10.00 | b/form |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:145` | `Array` | 9.00 | 9.00 | c/static |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:146` | `String` | 9.00 | 9.00 | c/static |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:156` | `String` | 9.00 | 9.00 | c/static |
| `GEM/base64-0.3.0/lib/base64.rb:283` | `String` | 8.33 | 8.33 | a/io |
| `GEM/actionpack-8.1.4/lib/action_dispatch/http/request.rb:66` | `Rack::Request` | 8.00 | 8.00 | a/io |
| `GEM/actionview-8.1.4/lib/action_view/helpers/tags/base.rb:12` | `String` | 8.00 | 8.00 | b/form |
| `GEM/importmap-rails-2.2.3/app/helpers/importmap/importmap_tags_helper.rb:42` | `Array` | 8.00 | 8.00 | b/preload-tags |
| `GEM/actionview-8.1.4/lib/action_view/helpers/tag_helper.rb:288` | `String` | 7.67 | 7.67 | b/form |
| `GEM/actionpack-8.1.4/lib/action_controller/metal/url_for.rb:49` | `Hash` | 7.33 | 7.33 | c/url-options |
| `GEM/actionpack-8.1.4/lib/action_dispatch/http/url.rb:170` | `String` | 7.33 | 7.33 | b/url-residue |
| `GEM/actionpack-8.1.4/lib/action_dispatch/journey/visitors.rb:51` | `String` | 7.33 | 2.67 | c/route |

## starter: top 30 allocating file:line + class pairs

Equal-weight mean across this app's measured routes/formats, **not a traffic mix**. Off selects the ranking; Default is the same callsite/class in the paired default process. Different classes on the same line are separate rows. Classifications and their exact mechanisms/certificates are defined above; `a/opaque` is deliberately not credited as removable. Full per-route counts are in the numeric export.

| Allocating file:line | Class | Off | Default | Class / mechanism |
|---|---|---:|---:|---|
| `GEM/uri-1.1.1/lib/uri/common.rb:465` | `String` | 29.00 | 29.00 | a/io |
| `<internal:array>:246` | `Array` | 28.25 | 28.25 | a/opaque |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:145` | `String` | 18.00 | 18.00 | c/static |
| `RUBY/net/http.rb:1058` | `String` | 17.00 | 17.00 | b/ssr-setup |
| `GEM/uri-1.1.1/lib/uri/common.rb:456` | `String` | 16.75 | 16.35 | a/io |
| `GEM/activesupport-8.1.4/lib/active_support/callbacks.rb:179` | `Proc` | 14.50 | 14.50 | c/callback |
| `GEM/activemodel-8.1.4/lib/active_model/attribute.rb:9` | `ActiveModel::Attribute::FromDatabase` | 13.00 | 13.00 | a/data |
| `RUBY/net/http/header.rb:498` | `String` | 13.00 | 13.00 | b/ssr-headers |
| `RUBY/net/http/response.rb:181` | `String` | 13.00 | 13.00 | a/io |
| `GEM/json-3.0.2/lib/json/common.rb:302` | `String` | 12.55 | 12.55 | a/data |
| `GEM/rack-3.2.7/lib/rack/mock_response.rb:139` | `String` | 12.05 | 12.05 | a/rack-client |
| `GEM/inertia_rails-3.22.0/lib/inertia_rails/props_resolver.rb:81` | `Array` | 11.00 | 11.00 | b/tuple |
| `GEM/inertia_rails-3.22.0/lib/inertia_rails/props_resolver.rb:82` | `String` | 11.00 | 11.00 | b/prop-path |
| `<internal:array>:228` | `MatchData` | 10.00 | 10.00 | a/opaque |
| `GEM/activesupport-8.1.4/lib/active_support/current_attributes.rb:236` | `Array` | 10.00 | 10.00 | b/tuple |
| `GEM/inertia_rails-3.22.0/lib/inertia_rails/props_resolver.rb:104` | `Array` | 10.00 | 10.00 | b/prop-dispatch |
| `<internal:symbol>:12` | `String` | 9.00 | 9.00 | a/opaque |
| `GEM/actionpack-8.1.4/lib/action_dispatch/http/request.rb:66` | `Rack::Request` | 9.00 | 9.00 | a/io |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:145` | `Array` | 9.00 | 9.00 | c/static |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:146` | `String` | 9.00 | 9.00 | c/static |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:156` | `String` | 9.00 | 9.00 | c/static |
| `GEM/inertia_rails-3.22.0/lib/inertia_rails/props_resolver.rb:231` | `Array` | 9.00 | 9.00 | b/prop-dispatch |
| `GEM/inertia_rails-3.22.0/lib/inertia_rails/props_resolver.rb:237` | `Array` | 9.00 | 9.00 | b/prop-dispatch |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/string/output_safety.rb:242` | `ActiveSupport::SafeBuffer` | 8.50 | 8.50 | a/data |
| `GEM/actionview-8.1.4/lib/action_view/helpers/tag_helper.rb:309` | `String` | 8.00 | 8.00 | c/tag |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_set/builder.rb:37` | `Array` | 8.00 | 8.00 | b/attribute-keys |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/erb/util.rb:143` | `String` | 8.00 | 8.00 | b/form |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/hash/slice.rb:25` | `Hash` | 8.00 | 8.00 | b/config-bind |
| `GEM/activesupport-8.1.4/lib/active_support/inflector/methods.rb:78` | `String` | 8.00 | 8.00 | b/inflection |
| `GEM/activesupport-8.1.4/lib/active_support/inflector/methods.rb:80` | `String` | 8.00 | 8.00 | b/inflection |

## redprints: top 30 allocating file:line + class pairs

Equal-weight mean across this app's measured routes/formats, **not a traffic mix**. Off selects the ranking; Default is the same callsite/class in the paired default process. Different classes on the same line are separate rows. Classifications and their exact mechanisms/certificates are defined above; `a/opaque` is deliberately not credited as removable. Full per-route counts are in the numeric export.

| Allocating file:line | Class | Off | Default | Class / mechanism |
|---|---|---:|---:|---|
| `GEM/sqlite3-2.9.5-x86_64-linux-gnu/lib/sqlite3/statement.rb:125` | `String` | 125.50 | 125.50 | a/data |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_methods.rb:273` | `Array` | 111.00 | 111.00 | b/store-read |
| `GEM/activemodel-8.1.4/lib/active_model/type/string.rb:39` | `String` | 90.00 | 90.00 | a/data |
| `<internal:array>:246` | `Array` | 62.00 | 62.00 | a/opaque |
| `GEM/tzinfo-2.0.6/lib/tzinfo/timestamp.rb:208` | `Rational` | 51.00 | 51.00 | a/data |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/date_and_time/zones.rb:34` | `ActiveSupport::TimeWithZone` | 36.00 | 36.00 | a/data |
| `GEM/frozen_record-0.27.4/lib/frozen_record/scope.rb:187` | `Array` | 36.00 | 36.00 | b/frozen-lookup |
| `GEM/tzinfo-2.0.6/lib/tzinfo/data_sources/constant_offset_data_timezone_info.rb:52` | `TZInfo::OffsetTimezonePeriod` | 36.00 | 36.00 | a/data |
| `GEM/tzinfo-2.0.6/lib/tzinfo/timestamp.rb:193` | `TZInfo::Timestamp` | 36.00 | 36.00 | a/data |
| `GEM/frozen_record-0.27.4/lib/frozen_record/scope.rb:262` | `Array` | 34.50 | 34.50 | b/frozen-lookup |
| `GEM/activerecord-8.1.4/lib/active_record/associations/association.rb:373` | `Array` | 32.00 | 32.00 | c/keys |
| `<internal:timev>:271` | `Time` | 25.50 | 25.50 | a/opaque |
| `<internal:array>:271` | `Array` | 23.00 | 23.00 | a/opaque |
| `GEM/activemodel-8.1.4/lib/active_model/attribute.rb:9` | `ActiveModel::Attribute::FromDatabase` | 22.50 | 22.50 | a/data |
| `GEM/uri-1.1.1/lib/uri/common.rb:465` | `String` | 20.00 | 20.00 | a/io |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:145` | `String` | 18.00 | 18.00 | c/static |
| `GEM/activesupport-8.1.4/lib/active_support/callbacks.rb:179` | `Proc` | 15.50 | 15.50 | c/callback |
| `GEM/sqlite3-2.9.5-x86_64-linux-gnu/lib/sqlite3/statement.rb:125` | `Array` | 15.00 | 15.00 | a/data |
| `GEM/uri-1.1.1/lib/uri/common.rb:456` | `String` | 13.86 | 14.39 | a/io |
| `GEM/activesupport-8.1.4/lib/active_support/core_ext/string/output_safety.rb:242` | `ActiveSupport::SafeBuffer` | 12.50 | 12.50 | a/data |
| `GEM/rack-3.2.6/lib/rack/mock_response.rb:139` | `String` | 12.05 | 12.05 | a/rack-client |
| `<internal:kernel>:48` | `FrozenRecord::Scope` | 12.00 | 12.00 | b/frozen-lookup |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_set/builder.rb:16` | `ActiveModel::LazyAttributeSet` | 12.00 | 12.00 | a/data |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_set/builder.rb:22` | `Hash` | 12.00 | 12.00 | a/data |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_set/builder.rb:28` | `Hash` | 12.00 | 12.00 | a/data |
| `GEM/activerecord-8.1.4/lib/active_record/associations.rb:79` | `Hash` | 12.00 | 12.00 | a/data |
| `GEM/activerecord-8.1.4/lib/active_record/result.rb:244` | `ActiveRecord::Result::IndexedRow` | 12.00 | 12.00 | a/data |
| `GEM/frozen_record-0.27.4/lib/frozen_record/scope.rb:299` | `FrozenRecord::Scope::Matcher` | 12.00 | 12.00 | b/frozen-lookup |
| `GEM/inertia_rails-3.21.2/lib/inertia_rails/props_resolver.rb:81` | `Array` | 12.00 | 12.00 | b/tuple |
| `GEM/inertia_rails-3.21.2/lib/inertia_rails/props_resolver.rb:82` | `String` | 12.00 | 12.00 | b/prop-path |

## pingcrm: top 30 allocating file:line + class pairs

Equal-weight mean across this app's measured routes/formats, **not a traffic mix**. Off selects the ranking; Default is the same callsite/class in the paired default process. Different classes on the same line are separate rows. Classifications and their exact mechanisms/certificates are defined above; `a/opaque` is deliberately not credited as removable. Full per-route counts are in the numeric export.

| Allocating file:line | Class | Off | Default | Class / mechanism |
|---|---|---:|---:|---|
| `<internal:array>:246` | `Array` | 76.50 | 76.50 | a/opaque |
| `GEM/activerecord-8.1.4/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `String` | 65.00 | 65.00 | a/data |
| `GEM/activemodel-8.1.4/lib/active_model/type/string.rb:39` | `String` | 45.00 | 45.00 | a/data |
| `GEM/activerecord-8.1.4/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `Array` | 38.50 | 38.50 | b/pg-types |
| `GEM/activerecord-8.1.4/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `Time` | 34.00 | 34.00 | a/data |
| `GEM/uri-1.1.2/lib/uri/common.rb:465` | `String` | 25.00 | 25.00 | a/io |
| `GEM/activerecord-8.1.4/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `Array` | 22.50 | 22.50 | a/data |
| `GEM/inertia_rails-3.23.0/lib/inertia_rails/props_resolver.rb:89` | `Array` | 22.00 | 22.00 | b/tuple |
| `GEM/inertia_rails-3.23.0/lib/inertia_rails/props_resolver.rb:90` | `String` | 22.00 | 22.00 | b/prop-path |
| `GEM/actionpack-8.1.4/lib/action_dispatch/http/content_security_policy.rb:336` | `String` | 20.00 | 20.00 | a/io |
| `GEM/uri-1.1.2/lib/uri/common.rb:456` | `String` | 18.51 | 18.59 | a/io |
| `GEM/actionpack-8.1.4/lib/action_dispatch/middleware/static.rb:145` | `String` | 18.00 | 18.00 | c/static |
| `GEM/activerecord-8.1.4/lib/arel/visitors/postgresql.rb:136` | `String` | 18.00 | 18.00 | b/query |
| `GEM/activemodel-8.1.4/lib/active_model/attribute.rb:9` | `ActiveModel::Attribute::FromDatabase` | 17.00 | 17.00 | a/data |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_set/builder.rb:16` | `ActiveModel::LazyAttributeSet` | 17.00 | 17.00 | a/data |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_set/builder.rb:22` | `Hash` | 17.00 | 17.00 | a/data |
| `GEM/activemodel-8.1.4/lib/active_model/attribute_set/builder.rb:28` | `Hash` | 17.00 | 17.00 | a/data |
| `GEM/activerecord-8.1.4/lib/active_record/associations.rb:79` | `Hash` | 17.00 | 17.00 | a/data |
| `GEM/activerecord-8.1.4/lib/active_record/result.rb:244` | `ActiveRecord::Result::IndexedRow` | 17.00 | 17.00 | a/data |
| `GEM/activerecord-8.1.4/lib/active_record/relation/predicate_builder.rb:50` | `Array` | 15.00 | 15.00 | b/query |
| `GEM/activerecord-8.1.4/lib/active_record/sanitization.rb:208` | `String` | 15.00 | 15.00 | b/query |
| `GEM/activesupport-8.1.4/lib/active_support/callbacks.rb:179` | `Proc` | 15.00 | 15.00 | c/callback |
| `GEM/jbuilder-2.15.1/lib/jbuilder.rb:354` | `Hash` | 15.00 | 15.00 | a/data |
| `<internal:kernel>:48` | `ActiveRecord::Relation` | 14.50 | 14.50 | a/opaque |
| `GEM/activerecord-8.1.4/lib/active_record/relation.rb:98` | `Hash` | 14.50 | 14.50 | b/query |
| `GEM/cancancan-3.7.0/lib/cancan/rule.rb:137` | `Array` | 14.00 | 14.00 | b/authorization |
| `GEM/inertia_rails-3.23.0/lib/inertia_rails/props_resolver.rb:120` | `Array` | 14.00 | 14.00 | b/prop-dispatch |
| `GEM/activerecord-8.1.4/lib/active_record/relation/predicate_builder.rb:87` | `Array` | 13.00 | 13.00 | b/query |
| `GEM/inertia_rails-3.23.0/lib/inertia_rails/props_resolver.rb:279` | `Array` | 13.00 | 13.00 | b/prop-dispatch |
| `GEM/inertia_rails-3.23.0/lib/inertia_rails/props_resolver.rb:285` | `Array` | 13.00 | 13.00 | b/prop-dispatch |
