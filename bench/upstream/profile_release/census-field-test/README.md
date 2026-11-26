# lowrail-profile 0.1.0.rc1: census field test (2026-11-25)

The README's flow, run on every census app that has a runnable suite, with the gem installed the way a stranger
would install it: `gem install --local` and one Gemfile line, with no checkout path.

**Result:** the tool never changed a test outcome, the load order or the app tree, and every documented exit code
held. The false alarms (Hackatime, Writebook, Sure), Sure's disk and memory use, and the hang without a timeout
blocked rc1, and all of them are resolved on main:

* compare ships as a report, not a gate, and refuses multi-process captures;
* T7 deletes the runs after the report, and the report streams them;
* T8 adds `--timeout`, and its exit status and report header are fixed at `6835d966`.

What remains is documentation and wording (ranked below).

## Apps × checks

The captures used gem rc1 from `aa4422c8`, sha256 `f569d5f5…a86d31`. It matched the three reviews.

Columns:
* Outcomes: per test, against the plain run.
* Load order: against the off-env baseline.
* Tree: whether the app tree was unchanged, over 7 captures (unchanged, planted handled by revert, and seed99).
* Exits: compare's 0/1/2 as documented.
* Plant: compare exits 1 with a plant row; "one" means one compare, "CI" means the README CI job with a second
  head capture.
* FA: the false-alarm rate of the combined gate over 6 unchanged captures, for one compare (120 assignments) and
  for the CI job (360).
* Overhead: a capture's wall time over the plain wall time, measured while other apps' suites ran (inflated).

