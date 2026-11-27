# SQ37 Thermos review, 2026-11-27

**Verdict: changes, posted body only.** The exact adapter code, regression test, CHANGELOG and commit are acceptable. Name the earlier floor bump as unreleased in the posted body. No Rails changes or queue-item edits were made by this review.

Reviewed `3e348f32bdc2b5b405d31f226e6de04aa3278dc9`, exactly one commit on `088fc0cf61e4ba0c7987decafacc69adb3e22eec`, from `thomasklemm/rails` branch `thomasklemm/sqlite-floor-3-37`. The fork fetch resolved to that exact head. Lowrail started at `9cd83cdf23557a1cec88330792e7c5225ad143aa` on local `main`. Review thread: https://ampcode.com/threads/T-01a21cf5-7978-7316-a2c3-ae40718644b4.

The `thermos` skill ran two independent, read-only Task reviewers in parallel in this thread. Correctness/security loaded `thermo-nuclear-review`; maintainability loaded `thermo-nuclear-code-quality-review`. No other threads or nested reviewers were created. The main reviewer independently inspected the diff and context, checked external claims and recent merges, ran the tests and probes below, and synthesized the findings. Reviewer IDs and returned findings are in [reviewers.md](reviewers.md).

## One body clarification is required

In SQ37.md's posted second sentence, retain the existing `check_version` link and replace:

> accepts 3.35.0 since #58284, so

with:

> accepts 3.35.0 on main after #58284 (unreleased), so

DECISIONS permits citing unreleased upstream evidence when the text identifies it as unreleased. Otherwise the proximity to “Rails 8.0” leaves a reader to infer whether the 3.35.0 floor shipped in that release. This is not a runtime defect. The replacement is fact-checked and acceptable; it needs no Rails head change.

[release-status.txt](release-status.txt) records the latest release lookup (`v8.1.4.1`, 2026-11-04), its actual `check_version` floor of 3.23.0, and the negative ancestry check for the 3.35.0-floor merge. The body describes current main, whereas that earlier floor bump has not shipped in the latest release.

## Optional points, not opening blockers

* **Test the effect rather than the hook's incidental return.** In `activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb:181`, `assert_nil @conn.check_version` could be `assert_nothing_raised { @conn.check_version }`. Stronger, use `@conn.connect!` in both version-stub blocks, preserving the exact error assertion. The current test covers the right rejection and inclusive boundary and fails on base; it is not a blocker.
* **Narrow the CHANGELOG's older-version wording.** At `activerecord/CHANGELOG.md:4`, replace `On older versions` with `On SQLite 3.35 and 3.36,`. Base already refuses versions below 3.35.0 at connect, so only the newly refused range reaches the metadata error on base. This is a non-blocking precision improvement.

The generator template still advertises SQLite 3.8.0. That wording is identical on base and is already documented as deliberately omitted in the queue item; it is not an introduced finding and this review does not ask to expand the change. The raw commit messages differ only by one extra trailing blank line on the rebuilt head. Their prose is identical; no head rewrite is warranted for that whitespace ([rebuild-message-comparison.txt](rebuild-message-comparison.txt)).

## Implementation, commit and readability

Cold read: if the runtime SQLite version is below 3.37.0, raise the existing unsupported-version error with the corrected minimum; otherwise continue connection setup. This is **L0**, with one existing branch and no new helper, state, SQL, fallback or abstraction. The version comes from `SELECT sqlite_version(*)` and Rails' numeric `Version` comparison, not lexical String comparison. The existing superclass configuration boundary disconnects and re-raises on failure; the executed connection probe confirms cleanup.

No Ruby code comments were added. The existing `:nodoc:` marker is unchanged. There is no new user-object operation, conversion, accumulator, mutation or synchronization boundary. The changed literals are at the canonical version gate, not a wrapper. Newly refusing raw-SQL-only use on 3.35/3.36 is a deliberate adapter-wide floor change; those controls worked on base, and the record and “For Thomas” already acknowledge the loss.

