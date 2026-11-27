# SEP1 detailed review, 2026-11-27

Reviewer: thermos-sol, orb `T-01a21d5a-243c-7558-b622-6f5801179598`.
Both Thermos rubrics were applied directly by the sole reviewer, as requested; no subagents or other threads were created. This is not a claim that two independent reviewers ran.

## Verdict and scope

**Approve the Redmine report at Lowrail `0a0321e20aa64355a236e68331f8b89306a5c565`, including its quoted repro and offered two-line restore. No must-fix remains in that report.** The detailed code, repro and text work targeted `a3256a73c6b5fc9de62256f9f00378d1fe85b6e3`; a final executed confirm covers the sole paragraph changed in `0a0321e20a`. Earlier drafts `ff9e697fa4` and `37fab2de5e` needed changes, detailed below. This pass is not on the obsolete PR body, and grants no permission to post an issue or open a PR.

The transported Ruby patch is unchanged: `0001-Keep-Pathname-SEPARATOR_PAT-as-a-deprecated-constant.patch`, SHA-256 `33d28fe45411d2b861491661022babeb28632800881cbd105bec821f9c210f18`, with From-header head `8961f4c5410f5459487af7fc110858100c0cf26d` and base `a1a9f45587282152aa8aa03afe6247bd64a3a99f`. Its code and regression test are sound. **Its old commit message is not approved for a future PR or patch-file submission:** its all-2.x installation claim and literal `/o` claim need the same narrowing as the report. That message is not included in the approved Redmine text, which offers the code, not a patch attachment.

Raw commands, stdout/stderr, source snapshots, probe programs, and build/test logs are in `thermos-sol-2026-11-27.tar.gz` beside this file. All paths below are archive-relative. No speed, allocation or instruction claim is made; these are correctness runs, not a performance comparison requiring A/A.

## Builds and execution

- Built unpatched Ruby with `RDIFF_HOME=... script/ruby-differential build --commit a1a9f45587282152aa8aa03afe6247bd64a3a99f --name sep-base`. Configure enabled both JITs; baseruby was 4.0.9, GCC 14.2.0. See `logs/build-base-driver.log` and `rdiff/logs/build-sep-base.log`.
- Applied the transported patch with `git am --committer-date-is-author-date`, Thomas as author and committer, then configured, compiled and installed it myself into a separate prefix. `git am` produced local commit `f2e5d9b32746282a5e6b0363179e041cb74e2f2d`, tree `8efbbaa4ae4a7c5bbd502563a9db983f321e87fe`; am does not preserve the source commit object/signature/committer metadata. The original unpublished object was unavailable, so this verifies the exact transported diff, not the original commit object. See `logs/applied-commit-raw.txt`, `logs/reviewed-patch.diff`, `logs/patch-applied.txt`.
- `make test-all TESTS=pathname` with the new test but no restore: **298 tests, 1224 assertions, 0 failures, 1 error**, exactly `TestPathname#test_separator_pat`, `NameError: uninitialized constant Pathname::SEPARATOR_PAT`. See `logs/base-new-test-full.log`.
- Same command on the patched build: **298 tests, 1226 assertions, 0 failures, 0 errors, 0 skips**. See `logs/build-fixed-and-pathname.log`.
- Fetched Ruby master during the review: `09cfdea5da228b2ec76d1545f55e7557d49dd637`, later than the requested `274cfe719a`. Both comparisons with `a1a9f45587` are empty for `pathname_builtin.rb`, `pathname.c`, `lib/bundler/source/path.rb` and `lib/bundler/self_manager.rb`. Built and installed `09cfdea5da` and reran the repros, rather than relying only on the file diff. See `logs/build-tip.log`, `logs/tip-head.txt`, `logs/history-and-master.txt`, `logs/load-order-and-tip.txt`, `logs/matrix-tip.log`.
- Tip pathname suite: **297 tests, 1222 assertions, 0 failures, 0 errors, 0 skips** (`logs/tip-pathname.log`). JIT execution was not separately exercised; this restore adds no VM/JIT mechanism. Windows was source-reviewed and expression-modeled, not run on a Windows host.
- Ruby 4.0.10 comparison used the installed release binary, revision `a704b7cd95a42cc0cf5f307137bf3aac0285b915`, and its exact tag's `pathname_builtin.rb`. See `logs/install-4.0.10.log`, `old-pathname.rb`.

