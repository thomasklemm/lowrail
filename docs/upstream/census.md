# Rails allocation census: `script/census`

One command runs the census of censuses 4 and 5: real apps on Rails main (SQLite, PostgreSQL, MySQL), 97
request, job and mailer workloads, interpreter and JIT modes, an A/A baseline, allocation sites attributed by file
and line, a breadth-first ranking, comparisons of patched Rails branches against the base with behavior controls,
and the open rails/rails PRs that touch the ranked lines. Rails ref, Ruby and mode are parameters. The same steps
therefore serve a Rails-main round, a Ruby 4.0.7 vs ruby-master comparison (`--ruby`) and a JIT vs interpreter
comparison (`--modes`, `LABEL:MODE`).

Results are allocation counts only. No timing is inferred from them. Speed claims need `lowrail bench`
([bench.md](../bench.md)).

## Run a round

```sh
# 1. App copies at a Rails ref (.corpus/census-APP), bundled, seeded, assets built, every workload smoke-tested.
script/census setup --rails main                     # or a commit, a tag, OWNER/REPO@BRANCH
# 2. The A/A pair: two full unpatched runs, base and base2.
script/census run --label base --aa --modes interp,yjit
# 3. Rank Rails lines by breadth on base2.
script/census rank --label base2 --mode interp       # and --mode yjit
# 4. Open rails/rails PRs on the ranked lines, so a candidate does not duplicate one.
script/census prs --label base2 --top 40
# 5. Each candidate is one commit on its own fork branch, based on the same commit.
script/census run --label extending --rails thomasklemm/rails@thomasklemm/merge-skip-empty-extending
script/census compare --base base2 --aa base extending              # add --markdown for the per-app table
script/census controls --script bench/upstream/census_5_controls.rb base2 extending
```

Common options: `--apps blog,campfire` (default: all ten configurations), `--ruby 4.0.7` (a mise version, installed
on demand, or a path to a `ruby` binary or its `bin` directory), `--corpus NAME` (copies in `.corpus/NAME-APP`, so
several bases can coexist), `--out DIR` (default `.lowrail/private/census`), `--jobs N` (apps measured in parallel
within one mode; counts are per process and unaffected). `script/census list` replays every workload three times
against the base, a smoke test after changing workloads. `script/census help` prints every option.

**Rails refs.** `SPEC` is `REF`, `OWNER/REPO@REF` or `/path/to/rails@REF`, where REF is a branch, tag or commit.
`setup` records the resolved commit as the base. `run --rails SPEC` measures another commit. A label's
commit and Ruby are fixed by its first run (`meta.json`), and a later run under that label must match them.

**How the Rails ref is swapped.** Each app keeps its own `Gemfile`. A variant `Gemfile.census-SHA12`, with its own
lock, differs in exactly one line: `gem "rails", github: "OWNER/REPO", ref: "SHA"` (`git: "PATH"` for a local
repository). The `ruby` pin is dropped, so the Ruby is a parameter. Every bundle is installed before measuring. No
`bundle` command runs during a run, and no shared gem checkout is patched in place (censuses 3 and 5 did patch it).
As a dependency control, `run` compares the variant lock with the base lock outside the Rails `GIT` block and
`RUBY VERSION`. It records the result in `meta.json` and warns when they differ.

**Ruby comparisons.** Give each Ruby its own labels and its own A/A pair, for example
`run --label m407 --aa --ruby 4.0.7` and `run --label master --aa --ruby ~/rubies/master`. Then run
`compare --base m4072 --aa m407 master`. `compare` prints each label's Rails commit and `RUBY_DESCRIPTION` first.
**JIT comparisons:** `compare --base base2:interpreter base2:yjit` pairs the same app across modes. `--modes zjit`
needs a Ruby built with ZJIT. The local 4.0.7 is not, so ZJIT has not been run through this command yet.

## Services and apps

| App | Source (script/corpus) | Overlay | Needs |
| --- | --- | --- | --- |
| blog | `real-blog-r4` (retained archive) | `blog.patch` | |
| campfire | `campfire` (`af4dd9f`) | `campfire.patch` | Redis |
| writebook | `writebook-r82` source (`7478e2c`), without its own overlay | `writebook.patch` | Redis |
| fizzy | `fizzy-r82` source (`77eada1`), without its own overlay | `fizzy.patch` | |
| fizzy-mysql | same source | `fizzy.patch` | MySQL 8.4 on 127.0.0.1:3307, root without password |
| codetriage | `codetriage` (`d1868f8`, plus `fixtures/corpus/codetriage.patch`) | `codetriage.patch` | PostgreSQL (local socket), memcached, Redis |
| pingcrm | `pingcrm` | `pingcrm.patch` | PostgreSQL, bun |
| redprints-cfp | `redprints-cfp` | `redprints-cfp.patch` | bun |
| react-starter-kit | `react-starter-kit` | `react-starter-kit.patch` | npm |
| lobsters | `lobsters` (`366e211`) | `lobsters.patch` | |

