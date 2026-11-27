# Ruby 4.1 gem differential: the most-downloaded gems' own suites on 4.0.10 and master (2026-11-27)

Ruby 4.1 ships around 2026-12-25. The [app differential](ruby41-differential-409.md) runs census apps; this round runs
the test suites of the most-downloaded gems themselves, each at its latest release tag, on Ruby 4.0.10 and on pinned
Ruby master with the same checkout, the same `Gemfile.lock` and the same environment, and compares outcomes per test.
Harness: [`script/gem-differential`](../../script/gem-differential) with the recorder
[`gemrec.rb`](../../bench/upstream/gem-differential/gemrec.rb) (Minitest, RSpec and test-unit, in every process of
a run). Nothing was posted, filed or pushed outside Lowrail.

**State: in progress.** The matrix is still running; this page is updated as it finishes.

## Pins and method

* Ruby 4.0.10 from tag `v4.0.10` (`a704b7cd95`) and Ruby master
  [`a1a9f45587`](https://github.com/ruby/ruby/commit/a1a9f45587) (2026-11-27 12:53 UTC), both release builds from
  `script/ruby-differential build` (`--enable-zjit --enable-yjit`, same GCC and rustc), interpreter only.
* Gems: the 400 most-downloaded on rubygems.org (packages.ecosyste.ms, 2026-11-27), the first 150 that are not skipped
  ([`gems.json`](../../bench/upstream/gem-differential/gems.json): rank, downloads, dependents, stars, tag, SHA,
  skip reason). Each runs at the tag of its latest release; when the tag's gemspec has another version (aws-sdk-ruby's
  v1 tags) or there is no tag (aws-sdk-ruby, ruby-progressbar), at the default branch's HEAD, recorded as such.
* The 4.0.10 run locks the bundle (committed lock if it installs, otherwise fresh); master installs that exact lock
  (`lock_identical` in each result). Same `TZ=UTC`, `LANG=C.UTF-8`, seed 41231, Redis, memcached and PostgreSQL.
  Outcomes per test: `bench/upstream/gem-differential/runs/LABEL/GEM.json.gz`; comparison:
  [`compare-v4.0.10-master-a1a9f45587.json`](../../bench/upstream/gem-differential/runs/compare-v4.0.10-master-a1a9f45587.json).

Skipped (89 before reaching 150): default and bundled gems whose suites run in ruby/ruby CI (bundler, rake, json,
minitest, …), Rails components (covered by Rails CI and the app differential), meta and data gems, archived repos
(thread_safe, simplecov-html, sass, htmlentities, sassc, thin, nap, sass-listen, sassc-rails, turbolinks), macOS-only
gems (rb-fsevent, fastlane, cocoapods, xcodeproj, …), suites needing servers the orb lacks (mysql2, elasticsearch),
Bazel monorepos (google-protobuf, grpc, selenium-webdriver), and long-unmaintained gems (arel, erubis, orm_adapter,
sass-rails, old Faraday adapters). Every skip and its reason is in `gems.json`.

## Findings

