# lowrail-profile 0.1.0.rc1: Astra M5 review

**Verdict: changes required; do not publish this candidate.** Four must-fixes below. This pass applies both
Thermos rubrics directly, without delegation or reading the parallel review. It changes no profiler code.

Reviewed `2c845e81..fd36835b` and `ab657532..24a6d0b1`, restricted to profile changes and the profiler code the
package ships. Checkout and built source: `24a6d0b1`. Decisions: [release plan](../profile-release-plan.md) and
[DECISIONS](../DECISIONS.md), “lowrail-profile 0.1”, 2026-11-25. Existing
[M4 receipts](../../bench/upstream/profile_release/2026-11-25/README.md) are supporting evidence, not a substitute
for this pass's new app. No publication, tag, issue, PR, or external comment was made.

## Must-fixes

### A1 — High: a failed or signalled suite becomes a successful CLI invocation

**Location:** `gem/exe/lowrail-profile:174–177,187–194,217–218`; promised by `gem/README-profile.md`, guarantee 5.
The child statuses are recorded but never used to exit the successful reporting path. A failure to construct a
report instead hard-codes exit 1, also losing a child's distinct nonzero status. A signal becomes `nil` through
`Process::Status#exitstatus`.

**Reproduced from the installed gem:** eight passing integration tests became seven passes and one deliberately
failed assertion. Both captured runs printed `8 runs, 17 assertions, 1 failures, 0 errors, 0 skips`;
`capture.json` recorded `"exit":[1,1]`; the CLI exited **0**. A separate command made two real engine requests and
then `exit 7`: metadata `[7,7]`, CLI **0**. The same command killed itself with SIGTERM: metadata `[null,null]`,
CLI **0**. Comparing the failed capture correctly exits 2, but that does not repair the top-level command.

**Smallest fix:** normalize and retain each `Process::Status` (including a defined signal convention such as
128 + signal), select a nonzero child status if any run failed, and return it after reporting, including reporting
error paths. Define which failure wins if the two runs differ; do not let a later successful run hide an earlier
failure. Keep an explicit failure for a profiler error when the children succeeded. Add CLI tests for ordinary
failure, signal, and failed-command/no-report. Merely changing the README would abandon an accepted guarantee.

**Attribution:** pre-existing implementation, newly shipped under the explicit release guarantee. The release
tests exercise child failure as compare metadata, not the CLI's own status.

### A2 — High: the new production guard ignores writable secondary databases

**Location:** `gem/lib/lowrail/profile_workloads.rb:29–40`, especially `configs_for(env_name: Rails.env)` at line 31.
Rails defaults `include_hidden` to false: replicas and configurations with `database_tasks: false` are omitted.
The latter are not read-only databases; the option excludes Rails database-management tasks, not app writes.

**Reproduced with Rails 8.1.4's actual configuration objects**, not a mocked `configs_for`: after booting the new
app, set `Rails.env = "production"` and `ActiveRecord::Base.configurations` to:

```ruby
{
  "production" => {
    "primary" => { "adapter" => "sqlite3", "database" => ":memory:" },
    "analytics" => {
      "adapter" => "postgresql", "host" => "db.example.invalid",
      "database" => "analytics", "database_tasks" => false
    }
  }
}
```

Then load the installed `profile_workloads.rb` with a workloads file whose first line is
`abort "POLICY_BYPASSED: workloads evaluated despite remote production database"`. Without `--allow-writes`, the
sentinel executed. `configs_for(env_name: "production", include_hidden: true)` independently returned hosts
`[nil, "db.example.invalid"]`. No database connection or request was sent by this safety probe.

**Smallest fix:** use `include_hidden: true` on the already-loaded branch and add a production test containing a
local primary plus a remote `database_tasks: false` secondary. Include a replica control. Preserve the no-autoload
branch and test it too: it is a separate raw-config/URL interpretation, not equivalent by construction. A guard
error must not silently turn into “no remote database”. Do not load Active Record solely to inspect its config.

**Attribution:** introduced by this release's new guard. This is also the principal maintainability finding: two
different configuration representations feed a safety decision without tests of either production path.

### A3 — Medium: a gem path containing a space prevents the app from starting

**Location:** `gem/exe/lowrail-profile:172`, interpolation of `"-I#{lib}"` into `RUBYOPT`.

