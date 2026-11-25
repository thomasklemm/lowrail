# SQ37 review evidence, 2026-11-25

Reviewed fork head `183262f44056c9b860cb0921b2c596a2e183653d`, exactly one commit on
`f785381cca8621772cba659ff93f825eb7f99942`. Lowrail started at `f23b18386c7e06825cf31bcfb27a7d8f5629e5e2`.
Thread: https://ampcode.com/threads/T-01a21502-d24f-743b-b975-de940480e1e3.

Both Thermos rubrics were loaded and applied by this reviewer in this thread, as requested. No independent
subagents or threads ran. This is not a claim of two independent reviewers. SQ37.md and the fork were not edited.

## Verdict: changes to the record; adapter code approved

The floor comparison and message are correct, no new code comments were added, and the CHANGELOG/commit message
follow the earlier floor bump's shape. The test is small and worth keeping: running the new test file with base
libraries gives `RuntimeError expected but nothing was raised` (1 failure); with head libraries it gives
`1 runs, 3 assertions, 0 failures, 0 errors, 0 skips`. See `boundary-regression.txt`.

Must fix the queue record's factual overstatements:

* `impact`: replace `8.0/8.1 accept 3.23.0` with `8.0.0 accepts 3.8.0; 8.1.4.1 accepts 3.23.0`.
  The pinned sources were fetched with `gh api .../contents/...sqlite3_adapter.rb?ref=TAG`; see `claim-sources.txt`.
* `impact`: remove `Model.column_names` from the shared main-and-8.1 failing list and append
  `Model.column_names fails on main but works on 8.1.4.1.` This is independently reproduced on 3.35.5 in
  `8.1-probe.txt` and `probes.txt`; the supplied 8.1 report agrees.
* `impact`'s final sentence: replace with `Main refuses SQLite below 3.35.0; 8.1.4.1 checks 3.23.0 and 8.0.0
  checks 3.8.0, despite sharing the 3.37.0 metadata dependency.` The broken 3.35/3.36 range is not main-only.
* `For Thomas`: replace `On those versions nothing that touches the schema works: db:prepare and every model fail`
  with `On those versions, db:prepare and ordinary model reads and writes fail`. Replace
  `That is safe because they cannot work today anyway` with `Those ordinary Rails operations already fail today`.
  Raw SQL, direct column inspection and table creation still work on base; head now refuses them too. This is
  consistent with choosing an honest overall adapter floor, but not with a claim of zero working use cases.
* In the evidence README, make the same version and scope corrections. The existing public-API results table
  already correctly distinguishes `Model.column_names` on 8.1; the impact line does not.

The posted-body draft and commit need no factual replacement. The body is near the upper end of the preferred
length but remains two readable paragraphs. It describes ordinary failure paths, not all possible uses.

## Optional companion changes

* The pre-existing app generator template
  `railties/lib/rails/generators/rails/app/templates/config/databases/sqlite3.yml.tt:1` still says
  `# SQLite. Versions 3.8.0 and up are supported.` Prefer replacing that line with
  `# SQLite. Versions 3.37.0 and up are supported.` The earlier floor bump missed it too; this is not an introduced
  runtime defect. Three checked-in test dummy `config/database.yml` files repeat it (Action Mailbox, Action Text,
  Active Storage); synchronizing those is optional. Current guides and CI do not otherwise pin the old supported
  SQLite floor. Historical release notes should stay historical. See the whole-tree search in `code-review.txt`.
* The new test's `assert_nil @conn.check_version` checks an incidental internal return. An optional stronger shape
  is `assert_nothing_raised { @conn.connect! }`, with the rejecting assertion also invoking `connect!`; stubbing
  `database_version` itself is consistent with nearby Rails adapter tests. The present test is not a blocker.

No structural regression: the single existing condition remains a single condition, no wrapper or fallback is
introduced, and the test file was already over 1,000 lines. Cold read: reject a database below the minimum;
otherwise allow connection setup to continue. Readability is L0.

## Executed checks

```sh
LOWRAIL_MIN_VERSIONS_CACHE="$PWD/.amp/in/orb-backup/sq37-review/min-versions" \
mise exec ruby@4.0.9 -- script/min-versions --repo https://github.com/thomasklemm/rails.git \
  --head 183262f44056c9b860cb0921b2c596a2e183653d --base f785381cca8621772cba659ff93f825eb7f99942 \
  --only sqlite --sqlite 3.36.0,3.37.0 --json .amp/in/orb-backup/sq37-review/min-versions.json \
  activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb bench/upstream/sq37/sqlite_data_sources_test.rb
```

