# M0 — three public Inertia Rails applications

Measured 2026-10-20 in a Debian 12 x86-64 orb, Ruby **4.0.7 +YJIT** for
requests, production, **Lowrail off**. The public corpus now covers Vue +
Jbuilder, React + Alba, and a React starter with SSR. No private ARGOS code,
credentials or fixtures were used. **These are baselines, not speedups.**

Main findings:

- All **124 tests/examples** have identical per-test outcomes on/off, including
  the browser suites, with no failures or skips. PingCRM exercises route and
  preload fast paths; React Starter Kit exercises route fast paths.
- Redprints runs unchanged on Ruby 4.0.7 despite its `ruby-3.4.3` version file.
  Its Freezolite/require-hooks integration leaves **zero fast-path hits**;
  equivalence proves safe fallback, not specialization coverage.
- **None of these revisions repeats ARGOS's asset-version digest per request.**
  They assign a digest String at boot, not a version proc. Positive-controlled
  traces of 400 requests per app recorded zero digest calls.
- Inertia configuration binding/descriptor assembly is a more concrete small
  fixed-input candidate. Alba's total includes dynamic model access and
  formatting; serializer setup and key transforms are individually small.

## Pins and setup

`script/corpus APP [DIRNAME]` fetches these exact current HEADs, selects Ruby
4.0.7, installs frozen bundles and JS lockfiles, prepares test/production
databases, and precompiles assets. Existing checkouts must match their pin.
Fresh-fetch PingCRM and repeat setup for all three succeeded; tracked app
sources and lockfiles remained unchanged. **No overlay was needed.**

