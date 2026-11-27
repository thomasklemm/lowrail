# lowrail-profile changelog

## 0.1.1 (unreleased)

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
* Tests: `QUIT` reaches the command under `--timeout`, a signal that comes before the command is started reaches it
  once it runs, and `profile_test.rb` is split into `profile_test.rb`, `profile_record_test.rb` and
  `profile_cli_test.rb`.

## 0.1.0 (not published)

Built from `644c99e4` as `0.1.0.rc1`.
