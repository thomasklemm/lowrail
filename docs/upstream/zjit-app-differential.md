# ZJIT differential on the census apps' own test suites (bet Z11)

Each census app's own test suite run twice on the same Ruby master build: once on the interpreter, once with
`--zjit --zjit-call-threshold=1`. Outcomes compared per test (and, for failing RSpec examples, per
exception class). Each difference was rerun alone in both modes, and at the default threshold.

**Result: no ZJIT divergence in 11 apps, 55,435 tests.** Two per-test differences showed up, and both are
test-environment artifacts: a 1-second wall-clock deadline in Campfire that a threshold-1 child process
sometimes misses (passes on a full rerun), and a Postgres-sequence dependence in two Discourse specs that
reproduces identically on the interpreter. No crash and no `[BUG]` in any run.
Nothing to file.

## Setup

* Ruby master `9aa0898240`, built here `--enable-yjit --enable-zjit` (release). Same binary for both modes;
  the mode is only `RUBYOPT`.
* Rails main `c042aee23a` through F1's master overlays (`fixtures/corpus/frontier-master/`, from F1 orb
  [T-01a19e58](https://ampcode.com/threads/T-01a19e58-1fef-7536-8634-062b91d84bd0)), each app in its own
  census copy. F1's overlays and `script/census --ruby-overlays` are not part of this commit.
* Services: PostgreSQL 15 (pgvector 0.8.1, pg_partman), Redis, memcached. Each app uses its own `z11_*`
  database and Redis DB number, never the census databases.
* `PARALLEL_WORKERS=1`, `TZ=UTC`, `CI=1`, fixed seed (`--seed 41231` for Minitest, `--order defined`
  for RSpec). Browser system specs are excluded everywhere (no browser driver).
* Native libraries for the apps: libvips 8.14, liblept5, libidn, and a no-op pdfium stub.

### Workarounds (applied identically in both modes)

These are Rails-main or environment incompatibilities in the apps, not ZJIT effects:

* **rspec-rails 8.0.x** writes into `default_url_options`, which Rails main now freezes
  (`FrozenError` in every feature and mailer example group). A small override of the two `included` blocks
  is required after `rspec/rails` in Lobsters, Mastodon, Discourse and CASA.
* **Sure**: `minitest-mock` added to the Gemfile (Minitest 6 split `Minitest::Mock` out).
* **Discourse**: the libvips ≥ 8.18 boot check is skipped by an env var; image-processing specs fail in
  both modes.
* **Fizzy**: `CI_PROGRESS_BAR=0`. **CodeTriage**: `bundle exec rails test` with explicit test dirs.

## Results

| App | Suite | Tests | Failing in both | Differ |
| --- | --- | ---: | ---: | ---: |
| Sure | Minitest | 14,236 runs | 15 F, 25 E | 0 |
| Mastodon | RSpec, no system specs | 7,748 | 283 | 0 (exception classes identical) |
| Loomio | Minitest | 3,660 | 1 F, 2 E | 0 |
| CASA | RSpec, no system specs | 2,992 | 224 (mostly the rspec-rails `FrozenError`) | 0 |
| Fizzy | Minitest | 1,787 | 5 F, 4 E | 0 |
| Lobsters | RSpec | 927 | 3 | 0 (exception classes identical) |
| Hackatime | Minitest | 794 | 0 | 0 |
| Campfire | Minitest | 634 | 0 | 0 on a full rerun; 1 flake (below) |
| Writebook | Minitest | 310 | 4 F, 1 E | 0 |
| CodeTriage | Minitest | 219 | 3 E | 0 |
| Discourse | RSpec: models, lib, serializers, services, jobs | 22,128 | 244 (libvips worker, multisite DB, Rails-main `FrozenError`) | 0 after the sequence check (below); 1 in the raw run |

Minitest outcomes were parsed from `-v` output, pairing each `Class#test_name =` line with its result
marker (some apps log between the two). RSpec outcomes come from the JSON formatter, keyed by example id.

### Campfire: timing flake, not a divergence

`SqliteWalCheckpointTest#test_tick_reports_busy_…` failed once in the first full threshold-1 run
("condition not met within 1s"). The test spawns `RbConfig.ruby -e …` as a lock holder and waits 1 s for its
ready file; the child inherits `RUBYOPT`, so at threshold 1 it compiles everything it runs during startup.
Alone it failed 2 of 3 runs at threshold 1, passed 2 of 2 at the default threshold and 3 of 3 on the
interpreter; a second full threshold-1 run passed it. The extra startup time of a threshold-1 child is
expected; the assertion is a wall-clock deadline.

### Discourse: upload-ID sequence, not a divergence

`spec/lib/discourse_spec.rb:785` (`clear_all_theme_cache!` invalidates theme CSS caches) passed in the
interpreter run and failed in the threshold-1 run (`…/original/2X/a/<sha>.png` expected, `…/1X/<sha>.png`
got); `shrink_uploaded_image_spec.rb:71` failed in both, with a different exception. Discourse derives the
upload path depth from the upload id (`FileStore::BaseStore#get_depth_for`, `1X` below id 1000, `2X/<h>` above),
and transactional fixtures do not roll back sequences: the interpreter run moved `uploads_id_seq` past 1000
before the threshold-1 run started. Run alone with the sequence set to 100, both modes pass the first spec and
fail the second with "expected false" (the interpreter run's result); with the sequence at 1000, both modes
fail both, as in the threshold-1 run.

## Gaps

* **Docuseal, Lago**: `bullet` 8.1.x raises "Bullet does not support active_record 8.2.0.alpha yet" at
  boot. Lago additionally needs `awesome_print`, which calls the removed
  `ActiveSupport::LogSubscriber.colorize_logging`. Docuseal's suite is also half browser system specs. Not run.
* **Chatwoot**: commonmarker does not build against master (F1 gap). **Flow**: temporalio caps Ruby
  below 4.1 (F1 gap).

## Notes

* Threshold 1 cost is lost in database time: Loomio 509 s vs 507 s on the interpreter, Campfire 44 s vs 49 s.
* Compared with Z2 (Rails' own suites at threshold 1, no new divergence), this adds the apps' gem and
  pattern mix (Devise, Sidekiq, Hotwire, Active Storage, factory_bot, Mocha, WebMock and many more). Master is clean on all of it apart from the two bugs
  already known from Z4 (Shopify/ruby#976, fixed by open ruby/ruby#18960; the Ractor-owned-set abort), neither
  of which any app suite hit.
