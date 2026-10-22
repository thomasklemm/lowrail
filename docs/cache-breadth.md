# Bet C2: cache-read copy-plan breadth

**Stopped at the census, 2026-10-22.** There is no useful new Marshal
reconstruction pool on the measured hot routes. No store port, runtime pass,
mutation variant, allocation off/off/on screen or Callgrind cohort was built
or run. This follows the requested early-stop rule, not an exactness or speed
claim. No application source/config patches or upstream activity; Lobsters
was not downloaded, changed or run by C2.

## Census: actual stores, not inferred configuration defaults

Ruby 4.0.7 / Rails 8.1.4, production, Lowrail off, interpreter. Each of the
19 successful routes has 25 warmups and **three independently recorded
request censuses**. Counts below agree in all three requests. The source and
dependency pins, complete hashed cache events, Coder types, load stacks and
allocation-class/role rows are in [cache-breadth.json](cache-breadth.json).

| App / route | Booted store | Marshal calls/request | Marshal objects/request | Intermediates at public cache return (share) | Coder UTF-8 String decodes/request |
|---|---|---:|---:|---:|---:|
| Fizzy `/buckets` | SolidCache | 0 | 0 | 0 (n/a) | 0 |
| Fizzy filtered `/bubbles` | SolidCache | 0 | 0 | 0 (n/a) | 2 |
| Fizzy `/account/users` | SolidCache | 0 | 0 | 0 (n/a) | 0 |
| Fizzy `/workflows` | SolidCache | 0 | 0 | 0 (n/a) | 0 |
| Fizzy `/notifications` | SolidCache | 0 | 0 | 0 (n/a) | 2 |
| Fizzy `/buckets/693169840/bubbles/613325334` | SolidCache | 0 | 0 | 0 (n/a) | 3 |
| Campfire room | RedisCacheStore | 0 | 0 | 0 (n/a) | 40 |
| Campfire pagination | RedisCacheStore | 0 | 0 | 0 (n/a) | 40 |
| Campfire sidebar | RedisCacheStore | 0 | 0 | 0 (n/a) | 2 |
| Campfire search | RedisCacheStore | 0 | 0 | 0 (n/a) | 12 |
| Campfire refresh | RedisCacheStore | 0 | 0 | 0 (n/a) | 80 |
| Blog `/articles` | SolidCache | 0 | 0 | 0 (n/a) | 0 |
| Blog `/articles/1` | SolidCache | 0 | 0 | 0 (n/a) | 0 |
| Blog `/articles/1/edit` | SolidCache | 0 | 0 | 0 (n/a) | 0 |
| CASA `/casa_cases` | FileStore | 0 | 0 | 0 (n/a) | 0 |
| CASA `/volunteers` | FileStore | 0 | 0 | 0 (n/a) | 0 |
| CodeTriage `/` | MemCacheStore | 5 | 7 | 7 (100%) | 3 |
| CodeTriage `/what` | MemCacheStore | 2 | 3 | 3 (100%) | 1 |
| CodeTriage `/joyent/node` | MemCacheStore | 5 | 6 | 6 (100%) | 4 |
| Writebook book list/show/leaf | RedisCacheStore (source only) | unmeasured | unmeasured | unmeasured | unmeasured |

Campfire is the existing `campfire-r81` fixture at `02023b0f`, with its
dependency-only 8.1.4 overlay. The corpus's newer `af4dd9fd` pin also explicitly
configures Redis, not SolidCache, but needs Rails 8.2 and was source-audited
only. Fizzy is `6f1d2003`, Writebook `be1f8fcf`, CASA `b584d2e6`, CodeTriage
`d1868f86`; the blog is the retained `real-blog-r4` archive. These are the
existing `script/corpus` fixtures, not newer arbitrary app revisions.

CASA's unoverridden Rails 8.1.4 default is **FileStore**:
`Rails::Application::Configuration#initialize` sets
`[:file_store, "#{root}/tmp/cache/"]`. The production comment about replacing
an in-process cache is not a configuration fact. Both routes render as a
naturally authenticated CasaAdmin in one disposable organization. Their
cache event lists are empty. Development MemoryStore declarations in CASA
and Writebook, and CodeTriage's test MemoryStore, are not production exposure;
no app was reconfigured merely to create a target.

### Why the pool disappears outside Lobsters

