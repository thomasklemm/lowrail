# Suite wall time, debug vs info log level, Ruby master × ZJIT

12 rounds per app, arms `a` and `a2` (suite as configured, debug log level; A/A) and `info` (`PT2_LOG_LEVEL=info`),
interleaved by round in rotated order, one run at a time, through `wall_rounds.rb`; each run a fresh copy and database.

* Ruby: `ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +ZJIT +PRISM [x86_64-linux]`, `--zjit` (every run's JSON: zjit true, yjit false)
* Rails: main 2e299253f942ab94041cc6f210ac9d33884c210d for CodeTriage, Hackatime (census Gemfile variants) and Campfire
  (Gemfile repinned from 36e0f96b9d). Fizzy stays on its own pin 36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e: on
  2e299253 its test boot fails with SystemStackError (config/initializers/uuid_primary_keys.rb).
* Apps: codetriage/codetriage d1868f8634e97a111a7fca49d58cc776d206007e, basecamp/once-campfire
  af4dd9fd599c65e0e0fc1f614ee469f70156ddf5, hackclub/hackatime 74deec42b2556f96ee25116e161fc1581bd72f27,
  basecamp/fizzy 77eada1c8ead75c39f7fda5c80f322bcf5a9adb5 (corpus censuspt2, script/ruby-differential setup)
* Orb: a1.xxlarge, `nproc` 16, PostgreSQL/Redis/memcached local, nothing else heavy running
* `runs.jsonl`: one line per run; `raw/`: suite_profile.rb's per-run JSON and run_suite.rb's `.run.json` (logs dropped)

## Wall (`wall_summary.rb runs.jsonl wall`)

| App | Rounds | Tests | wall a (median s) | A/A a2/a | 95% | info/a | 95% | Counts |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |
| codetriage | 12 | 219 | 7.28 | +1.14% | -4.94% to +7.84% | -8.60% | -10.16% to -4.09% | yes |
| campfire | 12 | 634 | 46.61 | -0.01% | -1.13% to +2.94% | -18.80% | -20.30% to -17.60% | yes |
| hackatime | 12 | 794 | 47.06 | -1.44% | -2.29% to +0.74% | -5.21% | -8.04% to -3.73% | yes |
| fizzy | 12 | 1787 | 84.7 | -0.10% | -3.80% to +1.65% | -11.90% | -13.71% to -9.20% | yes |

## CPU (`wall_summary.rb runs.jsonl cpu`)

| App | Rounds | Tests | cpu a (median s) | A/A a2/a | 95% | info/a | 95% | Counts |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- |
| codetriage | 12 | 219 | 6.29 | +0.89% | -5.50% to +7.68% | -9.40% | -11.21% to -6.81% | yes |
| campfire | 12 | 634 | 35.33 | -0.08% | -1.52% to +3.86% | -24.91% | -27.09% to -23.94% | yes |
| hackatime | 12 | 794 | 33.45 | -1.59% | -2.68% to +0.71% | -6.81% | -10.90% to -4.83% | yes |
| fizzy | 12 | 1787 | 84.86 | -0.13% | -3.77% to +1.65% | -11.93% | -13.67% to -9.21% | yes |

## Test outcomes

Test counts and exit statuses match across arms in every round. Minitest totals, identical in all 12 rounds of each arm:

| App | a, a2 | info |
| --- | --- | --- |
| codetriage | 219 runs, 457 assertions, 0 failures, 0 errors | same |
| campfire | 634 runs, 3856 assertions, 0 failures, 0 errors, 2 skips | same |
| hackatime | 794 runs, 3541 assertions, 0 failures, 0 errors | same |
| fizzy | 1787 runs, 6792 assertions, 0 failures, 4 errors, 6 skips | 1787 runs, 6740 assertions, **13 failures**, 4 errors, 6 skips |

Fizzy's 4 errors in every arm: Webhook::DeliveryTest, `undefined method 'parse' for class CGI` on this Ruby.
Fizzy's 13 `info`-only failures are its own tests of logged output, which expect debug-level lines
(ActiveRecordSqlRedactionTest ×11, ActionMailerDeliveredEventWithoutMailTest ×2); they take 1.56 s in total over all
12 `info` runs, so they don't account for the `info` difference.