| Finding | Reach | Cause (first bad commit) | Class | Owner, state |
| --- | --- | --- | --- | --- |
| SEP1: `bundle install` fails with `NameError: uninitialized constant Pathname::SEPARATOR_PAT` | every lockfile from Bundler < 4.0.12 with a PATH or GIT section; here parallel 2.3.0 (866M downloads), ruby-progressbar 1.13.0 (784M), rails-dom-testing 2.3.0 (714M) | [`4e243c709e`](https://github.com/ruby/ruby/commit/4e243c709e) made it private, `a5996718f3` removed it | deliberate Ruby change that breaks old Bundlers | decision for Thomas (below) |
| Active Support 8.0.x: `JSON.generate(..., quirks_mode: true)` raises `ArgumentError: unknown keyword` (globalid: 34 tests) | every Rails 8.0 app on 4.1 whose lock does not pin json 2.x | json 3.0.0 makes unknown options raise; master ships json 3.2.0 (`3ade997abe`) | intended (json NEWS) | Rails: fixed on 7-2-stable (released 7.2.4) and 8-0-stable ([`2786de26c6`](https://github.com/rails/rails/commit/2786de26c6), 2026-08-12), not in 8.0.5.2; record only |
| eventmachine 1.2.7 does not compile (`Data_Wrap_Struct` removed); websocket-driver's suite cannot install | 339M downloads, 1,158 reverse dependencies | [`a26f528b3b`](https://github.com/ruby/ruby/commit/a26f528b3b) (Feature #21768) | intended (NEWS, C API) | fixed on eventmachine master (#1027), unreleased; release asked in eventmachine/eventmachine#1032 (open); record only |
| pry: `syntax_checking_spec.rb[1:15]` fails on master with seed 11703, deterministic | test only | error_highlight now uses `Ruby::Prism`, so top-level `Prism` is no longer loaded by a NameError message; the spec helper counts errors with `Prism` only when it happens to be loaded | intended (Bug #22379); order-dependent spec | pry's ruby-head CI is green in its order; record only |

Checked and not a Ruby difference: excon's master run stopped at `Errno::EADDRINUSE` on its own test server port 9292
(free afterwards; rerun queued), diff-lcs and others fail the same tests on both Rubies.

## SEP1: Pathname::SEPARATOR_PAT

Bundler before 4.0.12 evaluates `/\A#{Pathname::SEPARATOR_PAT}/o` in `Bundler::Source::Path#generate_bin`, which runs
for every gem from a path or git source, including the gem of a Gemfile with `gemspec`. Bundler 4.1.1 switches to the
lockfile's `BUNDLED WITH` version ("Installing Bundler 2.4.2 and restarting using that version"), so such a lockfile
fails on master. Repros: [`separator_pat_gemspec.sh`](../../bench/upstream/gem-differential/repros/separator_pat_gemspec.sh)
and [`separator_pat_git.sh`](../../bench/upstream/gem-differential/repros/separator_pat_git.sh); results for
BUNDLED WITH 2.4.2, 2.6.9, 4.0.7, 4.0.11 and 4.0.12 on 4.0.10, master and master with the fix:
[`verify-2026-11-27.txt`](../../bench/upstream/gem-differential/evidence/separator-pat/verify-2026-11-27.txt).

* da3b7d5ee3 (2025-12-06, in 4.0.10) meant to make `SEPARATOR_LIST` and `SEPARATOR_PAT` private but wrote
  `private_constant :SEPARATOR_LIST, :SEPARATOR_LIST`. ruby/rubygems#9529 (nobu, merged 2026-05-07, released in
  Bundler 4.0.12 on 2026-05-20) switched Bundler to `Pathname#absolute?` because "bundler will break by fixing the
  typo". 4e243c709e (2026-05-01) fixed the typo; a5996718f3 (2026-05-07) removed the constant. That older lockfiles
  reinstall the older Bundler is not discussed in either place; no Redmine ticket or rubygems issue covers it.
* Reach: in this differential every committed lock with Bundler < 4.0.12 and a PATH section fails, and no other lock
  does. Apps with git gems have the same shape, e.g. forem's main lock (BUNDLED WITH 2.4.17, two GIT/PATH sections).
  The fix per repository is `bundle update --bundler`.
* Scope: lockfiles with only rubygems.org gems still install on master after Bundler switches to 2.4.2, 2.6.9 or
  4.0.11 ([`separator_pat_rubygems_only.sh`](../../bench/upstream/gem-differential/repros/separator_pat_rubygems_only.sh)).
  Master tip `274cfe719a` changes none of the files involved since `a1a9f45587`.
* Redmine draft (the coordinator's recommendation, pending Thomas; not posted):
  [`redmine.md`](../../bench/upstream/gem-differential/evidence/separator-pat/redmine.md), with its repro run as written.
* Candidate: queue item [SEP1](../../bench/upstream/pr-queue/items/SEP1.md), a four-line restore with
  `deprecate_constant` and one test, [patch](../../bench/upstream/gem-differential/evidence/separator-pat), on master
  `a1a9f45587`: the repros pass, `make test-all TESTS=pathname` 298 tests 0 failures, the new test errors without the
  restore, and no warning prints without `-W:deprecated`.

### Für Thomas (Erklärung zu SEP1)

**Was kaputt geht.** Bundler vor 4.0.12 benutzt beim Installieren eines Gems aus einem Pfad oder Git-Repo die
Konstante `Pathname::SEPARATOR_PAT`. Ruby master hat sie im Mai privat gemacht und dann entfernt. Weil Bundler
automatisch auf die Version aus `BUNDLED WITH` im Lockfile umschaltet, bricht `bundle install` auf Ruby 4.1 ab,
sobald das Lockfile von einem älteren Bundler stammt und eine PATH- oder GIT-Quelle hat. Das ist fast jedes Gem-Repo
mit eingechecktem Lockfile (das Gemfile sagt `gemspec`) und jede App mit Git-Gems.

```
# Gemfile: source "https://rubygems.org"; gemspec      Gemfile.lock: BUNDLED WITH 2.6.9
$ bundle install          # Ruby 4.0: ok
$ bundle install          # Ruby master: NameError: uninitialized constant Pathname::SEPARATOR_PAT
```

**Was die Änderung macht.** Die Konstante kommt mit demselben Wert wie in 4.0 zurück und wird mit
`deprecate_constant` markiert: vier Zeilen in `pathname_builtin.rb` und ein Test.

**Warum sie sicher ist.** Es kommt nur ein Name zurück, den 4.0 schon hatte; sonst ändert sich nichts, und eine
Warnung gibt es nur mit `-W:deprecated`.

**Zu entscheiden.** (a) Diesen PR auf ruby/ruby, (b) ein Redmine-Bug mit dem Repro, ohne Patch, oder (c) nichts
upstream: Die Änderung war gewollt, Bundler 4.0.12 hat den Fix, und jedes betroffene Repo kann `bundle update
--bundler` ausführen. Empfehlung: (b), weil nobu den Bruch von Bundler selbst kannte und die Wahl zwischen
Rückkehr der Konstante und einer Bundler-seitigen Lösung (z. B. beim Umschalten auf eine alte Version) bei den
Maintainern liegt; das Repro und der Patch sind fertig, falls sie den Patch wollen.