[source-review.txt](source-review.txt) preserves the full three-file diff, exact commit message, Thomas Klemm `<github@tklemm.eu>` as both author and committer, and empty trailers. Parent/count and patch-identity checks are in [context-and-recent-main.txt](context-and-recent-main.txt). An SSH signature exists; this review does not claim to authenticate it. The new and previous code/test patches have identical stable patch ID `4deab6000ad2799a470e1ba3f9fa39e1d4c2bc4f`; the CHANGELOG entry's added text is identical. The intervening SQLite schema-reader change affects `MASTER_CTE`, not this version gate or `data_source_sql`.

Flog 4.10.0 scores the extracted production method **4.7 on both base and head**. RuboCop 1.93.0 `--only Metrics` reports `2 files inspected, no offenses detected` on the same method extractions. The first Flog invocation combined identically named methods and therefore aggregated them to 9.4; [final-probe-checks.txt](final-probe-checks.txt) records the corrected separate invocations. These are readability diagnostics, not performance evidence. The large adapter/test files predate this change; no decomposition is justified by this diff.

## Every posted sentence and factual claim was checked

The title and body were read only through the boundary before `## For Thomas`. The posted body remains two paragraphs, contains no internal process references, no performance claims, and no irrelevant project inventory.

* **Title, “Bump the minimum supported SQLite version to 3.37.0.”** The actual comparison and matching diagnostic change from 3.35.0 to 3.37.0: [source-review.txt](source-review.txt).
* **Sentence 1, “Since #52354 (Rails 8.0), data_source_sql reads pragma_table_list, which SQLite added in 3.37.0.”** `gh api repos/rails/rails/pulls/52354/files` shows the replacement of `sqlite_master` by `pragma_table_list`; the merge is an ancestor of `v8.0.0`, whose source contains that query. `curl -fsSL https://www.sqlite.org/releaselog/3_37_0.html` names the new table-list pragma and dates the release 2021-11-27. The table-list documentation states its first appearance is 3.37.0. See [claim-sources.txt](claim-sources.txt).
* **Sentence 2, the 3.35.0 floor and the failing operations.** The actual earlier floor-bump diff is captured by `gh api repos/rails/rails/pulls/58284/files`; it changes 3.23.0 to 3.35.0 for RETURNING. Both exact body permalink targets were retrieved at the pinned SHA with the GitHub contents API and numbered: `schema_statements.rb:218–227` is `data_source_sql`, and `sqlite3_adapter.rb:518–522` is the base `check_version` accepting 3.35.0 ([additional-source-checks.txt](additional-source-checks.txt)). Ordinary table lookup/listing, schema-cache lookup and migrations fail with the stated error on actual 3.35.5/3.36.0 in [min-versions.json](min-versions.json). `Model.create!`, `find` and primary-key loading were independently run in [probes.txt](probes.txt). Actual `ruby bin/rails db:prepare` fails with that error on base and 3.36.0 ([app-results.txt](app-results.txt)). The missing unreleased qualifier is the required fix above.
* **Sentence 3, rejection in check_version, the RETURNING precedent, and failure at connect.** The earlier floor-bump diff/CHANGELOG explicitly cite RETURNING. The exact-head diff and actual old-library runs show the new diagnostic; `connect!` probes verify exception class, exact message and disconnected state. `db:prepare` on head and 3.36.0 fails with that diagnostic, not the metadata error. See [claim-sources.txt](claim-sources.txt), [probes.txt](probes.txt) and [app-results.txt](app-results.txt).
* **Sentence 4, system-library builds and the bundled current SQLite.** RubyGems currently lists sqlite3 2.10.2. Its installation instructions distinguish native/precompiled gems and the source gem's packaged SQLite from opt-in `--enable-system-libraries`; `dependencies.yml` packages SQLite 3.54.1. Main has the same packaging instructions and SQLite pin. The SQLite release history identifies 3.54.1 as its newest release. Main Rails' minimum sqlite3 gem version is 2.1, whose packaged SQLite is also above 3.37. See [claim-sources.txt](claim-sources.txt), [metrics-and-final-main.txt](metrics-and-final-main.txt) and [packaging-floor.txt](packaging-floor.txt). This statement explains the ordinary supported installation paths, not custom drivers or private-hook overrides.