**Reproduced:** install the built gem with `gem install --local --install-dir "$REVIEW/space home"`, then execute
that installation's CLI with `-- ruby -e 'puts "APP_RAN"'`. Both children fail before evaluating the command:

```text
lowrail-profile: run 1 of 2: ruby -e puts "APP_RAN"
ruby: invalid switch in RUBYOPT: -h (RuntimeError)
lowrail-profile: run 2 of 2: ruby -e puts "APP_RAN"
ruby: invalid switch in RUBYOPT: -h (RuntimeError)
```

The ordinary Ruby command prints `APP_RAN`. This affects common Bundler vendor paths beneath a project directory
with spaces, not just unusual command arguments; command arguments themselves are correctly passed as an array.

**Smallest fix:** carry the library directory in `RUBYLIB`, preserving its prior entries with
`File::PATH_SEPARATOR`, and leave only the require switch in `RUBYOPT`. Do not rely on shell quoting inside
`RUBYOPT`. Extend the installed-package test to run an actual capture from an installation directory with spaces;
`--help` and `--version` do not exercise the broken child-launch path.

**Attribution:** pre-existing launch code, exposed by the new standalone-gem installation contract.

### A4 — Medium: compare accepts an impossible empty measurement as valid evidence

**Location:** `gem/lib/lowrail/profile_compare.rb:116–135` (`report_problems`).

**Reproduced:** take the new app's valid two-run thread-parallel report; replace `ranked` and `actions` with `[]`,
leaving its eight completed request windows per run and other metadata intact. Pass that report as base, head and
A/A. Result: **exit 0**, `gate: true`, `compared: ["request"]`, `problems: []`, `regressions: []`. Nothing was
compared. A report produced by this counter cannot have completed requests without corresponding action rows
(even unnamed actions have a row). This is a malformed-evidence check, not a claim that report JSON is tamper-proof.

**Smallest fix:** require action coverage for every kind with completed windows; at minimum reject an empty
action collection for a nonempty kind. Prefer validating each action's window-count vector and its per-run sum
against `summary.completed`, which also detects partial row loss. Do not reject an empty ranked-line collection
alone: an action can allocate entirely in app code, which is intentionally absent from that collection. Add a
CLI regression test starting from a real generated report, rather than a fixture whose action counts and summary
are already inconsistent.

**Attribution:** pre-existing compare validator shipped by the release. Existing unit fixtures commonly claim
ten completed requests while providing no actions, which is why this inconsistency passes today's tests.

## Executed checks and their boundaries

All local execution used Linux x86_64, Ruby 4.0.7, Rails 8.1.4. Scratch app, gem installations, mutation copy,
scripts, native builds and raw logs are retained in `.amp/in/orb-backup/astra-profile/` in the review thread's
workspace. They are not changes to the release source. No runtime support beyond these exercised cases is claimed.

