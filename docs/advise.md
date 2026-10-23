# Profile → source patch (`lowrail advise`)

Advice is a source-editing workflow, **not runtime lowering or automatic
patching**. Profile production YJIT first: repeated computations, avoidable
allocations and eager/N+1 app work matter only when production caches and YJIT
have not already removed them. Ruby **4.0.7**, Rails **8.1.4**.

```sh
RAILS_ENV=production lowrail advise /path/to/disposable/app \
  --request GET:/hot-screen --request GET:/another-screen --out /private/new-dir
# Authentication, setup and jobs: explicit Ruby file returning {label => callable}.
lowrail advise /path/to/disposable/app --workload /private/replay.rb --out /private/new-dir
```

The app boots normally in production (the default); other environments,
disabled eager loading or disabled production caching refuse ranking.
Each workload gets a serial fork, with DB connections closed before forking.
CPU sampling runs **before** allocation tracing and TracePoint, which can
deoptimize YJIT. The command reuses `profile_summary`, the extracted allocation
census, and Observe's app-source filtering/labels. It ranks files by self CPU
samples, then inclusive samples, then direct allocations—not an invented sum
of incompatible units. Inclusive costs overlap and are not removable budgets.
Output includes individual CPU frames: a controller's cost is not the ceiling
of one helper. JSON retains source/lock hashes, allocation sites, call counts and
specific source-edit suggestions. Compilation during discovery is flagged;
discovery is not a steady-state measurement. Use `--warmup`/`--requests` for a
longer profile. Census/TracePoint sizes are bounded separately by `--census`.

The separate SQL census shows **real round trips** and **CACHE hits**. Exact
duplicate reads are ranked by duplicate real round trips only; cached repeats
never improve their rank. Identity includes bind values and the connection
within each operation; writes/locks/transactions break repetition. Discovery
exports SQL text and bind hashes, not bind values: keep its output private.

Cheap repetition detection inspects only the first 32 entries per method,
comparing exact scalar inputs/results on the same receiver. Counts include
all observed calls; raised frames are excluded. No argument/result values,
receiver IDs, response bodies or cookies are exported. Repetition **does not
prove purity or safe memoization**. Run against disposable data: workloads
execute real requests/jobs and are neither sandboxed nor rolled back.

## Accept a patch, not a profile

1. **First gate: current upstream main.** Before investing, verify the code
   path still exists. Record the repository, current SHA and present/fixed/unknown
   in the ledger. A corpus pin is not evidence of a current upstream opportunity.
2. Estimate the candidate's removable **YJIT** inclusive share first. Below
   roughly 2%: record **below resolution**, without a cohort. Prefer repeated
   or eager work above 5%; never substitute a whole controller's share.
3. Make an app-source patch in a local fork. Keep fixture/dependency overlays
   identical in base and patch arms. Run the app's **full suite** unchanged.
4. Compare complete responses and ordered SQL with bind values. Only an
   upfront, counted entropy declaration may differ; preserve every other byte.
   Retain raw hashes too. Never normalize SQL or silently mask an unknown field.
   SQL may drop only certified pure, exact duplicate SELECTs (same statement,
   binds and connection, earlier read in the same request, no intervening write).
   Report every drop, including `cached`. Retained events/order, writes, locks
   and transactions must be exact. CACHE-only savings do not justify pricing.
5. Use fresh, unprofiled **production**, eager-loaded, production-cached YJIT
   processes: four A/B/A blocks, 1,000 requests per arm. Warm to 2,000 quiet
   requests using `JitStability`; the prospective 100,000-request cap is a
   refusal, not successful warmup. Every measured window must remain JIT-flat.
6. Per block, compare B with mean(A endpoints). Report the mean of those four
   deltas and Student t95 (df=3), **not 4,000 independent request samples**.
   Both CPU and wall upper bounds must be negative and their A/A intervals
   wholly within ±2%. Interpreter Callgrind Ir/fixed-heap/A/A is supporting
   evidence only: interpreter-only savings are not accepted. Keep rejections.

`bench/experiments/advise_patch_study.rb BASE FORK WORKLOAD NEW_OUT` implements
this native screen/cohort; `--counter` reuses RequestPairs/HeapWindows for the
supporting interpreter measurement. `ADVISE_ENTROPY=/absolute/policy.json`
pins the declaration in the protocol. Optional `ADVISE_SQL_READS` names a JSON
array of `[statement, binds]` pairs explicitly certified as pure reads; the
default allows no drops. SQL text alone cannot certify purity. A prerequisite failure
stops before pricing. Passing timing alone never certifies the full suite.

## Public corpus results (2026-10-23)

