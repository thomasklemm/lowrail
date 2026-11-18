# Profile your own app: `lowrail-profile`

`lowrail-profile` shows where your Rails app spends avoidable work in Rails, Ruby and gems, from inside the app:
it counts the objects allocated per source line while the app serves requests, runs jobs, builds and delivers mail
and handles Action Cable actions (your own test suite, the requests of your `lowrail/workloads.rb`, or any command
that serves requests), and writes the same kind of report as the [census](upstream/census.md), plus two views from
your side:

* **Your code**: for each app line, the objects that Rails, Ruby and gems allocate below it per request, and the
  lines and actions it reaches most, so the report answers "what in my app should I change".
* **Actions**: objects per request for each controller action (and per job, mailer action and channel action), so
  heavy endpoints stand out.

Then the census's view: top lines outside the app by objects per request, grouped by gem, a noise floor from a
repeat run, the app line that leads to each one, and upstream pull requests from Lowrail's
[contributions ledger](upstream/contributions.md) that change that method. `lowrail-profile compare` sets two
reports against each other for CI.

It is a prototype. The census (`script/census app`) instead copies an app, boots it in production and measures the
same workloads file with an A/A pair, instructions, jobs and mailers; [Your own app](../README.md#your-own-app) says
when to use which.

Results are allocation counts, not timings. A line with many objects per request is a place to look, not a
measured speedup.

## Run it

Add the gem to the development and test group, unrequired:

```ruby
gem "lowrail", git: "https://github.com/thomasklemm/lowrail", glob: "gem/*.gemspec", group: [:development, :test], require: false
```

Then, from the app directory:

```sh
bundle exec lowrail-profile -- bin/rails test                      # Minitest: integration, controller, system tests
bundle exec lowrail-profile -- bundle exec rspec spec/requests       # RSpec
bundle exec lowrail-profile --record -- bin/rails test             # the same, and write lowrail/workloads.rb from it
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 \
  bundle exec lowrail-profile --workloads                            # lowrail/workloads.rb's requests, closest to production
bundle exec lowrail-profile report                                   # rebuild the report from tmp/lowrail-profile
bundle exec lowrail-profile compare base/report.json head/report.json  # exit 1 on a regression beyond the noise floor
```

`--workloads [FILE]` (default `lowrail/workloads.rb`) boots the app with `bin/rails runner` in the current
`RAILS_ENV`, evaluates the [workloads file](upstream/census.md#workloads-file) after boot, and sends its requests
10 times as warmup and 20 times counted, in file order, through the full middleware stack: with a browser's
`Accept`, `User-Agent` and `Sec-Fetch-Site` headers under the file's own, its sign-in (a form, or a cookie, signed with the app's key for `signed: true`), CSRF tokens, alternates and
blocks, and the cookies earlier responses set. A status outside a request's `expect:` aborts the run. Its mails and
jobs, and the jobs its requests enqueue, are not run here (they need the census's capture); `workloads.json` in the
output directory holds the file's manifest and lists what was replayed and what was not. Use a disposable database:
the requests are real requests.

`--record [FILE]` records, in the first run, the shape of every routed request: method, route, JSON or XHR, and for
a write one request's params. It then writes the 20 most frequent shapes as a workloads file (default
`lowrail/workloads.rb`, or `tmp/lowrail-profile/workloads.rb` when that file exists): route helpers on each model's
first row (`Article.first!`), GETs ready to run, writes commented out until they are made repeatable (a `setup`
reset, `alternate:` or a block). Shapes are noted after the counting window closes, so recording does not change
the counts. From the Blog's suite (21 tests, 12 requests) it writes:

```ruby
article = Article.first!
comment = Comment.first!

# 2 requests (a write: make it repeatable, then uncomment)
# patch article_path(article), name: "PATCH /articles/:id", params: {"article" => {"body" => "Rails is a web application framework running on the Ruby programming language.", "title" => "Updated Title"}}
# ...
get articles_path, name: "GET /articles"
get article_path(article), name: "GET /articles/:id"
get edit_article_path(article), name: "GET /articles/:id/edit"
get new_article_path, name: "GET /articles/new"
```

That file is what `script/census app` then measures as fixed workloads. `--paths FILE` is gone; a `paths.txt` line
`GET /articles` is `get "/articles"` in the workloads file.

Options (before `--`; everything after it is the command's): `--out DIR` (default `tmp/lowrail-profile`), `--runs N` (default 2; the last run is compared with the
first as the noise floor), `--top N` (default 30), `--seed N` (default 1234, passed as `SEED` and `--seed` to both
runs, so test order repeats), `--ledger PATH` (default: the ledger of the Lowrail checkout the gem comes from).
The first run builds a small C extension into `~/.cache/lowrail/profile/RUBY-BUILD/`; it needs a C compiler and
Ruby's headers, and is built outside the app, never during its boot.

## What it measures

`LOWRAIL_PROFILE` (set by the command, never by you) makes `RUBYOPT=-rlowrail/profile` install:

* an internal `NEWOBJ` hook, the one `ObjectSpace.trace_object_allocations` uses, that keeps a count per file,
  line, object type and kind of window in C memory (no Ruby objects, no retained records; GC stays on);
* windows, so only objects allocated inside one count, each named after what it runs:
  * a request: `Rails::Engine#call`, named by the first controller action it dispatches
    (`ActionController::Metal#dispatch`, so `RoomsController#show`);
  * a job: `ActiveJob::Base#perform_now` (`CachePageJob#perform`), and `ActiveJob::Base.execute` around it so a
    worker's argument deserialization counts too;
  * a mail: its build, `ActionMailer::Base#process` (`ProbeMailer#hello`), and its delivery,
    `ActionMailer::Base.deliver_mail` (`ProbeMailer.deliver_mail`), as two windows because apps often run them
    apart (`deliver_later`);
  * an Action Cable action: `ActionCable::Channel::Base#perform_action` (named by the action in the message) and
    `#subscribe_to_channel` (`RoomChannel#subscribed`).

  Each is prepended from Active Support's on_load hook for its framework class (`before_configuration`,
  `action_controller`, `active_job`, `action_mailer`, `action_cable_channel`), so nothing loads earlier than the
  app loads it, and a framework the app never loads is never hooked. A window inside another (a job performed
  inline, a mail delivered inside a request) counts as part of the outer one, so a request's numbers include the
  jobs and mail it runs and jobs, mails and Cable actions reported apart are the ones that ran on their own;