`matrix.py` runs the checked-in gemspec, git and rubygems-only repros unchanged, except for redirecting their mktemp directories into the retained scratch directory and setting HOME so their release prefix resolves. It records `bash -x`, including the complete output that the repros' summaries truncate. The scripts themselves exit 0 even when their embedded bundle command fails: the reviewed status is the captured `exit=`, not the wrapper's exit status. The quoted Redmine repro is executed verbatim in a fresh directory for each Ruby. Logs: `logs/matrix-{release,base,fixed,tip}.log`.

| Case | 4.0.10 | unpatched base | patched base | master tip |
| --- | --- | --- | --- | --- |
| Gemfile `gemspec`, files nonempty; Bundler 2.4.2, 2.6.9, 4.0.7, 4.0.11 | installs | SEPARATOR_PAT NameError | installs | SEPARATOR_PAT NameError |
| Same with Bundler 4.0.12 | installs | installs | installs | installs |
| Git gem, files nonempty; Bundler 2.6.9 | installs | SEPARATOR_PAT NameError | installs | SEPARATOR_PAT NameError |
| Only rubygems.org rake, Bundler 2.4.2, 2.6.9, 4.0.11 | installs | installs | installs | installs |
| Exact quoted Redmine repro, Bundler 2.6.9 | installs | SEPARATOR_PAT NameError | installs | SEPARATOR_PAT NameError |
| Empty file list, PATH or GIT, Bundler 2.6.9 | installs | installs | installs | installs |

## Findings and their disposition

1. **Fixed in the report: PATH/GIT alone was not enough.** The lookup is inside `spec.files.map`/`filter_map`; an empty file list never reads the constant. Replacing only `s.files = ["lib/foo.rb"]` with `s.files = []` makes both source types install on unpatched base and tip. The final subject says “can fail”; the description says “a path or git gem with files.”
2. **Fixed in the report: a simple version interval was false.** `boundaries.py` and `logs/version-boundaries.log` show 2.2.34 succeeds on 4.0.10 and patched Ruby but raises SEPARATOR_PAT on base; 2.3.0 already fails on both release and patched Ruby on `DidYouMean::SPELL_CHECKERS`. 2.0.2 and 2.1.4 also fail before reaching this lookup. 2.3.27 succeeds on release and patched Ruby, fails on base with SEPARATOR_PAT. The final text gives 2.6.9 as an example rather than claiming all 2.x or 2.3–4.0.11 are otherwise compatible.
3. **Fixed: plain update was not a universal workaround or universal failure.** In the exact failing 2.6.9 repository, `bundle update --bundler` raises the same NameError and leaves `BUNDLED WITH 2.6.9`; `bundle _4.1.1_ update --bundler` exits 0, writes 4.1.1, and the next `bundle install` exits 0. See `logs/matrix-base.log`, section “bundle update --bundler workaround”, and `logs/explicit-workaround.log`. `logs/update-boundaries.log` also proves plain update fails for 2.4.2 but succeeds for 4.0.7 and 4.0.11. The final report removes the plain-update claim altogether, limits explicit update to non-frozen/non-deployment mode, and adds the system-version install alternative. The final executed confirm below verifies these statements.
4. **Fixed: missing caller permalink and overly broad subject.** The final report links the verified Bundler 2.6.9 caller and says “can fail.” The first SHA I suggested was the RubyGems `v2.6.9` tag and was wrong; corrected to the dereferenced `bundler-v2.6.9` tag before approval. `logs/caller-permalink.txt` records the correct tag object, commit, line and byte comparison with the released gem.

