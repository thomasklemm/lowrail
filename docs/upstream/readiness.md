# Rails readiness runner

One repeatable round of "does the ecosystem still pass on the next Rails?", restarted before each 8.2 beta and RC
and later for 8.3. It runs apps' and gems' own test suites on a base and a candidate Rails tree and flags what
fails only on the candidate. Bisecting and classifying stay manual; the runner only flags.

Code: [`bench/upstream/readiness/readiness.rb`](../../bench/upstream/readiness/readiness.rb). It reuses the
ecosystem harness of [ecosystem-tests](ecosystem-tests.md) and [round 2](ecosystem-round-2.md):
[`eco.sh`](../../bench/upstream/ecosystem/eco.sh) bundles and runs each suite against one Rails checkout through
[`Gemfile.eco`](../../bench/upstream/ecosystem/Gemfile.eco), and
[`eco-locks.rb`](../../bench/upstream/ecosystem/eco-locks.rb) reports the lock difference besides Rails. The
failure parsing follows `fixtures/corpus/ruby-master-rails/compare.rb`.

## Run it

```sh
mise exec ruby@4.0.9 -- ruby bench/upstream/readiness/readiness.rb bench/upstream/readiness/MANIFEST.yml --jobs 3
```

Long rounds belong in a supervised service, so an Amp CLI restart doesn't stop them; rerunning the same command
resumes:

```sh
amp orb service start readiness --command 'cd ~/workspace/repo && exec mise exec ruby@4.0.9 -- ruby bench/upstream/readiness/readiness.rb bench/upstream/readiness/MANIFEST.yml --jobs 3'
amp orb service stop readiness   # when the report is written
```

The service manager starts the command again after it exits. Those reruns only rewrite the report from the
cache, but stop the service as soon as `summary.md` is written, so the orb can pause.

Options: `--only a,b` runs some suites, `--fresh a` drops a suite's cached state, `--report` rewrites the report
from what is cached, `--work DIR` (default `~/src/readiness/<manifest name>`) and `--out DIR` (default
`WORK/out`), `--services-down` stops every database service (teardown after a crash).

Databases: a suite lists the services it needs (`services: [postgres, postgres18, mysql, redis, memcached]`).
[`services.rb`](../../bench/upstream/readiness/services.rb) starts the ones not already listening as orb services
`readiness-<name>`, with data under `WORK/services` created on first use, and the round stops what it started when
it ends, also on failure:

