# Template lookup: surveyed and parked

2026-10-20. Candidate 3 in [candidates.md](../candidates.md). No pass,
runtime cache or new hits. The existing opportunity estimate is at most
**0.42% on any measured route**, before a complete resolver certificate.
The identity-only prototype is not exact. A filesystem-resolver epoch is
plausible, but its implementation and cost are not justified here.

## Existing Rails caches first

Checked Rails [8.1.4](https://github.com/rails/rails/tree/v8.1.4/actionview/lib/action_view)
and Campfire's pinned [8.2 alpha](https://github.com/rails/rails/tree/e3d5c569d217c56c022b04acb127a8c24dbe9685/actionview/lib/action_view):

- `FileSystemResolver` caches unbound templates by virtual path. Warm
  resolution does not rediscover files. Details still select among matches.
- `UnboundTemplate#bind_locals` caches the real Template by normalized local
  **names**, not values. Strict locals have their own shared-template path.
- `LookupContext::DetailsKey` interns requested detail objects; it is not
  a final-template cache or a resolver generation number.
- `PathSet` has a frozen list of paths, but its resolvers remain mutable.
  View-path replacement is observable independently of resolver mutation.
- Rails 8.1.4 `PathSet#find` uses `find_all.first`; the alpha already has a
  first-match resolver path and a separate raising `find!` operation.

Authorities: [lookup context](https://github.com/rails/rails/blob/v8.1.4/actionview/lib/action_view/lookup_context.rb),
[resolver](https://github.com/rails/rails/blob/v8.1.4/actionview/lib/action_view/template/resolver.rb),
[local binding](https://github.com/rails/rails/blob/v8.1.4/actionview/lib/action_view/unbound_template.rb),
and [alpha first-match lookup](https://github.com/rails/rails/blob/e3d5c569d217c56c022b04acb127a8c24dbe9685/actionview/lib/action_view/path_set.rb).
No warm ERB compilation or filesystem-scan saving is credited.

## Five-app request survey

Production, Lowrail absent, Ruby 4.0.7 +YJIT, existing corpus pins and fixture
routes. Twenty warmups, then ten untimed requests with call/return TracePoints
on `LookupContext::ViewPaths`. Count aliases by their defining method, not
again at `PathSet`/resolver layers. Each response was 200 and consumed.
Campfire response caching was disabled, fragment caches warm. Starter used
its real supervised Node renderer; `#app` had rendered element children.

| App / HTML request | `find` | `find!` | `find_all` | `exists?` | Literal app-target lookup shapes on this route |
|---|---:|---:|---:|---:|---|
| Blog articles index | 2 | 0 | 2 | 1 | 0; collection target comes from records |
| Blog article edit | 2 | 0 | 2 | 1 | 1: `render "form", article:` |
| Campfire uncached room | 3 | 10 | 0 | 0 | 10: nine ordinary partials plus explicitly named `messages/message` collection |
| PingCRM organizations | 1 | 0 | 2 | 0 | 0 in app source; one `inertia` engine-template lookup |
| Redprints proposals | 2 | 0 | 2 | 0 | 1: `render template: "layouts/core"`; other find is `inertia` |
| Starter dashboard, SSR | 0 | 0 | 3 | 0 | 0; initial page supplied by Inertia, layouts use `find_all` |

These are observed call shapes on representative pages, **not an exhaustive
static render-site census or certified eligible units**. Campfire performs
the collection template lookup once, not once per message. Its other
`find` calls are action `show`, missing layout `rooms`, and layout
`application`. The ten named partials are `rooms/show/nav`,
`rooms/involvements/bell`, `pwa/browser_settings`, `pwa/system_settings`,
`pwa/install_instructions`, `messages/template`, `rooms/show/invitation`,
`messages/message`, `rooms/show/composer`, and `layouts/lightbox`.

All five apps used exact `ActionView::FileSystemResolver` objects, unfrozen,
with template caching on and reloading off. **Zero** warm
`unbound_templates_from_path`, `template_glob` or `build_unbound_template`
calls were observed. Each returned template retained one identity across
the ten requests for that local-name signature. That is existing Rails
reuse, not evidence that an additional cache is safe.

Primary survey refusals below count lookup calls/request, once per operation;
use blog edit rather than adding its index request. All new eligible units
remain zero. The reason table is report-only, not a registered pass ledger.

| Primary reason | Blog edit | Campfire | PingCRM | Redprints | Starter |
|---|---:|---:|---:|---:|---:|
| `mutable_resolver_without_epoch`: positive find, no complete invalidation certificate | 2 | 12 | 1 | 2 | 0 |
| `missing_template`: nonraising miss, not a retained positive Template | 0 | 1 | 0 | 0 | 0 |
| `lookup_operation`: `find_all`/`exists?`, outside the priced single-Template operation | 3 | 0 | 2 | 2 | 3 |

## Executed invalidation counterexamples

Both Rails 8.1.4 and the pinned alpha produced the same following controls.
Temporary filesystem templates were outside the apps and removed afterwards;
only the probe process allowed French as an additional locale.

| Change | Actual Rails result | Why a pointer-only plan fails / what to retain |
|---|---|---|
| Warm repeat | Same Template; `OLD a&lt;&amp;` | Rails already binds and compiles it once |
| Rewrite file, **without** cache clear | Still old Template/output | Preserve Rails' deliberate production staleness; a new mtime watcher would change semantics |
| `resolver.clear_cache` after rewrite | New Template renders `NEW a&lt;&amp;`; held old Template still renders `OLD a&lt;&amp;` | View paths, resolver, details key **and resolver map identities all stay the same** |
| `LookupContext::DetailsKey.clear` on a registered filesystem resolver | Next find returns a new Template | Existing context keeps the same `view_paths` and memoized `details_key` identities |
| Explicit `variants: [:phone]` | `PHONE a&lt;&amp;` | Same context details key; per-call options cannot be omitted from a plan key |
| Locale / format setters | `FRENCH a&lt;&amp;` / `TEXT a<&` | Different template selection and escaping; format is not decoration |
| Additional local name | Different non-strict Template; reversed local-name order reuses it | Preserve Rails' normalized local-name signature and strict-local behavior |
| `disable_cache` | Nil details key and fresh Templates on repeated finds | Reusing a retained Template changes object/compilation semantics |
| Prepend earlier path | `EARLIER a&lt;&amp;`, new PathSet | Ordered path/prefix search remains live |
| Unknown mutable resolver changes text | `FIRST` → `SECOND` with same path/details identities | Refuse unknown resolver implementations without their own certificate |
| Missing required template | `ActionView::MissingTemplate`, names `missing_47` | Keep version-specific raising/nonraising APIs and diagnostics |

There is no native resolver epoch to compare. A future exact filesystem-only
plan could attach to `FileSystemResolver#clear_cache`, guard the implementations,
and retain live cache policy, complete ordered paths/prefixes, name, partial
flag, options/details and normalized locals. It must also handle cache clears
concurrent with lookup/publication; bumping a counter only after a clear is
not a complete design. Custom resolvers need refusal. The real Template must
still own rendering, compilation, strict locals, streaming and instrumentation.
These are requirements, not a closed or measured certificate.

## Budget and decision

The old guard-incomplete blog micro was 2.866 → 0.047 µs (19 → 0 objects).
Its 2.819 µs difference is **not** a measured saving of this proposed pass.
The earlier estimates remain ceilings: blog edit 0–0.42%, uncached Campfire
room 0–0.24%, PingCRM HTML 0–0.08%, Redprints HTML 0–0.23%; starter zero
credited finds. Do not apply one micro to layout arrays, missing checks or
each collection element. No instruction budget or native saving with a full
guard is available, so completed new hits, credited saving and expected
certified request effect are all **zero**.

**Parked:** the small ceiling does not justify a new filesystem-resolver
epoch now. This is not a proof that no exact narrow implementation exists.
Revisit only with a measured full-guard per-hit budget and a stacking case.
No runtime changes, after-gates, five-app on/off verification or shared bench
are claimed for a nonexistent variant. The three-group Action View before
gate in [erb.md](erb.md) remains valid.

Private evidence: `.lowrail/lookup-survey/{blog,campfire,pingcrm,redprints,starter}.json`
and `{rails-8.1.4,rails-alpha}.probes.json`. Census records include complete
lookup arguments, resolver classes, cache policy and result identity counts;
probe records retain rendered bytes and identity comparisons. Headers remain
private under the apps' `tmp/m0`. Reproduce from each app root with the same
production env and fixture headers: trace `LookupContext::ViewPaths` after
20 warm requests, request ten times, and separately trace filesystem resolver
miss/build methods. For invalidation, resolve and render a temporary partial,
rewrite it, compare before/after `clear_cache` and `DetailsKey.clear` on the
same context, and retain the old Template as a stale-output control.