Fizzy and Campfire really exercise cache hits, rather than an observer that
missed every cache. Rails 8.1's `ActiveSupport::Cache::Coder` stores ordinary
UTF-8/BINARY/US-ASCII Strings directly. Its `StringDeserializer#load` changes
encoding without Marshal reconstruction. The observed fragment payloads use
that path. Blog and CASA have no cache-read events on these routes.

CodeTriage is the positive observer control. Dalli 5.1.0 additionally marshals
the serialized cache-entry **String**, and Coder sometimes marshals its
non-UTF-8 **version String**. Home has three Dalli String loads plus two
version loads; `/what` has one plus one; repo show has four plus one.
Each Dalli load creates its one result String. Each version load creates
one result and one intermediate String. Thus the source-enumerated totals
are independently 3 + 2×2 = **7**, 1 + 1×2 = **3**, and 4 + 1×2 = **6**;
only **2/1/1** (28.57%/33.33%/16.67%) are internal intermediates relative to
each individual `Marshal.load` result. A separate nine-request untimed
follow-up follows the **outer public cache read/fetch result**: **all 7/3/6
Marshal objects are transient (100%)**. Dalli's encoded entry String is
sliced to produce the final payload, and Entry's version is not returned
to the caller. Both definitions are retained, not conflated. Even the more
generous all-Marshal pool is at most seven objects/request. A copy at the
individual load seam would still need its fresh String outputs, so it
cannot claim those outputs as free savings. No AR/association/Time graph appears.
The cached random ID Array in `Random::CachedIdQuery` belongs to
`UserMailer#poke_inactive`, not these HTTP hot routes; it is not counted
as a request opportunity or measured as a mail workload.

This is an off-only, own-request-thread discovery census, not a whole-app
or all-background-thread ceiling. Fresh cache payloads/legacy deployments,
other inputs, authenticated CodeTriage pages and mail/jobs can differ.
There is **no claim that all caches or all app routes avoid Marshal**.

## Refusals and setup attempts

Writebook's initial pre-boot schema load lacked its `leaf/leaves` inflection
and failed on inferred `leafe_id`. Moving only disposable schema preparation
after normal app initialization then reproduces the existing production
boundary: `ActiveRecord::Base.sqlite3_production_warning=` no longer exists
in Rails 8.1.4, but its unchanged production config sets it. No shim, setter,
ignored config option or app patch was added. Those routes remain unmeasured,
not silently assigned zero. Its source cache sites are HTML fragments.

CASA preparation initially double-loaded auto-discovered FactoryBot
definitions, then needed an explicit local DB username because the app's
production `casa` username otherwise survives URL merging. Requests initially
failed without built assets. CodeTriage likewise initially returned 500 for
missing `application.css`; its stock asset-precompile command fixes that.
CASA's first npm attempt used Node 26 against its Node 24 requirement; both
npm and Rails asset builds need the pinned Node 24 on PATH. All attempts are
untimed setup, retained as log hashes/reasons, not excluded counted rounds.
No performance counting occurred.

## Reproduction and validation

The off-only observer is [cache_breadth.rb](../bench/experiments/cache_breadth.rb);
the external disposable-data adapter is
[cache_breadth_setup.rb](../bench/experiments/cache_breadth_setup.rb).
It reuses the existing Fizzy and Campfire production fixtures, natural
CSRF/password login and Rack requests. PostgreSQL databases are explicitly
disposable `lowrail_cache_breadth_casa` and `lowrail_cache_breadth_codetriage`;
create them empty with a local `user` role. Redis at 6379 and memcached at
11211 must be dedicated disposable instances. All SQLite data and CASA boot
credentials are generated outside the app tree. No secret values or cached
payloads are in the public export.

Fetch source/overlays with `script/corpus APP --source-only`, then install
each frozen bundle. For CodeTriage run its ordinary `assets:precompile` in
production with the disposable DATABASE_URL and `SECRET_KEY_BASE_DUMMY=1`.
For CASA, use `mise exec ruby@4.0.7 node@24.22.0 --` for `npm ci`, `npm run
build`, `npm run build:css`, and test-mode `bundle exec rails assets:precompile`.
From the selected app directory, with absolute paths and a **new** state/output:

```sh
LOWRAIL=0 BUNDLE_FROZEN=true CENSUS_APP=fizzy CENSUS_ROOT="$PWD" \
  CENSUS_STATE="$LOWRAIL/.lowrail/cache-breadth/NEW-fizzy" \
  mise exec ruby@4.0.7 -- bundle exec ruby \
  "$LOWRAIL/bench/experiments/cache_breadth.rb" "$PWD" \
  "$LOWRAIL/bench/experiments/cache_breadth_setup.rb" NEW_JSON
```

