# SEP1 Astra: changes to the report's scope and workaround wording

Reviewed `redmine.md` at Lowrail `a3256a73c6b5fc9de62256f9f00378d1fe85b6e3`, personally, without delegation or upstream posts.
Reviewer: astra; orb: `T-01a21d5c-3bca-76ba-9b8d-c6960f5eabf9`; date: 2026-11-27.
The review began on ff9e697fa4, then checked 37fab2de5e, before the coordinator requested this final head. Its shell
repro and patch are byte-identical (`logs/latest-head-validation.log`); the tested explicit-version workaround is unchanged.
I have not edited the draft or offered patch. Verdict: **changes**. No demonstrated defect in the restoration code.

Raw evidence and executable harnesses: `astra-2026-11-27.tar.gz` in this directory. Paths below are inside that archive.
`logs/validation.log` checks all matrix outcomes, completeness, duplicate cases, lock preservation, exact repros and warning probes.

## Must-fix wording

1. **Scope the remaining rubygems-only assertion.** Replace “Lockfiles with only rubygems.org gems still install” with:

   > Rubygems-only sources do not use this constant.

   Evidence: `logs/matrix/master-2.3.0-rubygems-noexe-normal.log` fails before any source installation with
   `DidYouMean::SPELL_CHECKERS`, as does Ruby 4.0.10; the restore cannot fix that. The proposed sentence distinguishes
   absence of this lookup from an unconditional install-success claim. Alternatively, prefix the existing sentence
   with “With Bundler 2.6.9,”, which the matrix directly supports.

   The new subject, example-based opening, nonempty-files wording and released caller permalink resolve the earlier
   scope/citation findings. Keep them. The permalink's fetched file is byte-identical to the installed 2.6.9 gem
   (`logs/bundler269-path.rb`). No claim about all historical Bundler releases is needed; the matrix below covers
   the requested 2.3.x–4.0.12 range, not earlier releases.

2. **Qualify the switch and the workaround.** Replace “Bundler switches to the version in `BUNDLED WITH`” with:

   > By default, Bundler switches to the version in `BUNDLED WITH`

   Replace the whole sentence beginning “Plain `bundle update --bundler` runs the old Bundler” with:

   > Outside frozen or deployment mode, `bundle _4.1.1_ update --bundler` updates the lockfile. With Bundler 4.1, `BUNDLE_VERSION=system bundle install` avoids the version switch.

   Evidence: `logs/revised-only-old-path-noexe-frozen-explicit.log` and `...deployment-explicit.log` show the new
   explicit-version update exiting 16 because the lockfile is frozen; `...normal-explicit.log` succeeds.
   `logs/boundary-path-exe-frozen-system.log` and `...deployment-system.log` succeed with Bundler 4.1.1 and leave the
   lock byte-identical. `logs/boundaries.json` confirms the same results for path/git, with/without executables.
   The system override in normal mode may update the lock; do not promise an unchanged lock outside frozen mode.
   The new plain-update statement is true when continuing the exact repro (`logs/exact-update-master-plain.log`),
   but not universal: plain update succeeds in the tested isolated BUNDLE_PATH fixtures, even with only default
   4.1.1 and installed 2.6.9 (`logs/revised-only-old-path-noexe-normal-plain.log`). The explicit command succeeds
   after the exact failure (`logs/exact-update-master-explicit.log`). Keep that reliable command, qualify frozen
   mode, and cut the unnecessary general assertion about the plain command.

Apply the same scope qualifications to the patch commit message if it is later submitted; it repeats the universal
claims. The queue impact/body and background record also retain overbroad claims; this pass records the corrections
rather than silently rewriting the author's material.

## Builds and exact reproduction

Built from source with `script/ruby-differential build`, not reused binaries:

| Build | Source |
| --- | --- |
| Ruby 4.0.10 | `a704b7cd95a42cc0cf5f307137bf3aac0285b915` |
| Current master when fetched | `09cfdea5da228b2ec76d1545f55e7557d49dd637` |
| Offered patch | `git am` of the kept patch onto `a1a9f45587282152aa8aa03afe6247bd64a3a99f` |

The local applied commit is `7dd5d4ca0b` (different committer timestamp), tree
`8efbbaa4ae4a7c5bbd502563a9db983f321e87fe`. Its diff has only the offered four library lines and six test lines.
The current master has no changes since a1a9f45587 in `pathname_builtin.rb`, `pathname.c`, `lib/bundler/source/path.rb`
or `lib/bundler/self_manager.rb` (`logs/source-history.log`). Build logs are `logs/build-*.log` and `logs/build*-driver.log`.
An initial shared-clone checkout lacked lazy Git blobs; fetching those blobs and restoring the missing tracked files
completed the checkout before applying/building. It did not change the reviewed diff.

