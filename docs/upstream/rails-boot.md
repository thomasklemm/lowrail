# Rails boot and eager-load cost (bet B1)

Every Rails measurement so far was a warm request. This round measures **boot to first request** in production with
`eager_load`, on the five largest census apps (Discourse, Mastodon, Chatwoot, Sure, Lobsters). It covers
instructions, allocations by site and a stackprof breakdown by boot phase. It adds a Ruby master pass in the
interpreter and under ZJIT, and a development-mode reload pass. Each cost is assigned to Rails, a gem or the VM.

**Result.** Boot costs 2.7–4.0 s of CPU and 2.5–4.3 M objects in the interpreter on Ruby 4.0.7. Rails-owned
frames are **12–31% of boot self time**. They are spread over route drawing, association and callback
definition, generated methods and `action_methods`; no single Rails frame takes more than 1.6% of boot on average.
Most of boot is elsewhere:

* ISeq loading and compiling (`require`, Bootsnap) takes 27–31%.
* GC takes 14–24%.
* On Lobsters, Faker's 6 MB of locale YAML takes 26%.
* `tzinfo-data` takes 5–7% on Lobsters and Sure.

The largest Rails-adjacent cost is a **VM** cost: each url helper `define_method` invalidates the method caches of
every class that already includes the helpers module. It is 5.5% of Mastodon's boot and 2× cheaper on Ruby master.
Running a JIT from process start costs boot time:

* On Ruby 4.0.7, `--yjit` adds 11–44%.
* On Ruby master, `--zjit` adds 47% on Lobsters: 1,977 ISEQs and 1.6–1.7 s of compile before the first request,
  and +68% Callgrind Ir.
* Rails' `config.zjit` (#59183) avoids that cost: boot is the same as the interpreter. The first request still
  compiles 665 ISEQs in 0.45 s.

**One exact candidate**, development only. Nothing for production boot cleared the bar with an exact change.

