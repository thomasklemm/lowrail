# Ruby 4.1 differential against 4.0.9: the heavy apps (2026-11-27)

The heavy slice of [ruby41-differential-409.md](ruby41-differential-409.md). Each app's own suite ran on Ruby 4.0.9 and
on Ruby master, with one lockfile and one Rails version per app on both Rubies. Outcomes were compared per test,
including the exception class. Every difference was then rerun alone 3 times per mode on both Rubies. Nothing was
posted, filed or opened upstream.

**Result.** There are 4 master-only differences that come from Ruby, and none is a JIT effect. Each fails 3 of 3
alone on master in interp, yjit and zjit, and passes 3 of 3 on 4.0.9:

| App | Tests | Cause on master | Verdict |
| --- | ---: | --- | --- |
| Flow | 1 | `Time.iso8601("2026-02-30T00:00:00Z")` keeps Feb 30 (time 0.5.0) | **Regression**, known (Bug #21301), fix in review; the light slice's Finding 2 |
| Sure | 2 | `ENV.stubs` in Mocha raises `Ractor::IsolationError` | Intentional change (Bug #22291) that breaks Mocha; the light slice's Finding 1, MO1 |
| Discourse | 17 | `Symbol#to_s` returns a frozen String, and `PostMover` calls `sub!` on it | Intentional (Feature #22137); app bug, warned on 4.0.9 |
| CASA | 1 | Default gems newer than the lock are activated before `bundler/setup` | Intentional default-gem bumps; app test setup |

The other differences are app flakes under orb load and pass alone on both Rubies. There were no boot failures and
no crashes, `[BUG]` reports or Rust panics. The new warnings on master are deprecations of aliases that Ruby 4.3
will remove. Chatwoot did not run; Lago was compared in interp only, on the first 20,484 tests (below).

## Pins and method

* Ruby master [`f3e180b5eb`](https://github.com/ruby/ruby/commit/f3e180b5ebc835f87c2ff7ccb8474a1bf18b0115) and
  Ruby 4.0.9 (tag `v4.0.9`, `3e93b23afc`). Both were built with `script/ruby-differential build`, using the same
  compiler and flags.
* Modes: `interp`, `yjit` and `interpW` (`-W:deprecated`, for warning lines) on both Rubies, each compared in the
  same mode. Master `zjit` is compared with 4.0.9 `interp` as a diagnostic column. Seed 41231.
* Labels: [`2026-11-27-409-heavy-master-f3e180b5eb`](../../bench/upstream/ruby-differential/runs/2026-11-27-409-heavy-master-f3e180b5eb)
  and [`2026-11-27-409-heavy-v4.0.9-3e93b23afc`](../../bench/upstream/ruby-differential/runs/2026-11-27-409-heavy-v4.0.9-3e93b23afc).
  Each holds `runs.txt`, the per-test outcomes and `reruns.json`. The master label also holds `diffs.json` and
  `warnings-vs-*.json`.
* Commands: `script/ruby-differential compare --label <master> --base-label <4.0.9> --same-mode`, then
  `rerun --diffs-from <set> --rerun-modes interp,yjit[,zjit]` on each Ruby, then `warndiff`. This slice added
  `--same-mode`, `--keep`, `--diffs-from`, `--rerun-modes` and `warndiff`, and the app entries for Lago, Docuseal
  and Flow (outside `DEFAULT_APPS`). It also fixed a nil `group_by` in `rerun`.
* Each app's two lockfiles (`Gemfile.census-*-ruby-3e93b23afc.lock` and `-f3e180b5eb.lock`) are byte-identical.

## Per app

Tests are per mode. Every app except Lago ran the same count on each Ruby and in each mode.

| App | Tests | Rails | Differences (master vs 4.0.9) | After alone-reruns |
| --- | ---: | --- | --- | --- |
| Discourse | 22,128 | main `cf0325a832` | 17 post_mover in every mode, plus 6–9 others per mode | post_mover real; 16 others flakes |
| Sure | 14,236 | main `cf0325a832` | 2 JevTest in every mode | real |
| Flow | 9,714 | 8.1.4 | 1 in every mode; 1 more in interpW | 1 real; 1 flake on the 4.0.9 side |
| Mastodon | 7,748 | main `cf0325a832` | 2 featured_tag in interp only | flakes (`Redis::CannotConnectError`) |
| Lago | 20,484 compared (interp only) | 8.1.4 | 0 on the common tests | |
| Loomio | 3,660 | main `cf0325a832` | 0 | |
| CASA | 2,992 | main `cf0325a832` | 1 in every mode | real (environment) |
| Lobsters | 927 | `b5be03636e` | 0 (3 app failures on both) | |
| Docuseal | 107 | 8.1.4 | 0 | |
| Chatwoot | not run | | | commonmarker 0.23.12 does not build on master |

The Discourse flakes are `user_spec` ×6, `user_option_spec` ×3, `user_history_spec` ×3,
`discourse_id_authenticator_spec` ×3, `uploads_restorer_spec` ×3, `web_hook_spec` ×3, `pretty_text_spec` and
`stylesheet/manager_spec`. They failed with `SpecTimeoutError`, `MultipleExceptionError` or Redis errors while
several suites shared the orb, and each passes 3 of 3 alone on both Rubies in every mode.

Flow's `WorkspaceSignupTicketTest#test_what_it_carries_cannot_be_read_from_the_link` errored once on 4.0.9
(interpW, `ArgumentError: invalid base64`). Alone it errored 1 of 3 times in 4.0.9 interp and 0 of 9 times on
master. The cause is in the test. It splits a `url_safe: true` MessageEncryptor token on `"--"`, but urlsafe base64
can itself contain `-`, so the split sometimes cuts a part in the wrong place. 3,000 tokens from
`WorkspaceSignupTicket.issue` fail the split in 349 cases on 4.0.9 and 372 on master (about 12% on both).

## Real differences

### Flow: Time.iso8601 keeps impossible dates (time 0.5.0)

This is the slice's only real Ruby regression.
`RunnerProtocolConformanceTest#test_the_timestamp_matcher_takes_only_the_canonical_UTC_form_of_a_real_instant`
expects `"2026-02-30T00:00:00Z"` not to match a timestamp. On master, `Time.iso8601` returns a Time whose fields
read Feb 30 while its instant is March 2. Repro:
[`repros/time_iso8601_feb30.rb`](../../bench/upstream/ruby-differential/repros/time_iso8601_feb30.rb). Master
raises `Feb 30 kept: 2026-02-30T00:00:00Z`; 4.0.9 (time 0.4.2) prints `ok`.

* **First bad commit:** `77d0d22b59` "[ruby/time] Optimize Time.xmlschema" (byroot, 2026-06-22). `Time.xmlschema`
  now calls `Time.new(string)`. This was checked by loading that commit's `lib/time.rb` and its parent's on master.
* **Existing reports:** the behavior of `Time.new(string)` is open [Bug #21301](https://bugs.ruby-lang.org/issues/21301).
  [Bug #22375](https://bugs.ruby-lang.org/issues/22375) reports this exact `Time.iso8601` case and was closed as a
  duplicate. ruby/ruby#13246 was closed unmerged.
* **Fix:** the coordinator confirmed this as Finding 2 in [ruby41-differential-409.md](ruby41-differential-409.md).
  Master with only TN1's `time.c` (head `2e061793aa`, our draft ruby/ruby#20208) gives the rolled-over date in every
  case, so no new queue item is needed.

### Sure: Mocha stubs on ENV raise Ractor::IsolationError

`Provider::JevTest`, 2 tests, fail with `can't modify instance variables of a shareable Object`. Mocha keeps a
stubbed object's mock in `@mocha`, and on master `ENV` is shareable but not frozen. Repro:
[`repros/env_ivar_shareable.rb`](../../bench/upstream/ruby-differential/repros/env_ivar_shareable.rb). A full
miniruby bisect ([`bisect-env-ivar.log`](../../bench/upstream/ruby-differential/runs/2026-11-27-409-heavy-master-f3e180b5eb/bisect-env-ivar.log))
finds `73055acd57`, [Bug #22291](https://bugs.ruby-lang.org/issues/22291), an intentional change. freerange/mocha has
no issue or PR on this, and mocha 3.1.0 behaves the same. Covered by the light slice's Finding 1 and queue item MO1.

### Discourse: Symbol#to_s returns a frozen String

17 `post_mover_spec` tests fail with `FrozenError: can't modify frozen String: "existing_topic"` (or
`"new_topic"`). `PostMover#create_moderator_post_in_original_topic` calls `sub!` on
`PostMover.move_types[@move_type].to_s`. Repro:
[`repros/symbol_to_s_frozen.rb`](../../bench/upstream/ruby-differential/repros/symbol_to_s_frozen.rb).

* **First bad commit:** `2c574ca7e2`, [Feature #22137](https://bugs.ruby-lang.org/issues/22137), intentional. Its
  parent `3782b63b79` passes the repro with miniruby.
* **Warning on 4.0.9:** 4.0.9 with `-W:deprecated` prints this warning 17 times, so it is an app bug. Discourse
  main still has the code (`app/models/post_mover.rb:687-688`).

### CASA: newer default gems activated before bundler/setup

`spec/config/parallel_coverage_spec.rb[1:1]` starts
`ruby -I spec -rrspec/core -rspec_helper` with `RUBYOPT=-rbundler/setup`. On both Rubies, command-line `-r` options
load before RUBYOPT's. The process therefore activates rspec-core's dependencies from RubyGems first:

* On master these resolve to the default gems erb 6.1.0, strscan 3.1.9.dev and json 3.2.0. Bundler then stops with
  `You have already activated json 3.2.0, but your Gemfile requires json 2.21.2` (with only `-rrspec/core`, the
  same error names erb 6.1.0 against the lock's 6.0.7).
* On 4.0.9 the default erb is 6.0.7, the lock's version, so the child passes.

This is an intentional default-gem bump and the test's own load order, not a Ruby bug. It was reproduced outside the
suite with the same environment: master fails and 4.0.9 passes.

## Hard apps

* **Lago** runs on its own upstream Gemfile with Rails 8.1.4, because Rails main fails with bullet ("does not
  support 8.2") and awesome_print's `colorize_logging`. Its test database is ClickHouse 25.12.11.4, the version
  Lago's CI uses; ClickHouse 26.12 fails a migration with an AggregatingMergeTree error. `run_prep` creates and
  migrates one ClickHouse database per run. `spec/integration` is excluded. Each run uses 5–9 GB of memory, so
  Lago ran with one job per Ruby.
  **Only interp was compared, and only partly.** The full suite (about 27,500 `it` blocks, more with shared examples)
  takes over two hours per run on this orb while other Lago runs share its 32 GB. 4.0.9 interp hit the 7,200 s
  timeout after 20,484 examples (27 failures, 1 pending). Master interp was let run past the timeout and stopped
  with SIGINT after 32,509 examples (136 failures, 1 pending). On the 20,484 tests both runs recorded, outcomes and
  exception classes are identical, except the one example 4.0.9 was in when it timed out
  ([`lago-common-tests.txt`](../../bench/upstream/ruby-differential/runs/2026-11-27-409-heavy-master-f3e180b5eb/lago-common-tests.txt)).
  `compare` lists the master-only tail as `MISSING -> …` in `diffs.json`. 107 of master's failures in that tail
  are `Faker::UniqueGenerator::RetryLimitExceeded`, which 4.0.9 also shows (8 times) in the common part; they were
  not compared with 4.0.9. Lago yjit, interpW and master zjit were started but stopped for memory and are not
  recorded. No new warnings in Lago interp.
  The first master interp run stopped after 5,645 examples. `clickhouse_rake_spec.rb[1:7:2:1:1]` reached
  `abort` in `recipes:clickhouse:enable_clickhouse_events_store`, and RSpec does not rescue `SystemExit`. The task
  compares events older than `Time.current.beginning_of_hour`, and the test creates one `10.seconds.ago`. The
  example ran at 13:00:0x, in the first 10 seconds of an hour, so the counts differed (`Postgres count: 2,
  ClickHouse count: 1`). This is a Lago test bug at the hour boundary. Alone, the example passes 3 of 3 on both
  Rubies in every mode, and the suite was rerun.
* **Docuseal** uses Rails 8.1.4 and pdfium as the census's 9-symbol stub over bblanchon `chromium/8125`. System specs
  are excluded, which leaves 107 examples.
* **Flow** uses Rails 8.1.4 and temporalio 1.10.0 as a path gem built from source (magnus 0.8.5, rb-sys 0.9.130),
  with one bridge per Ruby (`bridge/4.0`, `bridge/4.1`). Its Vite build was run.
* **Chatwoot** did not run. commonmarker 0.23.12 does not build on master, and a maintainer declined the C-branch
  port ([gems-on-master.md](gems-on-master.md)). Chatwoot develop still locks 0.23.12 with Rails 8.0.5.2, so no
  lockfile works on both Rubies without replacing its Markdown gem.

## Gem bumps (applied on both Rubies)

* Discourse, Mastodon, Sure, Loomio and CASA use the existing master overlays on Rails main `cf0325a832`
  ([gems-on-master.md](gems-on-master.md)).
  * Discourse adds activejob.
  * Sure adds minitest-mock.
  * The vendored prism (Loomio) and tokenizers (Discourse) are built once per Ruby; `fresh_copy` copies
    `SO.ruby-REV`.
* Lobsters uses the corpus Gemfile with its own Rails pin `b5be03636e`. Rails `cf0325a832` fails at boot with
  `typedstore prefers_color_scheme`.
* Lago:
  * lago-expression from git `d23823a03e` (getlago/lago-expression#91), with its Rust extension built per Ruby.
  * datadog 2.33.0 → 2.49.0.
* Docuseal: numo-narray-alt 0.10.3 → 0.12.0.
* Flow:
  * temporalio 1.10.0 built from source.
  * cbor from git `08f34f5b9a` (cabo/cbor-ruby#31).
  * `force_ruby_platform` for sqlite3, nokogiri, ffi and google-protobuf.

## New warnings on master

From `warndiff`, in Ruby `warning:` lines and DEPRECATION WARNING lines, normalized:

* "the fallback to Object for alias of … is deprecated and will be removed in Ruby 4.3" (Feature #22276):
  * mocha 2.7.1 and 3.1.0 (`method`, in Sure, Flow and Discourse; open freerange/mocha#804);
  * Loomio's `app/models/concerns/null/group.rb` (`send`);
  * the active_model_serializers fork (Loomio) and 0.8.4 (Discourse), both `send`;
  * mini_sql 1.6.0 (`send`, Discourse);
  * irb 1.18.0 `ext/loader.rb` (`require` and `load`, Mastodon; fixed in irb 1.19.0 per ruby/irb#1255).
* "aliasing ActiveSupport::SafeBuffer#concat defined in a prepended module FreedomPatches::SafeBuffer is deprecated
  and will be removed in Ruby 4.3": Discourse `lib/freedom_patches/safe_buffer.rb`, from `1c13d07cfc` (Bug #22273,
  Jeremy Evans). Its plan is a warning in 4.1, a warning even without `-W` in 4.2, and removal in 4.3.
* Gone on master: Discourse's two chilled-string warnings (the `Symbol#to_s` case above), because master raises
  instead.

None of the new warnings are errors on master.
