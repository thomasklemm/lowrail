# lowrail-profile compare: false alarms on one-process suites (2026-11-27)

[Field test](../census-field-test/README.md) item 4: compare false-alarmed on unchanged one-process captures, CASA
in 20% of compares (6.7% of the README's CI jobs), Hackatime with 1 worker 12.5% (4.4%), Writebook with 4 workers
2.5% (0.56%). The record guessed record IDs in URLs. This round finds the cause of every alarming row, fixes what
lowrail-profile can fix exactly ([`fc460a81`](https://github.com/thomasklemm/lowrail/commit/fc460a81), reviewed as
`15ee2407` before the rebase, same patch), and documents the rest.

**Result:**

* **Hackatime:** what `Socket.tcp` allocates while it connects, which the counter mixed into actions, is now counted
  apart. Six new captures with the changed gem give **0 false alarms in 120 compares and 0 in 360 CI jobs**, against
  12.5% / 3.33% for six captures with the parent's gem. The plant is caught in 85% / 83% of them, the same with the
  old and new compare (field test: 51.67% / 50%). Two causes remain that are the app's own wall clock (a WebMock
  cache keyed by a URL with the current second, and hour buckets of the last 24 hours). They did not fire in these
  six captures but did in others (8.5% of compares over nine captures). compare still lists them, since the
  requests did different work.
* **CASA:** record IDs grow when the database is not reset between captures. The README now says to reset it before
  every capture, and the CI job does. With resets the record-ID rows are gone, but the false-alarm rate is not lower
  (22.5% / 5.0%). Other actions alarm instead, by 30 to 90 objects, most of it Sprockets resolving the layout's
  favicons in some requests and not others. That cause is **not found**: clearing Sprockets' disk cache and turning
  code reloading off (`CI=1`) both leave it (25% of 24 compares and 0 of 24 CI jobs with `CI=1`). Plant 100%.
* **Writebook with 4 workers:** its alarms come from its worker processes, which compare refuses since `abf515d3`.
  In one process it had 0 false alarms in the field test.

## Causes

Each confirmed on captures, with the attribution of a kept run (`--keep-runs`, [scripts/attribution.rb](scripts/attribution.rb)), except the one marked not found. [evidence/](evidence) keeps the attribution output each quoted per-site number comes from, with the capture, run and action; the raw runs it read are not kept.

| App | Alarming rows | Cause | Confirmed by | Fix |
| --- | --- | --- | --- | --- |
| Hackatime | `Admin::AdminUsersController#index`, `CustomDoorkeeper::AuthorizationsController#create`, `Doorkeeper::ApplicationsController#index`, `RUBY/socket.rb:72` | inertia's SSR check asks ViteRuby `dev_server_running?`, a `Socket.tcp` probe cached for one second: whichever request comes first after each second pays about 400 objects in Ruby's `socket.rb` | `Admin::AdminUsersController#index`, d1 run 1 vs run 2: `socket.rb:79` 0 vs 57 objects per warm window ([evidence](evidence/hackatime-d1-admin-users-index.txt)); `Doorkeeper::ApplicationsController#index` jumps by about 390 (8,116–8,130 vs 8,504–8,522 in the HEAD-gem captures) and stays within 8,102–8,146 once socket.rb is counted apart | counted apart (`fc460a81`) |
| CASA | `ChecklistItemsController#new` and `#edit`, `uri/common.rb:456` | record IDs grow from capture to capture (the database is not reset), and their digits change what URI encoding allocates | every sequence set to 9,000 and then 100,000 ([scripts/casa_ids.sh](scripts/casa_ids.sh)): `#new` 3,511 / 3,514 vs 3,494 / 3,494 warm objects (report.json, runs 1 / 2), and in run 2 `uri/common.rb:456` 24 vs 3 per warm window ([evidence](evidence/casa-ids9k-ids100k-checklist-items-new.txt)); the rows are gone from captures that run `db:test:prepare` first | README: reset before every capture (`fc460a81`) |
| CASA | `JudgesController#edit`, `CaseCourtReportsController#index`, `CaseContacts::FormController#new`, `CaseContactsController#index`, `NotificationsController#index`; with `CI=1` `ContactTypesController#new`, `ReportsController#index` (seen once the IDs no longer differ) | **not found.** The difference is mostly Sprockets resolving the layout's favicons (`_favicons.html.erb`, 14 lookups): `sprockets/resolve.rb:193` 29.5 vs 0 objects per warm window of `JudgesController#edit`, r6 run 2 vs r5 run 2 ([evidence](evidence/casa-r6-r5-judges-edit.txt)), and the same 29.5 vs 0 for `ContactTypesController#new` with `CI=1`, ci3 run 2 vs ci1 run 2 ([evidence](evidence/casa-ci3-ci1-contact-types-new.txt)), while the suite's mean at that line stays at 2.3–2.6 per request in every run; so which requests pay it moves, not how much | not Sprockets' disk cache: clearing `tmp/cache/assets` before every run (z1: `JudgesController#edit` 8,327 then 8,252) leaves it (alone, `judges_spec.rb` reads 13,620–13,637 with the cache kept and 13,596–13,637 cleared, [scripts/casa_sprockets.sh](scripts/casa_sprockets.sh)); not reloading: `CI=1` (no reloading, one cached Sprockets environment) drops 2,700–4,200 objects per request but still alarms (ci1–ci4) | none yet |
| Hackatime | `addressable/uri.rb:424`, `PullRepoCommitsJob#perform` | the job's URL has `since: 3.days.ago.iso8601`, and WebMock caches URI normalisation by URL; the test runs the job twice, so the second run is cheap only when both fall in the same second | [scripts/webmock_cache.rb](scripts/webmock_cache.rb) with Hackatime's WebMock 3.26.4 and Addressable 2.9.0: 551 objects for a new URL, 36 for the same URL again, 551 for the next second ([output](evidence/webmock-cache.txt)); the counts depend on the version (3.34.0 gives 748 / 39 / 748), the mechanism does not | none: the app's own wall clock |
| Hackatime | `My::ProjectRepoMappingsController#index` | `Cache::ActiveUsersGraphDataJob` buckets the last 24 hours of heartbeats by hour (`24.hours.ago`), so the rows it reads depend on the time of day | n1–n2 read about 9,432, n4–n9 about 9,460; n3's second run, which crossed 12:00, read 9,472; n1 run 2 vs n4 run 2: `active_record/attribute_methods.rb:484` called from `app/jobs/cache/active_users_graph_data_job.rb` 9 vs 18 per warm window ([evidence](evidence/hackatime-n1-n4-project-repo-mappings-index.txt)) | none: the app's own wall clock |
| Writebook, 4 workers | `PagesController#create` | which worker serves which test: compare refuses captures of more than one process since `abf515d3` (the replay here skips that check, as the field test's did) | Writebook in one process: 0 false alarms in 120 compares | none needed |

Neither wall-clock cause is lowrail-profile's to normalise: the request did more work, and a real change in that
code would look the same. A suite that freezes time (`travel_to`) does not have them.

## Numbers

[scripts/replay.sh](scripts/replay.sh) writes [results.txt](results.txt) from [captures.tar.xz](captures.tar.xz) and
the field test's reports: the field test's gate replay ([scripts/gate.rb](scripts/gate.rb), the census record's
`gate.rb` reading every report as the current format, plus `IGNORE` for analysis) over every assignment of the
unchanged captures to base, A/A and head (one compare), and base, A/A, head and a second head (the CI job). It runs
compare before (`16b53491`) and after (this change). The plant is the field test's
`20.times { ERB::Util.html_escape("a<b") }` in the same action. Before and after give the same numbers on every set:
compare reads what the counter recorded, and the change is in the counter.

| Captures (gem that recorded them) | False alarms: one / CI job | Plant: one / CI job |
| --- | ---: | ---: |
| Field test CASA, recorded (rc1) | 20% / 6.67% | 100% / 100% |
| Field test Hackatime 1 worker, recorded (rc1) | 12.5% / 4.44% | 51.67% / 50% |
| Field test Writebook 4 workers, recorded (rc1) | 2.5% / 0.56% | 0 / 0 |
| Field test Writebook 1 process, recorded (rc1) | 0 / 0 | 100% / 100% |
| Hackatime h2–h6, d1 (`16b53491`) | 12.5% / 3.33% | – |
| **Hackatime g1–g6, gp1–gp2 (this change's counter; see Files)** | **0 / 0** | 85% / 83.33% |
| Hackatime n1–n9, np1–np2 (intermediate: socket.rb left out by file) | 8.53% / 2.91% | 97.22% / 94.44% |
| Hackatime h2–h6, d1, wall-clock rows left out | 7.5% / 0 | |
| Hackatime g1–g6, wall-clock rows left out | 0 / 0 | |
| Hackatime n1–n9, wall-clock rows left out | 0.6% / 0 | |
| CASA r1–r6, rp1, `db:test:prepare` each | 22.5% / 5.0% | 100% / – |
| CASA ci1–ci4, cip1, `CI=1` and `db:test:prepare` | 25% / 0 (of 24 / 24) | 100% (12 of 12) / – |

The plant rates differ between the Hackatime sets: 51.67% / 50% in the field test, 97% / 94% for `n*`, 85% / 83.33%
for `g*`. I did not find why. No threshold formula changed, but this is not a proof that plant detection cannot
drop: moving objects out of an action changes its means and its spread, and with that its noise floor, in either
direction. What is measured is the cohorts above.

## Where instruction counts would help

Thread `T-01a21c9f-2b7b-77a1-9528-b3b6e3f690a6` prototypes Callgrind instruction counts for Duel: per sample, for
the whole process, exact within one process and about 0.34% apart between processes. For compare they would say
whether an allocation change costs anything: an extra 80 objects of Sprockets cache lookups and a planted
`html_escape` loop are both "objects", and only instructions tell their cost. They would not remove any cause above:
a socket probe, a cold WebMock cache and an extra hour bucket all execute instructions too, so the same requests
would move. And compare works per action, so it would need counts per window (per request), which the prototype
does not produce.

## Files

* [captures.tar.xz](captures.tar.xz): the report.json of every capture above. Hackatime: `h*`, `d1` with the
  parent's gem (`d1` attributed both runs, `Gemfile.diag`), `n*`, `np*` with an intermediate counter that left out
  allocations by socket.rb's path, `g*`, `gp*` with this change's counter. `g*` are not one immutable pin: they
  loaded the gem from the live checkout while its Ruby wrapper changed. `g1`–`g3` ran fe85e96a's `profile.rb`; during
  `g4` (around 13:30 UTC) the `Profile.main?` guard of 15ee2407 went in, with a stash and restore of `profile.rb`
  for its negative test; `g5`, `g6`, `gp1`, `gp2` ran 15ee2407's. The C counter was the same in all of them. The
  guard only returns early outside the main Ractor, and Hackatime's suite runs in the main Ractor, so the counts are
  expected to be the same; the source of each capture is not hashed. CASA: `r*`, `rp1`, `ids9k`, `ids100k`, `k*`,
  `x*` with the intermediate counter, `z1`, `ci*`, `cip1` with `bcabbf76` (the first review round). CASA made no
  connects (`network` 0 in every run), so its captures count the same under every version. The raw runs
  (`--keep-runs`, 1.5 GB) are not kept.
* [scripts/](scripts): the capture scripts (paths as on the orb; Ruby 4.0.7, Postgres 17, apps from `.corpus`), the
  replay, the attribution diff ([scripts/attribution.rb](scripts/attribution.rb)) and the WebMock check.
* Harness note: two Hackatime captures with this change's gem failed `WeeklySummaryEmailJobTest` (3 jobs instead of
  2). A user row was left in the shared test database by a capture stopped midway. The suite passes plain with seed
  1234 on a clean database, and `g*` load the schema before each capture.