No introduced security defect, structural regression, or must-fix code/test issue was found. The original patch message remains unsuitable for future publication, independently of approving this report:

- “Bundler before 4.0.12 evaluates /.../o”: downloaded source shows 2.0–2.4 examples use a regexp without `/o`, while 2.5.23, 2.6.9, 2.7.2 and 4.0.0–4.0.11 use `/o`. Its broader installation sentence also covers already-incompatible versions. Say the named Bundler 2.6.9 example instead. `logs/all-bundler-callers.txt` includes every 4.0.0–4.0.12 release and representative 2.x releases.
- “Bundler switches to the version named in BUNDLED WITH”: true for the default configuration in the executed repro. Explicit `BUNDLE_VERSION=system` bypasses the downgrade, an existing documented configuration boundary, not a defect in the restore. Recorded as `base explicit-system-bundler` in `logs/matrix-base.log`.
- The historical removal statements, 4.0 value, deprecation, and 4.0.12 fix are verified below. The patch's title correctly describes its code.

## Redmine text, sentence by sentence

Line numbers refer to `reviewed-redmine-0a0321e2.md` in the archive, byte-for-byte the file at the approved head. The a3256a73 snapshot and earlier drafts are retained too.

| Text | Check run or link opened | Result |
| --- | --- | --- |
| Subject: install “can fail” for older locks | Exact repro on release/base/fixed/tip; rubygems-only and empty-files controls in matrix logs | Exact existential claim; no universal old-version promise |
| L7: older Bundler such as 2.6.9, path/git gem with files, `gemspec` example | `python3 matrix.py` for all four Rubies; unchanged quoted repro and PATH/GIT repros | Verified; files and affected installation are necessary, source section alone is not sufficient |
| L10–12: downgrade message, NameError and path.rb:218 frame | `logs/matrix-base.log` and `logs/matrix-tip.log`, “redmine-as-written” | Exact output, aside from the shortened directory prefix |
| L15 sentence 1: default lockfile switch and 2.6.9 file check | Executed downgrade and system-version bypass; inspected `SelfManager`; fetched caller at `8a2a14d63da701e980f856d8772d273fd448b8a1` and byte-compared with the unpacked 2.6.9 gem | Verified; default qualification and correct line permalink |
| L15 sentence 2: private/removal commits; Bundler 4.0.12 removed use | `git show 4e243c709e`, `git show a5996718f3` in `logs/history-and-master.txt`; opened <https://github.com/ruby/rubygems/pull/9529>; inspected unpacked 4.0.11 and 4.0.12 source | Verified; 4.0.12 uses `Pathname#absolute?` |
| L15 sentence 3: rubygems-only sources do not use the constant | Rubygems-only controls on base and tip; searched all Bundler 2.6.9 library references and read `Source::Rubygems#install`, `logs/final-metadata.txt` | Lookup occurs only in the PATH source, inherited by GIT; does not promise all old Bundlers start successfully |
| L15 sentence 4: outside frozen/deployment, explicit 4.1.1 updates | `final-confirm.py`, fresh failing 2.6.9 fixtures on built tip; `logs/final-confirm-0a0321e2.log` | Normal update and following install exit 0; frozen/deployment update exit 16 and leave lock unchanged |
| L15 sentence 5: Bundler 4.1 system setting avoids the switch | Same final confirm: current bundled 4.1.1, `BUNDLE_VERSION=system bundle install` after the exact failure | Exits 0 without changing the 2.6.9 lock; original default install raised |
| L17: Ruby 4.0 installs, master raises; L20–30 repro commands | Exact checked-in `redmine-repro.sh` executed verbatim on 4.0.10/base/fixed/tip | Verified on Linux; `sed -i` is the demonstrated GNU sed command, not a portability claim |
| L33: the deprecated restore is enough for these locks; L36–37 code | Own patched Ruby build; both source repros; value/warning/Ractor/private-constant probes | Verified for this regression, not unrelated failures in ancient Bundlers |
| L40: can offer a PR and test if preferred | The kept patch has both the code and the regression test; full suite was run | A conditional offer, not a claim that a PR is open; no publication performed |