Both GitHub HTML permalinks were attempted directly. The schema-statements page returned 503 through the page reader twice; direct curl returned 503 for both pages. The adapter page reader succeeded. This did not prevent verification of either permalink's exact path, SHA or line fragment: both contents-API fetches succeeded and match `git show SHA:path`. The failed direct fetches remain in [permalink-fetches.txt](permalink-fetches.txt), rather than being presented as successful page reads.

The CHANGELOG and commit message were also checked sentence by sentence against the same sources and executed operations. Their historical query introduction, affected APIs, migration table creation, db:prepare and model-primary-key failure claims are supported. No substantive replacement is required there; the optional CHANGELOG range narrowing is above.

## Citations remain relevant and current

Today's DECISIONS rule was applied to every named project, including the sqlite3 gem even though its name is not a body link. These are necessary framework/database/driver dependencies, not a list of marginal downstream apps. Rails is the main subject and appears first; there is no list of callers to reorder or replace.

The saved API responses in [claim-sources.txt](claim-sources.txt) and the current SQLite release heading in [metrics-and-final-main.txt](metrics-and-final-main.txt) show:

| Project | GitHub stars | Last push | Latest release checked | RubyGems total downloads |
| --- | ---: | --- | --- | ---: |
| Rails | 59,174 | 2026-11-27 | 8.1.4.1, 2026-11-04 | 823,128,659 |
| SQLite | 11,155 (GitHub mirror) | 2026-11-27 | 3.54.1, 2026-10-16 (sqlite.org) | not a gem |
| sqlite3-ruby | 848 | 2026-11-25 | 2.10.2, 2026-10-26 | 203,666,215 |

None is archived or abandoned, and the gem is the current release, not an outdated citation. The modest star count for sqlite3-ruby does not make a default Rails database driver with this download reach niche. Historical Rails 8.0 and SQLite 3.37.0 references identify the introduction of a bug/feature, not recommendations to use superseded projects or dependencies.

## No recent merge supersedes this head

The canonical Rails main fetch still resolves to `088fc0cf61e4ba0c7987decafacc69adb3e22eec` at the final check. Git history since 2026-11-25, including all merge subjects and the complete diff for the SQLite adapter/schema-statements files, is saved in [context-and-recent-main.txt](context-and-recent-main.txt). The sole change there is temporary-table shadowing in `MASTER_CTE`; it leaves the floor and `pragma_table_list` requirement unchanged.

GitHub searches, with `incomplete_results: false`, also checked all 71 PRs merged since 2026-11-25 (including stable-branch backports), merged SQLite-related PRs, all PRs mentioning `pragma_table_list`, open PRs mentioning `check_version`, and PRs mentioning `3.37.0`. None covers this floor correction. Searches and returned titles/URLs are retained in [claim-sources.txt](claim-sources.txt). This is a point-in-time conclusion, not an opening authorization.

## Executed SQLite verification

All runtime comparisons used Ruby 4.0.9, revision `3e93b23afc`, and sqlite3 gem 2.10.2 compiled against each real SQLite library by `script/min-versions`; the script verifies `sqlite_version()` before each side. The exact run command and output are in [min-versions.log](min-versions.log); structured per-test diagnostics are in [min-versions.json](min-versions.json). The resolved dependency lock is [min-versions.Gemfile.lock](min-versions.Gemfile.lock).