| App | Ruby / Rails | Suite | Outcomes | Load order | Tree | Exits | Plant one / CI | FA one compare | FA CI job | Overhead |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: |
| Blog (generated) | 4.0.9 / 8.1.4 | `bin/rails test`, 21 | = | = | 7/7 | ok | 60/60, 60/60 | 0% | 0% | 1.4× |
| Blog floor | 3.3.14 / 7.2.4 | 21 | = | = | 7/7 | ok | 60/60, 60/60 | 0.83% (1, `uri/common.rb:394`) | 0% | 1.4× |
| Campfire, 16 workers | 4.0.7 / 8.2.0.alpha | 634 | = except the u2 flake (a 1 s deadline) | = | 7/7 | ok; u2 makes compare exit 2 | 40/40, 40/40 (without u2) | 0/60 (without u2) | 0/120 | 5.5× |
| CodeTriage | 4.0.7 / 8.1.4 | 222 | = | = (yard's `Module#constants` walk) | 7/7 | ok | 60/60, 60/60 | 0% | 0% | 2.6× |
| Lobsters | 4.0.9 / 8.1.3.1 | RSpec, 927 | = | = | 7/7 | ok | 60/60, 60/60 | 0% | 0% | 2.2× |
| Redprints CFP | 3.4.3 / 8.1.3 | RSpec without system specs, 50 | = | same set; bundlebun's integration order differs | 7/7 | ok | 60/60, 60/60 | 0% | 0% | 2.3× |
| React starter kit | 4.0.1 / 8.1.4 | RSpec without system specs, 35 | = | = | 7/7 | ok | 60/60, 60/60 (`UsersController#new`) | 0% | 0% | 3.8× |
| Fizzy, controllers only | 4.0.7 / 8.1.4 | `test/controllers`, 50, one process | = | = | 7/7 | ok | **0/60** (under the floor: +32 on 196k objects) | 0% | 0% | 2.3× |
| Fizzy, full, 16 workers | 4.0.7 / 8.1.4 | 124, with 7 errors in every run, plain included | = | = (parallel check) | 8/8 | always 2 (the suite fails) | – | – | – | 2.7× |
| CASA | 4.0.7 / 8.1.4 | `spec/requests`, 935 | = once record IDs are masked | = | 7/7 | ok | 60/60, 60/60 (with the action in the regex) | **20.0%** | **6.67%** | 3.3× |
| Hackatime, 2 workers | 4.0.6 / 8.1.3.1 | 794 | = | = (parallel check) | 7/7 | ok | **0/60** | **52.5%** | **34.4%** | 3.0× |
| Hackatime, 1 worker | same | same | – | – | 6/6 | ok | 31/60, 30/60 | **12.5%** | **4.44%** | – |
| Writebook, 16 workers | 4.0.7 / 8.1.4 | 119 | = | = (parallel check) | 7/7 | ok | 0/60 (no warm value) | **26.7%** | **11.7%** | 2.7× |
| Writebook, 4 workers | same | same | = | = | 7/7 | ok | 0/60 (no warm value) | 2.5% | 0.56% | 1.7× |
| Writebook, 1 worker | same | same | – | – | 6/6 | ok | 60/60, 60/60 (`SessionsController#create`) | 0% | 0% | – |
| Sure, 16 workers | 3.4.9 / 8.1.3.1 | `test/controllers`, 3,851 | = except a flake in u1 and u6 | = without yard | 7/7 | ok; the flake makes compare exit 2 | **0/24** (u2–u5) | **79%** (19/24, u2–u5) | **58%** (14/24) | 9.4× |
| Mastodon | 4.0.9 / 8.1.4 | `spec/requests` and `spec/controllers`, 2,296 | = plain2 (plain had 2 flake failures) | = | 7/7 | ok | 0/60 (a weak site, below) | 0.83% | 0% | 2.0× |
| Loomio | 4.0.9 / 8.1.3.1 | `test/controllers`, 1,491 | = | = | 7/7 | ok | 0/60 (not counted: controller test) | 0% | 0% | 2.2× |
| OpenProject (partial) | 4.0.9 / 8.1.4 | `spec/controllers`, 2,450 | same results, 0 failures; documentation lines reorder | = | 1/1 | 2 (one capture) | not run | – | – | 1.9× |
| Discourse | 4.0.7 / main of 2026-11-02 | `spec/requests`, 3,892 | plain run only | – | – | – | – | – | – | – |
| PingCRM | – | system tests only | not run | | | | | | | |

`--seed 99` reports exited 2 against seed 1234 on all 18 sets, as documented. `report DIR` again exited 0 on all
of them. Without `--aa`, compare exited 0, or 2 when the suite failed. Load order "=" for parallel suites means
`scripts/features_parallel.rb` found the parent's order identical and the union of all processes identical, except
for first-run files (`single_byte.so`, migration files) that show up only in the first plain run.

### Not run, or partly run

* **Discourse:** its libvips ≥ 8.18 worker starts with `unsetenv_others`, so `LD_LIBRARY_PATH` doesn't reach it. In
  the test environment `GlobalSetting` uses a blank provider, so `DISCOURSE_*` doesn't skip the check. Registering
  `/opt/vips818` with ldconfig and running `pnpm install` made it boot. One plain `spec/requests` run took 29:54,
  with 12 failures (`evidence/discourse-spec-requests-plain-tail.txt`). Eight captures would take more than 8 hours,
  so it wasn't profiled.
* **OpenProject:** `spec/requests` had 11 failures in a plain run (LDAP and roles), and `spec/controllers` with
  `spec/requests` took 20 minutes. Only `spec/controllers` was captured: plain, off and u1. Those are functional
  tests, so the report counts 0 requests and 93 jobs; there was no A/A pair and no plant.
* **PingCRM:** only Selenium system tests, and there's no browser driver in the orb.
* **Rails main:** not run on any app; there wasn't time.
* **Serial overhead remeasure:** not done. The overhead column was measured while up to 6 apps ran in parallel.

## Problems, ranked

### Release-blocking at rc1, resolved on main

1. **The compare gate false-alarms on parallel suites and misses plants there.** Hackatime with 2 workers: 52.5%
   for one compare, 34.4% for the CI job, plant 0/60. Writebook with 16 workers: 26.7% and 11.7%. Sure u2–u5: 79%
   and 58%, plant 0/24. Job and action values come out bimodal depending on how the tests are split across
   workers. Resolved: 0.1 ships compare as a report, and since `abf515d3` compare refuses multi-process captures.
   The captures are also committed under `../2026-11-25-t3/census/`.
2. **Sure's disk and memory use.** rc1 wrote 3.3 GB of runs per capture, and the report took about 6 minutes and
   7.1 GB RSS; the CI job's 4 captures would fill a GitHub runner. At c68 (T7): 825 MB while the runs exist, 12 MB
   after the report, but the report still took 6.16 GB. At `5cdc5669`, the streaming report on the same runs took
   **742 MB and 2:36**, against 6.16 GB and 5:30. report.json and report.md were byte for byte identical. A fresh
   capture's lowrail-profile process peaked at 731 MB, in 315 s (`c68/sure-size*`).
3. **No timeout: a hung worker hangs CI.** Fizzy u6 hung for more than 7 minutes in an autoload deadlock between
   active_job and turbo's ThreadDebouncer, with no lowrail frame on any stack (`evidence/`). It is the app's own
   hang: 3 of 20 plain runs without the profiler hung too (`c68/fizzy-plain`). T8's `--timeout` at c68:
   * It stopped every hang cleanly, with no process left behind, over 12 plain repeats and 3 SIGSTOP hangs.
   * When run 2 timed out after a failing run 1, lowrail-profile exited 1, not 124.
   * The report header said "2 runs" and didn't mention the stopped run.

   **At `6835d966` both are fixed** (`c6835/`): 3 of 3 hangs exited 124 with `exit [1,124]`, and the report opens
   with "**Incomplete: run 2 timed out after 20.0 s (--timeout) and was stopped …**". 6 normal repeats exited 1
   with `[1,1]`.

### Not blocking: document, or decide

4. **One-process suites can false-alarm too.** Hackatime with 1 worker: 12.5% and 4.4%
   (`Admin::AdminUsersController#index`, 0.7% data noise). CASA: 20% and 6.7% (`ChecklistItemsController#new` and
   `#edit`, `uri/common.rb:456`). The record IDs in their redirect URLs change from run to run. This is moot while
   compare is a report, but it is the evidence for any future gate.
5. **Controller tests count no requests, and the report doesn't say so.**
   * Loomio's `test/controllers` is 95 of 104 files `ActionController::TestCase`, so 1,491 tests yield 68 requests,
     and the plant in `SearchController#index` is never seen.
   * OpenProject's `spec/controllers` yields 0 requests.
   * README line 248 documents this, but the report header gives only the counts. A line such as "N tests ran, 0
     requests counted: controller tests are not counted" would save users a confused hour.
6. **A plant in an action with no warm value is never compared:** Writebook's `BooksController#index` (once per
   process), the starter kit's `DashboardController#index`, and 128 of Mastodon's 471 actions. The only hint is
   "Not compared: N actions (no warm value)".