| App / pin | Rails | Inertia | Other |
|---|---|---|---|
| [ledermann/pingcrm](https://github.com/ledermann/pingcrm/commit/22464f822dcf59c4425993dd623780ad44497fda) | 8.1.4 | 3.23.0 | Minitest, PostgreSQL, ViteRuby 3.11.1, Jbuilder |
| [evilmartians/redprints-cfp](https://github.com/evilmartians/redprints-cfp/commit/6080fc24fbf0015f7e5a5ae932e903731502c65a) | 8.1.3 | 3.21.2 | RSpec, SQLite 2.9.5 gem, Alba 3.10.0, ViteRuby 3.10.2 |
| [inertia-rails/react-starter-kit](https://github.com/inertia-rails/react-starter-kit/commit/f8081935e9bda68f8ef1ec53dc7eed19c819ee68) | 8.1.4 | 3.22.0 | RSpec, SQLite 2.9.6 gem, RailsVite 0.2.3, SSR |

`.agents/setup` installs the native/Ruby/Rust prerequisites and stackprof
0.2.28 without downloading apps or starting services. Its two warm runs took
0.60 / 0.41 s; a clean login shell found Ruby 4.0.7 and Cargo. Manual equivalent:

```sh
sudo apt-get update
sudo apt-get install -y build-essential libclang-dev libyaml-dev libssl-dev \
  libreadline-dev zlib1g-dev libffi-dev libsqlite3-dev libpq-dev postgresql libvips-dev
mise install ruby@4.0.7
export PATH="$(mise where ruby@4.0.7)/bin:$PATH"
gem install stackprof -v 0.2.28 --no-document

# Local DISPOSABLE PostgreSQL 15; no production or shared database access.
mkdir -p /tmp/lowrail-inertia-pg
/usr/lib/postgresql/15/bin/initdb -D /tmp/lowrail-inertia-pg/data -A trust -U user
amp orb service start inertia-postgres --port 55432 \
  --command '/usr/lib/postgresql/15/bin/postgres -D /tmp/lowrail-inertia-pg/data -k /tmp/lowrail-inertia-pg -p 55432 -h 127.0.0.1'
export PGHOST=/tmp/lowrail-inertia-pg PGPORT=55432 PGUSER=user APP_HOST=localhost
script/corpus pingcrm
script/corpus redprints-cfp
script/corpus react-starter-kit
```

PingCRM's `APP_HOST` is required by its production host authorization.
The JS installers were Bun 1.3.10 (frozen `bun.lock`) and Node 26.10.0 /
npm 10.9.9 (`npm ci` for the starter's `package-lock.json`). Selenium Manager
provisioned Chrome/ChromeDriver 155.0.8059.84. Redprints' Cuprite used
`BROWSER_PATH=$HOME/.cache/selenium/chrome/linux64/155.0.8059.84/chrome`.
Bundler 2.6.8 in Redprints emits RubyGems platform redefinition warnings on
Ruby 4; Vite also emits deprecation/sourcemap warnings. They were retained,
not fixed by updating dependencies or suppressing failures.

The starter pin enables SSR (despite its README saying it ships disabled).
`script/corpus` also builds `ssr/inertia.js`. In-process Rack does not start
its Puma SSR plugin, so run the renderer separately before preparing headers:

```sh
amp orb service start inertia-react-ssr --port 13714 \
  --command 'node /home/user/workspace/repo/.corpus/react-starter-kit/ssr/inertia.js'
curl --fail http://localhost:13714/health  # status: OK
```

An initial diagnostic HTML profile caught connection-refused CSR fallback;
it was discarded and replaced with healthy SSR measurements below. The setup
probe now requires actual element children in `#app`, not merely HTTP 200.

## Test baselines and Lowrail verification

Baseline runs had `LOWRAIL=0`, no Lowrail reporter, and seed **41231**.
PingCRM used `PARALLEL_WORKERS=1`. Test durations exclude process boot:

| App / command inside app (`bundle exec`) | Runs/examples | Assertions | Failures/errors/skips | Test seconds |
|---|---:|---:|---|---:|
| PingCRM `rails test --seed 41231` | 1 | 1 | 0 / 0 / 0 | 0.026 |
| PingCRM `rails test test/system --seed 41231` | 25 | 163 | 0 / 0 / 0 | 17.69 |
| Redprints `rspec --seed 41231` | 50 | — | 0 / 0 / 0 | 2.06 |
| Redprints `rspec spec/system --seed 41231` | 12 | — | 0 / 0 / 0 | 9.71 |
| React Starter Kit `rspec --seed 41231` (includes system) | 36 | — | 0 / 0 / 0 | 6.47 |

Redprints excludes system specs by default in its own configuration; the
explicit second command covers them. No tests were removed or skipped here.
From the Lowrail root, with the same PostgreSQL/host/browser environment:

```sh
cargo build
target/debug/lowrail build .corpus/pingcrm --preload-plans
PARALLEL_WORKERS=1 target/debug/lowrail verify .corpus/pingcrm -- \
  bin/rails test test/models test/system --seed 41231
target/debug/lowrail build .corpus/redprints-cfp --preload-plans
target/debug/lowrail verify .corpus/redprints-cfp -- bundle exec rspec --seed 41231
target/debug/lowrail verify .corpus/redprints-cfp -- bundle exec rspec spec/system --seed 41231
target/debug/lowrail build .corpus/react-starter-kit --preload-plans
target/debug/lowrail verify .corpus/react-starter-kit -- bundle exec rspec --seed 41231
```

RSpec now uses a RUBYOPT-loaded formatter with example IDs, full exception
class/message, pending/skip reasons and per-process hit counts. Duplicate
descriptions remain distinct. It does not activate RSpec before Bundler or
wrap `Kernel#require` (which conflicts with Bootsnap aliasing). Explicit test
commands keep the existing CLI contract; the default remains `bin/rails test`.
Verify now avoids double-counting Minitest's aggregate plus worker hit files.

| App | Identical outcomes | `route/path` ledger / units / hits | `view/link_to` ledger | Preload ledger eligible / declined; hits |
|---|---|---|---|---|
| PingCRM | **26/26**, all pass | 30/30 lowered; 4 units; **11 hits**, all 4 units | 0 sites | 12 / 10; **7 hits** (unit 4) |
| Redprints | **50/50 + 12/12**, all pass | 25/27 lowered; 14 units; **0 hits** | 0/1 lowered | 38 / 11; **0 hits** (unit 14) |
| React Starter Kit | **36/36**, all pass | 23/26 lowered; 8 units; **25 hits**, 7 units | 0/2 lowered | 2 / 0; **0 hits** (unit 8) |

Preload eligibility counts associations, not lowered units. There is one
preload runtime unit per app, so the manifest totals are 5 / 15 / 9 units.
These builds and verification were refreshed after main's `_url` support
landed in [0a1ec7a](https://github.com/thomasklemm/lowrail/commit/0a1ec7a).
Route declines: Redprints 2 direct `rails_blob_url`; starter 3 options-hash
calls. The three link sites have unsupported URL expressions. Preload declines
are polymorphic belongs_to (1/1/0), non-certified scopes (3/3/0), and through
associations (6/7/0). PingCRM/starter recorded zero guarded fallbacks; Redprints
recorded 6 in the non-system suite and 1 in the system suite, all in mailer
templates (4 distinct units), not specialization hits.

**Redprints compatibility boundary:** `LOWRAIL_DEBUG=1` reports
`compile options differ from the build; not serving lowered files`, and
require-hooks warns that it bypasses the existing `load_iseq` for processed
files. Freezolite 0.7.0 temporarily changes `frozen_string_literal` during
loading through require-hooks 0.4.0. Reusing an ISeq compiled under a different
string-literal policy would be incorrect. This thread leaves the guard and
original source path intact; neither route nor preload specialization is
claimed supported on Redprints. Fixing delivery composition is follow-up work.
The starter's unhit route unit is Settings::ProfilesController; preload had
no completed plans in its tests. Identical results alone do not establish
those units.

`lowrail observe` also completed successfully on all three with the same
seeded commands (Redprints non-system suite, before the `_url` refresh):

| App | Methods defined after boot | In facts by name | Generated-def match | Template match | Not in facts | Sampled methods |
|---|---:|---:|---:|---:|---:|---:|
| PingCRM | 13,599 | 10,739 | 455 | 2 | 2,403 | 39 |
| Redprints | 9,897 | 2,768 | 727 | 8 | 6,394 | 81 |
| React Starter Kit | 13,762 | 8,519 | 250 | 5 | 4,988 | 39 |

These are observations, not a claim that every missing definition is app
code. Most missing groups are test/driver/generated machinery. Facts had no
errors on PingCRM/Redprints; the starter had **21 explicit skipped model
entries**, all absent optional framework tables (Action Text/Mailbox/Storage,
Solid Cable/Cache/Queue), not boot errors. Core checks: 20 Rust unit tests and
the outcome-file CLI integration passed; the optional real-blog integration
did not exercise its absent corpus. Gem tests after refresh: **53 runs, 595 assertions,
0 failures/errors, 8 skips** (absent legacy corpus fixtures and minitest-mock).

## Authenticated production workload

From each app, after its final asset build and with the SSR service healthy:

```sh
export RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 LOWRAIL=0 RAILS_LOG_LEVEL=error
bundle exec rails runner ../../bench/inertia_setup.rb
```

The Lowrail-owned script refuses non-corpus/non-production roots. It creates
one deterministic M0 account/user with 30 organizations and 30 contacts in
PingCRM (10 rows/page), one speaker with 20 proposals in Redprints, and one
verified user/session in the starter. PingCRM's own `db:prepare` also creates
its standard seed account, isolated from the M0 user's authorization scope.
Login uses real password endpoints and CSRF tokens for PingCRM/the starter.
Redprints requires external OAuth credentials, so it uses the app's own
test-helper signed-cookie construction, with real production cookie checking
and database authentication, not an authentication stub.

Private, mode-0600 `tmp/m0/headers-{html,json}.json` contain the cookie and
the actual boot version. JSON navigation sends `X-Inertia: true`,
`X-Inertia-Version`, `X-Requested-With: XMLHttpRequest`, and `Accept: text/html`.
All 12 format/route probes check 200 and expected media type; JSON also checks
the authenticated user, data/counts and version. Initial HTML has the Inertia
page payload; starter HTML has real SSR markup. Negative controls require an
unsigned 302 and a stale-version **409**. Re-run setup after rebuilding assets:
one diagnostic stale header was correctly rejected by the benchmark, not timed.
These disposable credentials/settings must never be used in a real deployment.

## Request throughput and allocations (Lowrail off)

`bench/requests.rb`: HTTPS Rack environment, host `localhost`, eager load,
200 warmups/route, 4 s/route, one sequential driver, fresh Ruby process per
app/format. Each table entry is a **single point estimate**, not a confidence
interval or concurrency test. No profiler in timed windows; no test/build jobs
ran alongside the final measurements. Allocations are Ruby objects only.

| App / GET | Initial HTML req/s | HTML allocs/req | Inertia JSON req/s | JSON allocs/req |
|---|---:|---:|---:|---:|
| PingCRM `/organizations` | 309.2 | 2,942.8 | 314.1 | 2,528.6 |
| PingCRM `/contacts` | 240.2 | 3,470.8 | 288.5 | 3,056.3 |
| Redprints `/proposals` (20) | 395.1 | 3,413.6 | 489.0 | 2,885.5 |
| Redprints `/proposals/:id` | 400.7 | 2,408.3 | 485.9 | 1,878.4 |
| Starter `/dashboard` | 218.4 | 1,976.2 | 802.7 | 1,242.7 |
| Starter `/settings/profile` | 168.3 | 2,049.2 | 808.4 | 1,309.5 |

Starter HTML includes Node SSR and loopback HTTP; JSON does not invoke SSR.
The profile captures Ruby waiting, not Node's stacks/allocations. There is no
Lowrail request on/off comparison here and **no causal performance claim**.

Reproduce per app, with the production environment/headers above:

```sh
export BENCH_SECONDS=4
mapfile -t routes < <(jq -r '.[] | "GET:"+.' tmp/m0/paths.json)
for format in html json; do
  BENCH_HEADERS="$(cat tmp/m0/headers-$format.json)" \
    BENCH_JSON="tmp/m0/$format-results.json" \
    BENCH_PROFILE="tmp/m0/$format-profile.json" \
    ruby --yjit ../../bench/requests.rb "${routes[@]}"
  ruby ../../bench/profile_summary.rb "tmp/m0/$format-profile.json" "$PWD" 100 \
    > "tmp/m0/$format-summary.txt"
done
```

## StackProf self / inclusive total by area

Wall mode, 100 µs, raw stacks, run **after** timing. Per route the profiler
executes about two seconds of the unprofiled request count (not a fixed
two-second wall capture). Each app/format profile combines its two routes
with approximately equal unprofiled time. C self samples are charged to the
nearest Ruby caller; inclusive areas are counted once/stack and **do not add**.
Zero Alba means the app does not use it, not missed serializer attribution.

| Area (%) | Ping HTML | Ping JSON | Redprints HTML | Redprints JSON | Starter HTML (SSR) | Starter JSON |
|---|---|---|---|---|---|---|
| inertia_rails | 3.1 / 90.2 | 3.5 / 89.9 | 2.8 / 82.9 | 3.4 / 74.4 | 2.5 / 86.6 | 6.0 / 73.8 |
| alba | 0 / 0 | 0 / 0 | 3.6 / 23.9 | 3.8 / 25.5 | 0 / 0 | 0 / 0 |
| activerecord | 31.5 / 83.4 | 35.8 / 81.9 | 17.4 / 81.6 | 19.2 / 71.0 | 6.1 / 85.3 | 13.7 / 67.7 |
| actionpack | 8.2 / 94.1 | 8.7 / 94.2 | 8.3 / 92.9 | 9.2 / 85.4 | 6.5 / 95.0 | 13.5 / 90.8 |
| app Ruby | 0.6 / 51.8 | 0.6 / 46.5 | 0.6 / 75.0 | 0.9 / 62.3 | 0.1 / 14.7 | 0.2 / 34.7 |
| activesupport | 15.2 / 91.2 | 14.7 / 90.9 | 18.6 / 91.4 | 16.9 / 83.6 | 11.2 / 94.2 | 24.8 / 88.4 |
| actionview | 5.0 / 82.7 | 0.6 / 81.3 | 7.9 / 81.0 | 0.4 / 70.4 | 3.5 / 84.7 | 0.7 / 66.4 |
| GC/native without Ruby caller | 4.3 / 0 | 4.1 / 0 | 4.7 / 0 | 12.0 / 0 | 3.0 / 0 | 4.2 / 0 |

Raw-stack denominators, in the same order: **79,773 / 76,247 / 104,960 /
108,450 / 73,184 / 91,100**. These are sampling estimates. Area totals include
large middleware wrappers and dynamic work; they are not removable budgets.
The JSON area itself is 0.6 / 0.7% in PingCRM, 1.6 / 27.4% in Redprints
(Alba's `as_json` is evaluated inside JSON encoding), 1.0 / 1.0% in the starter.
Starter HTML's `net-protocol` self/total is **35.6 / 36.9%**;
`SSRRenderer#request` is **47.94% inclusive** wall. That is renderer IPC/waiting,
not a Ruby lowering opportunity or evidence that the SSR response is static.

## Version digest: an important negative control

All three initializers eagerly assign `config.version = ViteRuby.digest`
(PingCRM/Redprints) or `RailsVite.digest` (starter). Runtime inspection found a
String, and each app's 400-request trace (100 HTML + 100 JSON on each route)
had **zero** calls to those digest methods or `watched_files_digest`.
The same trace explicitly called the digest once as a positive control and
saw the expected 3 ViteRuby / 2 RailsVite method events. There is consequently
no observed request-time asset digest share analogous to ARGOS's 12.8% self.

The APIs differ: ViteRuby hashes watched source inputs, not its manifest.
[3.10.2](https://github.com/ElMassimo/vite_ruby/blob/vite_ruby%403.10.2/vite_ruby/lib/vite_ruby/builder.rb)
has a one-second digest memo;
[3.11.1](https://github.com/ElMassimo/vite_ruby/blob/vite_ruby%403.11.1/vite_ruby/lib/vite_ruby/builder.rb)
also reuses per-file digests when mtime/size are unchanged.
[RailsVite 0.2.3](https://github.com/skryukov/rails_vite/blob/rails_vite%400.2.3/lib/rails_vite/manifest.rb)
does `Digest::MD5.file` on every explicit digest call, but the starter only
calls it at boot. Inertia evaluates a callable version on reads; a plain
String does not re-enter these APIs. Do not turn the eager assignments into
procs merely to manufacture a public optimization case. Findings were sent
to the separate guarded-memo owner; no memo pass was implemented here.

## Measured pass candidates, not predicted gains

JSON profiles; entries are **self / inclusive total %** for named Ruby frames
(unlike area self, these do not charge child C time to the named frame):

| Repeated work | PingCRM | Redprints | Starter |
|---|---|---|---|
| `Configuration#bind_controller` | 0.72 / 2.14 | 0.92 / 3.13 | 1.99 / 6.94 |
| `Controller#inertia_shared_data` | 0.04 / 0.46 | 0.05 / 0.80 | 0.06 / 1.29 |
| `PropsResolver#deep_transform_props` | 0.42 / 10.01 | 0.28 / 1.96 | 0.48 / 12.63 |
| `PropEvaluator#call` (dynamic values inside that traversal) | 0.03 / 8.89 | 0.07 / 1.32 | 0.09 / 11.51 |

1. **Controller configuration/shared-prop descriptors:** plan class-fixed
   option merging and inherited descriptor assembly once, guarded by config,
   registered shared-prop blocks and method owners. Keep the per-request
   controller binding, user/session, flash, locale and proc evaluation.
   The starter's 6.94% inclusive binding cost is a candidate to investigate,
   not 6.94% that can all be removed.
2. **Prop/key traversal:** specialize known descriptor shapes, not resulting
   props. Partial/deferred/once headers, errors, runtime keys and lazy values
   remain inputs. Most traversal total wraps dynamic prop evaluation above.
   Across all callers, `Hash#transform_keys!` is only 0.40 / 0.30 / 0.60%
   inclusive in these JSON profiles; it is not a large standalone lever.
3. **Alba descriptor dispatch:** Redprints' `set_key_and_attribute_body_from`
   is 0.83 / 18.39%, but it includes dynamic getters, time formatting,
   conditional attributes and AR. `_setup` is just **0.19% self**;
   `Resource#initialize` 0.01 / 0.20%, `transform_key` 0.06 / 0.37%, and
   `Alba.regularize_key` 0.31% self. A guarded serializer plan must preserve
   params, conditional blocks, collection behavior and mutable class metadata;
   do not memoize user/CFP/proposal values. This is not ARGOS's missing digest.
4. **Database/framework dispatch remains larger.** PingCRM AR self 35.8%
   includes native PG work; authorization (CanCanCan 6.5% self), model
   instantiation/type handling and queries remain per request. Redprints AR
   self is 19.2%. Fixed schema/serializer plans cannot remove SQL or replace
   authorization results with boot constants. Starter SSR bundle/config
   detection is a smaller boot-fixed-input candidate (`bundle_exists?` 0.83%
   inclusive on HTML), not a way to cache personalized rendered output.

Open work: compose safe ISeq delivery with Freezolite/require-hooks, exercise
unhit units before claiming their support, and measure any future pass with
interleaved off/on cohorts and the same app pins/data/SSR state. Full browser
JS/network performance, concurrent load and Node CPU profiling are outside
this in-process Ruby baseline.
