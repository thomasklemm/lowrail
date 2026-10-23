# Pass `route/path` — named-route `*_path` helpers

**Quarantined, not opt-in.** Neither `route/path` nor `view/link_to` can be
selected or delivered from old artifacts. The implementation and measurements
below are historical: argument evaluation and `to_param` can change the actual
route formatter after entry authorization. See the permanent counterexamples,
whole-artifact refusal and required continuation rewrite in
[the quarantine contract](endpoint.md#source-arm-quarantine). No safe source
arm remains active; the proposed refusal cache is parked, not published.

Code: `src/lower/route.rs` (pass), `gem/lib/lowrail/routes.rb` (runtime),
`gem/lib/lowrail/oracle_routes.rb` (build-time oracle side), route facts in
`gem/lib/lowrail/guard.rb`. Runs on compiled ERB (after `view/link_to`, so
route calls inside its fast path are lowered too) and on every `*.rb` under
`app/` except `app/assets` and `app/javascript`.

## What Rails does (Action Pack 8.1.4 and 8.2 alpha)

`name_path(*args)` is a `define_method` in the route set's anonymous
`path_helpers_module`. It pops a trailing `Hash` / `ActionController::Parameters`
as options and calls the route's `UrlHelper`. Routes without requirements
and without a glob get an `OptimizedUrlHelper`, whose fast branch runs when
`args.size == required_parts.size`, there are no options, and
`t.send(:optimize_routes_generation?)` (no `default_url_options` on the
route set or the caller):

```text
options = t.url_options.merge(route.defaults)
params  = {part_i => args[i].to_param}          # nil or "" → UrlGenerationError
path    = route.format(params)                  # Journey: static text + escape_segment(value);
                                                #   optional groups like (.:format) dropped
path   << "/" if options[:trailing_slash] && !path.end_with?("/")
original_script = options.delete(:original_script_name)
script  = t._routes.find_script_name(options)
script  = original_script + script if present
result  = script.to_s.chomp("/") << path        # Http::URL.path_for, + params/anchor keys
```

Everything else (`super`) goes through `RouteSet#url_for` with recall,
`path_params` and Journey's generator. In a request, a controller's
`url_options` is a fresh frozen hash with host, port, protocol, `_recall`
and `script_name` (`""` unless mounted), or `original_script_name` for
engines. 8.1.4 escapes a `:controller` segment with `escape_path`; 8.2 uses
`escape_segment` for all segments (the probes catch the difference).
Production frees the route AST after boot (`Route#glob?` raises there), so
globs are read from the path spec.

## What is specialized

Shape: receiverless call, no block, only positional arguments (no hash
literal, keywords, splats), exactly one per required part, inside an
instance method (any `def` without receiver in a Ruby file; always in a
template), arguments on one line. The pass emits, on the call's first line:

```ruby
((::Lowrail.ok?(U, self.class)) ? (__lr0a0 = ARG; (!(::Hash === __lr0a0 || ::ActionController::Parameters === __lr0a0) &&
  optimize_routes_generation? && (__lr0o = url_options.merge(::Rails.application.routes.named_routes.get(:edit_article).defaults)) &&
  ::String === (__lr0p0 = __lr0a0.to_param) && !__lr0p0.empty?) ?
  (::Lowrail::Routes.finish(+"" << "/articles/" << ::Lowrail::Routes.seg(__lr0p0) << "/edit", __lr0o, self, false)) : edit_article_path(__lr0a0)) : (edit_article_path(article)))
```

(one line in the output). Arguments are evaluated once, in order. Rails' own
conditions stay calls, so `default_url_options`, mounted script names and
`to_param` overrides behave as before. Options are merged before argument
conversion; the path is formatted before script-name resolution. `Routes.finish`
retains `find_script_name` on the actual route-set object and Rails' final URL
strategy, including option mutations made by that method. `Routes.seg` returns an ASCII value
with no character Journey would escape as is, else calls
`Journey::Router::Utils.escape_segment`. Templates add
`defined?(name) == "method"` for argument-less calls, since a local passed to
`render` may shadow the helper.

Facts per unit: each helper as `@self#name_path` with the route
(`name`, path spec, required parts, `defaults.inspect`), checked per class of
`self` (owner must be `Rails.application.routes.named_routes.path_helpers_module`,
route unchanged, no requirements, no glob), plus the Rails methods whose
behavior is inlined (`OptimizedUrlHelper#call/optimized_helper/parameterize_args/optimize_routes_generation?`,
`Journey::Route#format/required_parts`, `Journey::Format#evaluate`,
`Router::Utils.escape_segment`, `UriEncoder#escape_segment/escape`).
Redrawing routes redefines the helpers, which resets the units.

The first private-app iteration exposed a vacuous verify: an unrelated mounted
engine's singleton `find_script_name` disabled every route unit through a global
instance-override guard (0 hits, 794 fallbacks). That method and URL assembly are
now called, not inlined. Their global facts are no longer needed. Public emitted
Ruby tests check both path and URL helpers with mounted prefixes, options mutation,
defaults, escaping, trailing slash, query/anchor, and argument-conversion order.

## How it is proven at build time

The oracle (booted app) reports the route behind each helper and calls it
with marker arguments (`LRHP0Q`) to get the template; the pass refuses unless
each marker appears once and the static text is ASCII. It then evaluates the
exact inner expression it will emit next to the real helper call, for ~37
argument values per position (special characters, `/`, `%`, non-ASCII,
binary and broken UTF-8, UTF-16, `""`, `nil`, Integer, bignum, Float,
Symbol, Array, `{}`, options hash, `ActionController::Parameters`,
SafeBuffer, `BasicObject`, records with and without id), in five contexts
(the oracle's view; views and controllers of requests routed through the
app's route set with `SCRIPT_NAME` `""` and `"/sub/"`), comparing class,
bytes, encoding, frozen, html_safe, or exception class and message. Any
difference refuses the helper. In a `class` body (not a module) the oracle
also checks the helper resolves to the route set's method in that class.

## `*_url` helpers

Same shape as `*_path`, with `Routes.finish(..., true)`. Rails ends `OptimizedUrlHelper#call` in
`Http::URL.url_for(options)`: `path_for` with `:only_path`, else
`build_host_url(host, port, protocol, options, path_for(options))`.
Script completion remains a dynamic Rails call, including any option mutation.
The guard requires the helper to be the route set's URL helper module method.
Route defaults with host-part keys are still refused. Probes add an
`https://user.example.co.uk:8443` request context.

Historical measurement **before the dynamic finishing change** (real-blog,
controller with an HTTPS request, YJIT, 3 runs):
`article_url(article)` 4.6–5.1 → 2.6–3.0 µs, 24 → 16 allocations. Most of
what remains is the controller's `url_options` hash, which Rails builds on
every call.

### Request-local host normalization (2026-10-20)

Rails 8.1.4 and the pinned 8.2 alpha already snapshot host, optional port,
protocol, `_recall` and controller `default_url_options` in `@_url_options`.
The latter can read `Current`/locale; Rails captures that first result, not
every later value. Views delegate to their controller. Each call still selects
the script name from request routes, engine script name or original script name,
and duplicates/merges the base hash. Route-set defaults and
`optimize_routes_generation?` remain live. Replacing this with a second
controller-options cache would risk different invalidation semantics.

Instead, new `_url` expressions opt into host-only memoization with a fifth
`finish` argument. Four-argument calls in older manifests keep Rails' uncached
strategy. `url_options`, options merging, `to_param`, `find_script_name` and
`path_for` still run each call, in Rails' order. Only normalized host text is
stored on the request. Its key includes host, port, protocol, **port-key
presence**, `URL.secure_protocol`, and string encodings; strings are copied so
in-place mutations miss. Query/anchor, subdomain/domain/TLD, credentials,
non-scalar options and non-request contexts use Rails unchanged. The URL methods
bypassed by a cache hit are guarded; engine route sets are never globally guarded.
No rows, final paths or application override results are cached.

Oracle probes warm the cache then vary URL options on the same request, including
in-place changes. Runtime regression coverage changes script name, request,
defaults, a Current-style override, encoding, secure-protocol config and embedded
host ports. The emitted-Ruby engine ordering/mutation regression remains intact.

`bench/routes.rb`, production real-blog, YJIT, seven interleaved 200k-call
samples (construction includes controller `url_options` and AR `to_param`,
excludes the call-site guard):

| `article_url(article)` | median µs (min–max) | allocations |
|---|---:|---:|
| Rails | 3.711 (3.575–4.065) | 25 |
| Dynamic finishing, no host cache | 2.791 (2.741–2.900) | 18 |
| Request-local host cache | 2.205 (2.160–2.356) | 9 |

Five-app builds and per-test verification after combining the loader and engine
fixes: real-blog 21/21, 55 hits; Campfire 634/634 (2 skips), 7200 hits;
PingCRM 26/26 including system, 11 hits; Redprints 50/50 + 12/12 system,
25 + 19 hits; React Starter Kit 36/36, 25 hits. **Zero route-guard fallbacks**
throughout; real-blog recorded one existing `view/link_to` fallback (unit 0),
also seen in the loader-only run. No new sites are added by host memoization.

Production requests (`bench/requests.rb`, five alternating off/on fresh-process
pairs, YJIT, 200 warm-ups, 2 s/sample; same fixture cookies, default caches,
healthy starter SSR). These compare all enabled lowerings against Rails,
not host caching in isolation:

| Request | off µs median (min–max) | on µs median (min–max) |
|---|---:|---:|
| real-blog articles | 1563 (1538–1591) | 1505 (1322–1714) |
| real-blog article | 1616 (1589–1652) | 1514 (1462–1712) |
| Campfire room, cached | 2201 (1884–2272) | 1875 (1794–2133) |
| PingCRM organizations | 2599 (2550–2864) | 2423 (2311–2736) |
| Redprints proposals | 1682 (1641–1918) | 1690 (1634–1748) |
| Starter dashboard, SSR | 3280 (3185–3358) | 3302 (3008–3708) |

**Request-level effects are within noise** (overlapping cohort ranges).
The Inertia GETs mainly exercise rendering rather than the lowered redirect
sites; their allocation counts are effectively unchanged. real-blog articles
allocations fall 2404 → 2282 from the full view/route pipeline. No application
speedup is attributed specifically to host memoization.

### Block-backed `direct` / `resolve` helpers (2026-10-20)

No new shape is claimed. Campfire's 18 refused calls are six
`fresh_account_logo_path` (reads `Current.account` and its timestamp), seven
`fresh_user_avatar_path` (calls `avatar_token` and transforms the timestamp),
and five `rails_blob_path` (dispatches through the mutable
`resolve_model_to_route` setting). Redprints' `rails_blob_url` uses that same
Active Storage dispatch. None is a pure alias with unchanged arguments/options.
Active Storage's subsequent helpers also sign records and handle expiry,
filename and glob segments. Sampling their output cannot prove the app block's
branches or effects, and calling it twice could change behavior.

The ledger now records the block's source location and ISeq sends when its
identity is unique, explicitly naming the missing result-helper and
argument/option-mapping guards. Diagnostics never execute the block. The
runtime fixture exercises both `direct` and `resolve`, changes Current-style
state on the same view, checks once-only block execution, and proves the oracle
rejects an ordinary-helper forwarding candidate that drops that state/query.
The fake oracle checks that refusal leaves the source unchanged without probes.

All five apps rebuilt and verified again: 21 / 634 (2 skips) / 26 / (50 + 12
browser) / 36 outcomes identical, 57 / 7200 / 11 / (25 + 19) / 25 hits,
zero fallbacks. Gem suite: 60 runs, 1173 assertions, 3 optional skips, no
failures. This step changes diagnostics only, not runtime route generation.

Repeat micro (same seven-sample protocol): Rails 4.160 µs (3.917–4.635),
uncached lowering 3.119 (2.971–3.269), host cache 2.373 (2.326–2.867);
allocations remain 25 / 18 / 9. Repeat five-pair request runs, same protocol
as above, again have overlapping ranges: **within noise**, not a new speedup.

| Request | off µs median (min–max) | on µs median (min–max) |
|---|---:|---:|
| real-blog articles | 1761 (1655–1786) | 1620 (1451–2117) |
| real-blog article | 1725 (1701–1849) | 1843 (1551–2037) |
| Campfire room, cached | 2349 (2266–2678) | 2230 (2078–2312) |
| PingCRM organizations | 3033 (2936–3126) | 2952 (2791–3052) |
| Redprints proposals | 2027 (1899–2395) | 1998 (1895–2056) |
| Starter dashboard, SSR | 3627 (3594–3785) | 3546 (3396–3690) |

### Arity, defaults and recall (2026-10-20)

Campfire's 17 arity refusals all have a route-default `user_id: "me"`:
15 calls omit every argument, two pass one of two required parts. Describing
these as 17 missing request-recalled IDs was inaccurate. The oracle now reports
default-backed required parts and segment keys; the ledger identifies those
defaults, optional segments and the unsupported generic generator semantics.

They remain refused, not rewritten as an optimized helper with extra defaults.
Rails' generic helper first maps short argument lists after removing keys
supplied by controller options and route defaults. Without a `user_id` default,
one argument fills `user_id` and the last `id` can come from recall; with the
default, that argument fills `id`. Optional format supplied by `url_options`
is honored; recalled format alone is discarded for these named routes. Extra
arguments can fill optional format instead of being an error.

Crucially, generic `RouteSet#url_for` calls `find_script_name` **before** Journey
parameter conversion, and that method can mutate the parameters used to build
the path. Reusing the optimized helper's path-first `finish` would be wrong.
Exact specialization would need the generic generator's separate ordering,
argument mapping, option filtering and recall contract, not another scoped
RouteSet guard. The runtime fixture uses asymmetric IDs (41 / 23 / 9), supplied
versus recalled format, and an engine singleton that changes `user_id` before
`to_param`. New oracle probes reject naive default expansion on supplied format;
the fake oracle keeps short, default-backed and excess-argument calls unchanged.
No new units or arity-support claim are added.

Final five-app rebuild/verify repeats the preceding outcomes and hit counts,
with zero fallbacks in all six suites (including Redprints browser separately).
Rust: 24 unit + 2 integration tests pass; gem: 61 runs, 1183 assertions,
3 optional skips, no failures. Repeat micro: Rails 4.024 µs (3.934–4.188),
uncached lowering 3.052 (2.951–3.255), host cache 2.248 (2.179–2.525),
25 / 18 / 9 allocations. No runtime change is attributed to this refusal step.

Final five-pair request cohorts, same interleaved protocol: all ranges overlap,
so the request-level result is still **within noise**.

| Request | off µs median (min–max) | on µs median (min–max) |
|---|---:|---:|
| real-blog articles | 1614 (1579–1778) | 1656 (1601–1696) |
| real-blog article | 1642 (1617–1752) | 1659 (1582–1731) |
| Campfire room, cached | 2223 (2199–2462) | 2163 (2102–2229) |
| PingCRM organizations | 3032 (2863–3350) | 3044 (2865–3125) |
| Redprints proposals | 2024 (1708–2071) | 1995 (1731–2136) |
| Starter dashboard, SSR | 3718 (3583–3800) | 3668 (3473–3888) |

## Refused (ledger reasons)

Direct /
resolve helpers (`CustomUrlHelper`, e.g. `rails_blob_path`), explicit
receiver (`main_app.x_path`, `url_helpers.x_path`), options hash, arity ≠
required parts (generic mapping/defaults/recall, described above), not in an
instance method, a nested route call (the inner one is lowered), multi-line
arguments, requirements or glob, route defaults that set url options,
helper overridden in that class, probe mismatch.

## Results (2026-10-20, Ruby 4.0.7)

The real-blog/Campfire timings and hit counts below predate the dynamic finishing
change. They are not a performance claim for the new implementation; further
historical timings are recorded in
[Private Rails app with Inertia Rails](../m0/private-inertia-app.md).

| App | Route sites lowered | Units | `lowrail verify` |
|---|---|---|---|
| real-blog (8.1.4) | 10/10 (9 template, 1 controller) | 6 | 21/21 identical; 110 hits across all 11 units (link_to + route) |
| Campfire (8.2 alpha) | 108/162 with `_url` (51 of them `_url`; 27 Ruby files, 32 templates) | 59 | 634/634 identical (2 skips both ways); 52 units hit, 13238 hits, 0 fallbacks |

Before `_url` (57/162): 33 units, 12140 hits. Campfire refusals now:
18 direct helpers (`fresh_*`, `rails_blob_path`),
17 arity, 11 options hash, 4 explicit receiver, 2 model methods named like
route helpers (`Webhook#message_path`), 1 class-body call.

real-blog HTML (production build, `bench/requests.rb` `BENCH_DUMP`, CSRF
tokens masked): `/articles`, `/articles/1`, `/articles/1/edit`,
`/articles/new` byte-identical with `LOWRAIL=0` and `1`.

Micro (production, YJIT, view of a routed request, median of 5×300k):

| Call | Rails | lowered |
|---|---:|---:|
| `edit_article_path(article)` | 2701 ns | 1389 ns |
| `articles_path` | 1444 ns | 614 ns |

What remains is what Rails semantics require per call: `url_options`
265 ns (a dup per call in controllers), `optimize_routes_generation?`
121 ns, `article.to_param` 473 ns, the guard 82 ns.

Requests (real-blog, production, YJIT, 6 interleaved rounds of off /
link_to units only (`LOWRAIL_UNITS`) / link_to + route, 3 s per route after
200 warm-up requests):

| Route | off µs (min–max) | link_to only | + route | allocs off → + route |
|---|---|---|---|---:|
| GET /articles | 2056 (1948–2452) | 2084 | 1972 (−4.1 %) | 2378 → 2226 |
| GET /articles/1 | 2184 (1822–2561) | 1992 | 1998 (−8.5 %) | 2253 → 2227 |
| GET /articles/1/edit | 1464 (1324–1549) | 1437 | 1452 (−0.8 %) | 1716 → 1686 |
| GET /articles/new | 1319 (1098–1464) | 1256 | 1274 (−3.4 %) | 1594 → 1582 |

The spread inside one configuration (10–25 %) is larger than every
difference, so the request-time change is **within noise**. Allocations
are stable and drop by 1–6 %. Expected gain: real-blog renders few route
calls per request (~1.3 µs saved each), well under 1 % of a 1.3–2 ms
request.

## Open risks

- On the slow branch after a runtime condition fails, `url_options`,
  `optimize_routes_generation?` and `to_param` run again inside the helper
  (Rails itself calls `to_param` twice before raising). Pure in Rails; an
  app override with side effects would see an extra call.
- The guard calls `self.class`; an object overriding `class` would be
  checked against that answer.
- Fact names `call`, `format`, `evaluate`, `escape` are common: defining
  any method with those names resets the route units (re-validated on the
  next call per class). Harmless at boot, a cost if code defines such
  methods per request.
- Route facts compare spec, parts and defaults; requirements and globs are
  checked as absent. Engines' own helper modules and `main_app` calls are
  refused, not specialized.
- Ruby-file call sites without arguments rely on Prism's view of local
  variables; locals created by `eval`/`binding.local_variable_set` are not
  seen.
- `direct`/`resolve` helpers (18 in Campfire) and arity mismatches
  (17 default-backed Campfire calls, still requiring the generic generator)
  remain the largest refused groups.

## Host-only controller defaults: extension audit, not implemented

2026-10-20, following [the compiled-template coverage census](erb.md).
Campfire's measured production room reaches seven successful guards/request
but no completed lowering, because `SetCurrentRequest#default_url_options`
contains host/protocol. Four of these calls are `*_path`; three are `*_url`.
The following checks target **Rails 8.1.4**, not just the Campfire alpha.

Host/protocol/port are irrelevant to the final path bytes in ordinary cases:
[`RouteSet#url_for`](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_dispatch/routing/route_set.rb#L838-L900)
removes them as reserved keys before generation, and
[`Http::URL.path_for`](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_dispatch/http/url.rb#L169-L179)
does not read them. A named `*_path` already selects the `PATH` strategy;
it need not set an `only_path` key. `only_path: true` on generic `url_for`
selects that same final strategy, not a different generation algorithm.
Do not infer that a controller's host-only defaults imply host-only
**url_options**: real controllers also supply request `_recall` and
`script_name`/`original_script_name`.

Executed asymmetric real-controller comparisons of generic versus forced
optimized Rails helpers, route `/entries/:id`, argument `"a b"` from
`to_param`, route relative root `/relative-root-7`, request port **9551**,
default host/protocol/port with port **8449**. Both execute the actual Rails
helper; forcing the predicate is an experiment, not new Lowrail code.

| State | Generic and optimized path with a pure argument |
|---|---|
| Request script `/mount-3` | `/mount-3/entries/a%20b` |
| Request script `""` | `/entries/a%20b` (empty script wins over relative root) |
| No request script in this route context | `/relative-root-7/entries/a%20b` |
| Default options additionally contain `script_name: "/default-script-5"`, no request script | `/default-script-5/entries/a%20b`; this extra default key must be refused by the proposed allow-list |

Request recall deliberately also contains different `id: "27"` and
`format: "xml"`; the explicit full-arity argument wins in these controls,
and neither path has an XML suffix. These observations do not certify other
optional-segment/default/mapping shapes. The existing arity, explicit-option,
direct-helper and non-optimized-route refusals still apply.

**A host/protocol/port allow-list alone is not exact.** Rails'
[`OptimizedUrlHelper#call`](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_dispatch/routing/route_set.rb#L212-L267)
parameterizes and formats **before** resolving the script name. Generic
`RouteSet#url_for` resolves the script name **before** Generator/Journey
parameterization. TracePoints observe `[script, param]` versus `[param, script]`
in all four controls. A fifth test leaves defaults limited to the three
allowed keys and makes the argument's `to_param` change the route config's
relative root to `/changed-root-2`. No custom backend or engine method:

```text
generic Rails:          /relative-root-7/entries/a%20b
forced optimized Rails: /changed-root-2/entries/a%20b
```

That counterexample changes output, not merely tracing. Existing Lowrail
`Routes.finish` has optimized order, including setting `options[:path]`
before calling `find_script_name`. Simply relaxing its live predicate loses
generic semantics even if host/protocol/port cannot appear in the final path.

An exact **separate generic-order variant** is plausible, not proved by this
allow-list: retain the real `url_options` call, route-set defaults merge and
raw-argument mapping; resolve script/original-script first on the actual
options Hash; then specialize only the certified success path of
Generator/Formatter. Preserve optional/default/recall behavior, query extras,
conversion order/multiplicity, errors and mutable script-namer effects.
Unsupported state discovered after script resolution/conversion cannot
restart the entire original helper and repeat its side effects: it must
continue the real remaining generic operation with the captured state.
Requiring certified argument methods instead would shrink coverage and
needs its own eligibility census; receiver guard hits do not prove argument
purity. `*_url` host construction is outside this path-only proposal.

**Decision:** report this boundary before implementation. Do not broaden the
current optimized branch. No exact generic-order certificate/variant, new
hits, per-hit saving or expected request gain is claimed. Raw control output
is private at `.lowrail/erb-profile/rails-8.1.4.route-defaults.json`. This is
an executed semantics probe, not a new route support or speed certificate.

### Narrowing to certified parameter conversion

A second, off-only census used 20 warmups and ten requests per route, tracing
named-helper entry without changing its predicate. Campfire's four guarded
path calls have the following actual arguments (one call each/request):

| Helper; source | Positional arguments | Pure scalar-only condition | Base-AR extension candidate |
|---|---|---|---|
| `room_involvement_path`; `rooms/involvements/_bell:5` | `Rooms::Closed` | No | Yes, subject to the dependencies below |
| `searches_path`; `rooms/show/_composer:4` | none | Vacuously yes | Not needed |
| `room_messages_path`; `RoomsHelper#composer_form_tag` | `Rooms::Closed` | No | Yes, subject to the dependencies below |
| `user_path`; `Users::AvatarsHelper#avatar_tag` | `User` | No | Yes, subject to the dependencies below |

No String, Integer or Symbol was passed directly at these sites. Thus the
scalar-only proposal covers **one of four calls**, not all four. The other
three records have Integer `id`s, ordinary SQLite integer attribute types,
and unoverridden `ActiveRecord::Integration#to_param`, primary-key `id`,
`_read_attribute` and inherited `param_delimiter` readers at these boots.

Blog's observed named `*_path` calls are likewise either argument-less or
base-AR records, never directly passed scalars:

| Request | Calls/request | No arguments | Record arguments |
|---|---:|---:|---|
| Articles index (two fixture articles) | 9 | 1 (`new_article_path`) | 8: `article_path` × 6, `edit_article_path` × 2; all `Article` |
| Article show (one fixture comment) | 5 | 1 (`articles_path`) | `edit_article_path`, `article_path`, `article_comments_path`: `Article`; `article_comment_path`: `Article`, `Comment` |
| Article edit | 3 | 1 (`articles_path`) | `article_path` × 2: `Article` |

The counts include calls from polymorphic/form helpers as well as explicit
template calls: they are an argument census, **not new lowerable source
sites**. Blog already has an empty-defaults optimized branch; this proposed
default-options extension adds no demonstrated blog coverage. All observed
Article/Comment IDs are also Integers and their conversion readers have the
same base owners, with no app override.

On both Rails pins, base AR conversion is **not simply `id.to_s`**:
[`to_param`](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/integration.rb#L57-L60)
reads `id` twice, then `Array(id).join(self.class.param_delimiter)`. Certifying
only that method does not certify `id`, attribute storage/type-casting,
delimiter lookup, Array conversion/join or the ID's string conversion. The
observed ordinary integer IDs suggest coverage for all three remaining
Campfire calls, **if** that full conversion dependency set and the relevant
script-resolution methods can be certified side-effect-free; a class census
alone is not that proof. Singleton overrides, custom types/composite IDs and
unknown conversion methods need refusal or additional facts. Argument
expressions themselves must still be evaluated exactly once in source order.

No implementation is made here. The scalar-only path covers 1/4 Campfire
guarded path calls; the stronger base-AR proposal could cover 4/4, but remains
uncertified pending a decision after the template-lookup survey. Raw method
owners and per-site classes are private in
`.lowrail/erb-profile/{campfire,blog}.route-arguments.json`. No additional
hits, per-hit savings or route-speed claim is credited.