`exact.py` extracts the shell block from the draft and asserts byte equality with `redmine-repro.sh`. It then runs that
block verbatim in fresh directories and fresh gem homes, twice per build, without preinstalling the selected Bundler.
Both 4.0.10 runs install; both master runs print the draft's Bundler 4.1.1 restart message and fail at
Bundler 2.6.9 `source/path.rb:218`; both restored runs install. See `logs/exact-{ruby4010,master,patched}-{1,2}.log`.
`logs/latest-redmine.md` is the exact reviewed final text. Its repro and patch diff against the original head is
empty (`logs/latest-head-patch-repro-diff.log`); the earlier exact runs therefore test the identical instructions.
`logs/revised-redmine.md` retains the intermediate 37fab2de5e text used for the explicit-update probes.

## Complete released-version matrix

All 101 stable releases in the requested range, from the live RubyGems version list:
2.3.0–2.3.27, 2.4.0–2.4.22, 2.5.0–2.5.23, 2.6.0–2.6.9, 2.7.0–2.7.2, 4.0.0–4.0.12.
Prereleases and releases outside that range were not tested. Exact list: `logs/versions.json`.

For **each version on both Ruby builds**, ran all six shapes (path/git/rubygems-only × with/without executables), in
normal, `BUNDLE_FROZEN=true`, and `BUNDLE_DEPLOYMENT=true` mode. Each case runs `bundle install --local`, then
`bundle check`, then `bundle exec ruby`; successful executable cases also run the gem executable. Old Bundlers were
preinstalled in the isolated gem home for this matrix. Each case has an independent bundle directory. RubyGems gems
are rake 13.3.1 (executable) and ruby-progressbar 1.13.0 (none), downloaded from rubygems.org and installed through
the local cache. Path/git fixtures are the same tiny gem with one library file, plus an executable in the executable
variant. Local git transport avoids network variation. The separate exact repro exercises online Bundler installation.

| Selected Bundler | Ruby 4.0.10: install | Master: path/git install | Master: rubygems-only install |
| --- | --- | --- | --- |
| 2.3.0 | `DidYouMean::SPELL_CHECKERS` startup error | Same startup error | Same startup error |
| 2.3.1–2.7.2; 4.0.0–4.0.11 | Success | `Pathname::SEPARATOR_PAT` NameError | Success |
| 4.0.12 | Success | Success | Success |

No executable/no-executable or frozen/deployment exceptions to that table. Frozen/deployment locks stay byte-identical.
For every version except 2.3.0, `check` and `exec ruby` succeed **after the install attempt**, even after the separator
failure; they do not traverse this installation code. The separate fresh-install boundary probes show path-based
`check`/`exec` work before install too, whereas an uninstalled git source raises “not yet checked out” and a missing
RubyGems dependency raises `GemNotFound`, not the separator error. Do not turn this into a general claim that exec
or check works without installing dependencies.

Also checked empty `spec.files` for path/git on both Rubies with 2.3.0, 2.3.27, 2.4.0, 2.6.9, 4.0.11 and 4.0.12.
They install in all modes except the unrelated 2.3.0 startup error. Excluding a nonempty path/git gem's group with
`BUNDLE_WITHOUT=tools` also bypasses the fault. Installing a path/git fixture first with 4.1.1 and then reinstating
`BUNDLED WITH 2.6.9` still reproduces the separator failure, so an earlier successful installation is not a workaround.

The restored build repeats all six shapes and three modes for 2.3.0, 2.3.1, 2.3.27, 2.4.0, 2.6.9, 2.7.2, 4.0.0,
4.0.11 and 4.0.12. All succeed except 2.3.0's unchanged startup error. Across the matrices: 3,870 distinct cases;
`logs/analysis-final.log` reports no unexplained outcomes. Raw commands/output are in `logs/matrix/`; structured
results are `logs/matrix-*.jsonl` and `logs/matrix-summary.json`.

## Restoration and exactness

* `make test-all TESTS=pathname`: **298 tests, 1,226 assertions, zero failures/errors/skips** on the offered patch
  (`logs/patched-pathname-tests.log`). The new test run against unpatched master raises the expected NameError
  (`logs/unpatched-new-test-regex.log`). Two earlier exact-name selections ran zero tests; they are retained but
  provide no evidence. The successful selection is `-n /test_separator_pat/` with the patched test directory.
* `patch-probe.rb` compares the original and restored regexp construction for both Unix and Windows separator
  values, and executes the old `/\A#{Pathname::SEPARATOR_PAT}/o` pattern on absolute/relative/empty/drive/UNC paths,
  Unicode and binary strings, a String subclass, and a `to_str` object. No changed result against Ruby 4.0.10.