* an `at_exit` writer (one TSV per process; forked test workers reset their counts and write their own).

The repeat run also records, for every allocation inside a window, the nearest frame in the app's own code (under
the app root, outside `test/`, `spec/` and vendored gems) and the window's name. It reads the stack with
`rb_profile_frames`, which allocates nothing, so its counts stay comparable to the first run's; walking the stack
on every allocation is what costs time (below).

The report has these views:

* **Your code**: per app line, the warm objects per request that Rails, Ruby and gem code below it allocates (its
  own allocations apart, in Own), dev/test-only work apart, the lines it reaches most and the actions it runs in.
  App middleware that only hands the request on (`@app.call(env)`) is the nearest app frame of the whole stack
  below it, so it is listed under the table, not ranked. A last line gives the objects with no app line on the
  stack (middleware, routing, rendering setup).
* **Actions**: per controller action, objects per request (everything the request allocates) by run, its
  run-to-run Δ, and the lines outside the app and app lines it reaches most. Warm leaves out the action's first
  request in each process; an action that ran once per process has no warm value and is listed last.
* **Top lines outside the app**, as before:
  * **Warm/req**: objects per request, leaving out each line's first request per process. That removes one-time
    lazy work (route table build, template compilation, I18n load) which the census removes with 50 warmup
    operations. **All/req** keeps it.
  * **Reach**: the share of requests in which the line allocated.
  * **Δ**: last run minus first. The noise floor line summarizes it for the top lines.
  * **From the app**: the nearest app lines on the stack (repeat run).
  * **†**: Ruby's own `<internal:…>` code (Pathname, `Kernel#tap`) allocated it and is charged to its nearest caller
    outside such code. The census charges these to `<internal:…>` lines instead.
  * **Ledger**: [below](#ledger-matches).
* **Dev/test-mode work** gets its own table: debug logging, error pages, template compilation (Action View, erubi,
  Herb, Temple, Slim, Haml), route building, asset lookup (Propshaft, importmap, Sprockets compiling live, Vite Ruby
  checking its build with `autoBuild`) and code reload checks (`FileUpdateChecker`), which test and development mode
  do and production mostly does not. rack-mini-profiler (Lobsters, CodeTriage) stays ranked: both apps load it in
  every environment.
* **By gem**, and **Outside requests**: jobs, mails and Action Cable actions, each with its own action table and
  top lines, per window instead of per request.

Keys follow the census (`RAILS/actionpack/lib/…`, `GEM/name/path`, `RUBY/path`), so a report can be set against
`script/census rank`. Test runners and clients (minitest, rspec, rack-test, capybara) are left out, as the census
leaves out rack-test.

Not measured: instructions or CPU samples. Per-line instructions need Callgrind, which is
[`script/cpu-census`](upstream/census.md#cpu-census-scriptcpu-census)'s job; a sampling profiler from inside the app
was left out of this prototype. Per-request instructions from a hardware counter (`perf_event_open`, user space)
were planned but not built: in the orb this was developed in, `perf_event_open` for
`PERF_COUNT_HW_INSTRUCTIONS` fails with `ENOENT` (no PMU exposed to the VM; only software events open), so the
counting path could not be checked anywhere it would ship from.

### Ledger matches

A line gets a ledger entry when an upstream pull request linked from the
[contributions ledger](upstream/contributions.md) reduces allocations or time and changes that very line.
`script/profile-ledger` reads each linked pull request from GitHub into
[contributions-index.json](upstream/contributions-index.json): its state, merge date, the oldest of the repository's
30 newest release tags that contains its merge commit, and per file and method the code lines it removes and adds.
It marks a pull request as allocation work when its ledger entry reports objects, allocations, instructions or time
and is not a correctness or compatibility fix. The report then needs all of:

* the same repository: `RAILS/actionpack/lib/…` is `rails/rails` `actionpack/lib/…`, `GEM/name/…` the repository
  named like the gem, `RUBY/…` (and default gems) `ruby/ruby`;
* the same file and the same method;
* the line's own code among the lines the pull request removes or adds in that method.

and says what the pull request means for the version the app runs:

* **open upstream work**: still open, and the app's line is one it removes;
* **fixed in VERSION**: the app's line is one it removes, and it was first released in VERSION, newer than the gem
  version the app locks;
* **fixed in VERSION, after this app's revision**: the same for a gem the app takes from git;
* **merged DATE, after this app's version, not released yet**: the app's line is one it removes, so the app runs
  the code from before it;
* **merged, in VERSION, which this app runs**: the app's line is one it adds and the app's version is VERSION or newer.
  An added line in a git checkout or before any release is left out, because the same code can stand in the app's
  older version too.

On Campfire's report (Rails main `e3d5c569`, 300 top lines) this gives 21 matches. Each was checked by hand against
the pull request's diff: in every one the app's line is a line the pull request removes, in the method it changes.
The text match it replaces had 50, among them a pull request on `Array#to_query` matched to `Object#to_query` in the
same file, a correctness fix (#59634) matched through the same code in another method, and another author's pull
request the ledger only mentions. A backport merged as its own commit (Rails stable branches) is not found by merge
commit, so such a fix shows as not released. Rebuild the index with `script/profile-ledger` after the ledger
changes (`--missing` after GitHub's rate limit stops it).

## Compare two reports in CI

`lowrail-profile compare BASE.json HEAD.json` sets the `report.json` of two profiles against each other, per line
outside the app and per action (requests, jobs, mails and Cable actions apart), on warm objects per request. It
exits 1 when anything grew beyond its noise floor, 0 otherwise; `--json` prints the changes as JSON, `--min N`
(default 1) sets the smallest change that counts.

* A line's noise floor is the larger of its run-to-run difference in either report and `--min`.
* An action's is the largest of twice its run-to-run difference, 0.1% of its objects per request and 20 × `--min`,
  because parallel test workers split an action's requests differently from one invocation to the next, which the
  difference inside one invocation does not show. Actions that ran once per process have no warm value and are not
  compared.

On Campfire's suite an A/A pair (two invocations on the same code) has no changes beyond the floor (the largest
action move was 6.5 objects, 0.08%), and adding `20.times { ERB::Util.html_escape("a<b") }` to
`RoomsController#show` gives 3 regressions and exit 1: the action (+46.35 per request against a floor of 26.48) and
the two Active Support lines it calls (+1.68 per request each over all requests, floor 1.0), and nothing else.

A GitHub Actions job that profiles the pull request's base and head with the same command and fails on a
regression:

```yaml
lowrail-profile:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with: { fetch-depth: 0 }
    - uses: ruby/setup-ruby@v1
      with: { bundler-cache: true }
    - name: Profile base
      run: |
        git checkout ${{ github.event.pull_request.base.sha }}
        bin/rails db:test:prepare
        bundle exec lowrail-profile --out tmp/base -- bin/rails test
    - name: Profile head
      run: |
        git checkout ${{ github.event.pull_request.head.sha }}
        bin/rails db:test:prepare
        bundle exec lowrail-profile --out tmp/head -- bin/rails test
    - name: Compare
      run: bundle exec lowrail-profile compare tmp/base/report.json tmp/head/report.json | tee -a "$GITHUB_STEP_SUMMARY"
```

Both checkouts need the gem in their Gemfile; if the base does not have it yet, run the base step from the head's
Gemfile (`BUNDLE_GEMFILE`). A suite whose tests fail still profiles; check the suite in its own job.

## Safety

With the gem in the Gemfile and `require: false`, an app that does not run `lowrail-profile` loads none of
Lowrail. The gemspec no longer requires `lib/lowrail.rb` (Bundler evaluates a path or git gem's gemspec in every
process). When the command runs it, any failure to load the counter prints one warning and leaves the app as it is,
and a failure to write the report never changes the exit status.

Checked on five apps' own suites (fresh `script/corpus APP DIR --source-only` copies at their corpus pins, each
suite run the way its CI runs it, with the request, job, mail and Action Cable hooks above). Each suite ran three
ways: without the gem, with the gem in a copy of the Gemfile but not run ("off"), and through `lowrail-profile`
(both runs), with `$LOADED_FEATURES` dumped at exit from every process and seed 1234 throughout:

| App, suite | Ruby, Rails | Tests | Outcomes (plain = off = run 1 = run 2) | Suite time: plain, off, run 1, run 2 | Wall: plain, profiled (2 runs + report) |
| --- | --- | ---: | --- | --- | --- |
| Campfire, `bin/rails test -v` (2 workers) | 4.0.7, main `e3d5c569` | 634 | identical per test: 632 pass, 2 skip | 18.4, 17.7, 17.9, 26.7 s | 20.9, 57.3 s |
| Lobsters, `bundle exec rspec --format documentation` | 4.0.9 (YJIT), 8.1.3.1 | 927 | identical per example (timestamps and random tokens masked): 0 failures | 29.7, 29.5, 31.2, 36.2 s | 33.6, 84.8 s |
| Writebook, `bin/rails test -v` (2 workers) | 4.0.7, main | 310 | identical per test: 307 pass, 2 skip, 1 error | 26.5, 26.2, 27.0, 32.1 s | 28.7, 67.2 s |
| Pingcrm, `bin/rails test:all -v` (system tests, headless Chrome) | 4.0.7, 8.1.4 | 26 | identical per test: 26 pass | 14.0, 13.8, 15.5, 14.2 s | 15.2, 33.0 s |
| CodeTriage, `bin/rails test --verbose` | 4.0.7, 8.1.4 | 222 | identical per test for the 217 that print a line, totals 222 everywhere: 0 failures | 4.7, 4.3, 4.7, 6.0 s | 6.8, 16.7 s |

* Writebook's one error (`ActiveStorageAuthorizationTest`, `URI::Generic#request_uri`) happens without the gem too.
* Load order: in every process of every app, every feature outside Lowrail, RubyGems and Bundler loads in the same
  order in all setups. Profiled processes miss RubyGems files (`bundler_version_finder.rb`, for Lobsters also
  `request_set/…`) that `bundle exec lowrail-profile` loaded in the parent already. CodeTriage's yard loads its
  handlers in directory order, which already differs between plain and off; without them the order matches.
* Overhead: the first run (counting only) costs 0–11% of suite time. The repeat run walks the stack on every
  allocation to find the app frame and costs 1–45% (Campfire's suite, at 19,400 objects per request, the most).
* `--record` notes a request's shape after the counting window closes and requires `json` only at exit, when
  Bundler has long set up. On the Blog's suite (21 tests, Rails 8.1.4) per-test outcomes are identical plain and
  under `--record`.

## Proof on two corpus apps

Both apps are the census copies (`script/census setup --rails main`, Rails main `4500a94c34`, Ruby 4.0.9) with the
gem added to a copy of the census Gemfile, and compared with a census A/A pair on the same copies
(`script/census run --label base --aa --apps blog,campfire --modes interp`, compared against `base2`). Overlap is
how many of the census's top N lines (mean objects per operation over the app's workloads, `<internal:…>` lines and
the harness left out) are in the profile's top N. The census's own A/A overlap is the ceiling.

| Workload | Requests | Top 10 | Top 20 | Top 50 | Rails top 20 | Census A/A top 20 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Blog, own suite (`bin/rails test`, test env) | 12 | 5 | 10 | 23 | 7 | 20 (Rails 18) |
| Blog, own suite, dev/test lines left out | 12 | 5 | 13 | 26 | 11 | |
| Campfire, own suite (`bin/rails test`, 2 workers) | 666 | 6 | 13 | 30 | 5 | 20 (Rails 20) |
| Campfire, own suite, dev/test lines left out | 666 | 9 | 17 | 37 | 8 | |
| Blog, the census's 5 GETs replayed in production, vs the census's 5 GET workloads | 100 | 9 | 16 | 45 | 19 | 20 (Rails 19) |

**Where they agree.** Lines both reach have nearly the same cost per request. Replaying the same GETs in production (then `--paths`, now `--workloads`; [below](#workloads-against---paths)), the
counts match the census within about 1%: `useragent` `browsers/base.rb:120` 32.67 against 33.00,
`output_safety.rb:245` 30.81 against 31.40, `sqlite3` `statement.rb:143` 18.66 against 19.00. The 1% is the warm
column leaving out each line's first of 100 requests. On Campfire's suite the same `uri` and `rack` lines lead both
rankings (`uri/generic.rb:1007` first in both, 531 against 428 objects per request; `url.rb:361` 266 against 211),
because Campfire's content security policy parses every importmap URL on every page; the profile names the app line,
`inline_script_hashes.rb:40`. `where_clause.rb:22/32` costs 37 and 39 per request in the suite against 41 and 40 in
the census.

**Why they differ.**

* **Development and test mode.** Test mode logs at debug level (`log_subscriber.rb:40` `binds.inspect`,
  `colorize_logging.rb`, `event_reporter.rb:459` `caller_locations`), renders error pages
  (`error_highlight` and Prism parse the failing file: 1,987 objects per request on the 2% of Campfire requests that
  raise, from `fetch_metadata_test.rb:55`), and does not cache asset lookups (`importmap/map.rb:279`,
  `propshaft/helper.rb:113`). The census runs in production at log level fatal and never ranks these. They are 5,629
  of Campfire's 13,617 warm objects per request outside the app; leaving them out raises the overlap
  (13 → 17 of 20).
* **The workload.** A suite requests what its tests need, not a request mix. In 5 of the Blog's 12 requests
  the suite reaches I18n lookups (with `MissingTranslation` fallbacks), so I18n lines lead its profile (`i18n/backend/base.rb:157` 39 per request
  against 17 in the census). Its tests send Rails' `Rails Testing` user agent, not a browser's, and the `useragent` lines that the
  census (Firefox header, through the app's `allow_browser`) ranks 2nd and 3rd are absent; the replay, which sends the census's Firefox header, finds them at the census's cost. Compared only
  with the census's GET workloads, the Blog suite overlaps in 2 of 20 lines, the replay in 16.
* **Attribution.** Lines marked † are charged from Pathname and other `<internal:…>` code to their caller; the
  census keeps them on the internal line (`propshaft/helper.rb:113` 23.6 against 1.8 in production for this reason).
* **Unexplained.** `uri/common.rb:465` (`_decode_uri_component`) costs 28.5 per GET in the census and 10.2 in the
  replay; the census's rack-test cookie jar is a plausible cause, not checked.

The noise floor is small in every run: median |Δ| 0.0, max 1.17 objects per request over Campfire's top 40 lines
(`json/common.rb:297`), 0.63 for the Blog's replay, 0.0 for the Blog's suite.

## `--workloads` against `--paths`

The Blog's census copy in production (Rails 8.1.4, Ruby 4.0.9; production mode turns YJIT on, the same for both),
the five GETs once as `paths.txt` through the previous `--paths` and once as five `get` lines through
`--workloads`: 100 counted requests each, 2,660.07 and 2,659.68 objects per request in the first run. The same
878 lines are ranked, the top 10, 20 and 50 are the same lines, and no line differs by 0.5 objects per request or
more (largest: `uri/common.rb:456` and `:465`, −0.35 and −0.33, against a noise floor of 0.18 and 0.30). The
whole Blog file (its nine requests, writes included) replays as 180 counted requests; its job is listed as not
replayed.