7. **Weak plant sites are invisible.** Fizzy's `BubblesController#show` adds +32 to 196k objects. On Mastodon's
   `Api::V1::AccountsController#show`, the plant line has 0.04 warm objects per request: it runs in about 2 warm
   requests, and I didn't look into why. These are expected under a floor, so they're not tool bugs.
8. **A flaky suite makes compare exit 2** (Campfire u2, Sure u1 and u6), and Fizzy's suite fails in every run, so
   compare always exits 2. This is documented, but in a real CI job one flake voids the whole comparison.
9. **The `--workloads` example doesn't run on the floor Blog as written.** The README's
   `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1` fails with "No database file specified": the generated
   production `database.yml` has no SQLite path. It works with `RAILS_ENV=development`.
   * The write guard works: without `--allow-writes`, uncommented POSTs give exit 1 with "POST /articles is a
     write; --workloads sends real requests, so it needs --allow-writes".
   * With the flag: exit 0, 120 requests and 40 jobs; the development database grew to 63 articles and 63
     comments, and I restored it afterwards.
   * `--record` writes `lowrail/workloads.rb` into the app tree, as documented: 4 GETs enabled, writes and
     `Comment.first!` commented out (`c68/blog-floor-wl/`).
10. **The overhead is high on allocation-heavy parallel suites:** a capture takes 9.4× the plain wall time on Sure
    and 5.5× on Campfire under load. Run 2 alone was +173% on Campfire. A serial remeasure is still pending.

