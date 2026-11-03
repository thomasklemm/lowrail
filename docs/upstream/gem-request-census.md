# Gem request census: request CPU in gem code, and three boot leads checked in the gems

Lowrail bet G1, second round. The [gem census](gem-census.md) ranked gem allocation sites; this round asks where
**request CPU** goes in gem code (not Rails, not the app) across the 20 census apps on Rails main with Ruby 4.0.7,
in the interpreter and under YJIT, with an A/A pair. It also checks the three boot leads from
[rails-boot](rails-boot.md) (Propshaft, ViewComponent, Devise) in the gems themselves. Nothing is opened or posted;
the drafts are below.

**Result.** Gems take **23% of request CPU** in the interpreter and 28% under YJIT (Rails 69% / 63%, app code
5%), mean over 213 workloads. Most of it is required or already in someone's open PR:

* pg's `get_result` (5.8% / 8.6%) is the wait for PostgreSQL, sqlite3 (1.4% / 2.3%) is the SQLite engine, and
  redis-client is socket I/O.
* rack (2.1% / 2.4%, all 20 apps) is covered by open PRs from others: rack/rack#2519 (approved), rack/rack#2520
  and rack/rack#2522.
* i18n (1.3% / 1.1%) is covered by our own i18n work ([i18n-performance](i18n-performance.md)).
* concurrent-ruby (1.1% / 1.4%, all 20 apps) is call volume: thin wrappers around Hash, behind Rails' caches.

The gems in the brief (Devise, Warden, Turbo, Sidekiq, jbuilder, Pundit) each spend under 0.03% of request CPU in any
one method.

Two exact candidates came out:

| # | Fork branch | Per call, Ir (4.0.7 interp / YJIT, master ZJIT) | Objects | L |
| --- | --- | --- | --- | --- |
| P1 | [thomasklemm/propshaft `thomasklemm/logical-path-without-pathname`](https://github.com/thomasklemm/propshaft/tree/thomasklemm/logical-path-without-pathname) [`a5bd01cc65`](https://github.com/thomasklemm/propshaft/commit/a5bd01cc65dd1eb7bcb8407ab13b2e2db591dc8b) | load path over 422 assets: 99.5 M → 12.6 M / 95.7 M → 10.4 M / 33.9 M → 7.4 M | 74,015 → 9,970 | L1 |
| R1 | [thomasklemm/rack-mini-profiler `thomasklemm/render-subscribers-check-measure`](https://github.com/thomasklemm/rack-mini-profiler/tree/thomasklemm/render-subscribers-check-measure) [`03a1eaae2c`](https://github.com/thomasklemm/rack-mini-profiler/commit/03a1eaae2c52a073713e6cd6ea800068dd68e76e) | one render event, not profiled: 33.9 k → 25.4 k / 21.5 k → 14.1 k / 21.3 k → 14.3 k; in 5 apps 0.43% → 0.32% of request CPU | 18 → 7 per render | L0 |

The three boot leads, checked in the gems:

* **Propshaft:** the Pathname work is real and is P1.
* **ViewComponent:** main already halved it on the day of this round (view_component#2769). What remains repeats
  globs and file reads per ancestor (a lead).
* **Devise:** the second route draw reaches 4 apps, but has no exact fix inside Devise (a lead).

## Pins and method

* **Rails:** canonical `rails/rails` main [`1105756f42`](https://github.com/rails/rails/commit/1105756f426ee42834af5c87b4549ef709d631e5)
  (`git ls-remote` on 2026-11-03, 17:25 UTC); all copies set up fresh on it with `script/census setup`.
* **Ruby 4.0.7** (mise), interpreter and `--yjit`, production, as briefed. Lowrail's pin moved to 4.0.9 during
  this round ([DECISIONS](../DECISIONS.md#evidence-and-measurement)); every census label here is on 4.0.7, and
  the candidates' per-call numbers are also given on 4.0.9. Ruby master
  [`a8b095a07e`](https://github.com/ruby/ruby/commit/a8b095a07e55adf429839d4642027e832e30d3a7), built here with
  `--enable-zjit`, for the ZJIT micros.
* **Apps:** one configuration per app, 20 apps: blog, campfire, writebook, fizzy (SQLite), codetriage, pingcrm,
  redprints-cfp, react-starter-kit, lobsters, docuseal, mastodon, lago, discourse, loomio, sure, casa, chatwoot,
  flow, thinkroom, hackatime; 213 workloads. Services are disposable orb services: PostgreSQL 15 with pgvector
  0.8.1 and pg_partman, Redis, memcached, MySQL 8.4.10.
* **Profiler:** [`prof.rb`](../../bench/upstream/gem_request_census/prof.rb), driven by
  [`run.rb`](../../bench/upstream/gem_request_census/run.rb), uses the census harness's boot and workloads.
  * **Warm-up and sampling:** per workload, 50 warm-up operations, then 150 operations under stackprof (0.2.28,
    wall mode, 100 µs, raw stacks). Chatwoot runs 60, because its message POSTs hit Chatwoot's own per-minute
    flood limit beyond that. Side-effect resets run with the profiler stopped.
  * **Attribution:** each sample goes to the leafmost frame that belongs to the app, Rails, the harness
    (rack-test, Rack's mock request) or a gem. C functions, `<internal:…>` frames, Ruby's standard library and
    its default gems (except json, as in `rank --gem all`) fold into their caller.
  * **Wait:** samples whose leaf is a Ruby-level wait (`IO#wait_readable`, `sleep`, `Queue#pop`, …) count as wait
    and are left out.
  * **Objects:** 10 more operations run under stackprof's object mode, attributed the same way, for an objects
    column.
* **Ranking:** [`rank.rb`](../../bench/upstream/gem_request_census/rank.rb).
  * **Reach:** a site (a gem, or a gem method keyed by path and name, so gem releases with shifted lines share a
    key) reaches a workload at ≥ 0.1% of that workload's samples.
  * **Order:** tiers by apps reached (≥ 7, 5–6, 3–4, 2, 1), then by mean share over all 213 workloads.
  * **Columns:** share of CPU samples, µs per operation (share × the thread CPU time of the operation), objects
    per operation, and the A/A difference.
  * **Owners:** [`owners.rb`](../../bench/upstream/gem_request_census/owners.rb) gives the split by owner.
* **A/A:** labels `p` and `p2`, two full runs of the same commit. Candidates are compared with `p2`.
* **Per call:** Callgrind `Ir` with GC disabled, `(Ir(N) − Ir(0)) / N` after a warm-up, base / branch / base:
  * [`ir.sh`](../../bench/upstream/gem_request_census/ir.sh) counts the whole process;
  * [`ir_region.sh`](../../bench/upstream/gem_request_census/ir_region.sh) counts only the measured loop through
    Lowrail's [`bench/callgrind.c`](../../bench/callgrind.c). It is used where boot varies more than the calls
    cost (a Rails app): `ir.sh` gave negative per-call counts there.
* **Receipts:** [`data/gem-request-census/receipts.tar.xz`](data/gem-request-census/receipts.tar.xz): the 80 `p`/`p2`
  receipts, the 10 `rmp` receipts, rankings and owner splits.

**Caveat on "CPU".** Samples are wall-clock inside the request. A C call that blocks without a Ruby-level wait,
pg's `get_result` while PostgreSQL works, counts as its gem's time. That is why pg is first. sqlite3 runs in
process, so its share is real CPU.

## Where request CPU goes

Mean share of each workload's samples outside I/O wait, over 213 workloads (`p` / `p2`):

| Owner | Interpreter | YJIT |
| --- | ---: | ---: |
| Rails | 69.0 / 69.8% | 63.2 / 63.6% |
| gems | 23.5 / 23.0% | 27.7 / 27.5% |
| app | 4.9 / 4.6% | 5.3 / 5.3% |
| GC | 1.6 / 1.5% | 2.6 / 2.5% |
| harness | 1.0 / 1.1% | 1.1 / 1.2% |

## Ranking by gem

`p2`, top tier (≥ 7 apps), then the 5–6 tier. Share is the mean share of CPU samples per workload; A/A is `p2 − p`
in percentage points.

| # | Gem | Apps | Interp share (A/A) | YJIT share (A/A) | µs/op interp | Objects/op | Disposition |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | pg | 12 | 5.85% (−0.36) | 8.61% (−0.16) | 3,627 | 17.6 | Wait: `get_result` while the server runs the query |
| 2 | rack | 20 | 2.09% (−0.10) | 2.42% (+0.01) | 606 | 177 | Covered: open rack/rack#2519, rack/rack#2520 and rack/rack#2522 (below) |
| 3 | sqlite3 | 8 | 1.42% (−0.12) | 2.27% (−0.14) | 479 | 107 | Required: SQLite `step` and `prepare` |
| 4 | i18n | 20 | 1.27% (−0.01) | 1.07% (+0.03) | 1,122 | 410 | Covered: our ruby-i18n/i18n#763, #764 and #765 and C1–C4 ([i18n-performance](i18n-performance.md)) |
| 5 | concurrent-ruby | 20 | 1.13% (−0.02) | 1.44% (+0.02) | 637 | 5.9 | Call volume: `Map#[]`, `compute_if_absent` and `MutexAtomicFixnum` behind Rails (below) |
| 6 | nokogiri | 12 | 0.72% (−0.01) | 0.93% (−0.01) | 416 | 131 | Required: sanitizer XPath and serialization |
| 7 | redis-client | 9 | 0.70% (+0.08) | 0.79% (+0.01) | 373 | 38 | Required: socket writes and reads |
| 8 | json | 19 | 0.37% (+0.01) | 0.54% (+0.02) | 146 | 44 | Required: generate and parse |
| 9 | useragent | 7 | 0.37% (+0.01) | 0.45% (+0.01) | 66 | 43 | Lead (Rails); the gem is unmaintained (below) |
| 10 | tzinfo | 20 | 0.36% (+0.01) | 0.23% (+0.00) | 237 | 84 | Lead from the gem census: `Timestamp.for_time` (Active Support) |
| 11 | globalid | 10 | 0.27% (+0.01) | 0.32% (+0.01) | 83 | 24 | Rejected (below) |
| 12 | lograge | 8 | 0.15% | 0.15% | 60 | 9 | App logging, spread over formatting |
| 13 | logger | 17 | 0.13% | 0.14% | 47 | 0.4 | Level checks; required |
| 14 | rack-session | 17 | 0.13% | 0.09% | 34 | 2.4 | Cookie session commit; required |
| 15 | connection_pool | 10 | 0.12% | 0.10% | 62 | 14 | Our connection_pool#225 (open) |
| 16 | base64 | 16 | 0.11% | 0.14% | 41 | 11 | Required: encode and decode |
| 17 | turbo-rails | 7 | 0.07% | 0.08% | 30 | 10 | Nothing above 0.01% per method |
| 18 | propshaft | 7 | 0.07% | 0.07% | 25 | 11 | Request side small; the boot and precompile side is P1 |
| – | mail | 5 | 1.34% | 1.28% | 89 | 76 | Mailer workloads only, spread; `8bit.rb` covered by open mikel/mail#1693 |
| – | inertia_rails | 6 | 0.89% | 0.99% | 204 | 95 | Mostly `SSRRenderer#request` (the SSR server) and prop transforms |
| – | rack-mini-profiler | 5 | 0.51% | 0.61% | 280 | 146 | Discourse's PG patch is the job; render subscribers are **R1** |
| – | sentry-ruby | 6 | 0.45% | 0.36% | 167 | 25 | Hub lookup and breadcrumbs, spread |
| – | jbuilder, warden, devise | 6 each | 0.16%, 0.12%, 0.10% | 0.14%, 0.11%, 0.09% | 93, 39, 36 | 25, 12, 5.5 | No method above 0.03% |

Sidekiq (3 apps), Pundit (1 app) and pagy (5 apps) each stay under 0.05% of request CPU.

## Ranking by method

`p2`, interpreter; YJIT has the same sites in nearly the same order. Methods of pg, sqlite3, redis-client, json and
nokogiri that are required work (as in the table above) are left out after the first row.

| # | Method | Apps | Share (A/A) | µs/op | Objects/op | Disposition |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 1 | pg `Connection#get_result` | 12 | 5.84% (−0.36) | 3,622 | 12 | Wait |
| 3, 5, 7 | concurrent-ruby `NonConcurrentMapBackend#[]`, `#get_or_default`, `MriMapBackend#compute_if_absent` | 20 | 0.33%, 0.29%, 0.21% | 167, 185, 103 | 0 | Two frames over `Hash#[]`; Rails' caches call them. Nothing to remove in the gem |
| 11 | i18n `Base#config` | 19 | 0.15% (−0.02) | 105 | 0 | Covered: our C4 (`fiber-storage-check-once`) |
| 12 | i18n `Simple#lookup`, `Base#translate`, `Fallbacks#translate` | 16 | 0.14%, 0.11%, 0.11% | 164, 120, 144 | 58, 57, 131 | Covered: I1, I2, C1–C3 |
| 13 | rack `Request::Env#get_header` | 18 | 0.13% | 46 | 0.1 | Required: a Hash read per call; rack/rack#2520 removes repeated `ssl?`/scheme work |
| 14 | rack `ETag#digest_body` | 19 | 0.13% (−0.02) | 49 | 3.4 | Covered: rack/rack#2522 (OpenSSL SHA-256) |
| – | concurrent-ruby `MutexAtomicFixnum#synchronize` | 20 | 0.12% | 75 | 0 | Lead (Rails): Active Record's `@query_cache_version` |
| – | rack `QueryParser#unescape`, `#each_query_pair` | 15 | 0.11%, 0.08% | 26, 20 | 34, 26 | Covered: rack/rack#2519 (approved by jeremyevans) for the parser; the decoding copies are ruby/uri's (parked) |
| – | rack `Utils.escape`, `Utils.unescape` | 16, 15 | 0.11%, 0.09% | 26, 21 | 13, 15 | ruby/uri `encode_www_form_component` and `decode_www_form_component`; parked |
| – | globalid `URI::GID.build` | 10 | 0.08% | 40 | 12 | Rejected (below) |
| – | useragent `Version#initialize`, `UserAgent.parse` | 7 | 0.08%, 0.06% | 13, 10 | 11, 8 | Lead (Rails), below |
| – | tzinfo `Timestamp.for_time` | 11 | 0.06% | 38 | 32 | Lead (Active Support), as in the gem census |
| – | rack-mini-profiler `MiniProfilerRails.shorten_identifier` | 3 | 0.02% | 44 | 82 | **R1** |

The full rankings (both modes, every site) are in the receipts.

## P1: Propshaft computes logical paths without `Pathname#relative_path_from`

`LoadPath#assets_by_path` walks every load-path directory and, for each file, computes its logical path with
`file.relative_path_from(path)`. That runs `cleanpath` on both paths and `chop_basename` per component, about
170 objects per asset. The branch computes `File.join(path, "")` once per directory and takes
`file.to_s.delete_prefix(prefix)`:

```diff
       @cached_assets_by_path ||= Hash.new.tap do |mapped|
         paths.each do |path|
+          prefix = File.join(path, "")
           without_dotfiles(all_files_from_tree(path)).each do |file|
-            logical_path = file.relative_path_from(path)
-            mapped[logical_path.to_s] ||= Propshaft::Asset.new(file, logical_path: logical_path, load_path: self)
+            logical_path = file.to_s.delete_prefix(prefix)
+            mapped[logical_path] ||= Propshaft::Asset.new(file, logical_path: logical_path, load_path: self)
           end if path.exist?
```

**Where it runs.** Once per process wherever something reads the load path in production. In Mastodon that is
inline_svg on the first request: 25 ms of CPU and 123k objects, the "112k Pathnames" of
[rails-boot](rails-boot.md). Sure and Redprints also use inline_svg. It also runs in every `assets:precompile`, on
every development cache sweep, and with the dynamic resolver. Propshaft 1.0.0, 1.1.0 and 1.3.2 all have the line;
15 of the 20 census apps use Propshaft. Since rails/propshaft#272 and rails/propshaft#274, production lookups go
through the manifest, so the remaining users are precompile, development and direct load-path callers.

**Why it is exact.** `Pathname#children` builds each child as `File.join(@path, entry)`, or as the bare entry when
the path is `"."`. This holds in Ruby 4.0's `pathname_builtin.rb` and in the older pathname gems. So every file string
starts with `File.join(path, "")`, and removing it leaves what `relative_path_from` computes.
`Asset#initialize` wraps the String in `Pathname.new`, so `Asset#logical_path` is unchanged, and the Hash key was
already a String.

Checked:

* **Differential:** [`propshaft_diff.rb`](../../bench/upstream/gem_request_census/propshaft_diff.rb)
  (24 spellings; the correctness review ran 31 more) compares keys, key encodings, `Asset#logical_path` and `Asset#path`. Spellings: relative and absolute, trailing
  and doubled slashes, `.`, `./`, `..` inside and at the end, symlinked directories, Pathname and String, ASCII-8BIT
  and ISO-8859-1 paths, non-ASCII names, nested load paths through `dedup`. Output is byte-identical.
* **Suite:** 170 runs, 0 failures. RuboCop clean. The open PRs on `load_path.rb` (rails/propshaft#277,
  rails/propshaft#280) merge cleanly with it.
* **The one difference** (the correctness review found it, reproduced here): a filename with bytes that are
  invalid in UTF-8 made `relative_path_from` raise `ArgumentError`, so the whole asset map failed and every
  lookup raised. The branch builds the map; that one asset fails later, when it is digested. It is more
  lenient, not less, and the draft names it.

**Per call** (`assets_by_path` over Mastodon's `app/javascript/images` and `material-icons`, 422 assets;
[`setup_propshaft.rb`](../../bench/upstream/gem_request_census/setup_propshaft.rb) with `ir.sh`, N = 20):

| | Base (A/A) | Branch | Change |
| --- | ---: | ---: | ---: |
| Ir, 4.0.7 interpreter | 99.47 / 99.47 M | 12.61 M | −87% |
| Ir, 4.0.7 YJIT | 95.67 / 92.69 M | 10.41 M | −89% |
| Ir, 4.0.9 interpreter | 99.46 / 99.46 M | 12.62 M | −87% |
| Ir, 4.0.9 YJIT | 94.26 / 94.24 M | 10.64 M | −89% |
| Ir, master interpreter | 47.14 / 47.14 M | 9.49 M | −80% |
| Ir, master ZJIT | 33.92 / 33.94 M | 7.36 M | −78% |
| CPU, 4.0.9 interpreter (best of 7) | 15.0 / 14.5 ms | 1.9 ms | |
| CPU, 4.0.9 YJIT | 14.0 / 14.3 ms | 1.6 ms | |
| Objects | 74,015 / 74,015 | 9,970 | |

**Reviews.** The Thermos pair (correctness and maintainability), run with this thread's model rather than GPT-6.1
Sol, approves. The maintainability review rates it
**L1**: string prefix stripping where a Pathname method was, clear at once, no comment or test needed. The Sol
pair that [DECISIONS](../DECISIONS.md#primary-review) requires before the queue has not run.

**Interlocks.** None with Rails, Ruby or ZJIT. Ruby master's Pathname is already about twice as fast as 4.0's
(47 M vs 99 M Ir here). The change still removes 80% there.

### Draft (rails/propshaft)

> **Compute logical paths without Pathname#relative_path_from**
>
> `LoadPath#assets_by_path` computes each asset's logical path with `file.relative_path_from(path)`, which cleans
> both paths and walks them component by component for every file. Every `file` comes from `path.children`, which
> builds it as `File.join(path, name)`, so this strips `File.join(path, "")` from the front instead. Logical
> paths, keys and `Asset#logical_path` are the same. One difference: a filename that isn't valid UTF-8 used to make
> `relative_path_from` raise and the whole load path fail; now only that asset fails, when it is digested.
>
> | `assets_by_path`, 422 assets | Before | After |
> | --- | ---: | ---: |
> | Ruby 4.0.9 | 99.5 M instructions, 15.0 ms | 12.6 M, 1.9 ms |
> | Ruby 4.0.9, YJIT | 94.3 M, 14.0 ms | 10.6 M, 1.6 ms |
> | Ruby master, ZJIT | 33.9 M | 7.4 M |
> | Objects | 74,015 | 9,970 |
>
> This runs in `assets:precompile`, on every cache sweep in development, and once per process for anything that
> reads the load path in production (inline_svg, for one): 25 ms and 123k objects on Mastodon's first request. I
> found it profiling the boot of open-source Rails apps with
> [Lowrail](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-request-census.md), my research
> project.

## R1: rack-mini-profiler skips its render subscribers when the request is not measured

`MiniProfilerRails.initialize!` subscribes to `render_template.action_view` and `render_partial.action_view` (when
`patch_rails?` is false, the default). Both blocks call `shorten_identifier(payload[:identifier])` first, which
splits the template path on `/` and joins the last two parts. Only then does `render_notification_handler`
check `should_measure?` and return. So every render in every request pays for the split and join, profiled or
not. In production almost no request is profiled. The other four subscribers in the same method check
`should_measure?` first; the branch adds the same line to these two:

```diff
       subscribe("render_partial.action_view") do |name, start, finish, id, payload|
+        next if !should_measure?
+
         render_notification_handler(shorten_identifier(payload[:identifier]), finish, start)
       end
 
       subscribe("render_template.action_view") do |name, start, finish, id, payload|
+        next if !should_measure?
+
         render_notification_handler(shorten_identifier(payload[:identifier]), finish, start)
       end
```

**Where it runs.** Every app with rack-mini-profiler in its production bundle. That is 7 census apps (Chatwoot,
CodeTriage, Discourse, Fizzy, Hackatime, Lobsters, Sure); the census sees the split in Lobsters, Sure and
CodeTriage (below).

**Why it is exact.** When measuring, the handler runs as before. `should_measure?` is evaluated once more; it reads a
thread variable and has no side effect. When not measuring, base computed a String and discarded it.
Checked:

* **Behavior:** `shorten_identifier` is a public module method. An app that overrides it with side effects would
  see fewer calls, the same class as a global redefinition.
* **The one difference** (found by the correctness review and reproduced on Rails 8.1.4): rendering an object of an
  anonymous class with `render renderable:` sends `identifier: nil`, because the identifier is the class name.
  `nil.split` raised `NoMethodError` in every render, so the page failed even when nothing was profiled. Now it
  fails only while profiling. It is more lenient, not less, and the draft names it.
* **CodeTriage differential:** [`rmp_diff.rb`](../../bench/upstream/gem_request_census/rmp_diff.rb) runs every
  workload unprofiled (status and masked body digest), then with `authorization_mode = :allow_all` (the node names
  of each stored timer tree). Base, a second base and the branch give byte-identical output on all 14 rows.
* **Suite:** 302 examples; the same 5 failures on base and branch, all in `snapshots_transporter_spec` (HTTP
  transport, unrelated). RuboCop clean.
* **Open PRs:** none on these subscribers. #667 and #668 merge cleanly; #662 already conflicts with main
  elsewhere, and its `railtie.rb` hunks don't overlap.

**Per call** (one `render_template.action_view` event outside a profiled request, Notifications dispatch included,
in a minimal production Rails app; [`setup_rmp.rb`](../../bench/upstream/gem_request_census/setup_rmp.rb) with
`ir_region.sh`, N = 2,000):

| | Base (A/A) | Branch | Change |
| --- | ---: | ---: | ---: |
| Ir, 4.0.7 interpreter | 33,949 / 33,945 | 25,367 | −25% |
| Ir, 4.0.7 YJIT | 21,544 / 21,770 | 14,119 | −35% |
| Ir, 4.0.9 interpreter | 33,862 / 33,865 | 25,354 | −25% |
| Ir, 4.0.9 YJIT | 21,677 / 21,679 | 14,015 | −35% |
| Ir, master interpreter | 33,571 / 33,580 | 25,752 | −23% |
| Ir, master ZJIT | 21,254 / 21,253 | 14,254 | −33% |
| CPU, 4.0.9 interpreter (best of 7) | 4.07 / 4.02 µs | 2.64 µs | |
| CPU, 4.0.9 YJIT | 2.23 / 2.34 µs | 1.23 µs | |
| Objects | 18 | 7 | |

**In the apps** (label `rmp`: the branch pinned with `CENSUS_GEMS`, compared on the same apps with `p` and `p2`).
Lobsters, Sure, CodeTriage, Hackatime and Chatwoot, 53 workloads:

| rack-mini-profiler, mean per workload | `p` / `p2` (A/A) | `rmp` |
| --- | ---: | ---: |
| Share of CPU, interpreter | 0.434 / 0.432% | 0.320% |
| Share of CPU, YJIT | 0.424 / 0.429% | 0.304% |
| µs per operation, interpreter | 457 / 485 | 250 |
| µs per operation, YJIT | 309 / 310 | 156 |
| Objects per operation | 339 / 339 | 8.7 |

`shorten_identifier` (0.09% interp, 0.12% YJIT, 330 objects per operation on these apps; most of it Sure, whose
pages render hundreds of partials) drops out of the method ranking. What remains is `Rack::MiniProfiler#call` and
`current` per request. Discourse could not be pinned: it requires the gem with `require: false` and calls
`initialize!` itself, the pin drops that option, and the gem raised "initialized twice" at boot.

**Reviews.** The Thermos pair, run with this thread's model rather than GPT-6.1 Sol, approves. The correctness
review checked `patch_rails?` both ways, nested renders, fibers and the double `should_measure?` (the handler keeps
its own guard because it is public and specced directly). **Readability: L0**: it is the line the four neighbouring
subscribers already start with, blank line included. No comment or test is needed; no spec drives these
subscribers, and a test could only assert that a method is not called.

**Interlocks.** None.

### Draft (MiniProfiler/rack-mini-profiler)

> **Skip render subscribers when the request is not being measured**
>
> The `render_template` and `render_partial` subscribers shorten the template identifier (split it on `/` and join
> the last two parts) before `render_notification_handler` checks `should_measure?`. So every render in every
> request allocates that Array and those Strings, even when nothing is being profiled, which in production is almost
> every request. This adds the `next if !should_measure?` that the other four subscribers in `initialize!` already
> start with. One difference: a renderable of an anonymous class (`identifier: nil`) used to raise `NoMethodError`
> in `shorten_identifier` on every render; now that happens only while profiling.
>
> | One render event, not profiled | Before | After |
> | --- | ---: | ---: |
> | Ruby 4.0.9 | 33.9k instructions, 4.0 µs | 25.4k, 2.6 µs |
> | Ruby 4.0.9, YJIT | 21.7k, 2.2 µs | 14.0k, 1.2 µs |
> | Ruby master, ZJIT | 21.3k | 14.3k |
> | Objects | 18 | 7 |
>
> On five open-source apps that ship it in production, the gem's share of request CPU drops from 0.43% to 0.32%
> and its objects per request from 339 to 9 (Sure renders hundreds of partials per page). I found it profiling request CPU in open-source Rails apps with
> [Lowrail](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-request-census.md), my research
> project.

## The boot leads, checked in the gems

### Propshaft: P1

Propshaft's boot cost in [rails-boot](rails-boot.md) (112k Pathnames in Mastodon) is not boot. In this census copy
nothing reads the load path during boot. Mastodon builds it on its first request, through inline_svg's
`PropshaftAssetFinder` (`LoadPath#find`): 25.3 ms of CPU and 122,971 objects for 435 files
([`propshaft_app.rb`](../../bench/upstream/gem_request_census/propshaft_app.rb)). Almost all of it is Pathname
work in `relative_path_from`, which P1 removes.

### ViewComponent: fixed on main the same day; a lead remains

Sure (view_component 4.21.0) spends its boot `CacheDigest` time in `precompute!`. That digests every component at
boot when `eager_load` and `cache_template_loading` are on, which is new in 4.15
([`vc_precompute.rb`](../../bench/upstream/gem_request_census/vc_precompute.rb), 92 components):

| view_component | `precompute!` CPU (three runs) | Objects |
| --- | --- | ---: |
| 4.21.0 (Sure's lock) | 262 / 281 / 257 ms | 460,302 |
| main [`d64933f5`](https://github.com/ViewComponent/view_component/commit/d64933f5b70ded164237c79585f7724326e9a0a6) | 161 / 170 / 160 ms | 242,839 |

ViewComponent/view_component#2769 (erikaxel, "share templates and parsed sources within a cache digest
computation", merged 2026-11-03) did that; nothing to build on top of it. What remains on main is Prism parsing
(22% of the time, one parse per distinct source) and file access that repeats per ancestor
([`vc_repeats.rb`](../../bench/upstream/gem_request_census/vc_repeats.rb)):

* `Dir.[]` runs 740 times for 192 distinct patterns; Lookbook's `BaseComponent` sidecar glob alone runs 70 times.
* `IO.binread` runs 517 times for 128 files, and `File.read` 417 times for 185.
* All of it comes from `Resolver#template_sources`, which globs sidecar files for every ancestor of every
  component.

Memoizing per ancestor within one `memoizing` block would remove them, worth at most about 30 ms of Sure's 4.3 s
boot (≤ 0.7%). Sure and Redprints lock view_component, and the file changed six times this week. **Lead**, not
built.

### Devise: the second route draw, 4 apps, no exact fix in Devise

Devise's `before_eager_load` calls `app.reload_routes!` when `Devise.reload_routes` is true, the default.
`RoutesReloader#reload!` restores the previous load state (`nil`), so Rails' `set_routes_reloader_hook` draws
again. Measured with [`boot_route_draws.rb`](../../bench/upstream/gem_request_census/boot_route_draws.rb):

| App (routes) | Boot CPU | Devise's draw | Rails' draw (the second) |
| --- | ---: | ---: | ---: |
| CASA (325) | 4,192 ms | 81.8 ms | 45.6 ms (1.1%) |
| Chatwoot (867) | 3,715 ms | 151.5 ms | 148.8 ms (4.0%) |
| CodeTriage (80) | 1,566 ms | 111.0 ms | 10.9 ms (0.7%) |
| PingCRM (40) | 1,058 ms | 141.6 ms | 7.3 ms (0.7%) |
| Mastodon (829), `reload_routes = false` | 3,832 ms | – | 555.4 ms (one draw) |

The first draw is the larger one: it autoloads the models and controllers that `routes.rb` names. Docuseal also
sets `reload_routes = false`. Inside Devise there is no exact fix:

* **Calling the reloader's `execute_unless_loaded` instead** would run `after_routes_loaded` before eager load.
  It would also mark the routes loaded, so routes that initializers prepend or append after `before_eager_load`
  are only kept because rails/rails#53522 handles prepends on loaded routes. heartcombo/devise#5716 shows how
  fragile that ordering is.
* **Skipping the draw** is what `reload_routes = false` already does. heartcombo/devise#5400 and #5716 show apps
  that need it either way.

**Lead:** Devise could document that most apps can set `reload_routes = false`. A Rails change that keeps the
reloader's state after an early `reload_routes!` belongs to rails/rails, not to a gem.

## Rejected and leads

* **globalid `URI::GID.build`** (10 apps, 0.08%; 9.8 µs and 37 objects per call). The objects are spread over URI's
  generic `build` and component checks and globalid's own split of the path it just built (`check_path` →
  `set_model_components`). Skipping that re-parse would skip the validation it performs. Rejected.
* **useragent** (7 apps, 0.37% / 0.45%): `UserAgent.parse` runs once per request under Rails' `allow_browser`.
  `Version#initialize` uses `=~` where `match?` would do, and `parse` slices the string twice per token. The gem
  has had no push since 2024-12, and nine PRs opened since July are unanswered (including gshutler/useragent#73).
  **Lead for Rails:** cache the allow/deny decision per User-Agent string in `AllowBrowser::BrowserBlocker`.
* **concurrent-ruby `MutexAtomicFixnum`** (20 apps, 0.12%): the portable fallback takes the mutex on every read by
  design, and reading without it changes the memory model the gem promises. The caller is Active Record's
  `@query_cache_version`, read on every cached query. **Lead for Rails.**
* **concurrent-ruby `Map`** (20 apps, 0.8% together): on CRuby, `Map#[]` is two Ruby frames over `Hash#[]`; the
  share is how often Rails' caches call it.
* **rack:** query parsing is covered by rack/rack#2519 (approved), request scheme and forwarded headers by
  rack/rack#2520, ETag digests by rack/rack#2522. The remaining decode/encode copies are ruby/uri's
  `_decode_uri_component` (`str.b.gsub`, two copies even with nothing to decode). ruby/uri is parked
  ([DECISIONS](../DECISIONS.md)).
* **sqlite3** `Statement#each`/`#initialize`: `step` and `prepare` in C; statement reuse is Active Record's.
* **pg** `get_result`, **redis-client** `BufferedIO`: waiting on the server and the socket.
* **sentry-ruby, inertia_rails, mail, lograge:** spread over many methods; no method above 0.1% of CPU in 5 or more
  apps except Inertia's SSR request, which is the SSR server's time.

## Process notes

* **Concurrent runs:** a first profiler run measured each copy in both modes at once. Writes in one mode broke the
  other's state (Campfire, Writebook, Fizzy, Lobsters and Docuseal failed). `run.rb` now runs one copy's modes in
  sequence; every label was rerun from scratch.
* **Default gems:** a second run attributed Ruby's default gems (uri, securerandom) to themselves. uri came out
  at 1.7% of CPU in 18 apps, mostly decoding called from rack and Rails. `prof.rb` now folds default gems into their
  caller, as `rank --gem all` does, and both labels were rerun.
* **Shared copies:** no probe ran in a copy while the census measured it, except a Devise boot probe in Chatwoot
  during the first (discarded) run.
