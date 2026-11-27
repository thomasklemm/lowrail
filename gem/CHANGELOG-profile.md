# lowrail-profile changelog

## 0.1.1 (2026-11-27, not published)

* An engine profiled in place, whose own directory is both the app root and a path gem, keeps the files under a
  directory named `gems` (such as `app/views/gems/index.html.erb`) as app lines, like its other files; 0.1 ranked them
  as the engine gem's. So does a dummy app below an engine kept in a `gems/` directory. A path gem kept inside the app
  (`gems/`, `vendor/gems/`) is still ranked as that gem.
* Controller tests (`ActionController::TestCase`, rspec-rails controller specs) still count no requests, but the
  report now says how many requests they made ("Not counted in run 1: N requests made by controller tests"), and so
  does the error when nothing else was counted. In the census field test Loomio counted 68 requests from 1,491 tests
  and OpenProject's controller specs none, with only the counts to show for it. report.json has `controller_tests`
  per run.
* compare says above its tables how many actions it did not compare and why ("Not compared: 6 of 20 actions (6 no
  warm value in base and head), so a change in them is not checked"), and lists them in a table; 0.1 gave one count
  at the end. A missing warm value names the report that lacks it.
* README: the `--workloads` production example needs the production database, with the records the file names, and
  compiled assets, and on a new Rails 7.2 app a production database path; the README says so.
* Network connects are counted apart: what `Socket.tcp` allocates while it connects follows timing, not code (it
  races its attempts on threads and timers). On Hackatime in one process ViteRuby probes its dev server at most once
  a second, so which request paid about 400 objects for it changed from run to run, and compare listed
  `Admin::AdminUsersController#index` and `RUBY/socket.rb:72` on unchanged code. Objects allocated inside a
  `Socket.tcp` call without a block (a module prepended to `Socket` once the app has loaded it) are left out of their
  action and lines; the report and compare say how many by kind and run (`network` per action and run, `network` in
  compare's `--json`). Reads and writes on a socket, and `Socket.tcp` with a block, are still counted and compared.
  report.json is format 4 and the raw counts `# lowrail-profile 4`: profile again.
* README: reset the test database before every capture (the CI job now runs `db:test:prepare` before base2 too).
  CASA's `ChecklistItemsController#new` read 3,511 warm objects per request with record IDs from 9,000 and 3,494
  from 100,000, so captures that continue each other's IDs differ.
* A file `ActionDispatch::Static` serves before routing is a request named `ActionDispatch::FileHandler#serve`, not
  one with no action name, and the header says how many there were and the other requests' objects per request,
  counted as the Actions table counts them (none when every request was a file). In a
  field test most of a system-test slice's requests were the browser fetching such files. report.json has
  `static_requests` and `objects_per_dynamic_request` per run.
* The header's table gives objects per request warm too (each line's first request per process left out, as the
  noise floor counts), next to all, which includes one-time work (`warm_per_request` in report.json).
* By gem counts dev/test-mode work as a group of its own, as its own table lists it, instead of in each gem (an error
  page's `Prism.parse_file` per frame ranked Ruby's standard library and prism high); groups at 0.0 warm objects
  are named in one line instead of listed as rows, top lines at 0.0 are left out, and the report says what a `:0`
  line is. *From the app* marks
  app middleware that only hands the request on (*(middleware)*): it is the nearest app line of an error page, not
  the line that raised.
* compare refuses the base passed as its own A/A report (exit 2) and warns when the A/A report has exactly the
  base's counts.
* `--timeout` also stops the processes a run started in a group of their own (selenium-webdriver's driver and
  browser), which outlived exit 124 before, as long as they are still found from the run: a daemon whose parent
  exited before the deadline is not.
* The gem's description no longer says "CI gate": compare is a report and exits 0 when it lists a regression.
* README: installing from GitHub (`github:` with `glob:`), and its size; captures taken at different times differ
  more than 1% when the app's work depends on the clock, so profile the base twice and pass `--aa`.
* Tests: `QUIT` reaches the command under `--timeout`, a signal that comes before the command is started reaches it
  once it runs, and `profile_test.rb` is split into `profile_test.rb`, `profile_record_test.rb` and
  `profile_cli_test.rb`.

## 0.1.0 (not published)

Built from `644c99e4` as `0.1.0.rc1`.
