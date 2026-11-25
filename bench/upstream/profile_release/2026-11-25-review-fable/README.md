# lowrail-profile 687f168b..1618fc38: thermos-fable review receipts (2026-11-25)

Receipts for the *Post-field-test review: thermos-fable* section of
[profile-release-review-2026-11-25.md](../../../../docs/upstream/profile-release-review-2026-11-25.md). The gem
was built in `gem/` at `1618fc38` (sha256 `e5b8991d963ebd1bf5e4c984c236c821becea0bb9a62506f088bc5cc6b4ca4b5`) and
installed with `gem install --local` into Ruby 4.0.7 and 3.3.14. Everything ran in one orb, with apps under
`/tmp/pr`; the scripts keep those paths.

* [smallest-fixes.patch](smallest-fixes.patch): the reviewer's fixes for must-fixes 1 to 4 and the symlinked path
  gem, against `1618fc38` (27 added lines, 12 removed). It is not applied to `gem/`. With it the profile suites give
  35 runs and 0 failures on both pairs (`logs/suite-fixed-*.txt`).
* `scripts/setup-gems.sh`, `suite.sh`: CI's gem set and its *Profile tests* step. `logs/suite-40.txt`,
  `suite-33.txt`: the suites at `1618fc38`.
* `scripts/revert.sh`, `reverts-all.sh`: each commit's tests against its parent's gem code. `logs/reverts-*.log`.
* `scripts/fresh-app.sh`, `probes/minitest-probes.sh`, `probes/probe.rb`, `probes/t4.sh`: the fresh Rails 8.1 app
  and what its child processes see, plain and profiled. `logs/t4-fresh81.log` (no seed, `SEED=99`) and
  `t4-fresh81-par2.log` (two workers; that run predates the `Bundler.with_*_env` probes). A child named
  `helper_load` differs by design (it starts before Minitest reads its options); `*_original_env` and
  `*_unbundled_env` are must-fix 2; `after_run_nested_suite` differs only by its random seed and timing.
* `scripts/rspec-app.sh`: the RSpec app on Rails 7.2. `logs/t4-rspec72.log`: the same comparison; ` M
  swagger/order_unbundled.txt` after a profiled run is the nested rspec that got the seed.
  `scripts/t4-rspec-extra.sh`, `logs/t4-rspec-extra.txt`: `rake spec`, a Minitest file and `--workloads` in that
  app, before `dbe31072`, with the built gem and with the fix (must-fix 1).
* `scripts/t1-app.sh`, `t1-report.rb`, `t1-vendor.sh`: the path-gem fixtures. Each `many` allocates its count of
  Strings and one Array in 7 of 13 requests. `logs/t1-head.txt` (built gem) and `t1-fixed.txt` (with the fix).
* `scripts/t7.sh`, `logs/t7-out.txt`: disk use, `--keep-runs`, `report`, and the path table's saving.
* `scripts/t8.sh`, `logs/t8.log`: `--timeout 20` with a hanging test (`HANG=1` exits on `TERM`, `HANG=ignore` does
  not), serial and with two workers. `t8.log` predates the script's check for worker process titles, so its last
  case says *nothing left running* although `Rails test worker 0` was (found by its PID). `logs/t8-fixed.log`:
  that case with the fix.
* `scripts/ci-job.rb`, `ci-job.sh`, `logs/ci-job.log`: the README's CI job, each `run` step under `bash -e`, for
  an unchanged head, a planted one, a failing suite, and two workers.
* `scripts/osm-check.rb`: the README's OSM numbers from the captures in `oss_profile_sweep_1/osm`.
* `scripts/misc.sh`, `logs/misc.txt`: lowrail-profile outside `bundle exec`, T2, `--out` with glob characters,
  `--timeout` under a pty.
