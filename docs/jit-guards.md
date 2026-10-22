# Bet Y: non-creating guards

## Prospective protocol (2026-10-22)

Start from main and compare the external Fizzy DirectSite overlay at
[`936cc46`](https://github.com/thomasklemm/lowrail/commit/936cc462ffa2586a45458f6efa69d9717f965fe8)
with the same overlay using the existing native `exact_class?` primitive.
Do not remove method-body, visibility, schema, reflection, scope, connection
or mid-request checks. An existing singleton class, even an empty one, refuses
the new path. No app source/configuration edits or production admission.

Inventory and screen the unchanged main blog form/token/collection units too.
The necessary private implicit calls stay live: public sends and captured
helper bodies are not equivalent to Rails dispatch. Do not replay bet K's
rejected combined form/constant candidate as a new result.

Use Ruby 4.0.7 / Rails 8.1.4. Build official Ruby with
`--enable-yjit=stats --disable-install-doc` for diagnostic counters; use stock
`mise exec ruby@4.0.7 --` for allocations and interpreter checks. Pin
`BUNDLER_VERSION=4.0.20` before Bundler, and assert actual JIT state after
boot in every worker. Certificates match each actual Ruby build/mode.
Two-seed exact status/body/all-header comparisons and positive fast-path
hits with zero fallbacks precede measurement. Keep strict query shadows in
untimed coverage only. Use 2,000 warm requests and 500 stats requests, matching
K; retain every worker and all premeasurement failures.

**Screen gate:** singleton-send fallbacks must fall clearly from F's old-on
value to the same fixture's off value or below (historical target about
243/request). No allocation or interpreter-Ir regression. Report side exits,
all invalidation reasons, code GC, new compilation and window ratio-in-YJIT
separately; fallbacks are not exits. New compilation means diagnostic stats,
not a JIT-flat price. No ZJIT execution/speed claim from YJIT counters.

Only if exactness, counters and interpreter non-regression pass, run **one**
Fizzy `/buckets` real-Puma cohort using the existing `script/rps` harness at
`b1e239f` and the `44a33c4` / `544ad8d` protocol: 4 workers × 1 thread,
concurrency 16, 5 s warmup / 20 s load, 20 rotated off-A/on/off-B rounds.
Require A/A RPS's 95% interval to contain zero; treatment's RPS lower 95%
bound must exceed the A/A upper bound. All coverage workers must prove JIT
active, hits > 0 and fallback 0 before load. Run A/A admission first, retain
all rounds, no retries/exclusions. Record p50/p90/p99, allocations, GC and
worker state; no uniformly-faster claim when tails regress. Never push main.

## Guard inventory

| Unit / boundary | Exact facts and emitted shape | Decision |
|---|---|---|
| F `bucket_rows`, user | Actual User holder; live `persisted?`/integer ID; two effective public reader bodies. Old `singleton_methods.empty?` followed by captured `singleton_class.bind_call` and Module lookup | Replace creating lookup with native exact holder **after** live reads, then captured ordinary-class public/body checks. Keep ordinary ID/association sends visible. |
| F `Site#eligible?`, owner | Owner class, live persisted/integer ID, association/ID/persisted reader bodies and public visibility | Native exact holder before and after live reads; ordinary-class lookup only after that proof. Existing eigenclasses conservatively fall back. |
| F model and relation methods | Captured Module lookup and public visibility on model singleton class (class setup, not a record's eigenclass), model-specific relation delegates and WhereChain | Retain. No guard-created ordinary singleton class; hook-only or JIT-only invalidation cannot certify erased calls. |
| F schema/scope/reflection | Defaults, types/columns/table identity, current/global scope, role/shard, reflection identity/options/scope/keys, no query transformers | Retain live comparisons. JIT CME invalidation does not watch mutable data contents. |
| F association/connection | Actual association not loaded, no cached scope/public singleton overrides; connection/visitor identity and prepared mode; PID/database-config-qualified child rebind | Retain; singleton enumeration does not materialize an eigenclass. Fork rebinding is still bench-only. |
| Sealed admission, all three units | One natural original witness; source/binary/ISeq/visibility/holder/config/translation/route/template facts, mutex, one attempt, epoch before publication | Cold, not a per-request guard. No runtime autoload/materialization or new guard hooks. |
| Form hot entry | Main Ractor/epoch; exact Array/Proc/view/Article/Comment holders, options/block source, builder/buffer holder/context, locale and blank/unpersisted child | Existing native holder primitive creates no eigenclass. Captured ivar and block-source `bind_call` avoid app reflection overrides. Keep checks. |
| Form live helper boundary | Captured stock `BasicObject#instance_exec` invokes private `tag_builder`, `output_buffer`, `url_for`, `token_tag`; named route retains original public_send/new String | Retain. A public send changes private/method_missing semantics; a captured method body bypasses legitimate overrides. No new method/ancestry shim. |
| Token hot entry/continuation | Main Ractor/epoch, nil token, exact options/view/builder and view-context link; after generation/conversion recheck epoch and String/builder holders | Retain non-creating native checks and saved-value stock continuation. Never regenerate a token or reconvert its name. |
| Token live helper boundary | Captured instance_exec for defined?/private protection, generator/name calls, live autocomplete getter and fallback tag | Retain implicit dispatch. K's five constant-cache exits are known, but its combined capture/split candidate failed its screen; not claimed fixed here. |
| Collection hot entry/body | Main Ractor/epoch, exact renderer/view, nonnil template/no layout; lexical PartialIteration-shadow refusal at witness | Already ordinary method, constant and live iterator/Template sends. Preserve preload/locals/cache-key/render/event effects; no singleton/instance_exec rewrite needed. |

Runtime counters are window-wide, not per-guard attribution. Public Ruby APIs
cannot assign every side exit, invalidation or ratio to an individual guard.
The old/new F pair isolates its two holder-guard changes; unit ablations on
blog can locate aggregate costs but do not make counters additive.
