# Importmap / CSP: app cache candidate, no exact Lowrail pass

Investigation, 2026-10-20. **No new pass or setup hook is installed.**
The five held runtime files are unchanged. The local Campfire fork is
`.corpus/campfire-importmap`, branch `cache-script-locations`; its portable
patch and publication drafts live in [upstream-drafts](../upstream-drafts/campfire.md).
No upstream issue or PR has been opened. [Machine-readable evidence](importmap-measurements.json)
retains the instruction totals, all native cohort blocks/controls, micro
blocks, scoped call counts and byte/boundary checks (no cookies or raw HTML).

## Ownership and repeated work

Pins are the [Campfire M0](../m0/campfire.md) pins, not today's gem releases:

| Component | Version / pin | Relevant code |
|---|---|---|
| Campfire | `af4dd9fd599c65e0e0fc1f614ee469f70156ddf5` | `app/controllers/concerns/inline_script_hashes.rb:15–19,36–50`; `cached_responses.rb:6,94,101–106` |
| importmap-rails | 2.2.2, `51c1a531327fc04ed4552bb0fd523eb43561b817` | `lib/importmap/map.rb`, `to_json`, `cache_as`, `clear_cache` |
| Propshaft | 1.3.2, `dc979db89cd07c72ee4d11d415ae1cb4fd072623` | `lib/propshaft/resolver/static.rb`, `initialize`, `resolve` |
| Rails / Action Pack | 8.2.0.alpha, `e3d5c569d217c56c022b04acb127a8c24dbe9685` | `action_controller/metal/content_security_policy.rb`, `current_content_security_policy`; `action_dispatch/http/content_security_policy.rb`, middleware `call` and policy `build` |
| URI | 1.1.1 | `URI.join`, `RFC3986_Parser#join` / `parse` |
| Ruby | 4.0.7 | YJIT for native measurements; interpreter for the instruction counter |

**The hot loop belongs to Campfire, not a missing importmap/Propshaft cache.**
`Importmap::Map#to_json` already returns its `@cache["json"]` value on warm
requests. Its cache is cleared by pin/directory/config reload operations;
it is not keyed by the resolver unless the caller supplies a different
`cache_key`. We preserve that existing contract, including its limitations
for request-dependent asset-host procs; we do not introduce another resolver cache.
Propshaft's static resolver loads the precompiled manifest once at construction.
There is no warm asset resolution, glob, manifest read or asset hashing in
this path. Do not upstream another memo into either gem for this finding.

Campfire's `content_security_policy` before-action still runs before its
presentation/page cache. It obtains a fresh policy clone, reads the cached
importmap JSON, parses it again, and joins every imported URL with the request
base URL. It computes origins, finds the **last** asset-directory occurrence,
and deduplicates the resulting location strings. It then hashes the importmap
and entry-point script, unions sources, and constructs the worker source.
Rails' middleware serializes that request's policy after dispatch. Campfire's
cached response header allowlist deliberately omits CSP: a page cache hit does
not bypass this work. No templates are rendered again on the measured warm pages.

### Actual warm call counts

`bench/importmap.rb trace`: 50 warmups per route, then 20 traced requests each
for room, messages, sidebar and search; **all four have the same CSP counts**.
Tracing is separate from every timed/instruction window.

| Work | Calls / request |
|---|---:|
| `Importmap::Map#to_json` | 1 |
| `build_import_map`, Propshaft resolution / integrity calculation | 0 |
| Campfire `script_locations` | 1 |
| `JSON.parse` **inside** `script_locations` | 1 |
| `URI.join` inside that method | **90** |
| URI parser `parse` inside that method (base + import) | **180** |
| Campfire `script_hashes` | 1 |
| `Digest::Class.base64digest` | 2 |
| Rails CSP `build` | 1 |

The importmap is **7,703 bytes**, with **90 distinct imported URLs**, all
collapsing to **one** source: `localhost/assets/`. Deduplicating the URLs
before parsing would save nothing here. Request-wide JSON counts are 6–7,
and URI parse counts 181; the table deliberately isolates CSP's own parse
and 180 URI parses rather than attributing unrelated request parsing to it.

### Which inputs are fixed?

| Input | This production boot | Required boundary |
|---|---|---|
| Importmap JSON / pinned asset names | Cached String; unchanged across measured requests | Read the actual `to_json` result each time; compare complete content, not map identity, size, stat or time |
| Digested asset paths | Precompiled Propshaft manifest, loaded once | A changed map/resolver result must not hit the old derived-location entry |
| Relative URL root / asset prefix | `nil` / `/assets` | Read current values, include the resulting asset-directory string in the key |
| Request scheme / host / port | `https://localhost` / `localhost` in the workload | **Not boot constants**; include both current `base_url` and `host_with_port` |
| CSP config | Script self, object none, base self | Clone/build per request; do not cache the policy, source union or worker route |
| Nonce | Generator **nil**, no `nonce-` in the header | Not generally constant; never cache a generated nonce or full policy |
| Regexp timeout / hooks | Rails sets **1.0 s**; methods/tracing can change | Content equality alone does not certify skipping the parser's observable execution |