The caller URL is <https://github.com/ruby/rubygems/blob/8a2a14d63da701e980f856d8772d273fd448b8a1/bundler/lib/bundler/source/path.rb#L218>. Its HTTP page fetch failed temporarily, so the same commit's GitHub contents API was fetched successfully and byte-compared with the released gem; the actual line is `next path unless /\A#{Pathname::SEPARATOR_PAT}/o.match?(path)`.

Relevance/currency: Bundler/RubyGems is the only external dependency named, and the current Bundler itself selects the older version here. Queried GitHub and rubygems.org: repository not archived, last push 2026-11-27, 3,997 stars; Bundler 4.1.1 released 2026-11-25, 4,003,853,703 total downloads at query time. These are a relevance check only, not claims to add upstream. See `logs/external-and-constant-source.txt`. The historical caller is deliberately the version activated by the current tool, not an argument for using obsolete releases.

### Final confirm on 0a0321e20a

Read `git diff a3256a73c6 0a0321e20a -- .../redmine.md`: only the third paragraph changed; the subject, concrete example, caller link, repro, offered code and conditional PR offer are identical. Ran `python3 final-confirm.py` against the personally built master `09cfdea5da`. Each of four fresh copies first ran the exact quoted repro and failed with SEPARATOR_PAT. Then:

- `BUNDLE_VERSION=system bundle install`: exit 0, original 2.6.9 lock unchanged.
- `bundle _4.1.1_ update --bundler`: exit 0 in normal mode, lock becomes 4.1.1, following `bundle install` exit 0.
- The explicit update in frozen and deployment modes: exit 16 in each, original lock unchanged.

Read the bundled 4.1.1 `SelfManager` default/switch guards, searched the unpacked 2.6.9 library for SEPARATOR_PAT (only `source/path.rb:218`), and followed `Source::Rubygems#install`. These checks support each replacement sentence without broadening an install-success claim. Logs are `logs/final-confirm-0a0321e2.log`, `logs/final-confirm-driver.log`, `logs/final-metadata.txt` and `logs/external-and-constant-source.txt`. Result: approve this exact report head, no must-fix. The unused patch-file message is still excluded from approval for future publication.

## Exactness checklist and differential probe

Ran `python3 probes.py`, which executes the same `exactness.rb` under 4.0.10 and the compiled patch and asserts identical JSON, excluding intentional warning-category differences. It also records the unpatched NameError, executes warning modes, and evaluates the actual old/new separator expressions with POSIX and Windows constants. Final output: `PASS: old/patched exactness, warnings, POSIX/Windows expression models; logs/exactness.log`.

1. **Singletons, extend, prepend, missing methods:** checked a String subclass with a singleton `to_str`, objects with public/private `to_str`, `extend`, singleton-class `prepend`, and `method_missing`/`respond_to_missing?`. Same results and conversion counts.
2. **Subclasses:** String subclass/frozen String checked. Hash and Array subclass operations do not apply: no collection API or method accepting those objects is added or changed; the only production change is boot-time constant construction and deprecation metadata.
3. **Implicit conversions:** public/private/dynamic `to_str` each called once; a raising conversion retains exception class/message. No `to_a`, `to_ary` or `to_hash` conversion is added.
4. **Added/skipped calls:** no per-user-object call is added or skipped by the restore. The expression quotes File's platform-owned separator strings and creates a Regexp during initialization. Global core-method redefinitions are outside the checklist's accepted boundary.
5. **Copies/ownership:** no user result becomes an accumulator. Both Rubies expose the same frozen, Ractor-shareable regexp, with identical `source`, `options` and encoding.
6. **Mutation/fibers:** a conversion suspends and resumes a Fiber once with identical result/calls. Replacing the constant after initializing Bundler's `/o` regexp does not change the cached match behavior in either Ruby. No user collection iteration is changed.
7. **Frozen/error semantics:** frozen String/subclass, nil, integer, false, binary/invalid bytes, UTF-16LE, relative/absolute paths, newlines and non-ASCII names were compared. Same matches and exceptions. Real Ractor reading succeeds in both. No explicit `.freeze` is necessary here: the interpolated regexp is already frozen on the tested Rubies.
8. **Load order/standalone require:** `--disable-gems` before `require 'pathname'` sees Pathname already defined; release/patched have the constant and base does not; first require returns true, second false. See `logs/load-order-and-tip.txt`. The restore introduces no lazy loading, caller configuration read, or new require.