| SQLite | Base | Head |
| --- | --- | --- |
| 3.35.5 / 3.36.0 | Adapter test helper cannot boot: `no such table: pragma_table_list`. Standalone: 15 tests, 12 errors; raw SQL, columns and create_table controls work. | Adapter helper cannot boot: the supported-minimum error. Standalone: all 15 tests stop at the version gate, including the three controls. |
| 3.37.0 | Adapter: 115 runs, 0 failures/errors, 1 skip. Standalone: 15 runs, 17 assertions, no failures/errors/skips. | Adapter: 116 runs, 0 failures/errors, 1 skip. Standalone: same 15 successful tests. |
| 3.44.2 | Adapter: 115 runs, 283 assertions, no failures/errors/skips. Standalone: 15 successful tests. | Adapter: 116 runs, 286 assertions, no failures/errors/skips. Standalone: same 15 successful tests. |

`script/min-versions` exits **2**, correctly recording the below-floor helper crashes. This is not an all-green matrix, and the three newly refused controls are not hidden as equivalent behavior.

* [boundary-regression.txt](boundary-regression.txt) runs the new head test unchanged with base libraries: `RuntimeError expected but nothing was raised` (one failure). With head libraries: `1 runs, 3 assertions, 0 failures, 0 errors, 0 skips`.
* [probes.txt](probes.txt) independently reruns the prior review's fresh-connection public-API probe on base/head and actual SQLite 3.35.5, 3.36.0 and 3.37.0. Raw SQL, column inspection and direct table creation work only on base below the new floor; metadata/model paths produce the reported errors. At 3.37.0 both produce the same useful results.
* The additional [boundary_probe.rb](boundary_probe.rb) checks ten version values, including both sides of each boundary, 3.36.99, 3.100.0 and 4.0.0, using real Rails Version objects, frozen Version objects, a Version subclass and a duck comparator. Each side passes 40 cases through `connect!`, checking exact RuntimeError text and cleanup on rejection. The expected boundaries are supplied independently as numeric tuples. Subclasses and duck values are extra probes, not claimed public inputs to this `:nodoc:` hook.
* [app-results.txt](app-results.txt) runs the kept minimal app fixture with real `ruby bin/rails db:prepare`: 3.36.0 fails with the missing pragma table on base and the supported-minimum error on head; 3.37.0 exits 0 on both. SQL inspection confirms `widgets`, `schema_migrations`, `ar_internal_metadata` and migration version `20261125000000` in both successful databases ([final-probe-checks.txt](final-probe-checks.txt)).

The eight exactness checklist categories were considered: the candidate has no method arguments, container iteration, implicit conversions, result adoption, user callbacks, fibers or new configuration read. Existing version-object dispatch and the failure exception contract were probed; frozen version values and standalone require order were exercised. Successful configurations at/above the new floor follow the same path. Overrides of private/nodoc internals and global core-method redefinitions are outside the contract, as DECISIONS permits. No claim is made of preserving the intentionally withdrawn lower-version support.

This reviewer did not rerun full Active Record, PostgreSQL, MySQL or alternate-Ruby suites; the production diff is SQLite-only. The builder's full-suite numbers remain the builder's evidence, not this review's executed results. No performance claim or A/A timing comparison is made.

## Replaying and delivery boundaries

The original source-check attempt stopped because the single-branch clone had no `v8.0.0` tag. [claim-sources-initial.txt](claim-sources-initial.txt) preserves that failure; [check-sources.sh](check-sources.sh) adds an explicit tag fetch and then completes. The initial SQLite changes-page truncation captured only its header and generated curl's expected broken-pipe error; [metrics-and-final-main.txt](metrics-and-final-main.txt) fetches the whole page and extracts the actual current-release heading instead.

The kept shell runners and boundary probe retain their executed scratch paths under `.amp/in/orb-backup/sq37-review`. `run-probes.sh` reuses the 2026-11-25 public-API probe; app fixtures are copied unchanged from that review, whose git history was inspected. To replay in a fresh orb, populate that scratch directory and cache with the same files/`script/min-versions` invocation first. No database binaries, generated app databases, gem installations or build trees are added to Lowrail.

Only this evidence directory is part of the review's Lowrail commit. SQ37.md, the Rails fork and upstream GitHub state are unchanged. The builder owns recording the pass and applying the body wording. This `changes` verdict does not authorize opening a PR or bypass the separate current-head Astra gate.
