---
id: E2b
repo: rails/rails
kind: fix
area: Active Record SQLite schema readers
reviewer: "ngan (author of 2cb3daba96, #58498), byroot (merged it)"
branch: thomasklemm/sqlite-schema-readers-temp-shadowing
head: "29079a50ff7b808d170d3425e36a3ee4b953be6a"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on:
alternative_of:
impact: "a temporary SQLite table or view hides the permanent one again: columns and indexes no longer duplicated, primary key no longer composite"
rank: 5
risky: false
state: merged
pr: 59668
note: "2026-11-26 (ractor CI fix, Opus thread T-01a217e5-02b4-7112-bbc7-e72629ed5dff): Buildkite 137206 on 440a2c09b8 failed activerecord sqlite3:ractor (4.0): the class-body gate called database_version on the ractor proxy, whose ProxyConnectionPool has no server_version, so the suite aborted while loading the file (main 137197 passes that job; the rubocop and actioncable reds are not ours). Amended to 29079a50ff: the test is always defined and skips below 3.40 by asking the standalone @conn its DDL runs on; the why-comment became the skip message. Message byte-identical, author date, parent and no trailers kept, signed. thermos-sol approved; lease-pushed over 440a2c09b8; body unchanged, no comments. Buildkite rails 137218 pending at push. Details under Ractor gate fix below. 2026-11-26 (Opus thread T-01a21498-95c1-733c-9e7a-bc9ddb899e31, Thomas chose E2 option b): #59668 continues alone and is not closed. Its commit is bc90b487f2 amended with E2's fixture split: the temp-index shadowing subcase is its own test, defined on SQLite >= 3.40 (thermos-sol corrected the first proposal's 3.38; 3.38.0 and 3.39.4 still refuse that index); author date 1793806867, parent 1e235cee11, message unchanged, no trailers. thermos-sol approved 440a2c09b8 and the 128-word body. Lease-pushed over bc90b487f2 and the body was PATCHed (stacked #59671 claim, the #59671 reference and the bare SHA removed); no comments posted. Details under Pushed below. 2026-11-25 (Thomas): folded into E2; #59671 carries this commit (rebuilt as 7eb404b4ca on main 7c0f820c1a) and its body takes this body's facts; #59668 is to be closed, its state here changes with sync. opened as draft 2026-11-05; reviewed on bc90b487f2 (skeptic, Sol, Astra; Buildkite 136242 green); ready when a slot frees; E2 stacked on it, E2c on E2; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: the 8-1-stable/main/PR table, the temp-index and trigger sentences and the shared index-name case (fixed in E2c); in docs/upstream/ecosystem-tests.md"
passes:
  - {reviewer: sol, head: "472c680d15", date: 2026-11-05, verdict: nits, open: applied}
  - {reviewer: sol, head: "472c680d15", date: 2026-11-05, verdict: approve, open: "20:07, no must-fix; body nit applied before opening"}
  - {reviewer: skeptic, head: "472c680d15", date: 2026-11-05, verdict: changes, open: "must-fix: sqlite_temp_master first makes index_details read a same-named temp index CREATE, so the permanent index loses where: (main keeps it); fix: keep sqlite_master first. Follow-up: pragma_index_info still resolves temp first (columns doubled, from 2cb3daba96). Nit: check constraints etc. also come from the temp CREATE, not only collation"}
  - {reviewer: skeptic, head: "3029db3847", date: 2026-11-05, verdict: nits, open: "no must-fix; comment overstated the sort order (ties unordered with PRAGMA threads > 0, main equally exposed), reworded in 52c21b2fa4; check constraints, auto-increment and generated columns from the temp CREATE confirmed and named in the body"}
  - {reviewer: skeptic, head: "52c21b2fa4", date: 2026-11-05, verdict: approve, open: "confirm pass: comment-only delta accurate; posted body checked (temp index sentence, check constraints, auto-increment, generated columns)"}
  - {reviewer: sol, head: "52c21b2fa4", date: 2026-11-05, verdict: changes, open: "partial-index where assertion depends on sort tie order; comment claims a guarantee; check constraints sentence untested"}
  - {reviewer: astra, head: "52c21b2fa4", date: 2026-11-05, verdict: changes, open: "type != 'table' mutant passes (permanent views not hidden); fixed in bc90b487f2"}
  - {reviewer: skeptic, head: "bc90b487f2", date: 2026-11-05, verdict: approve, open: "no tie-order assertion left; type != 'table' mutant and permanent-wins mutant fail; posted body checked"}
  - {reviewer: sol, head: "bc90b487f2", date: 2026-11-05, verdict: approve, open: "round 4, scope stated"}
  - {reviewer: astra, head: "bc90b487f2", date: 2026-11-05, verdict: approve, open: "all four table/view shadowing combinations; no order-dependent assertions"}
  - {reviewer: claude-code, head: "bc90b487f2", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: approve, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Added clause backed by ecosystem-tests.md E2/E2b."}
  - reviewer: thermos-sol
    orb: T-01a217a0-2010-72ff-9075-f7a00123c718
    head: "3b5912d71d9fb0962ae11055cea1b8574118fc16"
    date: 2026-11-26
    verdict: changes
    open: >-
      Both Thermos rubrics applied personally, without delegates or other
      threads. P2: the new >= 3.38.0 test gate still admits unsupported DDL;
      real SQLite 3.38.0 and 3.39.4 error before the new test's first assertion.
      The boundary is 3.40.0: change the gate to >= "3.40.0" and its why-comment
      to "since 3.40." Exact replacement and executed controls below. Branch
      and clean merge with Rails main 5a161379f5 pass the adapter directory
      on 3.37.0 (233/614) and 3.54.1 (234/617), zero failures/errors/skips,
      but those endpoints miss this defect. No other code or structural
      finding. The proposed 128-word body is approved sentence by sentence;
      commit wording, author/date and parent are preserved, no trailers;
      raw message differs only by one extra trailing blank line. Published
      PR/head/body fields are unchanged; no upstream changes made.
  - reviewer: thermos-sol
    orb: T-01a217a0-2010-72ff-9075-f7a00123c718
    head: "440a2c09b8351f5c1be96ee87157bac84eefcd85"
    date: 2026-11-26
    verdict: approve
    open: >-
      Both Thermos rubrics applied personally to the corrected-gate delta,
      without delegates or other threads. Only the two requested test lines
      change: the why-comment says since 3.40 and the gate is >= "3.40.0".
      The prior P2 is resolved. Independently reran the adapter directory
      on branch and merge with Rails main 5a161379f5: 3.37.0 and 3.39.4
      233/614, 3.40.0 and 3.54.1 234/617, all 0F 0E 0S. SQLite 3.38.0
      schema-reader subset 4/11, also clean. Commit message byte-identical
      to bc90b487f2, original author/date/parent preserved, no trailers.
      Corrected one-line why-comment meets the comment rule; unchanged
      128-word proposed body remains approved. No remaining findings.
  - reviewer: thermos-sol
    orb: T-01a217f1-50ae-711e-b8b4-5ff21d0fdeef
    head: "29079a50ff7b808d170d3425e36a3ee4b953be6a"
    date: 2026-11-26
    verdict: approve
    open: >-
      Delta confirm of the ractor gate fix, both rubrics personally, no
      delegates. Smallest fix: asks the standalone @conn used by the DDL,
      after setup, not the ractor proxy during class definition; the in-test
      skip matches PostgreSQL enum_test.rb:135 and partitions_test.rb:18; the
      class-body supports_expression_index? gate works only because the proxy
      dispatches it remotely. Skip message supplies the 3.40 reason, so the
      dropped comment is right; DDL, assertions, cleanup and trigger/table
      coverage unchanged. Reran: 440a2c09b8 under sqlite3_ractor aborts at
      line 960 with the Buildkite NoMethodError, candidate passes; adapter
      directory 3.39.4 plain 234/614 1S, ractor 172/416 1S; 3.40.0 plain
      234/617 0S, ractor 172/419 0S; all 0F 0E. Message byte-identical,
      author/date/parent kept, no trailers, signature valid with Thomas's
      GitHub signing key. RuboCop clean. No findings.
---

# Let a temporary SQLite table or view hide a permanent one in the schema readers

The batched SQLite schema readers from 2cb3daba96 join each pragma to a list of `sqlite_master` and `sqlite_temp_master` rows. While fixing their table-name case lookup (#59671), I found that when a temporary table has the same name as a permanent one, both rows match, and the pragmas resolve both to the temporary table, as SQLite does. So columns and indexes are duplicated, and the primary key becomes composite.

The list now takes a permanent table or view only when no temporary table or view has its name, which is how SQLite resolves identically spelled names. Collations and check constraints now come from the temporary table's CREATE statement too; 8-1-stable read the columns from the temporary table but the statement of the permanent one.

Shared index names remain a separate issue. #59671 (table names in any ASCII case) is stacked on this one.

## For Thomas

### Thermos-sol delta confirm, 2026-11-26

**Verdict: changes, one P2 must-fix**, on candidate
[`3b5912d71d9fb0962ae11055cea1b8574118fc16`](https://github.com/thomasklemm/rails/commit/3b5912d71d9fb0962ae11055cea1b8574118fc16),
orb `T-01a217a0-2010-72ff-9075-f7a00123c718`. Both correctness/security and maintainability rubrics applied
here, without subagents or other threads. This is not approval of a corrected head. The published branch,
head and body above remain as fetched; the ASCII-case half is outside this confirm.

**Scope and identity.** `git diff bc90b487f2 3b5912d71d`: only the test file, 18 insertions / 2 deletions;
no runtime change. Both raw commits have parent `1e235cee11`, Thomas author/committer, author date
`1793806867 +0000`, no trailers. Message wording is identical; the candidate adds one trailing blank line
(not byte-identical, not a substantive finding). `merge-tree --write-tree 5a161379f5 3b5912d71d` is clean,
tree `e7f068789735ece96cd4139ce17339b1428a8d1a`.

**Must-fix, test lines 959–965:** the 3.38 cutoff and its comment are false. The exact fixture fails on
SQLite 3.38.0 and even 3.39.4 with `there is already a table named shadowed`, before any assertion in the
new test. It first succeeds on 3.40.0. Replace the two lines with:

```ruby
      # SQLite allows a temporary index to share a permanent table's name since 3.40.
      if ActiveRecord::Base.lease_connection.database_version >= "3.40.0"
```

The DDL alone reproduces the boundary:

```sql
CREATE TABLE shadowed (id INTEGER PRIMARY KEY, number INTEGER);
CREATE TEMP TABLE index_shadowed_on_number (other INTEGER);
CREATE INDEX temp.shadowed ON index_shadowed_on_number (other);
```

Read the 3.38.0, 3.39.0, 3.39.4 and 3.40.0 sources: `sqlite3CreateIndex` checks
`sqlite3FindTable(db, zName, 0)` before 3.40 and `sqlite3FindTable(db, zName, pDb->zDbSName)` in 3.40.
That schema-qualified collision check explains the executed boundary; the
[3.40 release notes](https://www.sqlite.org/releaselog/3_40_0.html) provide supporting context.

**Executed checks.** Ruby 4.0.9, system-linked sqlite3 gem 2.5.0; built official SQLite amalgamations,
printed `SELECT sqlite_version()` per process. From `activerecord`, component libraries on `RUBYLIB`,
`ARCONN=sqlite3 PARALLEL_WORKERS=1 MT_CPU=1`:
`ruby -Itest -e 'Dir["test/cases/adapters/sqlite3/**/*_test.rb"].sort.each { |f| require_relative f }' -- --seed 41231`.

| SQLite | Candidate adapter directory | Merge with 5a161379f5 |
| --- | --- | --- |
| 3.37.0 | 233 runs / 614 assertions, 0F 0E 0S | Same |
| 3.39.4 | 234 / 614, 0F 1E 0S (new temp-index test) | Not run |
| 3.40.0 | 234 / 617, 0F 0E 0S | Not run |
| 3.54.1 | 234 / 617, 0F 0E 0S | Same |

On 3.38.0 the schema-reader subset is 5/11, 0F 1E 0S. On 3.37.0 old head is 4/8, 0F 1E 0S;
candidate is 4/11, 0F 0E 0S: trigger/table assertions remain active. With only the gate changed to 3.40
in memory (no Rails edit), the directory passes on 3.37.0 and 3.39.4 (233/614), and 3.40.0 and 3.54.1
(234/617), all 0F 0E 0S. Initial missing FTS5/math flags and CLI/library mismatch were fixed before the
complete reruns. Rails RuboCop: 1 file, no offenses; `diff --check` passes. No full Active Record,
other-database, Ruby-floor or hosted-CI run claimed.

**Maintainability/comment.** Cold read: keep trigger/table coverage everywhere; define the index test
where its fixture is legal. This follows the neighboring expression-index gate; no one-use helper is
needed, and cleanup remains correct. The file was already over 1,000 lines (1,705 → 1,721).
Flog: old 24.13 → trigger/table 22.83, index 22.93; ABC 15.13 → 14.14 / 13.15; cyclomatic/perceived 3
per test. Repeated setup buys independent coverage. The one-line why-comment prevents a misleading gate
removal and is not public API documentation; keep it with the corrected version. No structural blocker.

**Commit message, every sentence approved.** Title: unchanged resolution fix. First sentence: old CTE
lists both catalogs. Second: base probes duplicate columns/indexes and return `["temp_id", "temp_id"]`.
Third: predicate and all four table/view pairings agree. Fourth: nonhiding index/trigger probes agree;
it describes table/view hiding, not the separate shared-index-name defect. No wording change.

**Proposed replacement body, all six sentences approved.** The reviewed text is the coordinator's exact
128-word, three-paragraph proposal, not the still-live body above:

1. “The batched SQLite schema readers from #58498…”: opened that PR and verified `2cb3daba96` in its
   merged ancestry; its code joins pragmas to both catalogs. PR reference replaces the bare SHA.
2. “While fixing their table-name case lookup…”: discovery recorded in `docs/upstream/ecosystem-tests.md`;
   base probes reproduce the duplicate-row/temporary-resolution mechanism. No dependency claim remains.
3. “So columns and indexes are duplicated…”: asymmetric base fixture demonstrates all three effects.
4. “The list now takes a permanent table or view…”: predicate and all four pairings agree;
   “identically spelled” correctly excludes the held ASCII-case fix.
5. “Collations and check constraints…”: quoted `"temp_name" COLLATE "NOCASE"` plus distinct checks returns
   NOCASE/`temp_check` on old head, candidate and merged tree; base and 8-1-stable `e697e1766e` return
   nil/`permanent_check` with temporary columns. Stable's CREATE lookup is main-first.
6. “Shared index names remain a separate issue.”: permanent partial `shared_index(number)` beside temporary
   `shared_index(label)` still reports `["label", "label"]` for the permanent index on base and candidate.

Drop the stacked sentence as proposed; #59671 stays held. After the independent audit, fetched live metadata
and discussion: #59668 open/ready at `bc90b487f2`, no reviews or comments. Runner, probes, native builds,
metrics and logs: `.amp/in/orb-backup/e2b/`. Only this Lowrail record changed; upstream untouched.

### Thermos-sol corrected-gate confirm, 2026-11-26

**Verdict: approve**, on
[`440a2c09b8351f5c1be96ee87157bac84eefcd85`](https://github.com/thomasklemm/rails/commit/440a2c09b8351f5c1be96ee87157bac84eefcd85),
same orb, both rubrics applied personally. Compared the complete tree diff against `3b5912d71d` and
verified it equals the exact two-line replacement above: comment `since 3.40.`, gate `>= "3.40.0"`.
No other tree change. The test now excludes the illegal fixture below 3.40 without dropping trigger/table
coverage, and includes it at 3.40. The comment gives the otherwise non-obvious reason for the cutoff;
no correctness/security or maintainability finding remains. The unchanged 128-word proposed body retains
its sentence-by-sentence approval; the published fields/body above remain untouched.

Raw commits confirm author date `1793806867 +0000`, parent `1e235cee11`, Thomas author/committer and no
trailers. The message is now byte-identical to `bc90b487f2`, including its final newline. Clean
`merge-tree` with `5a161379f5`: tree `d51cbd65df02374d8af4253ae672c5e07689e944`.

Reran the same adapter-directory command and native-library setup as above, seed 41231, on the actual
new head and its merge, not an in-memory correction:

| SQLite | Branch | Merge with 5a161379f5 |
| --- | --- | --- |
| 3.37.0 | 233 runs / 614 assertions, 0F 0E 0S | Same |
| 3.39.4 | 233 / 614, 0F 0E 0S | Same |
| 3.40.0 | 234 / 617, 0F 0E 0S | Same |
| 3.54.1 | 234 / 617, 0F 0E 0S | Same |

Also reran the schema-reader subset on 3.38.0: 4/11, 0F 0E 0S. Rails RuboCop: 1 file, no offenses;
`git diff --check` passes. Logs: `.amp/in/orb-backup/e2b/confirm*-*.log`. No Rails source, branch or PR
changes; only this Lowrail pass and confirm section added.

### Pushed, 2026-11-26

Opus thread `T-01a21498-95c1-733c-9e7a-bc9ddb899e31`. After thermos-sol's approval of `440a2c09b8` (pass above), the branch
`thomasklemm/sqlite-schema-readers-temp-shadowing` was lease-pushed from `bc90b487f2` to
`440a2c09b8351f5c1be96ee87157bac84eefcd85`, and the body was PATCHed through the REST API to the approved 128-word text below (the GitHub
API returns it byte for byte). No comments were posted; #59668 stays open and ready. The review copy
`thomasklemm/sqlite-schema-readers-temp-shadowing-2` points to the same commit. The builder's checks on the branch and on its
clean merge with Rails main `5a161379f5` (seed 41231): SQLite 3.37.0 and 3.39.4 give 233 runs/614 assertions; 3.40.0 and 3.54.1 give
234/617; all 0F 0E 0S. `bc90b487f2` had 1 error on 3.37.0. `script/min-versions --only sqlite` on `3b5912d71d` (same code, gate at 3.38,
against base `1e235cee11`): on SQLite 3.35.5 the readers test passes 6/6 for base and head, and Rails' helper crashes on both on
`pragma_table_list`; on 3.44.2 base gives 110 runs and head 115, with no new failures. Buildkite on the new head has not been checked
yet (the Amp GitHub app cannot subscribe to rails/rails).

### Ractor gate fix, 2026-11-26

Opus thread `T-01a217e5-02b4-7112-bbc7-e72629ed5dff`. Buildkite rails 137206 on `440a2c09b8` failed the activerecord
`sqlite3:ractor` (4.0) job; main's 137197 passes it (that build's rubocop guides Lint/Syntax and actioncable reds are not
ours). Buildkite runs `rake sqlite3:test:ractor` in activerecord (rails/buildkite-config `pipelines/rails-ci/pipeline.rb`),
which sets `ARCONN=sqlite3_ractor`. The class body's `ActiveRecord::Base.lease_connection.database_version >= "3.40.0"`
reaches `abstract_adapter.rb:1041` `pool.server_version(self)` on the ractor proxy, whose `ProxyConnectionPool` has no
`server_version`, so loading the file raised NoMethodError and aborted the whole suite. The neighbouring class-body gate
`supports_expression_index?` survives only because `SQLite3ProxyAdapter` dispatches it remotely.

Fix, amended with `script/commit --amend` to
[`29079a50ff7b808d170d3425e36a3ee4b953be6a`](https://github.com/thomasklemm/rails/commit/29079a50ff7b808d170d3425e36a3ee4b953be6a):
the test is always defined and starts with
`skip "SQLite allows a temporary index to share a permanent table's name since 3.40" unless @conn.database_version >= "3.40.0"`.
`@conn` is this class's standalone `SQLite3Adapter.new(database: ":memory:")` (a NullPool, which has `server_version`), the
connection the test's DDL runs on, so the check is exact under both handlers. The in-test skip follows PostgreSQL's
`enum_test.rb:135` and `partitions_test.rb:18`. The skip message replaces the why-comment; DDL, assertions and cleanup are
unchanged (13 insertions, 14 deletions, test file only). Parent `1e235cee11`, author date `1793806867 +0000`, raw message
byte-identical to `440a2c09b8`, no trailers, SSH-signed. Rails RuboCop 1.90.0: 1 file, no offenses; `git diff --check` clean.

Reproduction (Ruby 4.0.9, Rails bundle, sqlite3 gem 2.5.0 with its SQLite 3.47.2, seed 41231, `CI=1 BUILDKITE=true`, from activerecord):

| Run | `440a2c09b8` | `29079a50ff` |
| --- | --- | --- |
| `ARCONN=sqlite3_ractor ruby -w -Itest test/cases/adapters/sqlite3/sqlite3_adapter_test.rb` | aborts at load: `sqlite3_adapter_test.rb:960`, NoMethodError `server_version` for ProxyConnectionPool | 107 runs / 257 assertions, 0F 0E 0S |
| same with `ARCONN=sqlite3` | 115 / 283, 0F 0E 0S | 115 / 283, 0F 0E 0S |
| `rake sqlite3:test:ractor` (the Buildkite task) | aborts at load, same error and line | 9,559 runs / 34,291 assertions, 0F 0E 24S |

The first fixed rake run had 5 environmental errors (no `pg` gem in the trimmed bundle, no `sqlite3` CLI); both installed,
the rerun above is clean.

`script/min-versions --only sqlite --sqlite 3.37.0,3.39.4,3.40.0,3.54.1`, base `1e235cee11` versus head `29079a50ff`,
the 15 files of `activerecord/test/cases/adapters/sqlite3/`, plain `sqlite3` handler:

| SQLite | Base | Head | New failures in head |
| --- | --- | --- | --- |
| 3.35.5 (floor) | crashed: Rails' helper uses `pragma_table_list` | same crash | none |
| 3.37.0 | 229 / 603, 0F 0E 0S | 234 / 614, 0F 0E 1S (temp-index test) | none |
| 3.39.4 | 229 / 603, 0F 0E 0S | 234 / 614, 0F 0E 1S (temp-index test) | none |
| 3.40.0 | 229 / 603, 0F 0E 0S | 234 / 617, 0F 0E 0S | none |
| 3.44.2 (middle) | 229 / 603, 0F 0E 0S | 234 / 617, 0F 0E 0S | none |
| 3.54.1, min-versions build | 229 / 593, 4E | 234 / 607, 4E | none (4 `no such module: fts5` on both) |
| 3.54.1 with FTS5 and math functions | 229 / 603, 0F 0E 0S | 234 / 617, 0F 0E 0S | none |

min-versions' SQLite 3.54.1 recipe builds without FTS5, so `SQLite3VirtualTableTest` errors on base and head alike; the
last row reruns the directory on an official 3.54.1 build with `-DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_MATH_FUNCTIONS`
(library and CLI both 3.54.1, `ENABLE_FTS5` checked). Below 3.40 the head runs five more tests than base and skips one:
the trigger/table test still runs. Scripts and logs: `.amp/in/orb-backup/e2b-ractor/` in this thread's orb.

thermos-sol (orb `T-01a217f1-50ae-711e-b8b4-5ff21d0fdeef`) approved `29079a50ff` with no findings (pass above), including
the ractor handler on 3.39.4 (172 / 416, 1S) and 3.40.0 (172 / 419, 0S). The branch was then lease-pushed from
`440a2c09b8` to `29079a50ff`; the PR head on GitHub is `29079a50ff`, the body is unchanged and no comments were posted.
Buildkite rails [137218](https://buildkite.com/rails/rails/builds/137218) and docs-preview 26427 were pending at push; the
Amp GitHub app still cannot subscribe to rails/rails, so the watcher has to check them.

Posted body:

The batched SQLite schema readers from #58498 join each pragma to a list of `sqlite_master` and `sqlite_temp_master` rows. While fixing their table-name case lookup, I found that when a temporary table has the same name as a permanent one, both rows match, and the pragmas resolve both to the temporary table, as SQLite does. So columns and indexes are duplicated, and the primary key becomes composite.

The list now takes a permanent table or view only when no temporary table or view has its name, which is how SQLite resolves identically spelled names. Collations and check constraints now come from the temporary table's CREATE statement too; 8-1-stable read the columns from the temporary table but the statement of the permanent one.

Shared index names remain a separate issue.
