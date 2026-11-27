# ruby/rubygems issue: autoswitch to Bundler < 4.0.12 fails on Ruby 4.1 (SEP1)

**Draft only. Nothing is posted until Thomas approves the exact text.** Issue only, no PR. Queue item
[SEP1](../../bench/upstream/pr-queue/items/SEP1.md); background in
[ruby41-gem-differential.md, SEP1](../upstream/ruby41-gem-differential.md#sep1-pathnameseparator_pat). Evidence:
[`evidence/separator-pat/rubygems-issue/`](../../bench/upstream/gem-differential/evidence/separator-pat/rubygems-issue).
Checked 2026-11-27 on Ruby master `0d399335b7` (Bundler 4.1.1), RubyGems/Bundler master `fc37d0f953` (4.2.0.dev)
installed on that Ruby, Ruby 4.1.0-preview1 and Ruby 4.0.9 as the control.

## Issue title

On Ruby 4.1, bundle install switches to a locked Bundler older than 4.0.12 and fails with uninitialized constant Pathname::SEPARATOR_PAT

## Issue body

---

On Ruby 4.1.0-preview1 and current master, `bundle install` fails when `BUNDLED WITH` is older than 4.0.12 and the lockfile has a gem from a path or git source, such as the gem itself in a repository whose Gemfile says `gemspec`:

```
Bundler 4.1.1 is running, but your lockfile was generated with 2.7.2. Installing Bundler 2.7.2 and restarting using that version.
NameError: uninitialized constant Pathname::SEPARATOR_PAT
  .../gems/bundler-2.7.2/lib/bundler/source/path.rb:227:in 'block in Bundler::Source::Path#generate_bin'
```

Ruby 4.1 removes `Pathname::SEPARATOR_PAT` (ruby/ruby@4e243c709e, ruby/ruby@a5996718f3) and Bundler 4.0.12 stopped using it (#9529), but by default Bundler still switches to the locked version, which [reads it](https://github.com/ruby/rubygems/blob/b463ced1459e03bf871116fff3a09c5d287806c2/bundler/lib/bundler/source/path.rb#L227). `BUNDLED WITH` 2.4.2, 2.4.22, 2.5.23, 2.6.9, 2.7.2, 4.0.7 and 4.0.11 all fail this way on master, with a path and with a git source, and install on Ruby 4.0; 4.0.12 installs on both. Bundler from this repository's master switches the same way.

To reproduce on Ruby master:

```sh
mkdir foo && cd foo && mkdir lib && echo 'module Foo; end' > lib/foo.rb
cat > foo.gemspec <<'G'
Gem::Specification.new do |s|
  s.name = "foo"; s.version = "0.1.0"; s.summary = "foo"; s.authors = ["x"]; s.files = ["lib/foo.rb"]
end
G
printf 'source "https://rubygems.org"\ngemspec\n' > Gemfile
bundle lock
sed -i '/BUNDLED WITH/{n;s/.*/   2.7.2/}' Gemfile.lock
bundle install
```

Many repositories will hit this when they first try Ruby 4.1. The committed lockfiles of [parallel](https://github.com/grosser/parallel/blob/a8de399448a6d5029deb809b1b4890b5e38c18c1/Gemfile.lock#L123), [ruby-progressbar](https://github.com/jfelchner/ruby-progressbar/blob/bafa278bfb14353282c2ae3207060f69615db7ae/gemfiles/v2.4/Gemfile.lock#L46), [rails-dom-testing](https://github.com/rails/rails-dom-testing/blob/153dbecf2601a71639a6a37ad8fd5da9d79e5ced/Gemfile.lock#L107), [marcel](https://github.com/rails/marcel/blob/731f57062adad157a6a67f724a6f724ef77339d5/Gemfile.lock#L110), [factory_bot](https://github.com/thoughtbot/factory_bot/blob/6310dd3550608d19abcb7f1b05ab5ceef1259d9e/Gemfile.lock#L190), [devise](https://github.com/heartcombo/devise/blob/05811fb8366edd08874111d0f6fb44543e1c91ef/Gemfile.lock#L314) and [fastlane](https://github.com/fastlane/fastlane/blob/c66165c23eee1c6471bc617bb3c3513bb36f6132/Gemfile.lock#L406) fail this way on master today, as do apps with git gems such as [Gumroad](https://github.com/antiwork/gumroad/blob/2606df2deca070fe5d78c007351b22aef96903ec/Gemfile.lock#L1289) and [the Archive of Our Own](https://github.com/otwcode/otwarchive/blob/452391b648f2fb06b55c36133812449747634504/Gemfile.lock#L816) once their Ruby version is raised. svenfuchs/rails-i18n#1173 and ruby/ruby-bench#510 bumped `BUNDLED WITH` to get ruby-head CI past it, and ruby/rbs#2952 set `version` to `system` there.

`BUNDLE_VERSION=system bundle install` (the `version` setting) avoids the switch, and `bundle _4.1.1_ update --bundler` updates the lockfile. Plain `bundle update --bundler` can fail too once the old Bundler is installed, since it restarts with that version.

One way out would be not to switch to a Bundler that can't run on the current Ruby. For context, ruby/ruby#16909 keeps the constant removed, and the autoswitch change is planned for Bundler 4.2 there and in #9236.

---

## Follow-up comment for ruby/ruby#16909

Dropped (2026-11-27, after Astra's interim finding): hsbt replied at
https://github.com/ruby/ruby/pull/16909#issuecomment-7228959325 (22:01 UTC) that the earlier comment was wrong, the
autoswitch change is planned for Bundler 4.2, not 4.1, the usual path is updating `BUNDLED WITH` to a recent 4.0.x
on Ruby 4.0 before moving to 4.1, the constant stays removed, and he'd like to end the discussion there. No further
comment on #16909.

**Recommendation: hold the issue.** The rubygems maintainer has now said in public that the autoswitch changes in
4.2 and that projects should update `BUNDLED WITH` before moving to Ruby 4.1. A new issue would ask him the same
question again right after he closed the discussion. If Thomas still wants it, the text above is the corrected
draft; its remaining value is the evidence that Bundler 4.1 users on Ruby 4.1 get a crash with an error report
template instead of advice to update the lockfile.

## Evidence and notes (internal)

Raw outputs, scripts and samples are in
[`evidence/separator-pat/rubygems-issue/`](../../bench/upstream/gem-differential/evidence/separator-pat/rubygems-issue).

* **Switch and versions** (`autoswitch_matrix.sh`, `matrix-plain-2026-11-27.txt`): fresh `GEM_HOME` per run, lockfile
  written by the script, `BUNDLED WITH` 2.4.2, 2.4.22, 2.5.23, 2.6.9, 2.7.2, 4.0.7, 4.0.11, 4.0.12, PATH (`gemspec`)
  and GIT (`file://` repo). Master `0d399335b7`: every version below 4.0.12 prints "Installing Bundler X and
  restarting" and raises `NameError: uninitialized constant Pathname::SEPARATOR_PAT`, both source kinds; 4.0.12
  switches and completes. Ruby 4.0.9 (Bundler 4.0.20): all 16 switch and complete.
* **RubyGems/Bundler master** `fc37d0f953` (4.2.0.dev; `setup.rb` into a separate prefix of the same Ruby):
  identical outcome (`matrix-rubygems-main-2026-11-27.txt`). `lib/bundler/settings.rb:91` still defaults
  `BUNDLE_VERSION` to `lockfile`; `SelfManager` is unchanged in shape. Ruby 4.1.0-preview1 (`2d08b5f42f`, Bundler
  4.1.0.beta2): 2.6.9, 2.7.2 and 4.0.11 switch and raise, PATH and GIT; 4.0.12 completes
  (`matrix-preview1-2026-11-27.txt`).
* **Workarounds** (`workarounds-*.txt`, PATH and GIT, 2.6.9 and 4.0.11): `BUNDLE_VERSION=system`,
  `bundle config set --local version system` and `BUNDLER_VERSION=<running>` all skip the switch and complete, also
  after a failed install. `bundle _4.1.1_ update --bundler` then `bundle install` completes in every case.
  Plain `bundle update --bundler` completes on a fresh `GEM_HOME`, but after a failed `bundle install` has put the
  old Bundler into `GEM_HOME` it restarts with 2.6.9 and raises (4.0.11 got through: it restarts with 4.0.11,
  which updates to 4.1.1 before installing). `BUNDLE_FROZEN=true` fails like plain install. With `version system`
  a 2.x lock is rewritten to `BUNDLED WITH 4.1.1`; a 4.0.11 lock is left as is. Not in the issue text.
* **Issue repro as written** (`issue-repro.sh`, run with `run-issue-repro.sh`, `issue-repro-2026-11-27.txt`):
  Ruby 4.0.9 switches to 2.7.2 and completes; master and master with RubyGems master raise at
  `bundler-2.7.2/lib/bundler/source/path.rb:227`. The permalink is the `bundler-v2.7.2` tag commit
  `b463ced145`, line 227 `next path unless /\A#{Pathname::SEPARATOR_PAT}/o.match?(path)`.
* **Gem repositories** (`autoswitch_repo.sh`, `repos-gems-2026-11-27.txt`): each default branch at its current
  SHA, committed lock unchanged, fresh `GEM_HOME`/`BUNDLE_PATH`. On master all 11 raise the NameError after the
  switch: parallel (BUNDLED WITH 4.0.7), ruby-progressbar (2.4.2), rails-dom-testing (2.4.14), marcel (4.0.6),
  byebug (2.7.2), factory_bot (2.7.2), xpath (2.6.8), factory_bot_rails (2.7.2), devise (4.0.3), pry-byebug
  (2.6.6), fastlane (2.7.2). On 4.0.9 all 11 complete. Downloads (rubygems.org, 2026-11-27): parallel 866M,
  ruby-progressbar 785M, rails-dom-testing 714M, marcel 514M, byebug 494M, factory_bot 371M, xpath 354M,
  factory_bot_rails 309M, devise 308M, pry-byebug 296M, fastlane 223M. Latest releases: parallel 2.3.0
  (2026-10-03), ruby-progressbar 1.13.0 (2023-03-04, repo pushed 2026-01-08), rails-dom-testing 2.3.0
  (2025-05-20), marcel 2.1.0 (2026-08-22), byebug 13.0.0 (2026-01-15), factory_bot 6.7.0 (2026-11-26), devise
  5.0.4 (2026-05-08), fastlane 2.242.0 (2026-11-16). Named in the issue: the seven with the most reach and a
  current release or push; byebug, xpath (last release 2018), factory_bot_rails and pry-byebug left out for length.
* **Breadth among the 400 most-downloaded gems** (`scan_locks.rb`, `default-branch-locks-2026-11-27.json`): 344
  distinct GitHub repositories; 46 non-archived ones commit a `Gemfile.lock` with a PATH or GIT section on their
  default branch, and 29 of those lock Bundler older than 4.0.12. Not in the issue (some lock 2.2/2.3, which
  have other problems on Ruby 4.0).
* **Apps** (`repos-apps-2026-11-27.txt`, `RUBY_UPGRADE=1`: `.ruby-version` set to the running Ruby and the Gemfile
  `ruby` line dropped, as an app moving to that Ruby would). Gumroad (antiwork/gumroad, 10.2k stars, BUNDLED WITH
  2.5.10, 2 GIT), otwarchive (2.5k stars, 2.6.9, 4 GIT) and sharetribe (2.4k stars, 4.0.6, 4 GIT) raise the
  NameError on master; all three complete on 4.0.9 with the same edit.
  **forem dropped:** its main (BUNDLED WITH 2.4.17) switches on master but fails earlier in resolution, because
  cld3 caps Ruby below 3.5; it can't move to 4.1 regardless. Sharetribe left out of the issue for length.
* **Code search** (`codesearch_sample.rb`, `codesearch-sample-2026-11-27.json`): GitHub reports about 35,100
  indexed `Gemfile.lock` files with `remote: .` and about 29,600 with `revision:`. In the first 200 best-match
  results per query, 189 PATH and 179 GIT locks are below 4.0.12, and 61 of 72 and 32 of 41 among repositories
  pushed in the last six months. Best-match order is not a random sample and the index includes stale repos, so
  no estimate goes into the issue.
* **Existing reports.** ruby/rubygems: no issue about the autoswitch reaching `SEPARATOR_PAT` (searched
  `SEPARATOR_PAT`, `autoswitch`, `auto-switch`, `BUNDLED WITH` since 2026-04, `restarting using that version`,
  `Pathname` since 2026-04). Related: #9529 (the fix in 4.0.12), #10072 (4.1.0 crash with a plugin after the switch
  to 4.0.17; hsbt: move the lockfile to 4.0.25), #9236 (merge plan, phases 4+ open), our #10017 (Bundler 4.0.x
  on RubyGems 4.1 with a `---` config, fixed by #10047). Downstream, ruby/rbs#2952 set `version system` on
  ruby-head CI and these bumped `BUNDLED WITH`: svenfuchs/rails-i18n#1173, ruby/ruby-bench#510, basecamp/basecamp-sdk#335,
  pocke/rbs_rails#401; still open: Shopify/erb_lint#465 and MadBomber/ragdoll#79 ("Gemfile.lock can't be
  installed on Ruby 4.1", 2.7.2). ruby/ruby#16909: hsbt replied 2026-11-27 22:01 UTC (above); autoswitch change planned for Bundler 4.2.
* **Changed versus earlier findings:** faker and responders fail only at their release tags; their default
  branches lock 4.0.15 and 4.0.16 and are dropped. forem is not a valid example (above). 2.7.2, the last 2.x, fails
  too. RubyGems/Bundler master is now 4.2.0.dev and still switches. Plain `bundle update --bundler` fails only
  once the old Bundler is installed, not always. hsbt's reply on #16909 (Bundler 4.2, not 4.1) ends the open
  question there. ruby-progressbar's root `Gemfile.lock` is a symlink to `gemfiles/v2.4/Gemfile.lock` (Astra).
