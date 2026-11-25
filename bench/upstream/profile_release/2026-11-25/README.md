# lowrail-profile 0.1.0.rc1: corpus proof from the built gem (2026-11-25)

M4 of [docs/profile-release-plan.md](../../../../docs/profile-release-plan.md): the install path a stranger takes,
on fresh copies of Campfire, Lobsters and CodeTriage and on a generated Blog at the support floor (Ruby 3.3.14,
Rails 7.2.4; CodeTriage locks Rails 8.1.4), plus one real GitHub Actions run of the README's CI job and Campfire's
suite on macOS. Summary in [docs/profile.md](../../../../docs/profile.md#release-candidate-proof-from-the-built-gem-2026-11-25).

## Method

* Gem: `gem build lowrail-profile.gemspec` from `gem/` at lowrail main `fd36835b`, `lowrail-profile-0.1.0.rc1.gem`
  (sha256 `97aca67ac8bab61206d468c6d24074271e621fc692def4b6432f97df5f2baa3e`, 14 files, no lowering code),
  installed with `gem install --local` into the app Ruby's gem home (`*/installed-from.txt`). Each copy's
  `Gemfile.lowrail` is its Gemfile plus only `gem "lowrail-profile", "0.1.0.rc1", group: [:development, :test],
  require: false`; no `RUBYLIB`, no `RUBYOPT`, and an empty `XDG_CACHE_HOME`, so the first capture built the counter.
* Apps: `script/corpus APP rc-APP` at their corpus pins; the Blog `script/corpus real-blog` with
  `LOWRAIL_CORPUS_RUBY=3.3.14 LOWRAIL_RAILS=7.2.4`, whose generator writes Rails 8's `params.expect`: rewritten for 7.2
  before any run ([blog-floor.patch](blog-floor.patch)), without which 3 tests error without the gem too.
* [scripts/all.sh](scripts/all.sh) runs the apps one after another (8-CPU orb, nothing else running), each through
  [scripts/proof.sh](scripts/proof.sh) with `SEED=1234` and `RUBYOPT=-r scripts/dump_features.rb` (every process
  writes `$LOADED_FEATURES`): `plain` and `plain2` (own Gemfile), `off` (Gemfile.lowrail, not run), then `profiled`,
  `base2` and `head` (three invocations of `bundle exec lowrail-profile --out DIR -- COMMAND` on the same code),
  `planted` (`20.times { ERB::Util.html_escape("a<b") }` added at the top of one action, reverted after) and, for the
  Blog, `seed99` (`--seed 99`). [scripts/compare.sh](scripts/compare.sh) runs `compare profiled HEAD --aa base2`.
* [scripts/controls.sh](scripts/controls.sh): `off-env`, the off setup as `bundle exec env COMMAND`. lowrail-profile
  starts its command as a new process under `bundle exec`'s `RUBYOPT=-rbundler/setup`, whereas `bundle exec bin/rails`
  and `bundle exec rspec` load the script inside Bundler's own process; that alone moves Bundler's early `pathname`
  (Ruby 3.3) or `etc.so` (Ruby 4.0) ahead of `bundled_gems.rb`. So the load-order baseline for the captures is
  `off-env`, which runs no Lowrail code.
* Tree: a sha256 of every file `git ls-files -co --exclude-standard` lists, without `log/`, `tmp/` and SQLite
  databases (the suite's own writes), before and after each capture (`tree-*.txt`).
* Outcomes: [scripts/outcomes.rb](scripts/outcomes.rb), Minitest's verbose lines without times, RSpec's documentation
  lines with timestamps, `token` and `short_id` masked; sorted. Load order: [scripts/features_cmp.rb](scripts/features_cmp.rb)
  (`*/features.txt`), outside Lowrail, Bundler and RubyGems. Overhead: [scripts/overhead.rb](scripts/overhead.rb), the
  suites' own "Finished in" ([overhead.txt](overhead.txt)). Ledger: [scripts/ledger_check.rb](scripts/ledger_check.rb).
* Kept per capture: `capture.json`, `command.txt`, `report.md`, `report.json.gz`; per step the outcomes and the log's
  last 40 lines. Raw runs, feature dumps and the counter build were removed (1.3 GB).

## Results

| App, suite | Ruby, Rails | Tests | Outcomes (plain = plain2 = off = every capture run) | Load order | A/A `compare --aa` (closest row) | Planted | Tree |
| --- | --- | ---: | --- | --- | --- | --- | --- |
| Blog (generated), `bin/rails test -v` | 3.3.14, 7.2.4 | 21 | identical: 21 pass | every capture process = `off-env`; plain = plain2 = off | 0; 2,017 lines, 3 actions; `CommentsController#create` −15.0 against 22.0 (68%) | 1: `output_safety.rb:228` +1.67 against 1.0 (the action runs once per process) | unchanged |
| CodeTriage, `bin/rails test --verbose` | 4.0.7, 8.1.4 | 222 | identical for the 217 that print a line; 0 failures everywhere | every capture process = `off-env` without yard's 27 handler and code-object files (yard loads them by walking `Module#constants`) | 0; 7,789 lines, 18 actions; a kramdown job line −1.00 against 1.00 (100%, not beyond) | 1: `PagesController#index` +39.35 against 20.0, `erb/util.rb:15` +5.01, `output_safety.rb:242` +5.00 against 1.0 | unchanged |
| Campfire, `bin/rails test -v` (parallel workers) | 4.0.7, main `e3d5c569` | 634 | identical: 632 pass, 2 skip | every process of every setup identical to a plain one (12 plain2, 12 off, 96 capture processes) | 0; 7,573 lines, 27 actions; `Users::ProfilesController#show` +24.75 against 58.0 (43%) | 1: `RoomsController#show` +42.05 against 24.56, `output_safety.rb:243` +1.68, `erb/util.rb:17` +1.65 against 1.0 | unchanged |
| Lobsters, `bundle exec rspec --seed 1234 --format documentation` | 4.0.9, 8.1.3.1 | 927 | identical (masked): 0 failures | every capture process = `off-env` = plain2 = off | 0; 6,639 lines, 64 actions; `CommentsController#create` +15.45 against 30.0 (51%) | 1: `HomeController#index` +59.60 against 20.0, `output_safety.rb:242` and `erb/util.rb:15` +2.80 against 1.0 | unchanged |

* Exit 2: the Blog's `--seed 99` capture against the base ("base and head differ in seed"), and CodeTriage's base
  against a Lobsters capture (identity and Ruby differ). Without `--aa` every head pair lists and exits 0.
* Explained first-run differences, as on 2026-11-18: CodeTriage's first plain run printed `git clone` output into
  `ParseDocsTest#test_Can_parse_yard_docs`'s line (216 lines, the test passes) and loaded `enc/trans/single_byte.so`;
  Lobsters' first plain run after `db:prepare` loaded `extras/sponge.rb` and `unicode_normalize` elsewhere (291
  positions). CodeTriage's `off` loads `etc.so` before bootsnap (its Gemfile is a copy): plain2 = off without it.
* Overhead, suite time (mean of plain and plain2 against the three captures): Blog run 1 +9%, run 2 +37%;
  CodeTriage +4%, +35%; Campfire +7%, +87%; Lobsters +6%, +31%. Run 1 counts; run 2 also walks the stack on every
  allocation to find the app line. Wall time for a capture (two runs and the report) is 2.6–3.6× the plain suite.
* Ledger: with the bundled snapshot (2026-11-25), each match checked against its pull request's live diff on GitHub
  (the line's code is a removed or added line of that file): 4 of 4 in the default 30 rows, 52 of 52 at `--top 300`
  (Campfire 23, Lobsters 13, Blog 11, CodeTriage 5; [ledger-check-top300.txt](ledger-check-top300.txt)). Scripted,
  not by hand; the labels read right for the locked versions (Rails main merges after 8.1.3.1 and 7.2.4 say "not
  released yet").

## GitHub Actions ([actions](actions))

A private repository `thomasklemm/lowrail-profile-ci-proof` with the floor Blog and the unpacked built gem as a path
gem (`vendor/lowrail-profile-0.1.0.rc1`, from `gem unpack` and `gem spec --ruby`; the gem is not published), and
[the README's job](actions/profile.yml) verbatim:

* [planted.patch](actions/planted.patch), pull request 1: the job fails, compare exits 1 with one regression,
  `output_safety.rb:228` +1.67 against 1.0
  ([run 45622076753](https://github.com/thomasklemm/lowrail-profile-ci-proof/actions/runs/45622076753)).
* A README-only change, pull request 2: the job passes, 0 regressions
  ([run 45622083685](https://github.com/thomasklemm/lowrail-profile-ci-proof/actions/runs/45622083685)).
* The repository's other workflow (`CI`, from `rails new`: brakeman, rubocop, system tests) fails on both; it is
  the generated app's and not part of the proof.

## macOS ([campfire-macos](campfire-macos))

Campfire at its pin on `macos-latest` (Ruby 4.0.7, arm64, Apple clang;
[run 45622936395](https://github.com/thomasklemm/lowrail-profile-ci-proof/actions/runs/45622936395),
[workflow](campfire-macos/workflow.yml)): the counter built as `lowrail_profile.bundle`, and 634 tests identical
plain, off and profiled (both runs), 0 failures, 1 skip. Two earlier attempts stopped before the suites (libvips
missing, then ffmpeg for video previews: 3 failures and 5 errors without the gem too).