Private-constant interactions: applying `private_constant` still rejects an uncached explicit lookup with the same NameError; `const_get` still returns the value; `public_constant` makes the explicit read work again; an already interpolated `/o` regexp remains cached. Deprecation flags are independent of visibility flags in `variable.c`, which was read (`logs/external-and-constant-source.txt`).

Warnings: ordinary execution, `-W:no-deprecated` and `-W0` produce no deprecated-constant warning; `-W:deprecated` and `-w` enable it on the restored constant. `/o` reads it on its initial interpolation, not on every matching call. No claim that `-W:deprecated` is the only way to enable the category is approved.

Windows: read File's ALT_SEPARATOR definition and the exact 4.0.10/new expressions. With ALT_SEPARATOR `\\` and SEPARATOR `/`, both produce source `[\\/]`, frozen/shareable, matching slash and backslash at the start but not a drive letter. With nil, both produce `/`. This is not an attempt to replace the separator regexp with `Pathname#absolute?`: a drive-letter path is intentionally not a separator-starting path. The Linux expression model confirms source/value behavior, not native Windows execution.

## Maintainability, comments and test

Plain reading: choose a regexp matching either separator when an alternate exists, otherwise the ordinary separator; mark the restored name deprecated. No new methods, stateful helper, branch in a pathname operation, or abstraction layer. No touched method's production complexity increases; method-level flog/RuboCop metrics are inapplicable to a constant-only restore.

Asked whether less code could preserve the contract: hard-coding POSIX loses Windows behavior; using `Regexp.union` changes the Windows regexp's public source/string representation; keeping the restored constant private would not repair the caller. The direct definition plus `deprecate_constant` is the smallest obvious exact restore. A multi-line `if` would be stylistically possible, not a simpler mechanism. Fixing Bundler selection is an alternative policy, and the report intentionally leaves that choice to maintainers. See the corrected alternative-expression probe in `logs/final-metadata.txt`.

The existing `# :stopdoc:` is the right placement: this compatibility constant should not be promoted into Pathname's documented API. The one new comment, `Read by Bundler before 4.0.12, which older lockfiles still install.`, explains the otherwise surprising reason for an unused constant. It does not restate the assignment, name the PR, or narrate a measurement; keeping this one short why line meets DECISIONS. Its “before 4.0.12” is an existential reader statement, not a promise that every such Bundler installs on Ruby 4.

The test checks externally observable constant access, matching, and a deprecation warning. It fails without the restore and passes with it; it adds no internal-state or timing assertions. It is intentionally small. A negative relative-path assertion or explicit Windows branch assertion would be useful extra coverage, but the exact differential source/value checks already found no defect; neither is a must-fix for this report.

The final Redmine report uses plain complete sentences, no internal names/IDs, review metadata, Lowrail links, niche projects, or performance numbers. The repro and proposed code necessarily make it longer than a short PR description; they are the concrete bug report requested, not internal run narration. The old PR body was not reviewed for posting. No upstream PR, issue, comment or branch was created or pushed.