## Micro: where the native CPU goes

`bench/importmap.rb micro CANDIDATE`: Ruby 4.0.7 +YJIT, production, actual
resolved map, full GC before each of seven 1,000-call blocks, 400 warmups.
Values are medians of block means, **not latency percentiles or independent
process confidence intervals**. Request and method microblocks are separate;
do not add them or interpret their ratio as a fresh sampled frame share.
The standalone controller has a constructed Rack request, not a reused
live controller instance from a measured request. Clock/loop overhead is
included; no profiler is active.

| Operation | Original µs/call | App-cache µs/call | Original → cache allocations |
|---|---:|---:|---:|
| Complete warm room request | 2716.800 | 1530.826 | 6161.1 → 1680.9 |
| Cached importmap JSON lookup | 0.144 | 0.136 | 1 → 1 |
| Parse the JSON | 12.879 | 13.038 | 93.1 → 93.1 |
| Join all 90 URLs | 753.279 | 769.272 | 3070.0 → 3070.0 |
| Full `script_locations`, including request/config reads | **1265.453** | **26.555** | **5335.9 → 52.0** |
| Hash both inline scripts | 36.728 | 37.370 | 14 → 14 |
| Serialize the assembled CSP | 5.140 | 5.212 | 30 → 30 |

The JSON/URI rows intentionally execute their original operations even in
the candidate phase: these are controls, not claims that the cache speeds up
the parser. The candidate skips those operations in `script_locations`.
The earlier **34.8% inclusive** HTML share remains the M0 four-route sampled
measurement, not a prediction or a measured 34.8% speedup. A fresh original
room-only StackProf wall profile (100 µs, after a separate two-second native
timing window, 200 warmups) has **38,892 raw samples**, **12,608** including
`script_locations`: **32.42% inclusive**, 1.1% self. This corroborates the
hot path on one route; it does not reproduce the old four-route weighting.

## Primary instruction comparison: control failed

Used `bench/request_pairs.rb`'s unchanged counter protocol (three independent
rounds, fresh N=0/N=200 workers, 50 warmups, interpreter confirmed off-YJIT,
post-warmup GC, client-request region). The added `BENCH_VARIANT_APP` layer
boots the **real fork checkout**, Lowrail off; all other layers are unchanged.
Same fixture database contents, frozen lockfile, assets, authentication and
route. No measurement-window GC is disabled or subtracted.

| Round | Original A instructions/request | Original B (A/A) | App cache |
|---|---:|---:|---:|
| 1 | 19,760,841.475 | 18,146,868.435 | 6,155,355.520 |
| 2 | 19,766,306.175 | 19,755,606.420 | 6,151,010.465 |
| 3 | 19,774,573.840 | 18,016,398.870 | 6,111,806.960 |

App-cache paired median difference: **−68.88%**, nominal bootstrap interval
−69.09…−68.85%. **Not an accepted comparison:** off/off median is −8.17%,
interval **−8.89…−0.054%**, failing both inclusion of zero and the ±0.5% gate.
Exit **2** is retained; no rerun or widened threshold was used to get green.
In round 1, self instructions in Ruby GC source files are 505,504,419 vs
284,322,840 in the two 200-request controls: **221.2 million** of their
322.8-million-instruction difference. This demonstrates substantial GC-phase
work in the disagreement; it does not prove that GC explains every difference.
Those instructions remain in the totals. Neither the app-cache result nor
the default Lowrail layer's apparent improvement is an accepted instruction
speed claim. Interpreter differences also are not native YJIT speed claims.

## Secondary native YJIT comparison: control also failed

Five independently booted cohorts, eight rotating/reversing sequential
rounds per cohort, 0.6-second baseline calibration, 400 warmups and two
untimed blocks, same app fork layer. No other benchmark/test ran during this
experiment. All workers reported YJIT enabled. All five individual cohort
controls failed and remain in the aggregate, without retries.

| Layer | CPU µs/request, median of cohort medians | Allocations/request |
|---|---:|---:|
| Original A | 3219.84 | 6163.27 |
| Original B (A/A) | 3125.19 | 6163.31 |
| App cache | 1518.32 | 1681.10 |

App-cache paired CPU difference: **−53.85%**, nominal interval
−54.38…−43.44%; wall difference −53.85%, interval −54.39…−43.39%.
**Not an accepted native speed claim**: off/off CPU interval
**−10.07…+15.16%** and wall interval **−10.04…+15.29%** are far outside
the ±2% gate. Exit **2** is retained. The direction is promising, but these
controls do not support publishing a precise end-to-end improvement.
The method micro and removal of the repeated calls establish the local
work reduction, not a passed request-performance gate.

## Exact Lowrail decision

