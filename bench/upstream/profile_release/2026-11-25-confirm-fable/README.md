# lowrail-profile 1618fc38..0ee4aed2: thermos-fable confirm receipts (2026-11-25)

Receipts for the *Confirm of the review fixes: thermos-fable* section of
[profile-release-review-2026-11-25.md](../../../../docs/upstream/profile-release-review-2026-11-25.md). The head
moved three times during the pass, so four gems were built in `gem/` and installed with `gem install --local` into
Ruby 4.0.7 and 3.3.14, one after another: `7a5ee0b6` (sha256 `6a807858…94470`), `60387485` (`c4a3a7c3…29df68`),
`53a071fd` (`d1e80952…f3f5`) and `0ee4aed2`
(`57eb11b39028eb34fd9d86ebdd9dfc12f18edeab8d9beb5a886e40abc4ef518d`), each as stated. `gem/lib`, `gem/ext` and the
README are the same from `9b31044c` to `0ee4aed2`; only `gem/exe` changed after `7a5ee0b6` (the counter's build and
`--timeout`'s wait for the group), so a log names the gem it ran with. Everything ran in one orb with the apps of
the first review under `/tmp/pr` ([2026-11-25-review-fable](../2026-11-25-review-fable/README.md), whose scripts the
ones here call); the scripts keep those paths.

* [smallest-fixes.patch](smallest-fixes.patch): the reviewer's fixes for the two must-fixes, with one test row,
  against `0ee4aed2` (it applies with `git apply`). It is not applied to `gem/`. `logs/suites.txt` has the profile
  suites with it on both pairs.
* `scripts/suite.sh`: `ci.yml`'s *Profile tests* step. `logs/suites.txt`: its summary line at each of the four
  heads on both pairs.
* `scripts/mutants.rb`: one fix undone at a time in a worktree, then the test said to cover it.
  `logs/mutants-60387485.txt`, `mutants-53a071fd.txt` (every mutant) and `mutants-0ee4aed2.txt` (those of the exe
  and of the tests `776ef498` added).
* `scripts/run-a.sh` (gem of `7a5ee0b6`): the first review's reproductions again.
  * `rspec-extra.sh`, `logs/rspec-extra-*.txt`: the first pass's must-fix 1 (rswag-specs): `rake spec`, a Minitest file, `--workloads`.
  * `logs/t4-rspec72.log`, `t4-rspec72-outcomes.txt`, `t4-fresh81.log`: plain against profiled, per test and per
    child process. In `t4-rspec72.log` the outcome comparison is left out: its pattern also matched RSpec's numbered
    list of pending examples, whose order follows the seed; `t4-rspec72-outcomes.txt` compares the example lines.
    `helper_load` differs by design (now in the README), `after_run_nested_suite` by its random seed and timing, and
    a non-Ruby child sees `RUBYLIB` unset where a plain run has it empty.
  * `logs/t8-7a5ee0b6.log`: `--timeout 20` with a hanging test, serial and with two workers.
  * `logs/misc.txt`: lowrail-profile outside `bundle exec` (the first review's script runs it twice, as *built gem*
    and *fixed*; both are the installed gem here), T2, `--out` with glob characters (again at `53a071fd` in its
    last line), `--timeout` under a pty.
  * `logs/t7-out.txt`: disk use, `--keep-runs`, `report`.
* `scripts/run-b.sh` to `run-e.sh` (gem of `60387485`):
  * `logs/t1.txt`, `t1v.txt`: the path-gem fixtures, and the same with the bundle in `vendor/bundle`.
  * `stream-equal.rb`, `logs/stream-equal.txt`: the report of kept runs built by `1618fc38`'s lib and by the new one.
  * `gems-dir.rb`, `gems-app.sh`, `logs/gems-dir.txt`, `gems-app.txt`: must-fix 1 below, on written runs and on a
    copy of the fresh app with a `GemsController`.
  * `trap-restore.rb`, `logs/trap-restore.txt`: a signal during the report, after a `--timeout` run, with and
    without the line that restores the traps.
  * `ci-job.rb`, `ci-job.sh`, `logs/ci-job.log`: the README's CI job; after a failed step only steps with
    `if: always()` run.
  * `m523.sh`, `logs/m523.txt`: Minitest 5.23.1, where the profiler prepends to Minitest instead of registering a
    plugin. `bundle update --local` exits 7 on a platform gem it does not need; the lock and the run have 5.23.1.
  * `build-unbundled.sh`, `logs/build-unbundled.txt`: the counter built under an app's bundle.
  * `replay.sh`, `logs/replay.txt`: `run_options.sh` for seven sets with the checkout's `gem/lib` (six in the
    script; `hackatime-serial` was run by hand before it, 3 min 41 s). `git status` at its end lists nothing, so
    every `options-*.txt` came out byte for byte. OSM's serial captures were read from
    `bench/upstream/oss_profile_sweep_1/osm/s1`–`s5` through a symlink at the path `run_options.sh` expects.
* `scripts/run-f.sh` (gem of `53a071fd`) and `run-g.sh` (gem of `0ee4aed2`): `ps-probe.rb`, `logs/ps-probe.txt`
  (a `ps` that fails, before and after `0ee4aed2`), the trap and glob checks again, `t8-53a071fd.log`,
  `t8-0ee4aed2.log`, the suites and the mutants.
* `scripts/forem-drift.rb`, `logs/forem-drift.txt`: must-fix 2, from Forem's captures in `oss_profile_sweep_1/forem`.