| Check | Actual result |
| --- | --- |
| Build and local installation | From `gem/`: `gem build lowrail-profile.gemspec --output "$REVIEW/lowrail-profile-0.1.0.rc1.gem"`, then `gem install --local --no-document`. SHA-256 `df543df744cc56ade168778c66e847266ebfad40903f377f3673729e800eba58`. Empty review-specific `XDG_CACHE_HOME`; the installed CLI compiled its counter. No checkout `RUBYLIB`. |
| Fresh non-corpus app | Generated with Rails 8.1.4 `rails new … --minimal --skip-bundle --skip-git`; installed gem in Gemfile with `require: false`. Mounted isolated `Outsider::Engine`, inline Active Job, SQLite, Bootsnap 1.26.2, Minitest 5.27.0, RSpec 3.13. |
| Process-parallel integration suite | `parallelize(workers: 2, with: :processes, threshold: 0)`: 8 tests / 16 assertions / zero failures or errors plain and in both profiled runs. Reports contain exactly 8 completed outer request windows in 2 processes per run, named `Outsider::ProbeController#index`; engine nesting and inline jobs do not double-count. |
| Thread-parallel integration suite | Same eight tests with `with: :threads`: all pass plain and in both profiled runs; exactly 8 completed requests in 1 process per run. |
| RSpec | Four real engine request examples pass plain and in both profile runs. Reports contain 4 requests per run. |
| Load order | In a separate Minitest capture, every one of the six target-process feature sequences (two parents and four forked workers) exactly matches a plain process after excluding profiler files. Baseline uses `bundle exec env bin/rails test`, matching the process boundary. The profiling CLI's own 203-file process is not an app process and is excluded. |
| App files | SHA-256 lists of every file in `app/`, `config/`, `lib/`, `test/`, `spec/` are byte-identical before and after another installed-gem capture. Logs, SQLite state and the declared output directory are intentionally not in this source-tree comparison. |
| Cable, exceptions, other profilers, Sidekiq | New-app probe passes plain and in both profile runs: real channel subscription and 3 `ping` actions; raised Active Job exception preserves object identity; `memory_profiler` 1.1.0 surrounds 3 engine requests and still reports allocations; forced GC compaction succeeds; Sidekiq 8.1.7 testing-inline worker produces the same result. Direct Sidekiq workers are not separately counted by the Active Job hook. |
| Native stress | Rebuilt the shipped C source with clang 19.1.7 and `-fsanitize=undefined -fno-sanitize-recover=all`. A separate C NEWOBJ observer is enabled before Lowrail. Four Ruby threads, 100 total parent windows, compaction inside windows, fork with 3 child windows and reset verification, and another Ractor allocating 10,000 strings: `NATIVE_OK windows=100 child=3 other_newobj=true`, exit 0, no UBSan diagnostic. |
| Existing focused suite | `profile_test.rb profile_package_test.rb workloads_test.rb load_hooks_test.rb --seed=1729`: **25 runs, 290 assertions, 0 failures, 0 errors, 0 skips**. |
| Killed mutation | In a disposable copy, change `ProfileCompare#regressions` to `[]`. `test_compare_gates_on_the_floor_of_an_a_a_pair` fails: expected exit 1, actual 0; 1 run, 2 assertions, 1 failure. Production source was never mutated. |
| Surviving safety mutation | In that copy, disable the entire production host guard with `if false && Rails.env.production?`. `test_workloads_refuse_writes_without_allow_writes` still passes: **1 run, 33 assertions**. This test checks declaration refusals in test mode, not production host protection. |
| Spring 4.7.0 | Start a supervised Spring server, warm the app unprofiled, then `lowrail-profile -- … spring rails test`: both suites pass, but no windows are recorded and the CLI exits 1. Source inspection confirms the existing server forks without processing the new `RUBYOPT`; changing its environment cannot retroactively load the profiler. Service stopped after the probe. |
| macOS | Not rerun on a Mac. Read the committed Campfire receipt (634 tests, 3858 assertions, zero failures/errors, one skip, identical outcomes) and independently queried Actions run 45622936395: `campfire` job and run both `success`, proof-repository head `b509370449ecdcd4005d6ef6c02885743b33cf75`. Local clang/UBSan execution is additional Linux evidence, not macOS certification. |

Initial fresh-app setup errors were fixed before the successful controls: process workers needed a schema dump,
and the in-app engine needed its own route-file path rather than sharing the application's route file. These
errors occurred without Lowrail too and are not profiler findings. Spring required its documented opt-out of the
reloading requirement for this generated test environment; even after the plain Spring run passed, profiling a
warm server recorded nothing.

### Compare edge outcomes

The installed CLI was called directly on JSON variants of the new app's real report, not just on the comparison
class. Same report supplied as A/A is a deterministic validator control, not a claim about independent-run noise.

| Input | Exit | Assessment |
| --- | ---: | --- |
| Empty `{}` reports | 2 | Correct refusal. |
| Different metadata seed | 2 | Correct refusal. |
| Identical valid reports | 0 | Correct. |
| One line grows by 0.5 objects, below default minimum 1 | 0 | Correct; a below-floor regression is intentionally not a gate failure. |
| One line grows by 1,000,000 | 1 | Correct. |
| Failed suite's actual capture | 2 | Correct, despite A1 at the profiling CLI boundary. |
| Rename the only action and add 1,000,000 to its warm app-only cost | 0 | Intentional current behavior: both names listed in `not_compared`, no shared external-line increase. Not evidence that the renamed action is regression-free. Document this exclusion prominently. |
| Empty measurement collections with positive completed summary | 0 | Incorrect; A4. |

## Maintainability and remaining release limits

* **No size-driven rewrite is needed.** The shipped C counter is 650 lines, Ruby reporter 600, shared workload DSL
  483, hook runtime 376, compare 286, CLI 218. None crosses 1,000 lines. Extracting `loaded_constant` lets the
  profiler avoid loading the lowering runtime without duplicating its no-autoload contract; that is appropriate.
