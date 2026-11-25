# Ruby 4.1 differential, round 1: census app suites on master and zjit-headline2

The first round of the "correctness before Ruby 4.1" bet (DECISIONS, "Next bets after the first three"). Each census
app's own test suite runs on the interpreter, `--yjit`, `--zjit --zjit-call-threshold=1` and `--zjit`, on Ruby master
and on k0kubun's zjit-headline2. Outcomes are compared per test, including the exception class of failures. Each
difference is rerun alone, three times each on the interpreter, at `--zjit`, at `--zjit-call-threshold=1` and in the mode
where it differed. This is Z11's method ([zjit-app-differential.md](zjit-app-differential.md),
[zjit-differential.md](zjit-differential.md#z11-on-three-census-apps)), now in one rerunnable script.

**Result.**

* **Ruby master `42a644f6e0`: no divergence.** 10 apps, 54,508 tests per mode, 4 modes. Two tests differ from the
  interpreter, and both are flakes in the apps' own tests, not Ruby effects (below). No crash, `[BUG]` or Rust panic.
* **zjit-headline2 `f2c3f457ff`: one divergence, [Shopify/ruby#1133](https://github.com/Shopify/ruby/issues/1133).**
  It is a wrong result: `TypeError: no implicit conversion of … into Hash`. It breaks Active Record inserts in 6 of the
  10 apps under ZJIT, at the default threshold and in 4 of them at threshold 1. The cause is an implicit-argument
  `super` from a method with keyword parameters into a `def m(...)` method. Rails' PostgreSQL adapter makes that call
  on every record insert, and all six affected apps use PostgreSQL. CodeTriage, also on PostgreSQL, is not affected;
  why was not examined. The first bad commit is headline2's **`58b019f6fe`** "ZJIT: Specialize zsuper from methods with
  keyword parameters" (k0kubun, 2026-11-21); its parent `2d609d397d` is good. It is not on master. The same commit is
  in `zjit-headline3` (`c3c92dd544`) and the `zjit-sfr-exp/*` branches, and no branch has a later fix. Before this
  round no issue, PR or bugs.ruby-lang.org report existed. #1133 was opened from this round's report, and the fix
  (thomasklemm/ruby `zjit-zsuper-forwardable`, `2dc14101c3`) passes the same checks as the revert (below). YJIT on headline2 matches the interpreter everywhere.
* **headline2 with `58b019f6fe` reverted: no other divergence.** #1133 masked most of five suites, so the same 10
  apps ran again on headline2 minus that commit, on the interpreter and at `--zjit`, plus `--zjit-call-threshold=1` for
  the four apps #1133 hit at threshold 1. They match the interpreter, apart from Sure's flaky race test (below).

| Build | Apps | Modes | Test executions | Divergences |
| --- | ---: | --- | ---: | --- |
| master `42a644f6e0` | 10 | interp, yjit, zjit1, zjit | 218,032 | none |
| headline2 `f2c3f457ff` | 10 | interp, yjit, zjit1, zjit | 181,810 (38 of 40 runs; Sure zjit and zjit1 hung, below) | #1133 |
| headline2 − `58b019f6fe` | 10 | interp, zjit; zjit1 for Sure, Loomio, CASA, Hackatime | 130,698 (24 runs) | none |

`zjit1` is `--zjit --zjit-call-threshold=1`, `zjit` is `--zjit` at the default threshold (30).

## Shopify/ruby#1133: zsuper with keywords into a `(...)` method

Standalone repro [`repros/zsuper_kw_fwd.rb`](../../bench/upstream/ruby-differential/repros/zsuper_kw_fwd.rb):

```ruby
class Base
  def m(*args, **kw) = [args, kw]
end
class Middle < Base
  def m(...) = super
end
class Top < Middle
  def m(a, k: nil) = super
end
o = Top.new
100.times do |i|
  got = o.m(1, k: 2)
  raise "iteration #{i}: #{got.inspect}" unless got == [[1], {k: 2}]
end
puts "ok"
```

| Ruby | interp | `--yjit` | `--zjit` | `--zjit-call-threshold=1` | `--zjit-call-threshold=2` |
| --- | --- | --- | --- | --- | --- |
| headline2 `f2c3f457ff` | ok | ok | **TypeError** in `Middle#m` | ok | **TypeError** |
| headline2 − `58b019f6fe` | ok | ok | ok | ok | ok |
| master `42a644f6e0` | ok | ok | ok | ok | ok |

Each part is needed. An explicit `super(a, k:)` works, a middle method `(*a, **k)` or `(*, **)` instead of `(...)`
works, and a caller without keyword parameters works. The commit makes ZJIT pass the zsuper's `newhash` keyword
splat (`invokesuper ZSUPER|KW_SPLAT|KW_SPLAT_MUT`) to an ISEQ target as explicit keywords. It does not exclude
forwardable (`...`) callees, which receive the callinfo as is and read the explicit keyword values as the keyword hash.
In the apps the chain is `PostgreSQL::DatabaseStatements#insert(…, returning:)` → `super` →
`QueryCache#insert(...)` → `super`, the path of every record insert on PostgreSQL.

In the apps it also fails at threshold 1, which the repro does not. Two variants (an extra call frame, `Middle#m`
called directly first) still print ok at threshold 1. CASA's
`spec/callbacks/case_contact_metadata_callback_spec.rb` is the threshold-1 check: 15 of 16 examples fail on headline2
at threshold 1 and none with the commit reverted. Of the 35 sampled tests rerun alone (5 per whole-suite failure,
[`reruns.json`](../../bench/upstream/ruby-differential/runs/2026-11-25-zjit-headline2-f2c3f457ff/reruns.json)), all pass on
the interpreter. 24 fail 3 of 3 at threshold 1, and 7 of those also at the default threshold. The other 11 pass alone
in every mode and fail only in the full suite, where the methods have been called from more sites first.

**Bisect** (headline2 range `4abea25ab0..f2c3f457ff`, 104 commits). From the subjects, `58b019f6fe` was the suspect;
it fails the repro at `--zjit-call-threshold=2` and its parent `2d609d397d` passes. A full `git bisect run` over the range
with [`bisect-test.sh`](../../bench/upstream/ruby-differential/bisect-test.sh) (a miniruby build per step, 7 steps) gives
the same first bad commit, `58b019f6fe`
([log](../../bench/upstream/ruby-differential/runs/2026-11-25-zjit-headline2-f2c3f457ff/bisect-1133.log)). With
`58b019f6fe` reverted on `f2c3f457ff`, the repro and the apps pass.

**Ownership.** The commit is k0kubun's, on his own branch, and not on master. Before this round, searches of
Shopify/ruby issues ("zsuper", "keyword splat super", "forwarding"), ruby/ruby PRs and bugs.ruby-lang.org found nothing
(the nearest are fixed: Bug #20213, zsuper with `KW_SPLAT_MUT`; Bug #22527, zsuper with a reassigned kwrest). Shopify/ruby#1133
was opened from this round's report on 2026-11-25. The fix was written in another thread.

### The fix, checked: thomasklemm/ruby `zjit-zsuper-forwardable` `2dc14101c3`

The fix thread's commit on headline2 `f2c3f457ff` keeps the zsuper dynamic for forwardable callees, as before
`58b019f6fe` (record: [zjit-zsuper-forwardable.md](zjit-zsuper-forwardable.md)). It was built here like the revert
build and compared with it. Identical results were expected, and that is what came out:

| Check | headline2 | headline2 − `58b019f6fe` | headline2 + `2dc14101c3` |
| --- | --- | --- | --- |
| Repro, `--zjit` / threshold 1 / threshold 2 | TypeError / ok / TypeError | ok / ok / ok | ok / ok / ok |
| CASA `case_contact_metadata_callback_spec.rb`, threshold 1 | 15 of 16 fail | 0 of 16 | 0 of 16 |
| the same, default threshold | 14 of 16 fail | 0 of 16 | 0 of 16 |
| CASA suite, zjit1 / zjit (2,992) | 2,271 / 2,270 differ | 0 / 0 | 0 / 0 |
| Mastodon suite, zjit1 / zjit (7,748) | 0 / `before(:suite)` fails, 0 examples | – / 0 | 0 / 0, `before(:suite)` gets through |
| Discourse suite, zjit1 / zjit (22,128) | 0 / 16,769 differ | – / 0 | 0 / 0 |

The fix build's runs are compared with the revert build's interpreter baseline (`compare --base-label`). Each one has
the same failing tests, with the same exception classes, as the revert build's run in the same mode.

### Where #1133 shows in the suites (headline2)

| App | zjit (default) | zjit1 |
| --- | --- | --- |
| Discourse | 16,769 of 22,126 differ (9,125 `TypeError`, 7,538 `NoMethodError`) | 0 differ |
| Mastodon | 0 examples: `before(:suite)` seeds fail (`db/seeds/05_blocked_usernames.rb`) | 0 differ |
| CASA | 2,270 of 2,992 | 2,271 |
| Loomio | 2,195 of 3,660 | 2,196 |
| Hackatime | 625 of 794 | 630 |
| Sure | hung after 235 of 14,236 tests (`Import::CategoryMappingTest#…concurrent_imports`), stopped at 61 min | the same, stopped at 70 min |
| Campfire, Writebook, Fizzy, CodeTriage | 0 differ | 0 differ |

With `58b019f6fe` reverted, every one of these matches the interpreter (table below), so Discourse's `NoMethodError`s
and the Sure hang come from #1133 too. How they follow from it (likely a nil record after a failed insert, and a thread
waiting for one whose insert raised) was not traced.

## Differences that are not divergences

| Build, mode | App, test | Alone, 3 runs each | Verdict |
| --- | --- | --- | --- |
| master yjit | Discourse `spec/jobs/scheduled/notify_admins_of_available_upcoming_changes_spec.rb[1:10:2:1]`: names in the other order | pass in interp, yjit, zjit, zjit1 (12 of 12) | **App test order**: `upcoming_changes_to_notify` is `SELECT DISTINCT … UNION …` without `ORDER BY`, and the spec expects one order |
| master zjit; headline2 − `58b019f6fe` zjit and zjit1 | Sure `FamilyMerchantConcurrencyTest#test_find_or_create_with_name_survives_a_real_unique-constraint_violation…`: "reader never blocked on the unique index … timed out waiting" | interp: pass, error, error (`RecordNotUnique`); zjit: error, fail, pass; zjit1: pass ×3 | **Timing flake**: a two-thread race on `pg_stat_activity` with a 10 s wall-clock deadline; it fails on the interpreter alone too |

Campfire's known `SqliteWalCheckpointTest` flake did not show in any run this round.

## Pins and method

* **Ruby**, release builds (`--enable-zjit --enable-yjit`, Rust 1.100.0), one binary per tree for every mode:
  * master [`42a644f6e0`](https://github.com/ruby/ruby/commit/42a644f6e0) (2026-11-25, the tip when the round ran);
  * zjit-headline2 [`f2c3f457ff`](https://github.com/k0kubun/ruby/commit/f2c3f457ff), still its head on 2026-11-25
    (104 commits on master `4abea25ab0`), the commit [zjit-gap-census-2](zjit-gap-census-2.md) measured;
  * headline2 with `58b019f6fe` reverted (`67bb8ca772`, local), installed over a copy of headline2's prefix so it uses
    the same gems;
  * headline2 with the #1133 fix, thomasklemm/ruby `zjit-zsuper-forwardable` `2dc14101c3`, installed the same way.
* **Apps**, each in `.corpus/censusrd-APP` (not checked in):
  * Campfire `af4dd9f`, Writebook `7478e2c` and Fizzy `77eada1` on their Rails 8.2 pins (`script/corpus APP-r82`, as in
    Z2 and zjit-gap-census-2), with the ruby pin dropped and Writebook's redcarpet at 3.6.1.
  * The PostgreSQL apps through `script/census setup --corpus censusrd` on Rails main
    [`cf0325a832`](https://github.com/rails/rails/commit/cf0325a832) with F1's master overlays
    ([`overlays/`](../../bench/upstream/ruby-differential/overlays), links to `fixtures/corpus/frontier-master`):
    CodeTriage `d1868f8`, Mastodon `5ccbf0e`, Sure `8d0d84d`, Loomio `407d4a8`, CASA `b584d2e`, Hackatime
    `74deec4` and Discourse `0f52471`.
* **Services**, started here: PostgreSQL 17.12 (pgvector 0.8, pg_partman, `fsync=off`), memcached 1.6.38, and a
  **private Redis 8.0.2 per run** (below). MariaDB 11.8 was started for the MySQL configuration, but none of the seven
  apps uses MySQL, so it went unused.
* **Isolation.** Each run works in a fresh copy of the app (`rsync`, `node_modules` linked). Its PostgreSQL database
  is cloned from a template that `setup` loads once per app (`createdb -T`), so every mode starts from the same rows
  and sequences. That removes Z11's Discourse upload-sequence artifact. Each run also gets its own `redis-server`, on
  a port claimed with a lock file.
* **Recorder.** [`recorder.rb`](../../bench/upstream/ruby-differential/recorder.rb), loaded through `RUBYOPT`,
  records every Minitest result with its exception class and file, and which JIT actually ran; RSpec uses its JSON
  formatter. It also keeps the interpreter baseline on the interpreter: Rails' `:enable_yjit` initializer
  (`config.yjit`, on under `load_defaults` 7.2 and later), Writebook and Sure call `RubyVM::YJIT.enable` after boot.
  Every run's recorded `yjit`/`zjit` state matched its mode.
* `PARALLEL_WORKERS=1`, `TZ=UTC`, `CI=1`, Minitest `--seed 41231`, RSpec `--order defined`. Browser system specs are
  excluded (no driver), as in Z11.

### Workarounds, the same in every mode

* rspec-rails 8.0.x writes into the frozen `default_url_options` of Rails main:
  [`rspec_rails_fix.rb`](../../bench/upstream/ruby-differential/rspec_rails_fix.rb) (Z11's) in Mastodon, CASA and
  Discourse (and Lobsters).
* **Sure**: `minitest-mock` (Minitest 6 split out `Minitest::Mock`).
* **Discourse**: the libvips ≥ 8.18 boot check is skipped by `RDIFF_NO_VIPS` (the orb has 8.16), so image-processing
  specs fail in every mode. `activejob` is added to its Rails component list: Rails main
  [`1897e3587f`](https://github.com/rails/rails/commit/1897e3587f) ("Break hard dependency between Action Mailer and
  Active Job") dropped it from Action Mailer's gemspec, and Discourse's mailers still load it.
* **CodeTriage**: bluecloth 2.2.0 and rbtrace 0.5 do not compile on master (`Data_Wrap_Struct`, the old
  `rb_proc_new`); neither is loaded by the tests, so
  [`overlays/codetriage.sh`](../../bench/upstream/ruby-differential/overlays/codetriage.sh) drops them.
* Master's installed bundler 4.0.20 was incomplete after eight parallel `bundle install`s
  (`cannot load such file -- …/bundler/vendored_persistent`); `build` reinstalls it once.

### Not run

* **Lobsters**: the suite fails before the first example on Rails main (`before(:suite)`: `User has no attribute
  prefers_color_scheme`, activerecord-typedstore 1.6.0), on the interpreter too, as in zjit-gap-census-2.
* **OpenProject** (`a3cc89f7d7`, dev, own Rails 8.1.4.1) does not bundle on master. Its C extensions still use untyped
  data: rbtree3 0.7.1 (airbrake-ruby; stubbed), cbor (nobu's TypedData branch fixes it) and then eventmachine 1.2.7
  (puffing-billy), with more likely behind them. Its suite is 61,109 examples, about 90 minutes per mode with one
  worker. It needs its own master overlay first.
* Docuseal, Lago (bullet), Chatwoot and Flow, as in Z11.

## Per-app results

Test counts are the same in every mode and build unless the table says otherwise. "Failing in all" means failing in
every mode, with the same exception class.

| App | Suite | Tests | Failing in all | master differ (yjit / zjit1 / zjit) | headline2 differ (yjit / zjit1 / zjit) |
| --- | --- | ---: | --- | --- | --- |
| Discourse | RSpec: models, lib, serializers, services, jobs | 22,128 | 238 F | 1 (order) / 0 / 0 | 0 / 0 / #1133 |
| Sure | Minitest | 14,236 | 15 F, 24 E | 0 / 0 / 1 (race) | 0 / hung / hung |
| Mastodon | RSpec, no system specs | 7,748 | 288 F | 0 / 0 / 0 | 0 / 0 / #1133 |
| Loomio | Minitest | 3,660 | 1 F, 2 E | 0 / 0 / 0 | 0 / #1133 / #1133 |
| CASA | RSpec, no system specs | 2,992 | 224 F | 0 / 0 / 0 | 0 / #1133 / #1133 |
| Fizzy | Minitest | 1,787 | 4 E | 0 / 0 / 0 | 0 / 0 / 0 |
| Hackatime | Minitest | 794 | 0 | 0 / 0 / 0 | 0 / #1133 / #1133 |
| Campfire | Minitest | 634 | 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| Writebook | Minitest | 310 | 1 E (`URI::Generic#request_uri`, Rails main) | 0 / 0 / 0 | 0 / 0 / 0 |
| CodeTriage | Minitest | 219 | 0 | 0 / 0 / 0 | 0 / 0 / 0 |

headline2 with `58b019f6fe` reverted:

| App | zjit differ | zjit1 differ |
| --- | --- | --- |
| Discourse | 0 | (0 on headline2 itself) |
| Sure | 1, the race test (below) | 1, the same test |
| Mastodon | 0 | (0 on headline2 itself) |
| Loomio | 0 | 0 |
| CASA | 0 | 0 |
| Hackatime | 0 | 0 |
| Fizzy, Campfire, Writebook, CodeTriage | 0 | (0 on headline2 itself) |

Its interpreter baseline has the same counts and failures as master's in every app.

## Time per step

All times UTC on 2026-11-25, on a 16-core, 31 GB orb.

| Step | From | To | Took |
| --- | --- | --- | ---: |
| Read the method docs, clone both Ruby trees | 19:27 | 19:30 | 3 min |
| Build master and headline2 (in parallel) | 19:30 | 19:33 | 3 min |
| Start PostgreSQL, Redis, memcached, MariaDB | 19:33 | 19:36 | 3 min |
| App copies and bundles (two restarts: incomplete bundler, CodeTriage's C gems) | 19:36 | 19:57 | 21 min |
| Script, smoke run (4 apps, 2 modes) | 19:45 | 19:59 | 14 min |
| First full attempt, stopped: Discourse's `SLAVEOF` on the shared Redis, Discourse's `activejob` | 19:59 | 20:13 | 14 min |
| Full runs, master and headline2 at once (7 runs each) | 20:16 | 21:26 | master 54 min, headline2 70 min |
| #1133: minimize, while the suites ran | 20:27 | 20:33 | 6 min |
| #1133: bisect, candidate and parent (two miniruby builds, with the suites still running) | 20:33 | 20:36 | 3 min |
| #1133: full `git bisect run` over the 104 commits (7 miniruby builds; one suite still running) | 22:01 | 22:05 | 4 min |
| #1133: branches and upstream trackers | 20:36 | 20:45 | 9 min |
| OpenProject attempt (bundle on master) | 20:44 | 20:52 | 8 min |
| Build headline2 − `58b019f6fe` | 20:38 | 20:42 | 4 min |
| Runs on headline2 − `58b019f6fe` (3 at a time, then 10 after master finished) | 20:43 | 21:51 | 68 min |
| Reruns alone: master (2 tests) | 21:19 | 21:35 | 16 min (Sure's race test hit the 5 min timeout) |
| Reruns alone: headline2 (5 sampled per whole-suite failure; CASA and Mastodon redone after a script fix) | 21:27 | 21:41 | 14 min |
| Fix check: build `2dc14101c3`, CASA spec file, CASA, Mastodon and Discourse in zjit1 and zjit | 21:41 | 22:34 | 53 min |
| Weekly mode in the script, smoke run (`weekly`, 2 apps, both builds) | 22:28 | 22:44 | 16 min |
| Record, commit | 22:44 | 22:50 | 6 min |

Both bisects ran while suites were running. The repro is standalone and single-threaded, so the load changes only how
long each step takes, not its result.

## Outcome files

Kept in Git, per build: [`bench/upstream/ruby-differential/runs/`](../../bench/upstream/ruby-differential/runs).

* `LABEL/APP/MODE.json.gz` holds every test's result, exception class and first message line, plus the Ruby
  description, flags, exit status, seconds and JIT state.
* `runs.txt` lists every run, `summary.json` the per-run counts, `diffs.json` the differences (the first 100 of each
  run), and `reruns.json` the alone-rerun outcomes.

Raw logs and RSpec JSON stay in the orb under `~/rdiff/logs` and are not archived.

## Reproduce, and the weekly rerun

[`script/ruby-differential`](../../script/ruby-differential). The weekly run is one command, on an a1.xxlarge orb
(16 cores, 31 GB) with this repository at `main`:

```sh
script/ruby-differential services          # fresh orb only: PostgreSQL, Redis, memcached as orb services
script/ruby-differential weekly --jobs 14
```

`weekly` builds two release Rubies at once (in `~/rdiff/rubies/NAME`): the tip of ruby/ruby `master`, and the tip of
k0kubun's newest `zjit-headline*` branch (latest tip commit, then highest number). On an orb without the app copies
(`.corpus/censusrd-APP`, not in Git) it first runs `setup` with the master build: copies, edits, template databases.
It bundles every app for each build,
runs all 10 apps in `interp`, `yjit`, `zjit1` and `zjit` on both builds at once (7 jobs each), and compares each run
with the same build's interpreter run. Then it subtracts the differences that the previous run of the same app and
mode in the same series already had, and the known app flakes in
[`known.json`](../../bench/upstream/ruby-differential/known.json). Master labels form one series and `zjit-headline*`
labels the other, so headline3 is compared with headline2's run, and #1133 counts as known until it is gone. It reruns
only what is left, alone, and writes `report.md` per label. It exits 1 when either build has a new difference, and 0
otherwise. `--commit SHA [--repo URL] [--name NAME]` runs one Ruby instead; `--modes` and `--apps` narrow the round.

Results go to `bench/upstream/ruby-differential/runs/DATE-master-SHA10/` and `runs/DATE-zjit-headlineN-SHA10/`.
Each holds `report.md` (new differences with their alone-reruns, differences gone since the previous run, and
per-run counts and seconds), the outcome files below, and `diffs-all.json.gz`, which the next run compares against.
Commit the two label directories after each run; logs stay in `~/rdiff/logs`.

Runtime per weekly run on a1.xxlarge, from this round: builds 4 min (both at once), bundles about 10–15 min, suites
55–70 min (Discourse about 50 min and Sure about 15 min per run set the length), reruns 0–20 min. That is about
1.5 h when nothing hangs. A hung suite is killed after `RDIFF_TIMEOUT` (7200 s), so the worst case is about 3.5 h.
A fresh orb adds `services` (about 3 min) and `setup` (about 1 h). In this orb the fresh-orb steps ran one at a time,
not as part of one `weekly` call. A smoke run of `weekly --apps campfire,writebook --jobs 14` on master `f46d41a54c` and
zjit-headline3 `e0fc4df7ca` took 6 min 23 s, found no new divergence, and was not kept.

Single steps, as used in this round:

```sh
script/ruby-differential build   --commit SHA [--repo URL] [--name NAME]
script/ruby-differential run     --ruby DIR --label L --apps discourse,sure --modes zjit,zinl=--zjit+--zjit-inline-threshold=500
script/ruby-differential compare --label L [--base-label B]
script/ruby-differential rerun   --ruby DIR --label L [--apps LIST] [--reps 3]
```

`run` resumes a label: runs that already have an outcome file are skipped unless `--force`. Two invocations on
different builds can run at once, because databases are named by label, app and mode, and Redis ports are claimed
with lock files. A run with more than 50 differences is a whole-suite failure, and `rerun` reruns 5 of its tests that
passed in the baseline (seeded sample). A single-test rerun times out after 300 s (`RDIFF_RERUN_TIMEOUT`).

Bisect of a standalone repro, as done for #1133. Configure a worktree once, then:

```sh
git bisect start BAD GOOD
BUILD=$PWD/build BAD=TypeError git bisect run LOWRAIL/bench/upstream/ruby-differential/bisect-test.sh \
  LOWRAIL/bench/upstream/ruby-differential/repros/zsuper_kw_fwd.rb --zjit --zjit-call-threshold=2
```

Each step makes miniruby and runs the repro, about 20–50 s per step on this orb.
