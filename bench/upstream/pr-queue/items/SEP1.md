---
id: SEP1
repo: ruby/ruby
fork: thomasklemm/ruby
kind: restore
area: pathname_builtin.rb (Pathname::SEPARATOR_PAT)
reviewer: "nobu (author of 4e243c709e and a5996718f3, and of ruby/rubygems#9529)"
branch: thomasklemm/pathname-separator-pat
head: "8961f4c5410f5459487af7fc110858100c0cf26d"
base: master
built_on: "a1a9f45587"
introduced_by: "4e243c709e"
tracker: [ruby/rubygems#9529]
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/gem-differential/evidence/separator-pat, bench/upstream/gem-differential/repros/separator_pat_gemspec.sh, bench/upstream/gem-differential/repros/separator_pat_git.sh, bench/upstream/gem-differential/runs/compare-v4.0.10-master-a1a9f45587.json]
impact: "Ruby 4.1: `bundle install` fails with NameError (Pathname::SEPARATOR_PAT) for every lockfile written by Bundler before 4.0.12 (all of 2.x and 4.0.0-4.0.11) that has a PATH or GIT section, because Bundler switches to the BUNDLED WITH version and that version reads the constant removed on master. PATH covers every gem repository whose Gemfile says `gemspec` and commits its lock; GIT covers apps with git gems. In the 150-gem differential, parallel 2.3.0 (BUNDLED WITH 4.0.7), ruby-progressbar 1.13.0 (2.4.2) and rails-dom-testing 2.3.0 (2.4.14) cannot install their own bundle on master, and they are exactly the committed locks with an old Bundler and a PATH section; forem's main lock (2.4.17, two GIT/PATH sections) has the same shape. Workaround for each repo: `bundle update --bundler`."
rank: 1
risky: false
state: built
note: "2026-11-27 (coordinator): target is now a Redmine bug report offering the patch, not a PR (option b, pending Thomas). Text: bench/upstream/gem-differential/evidence/separator-pat/redmine.md; its repro run as written: redmine-repro.sh, output redmine-repro-2026-11-27.txt (4.0.10 installs, master a1a9f45587 raises at bundler-2.6.9 path.rb:218). Scope control: lockfiles with only rubygems.org gems and BUNDLED WITH 2.4.2, 2.6.9 or 4.0.11 install on master (repros/separator_pat_rubygems_only.sh). Master tip 274cfe719a changes none of pathname_builtin.rb, pathname.c, lib/bundler/source/path.rb, self_manager.rb since a1a9f45587. Passes on the text record its Lowrail commit as head. Earlier: not opened, ruby/ruby needs Thomas to name it (DECISIONS). Alternatives for Thomas: (a) this PR, (b) a Redmine bug report with the repro and no patch, (c) nothing upstream (the change is deliberate; the fix already shipped in Bundler 4.0.12 and each affected repo can run `bundle update --bundler`). Bisect: 0f618b87d5 (parent) resolves the constant, 4e243c709e (nobu, 2026-05-01, 'pathname: Remove unneeded constant') fixes the private_constant typo of da3b7d5ee3 and makes it private, a5996718f3 (2026-05-07) removes it; both after v4.0.10. nobu's ruby/rubygems#9529 body says 'bundler will break by fixing the typo in pathname', so the breakage of Bundler itself was known; that old lockfiles reinstall old Bundlers is not mentioned there. Searched: Redmine (SEPARATOR_PAT, Pathname bundler), ruby/rubygems issues since 2026-05 (SEPARATOR_PAT, uninitialized constant Pathname): nothing besides #9529. Verified on a1a9f45587 with the patch built in full: gemspec repro passes for BUNDLED WITH 2.4.2, 4.0.7, 4.0.11, 4.0.12 and git repro for 2.6.9 (all fail on unpatched master except 4.0.12); `make test-all TESTS=pathname` 298 tests 0 failures; the new test errors on unpatched master and passes with it; no warning without -W:deprecated."
passes: []
---

# Keep Pathname::SEPARATOR_PAT as a deprecated constant

Bundler before 4.0.12 reads `Pathname::SEPARATOR_PAT` whenever it installs a gem from a path or git source, which includes the gem itself in any repository whose Gemfile says `gemspec`. Bundler switches to the version in the lockfile's `BUNDLED WITH`, so on master `bundle install` with a lockfile from Bundler 2.x or 4.0.0 to 4.0.11 fails:

```
NameError: uninitialized constant Pathname::SEPARATOR_PAT
```

The constant became private in 4e243c709e and was removed in a5996718f3, after Bundler stopped using it in ruby/rubygems#9529.

This defines it again with its 4.0 value and deprecates it, so these lockfiles keep installing and remaining readers warn under `-W:deprecated`.
