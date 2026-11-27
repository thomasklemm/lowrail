# Rails-main boot check 2026-11-27

Rails main [`088fc0cf61`](https://github.com/rails/rails/commit/088fc0cf61e4ba0c7987decafacc69adb3e22eec) against v8.1.4.1 [`3f290b759c`](https://github.com/rails/rails/commit/3f290b759c8e2ffe7c257951b1255740751355e4), ruby 4.0.9, 20 census apps, 4 minutes. Previous run: 2026-11-25 (main [`f785381cca`](https://github.com/rails/rails/commit/f785381cca8621772cba659ff93f825eb7f99942)). Made by `script/rails-main-boot` ([how it works](rails-main-boot.md)); raw data in [`bench/upstream/rails-main-boot/2026-11-27/`](../../bench/upstream/rails-main-boot/2026-11-27/).

## New breaks

None.

Breaks already in the previous run: none.
Fixed since the previous run: discourse: `eager_load | LoadError | cannot load such file -- active_job`.

## Per app

| App | bundle | boot | eager_load | runner | Notes |
|---|---|---|---|---|---|
| blog | ok | ok | ok | ok |  |
| campfire | ok | fails on 8.1 only | not reached on 8.1, main ok | not reached on 8.1, main ok | 8.1 boot: `RuntimeError: Unknown version "8.2"` |
| casa | ok | ok | ok | ok |  |
| chatwoot | ok | ok | ok | ok |  |
| codetriage | ok | ok | ok | ok |  |
| discourse | ok | ok | ok | ok |  |
| docuseal | ok | ok | fails on both | skipped | 8.1 eager_load: `RuntimeError: Could not load libpdfium library. Make sure it's installed and in your library path. Error: Could not open library 'libpdfium.so': libpdfium.so: c`; main eager_load: `RuntimeError: Could not load libpdfium library. Make sure it's installed and in your library path. Error: Could not open library 'libpdfium.so': libpdfium.so: c` |
| fizzy | ok | fails on 8.1 only | not reached on 8.1, main ok | not reached on 8.1, main ok | 8.1 boot: `NameError: undefined method 'call' for class 'Hash'` |
| flow | fails on 8.1 only | not reached on 8.1, main ok | not reached on 8.1, main ok | not reached on 8.1, main ok | 8.1 bundle: `Bundler: Could not find compatible versions \| Because every version of rails depends on activestorage = 8.1.4.1 \|   and every version of activestorage depends` |
| hackatime | ok | ok | ok | ok |  |
| lago | ok | ok | ok | ok |  |
| lobsters | ok | ok | ok | ok |  |
| loomio | ok | ok | ok | ok |  |
| mastodon | ok | ok | ok | ok |  |
| pingcrm | ok | ok | ok | ok |  |
| react-starter-kit | ok | ok | ok | ok |  |
| redprints-cfp | ok | ok | ok | ok |  |
| sure | ok | ok | ok | ok |  |
| thinkroom | ok | ok | ok | ok |  |
| writebook | ok | ok | ok | ok |  |

## Notes (checked by hand)

* Off-schedule run for the 8.2 pre-beta round, on the warm copies (263 seconds, every app rebundled for the new head).
  All 20 probes loaded railties from `rails-088fc0cf61e4`.
* Discourse eager-loads again on main: AM3 merged on 2026-11-26.
* The range since `f785381cca` includes the inlined connection_pool (de40846d6a; blog's main lock no longer lists the
  `connection_pool` gem), the class_attribute code generator (50bdd8d1db) and the bounded quoted-name caches
  (8aca40de20, b2075077f7). None of them breaks bundle, production boot, eager load or `rails runner` in any census
  app. Per-request, job and test-suite behavior is not covered by this check.
* Unchanged: campfire, fizzy and flow cannot run on 8.1 and pass every check on main, as on the previous main;
  docuseal fails eager load on both trees (Docuseal's musl-only pdfium build).
