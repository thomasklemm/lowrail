# M0 — Campfire: cached pages, CSP work, and Active Record

Measured 2026-10-19, with **no Lowrail loaded**. Campfire's current main was
[`af4dd9f`](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5),
now pinned in `script/corpus`. Ruby **4.0.7 +YJIT**, Rails **8.2.0.alpha**
(lockfile Git revision
[`e3d5c56`](https://github.com/rails/rails/commit/e3d5c569d217c56c022b04acb127a8c24dbe9685)).
This is already above the Ruby 4.0 / Rails 8.1 floor: no Ruby/Rails downgrade,
Gemfile change, source patch, or dependency update was needed.

**Main finding:** unlike real-blog, this Campfire revision already caches
complete HTML responses. On warm HTML, CSP importmap URL processing is a
larger opportunity than template rendering. When page reuse is disabled,
Active Record/preloading and fragment-key construction dominate the remaining
rendering work. Low app self time does **not** imply app-level specialization
has no value: app code can repeatedly invoke expensive library operations.

## Setup and reproduction

Environment: Debian 12 x86-64 orb, Intel Xeon @ 2.60 GHz, 8 visible logical
CPUs, one sequential in-process request driver (not eight workers). SQLite
3 through sqlite3 gem 2.9.6, Redis 7.0.15, libvips 8.14.1, stackprof 0.2.28.
Chrome for Testing and ChromeDriver 155.0.8059.84 were downloaded automatically
by Selenium Manager for the system suite. FFmpeg was already installed.

From the Lowrail root, with mise installed (`~/.local/bin/mise` also works):

```sh
sudo apt-get update
sudo apt-get install -y libyaml-dev libssl-dev libreadline-dev zlib1g-dev \
  libffi-dev libsqlite3-dev redis-server libvips ffmpeg
mise install ruby@4.0.7
export PATH="$(mise where ruby@4.0.7)/bin:$PATH"
gem install stackprof -v 0.2.28 --no-document

# Local disposable Redis, not an external/shared instance. In an Amp orb:
amp orb service start campfire-redis \
  --command 'redis-server --bind 127.0.0.1 --save "" --appendonly no'
redis-cli ping                         # PONG
script/corpus campfire
```

`script/corpus campfire` selects/installs Ruby 4.0.7 if necessary, fetches the
pin into `.corpus/campfire`, installs its **frozen lockfile**, prepares both
test and production SQLite databases, and precompiles production assets.
An existing checkout must have the pinned HEAD; use a fresh optional DIRNAME
for a different local checkout. Fresh-fetch setup and repeat setup both passed;
Campfire's tracked source and lockfile remained unchanged.

Redis is configured for production cache/rate limits, Resque, and Action Cable;
`REDIS_URL` defaults to `redis://localhost:6379`. The test cable adapter is
`:test`, and job tests use Rails' test adapter. No separate job worker,
Postgres, mail server, or application HTTP server was needed for these probes.
Selenium starts its own Puma for system tests. Browser/driver downloads need
network access on the first run. libvips and FFmpeg exercise media tests.

Only out-of-tree/runtime setup was used: `PARALLEL_WORKERS=1`, a local Redis,
fixture data, and `SECRET_KEY_BASE_DUMMY=1` for the disposable production
corpus. **Never use that secret setting or these fixtures in a real deployment.**
Keep the same secret setting when generating and using the benchmark cookie.

Nonfatal upstream/environment diagnostics were retained: production rake tasks
warn about premature ActiveSupport load hooks; eager loading warns that the
`/rooms/:room_id/settings` route references missing `Rooms::SettingsController`.
That route is not among the measured routes. Tests print OpenSSL frozen-string
warnings and FFmpeg errors for intentionally invalid video inputs. None caused
a test failure. Redis warns about overcommit, but persistence is disabled here.

## Test baseline (Lowrail off)

Run from `.corpus/campfire`, with the Ruby bin directory above on PATH:

```sh
/usr/bin/time -p env PARALLEL_WORKERS=1 bundle exec rails test
/usr/bin/time -p env PARALLEL_WORKERS=1 bundle exec rails test:system
```

| Suite | Seed | Runs | Assertions | Failures | Errors | Skips | Test time | Wall time |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `rails test` | 35709 | 634 | 3856 | 0 | 0 | 2 | 35.37 s | 38.49 s |
| `rails test:system` | 14319 | 30 | 221 | 0 | 0 | 0 | 339.32 s | 346.72 s |
| Combined (separate processes) | — | **664** | **4077** | **0** | **0** | **2** | 374.69 s | **385.21 s** |

Tests did not explicitly enable YJIT; request benchmarks did. The browser wall
time includes first-run Selenium provisioning; it is not just application CPU.
No tests were excluded. A separate verbose run of the 17 libvips policy tests
identified the two existing skips:

- `VipsLoaderPolicyTest#test_denies_NIFTI_files_through_niftiload`: this libvips
  build does not support `niftiload`.
- `VipsLoaderPolicyTest#test_denies_RAW_files_through_dcrawload`: this libvips
  build does not support `dcrawload`.

For a seeded replay, Rails accepts `rails test --seed 35709` and
`rails test test/system --seed 14319`. Future `lowrail verify` must compare
**per-test outcomes**, including these skip identities, under the same native
dependencies; these totals alone do not establish Lowrail support. There is
no fast-path hit count or on/off equivalence claim in M0.

## Workload and authentication

Use the pinned app's own fixtures: 1 account, 5 users (including a bot),
7 rooms, 13 messages. The measured closed room, **All Talk**, has 10 messages;
David is an authenticated administrator/member. Search `pain` has matching
message bodies. There are no uploaded attachments in this request workload.

```sh
# From .corpus/campfire; modifies ONLY this disposable production database.
export RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1
bundle exec rails db:fixtures:load
bundle exec rails runner ../../bench/campfire_setup.rb
```

The Lowrail-owned setup script repairs fixture message counters, populates the
FTS index (fixtures bypass callbacks), logs in through the real `/session`
endpoint with same-origin Fetch Metadata/Origin headers, and visits the room
to establish its session state. It writes private `tmp/m0/headers.json` and
`paths.json`, plus response checks. No authentication/CSRF bypass or Campfire
source patch is used. Bot JSON requests use the fixture bot's URL key and **no
browser cookie**, so the API really exercises bot authentication.

All six probes were checked for HTTP 200 and expected content, not merely a
successful redirect: room/messages contain the fixture text “Champagne”, sidebar
contains All Talk and Designers, search contains “Pain is easy to write”, JSON
contains 10 messages, and the Turbo Stream contains an append with message HTML.
Response sizes were respectively 131792, 98162, 28442, 43849, 7813, and 98273
bytes. The stream is a full refresh (`since=0`), not an empty polling response.

`bench/requests.rb` now accepts a generic JSON object of Rack headers in
`BENCH_HEADERS`, e.g. `{"HTTP_COOKIE":"session_token=..."}` or
`{"HTTP_ACCEPT":"text/vnd.turbo-stream.html"}`. It rejects redirects rather
than accidentally timing a login page. An unsigned request to the sidebar was
confirmed to fail the benchmark with HTTP 302. Cookies/keys are local fixture
credentials and are not checked into Lowrail or printed in the report.

## Request measurements

Production, YJIT, in-process Rack, HTTPS on, host `localhost`, logging reduced
to warn and Active Record logging off. **200 warm-up requests per route,
4 seconds per timed route.** No profiler runs inside those timed windows.
Each scenario boots a fresh Ruby process. These are single-run point estimates,
not confidence intervals or concurrency/load tests. Do not interpret small
differences (especially JSON between cache modes) as meaningful gains.

Default production caches: 64 MiB page cache and 64 MiB fragment store. The
HTML requests repeat one user/path against an idle database, i.e. a warm-cache
best case. The page cache still authenticates and checks room access.

| GET endpoint | req/s | µs/req | allocs/req |
|---|---:|---:|---:|
| `/rooms/:room` | 383.2 | 2609.5 | 6159.4 |
| `/rooms/:room/messages` | 360.6 | 2773.1 | 6095.3 |
| `/users/me/sidebar` | 376.7 | 2654.3 | 6029.4 |
| `/searches?q=pain` | 386.2 | 2589.1 | 5990.5 |
| `/rooms/:room/:bot_key/messages` (JSON) | 112.9 | 8859.3 | 12915.5 |
| `/rooms/:room/refresh.turbo_stream?since=0` | 99.7 | 10026.3 | 15757.4 |

Control: **`CAMPFIRE_RESPONSE_CACHE_MB=0`**, disabling both page reuse and
record snapshots. **Fragment caching remains on and warm**: this is not a
fully cold-cache run and not a simulation of an arbitrary production write mix.

| Same GET endpoint | req/s | µs/req | allocs/req |
|---|---:|---:|---:|
| Room | 64.3 | 15553.1 | 22665.9 |
| Messages | 96.4 | 10370.8 | 15741.8 |
| Sidebar | 101.9 | 9810.3 | 14411.7 |
| Search | 83.6 | 11960.8 | 16183.3 |
| Bot JSON | 107.8 | 9274.7 | 12916.5 |
| Turbo Stream | 92.0 | 10873.4 | 16291.6 |

Reproduce the benchmark/profile for both modes (Bash, same directory/env):

```sh
export BENCH_SECONDS=4
for mode in default no-page-cache; do
  if [ "$mode" = no-page-cache ]; then
    export CAMPFIRE_RESPONSE_CACHE_MB=0
  else
    unset CAMPFIRE_RESPONSE_CACHE_MB
  fi
  export BENCH_HEADERS="$(cat tmp/m0/headers.json)"
  mapfile -t routes < <(jq -r '[.room,.messages,.sidebar,.search][] | "GET:"+.' tmp/m0/paths.json)
  BENCH_JSON="tmp/m0/$mode-html-results.json" \
    BENCH_PROFILE="tmp/m0/$mode-html-profile.json" \
    ruby --yjit ../../bench/requests.rb "${routes[@]}"
  BENCH_JSON="tmp/m0/$mode-stream-results.json" \
    BENCH_PROFILE="tmp/m0/$mode-stream-profile.json" \
    ruby --yjit ../../bench/requests.rb "GET:$(jq -r .stream tmp/m0/paths.json)"
  unset BENCH_HEADERS
  BENCH_JSON="tmp/m0/$mode-json-results.json" \
    BENCH_PROFILE="tmp/m0/$mode-json-profile.json" \
    ruby --yjit ../../bench/requests.rb "GET:$(jq -r .json tmp/m0/paths.json)"
  for format in html stream json; do
    ruby ../../bench/profile_summary.rb "tmp/m0/$mode-$format-profile.json" \
      "$PWD" 100 > "tmp/m0/$mode-$format-summary.txt"
  done
done
```

The benchmark prints the synthetic bot URL; keep raw logs private if adapting
this command to a real account. This harness measures request handling and
body consumption, not network/TLS, browser JS, asset downloads, WebSockets,
background fanout, message writes, attachment rendering, or saturated load.

## Profiles: self / inclusive total by area

Stackprof wall mode, 100 µs. After timing, the harness profiles approximately
two seconds' **unprofiled request count** per route. Profiling substantially
slows requests, so these are not two-second wall captures. The HTML profile
combines four routes with roughly equal unprofiled time, not equal counts;
profile overhead may change the resulting mix. JSON and stream are separate.

Raw stack sample counts: default HTML 164218, no-page-cache HTML 189650,
default stream 44954, default JSON 46768. Corresponding Stackprof reported
samples/missed samples: 164545/1773, 192302/7777, 45302/1906, 47037/912. The
summary uses raw-stack counts as its denominator, not the slightly different
reported sample count. These are sampling estimates, not exact tracing.

Each cell is **self % / total %**. C self time is charged to its nearest Ruby
caller; totals count an area once per stack and **must not be added**. GC has
no Ruby caller, hence a zero area total, not zero cost. `other` includes Ruby
internal array/marshal frames and the benchmark harness. App templates include
ERB and Jbuilder (`erb(app)` in the tool's output).

| Area | HTML, default | HTML, no page/record cache | Stream, default | JSON, default |
|---|---:|---:|---:|---:|
| App Ruby | 4.9 / 75.3 | 2.3 / 90.1 | 3.0 / 86.7 | 1.5 / 77.3 |
| App templates | 0 / 0 | 0.5 / 59.9 | 0.1 / 56.9 | 0.1 / 46.1 |
| Active Record | 2.7 / 73.6 | 28.8 / 89.6 | 27.0 / 85.9 | 30.2 / 76.4 |
| Active Model | 0.6 / 1.1 | 3.7 / 10.9 | 4.9 / 18.0 | 3.2 / 4.0 |
| Active Support | 17.6 / 85.7 | 12.3 / 93.1 | 10.7 / 91.7 | 10.1 / 80.2 |
| Action Pack | 12.2 / 87.2 | 6.1 / 93.5 | 4.7 / 92.1 | 4.4 / 80.7 |
| Action View | 0.5 / 73.2 | 7.2 / 89.5 | 2.5 / 85.8 | 1.3 / 76.3 |
| URI | 27.5 / 27.7 | 6.3 / 6.4 | 7.2 / 7.2 | 7.5 / 7.5 |
| Rack | 6.0 / 90.3 | 1.8 / 94.3 | 2.1 / 93.0 | 1.6 / 81.2 |
| Nokogiri | 0 / 0 | 5.2 / 5.2 | 10.6 / 10.7 | 0 / 0 |
| OpenSSL | 2.7 / 2.7 | 1.3 / 1.3 | 0.7 / 0.7 | 0.9 / 0.9 |
| JSON | 2.4 / 2.4 | 0.7 / 0.9 | 1.2 / 1.4 | 0.7 / 0.8 |
| GC/native without Ruby caller | 9.7 / 0 | 5.7 / 0 | 6.9 / 0 | 18.7 / 0 |
| Other | 6.2 / 90.3 | 12.8 / 94.3 | 13.2 / 93.1 | 15.4 / 81.3 |

Small areas omitted from this table remain in the generated summaries. Turning
off page/record caches barely changes the API distribution: stream AR is
28.7% self (versus 27.0%), JSON AR 30.2% (same); API requests do not use the
HTML page cache. Stream still uses browser authentication/record snapshots,
while bot authentication does not.

The summarizer now recognizes Rails components inside a Bundler Git checkout
and generated templates with sampled lines but no definition-line metadata.
Without these fixes, Rails areas collapse into an undifferentiated group and
template frames can be mislabeled as C. The previous real-blog document is
left as its historical measurement, not silently recalculated.

### Top self frames

| Profile | Leading self frames (% of raw samples) |
|---|---|
| Default HTML | `Regexp#match` 10.6; GC sweeping 9.3; `MatchData#[]` 3.2; `String#split` 2.5; `String#sub` 2.4; JSON parser 2.1; `OpenSSL::HMAC#initialize` 1.9 |
| HTML without page/record cache | GC sweeping 5.3; SQLite `step` 3.7; `Regexp#match` 2.6; SQLite `prepare` 2.3; `Regexp#match?` 1.5; `Array#join` 1.0; Nokogiri XPath `evaluate` 1.0 |
| Default stream | GC sweeping 6.3; SQLite `prepare` 3.3; SQLite `step` 3.1; `Regexp#match` 2.8; Nokogiri XPath `evaluate` 2.0; `Array#hash` 1.3; Gumbo HTML fragment parser 1.2 |
| Default JSON | GC marking 13.9; GC sweeping 4.8; SQLite `step` 4.1; `Regexp#match` 3.0; SQLite `prepare` 2.9; `Marshal.load` 1.2 |

### Selected inclusive frames (not additive)

These exclude ubiquitous Rack/dispatch wrappers; `Notifications.instrument`
is included to show why a big total is not necessarily an optimization budget.
Repeated occurrences of a named frame count once per raw stack.

| Frame | HTML default | HTML no page/record cache | Stream default | JSON default |
|---|---:|---:|---:|---:|
| `ActiveSupport::Notifications.instrument` | 71.1% | 88.9% | 85.0% | 75.5% |
| `InlineScriptHashes#script_locations` (app) | **34.8%** | 7.9% | 9.0% | 9.7% |
| `Authentication#restore_authentication` (app) | 14.5% | 6.2% | 3.9% | 0.1% |
| `CachedResponses#cache_read_response` (app wrapper) | 7.1% | 69.3% | 0% | 59.4% |
| `ActionView::Template#render` | 0% | **60.1%** | 56.9% | 46.2% |
| `ActiveRecord::Associations::Preloader#call` | 0% | **18.5%** | **30.3%** | **32.7%** |
| `MessagesHelper#message_fragment_cache_key` | 0% | 10.1% | **20.6%** | 0% |
| `TagBuilder#tag_options` | 0% | 3.2% | 0.1% | 0% |
| SQLite `step` or `prepare` | 2.1% | 6.0% | 6.3% | 6.9% |

For example, Action View is on warm HTML stacks because controller helpers are
used to resolve the importmap, **not** because the cached page is rendered again.
Likewise the 46.2% JSON template total includes Jbuilder's cached fragments and
their association work, not just string serialization. No app-template frames
were sampled in the default HTML profile; they were present in the control.

## What Lowrail could specialize — and what it must not assume

1. **CSP/importmap configuration is a concrete app-level candidate.**
   `InlineScriptHashes#script_locations` parses each import URL with `URI.join`
   on every response, including cached HTML. Precompute only the parts fixed
   by the importmap, asset manifest, asset prefix, relative URL root, helper
   owners and CSP policy. Request base URL/host remains a runtime input;
   asset-host procs or dynamic resolvers require a guard/fallback. This is not
   permission to broaden CSP to the entire origin, omit hashes, or cache a
   policy across incompatible hosts. The 34.8% inclusive share is a candidate
   budget, **not a predicted 34.8% speedup**.
2. **Framework specialization still matters, but AR outranks raw HTML
   construction on this workload.** Schema/reflection facts can specialize
   attribute/type handling, association/preloader dispatch and model-specific
   callback paths. They cannot make rows, membership, authorization, or query
   results boot-time constants. SQLite execution is only ~6–7% of the
   uncached/API profiles; the wider AR share includes Ruby coordination and
   allocation. Optimizing SQL or changing eager loading is a separate app/data
   access decision, not semantics-preserving lowering by default.
3. **Fragment-key work is significant even on cache hits.** Stream spends
   20.6% inclusive in `message_fragment_cache_key`, which fingerprints message,
   room, creator, rich text and boost data, and checks loaded associations.
   Schema-fixed field layouts and guarded dispatch are plausible targets;
   dynamic content hashes and the database-generation checks must remain.
   Campfire deliberately supports foreign SQLite writers that need not touch
   Rails timestamps. Replacing these checks with timestamp-only keys would
   violate the app's cache correctness contract.
4. **Views need a compilation seam, but not as the only first performance
   pass.** Without page reuse, templates wrap 60.1% of HTML time, yet Action
   View self is 7.2% (real-blog: 19.9%) and much of the inclusive work is AR.
   Fixed route/helper dispatch, partial resolution, and constant markup remain
   candidates. Generated ERB still uses `module_eval`, not `load_iseq`; Jbuilder
   is another template case. Guard template digests, helper owners, locale,
   config, and dependencies rather than assuming rendered content is static.
5. **Controllers/middleware have fixed dispatch costs, not fixed security
   results.** Callback/filter chains and configuration branches may specialize
   under boot facts. Authentication, cookie verification/renewal, room access,
   rate limits, and database-version observation stay per request. Instrumentation
   totals wrap the request; they cannot be removed while subscribers such as
   Sentry or Rails logging are installed. Subscriber changes need invalidation.

Compared with [real-blog](real-blog.md), the answer is more nuanced than
“all speed is in views.” App self remains small (1.5–4.9%), but app orchestration
of URI parsing is a major warm-path cost; uncached HTML and non-HTML APIs shift
toward AR and cache keys. This supports continuing M0/M1 with **both app and gem
coverage**, and evaluating guarded importmap/config specialization plus AR
dispatch before committing M4 to view helpers alone. There is no measured
Lowrail speedup here, and no claim that all of these hot frames are removable.