`min-versions.md`, `.json` and `.log` are this run, not copies of the builder's report. Exit 2 is expected:
Rails' suite cannot boot on 3.35.5/3.36.0, on base or head. The standalone cases report 12 metadata-path errors on
base, versus 15 connection-version errors on head, including the three previously working controls. On both
3.37.0 and 3.44.2 the adapter suite is 110 passing tests on base / 111 on head; standalone is 15 passing on each.
This is not an all-green claim for the below-floor cells. SQLite-only verification is appropriate for this
SQLite-only change; PostgreSQL, MySQL and other Ruby versions were not rerun by this reviewer.

`probe.rb` / `run-probes.sh` generated `probes.txt`: fresh connections and reset model schema for each operation,
with `find` and `create!` tested separately. `8.1-probe.txt` uses released Rails 8.1.4.1 at
`3f290b759c8e2ffe7c257951b1255740751355e4` and real SQLite 3.35.5 with `Gemfile-8.1`.
The stubbed connection boundary also checks 3.35.5, 3.36.0, 3.37.0, 3.37.1 and 3.100.0. Input subclasses and duck
types are not a caller contract here: the version is produced internally as the adapter's `Version` object.

`app-results.txt` reruns `ruby bin/rails db:prepare` in the included minimal Rails/Active Record app. On 3.36.0,
base gives `no such table: pragma_table_list`, head gives `Your version of SQLite ... supports SQLite >= 3.37.0.`;
on 3.37.0 both exit 0. `additional-checks.txt` queries both resulting databases: each contains `widgets`,
`schema_migrations` and migration version `20261125000000`. The runner and fixtures retain the original scratch
paths used in the orb; copy them back under `.amp/in/orb-backup/sq37-review` to replay them after min-versions.

`fallback-sql.txt` executes the same ordinary/FTS5 schema on real 3.35.5, 3.36.0 and 3.37.0. `sqlite_master`
labels ordinary, virtual and all five shadow tables `table`; 3.37.0's `pragma_table_list` distinguishes them.
A plain fallback would regress the virtual-table schema-dumping behavior that motivated the earlier change;
implementing equivalent general classification is not clearly better than this two-line floor update.

## Claim sources checked

* Both exact GitHub body permalinks were opened; their line ranges were also checked with `nl -ba`, recorded in
  `additional-checks.txt`. Both fragments point at the claimed methods.
* https://www.sqlite.org/releaselog/3_37_0.html and
  https://www.sqlite.org/pragma.html#pragma_table_list: feature and type values, release date 2021-11-27.
* `gh api repos/rails/rails/pulls/52354`, its commits and files: `pragma_table_list` introduced by that PR;
  the same query is present in fetched v8.0.0 source. The PR was merged 2024-08-26.
* `gh api repos/rails/rails/pulls/58284` and its actual merge diff: floor, unconditional capability predicates and
  CHANGELOG only, no test. Merged 2026-07-29. Latest Rails release queried is v8.1.4.1 (2026-11-04); its source
  still checks 3.23.0, whereas main checks 3.35.0. See `claim-sources.txt` and `code-review.txt`.
* https://github.com/sparklemotion/sqlite3-ruby/blob/v2.10.2/INSTALLATION.md and `dependencies.yml`, fetched with
  `gh api`: native/default source gems package SQLite; opting into system libraries requires a source build.
  Latest gem release queried is 2.10.2; it packages SQLite 3.54.1. Even v2.1.0, the first gem allowed by main,
  packages 3.46.1. The body's vendoring/affected-build claim is supported.
* https://repology.org/api/v1/project/sqlite: filtered 3.35/3.36 matches in `repology-matches.json` are Fedora 39's
  MinGW cross package and legacy entries in Npackd and xrepo, not a native supported distribution SQLite.
  The earlier README's parenthetical `only ... mingw ... and xrepo` omits Npackd; optional replacement:
  `only cross-compilation and legacy package entries`.
* Alpine aports 3.14-stable / 3.15-stable APKBUILDs and Fedora dist-git f35 / f36 sqlite.spec were fetched;
  endoflife.date's Alpine/Fedora APIs confirm the stated EOL months. See `distro-sources.txt`.

The ownership search was not rerun: the item is held and no upstream opening was requested. No upstream comment,
fork push, review submission or PR edit was made. Only this review evidence was added to Lowrail.
JSON parsing, Ruby syntax and shell syntax checks pass. `git diff --check` flags whitespace in captured git diffs,
numbered source lines and Ruby backtraces; those raw transcripts are retained verbatim, not reformatted.
