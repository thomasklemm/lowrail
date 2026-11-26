---
id: E2b
repo: rails/rails
kind: fix
area: Active Record SQLite schema readers
reviewer: "ngan (author of 2cb3daba96, #58498), byroot (merged it)"
branch: thomasklemm/sqlite-schema-readers-temp-shadowing
head: "bc90b487f2"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on:
alternative_of:
impact: "a temporary SQLite table or view hides the permanent one again: columns and indexes no longer duplicated, primary key no longer composite"
rank: 5
risky: false
state: ready
pr: 59668
note: "2026-11-25 (Thomas): folded into E2; #59671 carries this commit (rebuilt as 7eb404b4ca on main 7c0f820c1a) and its body takes this body's facts; #59668 is to be closed, its state here changes with sync. opened as draft 2026-11-05; reviewed on bc90b487f2 (skeptic, Sol, Astra; Buildkite 136242 green); ready when a slot frees; E2 stacked on it, E2c on E2; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: the 8-1-stable/main/PR table, the temp-index and trigger sentences and the shared index-name case (fixed in E2c); in docs/upstream/ecosystem-tests.md"
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
