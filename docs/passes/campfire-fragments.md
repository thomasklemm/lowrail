# Campfire fragment caches: hit versus uncached rendering

2026-10-20. **App recommendation, not a Lowrail pass.** None of the measured
fragments has observed uncached all-pass rendering cheaper than its cache hit.
Keep these caches for this fixture mix. Native A/A controls failed, so the
table is a coarse cost comparison, **not** a precise Lowrail speedup claim.
No application files, caching policy, issue or PR were changed or published.

## Method and scope

Same `script/corpus` Campfire pin, Rails 8.2 alpha, Ruby 4.0.7 **YJIT on**,
production, authenticated room `/rooms/486777696` and sidebar
`/users/me/sidebar`. `CAMPFIRE_RESPONSE_CACHE_MB=0`, debugger off, local
SQLite and the app's bounded `FragmentCache` MemoryStore. These are real
controller requests, not detached rendering without request/Current state.
The room contains ten messages (plain/rich text and boosts); sidebar has two
direct memberships. Attachments/direct-room message variants are not covered.

Six fresh cohorts each boot independent `off_a`, `off_b`, and all-existing-
passes-on processes, rotating arm order. Each process warms 30 requests per
route, then warms ten and records 30 requests in **each** exposure mode:

1. **hit:** ordinary warm collection cache; ten message or two direct hits.
2. **inner_hit:** bypass collection caching only, exposing the nested
   `cache` block. Nested fragment caches remain warm.
3. **leaf_hit:** also bypass those outer `cache` blocks, exposing warm
   message-actions and text-presentation caches independently.
4. **uncached:** `perform_caching` false, so collection/block/action/text
   reuse is bypassed. All model, helper, escaping and output work still runs.

This layering matters: an outer hit otherwise prevents the inner fragment
from executing at all. Rows are **nested observations, not additive savings**.
Shared sidebar rooms and placeholders have no fragment cache in the source;
they are not invented cache candidates or included in the direct-fragment row.

CPU time brackets the actual CollectionRenderer call, including forcing
`RenderedCollection#body` (joining/output), or the actual cache block/partial.
The message-block row additionally includes its immediately preceding
`message_fragment_cache_key` evaluation. Collection timing already includes
that helper, preload/key construction, MemoryStore read, and body assembly.
Actions/presentation rows time their complete partial output, not just the
MemoryStore call. SQL is counted through `sql.active_record`, excluding
schema/transaction bookkeeping but including query-cache events. Nested timer
and notification overhead is present, consistently, in all arms.

All-on uses a freshly built production `--passes all-opt-in` manifest:
82 units: 59 route, one link, one SHA memo, one preload, 19 instantiation,
one AR-plan. No digest/Inertia unit is applicable here; URI memo is refused
by the existing certificate/regexp boundary. The shared activation probe
reports **82 active units, JIT true**. Counters are disabled for timing.

## Measurements

CPU µs/fragment: median of six **cohort means**, not request percentiles or
an average over differently sized fragments. Message/action/presentation rows
represent one message; collection rows state their full size. Columns (b)/(c)
disable every native fragment cache in the subtree, not just the top layer.

| Fragment | (a) Warm hit, off | (b) Uncached, off | (c) Uncached, all exact existing passes | Queries a / b / c | c < a? |
|---|---:|---:|---:|---|---|
| Room message collection, 10 messages | 5,979.8 | 27,474.7 | 27,184.6 | 8 / 8 / 8 | no |
| Individual message `cache` block, including key | 308.4 | 2,401.5 | 2,360.2 | 0 / 0 / 0 | no |
| Message actions partial, including action-cache hit | 73.6 | 403.7 | 402.2 | 0 / 0 / 0 | no |
| Message presentation partial, including text-cache hit | 97.2 | 952.9 | 930.3 | 0 / 0 / 0 | no |
| Sidebar direct collection, 2 memberships | 1,183.5 | 2,074.1 | 2,143.6 | 1 / 3 / 3 | no |
| Individual sidebar direct `cache` block | 177.3 | 712.7 | 740.0 | 0 / 1 / 1 | no |