GC is disabled only for the three untimed request censuses. Each Marshal
load is allocation-traced separately, using bet M's allocated-only
reachability traversal from its result. Objects at `<internal:marshal>:34`
are divided into returned graph and intermediates; wrapper/framework sites
remain separate in the export. VM-internal non-enumerable allocations are
not assigned to this count. No intermediate share is calculated for 0/0.
Before/after app/config/lib content hashes agree for every successful worker;
tracked app changes are dependency overlays only. Early Fizzy/Campfire/blog
reports predate metadata/error-reporting-only observer edits; their actual
observer/setup hashes are retained, not rewritten to the latest hash. Only
CodeTriage additionally runs the outer-cache-return reachability observer;
the earlier reports all have zero loads, hence no graph to reclassify.

Both Ruby files pass `ruby -c`. Independent export reconciliation verifies
19 route identities / 57 primary samples plus nine CodeTriage attribution
samples, identical three-sample counts and Coder mixes, all class/role sums,
and the independently derived Dalli and version totals above. A public
MemoryStore control distinguishes a retained aliased/nested graph (12
Marshal objects: five in the result, seven intermediate) from ordinary
String reads (zero Marshal), and checks independent mutable returns. This
is observer validation, not an app workload or a MemoryStore port. The first
scratch expectation mistakenly counted a preexisting frozen Hash key as a
new graph object; inspection corrected that expectation, not the observer.
No runtime implementation changed, so no app off/on test-suite or
`lowrail verify` support claim is made.

## What main as an opt-in would need — not started

The accepted baseline is bet P's scoped Lobsters price at
[`94f3f32`](https://github.com/thomasklemm/lowrail/commit/94f3f321c8c73a3814f3828bb299f26ba31e2ab0):
−5.183274% front page / −1.637261% story interpreter Ir. Bet M's earlier
[`32933cd`](https://github.com/thomasklemm/lowrail/commit/32933cd42ce87b0a24ed321b9f50757ccadae7ef)
cohort stays rejected; C2 neither reruns nor re-scores either.

1. **Passive sealed admission, explicit selection.** The branch specimen at
   [`42d3e5a`](https://github.com/thomasklemm/lowrail/commit/42d3e5ade83922afc1ed39c632cc3c8ecee0dcd0)
   uses runtime ObjSpace, compilation and observation prepends. It is not an
   admissible default/guarded pass. Design source-certified, ancestry-neutral
   delivery under the sealed contract; original loading remains untouched
   through boot. Missing/stale/unsupported artifacts must silently retain
   stock behavior, with manifest assumptions and explicit ledger reasons.
2. **Exact reconstruction and complete certificates.** Preserve stock AR
   marshal-load callbacks/initialization, aliases, cycles, encodings, frozen
   keys and independent nested mutable graphs. Refuse unknown classes,
   callbacks, serializers/compressors/encryption, native hooks or timezone
   behavior; source-pin Ruby/Rails/AR format and primitive/method facts.
   Sealing is not permission to ignore data mutation or Entry semantics.
3. **Fresh bytes and stock continuation.** Re-read every entry; compare the
   complete serialized payload, never key/row id/timestamp/size/digest alone.
   SolidCache rows can be replaced by another process. Keep live expiry,
   version, decompression, encryption, errors, miss generation and cache
   notifications. Different bytes must take stock deserialization, not a
   stale plan; establish concurrency-safe finite capture, publication and
   eviction without shared mutable results or first-hit semantic changes.
4. **Coverage before pricing.** External-process same-id/same-size row
   replacement between requests must change the actual response exactly as
   stock. Also check expiry, version mismatch, deletion, malformed payloads,
   repeated nested mutation and alias/cycle isolation. Two-seed exact cold
   and warm responses plus each app's own identical test identities/outcomes
   and nonzero plan hits are required; test NullStore refusal is not coverage.
5. **Operational and performance gate.** Bound retained bytes/plans and
   measure cold capture/compile cost and concurrency/fork/reload behavior.
   Then the published screen's off-A/off-B/on allocations, hits/fallbacks,
   raw cache-row bytes and background signatures must pass. Only a clear
   allocation win warrants one prospectively frozen interpreter cohort:
   both total/no-GC A/A intervals wholly within ±0.1%, fixed heap, no retries
   or exclusions. No new YJIT, latency or broad-support claim follows from
   the old Lobsters price. There is currently no breadth reason to start this.
