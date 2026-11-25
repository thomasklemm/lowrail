# Profile your own app: `lowrail-profile`

**Using it on your app: read [gem/README-profile.md](../gem/README-profile.md)**, the gem's README (install,
commands, reading a report, the CI recipe, guarantees). This page is the evidence behind it: how it measures, the
corpus runs, reviews and reruns. The [release plan](profile-release-plan.md) says what 0.1 ships.

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
reports against each other for CI, with a second profile of the base as the noise floor.

It is a prototype. The census (`script/census app`) instead copies an app, boots it in production and measures the
same workloads file with an A/A pair, instructions, jobs and mailers; [Your own app](../README.md#your-own-app) says
when to use which.

Results are allocation counts, not timings. A line with many objects per request is a place to look, not a
measured speedup.

## Run it

Add the gem to the development and test group, unrequired:

```ruby
gem "lowrail-profile", git: "https://github.com/thomasklemm/lowrail", glob: "gem/lowrail-profile.gemspec", group: [:development, :test], require: false
```

`--workloads` in production (below) needs the gem installed there too: list it in a group your production
`bundle install` keeps, or run that profile from a checkout whose Bundler settings do not exclude it.

Then, from the app directory:

```sh
bundle exec lowrail-profile -- bin/rails test                      # Minitest: integration and system tests (not ActionController::TestCase)
bundle exec lowrail-profile -- bundle exec rspec spec/requests       # RSpec
bundle exec lowrail-profile --record -- bin/rails test             # the same, and write lowrail/workloads.rb from it
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 \
  bundle exec lowrail-profile --workloads                            # lowrail/workloads.rb's requests, closest to production
bundle exec lowrail-profile report                                   # rebuild the report (needs --keep-runs)
bundle exec lowrail-profile compare base/report.json head/report.json --aa base2/report.json  # a report: exit 0, 2 without valid evidence
```

`--workloads [FILE]` (default `lowrail/workloads.rb`) boots the app with `bin/rails runner` in the current
`RAILS_ENV`, evaluates the [workloads file](upstream/census.md#workloads-file) after boot, and sends its requests
10 times as warmup and 20 times counted, in file order, through the full middleware stack. It sends them the way
`script/census app` does, through the same code (`Lowrail::Workloads::Replayer`): a browser's `Host`, `Origin`,
`Accept`, `User-Agent` and `Sec-Fetch-Site` headers under the file's own, its sign-in (a form, or a cookie, signed
with the app's key for `signed: true`), CSRF tokens (none for `csrf: false`), alternates and blocks, and the cookies
earlier responses set, kept as the census's Rack::Test session keeps them (by name and `Path`, sent only under that
path, dropped after their `Expires`; `Domain` and `Max-Age` are not modeled). A status outside a request's
`expect:` stops the run.

**The requests are real.** They write to the app's database and go through its own queue adapter and mail
delivery: an inline adapter performs the jobs they enqueue inside the request (and counts them as part of it), any
other adapter enqueues real work that workers will run, and mail is delivered as the environment is configured. Run
it only against a disposable database and disposable queue, mail and third-party services. What it does not run is
the file's own `mail` and `job` workloads (the census runs those, with jobs captured). `workloads.json` in the
output directory holds the file's manifest, the adapters the requests used, the requests that enqueue jobs, and for
requests with an alternate or block the variants measured.

`--record [FILE]` records, in the first run, the shape of every routed request: method, route, format, JSON or XHR,
a GET's `Accept` as sent (a write's only when the file would not send it anyway, such as a Turbo Stream's), and one
request's params (a GET's query, a write's body). A JSON or XML GET is written as a GET with its `Accept` header and
query, not with `as: :json`, which would send the query as a JSON body. It then writes the 20 most frequent shapes as a workloads file (default `lowrail/workloads.rb`, or
`tmp/lowrail-profile/workloads.rb` when that file exists): route helpers on each model's first row
(`Article.first!`, for models the app has loaded). Recording is sensitive: params pass through the app's
`filter_parameters` (the list as it is when the request runs) before anything is kept or used to group requests,
every path value, the format and the `Accept` header included (the header as Rails' `filtered_env` filters it);
filtered values are written as `[FILTERED]`, a request with one is commented out, and nothing is taken from the raw
path or query string. Values are kept only when every entry of the list is a Symbol, String or Regexp: a Proc
may depend on Rails' merged params, which Lowrail does not reproduce, so with one in the list (or without the app's
filter) no request values, `Accept` included, are kept and each such shape is commented out. Still check the file before you commit
it: only what the filter names is hidden. Every value from a request is written as
a quoted literal, never as Ruby. Only GETs that replay as recorded are enabled; each other shape is commented out
with its reason, until you make it work:

* a write (it repeats one test's params): make it repeatable with a `setup` reset, `alternate:` or a block;
* params with `[FILTERED]` values: fill them in;
* params that were shortened (long or binary values, uploads), optional path parts, or a write's query string;
* a path part the file cannot look up (`:slug`, a model the app had not loaded): the path is the one seen.

A record lookup only commented-out requests use is commented out too. Shapes are noted after the counting window
closes, so recording does not change the counts. From the Blog's suite (21 tests, 12 requests) it writes:

```ruby
article = Article.first!
# comment = Comment.first!

# 2 requests (a write: make it repeatable, then uncomment)
# patch article_path(article), name: "PATCH /articles/:id", params: {"article" => {"body" => "Rails is a web application framework running on the Ruby programming language.", "title" => "Updated Title"}}
# ...

# 1 request
get articles_path, name: "GET /articles"

# 1 request
get article_path(article), name: "GET /articles/:id"
# ...

# 1 request (a write: make it repeatable, then uncomment)
# delete article_comment_path(article, comment), name: "DELETE /articles/:article_id/comments/:id"
```

That file is what `script/census app` then measures as fixed workloads. `--paths FILE` is gone; a `paths.txt` line
`GET /articles` is `get "/articles"` in the workloads file.

Options, all before the first `--` (everything after it, a second `--` included, is the command's, unchanged):

* `--out DIR` (default `tmp/lowrail-profile`): a new or empty directory, or one lowrail-profile created before (it
  leaves a `.lowrail-profile` marker), where it replaces only its own runs and reports. It refuses any other
  existing directory and deletes nothing in it.
* `--runs N` (default 2; the spread between runs is part of compare's noise floor), `--top N` (default 30), `--seed N` (default
  1234, passed as `SEED` and `--seed` to every run, so test order repeats), `--ledger FILE` (a ledger index; default:
  the dated snapshot `gem/data/contributions-index.json` the gem ships, from `script/profile-ledger --snapshot`),
  `--no-ledger`.
* `--keep-runs`: keep `run*/`, one TSV per process with the raw counts, in which each file path is written once
  (a `P` row) and rows refer to it by number. Without it `run*/` is deleted once the report is written. On Sure
  (16 workers) run 2 wrote 16 TSVs of about 240 MB, where paths were four fifths of the bytes.
* `--timeout SECONDS` (no default): the command runs in its own process group, and lowrail-profile passes `INT` and
  `TERM` on to it. A run still going at the deadline gets `TERM`, then `KILL` 10 s later; no further run starts,
  `capture.json` lists it in `timed_out`, and lowrail-profile exits 124. A parallel worker of Fizzy hangs in about
  1 of 14 profiled runs in an autoload deadlock with no lowrail frame on its stack.

The first run builds a small C extension into `~/.cache/lowrail/profile/RUBY-BUILD/DIGEST/`, where the digest
covers its sources and compiler settings, so another Lowrail checkout never picks up a different build; the app
also refuses an extension of another version before hooking anything. It needs a C compiler and Ruby's headers, and
is built outside the app, never during its boot.

## What it measures

`LOWRAIL_PROFILE` (set by the command, never by you) makes `RUBYOPT=-rlowrail/profile` install the items below. When
the suite has read its options (Minitest's plugin init, after it reads `SEED`; RSpec's runner, which has read
`SPEC_OPTS` before the app boots), the profiler removes what the command added: `LOWRAIL_PROFILE*`, its `-I` and
`-rlowrail/profile` in `RUBYOPT`, its `RUBYLIB` entry, and the seed, putting back the caller's `SEED` and
`SPEC_OPTS`. Processes the suite starts then run as in a plain run; Bundler's own `RUBYOPT` and `RUBYLIB` entries
stay. A command that is no Minitest or RSpec suite (a server, a script) keeps them for its children. The profiler installs:

* an internal `NEWOBJ` hook, the one `ObjectSpace.trace_object_allocations` uses, that keeps a count per file,
  line, object type and kind of window in C memory (no Ruby objects, no retained records; GC stays on). An open
  window keeps its fiber and thread alive until it closes, see below;
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
  app loads it, and a framework the app never loads is never hooked. A hook that cannot be installed (the class is
  frozen) prints a warning, and that framework is not counted. A window inside another (a job performed
  inline, a mail delivered inside a request) counts as part of the outer one, so a request's numbers include the
  jobs and mail it runs and jobs, mails and Cable actions reported apart are the ones that ran on their own.
  A window belongs to the fiber that opened it: overlapping threads (with M:N threads too) and independent fibers
  (a fiber scheduler's requests) each count their own, and allocations in another fiber the window starts
  (`Enumerator#next`) are not counted. A fiber dropped while its window is open (a scheduler cancelling a request
  mid-flight and never resuming it) stays alive, with what it references, until more than 1,024 windows are open;
  then the oldest open window off the current fiber is given up, counted as dropped, and its fiber can be collected.
  So such an app retains at most 1,024 abandoned fibers. A window still open when the process writes is in its
  run's window count but merged into no line or action; the report lists it as unfinished, and `compare` refuses
  that capture (as it refuses one with dropped windows). Code
  in Ractors other than the main one runs uncounted;
* an `at_exit` writer (one TSV per process; forked test workers reset their counts and recorded shapes and write
  their own).

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

On Campfire's report (Rails main `e3d5c569` of 2026-10-05, 300 top lines) this gives 19 matches: 7 open upstream
work (importmap-rails#336 twice, #59804 twice, nokogiri#3759 twice, rack#2550) and 12 merged after the app's
revision (#59329, #59235, #59613, #59562, #59274, #59551, #59605, #59316, #59537, #59561). Each was checked by hand
against the pull request's diff: in every one the app's line is a line the pull request removes, in the method
whose hunk removes it. The text match it replaces had 50, among them a pull request on `Array#to_query` matched to
`Object#to_query` in the same file, a correctness fix (#59634) matched through the same code in another method,
#59555 (a regression fix on `index_with`), and #59141, another author's pull request the ledger only mentions.
A backport merged as its own commit (Rails stable branches) is not found by merge
commit, so such a fix shows as not released. Rebuild the index with `script/profile-ledger` after the ledger
changes (`--missing` after GitHub's rate limit stops it).

## Compare two reports in CI

**0.1 ships without a gate** ([DECISIONS](DECISIONS.md), [profile-gate-design](profile-gate-design.md)): compare
lists what exceeds the floor below and exits 0, or 2 without valid evidence, which includes a capture of more than
one process. What this section says about exit 1 describes the release candidate's gate, whose measurements follow;
read "exits 1" as "lists a regression".

`lowrail-profile compare BASE.json HEAD.json --aa BASE2.json` sets the `report.json` of two profiles against each
other, per line outside the app and per action (requests, jobs, mails and Cable actions apart), on warm objects per
request. `BASE2.json` is a second profile of the unchanged base, so `BASE.json` and `BASE2.json` are an A/A pair:
how much they differ is how much two invocations of the same code differ. compare exits 1 when anything grew beyond
its noise floor and 0 when nothing did, but only for valid evidence; otherwise it exits 2 and says why. `--json`
prints the result as JSON, `--min N` (default 1) sets the smallest change that counts.

**Without `--aa`, compare is not a gate.** It lists the changes beyond the spread inside each capture, says that
this is a look and not a gate, and exits 0 (or 2 without valid evidence): that spread misses how much invocations
differ (below), so such a list is a reason to look, not a confidence bound.

* **Valid evidence**: every report (base, head and the A/A report) comes from this version of lowrail-profile and pass one strict check of their
  shape (every key compare reads present with its type, every summary number included, line rows with a unique site and action rows with a unique
  name, one warm value per run that is finite, or for an action that ran once per process none), with at least two
  runs each, every run's command exiting 0, no dropped samples, every window finished, windows in every run, and one
  known Ruby and environment in every process; and head and the A/A report each have the same capture identity,
  seed, Ruby, environment and number of runs as base. The identity of a command is its arguments; of `--workloads` it is the file's
  manifest (header and `env:` values digested as values), the replay host and, per run, a digest of every counted
  request as sent (so a block that sends other requests is a different capture), recorded only once the run
  finished measuring at least one request, never the output directory; none of these may be empty. That digest
  covers a run only when the run is one process whose request windows are exactly the requests it measured, so a
  workload run with more than one contributing process (such as a forked child that runs a job), or with requests
  it did not measure (such as from `at_exit`), is not CI evidence (ordinary command captures may have any number of
  processes). An `env:` value that is not a JSON value
  (String, number, true, false, nil, or Arrays and Hashes of them) has no identity a digest can certify, so such a
  capture is not CI evidence. Anything else unexpected, a missing or partial report, a failing suite or a one-run
  profile is never a green result.
* A kind of window (requests, jobs, mails, Cable actions) is compared only when every run of every report has some;
  a kind some runs have and others lack, or no comparable kind at all, exits 2.
  A line base or head never reached is a measured zero there, and one the A/A report never reached adds no spread
  to its floor; an action base, head or the A/A report did not run, or
  that has no warm value there (it ran once per process), is listed as not compared.
* A row's noise is the base's spread across the A/A pair: largest minus smallest of all the runs of both base
  reports, so it covers the pair's difference and each one's own spread (every run counts with `--runs` above 2);
  or head's own spread, if that is larger. Without `--aa` it is the larger spread inside base or head.
* A line's noise floor is the larger of twice its noise and `--min`: one A/A pair is one sample of that noise, and
  at once the noise one pair failed 4.5% of unchanged heads on the 3.3 Blog (M5 confirm receipts).
* An action's is the largest of twice its noise, 0.1% of its objects per request and 20 × `--min`, because parallel
  test workers split an action's requests differently from one invocation to the next. That multiplier comes from
  Campfire's first A/A pair, before the floor spanned invocations, not from a general confidence bound.

On Campfire's suite an A/A pair (two invocations of `bin/rails test` on the same code) exits 0 with no changes
beyond the floor, and adding `20.times { ERB::Util.html_escape("a<b") }` to `RoomsController#show` gives exit 1
with 3 regressions: the action (+45.85 per request against a floor of 26.47) and the two Active Support lines it
calls (+1.68 per request each over all requests, floor 1.0), and nothing else; 35 actions that run once per process
are listed as not compared. Comparing a `bin/rails test -v` profile with a `bin/rails test` one exits 2 (different
commands). Rechecked after the review fixes; the first measurement gave +46.35 against 26.48. These runs predate
the A/A floor: each compared two captures, with the floor from the spread inside each.

**Why the floor spans two invocations.** After the confirm-review fixes, a second A/A pair of `bin/rails test -v`
on the same Campfire copy exited 1 with one regression: `GEM/json/lib/json/common.rb:364`, +1.69 objects per
request against a floor of 1.0. Across six Campfire captures that line's per-run values range from 107.3 to 111.2,
but inside one capture its two runs moved only 0.27 to 3.3, so the spread inside one invocation underestimates the
variation between invocations, as it does for actions. The A/A pair measures that variation for every row.

Rechecked with the A/A floor (fresh `script/corpus campfire` copy, Ruby 4.0.7, `bin/rails test -v`, 634 tests,
seed 1234): five unchanged captures, each its own invocation, and one with the planted `html_escape`. The json
line's two runs moved 3.9, 2.5, 2.6, 0.22 and 0.12 in the five. The last two are the case above: compared directly,
compare before the A/A floor exits 1 with `json/common.rb:364` +1.86 against 1.0; now it lists that line without
`--aa`, says it is not a gate and exits 0, and with any of three other unchanged captures as the A/A report it exits
0 with no regression. Every other unchanged base, A/A and head combination tried exits 0 (the closest row reached half
its floor). The planted change exits 1 against every pair tried, with the same 3 regressions and nothing else: the
action +43.2 to +44.8 against a floor of 25.76 and both Active Support lines +1.68 against 1.0. With a plain
`bin/rails test` profile as the A/A report of a `-v` base it exits 2 (base and the A/A report differ in identity).
One A/A pair is one more sample of the variation between invocations, not a confidence bound: a row that varies more
than this pair shows can still exceed it.

A GitHub Actions job that profiles the pull request's base twice (the A/A pair) and its head with the same command
and fails on a regression that a second profile of head shows too:

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
        bundle exec lowrail-profile --out tmp/base2 -- bin/rails test
    - name: Profile head
      run: |
        git checkout ${{ github.event.pull_request.head.sha }}
        bin/rails db:test:prepare
        bundle exec lowrail-profile --out tmp/head -- bin/rails test
    - name: Compare
      shell: bash # pipefail, so tee does not hide compare's exit status
      run: |
        status=0
        bundle exec lowrail-profile compare tmp/base/report.json tmp/head/report.json --aa tmp/base2/report.json \
          | tee -a "$GITHUB_STEP_SUMMARY" || status=$?
        [ "$status" = 1 ] || exit "$status"
        echo "Profiling head again: a regression fails the job only if it shows twice." | tee -a "$GITHUB_STEP_SUMMARY"
        bundle exec lowrail-profile --out tmp/head2 -- bin/rails test
        bundle exec lowrail-profile compare tmp/base/report.json tmp/head2/report.json --aa tmp/base2/report.json \
          | tee -a "$GITHUB_STEP_SUMMARY"
```

Both checkouts need the gem in their Gemfile; if the base does not have it yet, run the base step from the head's
Gemfile (`BUNDLE_GEMFILE`). A suite whose tests fail still profiles, for a look at the report, but compare then
exits 2; check the suite in its own job. `shell: bash` matters: without it GitHub runs the step without `pipefail`,
and `tee` would turn compare's exit status into 0. Without `--aa tmp/base2/report.json` the step never fails: compare
without an A/A pair is not a gate. The second base profile costs one more suite run. A first exit 1 profiles head once more, and the
job fails only if that comparison exits 1 too: on the receipts' Blog this took unchanged heads from 1.7% failing to
0.03%, with every planted regression on four apps still caught
([receipts](../bench/upstream/profile_release/2026-11-25-final)).

## Safety

With the gem in the Gemfile and `require: false`, an app that does not run `lowrail-profile` loads none of
Lowrail. The gemspec no longer requires `lib/lowrail.rb` (Bundler evaluates a path or git gem's gemspec in every
process). When the command runs it:

* a counter that fails to load, or one of another version (an older build), prints one warning and nothing is
  hooked;
* a framework hook that cannot be installed later (its class is frozen) prints one warning, and the app's load goes
  on as it would;
* every profiler call inside the app (opening, naming and closing a window, noting a request's shape) is contained
  where it runs, so the app's own results and exceptions pass through unchanged, as the same objects;
* code in a Ractor other than the main one runs uncounted, without calling the counter (its tables are not
  Ractor-safe, and are not marked so);
* lowrail-profile exits with the command's status (the first failing run's, or 128 plus the signal that stopped
  it), also when the report then fails; a passing command whose report cannot be built exits 1.

`gem/test/profile_test.rb` checks the cases above that a test can reach: a Cable subscription's return value and
exceptions with `--record`, an older counter's API, a frozen `ActionController::Metal`, and `--out` on a directory
it did not create.

### Release candidate: proof from the built gem (2026-11-25)

lowrail-profile 0.1.0.rc1 as a stranger installs it: `gem build lowrail-profile.gemspec` from `gem/`, `gem install --local`
into the app's Ruby, a Gemfile copy with only the gem's line added, no Lowrail checkout on any path and an empty
counter cache, on fresh `script/corpus` copies. Receipts, scripts and method:
[bench/upstream/profile_release/2026-11-25](../bench/upstream/profile_release/2026-11-25). Apps ran one after
another on an 8-CPU orb.

| App, suite | Ruby, Rails | Tests | Outcomes (plain = off = every capture) | A/A `compare --aa` | Planted `html_escape` loop | Overhead, run 1 / run 2 |
| --- | --- | ---: | --- | --- | --- | --- |
| Blog (generated), `bin/rails test -v` | 3.3.14, 7.2.4 | 21 | identical: 21 pass | 0 (closest row 68% of its floor) | 1: one line | +9% / +37% |
| CodeTriage, `bin/rails test --verbose` | 4.0.7, 8.1.4 | 222 | identical, 0 failures | 0 (100%, at the floor, not beyond) | 1: the action and two lines | +4% / +35% |
| Campfire, `bin/rails test -v` | 4.0.7, main `e3d5c569` | 634 | identical: 632 pass, 2 skip | 0 (43%) | 1: the action and two lines | +7% / +87% |
| Lobsters, `bundle exec rspec --format documentation` | 4.0.9, 8.1.3.1 | 927 | identical (masked), 0 failures | 0 (51%) | 1: the action and two lines | +6% / +31% |

* Load order: every profiled process loads the same features in the same order as the setup without the gem
  started the same way (`bundle exec env COMMAND`, a new process under Bundler's `RUBYOPT`, as lowrail-profile
  starts its command). Started as `bundle exec bin/rails` or `bundle exec rspec`, Bundler loads the script in its
  own process, which moves its early `pathname` (Ruby 3.3) or `etc.so` (Ruby 4.0) ahead of `bundled_gems.rb`.
  CodeTriage's yard handler and code-object files load in an order of their own, as before.
* A different seed, or another app's report, exits 2. The app tree (outside `log/`, `tmp/` and SQLite databases)
  is the same after every capture.
* Ledger: 52 of 52 matches at `--top 300`, each checked against its pull request's diff on GitHub.
* GitHub Actions: the README's job, verbatim, on a private copy of the Blog fails on a planted pull request
  (exit 1, one regression) and passes on an unchanged one. macOS (`macos-latest`, arm64): the counter builds with
  Apple clang and Campfire's 634 tests are identical plain, off and profiled (outcomes only; load order was not
  compared there).
* After the M5 review fixes the rebuilt gem was proved again where they reach: the floor Blog's full proof, and a
  failing and a killed suite's exit status and the `--workloads` write guard on Ruby 3.3 / Rails 7.2 and Ruby 4.0 /
  Rails 8.1 ([receipts](../bench/upstream/profile_release/2026-11-25-fixes)).
* The stack-walking run cost Campfire 87% of its suite time here, more than the 45% measured on the 2-CPU orb on
  2026-11-18; counting alone stays under 10%.

### Rerun on main (2026-11-18)

The three apps the review fixes left unchecked, on main `7ca0a20e` with the counter fix below, in fresh
`script/corpus` copies, three ways as before (seed 1234, `$LOADED_FEATURES` from every process), plus two more
profiles of each, so that `compare BASE HEAD --aa BASE2` ran on three invocations of the same code. Receipts,
scripts and the three captures' reports: [bench/upstream/profile_matrix/2026-11-18](../bench/upstream/profile_matrix/2026-11-18).
Other runs shared the 2-CPU orb, so no times are given.

| App, suite | Ruby, Rails | Tests | Outcomes (plain = off = every profiled run) | Load order | `compare --aa` |
| --- | --- | ---: | --- | --- | --- |
| Writebook, `bin/rails test -v` | 4.0.7, main `36e0f96b9d` | 310 | identical per test: 307 pass, 2 skip, 1 error | identical in every process | 2: the error fails every run; without that test 0 (5,211 lines, 25 actions compared) |
| Pingcrm, `bin/rails test:all -v` | 4.0.7, 8.1.4 | 26 | identical per test: 26 pass | identical to a second plain run | 0 (2,962 lines, 11 actions) |
| CodeTriage, `bin/rails test --verbose` | 4.0.7, 8.1.4 | 222 | identical per test for the 217 that print a line, totals 222 everywhere: 0 failures | same files; yard's handlers in another order | 0 (8,477 lines, 18 actions); 2 before the fix |

* Writebook's error is the same as before (`URI::Generic#request_uri`, without the gem too). A suite that fails
  never gives a gate (exit 2, "base's command exited [1,1]"); excluding that test
  (`--exclude /test_unpublishing_a_book_revokes_the_disk_URL/`) the A/A pair exits 0.
* Every `compare` with an A/A pair exits 0 with nothing beyond its floor; the closest rows reach 42% (Writebook,
  `PagesController#create` −9.0 against 21.4), 50% (Pingcrm, a `vite_ruby` line −0.73 against 1.46) and 62%
  (CodeTriage, `BackgroundInactiveEmailJob#perform` +87.5 against 142.0) of their floor. Without `--aa`, CodeTriage's
  pair lists that job as a regression (+87.5 against the 78.0 its captures' own spread gives) and exits 0 as not a
  gate. This is three more A/A samples, not a detection bound; no change was measured.
* **Fixed: code evaluated from line −1 dropped samples.** Sidekiq's Web compiles its ERB views with
  `class_eval …, -1`; the counter read that line as 2⁶⁴−1 and dropped the allocation, so every CodeTriage run had
  `dropped=1` and `compare` refused every pair (exit 2). Lines below 1 now count at line 0
  (`test_code_evaluated_at_a_negative_line_is_counted`).
* Load order: Writebook's 4 plain, 4 off and 24 profiled processes load the same features in the same order.
  Pingcrm's first plain run also loaded `vite_ruby/runner.rb` and `io.rb`, because Vite built the copy's assets
  then; a second plain run does not and matches every off and profiled process. CodeTriage loads the same files in
  every process, and the same order except for yard's 27 handler files: yard loads them by walking
  `Module#constants`, and their order is stable within a setup but differs between plain, off and profiled (off
  loads no Lowrail code). Its first plain run also loaded `enc/trans/single_byte.so`; a second did not.

### Rechecked after the review fixes (2026-11-18)

After the fixes for the [review](upstream/profile-review-2026-11-18.md), the same three ways on fresh copies of
the two apps the review asked for, with the same scripts (seed 1234, `$LOADED_FEATURES` from every process):

| App, suite | Ruby, Rails | Tests | Outcomes (plain = off = run 1 = run 2) | Suite time: plain, off, run 1, run 2 | Wall: plain, off, profiled |
| --- | --- | ---: | --- | --- | --- |
| Campfire, `bin/rails test -v` (2 workers) | 4.0.7, main `e3d5c569` | 634 | identical per test: 632 pass, 2 skip | 19.7, 20.8, 19.0, 31.4 s | 22.5, 23.3, 64.4 s |
| Lobsters, `bundle exec rspec --seed 1234 --format documentation` | 4.0.9, 8.1.3.1 | 927 | identical per example (timestamps and random tokens masked): 0 failures | 33.4, 33.3, 35.5, 40.8 s | 39.0, 37.9, 96.2 s |

* Load order: Campfire's 6 processes per setup load every feature outside Lowrail, RubyGems and Bundler in the
  same order plain, off and in both profiled runs. Lobsters' off and both profiled runs are identical, and so are
  two more plain runs and one more off run made as a control. Only the copy's first plain run after `db:prepare`
  loaded Lobsters' `extras/sponge.rb` and Ruby's `unicode_normalize` at another point (same files, 291 positions
  moved); its repeats did not, so that is the cold first run, not the gem.
* Lobsters' command now reaches RSpec with its own `--seed 1234`: options after `--` are no longer read by
  lowrail-profile (in the table below, that run's report showed the command without it).
* The profiled processes print no `[lowrail-profile]` warning; the numbers (666 Campfire requests at 19,487
  objects per request) match the earlier runs.

Checked first on five apps' own suites (fresh `script/corpus APP DIR --source-only` copies at their corpus pins, each
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
  handlers by walking `Module#constants`, in an order that already differs between plain and off; without them the
  order matches.
* Overhead: the first run (counting only) costs 0–11% of suite time. The repeat run walks the stack on every
  allocation to find the app frame and costs 1–45% (Campfire's suite, at 19,400 objects per request, the most).
* `--record` notes a request's shape after the counting window closes and requires `json` only at exit, when
  Bundler has long set up. On the Blog's suite (21 tests, Rails 8.1.4) per-test outcomes are identical plain and
  under `--record` (rechecked after the fixes, with the gem listed but off as the control).

## Proof on two corpus apps

These runs predate the review fixes: `--workloads` then sent no `Host` or `Origin` header and no form type for an
empty write, which it now sends like the census client.

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
counts matched the census within about 1% (on these GETs, before the review fixes): `useragent` `browsers/base.rb:120` 32.67 against 33.00,
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
