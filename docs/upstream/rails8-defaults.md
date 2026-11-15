# DEF8: what every new Rails app pays per request

Bet DEF8, 2026-11-14. A fix to a cost that `rails new` puts into every app reaches every new app. P-MAP found one such
cost, `allow_browser` (fixed by AB1, now the draft rails/rails#59808, so left out here). This bet looks for more: it generates fresh apps from
Rails main, switches each default piece off one at a time and prices it, and builds prototypes for the top fixable
ones.

**Result.** Four defaults cost a new app's bare HTML page 9–18% each under YJIT, by Callgrind instructions with a fixed
heap. They are `javascript_importmap_tags` (18.2%), `allow_browser` (12.9%, AB1), logging at the default `info`
level (10.2%) and `stylesheet_link_tag :app` (8.7%). After them come `Rack::ETag` (5% of the bare page and 20% of
the 57 KB index, interpreter) and the executor (4%). Everything else in the default middleware stack and callback
chain costs under 4% each, most of it under 1%.
Two of these have a small exact fix that isn't already in flight, and both are built:

* **IM1** (importmap-rails): keep the modulepreload tags of an entry point in the map's cache when the page has no CSP
  nonce. `javascript_importmap_tags` gets 4.1× faster (benchmark-ips, YJIT). A new app's bare page gets 9.5% fewer
  instructions under YJIT (10.4% in the interpreter) and about 60 fewer objects; the scaffold show page 5.2%.
* **QL1** (Rails): spell out "query"/"queries" in the request log line instead of `"query".pluralize(count)`, which
  ran the inflector's rules on every request with a query count other than 1. `log_process_action` gets 3.2× faster.
  A whole request gets 3.8% fewer interpreter instructions for a small JSON response and 1.8% fewer for a bare HTML
  page, with 6 fewer objects either way.

The rest of the top pieces are inherent, already fixed on an unreleased main branch (Propshaft's `:app` stylesheet
lookup), or covered by open upstream PRs (ETag digest, structured-event overhead), or by recent upstream rework
(`ActionDispatch::Static`, CSRF, `RemoteIp`).

## Setup

* **Apps.** `rails new --dev` from rails/rails main
  [50c54eed06](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b) (`load_defaults 8.2`), in
  three variants: the defaults (SQLite, Propshaft, importmap, Turbo and Stimulus, Solid Cache/Queue/Cable, Thruster
  and Kamal config, health check, PWA views, CSP initializer, Action Text and Active Storage via `rails/all`),
  `--api`, and `--css tailwind`. The resolved gems: propshaft 1.3.2, importmap-rails 2.2.3, turbo-rails 2.0.23,
  stimulus-rails 1.3.4, solid_cache 1.0.10, solid_queue 1.7.2, solid_cable 4.1.0, thruster 0.1.27, useragent
  0.16.11, puma 8.1.0, rack 3.2.8, sqlite3 2.10.2.
* **Scaffold.** `Post` with 20 fields (strings, texts, booleans, a datetime, integers, a decimal) and `Comment`
  (`post:references`), `has_many :comments`, the comments rendered on the post page, 30 posts with 5 comments each.
  A `PagesController#home` (an empty action under `ApplicationController` and the default layout) is the bare page.
* **Workloads.** `home` (bare page), `up` (health check), `index` (30 posts × 20 fields, 57 KB), `show` (post and 5
  comments), `new` (the 20-field form) and `update` (`PATCH` with 20 fields, 303). The API app has `home`, `up`,
  `index`, `show` and `update` as JSON. One cookie jar, so after the first update the client is a returning visitor
  with a session cookie (the scaffold pages read `notice`, which loads it).
* **Production.** `RAILS_ENV=production`, assets precompiled, logs at the default `info` level to STDOUT, which goes
  to `/dev/null` (formatting stays, the write is cheap). Ruby 4.0.9; YJIT is on as production enables it.
* **What is opt-in in the generated app:** the CSP initializer and the PWA routes are commented out, so CSP is
  priced as an opt-in below and PWA costs nothing per request. Thruster is a separate Go proxy in front of Puma and
  isn't in the Ruby request path. Solid Queue and Solid Cable cost nothing on these requests; Solid Cache is only its
  per-request local cache middleware, since nothing in a new app reads the cache.

**Callgrind ablations** ([`bench/upstream/def8/`](../../bench/upstream/def8/): `harness.rb`, `ir.sh`, `matrix.sh`,
`table.rb`). In process through `Rails.application.call`, 100 warmup rounds (300 for YJIT), then `GC.start`, GC off,
and 20 requests per workload inside one `Array#cycle`, dumped per workload. Each piece is switched off in its own
process: middleware dropped from the stack, a helper made to return nil, a callback skipped, the log level set to
`fatal`. The cost of a piece is base minus that run. Base runs twice as A/A. The interpreter runs with
`config.yjit = false`; a YJIT cell counts only when its window compiled no blocks (marked ⚠ otherwise).
**Vernier** (`shares.rb`, `under.rb`): Puma 8.1 in process with one thread, a raw-socket keep-alive client, 500–1,000
requests per workload, 200 µs wall sampling, the Puma worker's samples outside the keep-alive wait plus
`GC.total_time`. Each sample is charged to exactly one piece, the innermost one on its stack. The machine was busy with
Callgrind runs during the profiles, so absolute times are inflated; shares are the signal.
**benchmark-ips**: one pinned core, YJIT, best of 5, interleaved with an A/A.

## What each default piece costs

Callgrind instructions per request that the piece adds (base minus the run with the piece off), as a share of the
request, with objects in parentheses. Default app, interpreter. The A/A row is a second
run of base. Raw: [`data/def8/`](data/def8/).

| Piece | reach | home (bare) | up | index | show | new (form) | update |
|---|---|---:|---:|---:|---:|---:|---:|
| base Ir (objects) | | 2,804,280 (792) | 1,291,121 (328) | 20,827,681 (3,422) | 6,402,960 (1,411) | 14,392,851 (4,118) | 7,831,393 (1,799) |
| A/A | | −0.59% (4) | −0.10% (0) | −0.01% (0) | −0.13% (−2) | −0.08% (0) | −0.11% (0) |
| `javascript_importmap_tags` | HTML, importmap | 17.20% (92) | 0.13% | 2.35% (94) | 7.49% (93) | 3.35% (89) | 0.10% |
| all notification subscribers | all | 13.72% (68) | 9.64% (11) | 2.21% (70) | 6.96% (83) | 2.68% (68) | 8.07% (137) |
| structured-event subscribers | all | 13.34% (64) | 9.07% (14) | 1.82% (66) | 6.29% (77) | 2.51% (68) | 7.66% (127) |
| logging at `info` (vs `fatal`) | all | 10.39% (62) | 0.13% | 1.21% (58) | 4.80% (66) | 2.05% (62) | 6.35% (134) |
| `allow_browser` (AB1) | HTML | 10.01% (182) | 0.18% | 1.41% (183) | 4.46% (182) | 1.96% (182) | 3.65% (182) |
| `stylesheet_link_tag :app` | HTML, Propshaft | 7.90% (80) | 0.04% | 1.07% (83) | 3.53% (83) | 1.50% (77) | 0.07% |
| `Rack::ETag` | all | 5.18% (5) | 1.92% (5) | 20.09% (7) | 6.02% (3) | 2.84% (5) | 0.11% |
| `ActionDispatch::Executor` | all | 3.99% (15) | 8.29% (18) | 0.69% (23) | 3.28% (27) | 0.78% (18) | 2.18% (18) |
| `Rails::Rack::Logger` | all | 3.51% (24) | 4.32% (14) | 0.46% (26) | 1.52% (22) | 0.67% (24) | 1.80% (43) |
| `ActionDispatch::Static` | all | 2.52% (33) | 4.67% (33) | 0.38% (37) | 0.72% (24) | 0.37% (21) | 0.19% |
| CSRF callbacks (4) | HTML | 2.08% (11) | 3.15% (11) | 0.24% (13) | 0.69% (11) | 0.36% (11) | 0.83% |
| `csrf_meta_tags` (renders nothing) | HTML | 1.69% | −0.12% | 0.21% (4) | 0.49% | 0.24% | 0.18% |
| `ActionDispatch::RequestId` | all | 1.29% (15) | 2.17% (12) | 0.20% (17) | 0.69% (16) | 0.28% (15) | 0.61% (16) |
| `ActionDispatch::RemoteIp` | all | 0.90% (13) | 0.56% (2) | 0.15% (15) | 0.50% (13) | 0.22% (13) | 0.38% (15) |
| Turbo `turbo_tracking_request_id` | HTML | 0.76% (4) | 1.28% (4) | 0.11% (2) | 0.32% (5) | 0.12% (4) | 0.30% (4) |
| `Rack::TempfileReaper` | HTML | 0.60% (1) | 1.01% (5) | 0.02% (6) | 0.33% (8) | 0.17% (5) | 0.05% (3) |
| Solid Cache local cache middleware | all | 0.55% (6) | 0.83% (6) | 0.09% (9) | 0.28% (6) | 0.06% (6) | 0.30% (7) |
| `csp_meta_tag` (renders nothing) | HTML | 0.56% (1) | 0.02% | 0.04% (3) | 0.14% (4) | 0.02% | 0.03% |
| `Rack::Runtime` | all | 0.47% (1) | 0.74% (1) | 0.07% | 0.21% (3) | 0.17% (1) | 0.14% |
| `log_tags = [:request_id]` | all | 0.47% | 0.03% | −0.01% | −0.04% | 0.06% | 0.12% |
| `ActionDispatch::ContentSecurityPolicy::Middleware` | HTML | 0.40% (1) | 0.72% (1) | 0.09% (3) | 0.28% (4) | 0.06% (1) | 0.17% |
| `DebugExceptions`, `ShowExceptions`, `Callbacks`, `ConditionalGet`, `Head`, `MethodOverride` | all/HTML | ≤ 0.64% each, 0 objects | | | | | |
| `stale_when_importmap_changes` | HTML | 0.12% | 0 | 0.02% | 0.08% | 0.01% | 0.01% |
| `Rails::Rack::SilenceRequest` | all | 0.11% | −24.32% (−78): it keeps `/up` out of the log | | | | |
| **opt-in:** CSP from the commented initializer, session nonce | HTML | +18.93% (+159) | +31.19% (+155) | +1.09% (+32) | +3.51% (+30) | +3.56% (+153) | +1.17% (+26) |

Read the "all notification subscribers" and "structured-event subscribers" rows together with the logging row: at
`info`, the three log lines (Started, Processing, Completed) are 10.4% of the bare page. At `fatal`, the structured
events are still built and cost another 3%. The notifications machinery without any subscriber is a further 0.4%.
`ActionDispatch::Flash` is `new(app) = app` and costs nothing; Cookies and the session store can't be dropped without
breaking the app, so they appear only in the Vernier shares.

**YJIT, same ablations** for the four largest (Callgrind, default app; index cells are rejected because their base
and A/A windows compiled 9 and 2 blocks):

| Piece | home (bare) | show | new (form) | update |
|---|---:|---:|---:|---:|
| base Ir (objects) | 1,754,276 (794) | 3,628,961 (1,415) | 8,095,537 (4,139) | 4,647,887 (1,802) |
| A/A | +0.28% | −0.14% | −0.05% | −0.35% |
| `javascript_importmap_tags` | 18.22% (92) | 8.70% (90) | 4.00% (92) | 0.18% |
| `allow_browser` (AB1) | 12.90% (182) | 6.31% (184) | ⚠ 38 blocks | 4.83% (184) |
| logging at `info` | 10.23% (62) | 5.33% (68) | ⚠ 38 blocks | 8.24% (139) |
| `stylesheet_link_tag :app` | 8.67% (80) | 3.75% (77) | 1.68% (77) | 0.20% |

**API app** (`--api`, interpreter). The JSON bare request is 1,268,961 instructions and 308 objects, and there logging
weighs most: `info` logging is 25.61% (80 objects), `Rails::Rack::Logger` 10.62% (38), the executor 8.99%,
`Static` 4.74% (33), `RemoteIp` 3.28% (17), `RequestId` 3.06% (15), `ETag` 1.81%, the local cache 1.42%
([table](data/def8/ablation-api.md)). **Tailwind** (`--css tailwind`) adds a second stylesheet to `:app`, so
`stylesheet_link_tag` costs 12.41% of its bare page (107 objects); the other pieces match the default app within a
point ([table](data/def8/ablation-tw.md)).

## Where the time goes (Vernier, YJIT)

Share of server time, each sample charged to one piece, default app ([full table](data/def8/shares-blog-yjit.md)).
The bare page took 1.37 ms per request in this run and `show` 2.94 ms; the machine was loaded, so read shares, not
times.

| Piece | home | up | index | show | new | update |
|---|---:|---:|---:|---:|---:|---:|
| Puma (parse, write, keep-alive) | 14.8 | 26.9 | 4.4 | 8.1 | 5.4 | 7.5 |
| logging | 14.8 | 7.0 | 4.3 | 8.1 | 5.7 | 10.4 |
| controller (Metal, AbstractController) | 9.9 | 20.6 | 3.9 | 7.6 | 4.9 | 9.1 |
| Action View (other than the helpers below) | 8.3 | 4.1 | 24.3 | 13.6 | 56.0 | 0.9 |
| `allow_browser` | 7.6 | – | 2.1 | 4.1 | 2.2 | 3.5 |
| `stylesheet_link_tag` | 7.3 | – | 1.9 | 3.6 | 2.3 | – |
| `javascript_importmap_tags` | 6.9 | – | 1.4 | 2.8 | 1.7 | – |
| GC | 6.1 | 6.4 | 8.6 | 5.3 | 8.7 | 11.6 |
| callback chains | 4.1 | 5.2 | 1.3 | 2.3 | 1.7 | 3.1 |
| `ActionDispatch::Static` | 3.9 | 8.7 | 1.4 | 1.2 | 1.0 | 0.0 |
| notifications machinery | 3.0 | 2.8 | 1.5 | 2.1 | 0.8 | 1.8 |
| `Rack::ETag` | 2.3 | 1.9 | 7.5 | 2.2 | 1.2 | 0.1 |
| params | 2.2 | 3.3 | 0.8 | 1.3 | 1.0 | 12.3 |
| session and cookies | 0.7 | 0.9 | 6.0 | 11.1 | 0.2 | 11.0 |
| Active Record | 1.1 | 1.6 | 23.2 | 21.3 | 4.2 | 22.6 |

In the API app's JSON bare request ([table](data/def8/shares-blogapi-yjit.md)), logging is 22.4%, Puma 24.0% and
`Static` 16.3% (six `stat(2)` calls for a top-level path like `/home`, on a busy machine). Inside logging,
`"query".pluralize` is 9.4% of the logging samples, about 2% of the request, which QL1 removes. Computing the remote
IP for the Started line is another 11.7% of the logging samples.

## Ranked by cost × reach

Cost is the bare page's YJIT Callgrind share where measured, the interpreter share otherwise. Reach: "all" is every
new app, including `--api`; "HTML" is every app without `--api`; "importmap" and "Propshaft" are the defaults that
`--javascript` and `--css` options can replace.

| # | Piece | Cost | Reach | Inherent? | Upstream | Small exact fix? |
|---|---|---|---|---|---|---|
| 1 | Logging at `info`: three lines per request through structured events | 10.2% YJIT bare page, 25.6% interp API JSON | all | mostly (the lines are wanted) | rails/rails#58957 (skip event handlers nobody consumes) and #59717 (skip `source_location`) open, not ours; pluralize hadn't been touched | **QL1, built**: the inflector call in the Completed line. The rest (remote IP for the Started line, `Time#to_s`, tagging) is the log's content |
| 2 | `javascript_importmap_tags` | 18.2% YJIT bare page, 8.7% show | HTML with importmap (the default) | no: the tags are the same on every page without a nonce | our importmap-rails#336 (2 objects per tag) open and unanswered since 10-22; #333 (Early Hints, not ours) touches the same helper | **IM1, built**: cache the modulepreload tags with the packages they come from |
| 3 | `allow_browser` | 12.9% YJIT bare page | HTML | no | AB1, ours: [rails/rails#59808](https://github.com/rails/rails/pull/59808) (draft) | AB1 |
| 4 | `stylesheet_link_tag :app` | 8.7% YJIT, 7.9% interp; 12.4% with Tailwind | HTML with Propshaft | partly: `Rails.root.join` per call to build the glob is 45k instructions and 40 objects of it | fixed on Propshaft main (resolver-based `app_asset_paths_by_type`, unreleased since 1.3.2; with it the piece drops to 187k instructions and 36 objects, from 221k and 80); the rest is Rails' `AssetTagHelper` | no: what is left is spread over asset path, Link header and tag building |
| 5 | `Rack::ETag` body digest | 5.2% interp bare page, 20.1% of the 57 KB index | all | the digest is by design | rack/rack#2522 (OpenSSL SHA-256) open, not ours | covered |
| 6 | Executor (query cache, connection pool, `CurrentAttributes` hooks) | 4.0% interp bare page, 9.0% API | all | yes | – | no |
| 7 | `ActionDispatch::Static` | 2.5% interp, 4.7% API | all | the probe is by design | reworked 2026-10-13 to 11-09 by three authors (probe the top-level entry, skip ASCII copies, precompressed-only files) | no; a top-level path like `/home` or `/up` still does six `stat(2)` calls since the precompressed probe, a nested one does one |
| 8 | CSRF callbacks under `:header_only` | 2.1% interp | HTML | partly | reworked on main this month (Vary header, config reads) | no, in flux |
| 9 | `csrf_meta_tags` that renders nothing under `:header_only` | 1.7% interp | HTML | no | the `:header_only` change is from 10-25 and the config reads from 11-06 | not now: code being reworked |
| 10 | `RequestId`, `RemoteIp`, Turbo request id, local cache, `Runtime` | 0.5–1.3% each | all/HTML | yes or nearly (one UUID, one IP parse, one `LocalStore`) | `RemoteIp` optimized 10-30 | no |
| – | CSP (opt-in) with the session nonce from the template | +18.9% interp bare page; YJIT: the nonce is 5.1% of a bare page that otherwise wouldn't load the session | apps that enable CSP | the session nonce is the template's choice | – | no: a per-session nonce keeps Turbo navigations valid |

## Prototypes

Both are on our forks, built on the current upstream main, one commit each by Thomas Klemm with no trailers and no
comments. Queue items: [QL1](../../bench/upstream/pr-queue/items/QL1.md) and
[IM1](../../bench/upstream/pr-queue/items/IM1.md), state `reviewed`; review passes are recorded there and summed up
under [Reviews](#reviews).

### IM1: cache the modulepreload tags (importmap-rails)

[`thomasklemm/cache-module-preload-tags`](https://github.com/thomasklemm/importmap-rails/tree/thomasklemm/cache-module-preload-tags),
[`863322e`](https://github.com/thomasklemm/importmap-rails/commit/863322e8a1d98da1b460abab019d76e8313cf2a5) on
importmap-rails main `f255e55` (the measurements below are of the first head, `52e2d73`, which differs only for a
`false` nonce; see [Reviews](#reviews)). `javascript_importmap_module_preload_tags` built one `<link rel="modulepreload">` per
preloaded package on every page (seven in a new app), from packages the map already caches per entry point. Without a
CSP nonce (a nil one) the tags depend only on those packages, so they now go into the same map cache (`cache_as`, made public as
`:nodoc:`) under the entry point, are cleared with it when a pin changes or the sweeper runs, and are returned as a
copy. Pages with a nonce, `false` included, build them as before.

Exactness: a differential probe ([`im1_probe.rb`](../../bench/upstream/def8/im1_probe.rb)) of 20 cases (a `false` nonce before and after a plain page, plain, nonce,
plain after a nonce, another nonce, no request, full tags with and without nonce, a custom map with String, other and
Array entry points, a caller appending to the result, a pin added after the first render, `javascript_module_preload_tag`,
result identity) prints identical output on main and the branch, and main against itself. Suite: 105 runs, 0 failures
(Rails 8.1, Ruby 4.0.9, three seeds). The one new test renders two entry points, two nonces and a `false` one, appends
to a result and adds a pin; it passes on main and fails on the first head and on five wrong versions (no copy, caching
only with a nonce, a key without the entry point, a cache outside the map that pins don't clear).

Callgrind, whole request through the default app, interpreter, importmap-rails main against the branch (a second
run of main as A/A):

| Workload | main Ir (objects) | A/A | IM1 |
|---|---:|---:|---:|
| bare page | 2,799,328 (792) | +0.12% | −10.42% (−62) |
| index (30 posts) | 20,830,141 (3,420) | −0.06% | −1.49% (−64) |
| show (post and 5 comments) | 6,405,361 (1,411) | −0.05% | −4.68% (−64) |
| new (20-field form) | 14,390,868 (4,118) | −0.06% | −2.14% (−62) |
| update (redirect, no layout) | 7,820,599 (1,802) | −0.02% | −0.08% |

Under YJIT (bare page and show only, so the client has no session cookie; every window compiled no blocks): bare
page 1,746,656 → 1,581,203 instructions, −9.47% (A/A +0.66%), 790 → 728 objects; show 3,246,137 → 3,077,764,
−5.19% (A/A +0.04%).

benchmark-ips of `javascript_importmap_tags` in the default app's view context (`im1_ips.rb`, `bin/rails runner` in
production, YJIT, core 3, best of 5, [raw](data/def8/ips/): `imb` main, `imaa` its A/A, `im1` the branch):

| | main | A/A | IM1 | change |
|---|---:|---:|---:|---:|
| `javascript_importmap_tags` | 25,167 i/s | 24,627 (−2.1%) | 103,331 i/s | 4.1× |

### QL1: spell out "query" and "queries" (Rails)

[`thomasklemm/controller-runtime-query-literal`](https://github.com/thomasklemm/rails/tree/thomasklemm/controller-runtime-query-literal),
[`ce6d068`](https://github.com/thomasklemm/rails/commit/ce6d06884094c58baec9b6cf66eb4cc2df0ad51f) on 50c54eed06.
`log_process_action` in `ActiveRecord::Railties::ControllerRuntime` wrote `"query".pluralize(queries_count)` into the
Completed line of every request. `String#pluralize(count)` returns the word itself for 1 and otherwise runs
`Inflector.pluralize` with `:en`, which checks the uncountables and then the plural rules (43k interpreter instructions
and 6 objects a call, after jhawthorn's rails/rails#59651 already made the rules cheaper). The count is an Integer, so
the branch writes `queries_count == 1 ? "query" : "queries"`. It differs only for an app whose English inflections
pluralize "query" differently (an irregular or uncountable for it, or a generic rule such as `/y$/` to `ys`). `"query".pluralize(n)` equals the literal for every n from −3 to 2,000 and for 0.0, 1.0 and
2.5 under the default inflections. Suites: Action View's Active Record integration tests (177 runs, which include the
`(0 queries, 0 cached)` and `(1 query, 0 cached)` assertions) and `controller_runtime_test.rb`, 0 failures.

Callgrind, whole request, interpreter, same harness as above:

| Workload | base Ir (objects) | A/A | QL1 |
|---|---:|---:|---:|
| API: `GET /home` (JSON, no query) | 1,268,961 (308) | −0.03% | −3.84% (−6) |
| API: `GET /posts/1` (2 queries) | 3,976,192 (684) | +0.01% | −1.03% (−6) |
| HTML: bare page (no query) | 2,804,280 (792) | −0.59% | −1.77% (−6) |
| HTML: show (2 queries) | 6,402,960 (1,411) | −0.13% | −0.92% (−9) |
| HTML: index, update (1 query each) | | ≤ 0.11% | +0.00%, +0.27%: unchanged, as expected |

benchmark-ips of `log_process_action` with two queries (`ql_ips.rb`, YJIT, core 3, best of 5, [raw](data/def8/ips/):
`qlb` main, `qlaa` its A/A, `ql1` the branch):

| | main | A/A | QL1 | change |
|---|---:|---:|---:|---:|
| `log_process_action` | 245,107 i/s | 239,083 (−2.5%) | 792,623 i/s | 3.2× |


### Reviews

Two claude-code orbs (Opus 5.5, effort high) reviewed both heads independently:
[claude-code](https://ampcode.com/threads/T-01a1dc64-bf9b-767f-a931-99cff8cc12ab) and
[opus](https://ampcode.com/threads/T-01a1dc64-c914-71e3-b32d-db2e5e85f50f). Both found the code of QL1 exact and the
IM1 approach right; both asked for changes.

* **IM1, code (opus).** The first head cached whenever the nonce was falsy, but a nonce generator may return `false`
  (`->(r) { r.ssl? && SecureRandom.base64(16) }`), and main then renders `nonce="false"` on that page only. The head
  cached those tags and served them to later pages without a nonce. Now only a nil nonce caches (`863322e`); the probe
  gained the `false` cases and is identical to main, and opus measured the fixed bare page at −10.54% (interpreter),
  as before. claude-code didn't find this one.
* **IM1, test (both).** The first head's test let four of five plausible wrong versions pass. The new test is
  claude-code's with a `false`-nonce step from opus's.
* **QL1, body (both).** The Completed line ends in `| GC: …ms)`, so "ends in" became "includes"; the bare HTML page
  measured 1.43% and 1.81%, so "2 to 4 percent" became "up to 4 percent". The head is unchanged.
* **Numbers reproduced** on 2-core orbs, core 1: IM1 ips 3.9× in both (record 4.1×), bare page −10.55% and −10.64%
  interpreter, −9.89% YJIT; 59 and 63 fewer objects (record 62), so the body says about 60. QL1 ips 3.3× and 3.0×
  (record 3.2×), JSON bare −3.56% (record −3.84%).
* **Confirm passes** on `863322e` and the QL1 body: both reviewers approve IM1 (the new test fails on every wrong
  version they tried, including the old head; the 20-case probe and their wider probes match main; ips 4.0× on the
  fixed head). QL1: opus approves, claude-code `nits` (the optional 2-query test below). Both items are `reviewed`.
* **Not done**, optional: a 2-query case in `controller_runtime_test.rb` (the mutant `zero? ? "queries" : "query"`
  passes today); a dedicated method instead of the public `:nodoc:` `cache_as`, if a maintainer asks.

## Leads not built

* **`csrf_meta_tags` under `:header_only`** renders nothing but still costs 1.7% of a bare page (interpreter): it asks
  `protect_against_forgery?` twice (once directly, once inside `embed_authenticity_token?`), each reading the session
  and the controller config. The `:header_only` change (Sam Ruby, 10-25) and the config reads (Luke Gruber, 11-06) are
  this month's work, so it waits.
* **View-side config reads in `AssetUrlHelper`** (`config.asset_host`, `relative_url_root`,
  `default_asset_host_protocol`) still go through `OrderedOptions#method_missing`, about 8% of one `stylesheet_link_tag`
  call in the interpreter; the controller side was changed on 11-06 by its maintainer. A follow-up for him, not for us.
* **`ActionDispatch::Static` on top-level paths** (`/home`, `/up`, `/login`): six `stat(2)` calls per request since the
  precompressed-only probe (b63dddb7e3, 11-09), against one for a nested path. Being reworked by others.
* **Form parsing**: `Rack::QueryParser#unescape` (`URI.decode_www_form_component`, a `gsub` with a Hash per `+` and
  `%XX`) is 6.0% of the 20-field update under YJIT (inclusive). ruby/uri is parked.
* **Solid Cache's local cache** builds a `LocalStore` and a `BodyProxy` per request although nothing in a new app
  reads the cache (0.55%, 6 objects). Making it lazy changes when the store exists; small, left.
* **CSP (opt-in)**: the template's nonce generator, `request.session.id`, loads the session on pages that otherwise
  wouldn't (5.1% of a bare page under YJIT with a session cookie); per-session nonces keep Turbo navigations valid, so
  this is by design. Building the header itself is 0.5–1.5%.