Public fixtures, not production traffic or representative data volumes. All
source pins, selected findings and exact numbers are in
[`advise-results.json`](../fixtures/corpus/advise-results.json); candidate
patches are beside it. No upstream PRs/issues were opened.
**Tally: 0 accepted / 2 rejected / 3 below resolution / 2 already fixed upstream.**
These seven leads include two upstream screens and two final ceiling screens,
not seven priced patches. No qualifying four-block cohort or Ir gain is claimed.

| App / candidate | Evidence | Decision |
|---|---|---|
| Writebook: receiver-memoized `editable?` | Test replay: 18 calls/response, 30/32 scalar observations repeat. Existing suite: baseline 119/381 green; patch 1 stale-authorization failure. Production caching reduces calls to 2/response. | **Reject correctness.** Reuse must respect access changes; no speed claim. |
| Writebook: arrangement map/join → fresh descriptor string | Test replay saves 36 objects/response; 119 ordinary + 2 browser tests, 389 assertions green. Warm production replay: **0 helper calls**, 7 SQL events/response. Raw A/A body/headers vary. | **Reject production opportunity.** Cached away; no qualifying native blocks or Ir price. |
| Campfire: eager pagination/preload | Production YJIT: 96/673 samples (14.26% inclusive). Current main has cache-miss-only preloading through `Message::Pagination::Page`. | **Already fixed upstream.** No patch. |
| Fizzy: reuse the filter's two identical link URLs | Production discovery: `as_params` 535/3,825 samples (13.99% inclusive), 2 calls/response. Controlled 18,515-byte bodies/headers match; SQL 19 → 18, only a CACHE hit drops. Both suites: 124/458, same 7 `Current.reset_all` errors (no new failures). Main already memoizes `as_params` and the renamed `boards` relation. | **Already fixed upstream; CACHE-only stop.** Amended SQL gate passes; no DB round trip saved, no pricing or upstream PR. |
| CASA: invariant transition-age duration | Helper 29/576 samples (5.03% inclusive), 40 calls/response; code unchanged on current main. Production-YJIT micro: duration 0.268–0.290 µs vs helper 8.38–8.90 µs; estimated removable request share **0.15–0.17%**. Initial nonflat micro row retained/excluded. | **Below resolution.** No patch/cohort. Do not memoize the changing clock. |
| Campfire: composer model construction | Helper 47/673 samples (6.98% inclusive); code still present on main. Model construction beneath it only 9/673 (**1.34%**), including all nested initialization. | **Below resolution.** Capture/rendering is not a removable model-construction budget. |
| CodeTriage: repeated permitted parameters | `valid_params` is only 1/282 YJIT samples (0.35% inclusive), 6 calls/response—not the controller's 17.38%. Base/patch suites: 222/483 green; three filtered/paginated response+SQL vectors match. | **Below resolution.** No timing cohort. |

Fizzy drops one **cached, exact duplicate SELECT**, not a DB round trip:
```sql
SELECT "buckets"."id" FROM "buckets"
INNER JOIN "buckets_filters" ON "buckets"."id" = "buckets_filters"."bucket_id"
WHERE "buckets_filters"."filter_id" = ?
```
Bind: `filter_id = 437785243`. Event 18 drops; earlier identical reads at
6 (uncached), 8/14 (cached). All remaining 18 events match in content/order,
with no writes. Backtrace: `_filter.html.erb:17` → `as_params:41` →
`Filter::Resources#buckets:21` → `super.ids`. **App repetition, not a Rails bug**:
Rails 8.1.4 `ActiveRecord::Calculations#ids` → `QueryCache#cache_sql` correctly
serves cached results without loading records. Rails main still uses the same
unloaded `ids` → `pluck` → query-cache path. Current Fizzy main already memoizes
the app computations. Exact upstream SHAs are in the ledger. No fork commit or
PR draft was warranted. An earlier non-production, nonflat Writebook probe is excluded.

Writebook's obsolete SQLite warning setting is removed by the **symmetric
production fixture overlay**, not credited to either candidate. Redis and
Memcached are real local services; production caching is not disabled. CASA's
driver uses external throwaway credentials and its request-spec Warden login
fixture, not the app's production secrets or an authentication certificate.

For CodeTriage the only declared entropy is one CSRF meta-token value,
`x-request-id`, `x-runtime`, weak `etag`, and the encrypted
`_code_triage_session` cookie **value**. Cookie attributes, all other headers,
all other HTML bytes, status and SQL remain exact. There are **no timestamp
or blanket HTML/cookie exemptions**. Missing/extra token matches refuse.

Fizzy additionally declares two form CSRF tokens, the `session_token` cookie
value and its permanent-cookie expiry; `_fizzy_session` replaces CodeTriage's
session-cookie name. All other attributes and page timestamps remain exact.
Its supported `SKIP_TELEMETRY=1` disables external reporting symmetrically.
