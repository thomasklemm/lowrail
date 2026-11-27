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
impact: "Ruby 4.1: `bundle install` fails with NameError (Pathname::SEPARATOR_PAT) for every lockfile written by Bundler before 4.0.12 (not an exact interval: e.g. 2.2.34 and 2.6.9 fail only on master, 2.3.0 already fails on 4.0.10) that has a PATH or GIT section, because Bundler switches to the BUNDLED WITH version and that version reads the constant removed on master. PATH covers every gem repository whose Gemfile says `gemspec` and commits its lock; GIT covers apps with git gems. In the 150-gem differential, parallel 2.3.0 (BUNDLED WITH 4.0.7), ruby-progressbar 1.13.0 (2.4.2) and rails-dom-testing 2.3.0 (2.4.14) cannot install their own bundle on master, and they are exactly the committed locks with an old Bundler and a PATH section; forem's main lock (2.4.17, two GIT/PATH sections) has the same shape. Workaround for each repo: `bundle _4.1.1_ update --bundler` (plain `bundle update --bundler` runs the old Bundler and fails)."
rank: 1
risky: false
state: held
note: "maintainers declined the restore twice: ruby/ruby#16909 (Earlopain's identical deprecate_constant restore, closed by hsbt 2026-05-28) and nobu's reply of 2026-11-06 to our comment with branch 6c8385cd3f (https://github.com/ruby/ruby/pull/16909#issuecomment-6687729119). Missed by this round's ownership check although docs/upstream/ruby-4.1-ecosystem.md §2 and contributions.md had it; the earlier 'Searched … nothing besides #9529' below is wrong. No PR, no Redmine. Open question only: nobu's decisive reason (Bundler 4.1 no longer autoswitches) vs. master still switching; see the reply draft in evidence/separator-pat. 2026-11-27: Redmine text 0a0321e20a approved by thermos-sol and Astra; not posted, waits for Thomas (new issue). Before any PR or patch-file publication, narrow the patch commit message (still says all 2.x and a literal /o), per thermos-sol. 2026-11-27 after Astra on a3256a73c6 (changes, 14ad814f20): applied both wording fixes: rubygems-only sources do not use the constant (2.3.0 fails at startup even for those), 'By default' before the version switch, workaround sentence now `bundle _4.1.1_ update --bundler` outside frozen/deployment mode and `BUNDLE_VERSION=system bundle install` (checked here on the exact repro on master). 2026-11-27 after thermos-sol on 37fab2de5e: no version interval in the text (2.2.34 installs on 4.0.10 and patched and fails on master; 2.3.0 already fails on 4.0.10 and patched, DidYouMean::SPELL_CHECKERS; both reproduced here); subject says can fail, older Bundler; 2.6.9 is the example with a permalink to path.rb:218 at the bundler-v2.6.9 tag commit 8a2a14d63d (the reviewer's 2ee5bf9fd3 returns 404 on GitHub; line checked against the installed 2.6.9). 2026-11-27 after thermos-sol findings on ff9e697fa4: text narrowed to Bundler 2.3 to 4.0.11 (2.0.2, 2.1.4, 2.2.33 already fail on 4.0.10 and on the patched build; 2.3.27 installs on both), to path/git gems that list files (s.files = [] never evaluates the regexp), and the workaround is `bundle _4.1.1_ update --bundler` (plain update reruns 2.6.9 and raises, lock unchanged). 2026-11-27 (coordinator): target is now a Redmine bug report offering the patch, not a PR (option b, pending Thomas). Text: bench/upstream/gem-differential/evidence/separator-pat/redmine.md; its repro run as written: redmine-repro.sh, output redmine-repro-2026-11-27.txt (4.0.10 installs, master a1a9f45587 raises at bundler-2.6.9 path.rb:218). Scope control: lockfiles with only rubygems.org gems and BUNDLED WITH 2.4.2, 2.6.9 or 4.0.11 install on master (repros/separator_pat_rubygems_only.sh). Master tip 274cfe719a changes none of pathname_builtin.rb, pathname.c, lib/bundler/source/path.rb, self_manager.rb since a1a9f45587. Passes on the text record its Lowrail commit as head. Earlier: not opened, ruby/ruby needs Thomas to name it (DECISIONS). Alternatives for Thomas: (a) this PR, (b) a Redmine bug report with the repro and no patch, (c) nothing upstream (the change is deliberate; the fix already shipped in Bundler 4.0.12 and each affected repo can run `bundle update --bundler`). Bisect: 0f618b87d5 (parent) resolves the constant, 4e243c709e (nobu, 2026-05-01, 'pathname: Remove unneeded constant') fixes the private_constant typo of da3b7d5ee3 and makes it private, a5996718f3 (2026-05-07) removes it; both after v4.0.10. nobu's ruby/rubygems#9529 body says 'bundler will break by fixing the typo in pathname', so the breakage of Bundler itself was known; that old lockfiles reinstall old Bundlers is not mentioned there. Searched: Redmine (SEPARATOR_PAT, Pathname bundler), ruby/rubygems issues since 2026-05 (SEPARATOR_PAT, uninitialized constant Pathname): nothing besides #9529. Verified on a1a9f45587 with the patch built in full: gemspec repro passes for BUNDLED WITH 2.4.2, 4.0.7, 4.0.11, 4.0.12 and git repro for 2.6.9 (all fail on unpatched master except 4.0.12); `make test-all TESTS=pathname` 298 tests 0 failures; the new test errors on unpatched master and passes with it; no warning without -W:deprecated."
ownership: {date: 2026-11-27, checked: ["ruby/ruby PRs naming SEPARATOR_PAT", "ruby/rubygems#9529", "Lowrail ledger"], hits: ["ruby/ruby#16909 (PR, closed, Earlopain): Deprecate Pathname::SEPARATOR_PAT; hsbt closed 2026-05-28; nobu declined again 2026-11-06 after our comment with 6c8385cd3f"]}
passes:
  - reviewer: astra
    orb: T-01a21d5c-3bca-76ba-9b8d-c6960f5eabf9
    head: "a3256a73c6b5fc9de62256f9f00378d1fe85b6e3"
    date: 2026-11-27
    verdict: changes
    open: >-
      Reviewed the latest Redmine text personally; its example-based scope,
      file-list qualification and released caller link resolve the earlier
      scope/citation findings. Built Ruby 4.0.10 and master
      09cfdea5da, plus the offered patch on a1a9f45587. Exact shell repro twice
      per build: 4.0.10 and restored pass, master raises. All 101 stable Bundlers
      from 2.3.0 through 4.0.12 across path/git/rubygems-only, with/without
      executables, normal/frozen/deployment, install/check/exec; 3,870 cases
      including empty-file and patched controls, no unexplained outcomes.
      2.3.0 already fails on both Rubies with DidYouMean::SPELL_CHECKERS;
      tested versions 2.3.1 through 4.0.11 hit SEPARATOR_PAT when installing nonempty path/git
      gems. Excluded groups and empty file lists succeed. Check/exec do not hit
      the separator lookup. Explicit 4.1.1 update works after the exact failure
      but exits 16 in frozen/deployment mode. Plain update fails after the exact
      repro but succeeds in isolated BUNDLE_PATH fixtures, so it is not a
      universal failure. BUNDLE_VERSION=system bypasses switching, including
      frozen/deployment installs without lock edits. Patch has no demonstrated
      defect: pathname suite 298 tests, 0 failures/errors; new test errors on
      unpatched master; Windows value source-checked, /o, warning settings and
      Ractor shareability verified. Linked PR current and relevant. Evidence:
      bench/upstream/gem-differential/evidence/separator-pat/astra-review-2026-11-27.md
      and astra-2026-11-27.tar.gz in that directory; exact raw log paths and
      sentence-by-sentence review are in the report. No upstream post.
    must_fix:
      - >-
        Replace "Lockfiles with only rubygems.org gems still install" with
        "Rubygems-only sources do not use this constant." Alternatively, prefix
        the existing sentence with "With Bundler 2.6.9,". The current general
        install-success assertion is false for 2.3.0, which fails at startup on
        both Ruby builds; logs/matrix/master-2.3.0-rubygems-noexe-normal.log in
        the archive demonstrates it. Keep the latest title, example and caller link.
      - >-
        Replace "Bundler switches to the version in `BUNDLED WITH`" with "By
        default, Bundler switches to the version in `BUNDLED WITH`". Replace the
        whole sentence beginning "Plain `bundle update --bundler` runs the old
        Bundler" with "Outside frozen or deployment mode, `bundle _4.1.1_ update
        --bundler` updates the lockfile. With Bundler 4.1, `BUNDLE_VERSION=system
        bundle install` avoids the version switch."
  - reviewer: astra
    orb: T-01a21d5c-3bca-76ba-9b8d-c6960f5eabf9
    head: "0a0321e20aa64355a236e68331f8b89306a5c565"
    date: 2026-11-27
    verdict: approve
    open: >-
      Short text-only confirm. Read the complete revised report and verified
      byte-for-byte that its only changes from a3256a73c6 are the exact requested
      wording replacements: the rubygems-only lookup scope, default version
      switching, and the explicit-update/frozen-mode qualification with the
      system-version bypass. Both must-fix findings are resolved. Repro script,
      patch, caller permalink and linked PR are unchanged; the prior executed
      matrix, exact repro, patch tests and link checks remain applicable. No
      rebuild or matrix rerun needed for these prose-only changes. Evidence:
      bench/upstream/gem-differential/evidence/separator-pat/astra-confirm-0a0321e20a.txt
      and the retained astra-2026-11-27.tar.gz in that directory. No upstream post.
    must_fix: []
  - reviewer: thermos-sol
    orb: T-01a21d5a-243c-7558-b622-6f5801179598
    head: "0a0321e20aa64355a236e68331f8b89306a5c565"
    date: 2026-11-27
    verdict: approve
    must_fix: []
    open: >-
      Both Thermos rubrics self-performed, no subagents or other threads.
      Detailed code/test/repro/text review through a3256a73c6, with an executed
      confirm of the sole changed paragraph on this exact Redmine-text head.
      Own builds of base a1a9f45587, the unchanged transported patch, and newer
      master 09cfdea5da; exact quoted repro fails on both unpatched masters,
      passes on 4.0.10 and patched master. Patched pathname suite: 298 tests,
      1226 assertions, zero failures/errors/skips; new test without restore
      gives exactly one NameError. Constant value, /o interpolation, warning
      on/off, frozen/Ractor shareability, private_constant, conversions and
      load order match 4.0.10; Windows source/model checked, not native Windows.
      Found and verified empty-files PATH/GIT and non-contiguous version
      boundaries; final subject, example and caller permalink are exact.
      Final fresh tip controls: system-version install exits 0 with lock
      unchanged; explicit 4.1.1 update and next install exit 0 in normal mode;
      frozen/deployment updates exit 16 with lock unchanged. Rubygems-only
      sources do not read the constant. No report must-fix. Approval covers
      the Redmine text and offered code, not the obsolete PR body or the
      transported patch's old all-2.x and /o commit-message claims; narrow
      that message before any future patch-file/PR publication. Full audit:
      bench/upstream/gem-differential/evidence/separator-pat/thermos-sol-2026-11-27.md;
      raw commands, sources and logs: thermos-sol-2026-11-27.tar.gz beside it.
      No upstream action taken; item state left unchanged for the
      coordinator's publication decision.
---

# Keep Pathname::SEPARATOR_PAT as a deprecated constant

Older Bundler, such as 2.6.9, reads `Pathname::SEPARATOR_PAT` while checking the files of a gem from a path or git source, which includes the gem itself in any repository whose Gemfile says `gemspec`. Bundler switches to the version in the lockfile's `BUNDLED WITH`, so on master `bundle install` with a lockfile from such a Bundler fails:

```
NameError: uninitialized constant Pathname::SEPARATOR_PAT
```

The constant became private in 4e243c709e and was removed in a5996718f3, after Bundler stopped using it in ruby/rubygems#9529.

This defines it again with its 4.0 value and deprecates it, so these lockfiles keep installing and remaining readers warn under `-W:deprecated`.
