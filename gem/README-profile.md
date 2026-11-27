# lowrail-profile

**Exact object allocation counts for your Rails app, per request, job, mail and Action Cable action, by source
line, in your code and in the Rails, Ruby and gem code it calls.** It runs your test suite (or a recorded request
mix) with allocation counting on and tells you which lines allocate the most per request, which of your lines lead
there, and whether an upstream pull request already changes that line.

It counts objects. It does not measure time, CPU, retained memory or SQL, and it never changes or lowers your app.
For time, pair it with [vernier](https://github.com/jhawthorn/vernier) or your APM.

Experimental (0.1.1). Supported: Ruby 3.3, 3.4 and 4.0; Rails 7.2, 8.0 and 8.1; Linux and
macOS. Windows is refused with a message.

## Install

```ruby
# Gemfile
gem "lowrail-profile", group: [:development, :test], require: false
```

Until 0.1.1 is on rubygems.org, build it from a Lowrail checkout. The gemspec's file list is
relative to `gem/`, so build it there:

```sh
cd lowrail/gem && gem build lowrail-profile.gemspec && gem install --local lowrail-profile-0.1.1.gem
```

Or let Bundler take it from GitHub:

```ruby
gem "lowrail-profile", github: "thomasklemm/lowrail", glob: "gem/lowrail-profile.gemspec", group: [:development, :test], require: false
```

That checks out the whole Lowrail repository for each revision, about 530 MB of files (700 MB on disk in one
install, under Bundler's `bundler/gems`), plus about 250 MB of git cache, against 90 KB for the built gem.

`require: false` matters: nothing of the gem loads in your app unless you run the command below. The first run
compiles a small C extension (the counter) into `~/.cache/lowrail/profile/`, outside your app; it needs a C compiler
and Ruby's headers, which `bundle install` of a Rails app already needs. A compile failure stops the profiler with
the build log's path; it never touches `bundle install` or your app's boot.

## Three commands

```sh
bundle exec lowrail-profile -- bin/rails test             # or: -- bundle exec rspec
bundle exec lowrail-profile report                        # rebuild the report (needs --keep-runs)
bundle exec lowrail-profile compare base/report.json head/report.json --aa base2/report.json
```

The first runs the command twice (everything after `--` is passed unchanged) and writes `tmp/lowrail-profile/report.md`
and `report.json`. It prints the report too. The suite runs as it would, with `SEED` and `--seed` fixed (default
1234) so both runs order tests the same way. Only the suite's own process gets the seed and the profiler: once
Minitest or RSpec has read its options, any process the suite starts (a rake task, an `after(:suite)` that runs
rspec again) sees the environment you gave lowrail-profile. A process the command starts before its suite runs,
such as `rake test`'s parent, passes both on to the suite. A process started earlier than Minitest's or RSpec's own start (while `test_helper.rb` or `spec_helper.rb` loads, or from a plain `Minitest::Test` suite without `ActiveSupport::TestCase`) still gets the profiler and the seed. lowrail-profile exits with its status: the first failing run's exit
code, or 128 plus the signal that stopped it (143 for `TERM`), and 124 when a run timed out. A passing suite whose report cannot be built exits 1.

Bypass Spring (`DISABLE_SPRING=1`, or `bin/rails test` without a Spring binstub): a Spring server that is already
running forks the app without loading the profiler, so the run counts nothing and lowrail-profile exits 1 with *no
runs with requests*.

Options, all before `--`:

| Option | Default | |
| --- | --- | --- |
| `--out DIR` | `tmp/lowrail-profile` | A new or empty directory, or one lowrail-profile made (it leaves a `.lowrail-profile` marker). It refuses any other directory and deletes nothing in it. |
| `--runs N` | 2 | Runs of the command; their spread is part of compare's noise floor. |
| `--top N` | 30 | Rows per table. |
| `--seed N` | 1234 | `SEED` and `--seed` for every run. |
| `--ledger FILE` | bundled | A newer ledger index (`contributions-index.json`). |
| `--no-ledger` | | No ledger column. |
| `--keep-runs` | | Keep each run's raw counts (`run1/`, `run2/`), which `report` rebuilds from. Without it they are deleted once the report is written: compare needs only `report.json`, and on a large parallel suite the counts reach gigabytes. |
| `--timeout SECONDS` | none | Stop a run that takes longer: `TERM` to the command's process group, `KILL` 10 s later. `TERM` then `KILL` go to every process the run started, also when the first one exits on `TERM`, and to the processes it started in a group of their own (as selenium-webdriver starts its driver and browser) that are still found from the run at the deadline or during those 10 s: its descendants and the members of their groups. A process whose parent exited before the deadline and that is in a group of its own (a daemon) is no longer found and keeps running. lowrail-profile exits once the others are gone, at most about 10 s after the deadline. No further run starts, lowrail-profile exits 124 (also after an earlier failed run), the report says which run timed out, and compare treats the capture as a failed suite (exit 2). With it the command runs in its own process group, and lowrail-profile passes `INT`, `TERM`, `HUP` and `QUIT` on to it; a debugger that reads the terminal (`binding.irb`) stops there, so leave `--timeout` off to debug. |
| `--help`, `--version` | | |

## Reading the report

The header says what was counted: command, Ruby, Rails and environment, how many requests, jobs, mails and Cable
actions, and the ledger's date. Its table gives objects per request by run twice: *all* counts every request with the
one-time work of each process's first requests, *warm* leaves each line's first request per process out, as the
noise floor and the tables below do; compare the warm number. A file `ActionDispatch::Static` serves (`public/`,
precompiled assets) answers before routing: it is a request named `ActionDispatch::FileHandler#serve`, and the
header says how many there were and the objects per request without them. Assets a mounted Rack app serves (Sprockets
in development and test) have no action name. Then:

* **Your code.** Per app line, the objects Rails, Ruby and gems allocate below it per request: the nearest app
  line on the stack of every allocation (the second run walks the stack to find it). *Own* is what the line itself
  allocates; *Dev/test* is work production mostly does not do (see below).
* **Actions.** Objects per request by controller action, per run. *Warm* leaves out each action's first request in
  each process, which carries one-time work (route table, template compilation, I18n load); `–` means it ran once
  per process. *Δ* is the last run minus the first: the noise.
* **Top lines outside the app.** Per line in Rails, Ruby and gems: warm and all objects per request, *Reach* (the
  share of requests in which it allocated), the object types, the app lines that lead there, and *Ledger*. A † means
  objects from Ruby's `<internal:…>` code charged to the line that called it.
* **Dev/test-mode work.** Debug logging, error pages, template compilation, route building, asset lookup and reload
  checks, apart, so a suite profile is not read as production cost.
* **By gem**: warm and all objects per request by group, with dev/test-mode work as a group of its own; groups
  with no warm objects are named in one line below it. A line `:0` has no line number: allocated while Ruby loaded or
  compiled the file, or by code evaluated without one. In *From the app*, *(middleware)* marks app middleware that
  hands the request on: it is the nearest app line of work done after the request's code returned or raised (an
  error page), not the line that raised, which is no longer on the stack.
* **Outside requests**: jobs (`perform_now`), mails (build and delivery) and Cable actions, counted
  the same way. A job or mail inside a request counts as part of that request.

Line keys are `RAILS/<component>/path:line`, `GEM/<name>/path:line`, `RUBY/path:line` and `APP/path:line`.

**Ledger.** A dated snapshot of upstream pull requests that reduce allocations ships with the gem. A line matches
when a pull request changes that very line (same repository, file and method, and the line's code is among the
lines it removes or adds). The cell says what that means for the version your lockfile runs: *open upstream work*,
*fixed in 8.2.0* (upgrade), *merged, not released yet*, or *merged, in 7.2.3, which this app runs*. The ledger covers
the pull requests its authors track, not every upstream fix, and a snapshot goes stale: the header gives its date.

**Counts are not time.** A line with many objects is a place to look; some allocations are cheap. **A suite is not
traffic**: it requests what tests need, with a test user agent, in test mode. `--workloads` (below) gets closer.

## Compare

`compare BASE.json HEAD.json --aa BASE2.json` lists the lines and actions that grew or shrank beyond their noise
floor and exits **0** whatever it lists: in 0.1 it is a report, not a CI gate (below). It exits **2** when the reports
are not valid evidence: a failing suite, one run, a different command, seed, Ruby or environment, dropped samples,
unfinished windows, a capture of more than one process, a report of another version, or the base passed as its own
A/A report; an A/A report with exactly the base's counts (a copy?) is compared with a warning. `BASE2` is a second profile
of the unchanged base: the A/A pair sets the floor per row (twice the larger of a row's spread across both base
profiles and head's own spread; for a line at least `--min`, default 1 object per request, for an action at least
0.1% of its objects and 20 × `--min`). Without `--aa` the floor is the spread inside one capture, which misses how
much invocations differ. `--json` prints the result as JSON.

**Profile in one process.** Warm leaves out each process's first request of an action, and parallel test workers
split the tests anew in every capture, so which requests those are, where one-time work lands and which code paths
run change between captures: on openstreetmap-website (8 workers, the same code) `NotesController#index` read 8,063
warm objects per request in one capture and 26,106 in the next. compare refuses such captures (exit 2). Set
`PARALLEL_WORKERS=1` for `parallelize`, and run `parallel_tests` and similar runners without them.

**Why there is no gate in 0.1.** Over every assignment of unchanged captures to base, A/A and head, captured in one
process, compare listed a regression for 0 of 24 heads on openstreetmap-website, 0 of 120 on Writebook, 0 of 1,320
on a fresh Rails 8.1 app and 1.7% on a generated Blog, but 12.5% on Hackatime, and 4.4% even when a second profile
of head had to show it too. Hackatime's `Admin::AdminUsersController#index` reads 14,700–14,730 or 14,785–14,817
warm objects per request by capture with the same code: a 0.7% move with the data, which one A/A pair does not
sample. With parallel workers it was worse (openstreetmap-website 79%, Hackatime 52.5%, Writebook 26.7%). A job that
fails on unchanged code that often does more harm than good, so treat what compare lists as places to look
([the measurements](https://github.com/thomasklemm/lowrail/blob/main/docs/profile-gate-design.md)).

**What it can find.** In one process, an action change of about 20 objects per request, or 0.1% of the action if
that is larger: a planted `Array.new(200) { Object.new }` in openstreetmap-website's `NotesController#index` showed
as +168 against a floor of 27 (of 26,402), `20.times { ERB::Util.html_escape("a<b") }` in Campfire's
`RoomsController#show` as +44 against 26 and in Writebook's `SessionsController#create` as +55 against 20. A line
needs 1 object per request averaged over all requests of its kind, so a change in one action moves its lines only by
that action's share of the requests. Not found: the same `html_escape` plant in Hackatime's
`LeaderboardsController#index` (+40–60 on about 7,900, twice that action's own noise: listed in half the
comparisons), and with workers Writebook's plant in an action that runs once per worker process. An action that runs
once per process has no warm value and is not compared. Captures taken at different times differ on the same code
whenever the app's work depends on the clock or the date: on Forem, half an hour apart, compare listed five actions,
four by 0.1% to 0.25% and `ResponseTemplatesController#update` 15,028 → 15,154 (+0.8%); in a field test two captures
three hours apart, compared without `--aa`, listed an index action at +3.1% from app code that allocates by the date
and time. So a small listed change is a hint, not proof: profile the base twice, right before head, pass the second
with `--aa`, and freeze time in the tests that depend on it (`travel_to`).

**Network connects are left out.** What `Socket.tcp` allocates while it connects follows timing, not code: it races
its connection attempts on threads and timers. On Hackatime ViteRuby probes its dev server at most once a second,
and whichever request came first after each second paid about 400 objects for it. Objects allocated inside a
`Socket.tcp` call without a block, in the thread or fiber of the request, job, mail or Cable action, are left out of
its action and its lines, and the report and compare say how many by run (*Left out* in the report's header,
`network` per action and run). Only the connect is left out: a read or write on the socket is compared like any
other line, and `Socket.tcp` with a block is counted whole, since the block is the app's own work. The hook is a
module prepended to `Socket` once the app has loaded it; one object per call, allocated before it marks the connect,
stays in the action.

**Reset the test database before every capture** (`bin/rails db:test:prepare`, as the CI job below does). Record IDs
grow across runs, and their digits change what Rails and Rack allocate to encode them: on CASA,
`ChecklistItemsController#new` read 3,511 warm objects per request with IDs from 9,000 and 3,494 from 100,000, all of
it in `uri/common.rb:456`, with the same code. A capture after another one without a reset starts where the last one
stopped.

An action is compared only under the same name in every report: a renamed or new action, or one that ran in base
only, is listed under *Not compared* with the reason, and nothing about its own cost is listed; how many and why is
said above the tables. Lines outside the app it reaches are still compared.

A GitHub Actions job that profiles the pull request's base twice and its head once, in one process, and publishes
the comparison as the job summary and the reports as an artifact. It never fails on what compare lists:

```yaml
lowrail-profile:
  runs-on: ubuntu-latest
  env:
    PARALLEL_WORKERS: 1 # one process: compare refuses captures of parallel workers
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
        bin/rails db:test:prepare # every capture starts at the same record IDs
        bundle exec lowrail-profile --out tmp/base2 -- bin/rails test
    - name: Profile head
      run: |
        git checkout ${{ github.event.pull_request.head.sha }}
        bin/rails db:test:prepare
        bundle exec lowrail-profile --out tmp/head -- bin/rails test
    - name: Compare
      if: always() # also after a failing suite: compare then exits 2, which the summary shows
      run: |
        bundle exec lowrail-profile compare tmp/base/report.json tmp/head/report.json --aa tmp/base2/report.json \
          >> "$GITHUB_STEP_SUMMARY" || echo "compare exited $?: not valid evidence, see above" >> "$GITHUB_STEP_SUMMARY"
    - uses: actions/upload-artifact@v4
      if: always()
      with: { name: lowrail-profile, path: "tmp/*/report.*" }
```

Both checkouts need the gem in their Gemfile; if the base does not have it yet, run the base step with the head's
Gemfile (`BUNDLE_GEMFILE`). lowrail-profile exits with the suite's status, so a failing suite fails its Profile step
and the job; Compare and the upload still run (`if: always()`), and compare exits 2, which the summary shows. The job runs the suite three times, twice each, in one process: on openstreetmap-website, whose suite
takes 81 s on 8 workers, a capture took about 9.5 minutes. `--runs` and a narrower command (`bin/rails test
test/controllers test/integration`) make it cheaper.

## Experimental: `--record` and `--workloads`

```sh
bundle exec lowrail-profile --record -- bin/rails test     # also write lowrail/workloads.rb
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec lowrail-profile --workloads
```

In production the app needs what a deploy prepares: its database, with the records the file names (`Article.first!`),
and compiled assets (`RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails db:prepare assets:precompile`). A new
Rails 7.2 app's SQLite `config/database.yml` names no production database, so set
`database: storage/production.sqlite3` there first; a default Rails 8 app names one. With neither `RAILS_ENV` nor
`RACK_ENV` set, `--workloads` runs in development on the development database.

`--record [FILE]` writes the suite's 20 most frequent request shapes as `lowrail/workloads.rb` (or
`tmp/lowrail-profile/workloads.rb` when that file exists): route helpers on each model's first row, values as quoted
literals, filtered through the app's `filter_parameters` (`[FILTERED]`), only GETs that replay as recorded enabled
and every other shape commented out with its reason. It is recorded from real requests: check it for secrets the
filter does not name before you commit it.

`--workloads [FILE]` boots the app with `bin/rails runner` in the current `RAILS_ENV`, evaluates the file after boot
and sends its requests 10 times as warmup and 20 times counted, through the full middleware stack, with a browser's
headers, the file's sign-in, CSRF tokens and cookies. The file is Ruby in `ActionDispatch::IntegrationTest`'s words:

```ruby
article = Article.first!
get articles_path
get article_path(article), headers: { "Accept" => "text/html" }
```

**The requests are real.** Without `--allow-writes` it sends only GETs: a file with a write, a POST sign-in, a
`setup` block, `jobs: true`, or a GET that would reach the app as another method (an `env:` or header that changes
it, or a JSON GET with params in an app without `Rack::MethodOverride`) is refused before anything is sent, and so
is `RAILS_ENV=production` with a writable database on another host (any configuration but a replica, including
`database_tasks: false` ones) or a database configuration that does not load. The guard checks each request as the
file declares it; what a block or `alternate:` returns per turn (a path and params, never a method) is not checked
again. With `--allow-writes` the requests write to the app's database, enqueue through its queue adapter
and deliver mail as configured: use a disposable database, queue and mail service. `--workloads` needs the gem in a
group the environment's `bundle install` keeps.

## Guarantees

Each is checked by a test in this gem or on the apps below.

1. **No app changes.** It writes only inside `--out` and the `--record` target, and never edits the Gemfile,
   config or code. Processes the suite starts run unprofiled, without its seed: on Dawarich an `after(:suite)` that
   regenerates `swagger.yaml` with a nested rspec rewrote it in a different order when that rspec got the seed.
2. **No lowering.** The package holds only the profiler; it never loads Lowrail's runtime.
3. **Off means off.** With the gem listed and `require: false`, a process the command did not start loads none of
   it.
4. **Same outcomes.** On Campfire, Lobsters, CodeTriage and a Rails 7.2 / Ruby 3.3 blog, installed from this gem
   on Linux, per-test outcomes were identical plain, listed-but-off and profiled. CodeTriage prints an outcome for
   217 of its 222 tests; for the other 5 only the suite's totals (0 failures) are compared. Each app process loaded
   the same files in the same order as `bundle exec env COMMAND` (the process boundary the profiler starts the
   command at; a plain `bundle exec COMMAND` loads Bundler's own files differently), leaving out Lowrail's,
   Bundler's and RubyGems' files and, on CodeTriage, 27 yard handler and code-object files that yard loads by
   walking `Module#constants`, in an order of its own. On macOS, Campfire's per-test outcomes were identical; its
   load order was not compared there
   ([the evidence](https://github.com/thomasklemm/lowrail/blob/main/docs/profile.md)). That is a claim about those
   apps, not every app. Check yours: run the suite plain and profiled with the same seed and diff the
   per-test results (`bin/rails test -v`, `rspec --format documentation`).
5. **Exit status passes through** (a failed or killed run's status, above), and compare never turns invalid
   evidence green (exit 2).
6. **Never breaks the app.** A counter that fails to build stops lowrail-profile before the command starts, with
   the build log's path; the app never runs half-profiled. Once the command runs, a counter that fails to load or
   is of another version, or a framework hook that cannot be installed, prints one `[lowrail-profile]` warning and
   leaves the app as it is. Hooks are installed from Active Support's `on_load` hooks, so nothing loads earlier
   than the app loads it.

## Troubleshooting

* *building the counter failed, see …build.log*: install a C compiler and Ruby's headers (`build-essential` on
  Debian/Ubuntu, Xcode Command Line Tools on macOS).
* *no runs with requests, jobs or mails*: the command served no request through `Rails.application` (unit tests
  only, a server started in another process, or a warm Spring server: bypass it with `DISABLE_SPRING=1`). Profile
  integration, request or system tests. Controller tests (`ActionController::TestCase`, rspec-rails controller
  specs) call the controller directly, without the app's middleware and routing, and are not counted: a suite of
  only those counts no requests, and in a mixed suite the report covers its integration tests alone. The report and
  this error say how many requests the controller tests made. Rails' generated `test/controllers` tests are
  integration tests and are counted.
* *exists and was not created by lowrail-profile*: pick another `--out`; it never clears a directory it did not make.
* Overhead: the first run counts (4–9% of suite time on the four apps measured), the second also walks the stack
  per allocation (31–87%, most on allocation-heavy suites such as Campfire's). Measured per app in the evidence.
* Code in Ractors other than the main one is not counted.

Report issues with `report.json`, `capture.json` and the command at
[github.com/thomasklemm/lowrail/issues](https://github.com/thomasklemm/lowrail/issues).
