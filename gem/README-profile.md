# lowrail-profile

**Exact object allocation counts for your Rails app, per request, job, mail and Action Cable action, by source
line, in your code and in the Rails, Ruby and gem code it calls.** It runs your test suite (or a recorded request
mix) with allocation counting on and tells you which lines allocate the most per request, which of your lines lead
there, and whether an upstream pull request already changes that line.

It counts objects. It does not measure time, CPU, retained memory or SQL, and it never changes or lowers your app.
For time, pair it with [vernier](https://github.com/jhawthorn/vernier) or your APM.

Experimental release candidate (0.1.0.rc1). Supported: Ruby 3.3, 3.4 and 4.0; Rails 7.2, 8.0 and 8.1; Linux and
macOS. Windows is refused with a message.

## Install

```ruby
# Gemfile
gem "lowrail-profile", group: [:development, :test], require: false
```

Until 0.1 is on rubygems.org, build the release candidate from a Lowrail checkout. The gemspec's file list is
relative to `gem/`, so build it there:

```sh
cd lowrail/gem && gem build lowrail-profile.gemspec && gem install --local lowrail-profile-0.1.0.rc1.gem
```

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
such as `rake test`'s parent, passes both on to the suite. lowrail-profile exits with its status: the first failing run's exit
code, or 128 plus the signal that stopped it (143 for `TERM`). A passing suite whose report cannot be built exits 1.

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
| `--help`, `--version` | | |

## Reading the report

The header says what was counted: command, Ruby, Rails and environment, how many requests, jobs, mails and Cable
actions, and the ledger's date. Then:

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
* **By gem**, and **Outside requests**: jobs (`perform_now`), mails (build and delivery) and Cable actions, counted
  the same way. A job or mail inside a request counts as part of that request.

Line keys are `RAILS/<component>/path:line`, `GEM/<name>/path:line`, `RUBY/path:line` and `APP/path:line`.

**Ledger.** A dated snapshot of upstream pull requests that reduce allocations ships with the gem. A line matches
when a pull request changes that very line (same repository, file and method, and the line's code is among the
lines it removes or adds). The cell says what that means for the version your lockfile runs: *open upstream work*,
*fixed in 8.2.0* (upgrade), *merged, not released yet*, or *merged, in 7.2.3, which this app runs*. The ledger covers
the pull requests its authors track, not every upstream fix, and a snapshot goes stale: the header gives its date.

**Counts are not time.** A line with many objects is a place to look; some allocations are cheap. **A suite is not
traffic**: it requests what tests need, with a test user agent, in test mode. `--workloads` (below) gets closer.

## Compare in CI

`compare BASE.json HEAD.json --aa BASE2.json` exits **1** when a line or an action grew beyond its noise floor,
**0** when nothing did, and **2** when the reports are not valid evidence: a failing suite, one run, a different
command, seed, Ruby or environment, dropped samples, unfinished windows, or a report of another version. `BASE2`
is a second profile of the unchanged base: the A/A pair sets the floor per row (twice the larger of a row's spread
across both base profiles and head's own spread; for a line at least `--min`, default 1 object per request, for an
action at least 0.1% of its objects and 20 × `--min`). Without `--aa` compare lists changes as places to look and exits 0:
it is not a gate. `--json` prints the result as JSON.

An action is compared only under the same name in every report: a renamed or new action, or one that ran in base
only, is listed under *Not compared* with the reason, and nothing about its own cost gates. Lines outside the app it
reaches are still compared.

A GitHub Actions job that profiles the pull request's base twice and its head once, and fails on a regression that
a second profile of head shows too:

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

Both checkouts need the gem in their Gemfile; if the base does not have it yet, run the base step with the head's
Gemfile (`BUNDLE_GEMFILE`). Keep `shell: bash`: without it `tee` turns compare's exit status into 0. Check the suite
itself in its own job: a failing suite makes compare exit 2. The job runs the suite three times, each twice (six
suite runs), and twice more only when the first compare exits 1; `--runs` and a narrower command (`bin/rails test
test/controllers test/integration`) make it cheaper.

**Why head is profiled again.** One A/A pair is one sample of how much two invocations differ, not a bound, and a
capture can read other values on a line in both its runs (parallel workers split the requests differently). A
regression is in every profile of head; such a capture is in one. So a single exit 1 is a place to look, and the job
fails only when a second profile of head exits 1 too. Measured over every assignment of unchanged captures to base,
A/A and head: on a generated Blog (12 captures) one compare flagged 1.7% of unchanged heads and the job 0.03% (4 of
11,880); on a fresh Rails 8.1 app with two process workers (24 captures) 0.8% and 0.16%, from one line whose count
depends on how the workers split seven requests. Every planted regression was still caught, in both profiles of
head, on the Blog, Campfire, CodeTriage and Lobsters.

## Experimental: `--record` and `--workloads`

```sh
bundle exec lowrail-profile --record -- bin/rails test     # also write lowrail/workloads.rb
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec lowrail-profile --workloads
```

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
  only those counts no requests, and in a mixed suite the report covers its integration tests alone. Rails'
  generated `test/controllers` tests are integration tests and are counted.
* *exists and was not created by lowrail-profile*: pick another `--out`; it never clears a directory it did not make.
* Overhead: the first run counts (4–9% of suite time on the four apps measured), the second also walks the stack
  per allocation (31–87%, most on allocation-heavy suites such as Campfire's). Measured per app in the evidence.
* Code in Ractors other than the main one is not counted.

Report issues with `report.json`, `capture.json` and the command at
[github.com/thomasklemm/lowrail/issues](https://github.com/thomasklemm/lowrail/issues).
