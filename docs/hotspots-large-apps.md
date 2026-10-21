# Bet C: profile-guided specialization in larger apps

2026-10-21. **Exploration, not an optimization price or a support claim.**
Ruby 4.0.7, Rails 8.1.4, startup YJIT, Lowrail absent. Production-mode Rack
requests, unchanged application/configuration source, dependency-only overlays.
No Callgrind cohort, application patch, cache-policy override or GC tuning.

## Answer and next three passes

**Compile programs, not the hottest isolated method.** Framework work is
distributed across many small sites. The largest individual CPU sites are
GC, decompression, SQLite execution and response hashing; they are not
boot-invariant results that Lowrail can simply remove. Query construction is
the strongest app-specific specialization budget, especially in Fizzy.

| Rank | Next pass to prototype | Evidence and scope | Admission / stop rule |
|---|---|---|---|
| 1 | **Fixed relation-chain query programs** | Query-building self CPU: Fizzy **25.69%**, Campfire **11.96%**, Lobsters **8.17%**; objects **35.26 / 15.14 / 9.57%**. Fuse transient relation/where/Arel construction for a whole nonescaping call site, not another tiny association-reader cache. | Sealed-first candidate, not admitted by this study. Live binds, scopes, SQL execution, query cache and result lifecycle remain Rails-owned. Refuse escaping relations, arbitrary scope blocks/custom types and unsupported tenant/role/shard changes. Bet F owns implementation; this report supplies selection evidence. |
| 2 | **Whole typed render/helper programs** | View/render + helpers self CPU **13.91 / 9.68 / 11.46%**; objects **22.98 / 19.65 / 13.33%**. Tag/SafeBuffer/name-escaping intermediates occupy several of the top allocation sites. Compile a concrete fragment's helper/attribute/append program, not only `tag_option`. | Preserve dynamic output, escaping, iteration, lookup, cache-key effects and render/notification events. No app method/source changes. Certify actual builder/buffer/context and recheck after user conversions, or refuse. A fragment cache hit is not permission to bypass cache semantics. |
| 3 | **Whole fixed URL-generation programs** | Routing self CPU **1.02 / 1.55 / 6.18%**, objects **1.48 / 3.38 / 8.74%**. Asset-path checks add distinct helper costs; Lobsters also repeatedly computes title slugs. Fuse literal route/asset structure with live parameter conversion, rather than reviving quarantined caller-side route guards. | Start with one complete fixed-path program, not arbitrary `url_for`. Preserve `to_param`, script/host/protocol/locale, format/default/query ordering and fresh returned strings. Asset-host procs, custom route mappings and uncertified slug algorithms refuse. Prior route/default negative results remain negative; require an end-to-end net win before broadening. |

These percentages are **entire-area upper bounds before guards**, not projected
savings or claimed eligible coverage. Rank 3 is deliberately behind the much
larger relation and render programs. Generic cache codecs, ETag fusion and GC
policy changes are not recommended Lowrail passes from this evidence.

## What was actually run