* Windows was checked by reading `file.c` and `include/ruby/internal/dosish.h`: on Windows ALT_SEPARATOR is backslash
  and SEPARATOR is slash. The restored expression produces the same character class as 4.0.10. Its anchored form
  matches leading slash/backslash and UNC prefixes, not a leading drive letter, exactly as before. This is a source
  check and a synthetic two-separator probe, **not a Windows execution claim**.
* Default and `-W:no-deprecated`: no separator deprecation warnings. `-W:deprecated`: warnings at the constant
  reads, including one warning at the `/o` site across thirteen calls. The regexp is frozen and Ractor-shareable
  on both 4.0.10 and the restored build; a worker Ractor reads and matches it successfully. Explicit `.freeze`
  is not missing behavior here. The ordinary experimental Ractor warning is unrelated to deprecation.
* Exactness checklist: public constant visibility, load/require behavior, warning setting, regexp value/options/
  encoding, frozen state, non-main-Ractor access, String subclasses and implicit conversion were probed. This
  change adds a constant, not argument-processing calls, caches or iteration; argument mutation, callback ordering,
  private overrides, reloading and suspended fibers have no changed call boundary to test. No claim that the
  public-constant restoration is identical to unpatched master: that intentional behavior change is the fix.

## Every sentence and upstream text rules

| Draft passage | Evidence / assessment |
| --- | --- |
| “Tracker: Bug” | Demonstrated install regression from 4.0.10 to master; appropriate. |
| Subject and opening “can fail”, with 2.6.9 example | Correct; the final head resolves the overbroad version-range claim. |
| Quoted restart and NameError | Reproduced verbatim in both fresh master runs, including path.rb:218. |
| Version switch | Reproduced when selected version is absent; preinstalled versions are selected too. Configurable, so must-fix 2. |
| “while checking the files of a path or git gem” | Correct; the revised head fixes the empty-file overstatement. No executable required. |
| Private in 4e243c709e, removed in a5996718f3 | Read both actual diffs; confirmed in `logs/source-history.log`. |
| Bundler stopped using it in the linked PR | Current merged PR replaces the exact read with `Pathname#absolute?`; 4.0.11 fails and 4.0.12 succeeds. |
| Rubygems-only locks still install | True for the functioning versions tested, not 2.3.0; replace with the precise lookup scope. |
| Plain update runs old Bundler and fails | True continuing the exact repro, false for the tested isolated BUNDLE_PATH fixtures; cut the general assertion. |
| Explicit 4.1.1 update updates the lockfile | Verified after the exact failure; rejected under frozen/deployment configuration. Must-fix 2. |
| “To reproduce (Ruby 4.0 installs, master raises)” and shell block | Ran exactly, twice on 4.0.10 and master. No assertion about every historical 4.0 patch release. |
| Conditional deprecated restore and Ruby snippet | Built the offered patch; exact example and tested functional versions install; warning and Ractor checks pass. Not a cure for unrelated 2.3.0 startup failure. |
| Offer to open a PR and test | Conditional proposal, not a factual claim that a PR is open. No upstream action taken. |

The text is short, plain and contains no Lowrail name, internal ID, census counts, orb, reviewer or queue material.
The code comment explains why to retain an otherwise unused constant; no additional explanatory comment is needed.
The issue's repro belongs in the issue even though ordinary PR bodies omit verification commands. Keep the broad
matrix and review process out of the upstream text. The final head's caller permalink satisfies the restore-body citation rule.

## Linked PR: current and directly relevant

Read the live PR, file diff and comments via GitHub API. `ruby/rubygems#9529`, “Use Pathname#absolute?”, was merged
2026-05-07, last updated 2026-05-10, not a pending alternative. Its body explicitly predicts breakage when the
private-constant typo is fixed; its diff removes the same constant access. Bundler 4.0.12 was released 2026-05-20.
The current bundled implementation no longer reads the constant. The link explains the fix already shipped in
Bundler; it does not itself establish the lockfile version-switch behavior, which the exact runs establish.

Currency check on 2026-11-27: ruby/rubygems is not archived, has 3,997 stars and was pushed that day; Bundler has
4,003,853,703 downloads and current release 4.1.1 dated 2026-11-25. ruby/ruby is not archived, has 23,869 stars and
was pushed that day. This is one central dependency, not a list needing reach-ordering. API responses are retained
as `logs/pr9529*.json`, `logs/{rubygems,ruby}-project.json`, `logs/bundler-project.json` and `logs/bundler-versions.json`.
No ecosystem popularity or review-process data belongs in the proposed report.
