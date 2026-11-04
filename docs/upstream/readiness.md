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
`WORK/out`). The databases a suite needs (PostgreSQL, MySQL, Redis) are started by hand before the round. A
suite's runs go one after another, so its two trees can share a database name.

## Manifest

[`proof-e64f5a4258.yml`](../../bench/upstream/readiness/proof-e64f5a4258.yml) is a complete example. For a new
round, copy it, set `rails.base` and `rails.candidate` (pin SHAs: a branch name is fetched at every start, which
invalidates the cached runs whenever it moves), the Ruby, the two seeds and the suites:

| Key | Meaning |
| --- | --- |
| `repo`, `ref` | the suite's repository and its pinned tag or SHA |
| `framework` | `rspec` or `minitest`, which decides how results are read |
| `test` | the suite's command, run through `bundle exec bash -c` |
| `setup` | commands run once per tree after bundling (database creation, schema load) |
| `env` | environment for setup and runs (database credentials, `RAILS_ENV`) |
| `gemfile`, `lock` | another Gemfile of the suite (e.g. `gemfiles/rails_8_1.gemfile`), another lock to start from |
| `shims` | shell commands or `{patch: file}` applied to both checkouts before bundling (config copies, relaxed gemspec bounds) |
| `bumps` | gems replaced or added on both trees, `{name: "version"}` or `{name: {git: …, ref: …}}` (e.g. an unreleased rspec-rails fix) |
| `single` | how to run one test alone, with `{id}` (default `rspec {id}`, or the test command with `-n /^Class#test$/` in `TESTOPTS`) |

Each suite gets one checkout per tree (`WORK/suites/NAME/{base,cand}`), so a schema dump or a generated file on
one tree never leaks into the other. The base lock starts from the suite's own lock if it has one, the candidate
lock from the base lock, so the bundles differ only in Rails and what Rails itself requires. Shims and bumps are
inputs like the refs: they apply to both trees, they are part of the cache key, and the summary lists them.

## What it does

Per suite: prepare both trees (checkout, shims, lock, bundle, setup), then run base and candidate under seed A
and again under seed B (`SEED`, `TESTOPTS=--seed=…`, and `SPEC_OPTS=--seed … --format json`, so a suite's own
command needs no seed flag). Each run is cached under `WORK/state/NAME/` with a key over the suite, its commit,
that tree's Rails SHA, the lock digest, `ruby -v`, the seed and the explicit inputs. A crashed round resumes at the
first missing run; when only the candidate moves (the next beta), the base runs are reused. A run killed by
`timeout` (manifest key, default 3600 s) counts as not loaded.

Every test that fails in a candidate run gets one class:

| Class | Rule |
| --- | --- |
| `confirmed` | fails 2/2 on the candidate, passes 2/2 on base |
| `flaky-candidate` | fails 1/2 on the candidate, 0/2 on base, and fails at least once in 5 runs alone; the counts for both trees are in `detail` |
| `order-dependent` | fails 1/2 on the candidate, 0/2 on base, and passes all 5 runs alone |
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

| Manifest | Round | Smoke-tested suite |
| --- | --- | --- |
| [`proof-e64f5a4258.yml`](../../bench/upstream/readiness/proof-e64f5a4258.yml) | the proof round below | all four |
| [`round-app-suites.yml`](../../bench/upstream/readiness/round-app-suites.yml) | [app-suites](app-suites.md): Redmine, Lobsters, Solidus (core, api), Mastodon, Sure, Writebook | `lobsters-rspec-rails-main`: 927 examples; L2 3 `confirmed` as `known:L2`, as in the record |
| [`round-ecosystem-1.yml`](../../bench/upstream/readiness/round-ecosystem-1.yml) | [ecosystem-tests](ecosystem-tests.md), 24 gems | `pundit`: 184 examples, 0 failures ×4, as in the record |
| [`round-ecosystem-2.yml`](../../bench/upstream/readiness/round-ecosystem-2.yml) | [ecosystem round 2](ecosystem-round-2.md), 26 gems | `bullet`: 286 examples, 0 failures ×4, as in the record |

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
* **No service management.** Databases are started by hand; two suites that use the same database name must not
  run in parallel (`--jobs`). Prepare failures are cached like runs; rerun them with `--fresh NAME`.
* **Known findings are regexes.** A new failure with the same signature as a known one in the same suite reads
  as known; most entries outside the proof round are still unchecked against a real run.
* **Round manifests are smoke-tested, not rerun.** Three suites ran (above); the others come from the rounds'
  notes and may need a setup fix on their first run.
* **One bundle per suite** under `WORK/bundle/NAME`. A shared gem directory let one suite's RubyGems plugins
  (rdoc 8.1 loading json 3.1) break another suite's boot.
