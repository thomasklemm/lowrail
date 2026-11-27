# Suite wall time, debug vs info log level: Ruby 4.0.10 YJIT

`wall_rounds.rb OUT RUBY yjit 12 codetriage campfire hackatime fizzy` on an a1.xxlarge orb, run serially with
nothing else heavy. Arms `a` and `a2` run each suite as configured (debug log level, the A/A); `info` sets
`PT2_LOG_LEVEL=info`. Each round runs every app's three arms in a rotated order, each on a fresh copy and
database. Ratios are the median over 12 rounds; intervals are seeded 95% bootstrap intervals over whole rounds.

* Ruby: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +YJIT +PRISM [x86_64-linux] (all 144 runs, YJIT on)
* Rails: 2e299253f942ab94041cc6f210ac9d33884c210d for CodeTriage, Hackatime and Campfire (Campfire repinned
  from its own 36e0f96b9d pin). Fizzy stays on its own pin 36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e: on
  2e299253 its test boot fails with SystemStackError (config/initializers/uuid_primary_keys.rb overrides
  build_schema_context).
* Apps: codetriage d1868f8634e97a111a7fca49d58cc776d206007e, hackatime 74deec42b2556f96ee25116e161fc1581bd72f27,
  campfire af4dd9fd599c65e0e0fc1f614ee469f70156ddf5, fizzy 77eada1c8ead75c39f7fda5c80f322bcf5a9adb5
* nproc: 16

## Wall time (test window)

| App | Rounds | Tests | wall a (median s) | A/A a2/a | 95% | info/a | 95% | Counts |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |
| codetriage | 12 | 219 | 6.53 | +1.98% | -3.58% to +5.12% | -9.72% | -13.16% to -5.43% | yes |
| campfire | 12 | 634 | 40.69 | -1.16% | -3.15% to +1.26% | -19.41% | -21.46% to -17.51% | yes |
| hackatime | 12 | 794 | 45.78 | +0.19% | -1.43% to +2.07% | -3.37% | -6.13% to -2.14% | yes |
| fizzy | 12 | 1787 | 80.0 | -3.01% | -6.21% to +0.72% | -14.71% | -17.13% to -13.93% | yes |

## CPU time (test window)

| App | Rounds | Tests | cpu a (median s) | A/A a2/a | 95% | info/a | 95% | Counts |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |
| codetriage | 12 | 219 | 5.44 | +2.38% | -3.29% to +6.80% | -10.98% | -14.65% to -9.00% | yes |
| campfire | 12 | 634 | 29.95 | -1.76% | -3.89% to +1.78% | -26.93% | -28.62% to -24.47% | yes |
| hackatime | 12 | 794 | 31.92 | -0.07% | -1.60% to +2.34% | -4.84% | -7.96% to -3.12% | yes |
| fizzy | 12 | 1787 | 80.08 | -2.99% | -6.19% to +0.79% | -14.68% | -17.09% to -13.87% | yes |

## Test outcomes

Every arm of every round ran the same number of tests with the same exit status: CodeTriage 219 (exit 0),
Campfire 634 (0), Hackatime 794 (0), Fizzy 1787 (1, from 4 errors `NoMethodError: undefined method 'parse'
for class CGI` in every run).

Mismatch: Fizzy's `info` arm has 13 failures in all 12 rounds that `a` and `a2` don't (1787 runs, 6740
assertions, 13 failures, 4 errors vs 6792 assertions, 0 failures, 4 errors). They are the tests that assert on
log output: ActiveRecordSqlRedactionTest (11) and ActionMailerDeliveredEventWithoutMailTest (2), which expect
debug-level SQL and mail lines.

## Files

`runs.jsonl` has one line per run. `raw/*.json` holds each run's suite_profile.rb window and run_suite.rb
status. The per-run logs (13 MB) are not committed. After the 12 rounds the driver was restarted once by the
service manager and reran codetriage `a` round 0 before it was stopped; that rerun overwrote
`raw/codetriage-a-0.run.json` and was not appended to runs.jsonl, so those files were removed
(round 0's numbers are in runs.jsonl and `raw/codetriage-a-0.47093.json`).
