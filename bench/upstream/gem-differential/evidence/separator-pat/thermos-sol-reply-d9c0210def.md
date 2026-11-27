# SEP1 reply review — thermos-sol, 2026-11-27

Verdict: **approve**. Must-fix list: **empty**. No wording changes required on this head.

Reviewed Lowrail head: `d9c0210def7db1b07d47b930715aca622c0e892d`, specifically `reply-16909.md`, not the held restore patch or dropped Redmine report. Reviewer orb: `T-01a21d5a-243c-7558-b622-6f5801179598`. Both Thermos rubrics were applied personally, sequentially; no subagents or new threads. This is not a claim that two independent parallel reviewers ran.

The only change from `976c193a7624cc0b42e46171e0f4935beff0bc68` is the final question: `@nobu, is ... for 4.1?` becomes `Is ... for Ruby 4.1?`. The ping finding is resolved. The complete new text was read, not merely the diff.

## Result and question framing

Keep the final question exactly as revised:

> Is turning off the autoswitch still planned for Ruby 4.1?

[The merge proposal](https://github.com/ruby/rubygems/issues/9236#issuecomment-4748470107) does not answer that timing question. In the June 19 comment, hsbt explicitly leaves phases 4+ open: phase 4 discusses deprecation in the last 4.x releases, and phase 5 discusses a cutoff or wrapper in 5.x. [Colby's response](https://github.com/ruby/rubygems/issues/9236#issuecomment-4766435253) approves phases 1–3 and calls for another review at phase 4. Neither supplies a Ruby 4.1 deadline. There is a public direction for changing autoswitch; do not report that no plan exists. No implemented default-disable or explicit Ruby-4.1 commitment was found in the inspected source, changelogs, issues and PRs. That bounded search is not proof that no other plan exists.

Naming **Ruby** 4.1 distinguishes the forthcoming interpreter release from Bundler 4.1, which has already shipped. Asking whether the stated outcome is still intended for that Ruby release is a clarification of [the November claim](https://github.com/ruby/ruby/pull/16909#issuecomment-6687729119), not an assertion that the merge proposal promises it. The proposal therefore needs no extra paragraph in this short reply. The text neither argues for the constant nor asks to reopen the restore.

## Own runtime evidence

Fetched Ruby master and built `80343e1cf52997cbfcb0a279ee5c330cd630d029` from source in this orb, using the existing own build directory, a newly configured installation prefix, `make -j8` and `make install`. Remote master still named that commit at the recorded final source check. Output: `ruby 4.1.0dev (2026-11-27T14:39:46Z HEAD 80343e1cf5) +PRISM [x86_64-linux]`. No restore patch is applied.

Generated real lockfiles with released Bundler 4.0.11 and 4.0.12 on Ruby 4.0.10 using `bundle _VERSION_ lock`; the failing lock was not merely hand-edited to say 4.0.11. Each runtime case used a new HOME, GEM_HOME, GEM_PATH and BUNDLE_PATH, with no inherited Bundler or Ruby options. The `gemspec` has one actual file, `lib/foo.rb`.

Command: `python3 .amp/in/orb-backup/thermos-sol-reply-976c193a76/repro.py`. Decisive output: `PASS: actual 4.0.11 lockfile; master A/A, bypass, fixed and release controls; packaged beta3/4.1.0/4.1.1 autoswitch` in `logs/repro-v3.log` inside the archive.

| Case | Observed result |
| --- | --- |
| Current master, default configuration, 4.0.11 lock, two independent fixtures | Both print the exact quoted 4.1.1-to-4.0.11 installation/restart message, then `NameError: uninitialized constant Pathname::SEPARATOR_PAT`; install exits 1; next `bundle -v` is 4.0.11; lock unchanged |
| Same master, `BUNDLE_VERSION=system` | Install exits 0, no restart message, next version 4.1.1 |
| Same master, genuine 4.0.12 lock | Switches to 4.0.12; install exits 0; lock unchanged |
| Ruby 4.0.10, same genuine 4.0.11 lock | Install exits 0 with 4.0.11; lock unchanged |
| Released 4.1.0.beta3, 4.1.0 and 4.1.1, each on the same Ruby 4.0.10 host | Each starts as the named release, announces installation/restart into 4.0.11, completes installation under it, and leaves the lock unchanged |

The beta/release comparisons used ordinary `bundle install`, not `bundle _VERSION_ install` (which would pin the process and defeat the autoswitch test). Their starting version was selected by installing only that released Bundler into the isolated GEM_HOME; their starting `bundle -v` and subsequent 4.0.11 version were checked. These packaged comparisons ran on Ruby 4.0.10, not three separate historical Ruby-master builds.

Also ran the checked-in `separator_pat_gemspec.sh RUBY_PREFIX 4.0.11` on the fresh master build, with its `mktemp` redirected into the scratch directory. Its full `bash -x` log independently contains the same switch and NameError. Its existing one-line summary truncates the error to `NameError: u`; the full captured output, not that summary, is the evidence.

The system-version control's generated lock **changes**: Bundler replaces BUNDLED WITH with 4.1.1 and drops the old Bundler checksum. The earlier review's unchanged-lock observation was for its different, checksum-free fixture, not a universal guarantee. No lock-preservation claim appears in this reply. Two scratch-harness assumptions failed before the final run: the writer uses two spaces rather than three in BUNDLED WITH, and the checksum-bearing system control edits its lock. Both failed logs are retained; the corrected final run asserts the actual expected contents rather than suppressing these differences.

## Source and planned-change audit

Own full RubyGems checkout: master `fc37d0f953ddf1bae50d11670cd48eee2a588679`.

* `git show REF:lib/bundler/settings.rb` confirms `"BUNDLE_VERSION" => "lockfile"` at line 91 for `v4.1.0.beta3` (`cd7536a41fb5a6aa167f95916552a76b8b6f453f`), `v4.1.0` (`9af926714658c49259d17dae267206087fd030ed`), `v4.1.1` (`8a4df2cde8d774e6ed469488880733997d75f1f1`) and master.
* `git diff REF HEAD -- lib/bundler/self_manager.rb` is empty for all three releases. `find_restart_version` still selects the lockfile version unless `version` is `system`; `install_locked_bundler_and_restart_with_it_if_needed` still installs it and restarts. The `BUNDLE_DISABLE_VERSION_CHECK` setting is not removal of this self-manager path.
* Compared each released installed gem's self-manager byte-for-byte with its tag source, and compared v4.1.1's self-manager with the Ruby-master source: all equal. Cached released-gem SHA-256 values are in `logs/final-source-confirm.log`.
* Fetched the reply's exact settings permalink via GitHub contents at the full Ruby commit; `cmp` with the built source passes. The linked line is exactly the claimed default.
* Read the complete current 4.1.0 and 4.1.1 CHANGELOG sections, the historical tag copies, recent self-manager/settings history and version-switch-related commit subjects. No default-disable entry was found.
* Six GitHub searches cover `autoswitch`, `auto-switch`, `"BUNDLED WITH" "4.1"`, `"BUNDLE_VERSION" "4.1"`, `switch "4.1"`, and `"automatic switching"`, scoped to `ruby/rubygems`, including open/closed issues and PRs. Search responses, exact query strings and relevant full discussions are retained. Each response has `incomplete_results: false` and fewer than 100 hits. Search matching and indexing still limit a negative conclusion.
* Read issue 9236 and all comments, PR 9252 and its comments, release PRs 9864/10064, documentation PR 10036, and issue 10072 with its maintainer response. Open PR 9252 proposes installing Bundler in the system gem path to reduce restarts; it is unmerged and still intends selection of the lockfile Bundler, not disabling the locked-version default. Issue 10072 is a recent independent report of 4.1.0 switching; its maintainer response directs users to a newer locked Bundler, rather than announcing removal of switching.

## Sentence-by-sentence review

The internal wrapper is not upstream text. Its date and context match the API-fetched November 6 question from eregon. The draft remains unposted by this reviewer. The PR is closed, unmerged, since May 28; the full live comment history was fetched, including nobu's November 6 assertion and eregon's unanswered request for a link.

1. **“On master (80343e1cf5), Bundler 4.1.1 still switches to the version in BUNDLED WITH.”** Verified by the current-master own build and two fresh executions, not inferred solely from settings. It describes observed default behavior; the system-version control also verifies this is not an unconditional rule for every configuration.
2. **“With a lockfile written by Bundler 4.0.11 and a gemspec Gemfile:”** Verified by the actual 4.0.11 writer and fixture contents. The example contains a real file; this is not a claim that every possible empty-file gemspec fails.
3. **Both quoted log lines.** Each occurs verbatim in both master-default runs and the checked-in repro log. The two-line block is an excerpt, not the entire Bundler output. The old version's source-path backtrace is retained.
4. **“The default is still lockfile” plus settings link.** Verified by fetching that exact file at the full commit and comparing it with built source; line 91 and the self-manager's consumer were read.
5. **“Is turning off the autoswitch still planned for Ruby 4.1?”** A focused question about timing, not an unverified assertion of a committed plan. Issue 9236 does not supply the answer. No ping remains; it does not request restoration or dispute the maintainer's choice.

The reviewed Lowrail commit message is one sentence: “SEP1: reply draft without a mention, asking about Ruby 4.1”. The exact diff verifies both parts. Its author and committer are Thomas Klemm and it has no trailers. The superseded restore patch's code/test/comment/commit-message review is not reopened or approved for publication by this pass.

## Maintainability and exactness gates

There is no runtime-code, public-method, test or comment addition in the new review target. File-size, new abstraction, helper-layer, spaghetti/branching and metrics gates introduce no code concern. The plain short reply is simpler than another restore/report; no extra paragraph or proposal is needed. The framing is not combative and exposes no Lowrail/process material after the internal separator. Ruby and Bundler are central and current: API snapshots show ruby/ruby has 23,870 stars and a November 27 push, ruby/rubygems has 3,997 stars and a November 27 push, and Bundler 4.1.1 was released November 25 with about 4.00 billion total downloads. No abandoned or niche project is cited in the proposed upstream text.

Exactness checklist was applied to this **text-only** head:

* Items 1–6 (overrides, subclasses, implicit conversions, new/skipped calls, ownership and mutation/fibers): no changed Ruby behavior or calls to compare; not applicable, not silently claimed tested.
* Item 7 (frozen values/errors): no changed receiver or freezing contract. The concrete exception class/message and success controls were executed. No new frozen-mode claim is made by this pass.
* Item 8 (load order/configuration): standalone CLI, isolated settings, absent old version, automatic installation/restart, following invocation's selected version and the system-config bypass were executed. Installed source was compared with tag/build source.

The relevant differential is current master versus Ruby 4.0.10 on a genuine identical 4.0.11 lock, with current-master A/A, bypass and 4.0.12 controls; packaged beta3 versus released 4.1.0/4.1.1 confirms the historical autoswitch assertion independently. No new performance number, Windows behavior, Ractor behavior, constant restore or pathname-suite claim is introduced. The prior kept patch audit remains available separately; `make test-all TESTS=pathname` was not rerun for this prose-only pass.

## Retained evidence

Raw archive beside this report: `thermos-sol-reply-d9c0210def.tar.gz`. Paths inside it:

* `logs/build.log`: exact configure/make/install commands and new interpreter version.
* `repro.py`, `logs/repro-v3.log`, `logs/repro-driver-v3.log`, `sources/results.json`, `sources/generated-4.0.11.lock`, `sources/generated-4.0.12.lock`: final executable harness, complete outputs and actual generated locks.
* `logs/checked-repro-4.0.11.log`: full trace of the checked-in repro on the new build.
* `logs/repro.log`, `logs/repro-driver.log`, `logs/repro-v2.log`, `logs/repro-driver-v2.log`: diagnosed scratch-harness failures described above.
* `logs/source-audit.log`, `logs/claims-and-plans.log`, `logs/final-source-confirm.log`: exact pins, source checks, historical comparisons, commit message, complete relevant plan text and gem checksums.
* `sources/`: complete searched API responses and query strings, source/changelog snapshots, fetched linked settings, old/new exact draft and their diff. No private credentials or configuration were captured.

This is a review record, not permission to post. SEP1 remains held. No Ruby push, PR, Redmine issue or GitHub comment was made.