### Harness mistakes and workarounds (mine, not the tool's)

* **CodeTriage:** the first set planted every capture because a plant was left behind (`apps/codetriage-all-planted`).
  I redid it.
* **Gem home corruption** came from a `bundle install` while suites ran on the same Ruby; never do that.
* **`pkill -f`** matches the calling shell itself; use exact PIDs.
* **App setup:**
  * stringio 3.1.2 needs `-Wno-error=incompatible-pointer-types` on GCC 14.
  * Lobsters needs `config/database.yml` copied from its sample.
  * Mastodon needs Node 24.
  * Loomio needs its Vue build and `MISE_TRUSTED_CONFIG_PATHS`.
  * Sure needs `tailwindcss:build`.
  * Discourse is covered above.
* **Floor Blog's `tailwind.css`** was changed by my `assets:precompile` for `--workloads`, not by lowrail-profile.

## Gem builds checked

| Commit | sha256 | Expected |
| --- | --- | --- |
| `aa4422c8` (rc1) | `f569d5f5…a86d31` | matches |
| `c68afc98` (T7, T8) | `17b7f302…b960b295` | matches |
| `5cdc5669` (streaming report) | `e9ac10e6…dc0712eaaac5` | matches |
| `6835d966` (0.1.1 prep) | `25a417ed…a067dc90a8` | no reference given |

Each was built with `gem build` on Ruby 4.0.9 and 4.0.7, which gave identical results.

## Timings

The orb had 16 CPUs and 31 GB.

* **Parallel phase** (rc1, up to 6 apps at once): 19:43–22:40 UTC.
  * Blog 1 min; floor Blog 1.5 min; Redprints 2.5 min; CodeTriage 4.5 min; Writebook 6 min; Writebook with 4
    workers 6 min.
  * Campfire 8 min; Fizzy controllers 8.5 min; starter kit 9.5 min; Hackatime 16 min; Lobsters 22.5 min.
  * Fizzy 40 min, including the hang; CASA 40 min; Sure 90 min; Mastodon 97 min (a capture about 9 min); Loomio
    114 min (a capture about 10.5 min).
  * OpenProject's 3 steps took 23 min.
* **Serial follow-ups:**
  * Hackatime with 1 worker: 8 captures, 17.5 min (2:03–2:24 each).
  * Writebook with 1 worker: 8 captures, 8 min (1:07–1:19 each).
  * Fizzy `--timeout` at c68: 12 repeats in about 5 min, plus 4 hang runs in about 3.5 min.
  * Sure size at c68: 2 captures and a report, about 25 min.
  * Sure at `5cdc`: report 2.6 min, capture 5.3 min.
  * Fizzy at `6835`: 9 runs, about 5 min.
  * Discourse plain run: 30 min.

## Files

* `apps/APP/`:
  * `summary.txt` (wall time and exit per step, tree check), `outcomes.txt`, `features*.txt` (load order),
    `exits.txt`, `gate*.txt` (from `2026-11-25-final/scripts/gate.rb`; `gate-valid` leaves out the flaky captures,
    `gate-action` adds the action to the plant regex), `overhead.txt`.
  * `cijob-*.md`, `compare-*.md`, and the plant patch's `app/` hunk.
  * `reports.tar.xz`: every capture's `report.json`, `command.txt` and `capture.json`. The raw runs were deleted for
    disk space; Hackatime u1's are in `../2026-11-25-t3/census/hackatime/runs-u1.tar.xz`.
* `c68/`: the T7 and T8 checks (Sure size and RSS, Fizzy `--timeout`, hangs and plain repeats, `--record` and
  `--workloads`).
* `c6835/`: the Fizzy `--timeout` recheck at `6835d966`.
* `evidence/`: Fizzy's hang (gdb, Ruby backtraces), and the Discourse and OpenProject plain-run tails.
* `scripts/`: the harness. `ft.sh APP` drives M4's `proof.sh` and `controls.sh` from
  `../2026-11-25/scripts`, then `post.sh`, with the per-app settings in `scripts/apps/`. `collect.rb` prints the
  table rows, and `assemble.sh` copies the outputs here.