| App | Exact source | Dependency input / data / requests |
|---|---|---|
| Fizzy | [basecamp/fizzy 6f1d200](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9) | `script/corpus fizzy`; checked-in dependency patch. External fixture built from upstream SQL fixtures, real session login; six GETs below. This historical pin is not current Fizzy and its known test-suite errors are not fixed by this profile. |
| Campfire | [once-campfire 02023b0](https://github.com/basecamp/once-campfire/commit/02023b0f0cafc4d66e06e43be072cf4d6ca328fa) | `script/corpus campfire-r81`, not the 8.2-alpha app. External 133-message fixture, 130 in the busy room, real session login; four GETs + one POST. Dedicated disposable Redis at the app's existing localhost:6379/0 setting. |
| Lobsters | [ruby/ruby-bench 351a39b](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716) | `benchmarks/lobsters`, external `fixtures/corpus/lobsters.Gemfile{,.lock}`; copied shipped SQLite database: **1,003 users / 11,000 stories / 26,638 comments / 183 tags**. Six anonymous GETs, not ruby-bench's historical authenticated/randomized vector and not live Lobsters. |

Lobsters satisfied the larger-app requirement without application edits; no
Mastodon/Discourse setup was needed. A first SQLite schema-load attempt failed
on the historical `unsigned` declaration. It was not patched: the successful
fixture is the database already shipped by ruby-bench.

Harness: [`large_app_profile.rb`](../bench/experiments/large_app_profile.rb).
One fresh boot per app/mode, routes in listed order. Each route has 100 warmups
and one checked response; CPU/wall profiles then cover 200 requests each,
object profiles 30 each, native observations three blocks of 100 each.
StackProf **0.2.28**, CPU/wall requested interval 1,000 µs, object interval 1.
Signal delivery/sampling is not an exact clock; CPU counts are not converted
into milliseconds. Native CPU uses the process clock, wall the monotonic clock.
All 17 routes returned 200 with nonempty bodies. Campfire's independent oracle
also checked ordered 40/40/12 message windows, sidebar content and POST
persistence/FTS/Turbo-stream content outside the sampled regions.

The app's existing caching, instrumentation and database behavior remain
enabled. Campfire POST creates additional messages in a separate room and
queues its ordinary work; its data/Redis state grows within a capture. It is
not a fixed read-only request distribution. No server, network, browser or
concurrent-user latency was measured. StackProf and the Rack client themselves
contribute overhead; native blocks exclude the sampling session but still
load the profiler and execute the same client.

### Native observations and per-route query-building budget

Wall is the median of three block means, with their **full min–max range**,
not a request percentile or confidence interval. CPU is the corresponding
median process CPU/request. Objects/request use unprofiled `GC.stat` deltas.
GC ms/request is total recorded GC time / 300 requests, rounded; GC stays on.
Query columns are independent CPU/object profile shares, **not native timings**.

| App / route | Wall ms [range] | CPU ms | Objects/request | GC ms/request | Query CPU % | Query objects % |
|---|---:|---:|---:|---:|---:|---:|
| Fizzy `/buckets` | 9.05 [8.24–11.27] | 9.05 | 9,007 | 1.36 | 24.68 | 41.91 |
| Fizzy `/bubbles` with two bucket IDs, creator and stage filters | 20.84 [20.59–21.64] | 20.83 | 22,467 | 1.20 | 25.60 | 39.96 |
| Fizzy `/account/users` | 5.55 [5.50–5.57] | 5.55 | 5,485 | 0.35 | 19.19 | 18.34 |
| Fizzy `/workflows` | 3.41 [3.37–3.51] | 3.41 | 3,786 | 0.21 | 15.66 | 11.23 |
| Fizzy `/notifications` | 3.87 [3.84–4.01] | 3.86 | 3,751 | 0.22 | 13.43 | 14.00 |
| Fizzy `/buckets/693169840/bubbles/613325334` | 23.76 [21.74–24.55] | 23.75 | 18,074 | 2.66 | 31.60 | 40.69 |
| Campfire room | 15.82 [15.66–19.26] | 15.67 | 15,426 | 0.78 | 10.73 | 12.95 |
| Campfire pagination | 9.23 [8.90–9.50] | 9.10 | 6,770 | 1.35 | 9.64 | 11.10 |
| Campfire sidebar | 7.73 [7.63–8.35] | 7.63 | 8,980 | 0.45 | 14.29 | 20.23 |
| Campfire search | 11.14 [10.38–11.55] | 10.49 | 7,964 | 1.64 | 12.56 | 14.98 |
| Campfire POST message | 13.07 [12.16–14.07] | 12.57 | 10,508 | 1.21 | 13.30 | 16.73 |
| Lobsters `/` | 8.70 [8.61–11.78] | 8.70 | 14,168 | 0.60 | 4.70 | 5.48 |
| Lobsters `/newest` | 9.89 [9.16–10.67] | 9.89 | 14,340 | 0.89 | 4.47 | 5.42 |
| Lobsters `/comments` | 7.51 [7.48–9.85] | 7.51 | 9,973 | 0.49 | 7.08 | 8.31 |
| Lobsters `/u` | 2.71 [2.71–3.57] | 2.71 | 1,485 | 0.31 | 3.85 | 9.57 |
| Lobsters `/s/enr7ye` | 3.93 [3.74–4.56] | 3.93 | 3,683 | 0.19 | 18.35 | 22.01 |
| Lobsters `/hottest` (JSON response) | 11.07 [11.07–12.34] | 11.07 | 15,082 | 0.79 | 12.79 | 15.13 |

Exact Fizzy query:
`/bubbles?bucket_ids%5B%5D=693169840&bucket_ids%5B%5D=664343589&creator_ids%5B%5D=127326141&stage_ids%5B%5D=66287381`.
Campfire's paths/verbs and independent expected windows are generated in
`scenario.json` by [`campfire_scenario.rb`](../bench/experiments/campfire_scenario.rb).
Lobsters `/active` and `/recent`, used by the separate native-benchmark bet,
are **not** measured by this export.

## Area aggregation

Cells are **CPU % / wall % / allocated-object %** of that app's sampled work.
Equal requests per route, not equal app weight or a production traffic mix.
All cells use exclusive self attribution, not inclusive wrapper time.

| Source-owning area | Fizzy | Campfire | Lobsters |
|---|---:|---:|---:|
| Routing | 1.02 / 1.25 / 1.48 | 1.55 / 1.85 / 3.38 | 6.18 / 4.94 / 8.74 |
| Controller callbacks | 0.38 / 0.50 / 0.38 | 0.78 / 0.71 / 0.72 | 0.39 / 0.56 / 0.37 |
| Params | 0.18 / 0.17 / 0.19 | 0.07 / 0.10 / 0.21 | 0.13 / 0.03 / 0.09 |
| AR query building | 25.69 / 25.25 / 35.26 | 11.96 / 10.97 / 15.14 | 8.17 / 9.05 / 9.57 |
| AR instantiation/attributes | 5.03 / 4.97 / 2.33 | 4.43 / 4.49 / 3.15 | 6.96 / 6.71 / 6.63 |
| View lookup/render | 4.59 / 4.59 / 5.53 | 4.32 / 4.20 / 4.51 | 4.80 / 4.87 / 4.68 |
| Helpers | 9.32 / 9.43 / 17.44 | 5.35 / 6.13 / 15.14 | 6.66 / 6.80 / 8.65 |
| JSON | 0.29 / 0.41 / 0.42 | 0.48 / 0.53 / 0.43 | 0.69 / 0.84 / 0.36 |
| Rack/middleware | 4.30 / 3.79 / 2.89 | 8.94 / 6.02 / 3.79 | 8.30 / 7.39 / 5.17 |
| Instrumentation/notifications | 1.46 / 1.15 / 1.59 | 1.26 / 1.01 / 0.95 | 0.56 / 0.63 / 0.49 |
| GC | 9.26 / 8.42 / 0 | 9.23 / 12.67 / 0 | 9.77 / 8.66 / 0 |
| Database execution/cache | 14.03 / 14.41 / 6.71 | 10.97 / 10.45 / 5.29 | 4.67 / 5.30 / 2.72 |
| Cache/serialization | 0.85 / 0.80 / 0.32 | 9.56 / 9.12 / 4.32 | 9.55 / 9.08 / 8.96 |
| Active Support utilities | 10.17 / 9.90 / 11.30 | 10.08 / 9.63 / 14.07 | 14.35 / 15.62 / 15.64 |
| AR associations/preload | 2.75 / 3.21 / 2.91 | 3.14 / 2.72 / 7.70 | 2.16 / 2.22 / 4.36 |
| AR other/persistence | 1.29 / 1.51 / 0.59 | 2.55 / 1.94 / 4.15 | 1.60 / 1.59 / 1.32 |
| App Ruby | 0.64 / 0.75 / 1.01 | 0.74 / 0.43 / 0.50 | 3.67 / 3.86 / 11.44 |
| Other gems/runtime | 8.39 / 9.02 / 8.60 | 14.18 / 16.52 / 15.27 | 10.85 / 11.31 / 10.09 |
| Harness | 0.38 / 0.48 / 1.03 | 0.41 / 0.51 / 1.28 | 0.52 / 0.55 / 0.73 |
| Explicit sampler residual | 0 / 0 / 0 | 0 / 0.0072 / 0 | 0 / 0 / 0 |

`AR instantiation/attributes` is a source-area bucket, **not** a measurement
of `instantiate_instance_of` alone. Custom typed-store gems remain in other
gems. Utilities such as escaping can belong to Active Support even when a
view called them. Notifications are attributed before the broader AS bucket.
The exporter owns the deterministic classification; original frames remain
available to regroup it. This refines the preliminary broad Fizzy AR figure
sent during discovery: **25.69% query building**, not 30.63%; attributes,
associations and persistence are reported separately rather than hidden there.

For Bet F, these narrower **overlapping diagnostic path queries** can be
reproduced over `apps[app].profiles[mode].ranked_self`. Each cell is CPU/object %:

| Path family | Fizzy | Campfire | Lobsters |
|---|---:|---:|---:|
| `/arel/` | 3.89 / 6.25 | 2.14 / 3.40 | 1.08 / 1.83 |
| `/active_model/attribute`, `/active_model/type`, `/active_record/attribute`, `/active_record/type` | 3.04 / 1.37 | 3.10 / 2.26 | 7.39 / 7.39 |
| `/relation/spawn_methods`, `/relation/query_methods`, `/relation/where_clause`, `/relation.rb`, `/relation/delegation` | 10.49 / 16.87 | 4.84 / 6.03 | 4.06 / 5.38 |

These are string-path families, not disjoint semantic budgets. For example
the type family can include type-casting work inside query construction.
Do not sum this table into a new instantiation or query-building claim.

## Exactness contracts used in the site judgments

These are **requirements for a possible pass**, not certificates this study
has earned. Profiling supplies frequency, never a proof that a type/config
fact is invariant. The current [quarantine](passes/suppressed-hooks.md) and
[sealed admission policy](sealed.md) still apply.

* **G — GC:** no direct Lowrail specialization of marking/sweeping. Preserve
  reachable objects, finalization and observable identity. Allocation reduction
  elsewhere may reduce GC; neither magnitude nor linearity follows here.
* **C — cache/data decoding:** facts would include coder/serializer/compressor,
  version/expiry policy and complete returned graph semantics. Cached bytes,
  expiration and external writers stay live. No shared mutable decoded result,
  skipped `_load` hooks, changed aliasing or assumed immutable Redis/DB data.
  Generic Marshal/YAML/decompression is refused as an invariant result. A
  purpose-built codec is an upstream candidate, not an exact Lowrail shortcut.
* **D — database:** visitor/adapter/pool/connection identity, schema, prepared
  mode, role/shard and statement lifecycle must match. SQL/binds, query cache,
  notifications, transaction/error timing and row materialization remain live.
  Lowrail cannot remove SQLite stepping/required returned rows. A future
  prepared-statement lifecycle optimization needs independent evidence.
* **E — response digest:** body bytes, middleware order, digest algorithm and
  streaming/enumeration semantics matter, not just a stable route. Dynamic
  response bytes still need hashing. Refuse early constant ETags, changed
  iteration/close behavior or altered conditional responses. Only a certified
  whole producer could fuse work; that eligibility is not established here.
* **H — typed render:** certify implementation/owner/native facts, actual
  builder/buffer holder and view context, encoding/HTML-safety and literal
  attribute/name structure. Evaluate dynamic arguments and conversions once,
  in original order; keep effects/errors/events. Recheck the continuation
  after conversions or retain it in Rails. Refuse custom builders, unsafe
  mutable holders, overridden conversion/escaping, incompatible encodings,
  dynamic tag structure and unmodeled blocks. Fresh mutable public results stay
  fresh. Boot-only method facts are insufficient in the guarded tier.
* **U — URL/inflection:** certify route/asset manifest, resolver implementation,
  locale/inflection tables, static options, relative root and request host/
  script dependencies. Keep live `to_param`/`to_s` and recheck after them.
  Refuse dynamic route mappings, engine/script completion, host procs,
  custom slug methods or mutable inputs not certified at the actual use.
  Never cache a record-dependent slug based only on its model class/ID.
* **Q — fixed query program:** certify the nonescaping call-site AST, model,
  schema/type objects, scope/reflection implementations and actual visitor/
  connection, plus sealed or complete mutation certificates. Read current
  tenant/default scope/values/binds at their original evaluation points;
  preserve where-merge precedence, bind order, relation independence and
  return type. Refuse raw/custom Arel visitors, arbitrary blocks/custom types,
  mid-chain mutation, escaping/interrogated relations and unsupported pool/
  role/shard switches. Fall back before effects or resume a certified
  continuation; never replay a partially evaluated scope/conversion.
* **A — attributes/associations:** certify concrete model/schema/STI,
  reflection and type/attribute-set implementation. Preserve lazy reads,
  dirty tracking, callbacks, inverse identity, fresh mutable strings and
  custom type serialization. Refuse overridden accessors, custom types,
  unmodeled STI, schema swaps and alias-visible objects. A type declaration
  or observed class alone is not a copy-elision certificate.
* **N — notifications:** certify current subscriber sets, grouping, isolated
  execution context and event implementation at the actual event boundary.
  Keep payload production/order, listener exceptions and dynamic subscribers.
  Refuse arbitrary subscription churn/overridden notification code. Empty
  listeners may remove handle machinery only, not required payload effects.

### Reading ceilings correctly

The following tables rank **pooled observed work**, with source-gem versions
kept distinct. A “site” is native/internal leaf + nearest real Ruby caller +
sampled caller line, not a guessed native source line. Full file paths and
counts are in the appendix. Thus the same method at a different gem version
is a different site. No inclusive callback/render wrapper is treated as
removable. The top 20 are selected separately for CPU, wall and objects;
per-app and per-route rankings are also exported, not substituted for these.

For a site with fraction \(f\), deleting **all** of its self work would bound
time reduction by \(f\), and idealized speedup by \(1/(1-f)\), holding everything
else fixed. That is an Amdahl bound, not a forecast or confidence bound on
the true workload. Object percentages bound that site's object-count
reduction only, not bytes, retention or time. “≤ share” below is conditional
on proving eligibility; **0 direct** means the work is required or no exact
specialization is identified. Guard cost and eligible coverage are unpriced.
GC is separate: do not add the entire GC share to every allocation proposal.

## Top 20 CPU self-time sites

CPU denominator **8,443 samples**. “Upstream” records candidates only: no
foreign issue, comment or PR was opened. Generic/library improvements usually
belong upstream; app-fixed composition is Lowrail's opportunity.

| # | Site (caller line; native leaf where different) | Self % | Exact Lowrail judgment / ceiling | Upstream candidate? |
|---:|---|---:|---|---|
| 1 | GC marking | 4.868 | G: **0 direct**; secondary response to fewer allocations is unknown. | Ruby GC, not Rails; no policy recommendation from this profile. |
| 2 | GC sweeping | 4.524 | G: **0 direct**; do not count as a removable framework call. | Ruby GC candidate only. |
| 3 | AS Cache `LazyEntry#value:108` → `Zlib.inflate` | 3.245 | C: **0 identified** for live cache bytes; literal empty-entry shortcuts would not cover this work. | Cache codec/compression tradeoffs; behavior and workload study required. |
| 4 | sqlite3 2.5.0 `Statement#each:125` → `step` | 1.990 | D: **0 direct** for required database execution/rows. | Adapter/SQLite execution candidate, not Rails partial evaluation. |
| 5 | Rack 3.2.0 `ETag#digest_body:65` → digest append | 1.848 | E: **0 identified**; dynamic body must still be hashed. Whole-producer fusion is ≤ share, unproved. | Rack producer/digest fusion candidate, not a static ETag. |
| 6 | AS `marshal_load:40` → `Marshal.load` | 1.646 | C: no invariant value; decode/materialization remains live. **0 identified** removable budget. | Typed cache serialization candidate; preserve fresh graphs/hooks. |
| 7 | sqlite3 2.7.3 `Statement#each:125` → `step` | 1.149 | D: **0 direct**, distinct adapter-version site. | Adapter/SQLite candidate. |
| 8 | `String#blank?:159` → `Regexp#match?` | 1.125 | H/U: fold only certified literal/known-empty branches, not arbitrary user strings. Conditional **≤1.125%** across all callers; eligible fraction unknown. | Generic blank-check fast path may be better upstream; preserve Unicode/encoding. |
| 9 | Rack 2.2.24 `ETag#digest_body:71` → digest append | 0.888 | E: **0 identified**; do not merge version-specific behavior blindly. | Rack candidate. |
| 10 | sqlite3 2.5.0 `Statement#initialize:36` → prepare | 0.782 | D: required today; safe statement reuse could affect **≤0.782%**, not established by query compilation. | Adapter lifecycle/cache candidate is preferable. |
| 11 | `AssetUrlHelper#asset_path:192` → regexp match | 0.640 | U: fold URI test for a certified literal source and resolver; dynamic/custom host remains live. **≤0.640%**. | Generic regexp micro is upstream; fixed asset program is Lowrail. |
| 12 | Inflector `apply_inflections:382` → `String#sub!` | 0.580 | U: fixed literal + exact locale/rule table may fold; dynamic words/mutable rules refuse. **≤0.580%**. | Shared inflection caching only if mutation/return semantics preserved. |
| 13 | Rack 3.2.7 `ETag#digest_body:65` → digest append | 0.557 | E: **0 identified**, same restriction as rows 5/9. | Rack candidate. |
| 14 | `ActionView::OutputBuffer#<<:45` | 0.533 | H: fuse certified adjacent appends, retain escape/order/encoding and actual buffer. **≤0.533%** self; output bytes remain necessary. | Generic append improvement upstream; whole fragment Lowrail. |
| 15 | `TagBuilder#tag_option:309` | 0.497 | H: fixed typed attributes can eliminate intermediate assembly, not dynamic escaping. **≤0.497%** at this line. | Prefer generic Rails assembly improvement where possible; full-program pass separate. |
| 16 | `ERB::Util.xml_name_escape:145` → `String#match?` | 0.450 | H: certify literal valid attribute names, retain invalid/dynamic-name behavior. **≤0.450%**. | Generic literal/name fast path candidate; avoid duplicating Rails escaping. |
| 17 | sqlite3 2.7.3 `Statement#initialize:36` → prepare | 0.450 | D: reuse candidate **≤0.450%**, not an admitted Lowrail specialization. | Adapter preferred. |
| 18 | `AssetUrlHelper#asset_path:208` | 0.391 | U: fold known relative-root/path structure; keep request-dependent host/proc dispatch. **≤0.391%** at this line. | Whole fixed asset pipeline Lowrail; generic helper cleanup upstream. |
| 19 | `Psych::Parser#parse:62` → native parse | 0.379 | C: runtime bytes/YAML tags and object construction not boot invariants. **0 identified**. | Serializer/data-format candidate; no arbitrary YAML bypass. |
| 20 | `Arel::Visitors::Visitor#visit:28` | 0.343 | Q: fixed certified node/visitor program can bypass dispatch, not arbitrary Arel. **≤0.343%** for this leaf, much less than the whole query budget. | Generic visitor dispatch improvements upstream; fixed query program Lowrail. |

## Top 20 allocation sites

Object denominator **5,129,249 allocations** across 30 requests/route, counted
at interval 1. Fractions below are object counts, not CPU savings. Original
counts are retained so these need not be inferred from rounded percentages.

| # | Site | Objects | Share % | Exactness / theoretical object ceiling | Upstream candidate? |
|---:|---|---:|---:|---|---|
| 1 | `TagBuilder#tag_option:309` | 149,100 | 2.907 | H: assemble final tag without per-attribute temporary strings; keep fresh final output and dynamic escaping. **≤149,100**; not all are proven removable. | Generic Rails append fusion preferred for common cases; whole typed fragment remains Lowrail. |
| 2 | `marshal_load:40` → `Marshal.load` | 129,540 | 2.526 | C: fresh graph materialization often required. **0 identified** safe elision; replacing with shared decoded objects is inexact. | Serializer candidate, not a Lowrail memo. |
| 3 | `ERB::Util.xml_name_escape:143` | 79,890 | 1.558 | H: pre-escape certified literal names; preserve symbol/String conversion effects. **≤79,890**. | General literal-name path candidate. |
| 4 | `String#html_safe:242` → `String.new` | 72,990 | 1.423 | H: fuse only nonescaping intermediate wrappers into output; public fresh mutable SafeBuffer cannot become shared. **≤72,990**, escape analysis missing. | Rails output-buffer internals preferred for general use. |
| 5 | `SafeBuffer#initialize:71` → `String#initialize` | 69,600 | 1.357 | H: eliminate certified temporary copies, not required returned string storage. **≤69,600**. | Generic copy/append opportunity upstream. |
| 6 | `TagBuilder#tag_options:237` | 51,720 | 1.008 | H: compile ordered fixed keys/types into the whole tag; boolean/data/aria behavior stays exact. **≤51,720**. | Generic accumulator fusion candidate. |
| 7 | `ActiveRecord::Associations#association:60` | 33,030 | 0.644 | A: association object identity/cache/lifecycle is observable. Only nonescaping machinery could fuse; **≤33,030**, no eligible subset proved. | AR lazy association allocation candidate; not global object reuse. |
| 8 | Relation delegation `ClassMethods#create:139` → `Class#new` | 31,350 | 0.611 | Q: nonescaping relation-chain intermediates only. **≤31,350**; final public relation remains ordinary Rails. | General relation allocation improvement upstream; fixed chain Lowrail. |
| 9 | `ActiveRecord::Relation#initialize:77` | 31,350 | 0.611 | Q: same chain fusion, preserve model/table/predicate builder and independent state. **≤31,350**. | Same candidate, distinct allocation site; no double-counted inclusive cost. |
| 10 | Journey `Format#evaluate:40` → `Kernel#dup` | 28,590 | 0.557 | U: compile fixed route structure but return fresh mutable path. **≤28,590** temporary copies, not final path elision. | Generic formatter optimization candidate. |
| 11 | `WhereClause#extract_attributes:111` | 27,960 | 0.545 | Q: fixed predicate shape can omit repeated transient attribute lists. **≤27,960**, preserve custom node/reflection refusal. | General merge algorithm improvement upstream. |
| 12 | `WhereClause#merge:29` → `Array#\|` | 27,960 | 0.545 | Q: preserve precedence/equality/ordering; compile fixed merge with live binds. **≤27,960**. | Rails query-builder candidate. |
| 13 | `WhereClause#merge:29` | 27,960 | 0.545 | Q: fuse nonescaping WhereClause container, preserve caller-visible relations. **≤27,960**; separate leaf from row 12. | Rails allocation candidate. |
| 14 | Inflector `parameterize:138` → `String#gsub!` | 26,550 | 0.518 | U: dynamic slug bytes still transform; only fixed tables/structure can fold. **≤26,550**, no memo by record ID. | Generic transliteration/slug pipeline candidate. |
| 15 | Lobsters `Story#title_as_url:848` → `String#gsub` | 26,550 | 0.518 | U: specialize certified app+framework slug program with live title and exact max-length/drop-word/encoding rules; refuse overrides/custom conversions. **≤26,550** temporary strings. | App-specific algorithm; record only, no app patch/upstream post. |
| 16 | Notifications `Fanout#build_handle:287` → `Enumerable#map` | 26,100 | 0.509 | N: constant empty/subscriber groups could remove transient array only; payload/events remain. **≤26,100**. | Rails fanout fast path likely better upstream. |
| 17 | `ActiveModel::Attribute.from_database:9` | 25,980 | 0.507 | A: lazy/dirty identity may require attribute objects. **≤25,980** only after a concrete materializer proof; not removed by schema facts alone. | Rails materializer candidate; earlier Lowrail instantiate negative result remains. |
| 18 | `ActiveModel::Type::String#cast_value:39` → `String.new` | 25,350 | 0.494 | A: the copy protects mutable values. **0 identified** unconditional elision; nonescaping read-only region proof could bound by 25,350. | Rails custom-type-safe allocation candidate, not copy deletion. |
| 19 | `TagBuilder#prefix_tag_option:313` | 23,520 | 0.459 | H: fixed data/aria key prefixes may fold; values/JSON/conversions stay live and ordered. **≤23,520**. | Generic literal prefix opportunity upstream. |
| 20 | `AssetUrlHelper#asset_path:194` → `String#[]` | 22,500 | 0.439 | U: known literal source can fold query/fragment extraction; dynamic source refuses. **≤22,500**. | Generic helper candidate; whole fixed URL program Lowrail. |

The object leader is not the CPU leader. Lobsters' app-specific slug is
visible here despite low app CPU share; cache unmarshalling is its largest
allocation site (7.349% within Lobsters). A pass that saves objects but adds
Ruby dispatch/guards can still lose, as previous instantiate/memo experiments
demonstrated. Report allocations and GC beside time rather than assuming a
conversion from objects saved to milliseconds.

## Top 20 wall self-time sites

Wall denominator **39,405 samples**. Contracts/ceilings are explicit for
every row; repeated CPU sites retain the same exactness restrictions.

| # | Site | Wall % | Exact Lowrail judgment / ceiling | Upstream candidate? |
|---:|---|---:|---|---|
| 1 | GC sweeping | 5.063 | G: 0 direct; secondary effect unknown. | Ruby GC only. |
| 2 | GC marking | 4.916 | G: 0 direct; do not add twice. | Ruby GC only. |
| 3 | Cache `LazyEntry#value:108` → inflate | 3.236 | C: 0 identified for dynamic bytes. | Cache codec/compression. |
| 4 | sqlite3 2.5.0 `Statement#each:125` → step | 1.962 | D: 0 direct for required rows/execution. | SQLite/adapter. |
| 5 | Cache `marshal_load:40` → load | 1.447 | C: 0 identified, fresh graph/hooks required. | Serialization. |
| 6 | `String#blank?:159` → regexp match | 1.315 | H/U: only certified literals/branches, ≤1.315%. | Generic blank checks. |
| 7 | redis-client `BufferedIO#fill_buffer:213` → `IO#wait_readable` | 1.216 | C: **0 direct**; Redis response/ordering and external state remain live. Boot facts do not eliminate IO. | Redis/client round trips; no app cache-policy change. |
| 8 | sqlite3 2.7.3 `Statement#each:125` → step | 1.183 | D: 0 direct for required rows/execution. | SQLite/adapter. |
| 9 | Rack 3.2.0 `ETag#digest_body:65` → digest append | 1.005 | E: 0 identified; certified producer fusion ≤1.005%, unproved. | Rack. |
| 10 | Rack 2.2.24 `ETag#digest_body:71` → digest append | 0.812 | E: 0 identified; fusion ≤0.812%, unproved. | Rack. |
| 11 | sqlite3 2.5.0 initialize:36 → prepare | 0.650 | D: lifecycle reuse ≤0.650%, not proved. | Adapter preferred. |
| 12 | `asset_path:192` → regexp match | 0.617 | U: literal certified asset program ≤0.617%. | Generic upstream / fixed program Lowrail. |
| 13 | Inflector `apply_inflections:382` → sub! | 0.568 | U: fixed words/rules ≤0.568%. | Inflection algorithm/cache. |
| 14 | `xml_name_escape:145` → match? | 0.482 | H: certified literal names ≤0.482%. | Generic name fast path. |
| 15 | sqlite3 2.7.3 initialize:36 → prepare | 0.467 | D: lifecycle reuse ≤0.467%, not proved. | Adapter preferred. |
| 16 | `TagBuilder#tag_option:309` | 0.459 | H: typed intermediate fusion ≤0.459%. | Rails append fusion. |
| 17 | `OutputBuffer#<<:45` | 0.459 | H: certified append fusion ≤0.459%; output stays live. | Rails output internals. |
| 18 | Psych parse:62 → native parse | 0.434 | C: 0 identified for live bytes/hooks. | Serializer/data format. |
| 19 | Rack 3.2.7 `ETag#digest_body:65` → digest append | 0.396 | E: 0 identified; fusion ≤0.396%, unproved. | Rack. |
| 20 | sqlite3 2.10.1 `Statement#each:143` → step | 0.391 | D: 0 direct; Lobsters adapter version remains separate. | SQLite/adapter. |

## Automatic profile → select units → build pipeline (design only)

1. **Capture a declared vector without Lowrail.** Pin app/dependencies,
   Ruby/Rails/JIT/fixture, request weights, cache state and source hashes.
   Export CPU/wall/object separately, GC and native blocks beside them.
   Retain failed captures/missed samples and all reconciliation residuals.
   No automatic retry-to-green, profile-driven app edits or dependency update.
2. **Map evidence to source-owned programs.** Normalize generated templates
   and VM addresses, not gem versions or different app source. Join sampled
   callers/edges/lines to Prism call-site IDs + original source digest and
   lazily observed facts. A missing generated-source mapping is a named
   refusal. StackProf edges here are aggregate call-graph evidence, not a
   complete dynamic caller-context profile; do not invent exact per-call-site
   eligible hit counts from them. A selected candidate needs a bounded
   follow-up reachability/type census.
3. **Generate candidates, then certify.** Recognize whole relation chains,
   render fragments and fixed URL programs in the original AST. Attach
   required boot facts plus live-input/continuation certificates and refusals.
   Observed classes can prioritize a type guard but cannot prove one.
   Never materialize extra app/framework constants to manufacture eligibility.
   Use natural witnesses/load hooks and leave unobserved units refused.
4. **Select under an explicit budget.** Store each candidate's exclusive
   CPU/wall/object share, observed routes, uncertain eligible coverage,
   dependency/guard cost estimate and implementation risk. Prefer large
   nonescaping programs with shared facts. Deduplicate overlapping regions
   so render wrappers/children or query wrappers/Arel are not both priced.
   A possible score is estimated exclusive saved CPU minus guard/delivery
   cost, with allocation reduction as a separate objective, not a fake time
   conversion. Unknown cost stays unknown; static largest-share selection is
   a shortlist, not automatic promotion.
5. **Build an ordinary opt-in artifact.** A future interface could be
   `lowrail build APP --profile PROFILE --budget ...`, but neither flag is
   implemented here. Reuse the pass registry/manifest, original bodies,
   source/compiler/JIT-mode contracts and reason-coded ledger. Record the
   profile input hash and candidate evidence with each unit. Stale profile,
   unavailable source or failed proof means a refusal/no-op, never a weakened
   guard or a compiler failure that breaks the app.
6. **Screen first, price rarely.** Follow the owner's updated 2026-10-21
   policy: a minutes-long screen uses deterministic allocations/request,
   exact-output checks and a short alternating native YJIT run (e.g. three
   rounds), with an A/A noise observation. Use Bet A's shared `script/screen`
   once published; this profile study has no optimization arm to screen.
   Promote a clear signal (rule of thumb: more than 3× A/A noise), or make
   one improvement attempt and kill a no-win prototype with a five-line
   `DECISIONS.md` note. Variants on the exploration branch need no sequential
   approval; report only win/kill/blocker milestones. Main still requires
   identical outputs, DB state, own suites and Thermos; support claims still
   need `lowrail verify` with nonzero hits. Reserve at most one approved
   Callgrind cohort per bet for a result intended for the README, using
   `lowrail bench`'s fixed-heap/A/A and applicable actual-window JIT gates.
   Retain rejected cohorts and zero-unit/setup controls. Profiles never
   authorize promotion, deployment or upstream PRs.

## Reproduction and transferable inputs

The first published evidence checkpoint is
[`28e4af5`](https://github.com/thomasklemm/lowrail/commit/28e4af5eb3bc03f0e9a2dd89ae669a6c5f8e2af3)
on `thomasklemm/profile-guided-hotspots`. Captures were made against local
base [`0b920af`](https://github.com/thomasklemm/lowrail/commit/0b920af29b0dfa7c5441e36af20db0447978bfe8)
before that checkpoint was rebased onto refreshed `origin/main`. Each input
records that base plus the actual, then-uncommitted profile-harness SHA256.
Earlier Fizzy/native captures predate the compactor-only changes; they are not
falsely attributed to a final clean harness revision. The rebase changes no
capture input. `campfire_scenario.rb` subsequently gained other entry modes;
its preparation/environment/Driver code used here is unchanged.

SHA256 pins (hex, not credentials):

| Input | SHA256 |
|---|---|
| `fixtures/corpus/lobsters.Gemfile` | `6308f24386e443332c5663aba64fa7b6eae931b8d1de0b0a04eed4f031873fd3` |
| `fixtures/corpus/lobsters.Gemfile.lock` | `105a3c0f736082a5714e1db0feb48dc96addb87dd9050051fc8b3d85e4f35fcf` |
| Shipped Lobsters `db/production.sqlite3` | `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820` |
| Lobsters prepared private `primary.sqlite3` | `b90816703504429b1926c97c50a960ce9a29235b7543f3159fbc441ed1e9406b` |
| `fixtures/corpus/fizzy.patch` | `78d3b143055f5157eb017584aba3b574fc753cb2610598235ec69d0aec4cdb08` |
| Fizzy effective lock | `73c7a5a94a644adb57aee1306144406ab9ae99e2c14521cbd1d86c4ee716a212` |
| `bench/experiments/fizzy_link_fixture.rb` | `2a396ed02e2c93509bb5b1ffe990ab2c5d26d16850732ea9bb79e22ce62b34ed` |
| Fizzy private seed `primary.sqlite3` | `5a0872611d7e477cdb002b239c380d4d14a18968640dddce3767462b39880d42` |
| `fixtures/corpus/campfire-r81.patch` | `3b2ba973b090bf0ac00891299baf695ea99002dcfdc4891bfa3c3fba3698fd91` |
| Campfire effective lock | `0429e4e3e73f5c49efad7c88014bea13e1461b3ca69af3b9900caaff749971f5` |
| `bench/experiments/campfire_scenario.rb` at capture base | `cb6df5ffb01b6b16c9007287224cb2bbbc25c4c4e61483a1f5767e12c4b25780` |
| Campfire private seed `primary.sqlite3` | `9132337651a1d6ccc7e3c04aaf3e65bcb8245e43f10fa91d47c27434d812b2d0` |

Lobsters' prepared copy undergoes ordinary SQLite connection/header changes;
the shipped original stays byte-identical. Do not mistake the two hashes for
the same file. Per-mode copies and Campfire POST output may subsequently
change. Fixture primary hashes alone do not certify every queue/cache DB or
regenerated fixture byte: fresh preparation includes timestamps/random secrets.
For exact old driver bytes use `git show` at the capture base; do not replace
a newer shared driver. No database, login cookie or secret is checked in.

Preparation outline, from the Lowrail repo, using new private directories:

```sh
ROOT="$PWD"
PRIVATE="$ROOT/.lowrail/private/hotspots-large-apps"
script/corpus fizzy
script/corpus campfire-r81

# Fixture preparation is not a profiled worker. It uses the existing
# interpreter-only helpers; production profile workers do NOT call their boot().
BUNDLE_GEMFILE="$ROOT/.corpus/fizzy/Gemfile" BUNDLE_FROZEN=true \
  mise exec ruby@4.0.7 -- bundle exec ruby \
  "$ROOT/bench/experiments/fizzy_link_fixture.rb" \
  "$ROOT/.corpus/fizzy" "$PRIVATE/fizzy-seed"
BUNDLE_GEMFILE="$ROOT/.corpus/campfire-r81/Gemfile" BUNDLE_FROZEN=true \
  mise exec ruby@4.0.7 -- bundle exec ruby \
  "$ROOT/bench/experiments/campfire_scenario.rb" prepare \
  "$ROOT/.corpus/campfire-r81" "$PRIVATE/campfire-r81-seed"

git clone https://github.com/ruby/ruby-bench "$ROOT/.corpus/ruby-bench"
git -C "$ROOT/.corpus/ruby-bench" checkout --detach \
  351a39b77e6c06f4f4fa03148639b10a6bb0c716
export BUNDLE_GEMFILE="$ROOT/fixtures/corpus/lobsters.Gemfile"
export BUNDLE_FROZEN=true
mise exec ruby@4.0.7 -- bundle install
RUBY_YJIT_ENABLE=1 RUBY_ZJIT_ENABLE=0 LOWRAIL=0 \
  mise exec ruby@4.0.7 -- bundle exec ruby --yjit \
  "$ROOT/bench/experiments/large_app_profile.rb" lobsters prepare \
  "$ROOT/.corpus/ruby-bench/benchmarks/lobsters" "$PRIVATE/lobsters-seed"
```

Run Campfire against a **dedicated disposable** Redis, not a developer/shared
DB. This orb used the supervised `hotspots-redis` service. The fixture helpers
read private `secret_key_base` files; do not copy a secret into a command/log.
Their environment hashes select production, isolated primary/cache/queue/
cable SQLite URLs as appropriate, SKIP_TELEMETRY=1 and Campfire's Redis/version
values. The profile harness merges `RUBY_YJIT_ENABLE=1`, `RUBY_ZJIT_ENABLE=0`,
`LOWRAIL=0`, removes `RUBYOPT`, then directly loads `config/environment`.
It **does not call the interpreter-only fixture `boot`** or change
`Rails.application.config.yjit`. Lobsters uses its upstream benchmark secret
configuration; startup YJIT remains enabled despite its config.yjit=false.

StackProf is an external observer, not an application overlay. Install 0.2.28
for Ruby 4.0.7 outside the app lock, and supply both its Ruby and extension load
paths. Resolve those before entering Bundler, for example:

```sh
export LARGE_APP_STACKPROF_LOAD_PATH="$(mise exec ruby@4.0.7 -- ruby -e \
  's=Gem::Specification.find_by_name("stackprof", "0.2.28"); puts s.full_require_paths.join(File::PATH_SEPARATOR)')"
# Choose one name/app/seed/bundle; copy the seed to a NEW per-mode STATE first.
# OUT must be an absolute NEW file path (the harness changes cwd to the app).
NAME=lobsters
APP="$ROOT/.corpus/ruby-bench/benchmarks/lobsters"
STATE="$PRIVATE/lobsters-cpu-reproduction"
OUT="$PRIVATE/lobsters-cpu-reproduction.json"
cp -a "$PRIVATE/lobsters-seed" "$STATE"
env -u RUBYOPT BUNDLE_GEMFILE="$ROOT/fixtures/corpus/lobsters.Gemfile" \
  BUNDLE_FROZEN=true RUBY_YJIT_ENABLE=1 RUBY_ZJIT_ENABLE=0 LOWRAIL=0 \
  mise exec ruby@4.0.7 -- bundle exec ruby --yjit \
  "$ROOT/bench/experiments/large_app_profile.rb" "$NAME" cpu "$APP" "$STATE" "$OUT"
```

Repeat `native`, `wall`, `object` with **separate fresh state copies/output
paths**. Fizzy/Campfire select their own app bundle instead of the Lobsters
wrapper. Small wrapper/lock files and pins were shared with Bets A/F; the
Lobsters DB is fetched from ruby-bench, not transferred. Private source data
and profiles in this orb live under `.lowrail/private/hotspots-large-apps/`;
the tracked JSON below is the portable, normalized profile export.

## Limits, failed observations and JSON appendix

* **No JIT-flat claim.** Compiled blocks/ISeqs grew inside native windows:
  e.g. Fizzy `/buckets` blocks 50,029→57,025; Campfire room
  67,143→74,221; Lobsters `/` 34,693→42,829. Each route retains endpoints
  around its three native blocks, not separate JIT endpoints per block.
  There are no A/A, heap or idle-companion controls and no optimization arm.
  Native milliseconds are direction-finding observations only, not a price,
  speedup, throughput result or proof of steady-state JIT performance.
* Native blocks run sequentially in a shared orb with normal GC and
  background app activity. The first Fizzy block is visibly noisy; full ranges
  remain. CPU profiles are sparse at individual sites; no confidence interval
  or deployment-wide ordering is inferred from a few dozen samples.
* Object counts are allocations, not allocation bytes or retained memory.
  GC sample fractions and `GC.stat[:time]` are different measurements in
  different runs. `GC.measure_total_time` was true. No GC suppression/tuning
  was used to improve a result.
* The first Campfire CPU capture failed a raw/self reconciliation assertion
  before export; the exact lost delta is unavailable. A single bounded
  accounting diagnostic reconciled 865 samples with one missed sample; this
  does **not** prove the original failure's cause. The harness was changed
  to expose signed residuals rather than throw away otherwise useful samples.
  In the new complete captures, Campfire wall room retains **one unmatched
  raw/report sample and one frame/report residual**. This is the same one
  sample, not two. It is an explicit area, never redistributed over hot sites.
* Captured/missed counts: Fizzy CPU **3,422/1**, wall **14,924/0**, objects
  **1,877,038/0**; Campfire **2,708/0**, **13,889/249**, **1,489,550/0**;
  Lobsters **2,313/0**, **10,592/9**, **1,762,661/0**. Campfire room contributes
  243 of its 249 missed wall samples. Missed samples are outside reported
  self denominators, not silently assigned to framework work. No retry until
  the wall capture became clean was performed.
* Stack compaction retains native leaf + real Ruby owner + **sampled line**,
  weighted by raw-stack multiplicity, rather than attributing native work to
  a method's definition line. GC stays separate. Original frame/line/edge
  counts are also preserved. `background` means the sampled stack lacks the
  capture frame, **not an identified background thread**; GC stacks also meet
  that heuristic. It is not used to subtract work from denominators.
* Fizzy's original interval-1 raw allocation capture was about 4.2 GB and
  peaked around 12 GB RAM. It was compacted offline, not rerun. Later captures
  compact after each route. The normalized export preserves the required
  attribution/counts/call graph, not every original raw stack or timestamp.
  Original failed logs remain private; they contain no usable full profile
  that can honestly be reconstructed in the appendix.
* Application tracked-file fingerprints match before/after every successful
  capture. Fizzy/Campfire diffs contain only `.ruby-version`, `Gemfile`, lock;
  ruby-bench has no tracked source changes. No Lowrail runtime/default/pass
  behavior changed, and no `lowrail verify` support claim is made.

**JSON appendix:** [`hotspots-large-apps.json`](hotspots-large-apps.json),
12 captures / 3 apps / 17 routes per mode. CPU **8,443**, wall **39,405**,
objects **5,129,249** reported samples. Produced by
[`large_app_profile_report.py`](../bench/experiments/large_app_profile_report.py).

Schema/navigation:

* `captures[]`: app/source/lock/harness hashes, profiler/runtime versions,
  original input hash/name, per-route status/body size/content type, GC/JIT
  endpoints, native blocks or full normalized `profile` frames/lines/edges,
  compact `self_sites`, `raw_report_residual`, `frame_report_residual`,
  missed samples and route-local `top20_self`.
* `apps[app].native[route]`: native wall range/median, CPU median,
  objects/request, GC counts/time, response facts.
* `apps[app].profiles[cpu|wall|object]`: total/missed counts, disjoint
  `area_samples`, complete `ranked_self` (not just the top 20).
* `pooled[cpu|wall|object]`: the same aggregation over observed work from all
  apps, preserving different gem versions and caller lines.

Export asserts that every route's weighted self sites, including any explicit
residual, reconcile to its reported sample count. All area denominators
reconcile; this does not assert the profiler captured every request cycle.
The capture-source/harness pins and all nonzero miss/residual values remain
visible rather than being normalized into a green optimization result.