The message collection's eight queries include its presentation/preload work
before content-key lookup; inner block rows start after those records are
available. The direct collection still loads memberships on a hit; uncached
direct bodies add one room-user query per membership. Do not label these
hit paths query-free merely because the final MemoryStore read is in-process.

### Controls and limits

Shared `RequestPairs.summarize`/`estimate`, seed 41231, boot-level resampling,
mandatory native A/A ±2% criterion. **Every row fails that narrow control**:

| Fragment | Off-b vs off-a CPU delta, % [95% bootstrap CI] | Observed hit cohort range, µs | Observed uncached-on cohort range, µs |
|---|---|---:|---:|
| Message collection | −4.21 [−11.83, +16.58] | 5,027–6,468 | 25,826–29,116 |
| Message block | −3.58 [−11.57, +18.09] | 264–333 | 2,245–2,540 |
| Actions partial | −1.25 [−11.48, +19.48] | 64–82 | 377–421 |
| Presentation partial | −6.02 [−13.70, +19.83] | 90–102 | 893–992 |
| Direct collection | +3.04 [−3.37, +9.79] | 1,111–1,290 | 1,944–2,445 |
| Direct block | +4.06 [−5.31, +7.06] | 162–192 | 685–853 |

All observed hit cohort ranges are below all observed uncached-on ranges,
so no fixture shows the requested crossover. But **no small off→on gain,
regression, saved-µs/hit budget or promotion is established**. These are
GC-enabled native diagnostic windows, not fixed-heap Callgrind operation
budgets. No new instruction adapter/protocol was created: candidate 4 was
parked before that step. A real pass would still use shared HeapWindows and
strict activation/JIT/build probes separately from timing.

The earlier 13.3 ms room profile disabled **response** caching, not fragment
caching. It is not the denominator for this fully fragment-uncached render;
subtracting that route median from this collection table would be invalid.

## Untimed attestation and fallbacks

Separate notification/output probes establish actual reuse, not merely that
caching is configured: **10/10 message and 2/2 direct collection hits**;
12/12 inner block reads and 20/20 action/text reads hit. Complete message-
collection and direct-collection HTML hashes are identical across all four
exposure modes **and** between off and on: sixteen body observations, with
no masking. Full response sizes are respectively 131,792 / 28,442 bytes in
every timed mode; sizes alone were not used as byte-equivalence evidence.

An independent counted cohort (two requests/mode plus its warmups) records:

| Existing pass | Hits/guards | Fallbacks |
|---|---:|---:|
| Route | 2,882 guard successes, not completed-route counts | 0 guard failures |
| Link / SHA memo | 0 / 0 | 0 |
| Preload | 237 | 0 |
| AR instantiation | 3,326 | 156 |
| AR plan | 234 | 0 |

All 156 counted fallbacks belong to `Room` unit 73. Its plan remains valid;
the rows include the inheritance column, so Rails' original STI instantiation
branch runs. That is the existing supported fallback, not a disabled build.
The route guard counts do not override the previously established live
`default_url_options` completion boundary. Zero-hit units are not credited
with savings. These probes do not repeat the five-app correctness gates for
unchanged existing passes or claim support for a new pass.

## Recommendation

Retain the native caches in these workloads: uncached-on costs approximately
1.8–9.6× a hit. Even optimistically applying the layer study's 33–41%
endpoint-lowering ceilings to these entire uncached fragments would not close
the smallest gap (1.81 × 0.59 ≈ 1.07, still above a hit); this is a scenario,
not a newly measured fragment optimization. `message_fragment_cache_key`
still costs **14.08%** of the earlier response-cache-disabled room profile,
but that is app dependency hashing, not evidence that caching loses overall.
Removing that content fingerprint would weaken detection of foreign SQL edits;
timestamps alone are not equivalent. Measure additional attachment/large-body/
direct-room distributions before making a broader app policy recommendation.
No app optimization or upstream publication is authorized by this survey.

Private evidence: `.lowrail/fragments/` contains all eighteen process
reports/logs, boot-level samples/summary, counted and cache/HTML attestations;
`.lowrail/fragment-build-quiet.log` records the fresh build. No authentication
headers, cookies, rendered page contents or local database data enter this doc.