* **Keep fixes at their owners.** Child exit policy belongs in the CLI, production policy in the workload runner,
  report coherence in `report_problems`. Do not solve A1 by changing compare or scatter special cases among the
  framework hooks. The new anonymous workload-policy prepend is bounded to the replay process; a large policy
  framework would not improve this release. A2 needs full configuration enumeration and tests, not more host-name
  exceptions. These are the actionable structural findings, rather than speculative broad refactoring.
* **The native ownership model survived the exercised stress.** Open windows pin their thread/fiber; copied
  source-path bytes are owned by C; the unmarked VALUE cache only accepts a current string after checking its
  contents; fork resets counters in the child. No concrete memory-safety defect was found. UBSan is not ASan,
  race detection, or proof under allocation failure. macOS/arm64 and Ruby 3.3/3.4 were not locally executed.
* **No observed lazy-load or exception regression.** `loaded_constant` avoids autoload, and the tested hooks let
  app exceptions escape unchanged. The six exact feature-sequence comparisons support only this app and run;
  they do not certify every engine or custom `on_load` callback.
* **Spring needs a documented boundary or bypass.** Recommend `DISABLE_SPRING=1` with ordinary Spring binstubs
  during capture, with a regression test, rather than making profiler hooks migrate into a running preloader.
  The observed failure is explicit, not false-green evidence. Do not claim Spring support from fork tests alone.
* **GoodJob inline is not runtime-certified here.** GoodJob 4.24.1 was installed and its inline adapter's
  transaction/lock/perform path inspected, but no PostgreSQL-backed GoodJob execution was run. Active Job inline
  and direct Sidekiq testing-inline passing are not substitutes. Ractor checks cover independent allocation and
  the documented main-Ractor boundary, not a Rails app running inside a non-main Ractor.
* **Subprocess inheritance is intentional but needs care.** The child environment carries profiler variables and
  `RUBYOPT` to descendants so system-test servers can be observed. This pass did not establish a secret disclosure.
  The CLI only adds enabled optional flags, rather than clearing stale internal flags such as
  `LOWRAIL_PROFILE_ALLOW_WRITES`; explicitly set true/nil values at the launch boundary when fixing it. The source
  tree check does not mean arbitrary app commands, replayed GETs, jobs or mail have no external side effects.