| # | Branch | Commit | Per call (interp / YJIT / master ZJIT) | Effect |
| --- | --- | --- | --- | --- |
| B1-1 | [`thomasklemm/route-source-location-dir`](https://github.com/thomasklemm/rails/tree/thomasklemm/route-source-location-dir) | [`a9c03b098e`](https://github.com/thomasklemm/rails/commit/a9c03b098e76861d8b9d4d2ed51a27fbd95570b2) | 4.4 → 1.9 µs / 3.8 → 1.7 µs / 2.7 → 1.5 µs | dev route redraw −5% (Lobsters, Mastodon) |

## Pins and method

* **Rails:** canonical `rails/rails` main
  [`231bc7ed65`](https://github.com/rails/rails/commit/231bc7ed6503b0ae6e8ae239dd171b421dec0301) (merge of #59579),
  checked with `git ls-remote` on 2026-11-03. The candidate is one commit on it.
* **Ruby:** 4.0.7 (mise), interpreter and `--yjit`. Ruby master
  [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb), built here with
  `--enable-zjit --enable-yjit` (release build, GCC 12, Rust 1.99.1), interpreter and `--zjit`.
* **Apps:** fresh census copies made with `script/census setup --rails 231bc7ed65… --corpus censusboot`, with the
  [PG census](pg-census.md) and [Inertia/Chatwoot census](inertia-chatwoot-census.md) overlays and seeds. PostgreSQL
  15 with pgvector 0.8.1, built from source here, and Redis run as disposable orb services. Production
  environment, `eager_load` as each app configures it (true in all five).
* **Boot to first request:** [`bench/upstream/boot/probe.rb`](../../bench/upstream/boot/probe.rb), driven by
  [`run.rb`](../../bench/upstream/boot/run.rb).
  * Boot is the census harness's `RailsCensus.boot`: `config/application`, then `config/environment`, with
    census logging and queue controls.
  * The first request is one anonymous GET through census 4's Rack::Test client:
    * Lobsters: `/`;
    * Discourse: `/latest.json`, because the crawler HTML page needs the vips worker;
    * Mastodon: `/about`;
    * Sure: `/sessions/new`;
    * Chatwoot: `/app/login`.
  * One untimed boot runs first, so Bootsnap's caches are warm in all four apps that use it.
  * Timing uses process CPU clocks (`CLOCK_PROCESS_CPUTIME_ID`), from process start to booted and from booted to
    first response.
* **Passes per app and Ruby:**
  * plain: interpreter ×5, YJIT ×3;
  * stackprof wall profile at 250 µs with raw stacks (the `cpu` kind): ×3;
  * stackprof object mode (every allocation): ×1;
  * Callgrind Ir: ×2, the A/A.
* **Phases** ([`analyze.rb`](../../bench/upstream/boot/analyze.rb) `phases`): a sample belongs to the innermost
  phase marker on its stack.
  * `Bundler.setup`, `Bundler.require`;
  * `Initializer#run` (other initializers), `load_config_initializer`;
  * framework `*.eager_load!`, Zeitwerk `eager_load`;
  * `RouteSet#draw` / `RoutesReloader#load_paths`, `RouteSet#eager_load!` (route set compile);
  * `load_schema!`, `I18n` `load_translations`, `Template#compile!`;
  * GC.

  "Other" is what runs outside any marker: `config/application.rb`'s own requires, Railtie bodies and the probe.
  Owners (`owners`) assign self time to the nearest Ruby frame's gem. The exception is loading code: `require`,
  ISeq load, `eval`/`class_eval` count as `vm:require+compile`.
* **Receipts:** [data/rails-boot](data/rails-boot):
  * phase, owner and Rails-frame tables;
  * allocation sites per app;
  * reload phases.

  The raw profiles (1.1–1.8 GB per object-mode profile) stay in `.lowrail/private/boot` and are not committed.

## Boot to first request

Medians, process CPU. Callgrind Ir is the interpreter, boot plus first request, two runs.

| App | Boot, interp (range, n=5) | Boot, YJIT (n=3) | First request, interp | Objects at boot | GC at boot | Callgrind Ir (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Lobsters | 3,397 ms (3,382–3,573) | 3,781 ms (+11%) | 77 ms | 2.54 M | 28 GCs, 308 ms | 18.742 G (0.005%) |
| Discourse | 2,671 ms (2,628–2,748) | 3,853 ms (+44%) | 816 ms¹ | 2.57 M | 28, 520 ms | 17.446 G (0.017%) |
| Mastodon | 3,204 ms (3,102–3,284) | 4,494 ms (+40%) | 74 ms | 2.49 M | 30, 570 ms | 14.220 G (0.003%) |
| Sure | 4,024 ms (3,759–4,071) | 5,670 ms (+41%) | 76 ms | 4.27 M | 31, 859 ms | 18.954 G (0.012%) |
| Chatwoot | 3,738 ms (3,620–3,889) | 4,956 ms (+33%) | 49 ms | 3.29 M | 32, 747 ms | 16.564 G (0.0007%) |

¹ Discourse's first request starts its `Scheduler::Defer` thread, which spends 640 ms of CPU setting up site
settings and the job queue. The request thread itself uses 159 ms, measured with `/proc/self/task` and
`CLOCK_THREAD_CPUTIME_ID`.

On Ruby 4.0.7, YJIT here runs from process start (`--yjit`), so it compiles boot code. The 11–44% is that compile
time. YJIT is in maintenance mode, so this was not analyzed further.

### Phases (4.0.7 interpreter, % of sampled wall time per run)

| Phase | Lobsters | Discourse | Mastodon | Sure | Chatwoot |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Bundler.setup` | 3.6 | 3.8 | 3.5 | 2.2 | 2.7 |
| `Bundler.require` | 9.6 | 6.7 | 17.0 | 14.5 | 19.0 |
| config/initializers | 5.1 | 2.4 | 0.8 | 0.3 | 0.3 |
| other initializers | 3.0 | 13.7 | 5.0 | 15.7 | 3.7 |
| framework `eager_load!` | 11.3 | 4.9 | 6.6 | 7.4 | 6.4 |
| Zeitwerk eager load (app code) | 9.5 | 22.1 | 20.2 | 20.5 | 22.6 |
| i18n load | **25.7** | 0 | 3.3 | 4.6 | 2.0 |
| routes draw | 1.3 | 5.8 | **10.5** | 3.3 | **9.2** |
| route set compile | 0.7 | 4.7 | 1.9 | 1.5 | 2.0 |
| schema load (boot + first request) | 0.6 | 2.2 | 1.3 | 0 | 0.4 |
| template compile (first request) | 0.1 | 0 | 0.5 | 0.1 | 0 |
| GC | 14.3 | 19.5 | 21.8 | 22.8 | 23.8 |
| other boot | 12.6 | 8.9 | 5.9 | 5.9 | 6.5 |
| first request, rest | 2.7 | 5.2 | 1.8 | 1.1 | 1.5 |

Zeitwerk's eager load and `Bundler.require` are mostly ISeq loading of app and gem code. Across all phases, self time
by owner is:

* `vm:require+compile`: 27–31% (Bootsnap ISeq load included);
* GC: 14–24%;
* Rails: 12.2% (Lobsters), 17.4% (Sure), 24.8% (Chatwoot), 26.9% (Mastodon), 29.9% (Discourse);
* psych: 25.6% on Lobsters;
* tzinfo: 6.5% on Lobsters, 4.6% on Sure, under 1% elsewhere;
* Bootsnap's own Ruby: 1–4%.

Template compile is not a boot cost. Templates are eager loaded but compiled at first render, 1–16 ms per app.

### Rails-owned costs, by apps reached

Inclusive (total) time, % of boot per app, from
[rails-frames-407.txt](data/rails-boot/rails-frames-407.txt). "Self" is the nearest Rails frame plus the C function
it called.

| Rails cost | Apps ≥ 0.5% | Lob / Disc / Mast / Sure / Chat (%) | What it is |
| --- | ---: | --- | --- |
| Routes draw (`RouteSet#draw`) | 5 | 1.3 / 5.7 / 10.4 / 3.3 / 9.1 | Mapper and Journey parsing, plus `define_url_helper`'s `define_method`: self 0.1 / 0.6 / **5.5** / 0.6 / 1.3. The method itself is cheap; the VM invalidates the method caches of every class that already includes the helpers (below). Chatwoot draws twice (Devise, below). |
| Association builders (`Builder::Association.build`) | 5 | 2.0 / 6.9 / 4.0 / 5.2 / 5.1 | reflections, callbacks (`set_callback` 1.8% mean), `define_non_cyclic_method`'s `class_eval` (self 1.0% mean, 4 apps) |
| Route set compile (`RouteSet#eager_load!`) | 5 | 0.7 / 4.7 / 1.9 / 1.5 / 2.0 | Journey GTG transition table, anchored regexps, missing-keys regexps |
| `ActiveSupport::Concern#append_features` | 5 | 3.8 / 3.2 / 8.0 / 4.2 / 8.8 | inclusive of the included modules' bodies; self 0.1% |
| `AbstractController.eager_load!` (`action_methods`) | 4 | 0.6 / 1.1 / 2.7 / 0.9 / 3.2 | `public_instance_methods(true)` per controller and its abstract base; already reworked by [#59464](https://github.com/rails/rails/pull/59464) (merged 2026-10-31, in the pin) |
| Generated methods (`CodeGenerator#apply`, `Delegation.generate` `module_eval`) | 5 | 0.7 + 0.7 / 1.9 + 0.7 / 0.7 + 0.9 / 0.8 + 0.6 / 0.7 + 0.7 | attribute and delegate methods, parsing their source |
| `class_attribute` (`class_eval`) | 4 | 0.5 / 0.5 / 1.1 / 0.5 / 0.7 | |
| I18n `eager_load!` | 3 | 25.7 / 0 / 3.3 / 4.6 / 2.0 | Rails triggers it; the time is psych parsing gem/app YAML (Lobsters: Faker's 317 files, 6.1 MB, in the production bundle) |
| `TZInfo.eager_load!` | 2 | 6.5 / 0.7 / 0.7 / 4.6 / 0.6 | deliberate ([7ae4a5f3b5](https://github.com/rails/rails/commit/7ae4a5f3b5), byroot: done at boot so the data is shared by copy-on-write); expensive with `tzinfo-data`'s Ruby data source |
| Schema load (`load_schema!`, columns) | 3 | 0.6 / 2.2 / 1.3 / 0 / 0.4 | first use, mostly in the first request |

Allocations by site ([sites-*.txt](data/rails-boot)):

* Bootsnap's ISeq and YAML loads are the largest owner: 18.7–28.4% of boot objects in four apps.
* Action Pack is 4.1% (Lobsters), 7.4% (Sure), 11.7% (Mastodon), 14.9% (Chatwoot) and 17.8% (Discourse), mostly
  Journey parsing and the GTG builder, each site ≤ 0.9%.
* Active Support is 9.7–16.8%. Its largest site is `Inflector#camelize`, 1.4–3.6% of boot objects, called by
  Zeitwerk's inflector once per file and, in Discourse, by its memoizing backport.
* Propshaft's `LoadPath#assets_by_path` allocates 112k `Pathname` objects (4.8%) in Mastodon.

### Gems that dominate where Rails doesn't

* **Lobsters:**
  * psych is 25.6%: Faker ships 317 locale files and is loaded in production, and I18n's eager load parses them all.
  * tzinfo is 6.5%, from `tzinfo-data`.
* **Sure:**
  * view_component's `CacheDigest` (Prism parse of components) is 4.7%;
  * `tzinfo-data` is 4.6%;
  * yard is 2.2%;
  * the anthropic and stripe clients are 5.9% of objects each.
* **Chatwoot:**
  * Devise draws the routes a second time (below);
  * stripe is 1.5% of time and 5.8% of objects;
  * mime-types is 0.9%.
* **Mastodon:** Propshaft's `Pathname` work and mime-types are 1.4%.
* **Discourse:** its `SiteSettings` and `freedom_patches` initializers are 13.7% "other initializers", app code.

## Ruby master, interpreter and ZJIT (Lobsters)

Only Lobsters boots on master. It uses the [Ruby 4.1 watch](ruby-4.1-regression-watch.md) overlay: commonmarker
2.10.1 and source builds of ffi, herb, nokogiri, sqlite3 and pg. The other four are blocked by native gems that
don't build against master's headers, and no release fixes them:

* **cbor 0.5.10.3** (the latest, a webauthn dependency) blocks Discourse, Mastodon and Sure. It uses
  `Data_Get_Struct`/`Data_Wrap_Struct`, and untyped `RData` was removed with Feature #21768.
* **Chatwoot's vendored commonmarker 0.23.12** fails the same way (`RTypedData` has no `dfree`, plus
  `Data_Get_Struct`). Chatwoot also needs an explicit `io-wait` gem on master.

The copies are `.corpus/censusm-*`; their Gemfile edits are local and not overlays.

| Lobsters, Ruby master | Boot CPU (n=5) | First request | Objects at boot | Callgrind Ir (A/A) |
| --- | ---: | ---: | ---: | ---: |
| interpreter | 2,683 ms (2,581–2,720) | 68 ms | 2.51 M | 16.076 / 15.992 G (0.52%) |
| `--zjit` from process start | 3,940 ms (3,898–4,078), **+47%** | 523 ms (482–535) | 2.51 M | 27.008 / 27.016 G (0.03%), **+68%** |
| ZJIT by `config.zjit` (enabled in the `enable_zjit` finisher) | 2,501 ms (2,441–2,618), same as the interpreter | 481 ms (472–502) | 2.51 M | |

The phase shares on master match 4.0.7: i18n 26.2%, GC 14.2%, `vm:require+compile` 30.1%, Rails 12.2%. The
interpreter boot is 21% shorter than mise's 4.0.7, but there is no same-toolchain A/A between the two pins. The
regression watch found mise's prebuilt 4.0.7 1% slower than a GCC 12 build, so the gap is not attributed.

**ZJIT counters** (`--zjit-stats-quiet`, a separate process, two runs; the stats build costs about 1.5 s of boot on
its own):

| `--zjit` from start | after boot | after first request | after 200 requests |
| --- | ---: | ---: | ---: |
| compiled ISEQs | 1,977 / 1,977 | 2,987 / 2,605 | 4,251 / 3,913 |
| compile time | 1.63 / 1.71 s | 2.51 / 2.24 s | 3.75 / 3.60 s |
| code region | 11.7 MB | 17.2 / 14.7 MB | 25.6 / 23.0 MB |
| side exits | 19.9k | 21.8k / 20.9k | 76.0k / 75.0k |
| failed ISEQs | 0 | 0 | 0 |
| invalidation time | 17 ms | 17 ms | 17 ms |

With `config.zjit` ([#59183](https://github.com/rails/rails/pull/59183)), ZJIT starts after boot:

* **Boot:** 0 ISEQs compiled.
* **First request:** 665 ISEQs, 0.43–0.45 s of compile time (both runs).
* **After 200 requests:** 1,971–2,427 ISEQs and 1.5–2.1 s of compile time.
* **Requests 2–200:** a mean of 25.7–29.6 ms, against 29.0–29.6 ms when ZJIT runs from the start.

So `config.zjit` removes ZJIT's boot cost (+1.26 s, +47%) with no visible loss later. The first request costs
about 0.45 s of compile either way, against 68 ms in the interpreter. That is where a ZJIT warmup or a
compile-threshold choice would matter for deploys. It is Ruby/ZJIT territory, not a Rails change.

Stackprof under ZJIT can't separate compile time from the frames being compiled. Rails' share of samples rises from
12% to 24% under `--zjit`, so the counters, not stackprof, are the measure.

## Development-mode reload pass (Lobsters, Mastodon)

The pass uses [`reload.rb`](../../bench/upstream/boot/reload.rb), in development on the same copies:

1. Boot and warm one page.
2. Append a comment line to one model (Lobsters `app/models/story.rb`, Mastodon `app/models/account.rb`).
3. Wait until a reloader reports `updated?`, then time the next request.
4. Repeat 3 times; profile the third reload.

| App (file watcher) | Warm request | Request after a change | Request after that | Objects in the reload request |
| --- | ---: | ---: | ---: | ---: |
| Lobsters (evented, listen) | 4.7–6.6 ms | 121 / 142 / 240 ms | 5.5–7.7 ms | 129–135k |
| Mastodon (polling `FileUpdateChecker`) | 38–55 ms | 994 / 804 / 1,595 ms | 85–136 ms | 391–405k |

Where the reload request goes ([reload-phases.txt](data/rails-boot/reload-phases.txt)):

| Share of the reload request | Lobsters | Mastodon |
| --- | ---: | ---: |
| route redraw | 28% | 42% |
| other work inside the executor | 16% | 19% |
| GC | 18% | 13% |
| autoload | 22% | 12% |
| unload and setup | 5% | 4% |

Routes are redrawn on every reload by design (finisher comment: autoloaded constants may be used in
`routes.rb`). Inside Mastodon's 498 ms redraw:

* `define_url_helper` `define_method`: 75 ms. The stale controller classes from before the unload are still in the
  helpers module's subclass list until GC.
* `NamedRouteCollection#clear!` `remove_method`: 17 ms.
* `route_source_location`: 34 ms, of which 11 ms is `File.expand_path`. That is B1-1.

Every warm Mastodon request also spends 9.0 of its 44–48 ms in the reloaders' `updated?`:

* the autoload paths: 1,298 files, 4.3 ms;
* i18n: 530 files, 2.1 ms;
* views: 536 files, 1.9 ms.

That cost is polling `stat`s, which the evented checker (the `listen` gem) avoids. It is app configuration.

## B1-1: compute the Action Dispatch directory once for route source locations

In development (`route_source_locations` is `Rails.env.development?`), `Mapping#route_source_location` runs once
per route on every draw and expanded `File.expand_path("..", __dir__)` each time. The branch computes it once, as a
frozen constant on `Mapping`, next to its other constants.

```diff
       class Mapping # :nodoc:
         ANCHOR_CHARACTERS_REGEX = %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
         OPTIONAL_FORMAT_REGEX = %r{(?:\(\.:format\)+|\.:format|/)\Z}
+        ACTION_DISPATCH_DIR = File.expand_path("..", __dir__).freeze
...
           def route_source_location
             if Mapper.route_source_locations
-              action_dispatch_dir = File.expand_path("..", __dir__)
               Thread.each_caller_location do |location|
-                next if location.path.start_with?(action_dispatch_dir)
+                next if location.path.start_with?(ACTION_DISPATCH_DIR)
```

**Exactness** ([DECISIONS checklist](../DECISIONS.md), 3444d56):

* **Items 1–7:** no user-supplied object is involved. The argument is a String the method builds, and
  `String#start_with?` on a frame path calls nothing new.
* **Item 8 (load order and standalone require):** `__dir__` is `File.dirname(File.realpath(__FILE__))`, which is
  absolute and independent of the working directory. So the constant is the same string the method built on every
  call, and a `Dir.chdir` between draws can't change it. `route_source_locations` is still read at call time, as in
  base. Base expanded the directory only when the setting was on; the branch does it once per process at load,
  which costs about 3 µs.
* The constant is frozen, so it is Ractor-shareable.

**Micro:** [`micro_route_source.rb`](../../bench/upstream/boot/micro_route_source.rb). It draws 100 resources (800
routes) with source locations on and calls the method directly. Best of 7 × 5 draws, interleaved base / branch /
base, two rounds.

| | Interp 4.0.7 | YJIT 4.0.7 | Interp master | ZJIT master |
| --- | ---: | ---: | ---: | ---: |
| `route_source_location`, base (A/A runs) | 4.4 / 5.4 / 4.9 / 4.2 µs | 4.0 / 3.8 / 4.1 / 3.6 µs | 2.7 / 3.6 / 2.8 / 2.8 µs | 2.7 / 4.8 / 2.7 / 2.7 µs |
| `route_source_location`, branch | 2.2 / 1.9 µs | 1.6 / 1.7 µs | 1.5 / 1.6 µs | 1.6 / 1.5 µs |
| draw, per route, base (A/A) | 87.5 / 88.5 / 87.1 / 87.0 µs | 37.3 / 40.7 / 36.6 / 37.4 µs | 79.0 / 79.0 / 82.9 / 85.9 µs | 37.0 / 36.2 / 36.3 / 37.1 µs |
| draw, per route, branch | 83.1 / 81.8 µs | 37.6 / 32.7 µs | 76.8 / 73.6 µs | 36.7 / 37.2 µs |

The ZJIT draw is inside its A/A, and nothing regresses under ZJIT.

**In the app:** [`dev_routes.rb`](../../bench/upstream/boot/dev_routes.rb) runs `Rails.application.reload_routes!`
in development, best of 15 CPU timings after 2 warmups. Rounds are interleaved; base and branch are both bundled
from the local Rails checkout.

| | Lobsters (271 routes) | Mastodon (839 routes) |
| --- | ---: | ---: |
| base, 3 rounds | 30.7 / 30.6 / 30.1 ms | 101.2 / 99.2 / 100.2 ms |
| branch, 3 rounds | 29.2 / 29.0 / 28.9 ms | 97.5 / 97.6 / 92.8 ms |

That is −5% (Lobsters) and −4% (Mastodon) per redraw. Route redraw is 28–42% of a reload request, so B1-1 saves
1–2% of a dev reload request.

* **Production:** `route_source_locations` is false, the method returns `nil` before the changed line, and the
  constant costs one `expand_path` at load.
* **Unaffected:** ruby-bench (production) and the allocation census are not affected, so neither was run.

**Checks:** the Action Pack suite with `RAILS_STRICT_WARNINGS=1` ran 4,463 runs, 0 failures, 0 errors; the only
warnings were from Capybara and Dalli. RuboCop is clean. No test was added: behavior is unchanged, and
`inspector_test.rb` and `routing_test.rb` already assert source locations.

**Draft** (rails/rails short form):

> **Compute the Action Dispatch directory once for route source locations**
>
> In development, `Mapping#route_source_location` runs for every route each time the routes are drawn, at boot and
> on every reload. It expanded the same `File.expand_path("..", __dir__)` on each call; this computes it once,
> when the file loads.
>
> `__dir__` is already a real path, so the constant is the string the method built every time. Production doesn't
> call it, since `route_source_locations` is off there.
>
> | `route_source_location`, per call | Before | After |
> | --- | ---: | ---: |
> | Ruby 4.0.7 | 4.4 µs | 1.9 µs |
> | Ruby 4.0.7, YJIT | 3.8 µs | 1.7 µs |
> | Ruby master, ZJIT | 2.7 µs | 1.5 µs |
>
> Redrawing the routes in development gets about 5% faster on Lobsters (271 routes, 30.5 → 29.0 ms) and Mastodon
> (839 routes, 100 → 96 ms).

## Rejected and leads

* **Url helper `define_method` cost (VM lead, not Rails).** Each `define_method` on the helpers module calls
  `rb_clear_method_cache` for every class that includes it. The helpers module is included (through each
  controller's `HelperMethods`) into 17 (Discourse) to 218 (Mastodon) sites before the routes are drawn, because
  `eager_load!` runs before `set_routes_reloader_hook`.
  * **Micro** ([`micro_define_method_iclasses.rb`](../../bench/upstream/boot/micro_define_method_iclasses.rb), 1,000
    methods):

    | Include sites | Ruby 4.0.7 | Ruby master |
    | ---: | ---: | ---: |
    | 0 | 2.6 µs | 1.1 µs |
    | 218 | 20.0 µs | 9.5 µs |

  * **Callgrind:** `clear_method_cache_by_id_in_class` is 31.7% of the micro's Ir on 4.0.7.
  * **Why not in Rails:** drawing routes before eager load would change what `routes.rb` can reference, so it is
    not exact. A Ruby change (cheaper invalidation when a brand-new method name is added) would reach every app,
    but it belongs to the Ruby side.
* **Devise draws the routes twice (lead).** Devise's `before_eager_load` calls `reload_routes!` when
  `Devise.reload_routes` is true, which is the default. `RoutesReloader#reload!` restores the previous load state,
  so `set_routes_reloader_hook` draws again.
  * **Cost:** Chatwoot pays 187 ms, 4.6% of boot.
  * **Other apps:** Mastodon sets `reload_routes = false`; the other three don't use Devise.
  * **Why not exact:** skipping the second draw would change the `after_routes_loaded` ordering, and it would drop
    routes that depend on state set after `before_eager_load`.
* **Slimmer `define_non_cyclic_method` (rejected).** Generating `def name(*) = _non_cyclic(:name, :assoc, :method)`
  instead of the 17-line body is the same work at boot with less code to parse.
  * **Boot saving:** 23–26 → 9.3 µs per association method on 4.0.7, and 18–19 → 7.6–9.0 µs on master. With 233
    (Lobsters) to 970 (Discourse) such methods, that is 3–16 ms, ≤ 0.4% of boot.
  * **Runtime cost:** every autosave and validation callback call gets slower, 201–229 → 248–261 ns
    (interpreter) and 143–161 → 161–174 ns (YJIT), on every `save`.
  * **Why rejected:** a runtime loss for a boot gain. #57888 moved this method to `class_eval` for Ractors, and
    byroot asked there to keep the `@_already_called` Hash for object shapes.
* **Journey regexps rebuilt before deduplication (below the bar).** `requirements_for_missing_keys_check` and
  `offsets` compile a Regexp per route requirement and then dedup it by source.
  * **Discourse:** 1,945 compiles for 47 unique, 7.5 + 8.6 ms, 0.45% of its boot.
  * **The other four apps:** 7–82 compiles, ≤ 0.6 ms.
  * **Verdict:** one app reached.
* **Caching `internal_methods` per abstract controller (not exact).** Modules included into `ActionController::Base`
  after a controller computed its methods would not reach later controllers, because `method_added` doesn't fire for
  `include`. The remaining `action_methods` cost is 0.6–3.2%, and #59464 reworked it two days before the pin.
* **Early exit in `FileUpdateChecker#updated?` (not exact).** `updated?` caches the maximum mtime for `execute`. An
  early exit would cache a lower maximum and trigger an extra reload later. Polling cost is app configuration (use
  `listen`).
* **`TZInfo.eager_load!` and I18n eager load (deliberate).** Both are boot-for-copy-on-write by design. The cost is
  the data sources: `tzinfo-data`, and Faker's locales in a production bundle.

**Overlap check** (`gh search`, 2026-11-03):

* **Open PRs:** nothing on `route_source_location`, boot timing of routes, url helpers or autosave method
  definition. Boot-adjacent open PRs:
  * #59149, number-converter i18n keys on `eager_load!`;
  * #59186, `ractorize!`;
  * #53012, `zeitwerk:check:boot`;
  * #50291 and #58664, which touch `define_non_cyclic_method` for correctness.
* **Recent merges in this area, all in the pin:**
  * #59464, `action_methods`;
  * #58468, `Pattern#method_name` allocations at boot;
  * #59213 and #59217, Prism off boot;
  * #59151, `controller_name`, and #58509, `_prefixes` on `eager_load!`;
  * #58396, eager-load templates;
  * #59468, autoload Arel;
  * #59465, the test runner only when testing;
  * #59408, Capybara and Selenium not required in new apps;
  * #59183, `config.zjit`.

## Limits

* **Boot is single-run CPU time** with a 2–8% run-to-run range. Callgrind is the stable measure (A/A ≤ 0.017% on
  4.0.7), but no candidate changes production boot, so no Callgrind A/B was needed.
* **Ruby master and ZJIT cover Lobsters only;** native gems block the other four apps (above).
* **Stackprof wall samples** include time in C functions, attributed to the calling Ruby frame's owner. Under ZJIT,
  they include compile time.
* **The reload pass** uses one changed file per app and three reloads. Mastodon's reload requests vary 0.8–1.6 s
  with GC timing.
* **Chatwoot was not run in development** (no development database or gems in the census copy). The B1-1 in-app
  numbers use Lobsters and Mastodon.
