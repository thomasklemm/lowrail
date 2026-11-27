# Rails 8.2 pre-beta round: Rails main against 8.1.4.1 (2026-11-27)

Rails main `088fc0cf61` against v8.1.4.1 `3f290b759c`, on the census apps of the hot-lines run (same setup:
`bench/upstream/rails_main_hotlines/run.sh`, lowrail-profile, two profiled runs per tree), plus a heavy slice
(casa, chatwoot, discourse, flow, loomio, mastodon, sure; [slice record](../../bench/upstream/rails_main_hotlines/slice-casa-chatwoot-discourse-flow-loomio-mastodon-sure.md)),
the weekly boot census ([rails-main-boot-2026-11-27](rails-main-boot-2026-11-27.md)), census 12
([rails-main-census-12](rails-main-census-12.md)) and the lowrail-profile field test's three leads.
Outcome tables: `bench/upstream/rails_main_hotlines/compare-light.md` (plain), `compare-adapted.md` (gem adaptations
from `adapt/APP.sh`), `compare-main.md` and `compare-m2.md` (heavy slice).

## Items (pr-queue)

| Rank | Item | Kind | Cause | State |
| ---: | --- | --- | --- | --- |
| 1 | ATF1, Action Text `Attachment.from_node` overrides skipped | fix | #58173 | open, rails/rails#60006 |
| 2 | AM4, Action Mailer test helper requires Active Job | fix | #59820 | open, rails/rails#60013 |
| 3 | UG82D, upgrade guide: models can't define a `default_order` scope | docs | #39525 | open, rails/rails#60005 |
| – | DV1, compile the debug page's templates once | perf | DebugView (old); Herb default #58721 heavier | held: relevance |

ATF1: Campfire's 9 failures on main (ContentFiltersTest 6, RoomsControllerTest link previews 3) all pass on its head.
AM4: Discourse's whole spec suite fails on main with LoadError active_job. UG82D: Flow errors in 409 of 452 tests.
Each was reviewed by thermos-sol and Astra on its exact head and body.

DV1: every debug page and blocked-host page builds a new resolver, so DebugView compiles its 8 rescue templates and
defines 8 methods again each time (both trees); with source extracts stubbed, 7,998 objects per page on 8.1.4.1,
15,712 on main, 4,518 with DV1. Reach: 27 debug pages in 1,990 tests across nine census suites
(`field/reach/SUMMARY.txt`), well under a second per suite. Held; branch kept.

## Regressions classified as app or gem adaptations (inventory, no PR)

| App | Failure on main | Cause | Resolution |
| --- | --- | --- | --- |
| hackatime | blind_index 2.8.1 FrozenError on TableMetadata | frozen TableMetadata | blind_index master ac61e54cf4 (BI1), unreleased; adapted: 794/0 |
| lobsters | rspec-rails 8.0 FrozenError on default_url_options; then activerecord-typedstore 1.6.0 `has no attribute ... to define a reader for` | #59141 (deliberate) | rspec-rails 8.1 (SP1); typedstore master 263050a196 (#114), unreleased; adapted: 927/0 |
| react-starter-kit | rspec-rails 8.0 FrozenError | as lobsters | rspec-rails 8.1; adapted: 35/0 |
| redprints-cfp | leaked rows (pin_connection! no longer begins a transaction) | #58306 | test-prof 1.6.4; adapted: 50/0 |
| thinkroom | stub_connection builds the real Connection class | #50979 (deliberate) | app adapts, one test |
| codetriage | `include ActiveJob::TestHelper::TestQueueAdapter` leaks state | refactor 77b6966720 | app adapts (codetriage copies only) |
| casa, flow, sure | bundle conflict on marcel 2 | #58549 (deliberate) | caxlsx #542 merged, unreleased; lookbook 2.3.15; flow's pin |
| casa | amazing_print 2.0.0 colorize_logging | #55900 (deliberate) | amazing_print 3.0.0 |
| mastodon | `filter_proxies` (1,900 failures), `build_bind_attribute` (53) | #56805, #58479, private API | app adapts; our R1, ZM1 closed |
| sure | 91 errors from bind params in array-form find_by_sql (`DATE :x`, `date >= integer`) | #58427 (deliberate, CHANGELOG) | casts; our open #59565 hints the syntax-error case |
| discourse (behind AM4) | `RSpec::Mocks::ArgumentMatchers` missing | #59820 + transitive require | app adapts |

Not main-only: chatwoot (Rails 7.2 lock, unresolvable on both trees), mastodon's 7 Vary-header failures (8.1.4.1's
7a955ca367), pingcrm's 25 errors (fail on both trees). Boot census: no new breaks in 20 apps.

## Performance on main

From census 12 (71 workloads, fixed heap, A/A median −0.02%): main against 8.1.4.1 is −8.54% median interpreter
instructions per request (69 faster, 1 slower), −614 objects (71/71 lower); YJIT −12.62% over JIT-flat windows.
The one slowdown, codetriage's mail job +3.4%, is #56213 (debug_mode follows log_level; deliberate).
Since census 11: `cache_quoted_name` +0.054% (below the bar); redprints-cfp mailer +2.4% not attributed to a commit.

Field-test leads: CSP `validate` gsub fixed on main by #59286 (51 → 32 objects per build); `Time#change` Rational
fixed by #59323 (6 → 2 objects); both unreleased (`field/alloc_probe.rb`, `results.txt`). Debug-page source
extracts (about 113k objects per page on both trees) are old cost; lazy extracts would change the page. Lead only.

## Ranking of open leads (no owner, not built)

Shares are census-12 ceilings, not prices.

1. Query-cache store hashes the `[sql, binds]` key twice per hit (`Store#compute_if_absent`/`#[]` delete and
   reinsert): 1.09% mean, 67/71. Most of the cost is bind hashing, which open #59518 memoizes; price after it lands.
2. `IsolatedExecutionState.[]` and connection lookup: 1.01% and 0.81%, 68/71; `connected_to_stack` read again for
   role, shard and preventing_writes. Needs pricing.
3. `build_request` env_config merge: 0.35%, max 3.0%. Needs pricing.

Owned elsewhere: notifications fan-out (#58957), tag options (#57999; our TO1 held), InheritableOptions (OO1 held),
parameter filtering (#58958).