| Service | Where | Accounts |
| --- | --- | --- |
| `postgres` | PostgreSQL 15 on 127.0.0.1:5432 and `/var/run/postgresql`, 300 connections, pgvector if installed | trust; superusers `postgres` (password `postgres`) and `user` |
| `postgres18` | PostgreSQL 18 on 127.0.0.1:5418 (socket in `/tmp`), for findings that need 18.4+ (Sure's SU3) | the same |
| `mysql` | MariaDB on 127.0.0.1:3306 and `/run/mysqld/mysqld.sock` | `root` and `user` without password, timezone tables loaded |
| `redis`, `memcached` | 6379, 11211 | no persistence |

The packages (`postgresql`, `mariadb-server`, `redis-server`, `memcached`) must be installed, with their system
services disabled; for the app round, [`app-prereqs.sh`](../../bench/upstream/readiness/app-prereqs.sh) installs
them and the rest that round needs (below). Suites that share a service run one at a time, because variants of a gem share database names;
each suite creates its databases in `setup`.

## Manifest

[`proof-e64f5a4258.yml`](../../bench/upstream/readiness/proof-e64f5a4258.yml) is a complete example. For a new
round, copy it, set `rails.base` and `rails.candidate` (pin SHAs: a branch name is fetched at every start, which
invalidates the cached runs whenever it moves), the Ruby, the two seeds and the suites:

| Key | Meaning |
| --- | --- |
| `repo`, `ref` | the suite's repository and its pinned tag or SHA |
| `framework` | `rspec`, `minitest`, `test-unit` (random order seeded through `SEED`, [`test_unit_seed.rb`](../../bench/upstream/readiness/test_unit_seed.rb)) or `cucumber` (pretty output, `CUCUMBER_OPTS` carries the seed), which decides how results are read |
| `test` | the suite's command, run through `bundle exec bash -c` |
| `setup` | commands run once per tree after bundling (database creation, schema load) |
| `env` | environment for setup and runs (database credentials, `RAILS_ENV`) |
| `gemfile`, `lock` | another Gemfile of the suite (e.g. `gemfiles/rails_8_1.gemfile`), another lock to start from |
| `shims` | shell commands, `{run: cmd}` or `{patch: file}` (relative to the manifest), applied before bundling (config copies, relaxed gemspec bounds); `tree: cand` applies one to the candidate only |
| `bumps` | gems replaced or added on both trees, `{name: "version"}` or `{name: {git: …, ref: …}}` (e.g. an unreleased rspec-rails fix) |
| `services` | databases to start for the suite (above) |
| `exclusive` | a name; suites with the same name never run at the same time (e.g. ones that share a fixed `/tmp` path) |
| `ruby`, `rails` | a suite's own Ruby, or its own `base` and `candidate` Rails refs; a ref can be `{ref: SHA, picks: {PR: head SHA}}`, that commit with those rails/rails pull requests cherry-picked in order (CHANGELOG conflicts merge as a union, anything else stops the round), kept as `refs/readiness/picks-*` in `WORK/rails.git` |
| `share_base` | another suite whose base side this one reuses (checkout, bundle, setup and base runs); for variants that differ only on the candidate, which `--check` verifies |
| `timeout`, `alone_max` | per suite (or for the round): seconds per run (default 3600), and how many one-seed tests are rerun alone (the rest read `one-seed`) |
| `single` | how to run one test alone, with `{id}` (default `rspec {id}`, or the test command with `-n /^Class#test$/` in `TESTOPTS`) |

Commands see `READINESS_TREE` (`base` or `cand`), so a suite can give each tree its own database names, and
`READINESS_MANIFEST_DIR`, for scripts next to the manifest. Top-level keys starting with `x-` hold YAML anchors.

Each suite gets one checkout per tree (`WORK/suites/NAME/{base,cand}`), so a schema dump or a generated file on
one tree never leaks into the other. The base lock starts from the suite's own lock if it has one, the candidate
lock from the base lock, so the bundles differ only in Rails and what Rails itself requires. Shims and bumps are
inputs like the refs: they apply to both trees, they are part of the cache key, and the summary lists them.

## What it does

Per suite: prepare both trees (checkout, shims, lock, bundle, setup), then run base and candidate under seed A
and again under seed B (`SEED`, `TESTOPTS=--seed=…`, and `SPEC_OPTS=--seed … --require rspec_json.rb`, so a
suite's own command needs no seed flag). `rspec_json.rb` adds its JSON formatter after the command line's
formatters instead of passing `--format` in `SPEC_OPTS`: RSpec takes `SPEC_OPTS`' formatters in place of the
command line's, which dropped the formatter Discourse's `turbo_rspec` workers report through, so the parent waited
forever. Each run is cached under `WORK/state/NAME/` with a key over the suite, its commit,
that tree's Rails SHA, the lock digest, `ruby -v`, the seed and the explicit inputs. A crashed round resumes at the
first missing run; when only the candidate moves (the next beta), the base runs are reused. A run killed by
`timeout` (manifest key, default 3600 s) counts as not loaded; a run cut off because the round was stopped (no exit
status) is not cached, so the resumed round runs it again.

Every test that fails in a candidate run gets one class:

| Class | Rule |
| --- | --- |
| `confirmed` | fails 2/2 on the candidate, passes 2/2 on base |
| `flaky-candidate` | fails 1/2 on the candidate, 0/2 on base, and fails at least once in 5 runs alone; the counts for both trees are in `detail` |
| `order-dependent` | fails 1/2 on the candidate, 0/2 on base, and passes all 5 runs alone |
| `one-seed` | fails 1/2 on the candidate, 0/2 on base, but the suite's `alone_max` tests were already rerun alone |
| `base-failing` | fails on base too, with the same kind of error |
| `signature-changed` | fails on both trees with different errors |
| `suite-did-not-load` | a tree did not bundle, did not boot, or ran no test (RSpec load errors, a crash, a timeout); such a suite never reads as 0 failures, and its tests are not compared |
| `test-count-mismatch` | the four runs ran different numbers of tests |

Error signatures are the exception class and the first line of its message, with object addresses, tmp paths,
checkout and gem paths, line numbers inside Rails and the two Rails version strings stripped. For the
`base-failing`/`signature-changed` decision, assertion failures (RSpec expectations, `MultipleExceptionError`,
`Minitest::Assertion`) count as one kind, because their messages embed the values under test; other errors must
match class and normalized message.

## Output

In `--out`: `flags.json` (pins, per-suite runs and lock differences, and the flags grouped by class and
signature), `flags.tsv` (one row per flagged test: match, class, suite, test, signature, candidate and base fail
counts, detail) and `summary.md` (one row per suite; then **New** flags, one table per class; then **Known**
flags, one row per finding with its status and record; then what fails on base too). Base-only failures are
counted per suite in `flags.json` and not flagged.

## Known findings

[`known.yml`](../../bench/upstream/readiness/known.yml) lists the findings of the earlier rounds (app suites,
ecosystem rounds 1 and 2, the API audit, and the proof round's noise). Each entry has an `id`, a `suite` regex
over manifest suite names, a `signature` regex, optional `test` and `class` patterns, a `status` (`open-pr`,
`merged`, `prepared`, `issue`, `record-only`, `gem-side`, `noise`), a `record` path and a `note`. Every flag gets
`known:<id>` from the first entry that matches it, or `new`. Several entries can share an id when one finding
has more than one signature. Entries marked "unchecked" have regexes taken from the record's wording, and no run
through the runner has produced their signature yet. Narrow them, or add the missing ones, after the first run of
that round. When a finding changes status (a PR merges, a gem releases a fix), update its entry in the same commit
as the ledger.

## Rounds

| Manifest | Round | Run |
| --- | --- | --- |
| [`proof-e64f5a4258.yml`](../../bench/upstream/readiness/proof-e64f5a4258.yml) | the proof round below | in full |
| [`round-app-suites.yml`](../../bench/upstream/readiness/round-app-suites.yml) | [app-suites](app-suites.md): Redmine, Lobsters, Solidus (core, api), Mastodon, Sure, Writebook, Forem, Chatwoot, Discourse, Spree (core, api), 24 suites with their variants | in full against main `bdb3d96012`, below |
| [`round-ecosystem-1.yml`](../../bench/upstream/readiness/round-ecosystem-1.yml) | [ecosystem-tests](ecosystem-tests.md), 24 gems in 29 suites | in full against main `7a78da5a55`, below |
| [`round-ecosystem-2.yml`](../../bench/upstream/readiness/round-ecosystem-2.yml) | [ecosystem round 2](ecosystem-round-2.md), 26 gems in 49 suites | in full against main `7a78da5a55`, below |

`--check` validates a manifest without running anything: keys and shapes, patch files, `known.yml`, installed
Rubies (a warning), and that every Rails and suite ref resolves (`--no-resolve` skips the fetch). All four pass.
The manifests keep each round's pins. For a beta, copy one, set `rails.candidate`, and keep the base, so the base
runs are reused. Per-suite keys added for these rounds: `ruby` (Sure and Writebook run Ruby 3.4), `rails` (Writebook
compares its own locked Rails with main), and shims with `tree: cand` for the main-only workarounds of the record
(Redmine's S1 middleware, Mastodon's R1 and M1 app shims). Those run as separate `-shimmed` suites, so the plain
suite still shows the finding. A DB setting that the round's notes abbreviated follows the gem's own CI and is
marked in the manifest; if it is wrong, the suite reads `suite-did-not-load`. RSpec results go through
[`rspec_json.rb`](../../bench/upstream/readiness/rspec_json.rb), one JSON file per process, so Mastodon's
flatware workers and suites that run RSpec twice keep every result.

## Proof round (2026-11-04)

Manifest [`proof-e64f5a4258.yml`](../../bench/upstream/readiness/proof-e64f5a4258.yml), output in
[`proof-e64f5a4258/`](../../bench/upstream/readiness/proof-e64f5a4258/summary.md). The pins of ecosystem round 2:
8-1-stable `6e09124217` against main `e64f5a4258`, Ruby 4.0.9, seeds 4242 and 1717, PostgreSQL 15 for scenic.
The lock difference besides Rails is the expected one (herb, marcel 2.1.0, ractor-dispatch; psych and stringio
for scenic).

| Suite | Record | Runner |
| --- | --- | --- |
| scenic 1.9.0 | 111 ex, 2F on 8-1, 19F on main: R2-2 | 17 `confirmed`, all `wrong number of arguments (given 2, expected 3)` (3 of them inside an `IrreversibleMigration` expectation); the two 8-1 failures `base-failing` |
| lograge 0.15.1 | 134 ex, 3F on 8-1, 7F on main: R2-3, R2-4 | R2-3: 2 `confirmed` (`attach_to` on `ActionController::LogSubscriber`, Action View subscribers not removed). R2-4: 2 `signature-changed`, `FrozenError` on `rescue_responses`; on base those two tests fail only under seed 1717, with an assertion. The three 8-1 failures `base-failing` |
| Lobsters `b6ea255`, rspec-rails 8.0.2 from its lock | L1 | `suite-did-not-load` on the candidate: 20 spec files fail to load with `FrozenError: can't modify frozen Hash: {}` (`default_url_options`), so no example runs; base 927 examples |
| Lobsters with the rspec-rails fix (bump to `9fb6f4f0a3`, as in [app-suites](app-suites.md)) | L2 | 3 `confirmed` `UrlGenerationError … id: ""` in `stories_spec.rb` check_url_dupe |

L2 still reproduces because its fix (c9fc37095f) merged after `e64f5a4258`; on current main this suite should come
out clean. Nothing the records call noise was flagged as a candidate failure: lograge is order-dependent on both
trees under seed 1717 (32 and 34 failures), and those tests read `base-failing`; Lobsters'
`submit_story_spec.rb[1:10]` fails under seed 1717 on both trees (`Domain has already been taken`), also
`base-failing`.

Matched against `known.yml`, all 25 candidate flags read as known (R2-2, R2-3, R2-4, L1, L2) and the 33
`base-failing` rows as recorded noise: 0 new.

Timing on an a1.large orb with `--jobs 3`: about 15 minutes for the first round, most of it bundling Lobsters;
lograge runs take 2 s, scenic 4 s, Lobsters about 45 s. Resume was checked by stopping the service mid-round: the
restart reused lograge and scenic and redid the interrupted Lobsters prepare. After later runner changes every
tree was prepared again, and all 16 runs came from the cache, because their keys had not changed. Two throwaway
suites (RSpec and minitest, not kept) covered the classes the proof doesn't reach: `order-dependent` (0/5 alone),
`flaky-candidate` (2/5 alone on the candidate, 0/5 on base), `test-count-mismatch`, and the minitest
`--name` rerun.

## Full run of the gem rounds (2026-11-04)

Both ecosystem manifests, 8-1-stable `6e09124217` against main `7a78da5a5576d7ab7549b10fb13156788478ba35` (pinned
in both manifests), Ruby 4.0.9, seeds 4242 and 1717, `--jobs 3`, databases from `services.rb`. Output in
[`round-ecosystem-1/`](../../bench/upstream/readiness/round-ecosystem-1/summary.md) and
[`round-ecosystem-2/`](../../bench/upstream/readiness/round-ecosystem-2/summary.md). Every suite loads on base;
every candidate `suite-did-not-load` is a recorded finding.

| Round | Candidate flags | Matched | New |
| --- | --- | --- | --- |
| 1 | 58: 53 `confirmed`, 2 `signature-changed`, 2 `suite-did-not-load` (AMS E4, administrate L1), 1 `test-count-mismatch` (draper) | E2, E4, I1, L1 and the unnamed eco1 entries (draper, dynamic `:controller` routes, ransack select manager, view_component) | 0 |
| 2 | 172: 162 `confirmed`, 4 `order-dependent` (strong_migrations, R2-7), 2 `signature-changed` (lograge R2-4), 2 `suite-did-not-load` (paranoia R2-6, store_model R2-9), 2 `flaky-candidate` | R2-1 to R2-11, R2-13 to R2-18 | 2 at the run (will_paginate), since recorded as R2-18 |

The run's only new flag: `will_paginate-mysql` and `will_paginate-postgres`, `./spec/finders/active_record_spec.rb[1:11:1]`,
`expected 2 queries, got 4`, `flaky-candidate`. It failed under seed 1717 only, and alone 5/5 on the candidate and
0/5 on base (sqlite3 passes). Triaged since as R2-18 in [ecosystem round 2](ecosystem-round-2.md): two schema
queries the spec's SQL-text filter no longer recognizes, from two intended changes (23bb4cdd4b, ae739c3854), and
an earlier example hides them under seed 4242. `flaky-candidate` was right about the runs and wrong about the
cause: a test that fails 5/5 alone and passes in one full-suite order is order-hidden, not flaky.

Not produced by this run, so still unchecked: E1 (ransack `WeakSet`) and E3 (administrate `colorize_logging`;
administrate's candidate stops at L1). R2-12 shares R2-11's signature. Base-only noise that the records don't
list, because they ran one default-order run, is now in `known.yml` as `noise`: acts-as-taggable-on (3 tests under
seed 4242) and counter_culture's `fix_counts_by_scope_spec` (seed 1717), both on both trees.

Setup fixes this run needed, now in the manifests: closure_tree, counter_culture (`fail_fast` off; a utf8mb4
database on MariaDB), scenic (`spec:acceptance` too; its 2 acceptance failures are R2-2), ransack-postgresql,
administrate, good_job, paper_trail (the appraisal guard accepts `Gemfile.eco-*`), sidekiq, kaminari (test-unit),
factory_bot_rails (rails_template and a clean bundler environment for the cucumber apps,
[`factory_bot_rails-eco-rails.patch`](../../bench/upstream/readiness/round-ecosystem-2/factory_bot_rails-eco-rails.patch)),
and shoulda-matchers (test projects take Rails from `ECO_RAILS`, acceptance projects bundle their own Gemfile,
and the runner's `SPEC_OPTS` stay out of them,
[`shoulda-matchers-eco-rails.patch`](../../bench/upstream/readiness/round-ecosystem-2/shoulda-matchers-eco-rails.patch)).
With them, factory_bot_rails runs all 26 cucumber scenarios, and shoulda-matchers matches the record exactly: 3097
and 3159 unit examples with 0 failures on base and R2-15's 2 on the candidate, 10 acceptance examples with 0 on base
and R2-1's 1 on the candidate. kaminari is pinned to v1.3.2, the commit its default branch pointed to in round 1, so its
results don't change (555 tests, 0 failures ×4).

Time: the four runs per suite add up to 82 minutes in round 1 (good_job 29, solid_queue 15 per database) and
70 in round 2 (shoulda-matchers 13 per variant, factory_bot_rails' cucumber 11), before bundling and the reruns
alone; `--jobs 3` overlaps them, except for suites that share a service or an `exclusive` name.

## Full run of the app round (2026-11-05)

[`round-app-suites.yml`](../../bench/upstream/readiness/round-app-suites.yml): 8-1-stable `6e09124217` against main
`bdb3d960121e7eb73a61c04099d1eef3c821e397`, Ruby 4.0.9 unless noted, seeds 4242 and 1717, `--jobs 3`, on one
a1.large orb (8 cores, 16 GB) with PostgreSQL 15 and 18 and Redis from `services.rb`. Output in
[`round-app-suites/`](../../bench/upstream/readiness/round-app-suites/summary.md). Each app runs as itself (`NAME`),
with the app shims for findings no PR of ours covers (`-shimmed`), and with our 15 open rails/rails PRs cherry-picked
onto main (`-prs`, `cc1ff7b867`) in place of the shims they make unnecessary; the variants share the base runs.
Every app runs unattended; none is left manual.

| App, pin (default branch, 2026-11-05) | Tests | Per run | Round time | Candidate result |
| --- | --- | --- | --- | --- |
| Redmine [`d9f5f18b65`](https://github.com/redmine/redmine/tree/d9f5f18b65dc7f27509a8eb5ea18fe4a8dab0335) | 6117 | 6–8 min | 30 min | plain: S1 at boot; shimmed: S1 1, S2 3 |
| Lobsters [`6f6e48f652`](https://github.com/lobsters/lobsters/tree/6f6e48f652ff10b8efb84c4882108f07a238340b) | 936 | 1 min | 5 min | plain: L1 at load; with rspec-rails main: clean (L2 is merged) |
| Solidus [`ed00fc881c`](https://github.com/solidusio/solidus/tree/ed00fc881c88d62af152e550b68e859715cf9bf3) | core 4487, api 684 | 4–6 min, 1 min | 25 min | core clean; api SO1 1 |
| Writebook [`d57c62bc19`](https://github.com/basecamp/writebook/tree/d57c62bc19edac3930d3860a2584757f1d45d07c), Ruby 3.4.12, base its locked main `3a4961048a` | 313, system 3 | under 1 min | 5 min | clean (2 libvips failures on both trees) |
| Mastodon [`da4edd9b80`](https://github.com/mastodon/mastodon/tree/da4edd9b8003f54a5815165b5c8193604fbe679d) | 8010 | 2–3 min | 15 min | plain: R1 2195, M1 225, S2 11, precision 3, enum 1; prs (with the M1 app shim): S2 11, `Vary` 19, precision 3, enum 1 |
| Sure [`529d7de76f`](https://github.com/we-promise/sure/tree/529d7de76f07ba0557e8a442dd7c53cdd401169a), Ruby 3.4.9, PostgreSQL 18 | 14661 | 8–12 min | 40 min | SU2 455, SU5 27, SU3 3, SU4 2; SU1 is merged (#59640) |
| Forem [`310cb3f37b`](https://github.com/forem/forem/tree/310cb3f37b0a9eb351828218d7bbd5d8c15840f1), Ruby 3.3.13 | 16487 | 9–10 min | 80 min | plain: deprecation at boot; shimmed: F1 at schema load; with 8-1's schema: 1741, all the record's groups (FO1, FO3, deprecations) |
| Chatwoot [`17b246068c`](https://github.com/chatwoot/chatwoot/tree/17b246068c1e141ba0dc8488ca7f4c83f466e8ce), Ruby 3.4.4 | 7682 | 3–4 min | 50 min | plain: `attach_to` at boot; shimmed: CW2 125, CW6 54 (new), SU5 14, CW1, CW3–CW5; prs: CW1, CW2 and CW6 gone |
| Discourse [`f2eb5d605b`](https://github.com/discourse/discourse/tree/f2eb5d605b577bb62715c5df54ef390f133a9e81) | 35822 | 11–15 min | 90 min | plain: DS1 in `db:migrate`; shimmed: 130, among them #59574's json_api_kit 101; prs: 30; DS2 and AR-4 are merged |
| Spree [`0eb13214ed`](https://github.com/spree/spree/tree/0eb13214ed61c48c0cebdb356e0235c0b40e61d7) | core 11236, api 6320 | 8 min, 4–5 min | 55 min | plain: AR-2 at boot; prs: SP1 50, SP3 2, SP2 1 |

Round time is the four runs per variant plus reruns alone and prepares, measured on this run; with bundles cached a
full rerun takes about 7 hours, most of it one suite at a time, since nearly every suite needs PostgreSQL.

Result: 5181 candidate flags, every one known (5378 rows with the 197 that fail on base too), so **0 new**. The new
groups the run turned up are recorded and matched: CW6 (Chatwoot's new positional `Arel::Table.new`, covered by our
#59574) and a fourth Discourse `Vary` failure from a Discourse spec change (open #59500), both in
[app-suites](app-suites.md); noise that passes alone on both trees (Chatwoot's `bulk_actions` order dependency,
Discourse's `user_stat_spec` and the network-bound `smtp_spec`). Two Sure groups were checked by a rerun: the 9 files
behind its aborted-transaction, Financekit and `assert_raises` rows fail 27 times with prepared statements and 0
times without (266 tests), so they are SU2. Findings fixed on main since the record no longer show: L2 (#59625), SU1
(#59640), DS2 (#59595), AR-4 (#59634).

Runner fixes this run needed: RSpec's JSON formatter is added after the command line's formatters (Discourse's
`turbo_rspec` hung on the first run, see above), a run cut off by stopping the round is not cached, and Spree's root
bundle installs into the suite's bundle path.

**Rerun when main moves.** Set `rails.candidate` and `x-prs.ref` to the new main, drop merged or closed PRs from
`x-prs.picks` and update the pushed heads (`--check` resolves them), then:

```sh
bench/upstream/readiness/app-prereqs.sh && amp orb service start readiness --command 'cd ~/workspace/repo && exec mise exec ruby@4.0.9 -- ruby bench/upstream/readiness/readiness.rb bench/upstream/readiness/round-app-suites.yml --jobs 3'
```

The base runs are reused, so only the candidate side runs (about 4 hours). `summary.md` lists only what matches no
entry in `known.yml` under **New**. Stop the service when it is written (`amp orb service stop readiness`, from the
repository); `--services-down` cleans up after a crash.

## Limits

* **Suites only.** The cross-version data differential ([rails-82-differential](rails-82-differential.md),
  `fixtures/corpus/rails-82-diff`) and the Ruby master lanes ([ruby-master-rails](ruby-master-rails.md)) compare
  outputs, not pass/fail, and keep their own harnesses.
* **A load error hides the tests behind it.** RSpec runs no example once a file fails to load, so the suite reads
  as `suite-did-not-load` and its test-level regressions stay invisible until a bump or shim gets it past the load
  error (Lobsters' L1 hides L2; see the proof round).
* **Two seeds can't separate every flake.** Only a test that fails under one candidate seed is rerun alone. A suite
  that is order-dependent on base under one seed (lograge under 1717) turns those tests into `base-failing`, which
  can also cover a candidate regression in the same test; `signature-changed` catches it only when the error kind
  differs.
* **Signatures are a first line.** The class and the first line of the message; `MultipleExceptionError` shows its
  first error only. Grouping is a reading aid, not a cause.
* **RSpec ids are positional** (`./spec/x_spec.rb[1:2:3]`): stable for a pinned ref, but a test that exists on one
  tree only shifts the ids after it; `test-count-mismatch` points at that case.
* **Minitest output is read as text** (the default reporter and the Rails runner). A suite with another reporter
  reads as `suite-did-not-load`, never as 0 failures.
* **Services are this orb's packages.** PostgreSQL 15 and the Debian MariaDB, not the versions a gem's CI uses;
  MariaDB started with `--no-defaults` creates latin1 databases, so a suite that writes UTF-8 creates its database
  with `character set utf8mb4` (counter_culture). Prepare failures are cached like runs; rerun them with
  `--fresh NAME`.
* **Known findings are regexes.** A new failure with the same signature as a known one in the same suite reads
  as known. The ecosystem and app-suite entries are checked against their full runs above; app entries name the
  variants they show in and, where the signature is a bare assertion, the test files, so a new failure in another
  file still reads as new.
* **One round at a time on a1.large.** Discourse's 8 workers, Forem's 4 processes and Chatwoot's 8 fill the 16 GB;
  scratch runs alongside the app round got processes OOM-killed. The app round's suites share PostgreSQL, so they
  run one after another anyway.
* **Locks hold a worker.** A suite waiting for a shared service or an `exclusive` name keeps its `--jobs` slot,
  so three shoulda-matchers variants in a row leave one worker for everything else. Order `--only` lists, or run a
  slow exclusive group in its own process.
* **One bundle per repository** under `WORK/bundle/REPO`, shared by its variants, so the variants' locks must agree
  on the gems they share.
* **`Gemfile.eco` must not load a gem.** It runs inside Bundler's resolution; a `require "json"` there activated
  the default json 2.18.0 and every suite that locks another json (active_model_serializers, json 2.9.1) failed
  to boot. Bumps therefore travel in `ECO_BUMPS` as a Ruby hash literal, not JSON.