**Refuse whole-method/importmap-location memoization on this Campfire boot.**
No new registry entry, builder, runtime pass or `exp/importmap` hook is needed
for a refusal. Existing `--passes default,+memo` already records the relevant shared reasons:
`method_certificate` for an uncertified whole method, `call_certificate` for
JSON/resolver work, and `regexp_timeout` for the `URI.join` expression.
A duplicate runtime pass which only falls back would not establish coverage.

The app-cache patch deliberately introduces an application-owned successful
result cache. It is **not an exact compiler transformation** of the old
method. A concrete boundary probe warms a valid 20,000-character asset URL,
then sets `Regexp.timeout = 1e-9`: the app-cache variant returns its prior
location, while the original method with the same current inputs raises
`Regexp::TimeoutError`. This is a positive control at an intentionally tiny
timeout, **not** a claim that Campfire's normal 90 URLs time out at 1 second.
Tracing also observes 90 joins before and zero on a cache hit afterwards.
Method facts plus exact map/config/request bytes do not preserve these effects.
We neither change Rails' timeout nor use clocks/stat as guards. An audited
native parser certificate proving timeout impossibility for a restricted
input domain would be additional work, not something established by this run.

The existing URI memo can serve other certified, timeout-free apps; the
existing SHA pass handles the two script digests at one source site. Building
`--passes default,+memo` and running the serial gate here gives **634 identical outcomes**,
**15,109 reported SQL events**, **8,444 hits across 53 units**, of which
**1,332** are the existing SHA unit; zero fallbacks. These are **not** new
importmap pass hits. New importmap pass result: **0 units / 0 hits, refused**.
No importmap Lowrail speedup or nonvacuous importmap verify gate is claimed.

## Correctness and reproduction

The portable patch changes only Campfire's concern and its existing CSP
integration test. Original: warm-cache regression fails **0 expected / 90
actual joins**. Fork: **12 CSP tests / 1,390 assertions**, all pass; full
non-system suite **636 tests / 3,869 assertions**, zero failures/errors,
same two libvips skips. The 634 pre-existing test outcomes and all **15,053
ordered same-thread SQL events** match original; one concurrent repair test
has 13 vs 12 other-thread events (56 vs 55 across all common tests; advisory, not
silently presented as complete cross-thread SQL equality). No browser-suite
support claim is made for the app patch.

`bench/importmap.rb check` replaces only the location method with the fork's
actual implementation in an already-warm process. It checks **actual bytes**
of HTML and enforcing/report-only CSP for all four pages, without masking
nonces or CSRF tokens. Holding the same existing response cache keeps Rails'
randomized HTML CSRF masks constant; this is not a fresh-render comparison
or a new Lowrail off/on gate. Response sizes: 131,792 / 98,162 / 28,442 /
43,849 bytes. The fork still builds each request's policy/worker source and
calls the original importmap resolver entry point.

```sh
# Lowrail root: install/start the corpus exactly as docs/m0/campfire.md.
script/corpus campfire
# Make a second checkout at the SAME pin; copy prepared production storage,
# public/assets, .bundle and private tmp/m0 into the corresponding directories.
# Apply docs/upstream-drafts/campfire.patch in that checkout, NOT the baseline.

RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 mise exec -- \
  target/debug/lowrail build .corpus/campfire --env production
export BENCH_HEADERS="$(cat .corpus/campfire/tmp/m0/headers.json)"
export BENCH_VARIANT_APP="$PWD/.corpus/campfire-importmap"
path=$(jq -r .room .corpus/campfire/tmp/m0/paths.json)
BENCH_COUNTER=callgrind mise exec -- ruby bench/request_pairs.rb \
  .corpus/campfire /tmp/importmap-new-instructions "GET:$path"
# Exit 2 means FAILED A/A; retain it, do not retry to manufacture a pass.
BENCH_COHORTS=5 BENCH_ROUNDS=8 BENCH_SECONDS=0.6 mise exec -- \
  ruby bench/request_pairs.rb .corpus/campfire /tmp/importmap-new-native "GET:$path"

# From .corpus/campfire, env RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1:
ruby --yjit ../../bench/importmap.rb trace
ruby --yjit ../../bench/importmap.rb micro ../campfire-importmap/app/controllers/concerns/inline_script_hashes.rb
ruby --yjit ../../bench/importmap.rb check ../campfire-importmap/app/controllers/concerns/inline_script_hashes.rb
ruby --yjit ../../bench/importmap.rb boundary ../campfire-importmap/app/controllers/concerns/inline_script_hashes.rb

# Existing Lowrail gate, not a new importmap pass:
mise exec -- target/debug/lowrail build .corpus/campfire --passes default,+memo
RUBY_DEBUG_ENABLE=0 PARALLEL_WORKERS=1 LOWRAIL_SQL_TRACE=full mise exec -- \
  target/debug/lowrail verify .corpus/campfire -- bin/rails test --seed 41231
```

Open points: application review of the explicit cache contract; failed native
and instruction controls; no new exact importmap certificate; no full browser
gate or uncached-page performance claim. The app patch is not applied to the
pinned baseline.
