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
