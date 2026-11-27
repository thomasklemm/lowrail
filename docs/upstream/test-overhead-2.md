# P-TEST 2: where a Rails test suite's time goes outside the app (2026-11-27)

Bet: every Rails developer runs the test suite many times a day, so the framework's share of suite time has huge
reach. P-TEST 1 ([test-overhead.md](test-overhead.md)) priced one empty test in four apps and parked PT1. This round
profiles the census apps' **whole own suites** on current Rails main and ranks the framework parts by their share of
suite CPU.

## Result

**One framework part stands out: SQL debug logging, a median 8.5% of suite CPU (4.0.10, YJIT) and 8.3% (master,
ZJIT).** A test environment logs every query to `log/test.log` at debug unless the app says otherwise, and on Rails
main every logged query goes through the new structured-event chain (`ActiveRecord::StructuredEventSubscriber#sql` →
`Rails.event.debug` → `EventReporter#notify` → `ActiveRecord::LogSubscriber#sql`). Per logged query that chain costs
**61% more interpreter instructions than 8.1.4.1's log subscriber** (169,500 against 105,100; YJIT 111,000 against
69,200), an unreleased 8.2 cost. It is not ours to fix: three open rails/rails PRs by others work on exactly this path
(below), and maintainers merged three performance commits there since October. Recorded, nothing opened.

Everything else the brief listed is small or already owned:

| Rank | Part (inclusive share of sampled suite CPU, 9 apps) | Median YJIT | Range YJIT | Median ZJIT | Decision |
| ---: | --- | ---: | --- | ---: | --- |
| 1 | Garbage collection | 10.3% | 5.7–11.3% | 7.6% | Ruby runtime; no exact framework fix |
| 2 | SQL and event debug logging | 8.5% | 0.2–14.2% | 8.3% | 8.2 cost over 8.1; owned by open PRs of others |
| 3 | Fixtures, all | 2.9% | 1.5–9.1% | 3.2% | mostly real work (finds, BEGIN/ROLLBACK); PT1 stays parked |
| 4 | Test frameworks' own code (Minitest, RSpec, Rails test helpers) | 1.5% | 0.6–2.5% | 1.7% | spread thin; no hotspot |
| 5 | Integration session outside the request | 0.8% | 0.1–1.6% | 0.7% | rack-test about two thirds of it; cookie lead held |
| 6 | Mocks and stubs (Mocha, WebMock, rspec-mocks) | 0.6% | 0–3.4% | 0.8% | app-configured; nothing generic |
| 7 | Controller-test plumbing outside the action | 0.0% | 0–0.4% | 0.0% | negligible |
| – | Factories (factory_bot, Fabrication), all | 26–57% in the 3 apps using them | | 31–57% | mostly `save!`; factory_bot's own code 1.4–3.9%, reworked by its maintainer today |
| – | Parallel-testing setup and database forking | 1–3% of a 4-worker run | | | fixed per worker; [below](#parallel-testing) |

Shares overlap (logging inside a factory's `save!` counts for both) and are not additive. Factories are listed apart
because only three of nine suites use them, where they dominate; the gem's own code is the part a gem fix could touch.

## Suite wall time on a1.xxlarge

Ruby 4.0.10 with YJIT, a1.xxlarge (16 vCPUs, suites run serially), 12 rounds, each app's suite as configured twice
(`a`, `a2`: the A/A) against the logger at info with the event reporter's debug mode off (`info`, as
`config.log_level = :info` sets it). Median of each round's ratios, seeded 95% bootstrap intervals over rounds
([summary](../../bench/upstream/test_overhead/wall/ruby-4.0.10-yjit/summary.md),
[runs](../../bench/upstream/test_overhead/wall/ruby-4.0.10-yjit/runs.jsonl)):

| App | Suite wall, debug | A/A | Info against debug | 95% |
| --- | ---: | ---: | ---: | --- |
| CodeTriage | 6.5 s | +2.0% | **−9.7%** | −13.2% to −5.4% |
| Campfire | 40.7 s | −1.2% | **−19.4%** | −21.5% to −17.5% |
| Hackatime | 45.8 s | +0.2% | **−3.4%** | −6.1% to −2.1% |
| Fizzy (own pin) | 80.0 s | −3.0% | **−14.7%** | −17.1% to −13.9% |

Master `0d399335b7` with ZJIT, the same setup
([summary](../../bench/upstream/test_overhead/wall/ruby-master-0d399335-zjit/summary.md)):

| App | Suite wall, debug | A/A | Info against debug | 95% |
| --- | ---: | ---: | ---: | --- |
| CodeTriage | 7.3 s | +1.1% | **−8.6%** | −10.2% to −4.1% |
| Campfire | 46.6 s | −0.0% | **−18.8%** | −20.3% to −17.6% |
| Hackatime | 47.1 s | −1.4% | **−5.2%** | −8.0% to −3.7% |
| Fizzy (own pin) | 84.7 s | −0.1% | **−11.9%** | −13.7% to −9.2% |

On both Rubies every A/A interval contains 0 and every change interval excludes it, so all eight cells count. CPU
time moves the same way (Campfire −26.9% YJIT, −24.9% ZJIT). The info arm drops all debug logging, not only the SQL chain (Active Job, Action View, Active
Storage and the app's own `logger.debug` lines too), so this is the price of the test environment's debug level, the
upper bound for what the SQL path alone could give back; it is larger than the sampled SQL-chain shares above
(Campfire 5.4%), and the difference is not attributed. Fizzy's info arm also fails 13 tests in every round that
assert on debug log lines (`ActiveRecordSqlRedactionTest`, `ActionMailerDeliveredEventWithoutMailTest`), so it
does slightly less work there (1.6 s over 12 ZJIT runs, far too little to explain the drop). Test counts and exit
statuses otherwise match in all 288 runs.

## The ranking, per app

Ruby 4.0.10 with YJIT, Rails main `2e299253f9` (Fizzy: its own pin `36e0f96b9d`, below), `PARALLEL_WORKERS=1`, one
run per app with stackprof in CPU mode (1 ms, raw stacks). Shares are of the samples in the test window (Minitest's
`run_all_suites`, RSpec's `run_specs`; boot and loading excluded). CPU and objects per test come from the window's
clock and `GC.stat` counters, not from the sampler.

| Part | campfire | writebook | fizzy | codetriage | hackatime | casa | sure | loomio | mastodon | Median |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| tests | 634 | 310 | 1787 | 219 | 794 | 2992 | 14236 | 3660 | 7748 | |
| cpu ms per test | 41.6 | 156.2 | 40.8 | 19.6 | 35.2 | 32.9 | 46.2 | 86.4 | 62.1 | |
| objects per test | 39334 | 29639 | 28578 | 8473 | 15164 | 21454 | 25293 | 53375 | 39738 | |
| SQL and event debug logging | 5.4% | 7.0% | 10.1% | 9.1% | 7.0% | 8.5% | 14.2% | 0.2% | 39.1% | 8.5% |
| · of which query source (verbose_query_logs) | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 34.0% | 0.0% |
| Fixtures, all | 4.1% | 2.9% | 5.4% | 9.1% | 1.5% | 1.6% | 3.3% | 1.9% | 2.2% | 2.9% |
| · fixture loading | 1.2% | 0.5% | 1.6% | 2.1% | 0.0% | 0.0% | 0.2% | 0.4% | 0.0% | 0.4% |
| · transactional setup and teardown | 0.9% | 1.0% | 1.0% | 3.6% | 1.3% | 1.5% | 1.1% | 0.3% | 2.1% | 1.1% |
| · fixture accessors (record finds) | 1.5% | 1.3% | 2.6% | 3.0% | 0.0% | 0.0% | 1.8% | 1.1% | 0.0% | 1.3% |
| Integration session, outside the request | 1.6% | 1.6% | 1.3% | 0.1% | 1.4% | 0.5% | 0.8% | 0.1% | 0.2% | 0.8% |
| · rack-test request and cookies | 1.1% | 1.2% | 1.1% | 0.0% | 1.1% | 0.3% | 0.6% | 0.0% | 0.1% | 0.6% |
| Controller test plumbing, outside the action | 0.0% | 0.0% | 0.0% | 0.4% | 0.0% | 0.0% | 0.0% | 0.3% | 0.1% | 0.0% |
| Factories, all (factory_bot, Fabrication) | 0.0% | 0.0% | 0.0% | 0.0% | 26.0% | 43.7% | 0.0% | 0.0% | 56.7% | 0.0% |
| · factory gem's own code | 0.0% | 0.0% | 0.0% | 0.0% | 1.4% | 3.9% | 0.0% | 0.0% | 0.5% | 0.0% |
| Test framework (Minitest, RSpec, Rails test helpers), own code | 1.5% | 1.7% | 1.4% | 1.8% | 1.8% | 2.5% | 0.8% | 0.6% | 1.5% | 1.5% |
| Mocks and stubs (Mocha, WebMock, rspec-mocks) | 1.1% | 0.0% | 0.3% | 3.4% | 0.6% | 1.0% | 0.6% | 0.2% | 1.1% | 0.6% |
| Garbage collection | 11.3% | 10.7% | 10.6% | 9.1% | 10.3% | 10.2% | 5.9% | 5.7% | 10.6% | 10.3% |

Master `0d399335b7` with ZJIT, the same apps and Rails:

| Part | campfire | writebook | fizzy | codetriage | hackatime | casa | sure | loomio | mastodon | Median |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| tests | 634 | 310 | 1787 | 219 | 794 | 2992 | 14236 | 3660 | 7748 | |
| cpu ms per test | 47.6 | 162.4 | 46.8 | 24.5 | 40.1 | 44.1 | 50.7 | 102.6 | 73.7 | |
| objects per test | 38826 | 28653 | 27479 | 8445 | 15141 | 21260 | 24691 | 52330 | 39667 | |
| SQL and event debug logging | 4.9% | 6.5% | 9.6% | 8.6% | 7.3% | 8.3% | 13.3% | 0.3% | 34.5% | 8.3% |
| · of which query source (verbose_query_logs) | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 0.0% | 29.3% | 0.0% |
| Fixtures, all | 4.6% | 3.3% | 5.2% | 10.2% | 1.8% | 1.7% | 3.2% | 1.9% | 2.1% | 3.2% |
| · fixture loading | 1.3% | 0.6% | 1.6% | 2.1% | 0.0% | 0.0% | 0.3% | 0.3% | 0.0% | 0.3% |
| · transactional setup and teardown | 1.2% | 1.2% | 0.8% | 4.6% | 1.5% | 1.4% | 1.0% | 0.3% | 2.0% | 1.2% |
| · fixture accessors (record finds) | 1.6% | 1.4% | 2.6% | 3.0% | 0.0% | 0.0% | 1.7% | 1.1% | 0.0% | 1.4% |
| Integration session, outside the request | 1.8% | 1.9% | 1.5% | 0.1% | 1.3% | 0.5% | 0.7% | 0.0% | 0.2% | 0.7% |
| · rack-test request and cookies | 1.1% | 1.3% | 1.2% | 0.1% | 0.9% | 0.3% | 0.6% | 0.0% | 0.1% | 0.6% |
| Controller test plumbing, outside the action | 0.0% | 0.0% | 0.0% | 0.3% | 0.0% | 0.1% | 0.0% | 0.3% | 0.1% | 0.0% |
| Factories, all (factory_bot, Fabrication) | 0.0% | 0.0% | 0.0% | 0.0% | 30.9% | 42.6% | 0.0% | 0.0% | 57.0% | 0.0% |
| · factory gem's own code | 0.0% | 0.0% | 0.0% | 0.0% | 1.5% | 2.5% | 0.0% | 0.0% | 0.6% | 0.0% |
| Test framework (Minitest, RSpec, Rails test helpers), own code | 1.9% | 1.9% | 1.4% | 1.8% | 1.7% | 2.6% | 0.7% | 0.5% | 1.5% | 1.7% |
| Mocks and stubs (Mocha, WebMock, rspec-mocks) | 1.2% | 0.0% | 0.5% | 3.6% | 0.8% | 1.3% | 0.6% | 0.2% | 1.2% | 0.8% |
| Garbage collection | 7.0% | 6.3% | 7.5% | 8.0% | 8.4% | 9.3% | 7.6% | 5.4% | 10.9% | 7.6% |

Reading the outliers:

* **Mastodon's 39% logging is its own doing:** `spec/models/concerns/status/fetch_replies_concern_spec.rb` sets
  `ActiveRecord.verbose_query_logs = true` at file level and never resets it, so from load on every query walks the
  caller stack through the backtrace cleaner (34.0% of suite CPU; `String#sub` in the gem filter alone 14.5%). The
  rest of its logging is 5.1 points, in line with the others. Mastodon is measurement corpus only (DECISIONS,
  restrictive AI policy); nothing is reported there.
* **Loomio's 0.2%** is a natural control: its `config/environments/test.rb` logs at `:warn` when `CI` is set, as in
  these runs.
* **Sure's 14.2%** includes 2.0% for `ParameterFilter` on every bind (many filter parameters); 8.1's log subscriber
  filtered binds the same way.
* **CodeTriage at info** still spends 3.4% in subscribers, 1.8 points of it in sentry-rails' own SQL log subscriber
  (Sentry structured logs on), not Rails.

## SQL debug logging: 8.1.4.1 against main

`ActiveRecord::Base.logger` at debug against info, one `Post.find_by(id: 1)` on in-memory SQLite, Ruby 4.0.10,
[`sql_log_body.rb`](../../bench/upstream/test_overhead/sql_log_body.rb) through `script/upstream-bench` (objects,
Callgrind with A/A). The two trees resolve different dependency sets (main adds psych, stringio, ractor-dispatch,
date), which the tool refuses to pair, so each tree ran against a second worktree of itself as its A/A, and the
comparison across trees is a diagnostic of each tree with its own dependencies.

| Per query | 8.1.4.1 | main `2e299253f9` |
| --- | ---: | ---: |
| Interpreter instructions, logger at debug | 341,745 | 389,912 |
| Interpreter instructions, logger at info | 236,604 | 220,386 |
| **Logging cost (debug − info), interpreter** | **105,141** | **169,526 (+61%)** |
| YJIT instructions, debug / info | 189,733 / 120,515 | 203,107 / 92,038 |
| **Logging cost, YJIT** | **69,218** | **111,069 (+60%)** |
| Objects, debug / info | 97 / 50 | 97 / 38 |

Largest A/A: 0.05% (interpreter), 0.44% (YJIT). Main's YJIT debug cell compiled 3 blocks in each measured window, so
that cell is approximate. At info, main is cheaper than 8.1 (the event isn't built); at debug the structured event is
built and then consumed by the log subscriber, which 8.1 did in one step. Raw output:
[8.1](../../bench/upstream/test_overhead/body/sql-log-81), [main](../../bench/upstream/test_overhead/body/sql-log-main).

**The open PR closes little of it.** Main against main with #59717's head `f4d234e2b5` applied (its library changes;
a test-file conflict left unresolved), same dependencies, A/A per cell: **−1.1%** interpreter instructions per logged
query (390,226 → 385,774, A/A 0.01%), 97 → 92 objects; YJIT −2.6% but not JIT-flat (3 blocks compiled in every
debug window); no change at info. That is 4,450 of main's 64,400-instruction excess over 8.1, so after it debug
logging still costs about 57% more per query than on 8.1. The rest is the event design: per logged query main
resolves the payload, runs every event-reporter subscriber's filter proc, checks the log level twice
(`consumes?` and `emit`), reads tags and context, takes a timestamp and freezes the event, on top of what 8.1's
subscriber did in one method. Raw: [main vs #59717](../../bench/upstream/test_overhead/body/sql-log-main-vs-59717).

**Who owns it.** Merged on main since October: 98d80d5bdb "Speed up structured event logging" (linyiru, 10-06),
81d95a3f74 "Don't build structured events that no subscriber will consume" (Akira Matsuda, 10-13), 632d2f4100
"Don't build log subscriber events whose logging is turned off" (Bruno Costanzo, 11-24). Open:
[#58957](https://github.com/rails/rails/pull/58957) "Skip structured event handlers whose event nobody consumes"
(linyiru, updated today; at debug the log subscriber consumes `sql`, so it doesn't change this cell),
[#59717](https://github.com/rails/rails/pull/59717) "Skip capturing source_location for subscribers that don't read
it" (sampokuokkanen), and [#59330](https://github.com/rails/rails/pull/59330) "Log at info in the test environment of
new apps" (namespaceMarcello; generated apps only, existing apps keep debug). Etiquette: no comment on others' PRs
without Thomas's approval of that comment; our numbers stay here. If Thomas wants it, the one useful data point for
#59330 is the suite wall-time table above. Under the shared-helper rule (2026-11-27), any
fix of ours here would go into `EventReporter#notify` and the shared `EventReporter::LogSubscriber`, which every
framework's log subscriber uses, not into Active Record's `sql` handler alone; that is also where the open PRs work.

### Attribution of main's excess (2026-11-27, follow-up)

**Where the +61% goes, layer by layer.** [`sql_log_layers.rb`](../../bench/upstream/test_overhead/sql_log_layers.rb)
(main) and [`sql_log_layers_81.rb`](../../bench/upstream/test_overhead/sql_log_layers_81.rb) (8.1.4.1) log the same
`find_by` with one layer switched off at a time, through a prepended no-op in each case alike; a layer's cost is the
difference to the case one level up, inclusive of everything it calls. Interpreter instructions per logged query,
Ruby 4.0.10, `script/upstream-bench` with a second worktree as A/A (largest A/A 0.07% on 8.1, 0.08% on main):

| Layer (debug − info) | 8.1.4.1 | main `2e299253f9` | main − 8.1 |
| --- | ---: | ---: | ---: |
| Notifications dispatch to the first subscriber and its checks | 26,100 | 21,900 | −4,200 |
| `ActiveRecord::StructuredEventSubscriber#sql`: binds, seven keyword arguments | – | 15,600 | **+15,600** |
| `emit_debug_event` → `EventReporter#debug` → `#notify`: keyword hand-off | – | 15,800 | **+15,800** |
| `EventReporter#notify`: filter loop, subscriber check, payload, event, source location, freeze | – | 37,900 | **+37,900** |
| `EventReporter::LogSubscriber#emit`: logger, `event_method_for`, level check, `public_send` | – | 13,200 | **+13,200** |
| `ActiveRecord::LogSubscriber#sql`: message formatting and the logger write | 80,800 | 68,300 | −12,500 |
| **Total** | **106,900** | **172,700** | **+65,800** |

The harness's own wrappers add about 1–3k to main's total against the plain micro above (172,700 against 169,526).
With the four other framework log subscribers Campfire registers (Action Dispatch, Active Storage, Action
Controller, Active Job), each logged query costs another 6,700 in `notify`'s filter loop. Objects per logged query:
8.1 95 (56 without formatting, 50 at info), main 97 (62, 62, 53, 50, 46 down the layers, 40 at info). Bisecting was
not needed: on 8.1 the event reporter has no subscribers, so `StructuredEventSubscriber` stays silenced and the log
subscriber formats straight from the notification. aebcb61520 "Introduce ActiveSupport::EventReporter::LogSubscriber"
and 308594b580 "Convert log subscriber in Active Record to consume structured events" (neither in 8.1) subscribe the
log subscriber to the reporter, which puts the three middle layers between Notifications and the formatter; later
merged speedups made the formatter cheaper than 8.1's.
Raw: [main](../../bench/upstream/test_overhead/body/sql-log-layers-main),
[8.1](../../bench/upstream/test_overhead/body/sql-log-layers-81).

**Inside `notify` and `emit`.** [`sql_log_pieces.rb`](../../bench/upstream/test_overhead/sql_log_pieces.rb), same tool,
per call, A/A ≤ 0.41%, YJIT JIT-flat in every window:

| Piece | Interpreter | YJIT | Where it runs |
| --- | ---: | ---: | --- |
| Subscriber check `consumes?` (logger, `event_method_for`, `log_level_satisfied?`) | 11,778 | 4,839 | `notify`, once per event |
| The same check again before dispatch | 12,283 | 4,811 | `emit` |
| `resolve_payload` for the seven keyword arguments (`transform_keys(&:to_sym)`) | 11,830 | 10,096 | `notify` |
| `EventReporter#debug` → `#notify` with the seven keyword arguments plus two options | 12,930 | 12,092 | hand-off |

So the level check twice (about 24k), the payload copy (about 12k) and the keyword hand-offs (about 13k of the
15.8k) are most of the excess; source location (#59717) is 4.4k; the rest of `notify` (two event hashes, the
subscriber array, tags, context, timestamp, freeze, the emit loop) is about 10k. A per-function Callgrind diff shows
no hotspot: the cost is interpreter dispatch and small-hash work spread over about 100 Ruby and C calls in `notify`
and 50 in `emit` before formatting. Under YJIT the level checks shrink to about 4.8k each, while the payload copy
and the keyword hand-off stay near their interpreter cost (hash building and keyword copying in C).

**What the open PRs close** (`sql_log_body.rb`, main against main with the PR, A/A per cell):

| Tree | Debug, interpreter | Info, interpreter | Debug, YJIT | Share of the 64,385 gap |
| --- | ---: | ---: | ---: | ---: |
| [#58957](https://github.com/rails/rails/pull/58957) head `98ad26a304` | 390,229 → 390,455 (A/A 390,439) | 220,344 → 220,211 | 202,721 → 202,768 | **0%** (inside the A/A) |
| [#59717](https://github.com/rails/rails/pull/59717) head `f4d234e2b5` | 390,226 → 385,774 | 220,423 → 220,479 | 203,140 → 197,869 | **6.9%** |
| Both | 390,118 → 385,791 | 220,436 → 220,354 | 202,741 → 197,822 | **6.7%** (same as #59717) |

#58957 skips handlers whose event no subscriber consumes; at debug the log subscriber consumes `active_record.sql`,
and at info `sql` is already silenced as `debug_only`, so the logged query is unchanged. Raw:
[#58957](../../bench/upstream/test_overhead/body/sql-log-main-vs-58957),
[both](../../bench/upstream/test_overhead/body/sql-log-main-vs-both) (#59717's library changes applied on top of
#58957; no conflict).

**The remaining 93%: no exact fix large enough to open.** Each piece is a few percent of a logged query, and logging
is 3–19% of suite wall time ([above](#suite-wall-time-on-a1xxlarge)), so none moves a suite measurably (DECISIONS,
relevance bar):

* **Held, payload copy.** `resolve_payload` copies keyword arguments with `transform_keys(&:to_sym)`, one
  `Symbol#to_sym` call per key. A `**kwargs` hash is always a fresh Hash (checked on 4.0.10 and master `0d399335b7`),
  so returning it frozen when `kwargs.keys.all?(Symbol)` is exact. CPU time for the seven keys drops from 603 to
  211 ns (orientation only), so an estimated 7–8k of the 11,830 instructions, about 2% of a logged query. No branch built: same order as PM3, which was closed as too small.
* **Held, PM3 stays parked.** The level check runs twice per logged query (`consumes?` in `notify`, again in `emit`);
  PM3 (read the logger once in both, closed 2026-11-05) saves about 2,200 per check, about 1.1% of a logged query.
  The suite context adds reach but not size: no new evidence for reopening.
* **Dropped, skipping `emit`'s recheck.** `notify` stops checking after the first consuming subscriber and `emit` is
  the subscriber's public entry point, so the recheck is needed for every other subscriber and for direct callers.
* **Dropped, keyword hand-off.** Passing the collected keywords on as the positional payload would skip two 9-key
  hash copies, but changes what `notify` and `debug` overrides receive and the error message for event objects
  given keywords; not exact as a plain change.

The large lever stays outside the event code: logging at info in tests (#59330 for new apps; −3.4% to −19.4% suite
wall time in the table above). Recorded, nothing opened.

## Other parts, with decisions

* **Fixtures (median 2.9%).** Accessors are almost entirely the record `find_by!` per test (Fizzy: 2.43% of 2.58%;
  the two `method_missing` hops are under 0.1%). Transactional setup and teardown is 0.3–3.6%, mostly BEGIN/ROLLBACK
  and pool pinning; PT1's scan is a small part of it, so **PT1 stays parked: no new evidence**. Fixture loading
  (0–2.1%) reloads after non-transactional tests by design.
* **Integration session (median 0.8%).** `Rack::Test::Session#request` and its cookie jar are about 1.1% in the
  integration-heavy suites; `Rack::Test::Cookie#expired?` parses the `expires` string with `Time.parse` twice per
  call, 0.14–0.19% of suite CPU in Campfire and Fizzy. **Lead held:** halving it is below 0.1% of a suite, under the
  relevance bar (DECISIONS: a whole test run must move measurably). rack-test 2.3.0 (2026-10-21) is current; the code
  is unchanged on its main.
  If it is ever revisited, the fix belongs in the shared `Cookie#expires` (parse the attribute once, so `expired?`,
  `to_h` and every other caller gain), not a shortcut in `expired?` (DECISIONS, "Fix the shared helper", 2026-11-27).
* **factory_bot (1.4–3.9% own code).** `AttributeAssigner#attribute_names_to_assign` and
  `#attributes_to_set_on_instance` are 1.5% of CASA's CPU. Its maintainer merged three reworks of exactly this path
  today (thoughtbot/factory_bot `4a93822` "Cache a compiled snapshot per factory and traits", `900ab43` "Evaluate
  attributes with a single Evaluator", `6310dd3` "Consolidate attribute and trait resolution in Compiler").
  **Dropped:** DECISIONS, nothing in code a maintainer is reworking.
* **Test frameworks' own code (0.6–2.5%)** and **Active Support setup/teardown callbacks** are spread over many small
  frames; the callbacks mostly run the apps' own setup blocks. Nothing to build; P-TEST 1's note on hook dispatch
  stands.
* **Garbage collection (5.7–11.3%).** Ruby runtime cost of the suites' allocation volume (8,500–53,400 objects per
  test). No exact framework change; GC tuning is an app choice.

## Parallel testing

The profiles run one worker. Separately, Campfire (SQLite) and Hackatime (PostgreSQL) ran with `PARALLEL_WORKERS=4`
and per-worker counters around `Worker#after_fork` (database creation and schema load), the queue loop and
`safe_record` (the DRb round trip that returns each result), Ruby 4.0.10 with YJIT, one run each:

| Per worker | Campfire, 4 workers | Hackatime, 4 workers |
| --- | ---: | ---: |
| Suite window (parent) | 13.7 s (34.6 s with one worker) | 15.6 s (39.0 s with one) |
| Database setup after fork | 0.36–0.41 s (2.6–3.0%) | 0.12–0.15 s (0.8–1.0%) |
| Returning results over DRb | 0.10–0.12 s for 158–159 tests (0.8%) | 0.12 s for 198–199 tests (0.8%) |

The rest of each worker's queue time is idle tail waiting for the slowest worker. **No lead:** the setup is a fixed
cost per worker and the result return is under 1%; neither has an obvious cheaper exact form. Runs are diagnostics on
the shared 8-vCPU orb, not a cohort.

## Findings along the way

* **Fizzy's test boot fails on current Rails main** with `SystemStackError`: its
  `config/initializers/uuid_primary_keys.rb` overrides the internal `build_schema_context` and calls `primary_key`
  from it, and since 0405e2f4af "Move column layout information to the model" (2026-11-23) `primary_key` reads
  `schema_context`, so the override recurses. Class (d) in [app-suites](app-suites.md) terms (the app's use of
  private API); per DECISIONS no Rails restore and no fix in the app. Fizzy is measured on its own pin instead.
* **Campfire and Writebook** ran on main after repinning their copies from their own pin `36e0f96b9d` to `2e299253f9`
  (`bundle lock --update rails --conservative`); suites unchanged in outcome.

## Method, pins and data

* Ruby 4.0.10 (mise), master `0d399335b7` (release build, `--enable-zjit --enable-yjit`, by `script/ruby-differential
  build`). Rails main `2e299253f942ab94041cc6f210ac9d33884c210d`; Fizzy `36e0f96b9d`.
* Apps through `script/ruby-differential setup` with `RDIFF_RAILS` and `RDIFF_CORPUS=censuspt2` (fresh copy and
  template database per run, private Redis, `PARALLEL_WORKERS=1`, `CI=1`, Minitest seed 41231, RSpec defined order,
  browser system tests excluded): Campfire `af4dd9f`, Writebook `7478e2c`, Fizzy `77eada1`, CodeTriage `d1868f8`,
  Hackatime `74deec4`, CASA `b584d2e`, Sure `8d0d84d`, Loomio `407d4a8`, Mastodon `5ccbf0e`.
* Outcomes per suite (identical on both Rubies): Campfire 634 tests, 0 failures, 0 errors; Writebook 310, 1 error;
  Fizzy 1,787, 4 errors; CodeTriage 219 and Hackatime 794, clean; CASA 2,992 examples, 219 failures (220 on master:
  `spec/config/parallel_coverage_spec.rb`, a subprocess coverage spec); Sure 14,236, 15 failures, 22 errors (24 on
  master: two `Provider::JevTest` tests stub `ENV` with Mocha and get `Ractor::IsolationError: can't modify instance
  variables of a shareable Object`, a Ruby master change for the [4.1 differential](ruby41-differential-1.md) to pick
  up); Loomio 3,660, 1 failure, 4 errors; Mastodon 7,748 examples, 277 failures (the known main-only ones). The same
  failures on both Rubies apart from those three.
* Tools: [`suite_profile.rb`](../../bench/upstream/test_overhead/suite_profile.rb) (window, counters, stackprof),
  [`run_suite.rb`](../../bench/upstream/test_overhead/run_suite.rb),
  [`rank.rb`](../../bench/upstream/test_overhead/rank.rb), [`classify.rb`](../../bench/upstream/test_overhead/classify.rb),
  [`wall_rounds.rb`](../../bench/upstream/test_overhead/wall_rounds.rb) and
  [`wall_summary.rb`](../../bench/upstream/test_overhead/wall_summary.rb).
  `ruby bench/upstream/test_overhead/run_suite.rb APP RUBY yjit OUT cpu` reproduces one profile.
* Raw data: per-run window JSON, rank JSON and gzipped folded stacks (`fold.rb`) in
  [`suites/`](../../bench/upstream/test_overhead/suites); the full stackprof dumps (756 MB) are not kept.
* Limits: one profiled run per app and Ruby (sampling, not a cohort); CPU shares, not wall time, except in the
  a1.xxlarge table. Apps run concurrently on this 8-vCPU orb during profiling, which affects wall time but not the
  CPU shares.