* **Minor packaging/docs points:** the documented build command must run from `gem/`; executing `gem build
  gem/lowrail-profile.gemspec` from repository root fails file validation. clang reports `_GNU_SOURCE` macro
  redefinition (Ruby's headers define it as 1); no build failure. Installed-gem profiler wrapper lines also appear
  as `gem: lowrail-profile` in ranked JSON despite the `NOT_RANKED` entry for `lowrail-profile`; observed warm values
  were zero, so this is not a measured false regression.

M5 needs fixes for A1–A4, regression coverage at the actual CLI/installed-package boundaries, and confirmation on
the resulting candidate. The current green suite and corpus receipts do not satisfy those missing guarantees.

## Confirm pass on the fixes (thermos-fable, 2026-11-25)

**Verdict: confirmed. A1–A4 are fixed and the README additions are accurate; no must-fix remains from this
list.** Four non-blocking notes and the A/A recommendation follow. Both Thermos rubrics were applied directly,
without delegation and without reading the parallel confirm. No profiler code was changed, nothing was published,
tagged or posted.

Reviewed `c2e5c393..14579fb4`, profile changes only, at Lowrail `b6109a84` (`gem/` and the CI workflow are identical
to `14579fb4` there and at `a613a580`). Gem built from `gem/` at that head: sha256
`324affa67569770b578d73d96fab7aef6ca53e4126ecefc838d227b331236f2d`, the same bytes as the fixes receipts. Everything
below ran on Linux x86_64 on both ends of the support range, Ruby 4.0.7 / Rails 8.1.4.1 and Ruby 3.3.14 / Rails
7.2.4, with the same results unless a row says otherwise. Scripts and logs are in this review thread's workspace
(`.amp/in/orb-backup/fable-profile/`), not in the repository.

### Fix by fix

| Fix | Verdict | What was run |
| --- | --- | --- |
| A1 exit status (`b60a29e2`) | Fixed | Astra's three repros from the installed gem: failing suite 1 (plain 1), `exit 7` → 7, `TERM` → 143. Also `KILL` → 137, first run fails → 3, only the second fails → 4, both fail differently → the first's, no report after `exit 5` → 5, no report after `KILL` → 137, missing command → 127, report cannot be written after `exit 7` → 7, `--record` cannot write after `exit 7` → 7. A passing command exits 1 when no report can be built or `--record` cannot write, and 0 otherwise. `capture.json` records the same numbers. |
| A2 production database (`85c4fedc`) | Fixed | Astra's repro as a real `RAILS_ENV=production` run of the fresh app with a sentinel workloads file: local primary plus a remote `database_tasks: false` secondary is refused before the file runs, by `host:` and by `url:`; the same secondary as `replica: true`, a loopback host and a local-only config are not; `--allow-writes` passes; a stale `LOWRAIL_PROFILE_ALLOW_WRITES=1` in the caller's environment does not. No connection was made. |
| A3 paths with spaces (`e3a53f20`) | Fixed | Astra's repro from `gem install --install-dir ".../space home"`: both runs start with the profiler loaded, no `invalid switch`. Then the fresh app's whole process-parallel suite from an app directory, a path gem, a cache and an `--out` that all contain spaces, with a caller `RUBYLIB` that has one too: identical outcomes (11 tests), the counter built in the spaced cache. |
| A4 inconsistent report (`b6276362`) | Fixed | Astra's repro on the fresh app's real thread-parallel report (requests, jobs, mails, Cable actions) exits 2. So do: actions emptied alone, one action row lost, one window miscounted in one run, job or Cable actions emptied, a mail row lost, and a missing, short or non-integer `windows`. Still 0: an untouched copy, ranked lines emptied alone, windows moved between two actions with sums kept. Every valid report passes: 63 real reports (the M4 and fixes receipts of Blog, Campfire with 8 processes, CodeTriage, Lobsters under RSpec, two `--workloads` captures, and 38 of the fresh app in process, thread and RSpec runs). The reporter derives `completed` from the same action rows, so it cannot write a report this check refuses. |
| README: renamed actions, Spring (`7b45ced2`) | Accurate | Renaming an action in head and adding 1,000,000 objects to it exits 0 with both names under *Not compared* (ran in base only / ran in head only); raising a ranked line by 500 in the same report exits 1. Spring 4.7.0: a warm server passes the suite twice, counts nothing and exits 1 with *no runs with requests*; `DISABLE_SPRING=1` counts 7 requests and exits 0. The exit-status sentences match the A1 rows. |

**Each fix's test fails without the fix.** With the commit reverted and the tests kept at head:
`test_a_failed_command_fails_the_profile` (expected 7, got 0), `test_workloads_refuse_a_remote_production_database`,
`test_built_gem_runs_without_the_checkout` (the counter does not build) and
`test_workloads_captures_compare_by_what_they_measured` (exit 0 for the hollow report) each fail, on both Rubies.
Nine single-part mutants fail too: the signal convention, first-failure-wins, the status after a missing report,
`include_hidden`, the replica skip, the unloadable-config refusal, loading `ActiveRecord::Base` for the check,
`-I` back in `RUBYOPT`, and building the counter in place. One survives (note 2). At head the CI command passes
locally: 29 runs, 0 failures, 0 skips on both; CI on `b6109a84` is 14 of 14.

**Fresh app.** `rails new` on each Rails, the built gem installed and listed with `require: false`, an isolated
engine mounted at `/outsider`, inline Active Job, a mailer, a channel, Minitest with two workers and RSpec. Per-test
outcomes are identical plain and in both profiled runs for process workers (12 tests, 1 skip), thread workers
(the same 12) and RSpec (5 examples, 1 pending). Reports count 7 requests, 5 jobs, 6 mail windows and 4 Cable
actions per run in 2 processes (process workers) or 1 (threads), and 4 requests under RSpec; engine requests are
named `Outsider::ProbeController#…`, and jobs enqueued inside a request are not counted again. One suite
adjustment was needed that has nothing to do with the profiler: Rails 7.2's transactional tests fail under thread
workers in a plain run, so the thread runs turn them off and isolate by tag.

### Non-blocking notes

1. **Low: a child Ruby started with its own `RUBYLIB` no longer boots when the gem is not on its gem path**
   (`gem/exe/lowrail-profile`, the `RUBYOPT` line). The child inherits `-rlowrail/profile` but not the directory:
   `cannot load such file -- lowrail/profile`. Before `e3a53f20` the `-I` travelled in `RUBYOPT` and the child ran.
   Reproduced only from the checkout's exe with the gem not installed; with the gem installed or in the bundle the
   child finds it through RubyGems or Bundler and runs. Smallest fix, run: keep
   `("-I#{lib}" unless lib.match?(/\s/))` in `RUBYOPT` beside `RUBYLIB`; the child runs again and the spaced-path
   package test still passes.
2. **Low: A4's test proves only the empty case.** A mutant that refuses only an empty action list for a kind with
   completed windows passes the whole suite, though head also refuses a lost row and a miscount (run above).
   Smallest fix: one more assertion in the same test, on the report with one action row removed.
3. **Low, before and after the fix: a gem home with a glob character** (`[`, `{`, `*`, `?`) cannot build the
   counter, because `Dir["#{source}/*"]` treats the path as a pattern. Smallest fix, run:
   `Dir.children(source).map { File.join(source, _1) }` in both places.
4. **Boundaries of the A2 runs.** `bin/rails runner` always loads `ActiveRecord::Base` (the railtie's `runner`
   block), so in a stock app the guard takes the loaded branch; the raw-configuration branch and its *did not load*
   refusal are reached only by the gem's test, with its own runner. In the fresh app an unloadable `database.yml`,
   or a `DATABASE_URL` for an adapter the bundle lacks, stops the app at boot, before the guard and before the
   file. Nothing is sent either way. A remote `DATABASE_URL` with its adapter installed was not run here.

Maintainability: no structural objection. Each fix sits with its owner as the first pass asked (exit policy in the
CLI, production policy in the workloads runner, report coherence in `report_problems`), and no file crosses 1,000
lines. `gem/test/profile_test.rb` is at 981: move the compare tests to their own file (and add it to the CI
command) with the next test rather than after it. Two receipts of the fixes run (`w/post-allow`, both Blogs) are
reports compare refuses, by the existing unfinished-window check (21 job windows, 20 completed) and not by A4's.

### Recommendation: the A/A pair

**Do not default to more than one A/A pair. For 0.1, make a line's floor twice its measured spread, as an
action's already is, and have the documented CI job profile head again when compare exits 1.**

* A second pair buys little and costs two more suite runs on every pull request. Over the Blog's six unchanged
  same-seed captures (every choice of base, A/A and head), the shipped gate fails 6 of 120 unchanged comparisons,
  always on `uri/common.rb:394`; with two pairs 12 of 360, with three 12 of 720. With one pair and twice the
  spread, 0 of 120. In the comparisons against the planted captures the unrelated row appears in 19 of 60 as
  shipped, 50 of 240 with two pairs, 78 of 720 with three, 6 of 60 with one pair at twice the spread.
* Twice the spread costs no sensitivity that the receipts can show: the plant is found in every comparison on all
  four apps (60 of 60 on the Blog, 6 of 6 on Campfire, CodeTriage and Lobsters), because at most 2 lines per app
  in those receipts have a spread above `--min` at all. With independent run-to-run noise on one line and no
  change, a simulation of the rule fails 3.4% of comparisons as shipped, 1.3% with two pairs, 0.6% with three, and
  0.34% with one pair at twice the spread.
* It does not cover a capture whose runs agree with each other and differ from the base: the receipt's own
  comparison would still flag `uri/common.rb:394` (+3.88 against 2.0, the planted capture read 21.25 and 21.75),
  and in the fresh app's process-parallel suite on Ruby 4.0 one capture in eight read other values on several
  lines in both of its runs (probably another split of its seven requests over the two workers; not traced),
  which fails 42 of 336 unchanged comparisons even at three times the spread and 210 of 1,680 with two pairs.
  Only a second head capture separates that from a regression: requiring the row in both drops it to 30 of 1,680
  there and 0 of 360 on the Blog. A regression is in both; a shifted capture is in one.
* Concretely: `Change#threshold` uses `[2 * noise, min].max` for a line (the A/A floor test needs new numbers); the
  README's job reruns `lowrail-profile` on head when compare exits 1 and fails only if the second compare exits 1
  too, and its *When the gate fails on unchanged code* paragraph says so instead of *rerun the base pair*.
  Repeating `--aa`, or a `--confirm HEAD2.json` that requires the same row in both, can follow 0.1.

`uri/common.rb:394` is the `gsub!` of `URI._encode_uri_component`, which allocates per escaped character; why its
input differs between unchanged runs was not traced.