Overlays default to [fixtures/corpus/rails-main-census-4](../../fixtures/corpus/rails-main-census-4) (`--overlays`
picks another round's). They are dependency-only (Gemfile, lock, `.ruby-version`); setup then moves Rails to the
requested commit. `run` checks that the services are reachable and refuses to start otherwise. Use disposable local
services, for example `amp orb service start census-redis --command 'redis-server --save "" --appendonly no'`.
Database URLs in the environment are refused.

Setup per app: `db:create db:schema:load` in production, the app's JS build where it has one, `assets:precompile`,
then the harness `prepare` step. That step loads the Blog's seeds; test fixtures for Campfire, Writebook, Fizzy (with
its UUID fixture helper) and CodeTriage; PingCRM's seeds with `Faker::Config.random = Random.new(42)`; Redprints' and
the starter kit's seeds; Lobsters' seeds and `FakeDataGenerator` with `srand(42)` and
`Faker::Config.random = Random.new(42)`, under the app's own queue adapter (solid_queue). Last comes `list`. All ten
configurations have been set up and run through this command ([Validation](#validation-nine-apps-2026-11-03)).

PostgreSQL and MySQL databases are named by the app's config, not by the copy, so every copy of an app shares them.
For those apps `setup` runs `db:create` on its own and stops if it reports `Database '…' already exists`, rather
than loading the schema over another copy's data. Drop the databases first when they are disposable (for example
`dropdb pingcrm_production`, or `DROP DATABASE fizzy_production…` on port 3307). `setup` also creates `log`, `tmp` and
`storage`, which Git does not keep and Lobsters' production boot needs.

## What a run measures

The harness [bench/upstream/census/harness.rb](../../bench/upstream/census/harness.rb) boots each app in its own
process, in production, with no Lowrail preload. It uses census 4's request client, measurement and workload set
unchanged ([rails_main_census_4.rb](../../bench/upstream/rails_main_census_4.rb),
[census_4_workloads.rb](../../bench/upstream/census_4_workloads.rb)). What it generalizes is the round-specific
part:

* the expected Rails commit (`CENSUS_RAILS_SHA`), checked against the loaded railties;
* the mode, checked against `RubyVM::YJIT`/`RubyVM::ZJIT` after boot (Writebook's own `RubyVM::YJIT.enable` is
  hidden outside YJIT mode);
* preparation for every app;
* `GIT_REVISION=census` for every variant, so the app does not see the Rails commit.

Shared external controls, identical for every app: jobs are captured on the `:test` adapter and performed as their
own workloads, mail uses `:test` delivery, `config.hosts` is cleared, and URL options default to
`https://localhost`. Each response status is checked, and GET bodies must be non-empty.

Per workload: 50 warmup operations (`CENSUS_WARMUP`), then three GC-enabled windows of 20 operations (the median is
the reported value), then 10 traced operations with GC disabled (`CENSUS_REQUESTS`), attributed by file, line and
class. After every workload has been measured, a **SQL control** runs each workload twice more with an
`sql.active_record` subscriber on the measuring thread. It records `queries_per_op` and a digest of the statements,
with literals and numbers masked. The subscriber never runs during measurement.

## Outputs

Under `--out` (default `.lowrail/private/census`, not checked in):

| Path | Contents |
| --- | --- |
| `LABEL/APP-MODE.json` | One process: `app`, `ruby`, `mode`, `yjit`, `rails` (commit), `rails_dir`, `adapter`, `lock_sha256`, and per workload `gc_enabled_objects_per_op` (three windows), `traced_gc_objects`, `sites` (`file` as `RAILS/…`, `APP/…`, `GEM/…`, `RUBY/…`; `line`, `class`, `objects_per_op`) and `sql`. Same fields as census 4's receipts, plus `mode`, `rails_dir` and `sql`. |
| `LABEL/APP-MODE.log` | That process's output. |
| `LABEL/meta.json` | Rails spec and commit, Ruby description, and per run the apps, modes, `--only` and the dependency control. |
| `rank-LABEL-MODE.tsv` | Full ranking, written by `rank`. |
| `controls/SCRIPT-LABEL-MODE.txt` | Output of each controls run. |
| `open-rails-prs.json` | Cached open rails/rails PRs (`--refresh` refetches), with each PR's diff hunks once fetched. |

Receipts for a published round go to `docs/upstream/data/ROUND/receipts.tar.gz`, as in censuses 3 to 5.

## How ranking works

`rank` ([bench/upstream/census/rank.rb](../../bench/upstream/census/rank.rb)) is census 4's ranking. Only Rails
lines (`RAILS/…`) are ranked.

1. A line **reaches** a workload when it allocates at least 0.5 objects per operation there (traced window).
2. Apps reached counts distinct apps (`fizzy` and `fizzy-mysql` are one app).
3. Lines are **tiered by apps reached**: ≥ 7, 5–6, 3–4, 2, 1 by default (`--tiers 7,5,3,2`; with fewer apps, choose
   floors that fit).
4. Within a tier, lines are ordered by the **mean objects per operation over every workload of every app**. That is
   the per-call cost times how often an ordinary operation gets there. A line in more apps always ranks above a
   line in fewer, whatever its size, so single-app hotspots sink to the bottom.

Columns: apps, share (the fraction of all workloads reached), mean, workload kinds reached, and the two dominant
classes. Breadth across apps decides the order, and "workloads moved" in `compare` then decides whether a candidate
is worth a PR ([DECISIONS](../DECISIONS.md): prefer broad, idiomatic patterns over single-app hotspots).

`prs` matches the top `--top` ranked lines against open rails/rails PRs (via `gh`). It lists PRs whose diff hunks
cover the line (`line:`, approximate, because hunks are on each PR's own base) and counts the PRs that only touch
the same file (`file:`).

## Comparing branches, and the A/A rule

`compare --base B LABEL...` prints, per app and mode, the number of workloads whose median objects per operation
fell by at least one (`moved`), the median and the minimum delta (`--detail` lists every workload). The `ALL`
lines total each mode across apps. `SQL` lines count the workloads whose SQL digest differs from the base.
[compare.rb](../../bench/upstream/census/compare.rb) prints the same lines as census 4's `census_4_compare.rb`, and
`--markdown` prints census 5's per-app table.

**The A/A rule.**

* Every round runs two full unpatched runs, `base` and `base2`, with the same Rails, Ruby, apps and modes
  (`run --aa`). Candidates are measured against `base2`, and `compare --aa base` prints the `base2 − base` block
  first.
* The A/A pair is the noise floor. Single write workloads move by 10 to 180 objects in either direction between
  identical runs (cache, timestamp and job-payload effects). A candidate is therefore judged by the shift of the
  whole distribution: workloads moved ≤ −1 and the median, set against the A/A counts. Census 4's candidate 8 moved
  82 of 97 workloads against the A/A's 26. A single cell proves nothing.
* An A/A median that is not +0.0, or A/A counts that grow from round to round, mean state is accumulating between
  runs. Fix the workload reset first; do not rank or compare until then (census 4 reran everything for this).
* The SQL control follows the same rule. A candidate passes when its changed-SQL count does not exceed the A/A's, on
  the same workloads.
* `controls` runs a round's SQL-and-result snapshot script (for example
  [census_5_controls.rb](../../bench/upstream/census_5_controls.rb)) under each label's Rails, in one SQLite app's
  bundle (`--app`, default blog), for every mode. Every label's output must equal the first label's, otherwise the
  command exits 1.

## Validation (2026-11-02)

Blog and Campfire on Rails main `5810776eec` (census 5's pin), Ruby 4.0.7, interpreter and YJIT. The A/A pair
(`base`, `base2`) and census 5's candidate 12 (`thomasklemm/rails@thomasklemm/merge-skip-empty-extending`,
`2c301c33bf`) as the patched branch:

* `rank` output (text and TSV) is byte-identical to `rails_main_census_4_rank.rb` on all six label/mode runs. It is
  also identical on census 4's and 5's published receipts (`base2`, both modes). `compare` is identical to
  `census_4_compare.rb` (with `DETAIL=1`) on the same runs and on every census 4 receipt label. `--markdown` is
  identical to `census_5_table.rb` on census 5's receipts.
* A/A (`base2 − base`): median +0.0 in both modes. 0 / 2 of 19 workloads moved ≤ −1 (interpreter / YJIT), and one
  Blog YJIT write workload moved by −109. The SQL control changed for 0 workloads.
* Candidate 12: Campfire median −5.0 / −4.9 objects per workload, 6 of 9 workloads moved in both modes (A/A: 0).
  Census 5 recorded −5.8 / −4.3 for this app. Blog was flat, as in census 5. SQL changed for 0 workloads.
  `census_4_controls.rb` and `census_5_controls.rb` gave identical output for base, base2 and the branch in both
  modes. As a negative control, a script that prints the loaded Active Record path differs between labels and
  makes `controls` exit 1.
* A first pass recorded SQL from every thread. It showed 1–2 workloads drifting in the A/A pair. Recording only
  the measuring thread removed that drift.

## Validation, nine apps (2026-11-03)

All ten configurations on census 5's pin (Rails main `5810776eec`, Ruby 4.0.7), set up from scratch with
`script/census setup` and run with `run --label base --aa --modes interp,yjit --jobs 10`. Every copy passed `list`, with
97 workloads in total (blog 10, campfire 9, writebook 8, fizzy 14, fizzy-mysql 14, codetriage 7, pingcrm 8,
redprints-cfp 8, react-starter-kit 8, lobsters 11), the same names as census 5's receipts. Three fixes to the command
came out of the first full pass:

* **Server databases.** fizzy-mysql's `db:schema:load` failed on a foreign key because census 5's copies had left
  `fizzy_production*` on the shared MySQL server. `setup` now refuses when `db:create` reports an existing database
  (see [Services and apps](#services-and-apps)). It also creates `log`, `tmp` and `storage`; Lobsters' production
  boot opens `log/rails.log`. PingCRM's `prepare` requires `faker`, which its Gemfile marks `require: false`.
* **Lobsters data.** The first runs differed from census 5 on GET story (−3,282 objects) and GET tag (−936). Census
  5's recorded recipe (`db:prepare`, then `rails runner` with `srand(42)` and `Faker::Config.random =
  Random.new(42)`) reproduces census 5's stories exactly. The harness had omitted the Faker seed, and it generated
  under boot's `:test` queue adapter. Replaying census 5's recipe with only `queue_adapter = :test` added reproduces
  the harness's stories, so the generator's draws depend on the adapter. `prepare` now seeds Faker and generates under
  the app's adapter, and its stories match census 5's row for row. Two fresh setups give identical stories, users,
  tags and comments.
* **Job workloads.** fizzy-mysql under YJIT enumerated a 15th workload, `perform Turbo::Streams::BroadcastStreamJob`,
  in both A/A runs. Fizzy's `broadcasts_refreshes` enqueues that job from Turbo's debounce timer thread 0.5 s later,
  so census 4's `jobs_from` caught it only when the timer fired inside the capture. Census 5 never caught it. The
  harness now drops jobs enqueued on other threads. Only Fizzy uses refresh broadcasts; `list` still passes all 14
  Fizzy workloads.

Results, with the Lobsters and fizzy-mysql runs redone after the fixes:

* A/A (`base2 − base`): median +0.0 in both modes. 24 / 23 workloads moved ≤ −1 and 16 / 15 moved ≥ +1
  (interpreter / YJIT); census 5's A/A moved 17 / 18 and 24 / 23. SQL changed for 8 / 6 workloads. PingCRM moved 8
  of 8 interpreter workloads by a median −3.0, a uniform shift from one process to the next.
* Against census 5's `base2`: median 0.0 in both modes. Per-app medians are within ±2.2 objects, except PingCRM
  interpreter at −5.4, within its own A/A shift. Six workloads move more than 20 objects, all comment or message
  writes. Fizzy comment POST.json moves +81 (interpreter, A/A 35), −67 / −68 on MySQL (A/A 19 / 67), and Fizzy
  PATCH comment moves −82 under YJIT (A/A 81). The Blog's comment POST moves −60 under YJIT (A/A 59). Campfire's PATCH
  message moves −37 under YJIT, where both rounds' A/A is flat, and is flat in the interpreter; neither that nor
  fizzy-mysql's interpreter −67 is explained.
* `rank` on `base2`: the interpreter top 40 is identical to census 5's (same sites, ranks and app counts). YJIT
  shares 39 of 40 sites; `fanout.rb:263` (40th, now 41st) and `date_and_time/zones.rb:38` swap at the boundary.

## Older census scripts

Censuses 3 and 3b (`script/rails-main-census`, `bench/upstream/rails_main_census.rb`, `rails_main_rank.rb`,
`census_3_*`, `census_3b_*`), census 4 (`rails_main_census_4*.rb`, `census_4_*`) and census 5 (`census_5_*`) stay in
place. Their reports cite them as the way to reproduce those rounds, and this command builds on census 4's
harness and workloads. Per-call micros and probes (`census_N_allocs.rb`, `census_N_yjit_probe.rb`,
`census_4_callers.rb`) and controls scripts remain per round, because they target that round's candidates.
