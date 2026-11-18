# Profile your own app: `lowrail-profile`

`lowrail-profile` shows where your Rails app spends avoidable work in Rails, Ruby and gems, from inside the app:
it counts the objects allocated per source line while the app serves requests (your own test suite, the requests
of your `lowrail/workloads.rb`, or any command that serves requests), and writes the same kind of report as the
[census](upstream/census.md): top lines by objects per request, grouped by gem, a noise floor from a repeat run,
the app line that leads to each one, and matching entries of Lowrail's [contributions ledger](upstream/contributions.md).

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

Options: `--out DIR` (default `tmp/lowrail-profile`), `--runs N` (default 2; the last run is compared with the
first as the noise floor), `--top N` (default 30), `--seed N` (default 1234, passed as `SEED` and `--seed` to both
runs, so test order repeats), `--ledger PATH` (default: the ledger of the Lowrail checkout the gem comes from).
The first run builds a small C extension into `~/.cache/lowrail/profile/RUBY-BUILD/`; it needs a C compiler and
Ruby's headers, and is built outside the app, never during its boot.

## What it measures

`LOWRAIL_PROFILE` (set by the command, never by you) makes `RUBYOPT=-rlowrail/profile` install three things:

* an internal `NEWOBJ` hook, the one `ObjectSpace.trace_object_allocations` uses, that keeps a count per file,
  line and object type in C memory (no Ruby objects, no retained records; GC stays on);
* a window around `Rails::Engine#call`, so only objects allocated while a request is served count. It is prepended
  from Active Support's `before_configuration` hook, so nothing loads earlier than the app loads it;
* an `at_exit` writer (one TSV per process; forked test workers reset their counts and write their own).

The report then ranks lines outside the app:

* **Warm/req**: objects per request, leaving out each line's first request per process. That removes one-time
  lazy work (route table build, template compilation, I18n load) which the census removes with 50 warmup
  operations. **All/req** keeps it.
* **Reach**: the share of requests in which the line allocated.
* **Δ**: last run minus first. The noise floor line summarizes it for the top lines.
* **From the app**: the repeat run watches the first run's top lines and records the nearest app frame on the
  stack for each of their allocations, without allocating, so its counts stay comparable to the first run's.
* **†**: Ruby's own `<internal:…>` code (Pathname, `Kernel#tap`) allocated it and is charged to its nearest caller
  outside such code. The census charges these to `<internal:…>` lines instead.
* **Ledger**: entries that name the line's method in a code span and also name its file, gem or Rails component.
  This is a text match, so treat it as a lead to read, not a confirmed match.
* **Dev/test-mode work** gets its own table: debug logging, error pages, template compilation, route building and
  asset lookup, which test and development mode do and production mostly does not.

Keys follow the census (`RAILS/actionpack/lib/…`, `GEM/name/path`, `RUBY/path`), so a report can be set against
`script/census rank`. Test runners and clients (minitest, rspec, rack-test, capybara) are left out, as the census
leaves out rack-test.

Not measured: instructions or CPU samples. Per-line instructions need Callgrind, which is
[`script/cpu-census`](upstream/census.md#cpu-census-scriptcpu-census)'s job; a sampling profiler from inside the app
was left out of this prototype.

## Safety

With the gem in the Gemfile and `require: false`, an app that does not run `lowrail-profile` loads none of
Lowrail. The gemspec no longer requires `lib/lowrail.rb` (Bundler evaluates a path or git gem's gemspec in every
process). When the command runs it, any failure to load the counter prints one warning and leaves the app as it is,
and a failure to write the report never changes the exit status.

Checked on Campfire's suite (634 tests, 2 forked workers, Rails main `4500a94c34`, Ruby 4.0.9), with
`$LOADED_FEATURES` dumped at exit from every process (the two workers and two helper processes):

* Per-test outcomes, names and results, are identical without the gem, with it unloaded, and in both profiled runs
  (632 passed, 2 skipped).
* Every feature outside Lowrail and Bundler's own library loads in the same order in all three setups (3,236 files
  in the main process, 1,136 of them Rails). Listing a path gem adds Bundler's gemspec source and
  `rubygems/specification_policy.rb`; a released gem would not.
* `--record` notes a request's shape after the counting window closes and requires `json` only at exit, when
  Bundler has long set up. On the Blog's suite (21 tests, Rails 8.1.4) per-test outcomes are identical plain and
  under `--record`.
* Wall time: 14.8 s and 14.9 s profiled against 15.1 s plain (the suite's own "Finished in"). The hook costs about
  as much as the noise between runs here; heavier allocation paths will cost more.

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
