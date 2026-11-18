# Rules review: rails/rails and ruby/ruby PRs (2026-11-18)

The open rails/rails and ruby/ruby PRs, checked against the guard and comment rules in
[DECISIONS](../DECISIONS.md#submission-queue-2026-11-03) (`a85fd9b9`, `9fa887a3`) and against
[PR descriptions](../DECISIONS.md#pr-descriptions-thomas-2026-11-03-to-11-05), "Leave out". K1, PR59574 (code) and
ZRS1 were left alone; only PR59574's body was checked. A second thread covers the other repositories.

Guards reuse [guard-simplification-2026-11-18](guard-simplification-2026-11-18.md), with a second look at each guard
it kept ("would a human have written this here?"). The comment audit is new: every comment added in the PR diff, in
lib and tests, is marked keep, shorten or remove. Each diff was taken against the merge base of the queue head.

Nothing upstream changed. No PR branch was pushed and nothing was posted. Candidates are new fork branches with the
suffix `-lean`. Each is one commit with the original message and author date, Thomas as author and committer, made with
`/usr/bin/git commit-tree`, and no trailers (checked with `git cat-file` and `%(trailers:only)`). Corrected bodies are
in the items and have not been PATCHed.

## State on 2026-11-18

All 22 PRs are open and mergeable, and every fork branch is at the item's `head`. Live bodies equal the items, except
ZWB1, where only the item's sections were out of place. No PR has a conflict, so no `rebase` was run.

Red checks:

- **#59817 (FLK1b):** Buildkite 136661 failed only in `StrictLoadingTest#test_strict_loading_with_has_many_through_preloaded_alone_and_with_nested_association`
  on postgresql (4.0), seed 43812. **The failure is not ours.** The same assertion failed on main in 136568 (before
  `b835fe05b8`), and on an unrelated PR in 136761 (cole-robertson's fix-lease-connection-after-disconnect, seed 13952),
  whose head contains `b835fe05b8`. So the fixture fix did not end the flake on main. Of 36 failed builds in
  136560–136797, 3 failed this test. Our branch only touches the Ractor proxy.
- **ruby#19492, #19681:** only the two Windows 11-arm jobs fail, in setup, which is known and not ours.

Maintainer questions: none is unanswered. On ruby#19492, k0kubun's only entry on 2026-10-22 is his approval ("sure.")
on `3212a9c`. `git range-diff` shows that commit identical to head `e8629f928a`. It has been approved for 27 days
without merging, so the one neutral 14-day note
([DECISIONS](../DECISIONS.md#submission-queue-2026-11-03)) is due if Thomas wants it. ruby#19487 has the same state:
approved on 10-22, and our 11-04 comment explained the change made after the approval. On ruby#19680 (ZWB1), our size
reply to k0kubun was posted at 09:29 and has no answer yet; tenderlove's #19962 is still open.

## Rails

### A1 (#59851)

Guard `unless scope_chain_items.empty?` **keep**: it is the fix. Test comment `# Array#- hashes its elements,
serializing bind values, once both sides have more than 16.` **keep**: without it, a reader would shrink the 17 keys and
lose the repro. Body: no change.

### AM1 (#59832)

Guard `return [] if @errors.empty?` **keep**: this is fatkodima's suggested form. No comments. Body: no change. Its
benchmark-ips output starts with the `ruby -v` line, which includes the revision. That is the tool's output and the
Rails convention, so it stays (the same holds for FB1, K6 and MB1).

### CW2 (#59644)

There are no guards and no comments. The private `_find_all` hook is what the PR restores. Body: 176 words. "The
tests cover each of the three shapes…" describes the diff, and "121 of its mailer specs fail … and pass with this
change alone" is a suite count. **Proposal:** the body is now 141 words in the item, and it keeps the FileSystemResolver
boundary in one clause.

### E2 (#59671, draft, stacked on E2b)

There are no guards: `COLLATE NOCASE` and `downcase(:ascii)` are the fix. One test comment, `# Check that metadata comes
from the temporary CREATE statement.`, is marked **remove**. E2b asserts the same collation without a comment, and the
assertion already says what it checks. **Candidate:** `thomasklemm/sqlite-schema-readers-table-name-case-stacked-lean`
[`9bf31a08d7`](https://github.com/thomasklemm/rails/commit/9bf31a08d7c4eb2213da001b06a15155aecd3578), which is still on
`bc90b487f2`. SQLite adapter tests ran 237 times with 0 failures, plus the 4 known errors from the missing `sqlite3`
CLI. RuboCop is clean, and the merge-tree with main is clean. If it is adopted, the stacked line names the new SHA. The
body is otherwise fine.

### E2b (#59668)

The SQL condition is the fix. There are no comments. Body: no change.

### FB1 (#59824, draft)

The `match?`/`end_with?`/`empty?` checks before each copy **keep**: skipping the copy is the whole change, and every
check tests only what the next line would replace. No comments. Body: no change.

### FLK1 (#59812)

The test helper has no guards, and the PR removed the only comment. Body: "The Ractor connection proxy fix that was also
here is now #59817." is **cut** (review history). The 189-of-200 rate stays, because it is the evidence for a flaky test,
not a suite count.

### FLK1b (#59817)

The guards in `unpin_main_pool` were `pools&.pop`, `pools&.empty?` and `pool && !pool.discarded?`. The `&.` and
`pool &&` are **dropped**: an unpin runs only after a successful pin pushed the pool. `pin_connection!` calls
`unpin_main_connection!` only once `pin_main_connection!` has returned, and `unpin_connection!` raises before its ensure
when nothing is pinned. `discarded?` **keep**: it covers the forked child, which a test covers. The test guard
`if Process.respond_to?(:fork)` **keep**: it is Rails' idiom. Comments: none added; the PR removed one.
**Candidate:** `thomasklemm/fix-ractor-proxy-unpin-lean`
[`7181059af1`](https://github.com/thomasklemm/rails/commit/7181059af13136c1ee640707146d23068a5713e2), on main
`8e097e9d81`. The full `rake test:sqlite3:ractor` ran 9,666 times with 0 failures (4 sqlite3-CLI errors), and
`ractor_connection_handling_test` on sqlite3 ran 63 times with 0 failures. RuboCop is clean. Pushing it would also
replace the red flake run. Body: "Split out of #59812, as asked there." is **cut**.

### K6 (#59804, approved by seanpdoyle)

`unless options.key?("id")` **keep**: it is the reviewer's suggestion. No comments. Body: "As suggested in review" is
**cut**.

### MB1 (#59810)

The four clauses (`values.empty?`, `!other.null_relation?`, empty where and having) **keep**: each one has a test line
(dedup, `none.only(:order)`, `none.except(:where)`). No comments. Body: 386 words. **Proposal:** 317 words. The boundary
paragraph is shortened. "Without YJIT it is 17 to 22 percent faster" is cut because it doesn't say what was measured.
The `.to_a` noise sentence and the per-page list are cut too. The #59212 sentence stays, since that PR is still open
and a reviewer would ask about it.

### OP1 (#59661, risky)

**Needs an update:** main's `046cca206b` renamed its hook to `initializer "action_dispatch.ractorize"`. The merge is
still textually clean, but the result has two initializers with that name. Second look at the guards: the
`parameter_parsers_frozen` flag, the `ObjectSpace.each_object(ClassMethods)` walk (no other `before_ractorize` hook
walks ObjectSpace) and `&.freeze` protect parsers that Rails never parses with. `params_parsers` reads only
`ActionDispatch::Request.parameter_parsers`. **Candidate:** `thomasklemm/parameter-parsers-register-in-place-lean`
[`58c3765e8a`](https://github.com/thomasklemm/rails/commit/58c3765e8a424c69236f755b5abfced112715ab2), on main
`8e097e9d81`. It uses `DEFAULT_PARSERS.dup` on include and an unfrozen writer, and adds one
`ActionDispatch::Request.parameter_parsers.freeze` line to main's existing hook (lib +3/−2 instead of +16/−3). Two webservice
tests and the railties includer test go. The two remaining tests catch the no-dup and writer-freeze mutants. Action Pack
ran 4,526 times with 0 failures or errors, `railties/test/application/ractors_test.rb` with `RACK=head` 21 times with 0
failures, and RuboCop found no offenses in 4 files. The accepted difference, that other includers' parsers and parsers
assigned after `ractorize!` stay unfrozen, is one sentence in the body under For Thomas. No comments either way.

### OP8 (#59662)

`!type.respond_to?(:freezable_default?) || …` **keep**: it is Rails' idiom for optional type methods, and duck types
are real attribute types (tested). Comment `# The coder may load even a nil default as a container.` **keep**: without
it, a reader would change `false` to Mutable's `value.nil?`. Body: "(on an earlier revision of this change, with the
same behaviour)" is **cut**.

### PR59617 (#59617, draft)

There are no new guards: the `utc_offset ==` check and the fallback are the fix. Lib comment `# Prefer this time's
offset, so a repeated hour keeps the occurrence it is in.` **keep**. It replaces upstream's 11-line comment, and without
it, a reader would go back to `Time.new(…, zone)`. The test comments follow the file's own style and stay: trailing
`# 2026-10-25 02:30:00 +0100` values and the two-line "DST ended just before … rolled back 1 hour". The Dublin
comment's third line ("In tzdata, Ireland's winter time counts as DST") is why that case exists. Body: no change.

### UG82, UG82H, UG82P (#59675, #59734, #59735)

These are guide-only, with no guards or comments. Main's guide moved once (`e33853bf09`, typos elsewhere), and the
merges are clean. Bodies: no change.

### PR59574 (body only)

The third paragraph restated the calls from the first two and that "flipper 1.4.2's `get_all` runs again". **Cut**,
and its `nil, klass:` example moved into the second paragraph. The both-given sentence stays, as the one accepted
difference.

## Ruby

### RUBY19487 (ruby#19487, approved)

The method-ISEQ and T_CLASS/T_MODULE guard **keep**: it is a correctness property (the rebound block test). The
3-line lib comment **keep**: both sentences are reasons, the neighbouring send comment is 4 lines, and the code is
approved. The test's `if stats[:all_stats]` is the file's idiom. Body: the "three interleaved runs" method clause and
"New tests cover …; `make yjit-check` passes" are **cut**.

### RUBY19492 (ruby#19492, approved)

Comment `// Count dispatches even when the call raises or leaves nonlocally.` **keep**: it is why the increment moved.
The heredoc comment `# Warm the operation without compiling the measurement loop below.` **keep**: it explains the 100
vs 10 iterations against `call_threshold: 30`. Body: the regression-check paragraph is **cut** (method, and "these
timings don't measure the cost", which is a non-claim), and so is the test/`make yjit-check` paragraph.

### RUBY19659 (ruby#19659)

`argc == 1 && lead_num > 0 && !ambiguous_param0` and `argc < lead_num` are the change. The lib comments are
upstream's, adapted, plus one line on auto-splat: **keep**. Test comments: five explanatory comments are **removed**
(vm_callee_setup_block_arg restated, lambda path, guarded ISEQ, auto-splat). "Integer#times does `yield i`; a block
without params used to fall back" is **shortened** to its first clause (history). "Pass the same block ISEQ on every
call…" **keep**: without it, a reader would restore `test { 1 }`. **Candidate:**
`thomasklemm/zjit-yield-surplus-args-lean`
[`2ec80c1bf2`](https://github.com/thomasklemm/ruby/commit/2ec80c1bf24c1549bd7c75be202b16732342a963). It changes only
comments (`git diff` has no other lines), and `cargo check -p zjit --tests --features disasm` is clean. `make zjit-check`
was not run. Body: the `test_getblockparamproxy` sentence and the interleaved-rounds clause are **cut**. **Open:**
DECISIONS wants ZJIT stats as a diff, not a table. The raw `--zjit-stats` output isn't in the record, so the table stays
until the stats are rerun.

### RUBY19681 (ruby#19681)

`survivors.len() > num_live_across` before sorting **keep**: it is a hot-loop fast path in a PR about that loop. The
`binary_search` dedup **keep**: it prevents pushing twice. Lib comments: the 5-line table comment is **shortened** to the
2-line layout invariant, `// Reused for every CCall` is **removed**, and the spill-cases block, moved from upstream,
plus "Survivors are sorted by VRegId so the push order is stable." **keep**. The test comments (`// v1 is live across
the first CCall only…`, `// v4 is defined between…`) **keep**: the assertion can't be read without them.
**Candidate:** `thomasklemm/zjit-caller-saved-regs-stopgap-lean`
[`5df7fefa50`](https://github.com/thomasklemm/ruby/commit/5df7fefa50a617f5727704e82df7942de80af3f5). It changes only
comments, and `cargo check` is clean as above. Body: 362 words, with a master SHA, the command, the cross-check method,
run ranges, Callgrind percentages, a `run_benchmarks` non-claim and headings. **Proposal:** 208 words, keeping the
script and both stats diffs.

### ZS1 (ruby#19912)

The `rb_method_basic_definition_p(Symbol#to_proc)` and `!non_root_box_created()` guards, plus the runtime
`METHOD_ENTRY_BASIC` check, are VM invariants and stay. The `vm_args.c` comments move verbatim from existing code. The
2-line `zjit.c` comment explains why the flag is rechecked on every conversion, so it stays. The doc comments on
`gen_symbol_block_handler`, `BlockArgSymbol` and the two `exit_state` fields follow the file's style for fields and stay.
The HIR comments are adapted from upstream's or give the reason for a guard, so they stay. No test comments. Body:
`run_benchmarks.rb` and the stats diffs are in the tools' format, which DECISIONS asks for, including its version lines.
No change.

### ZWB1 (ruby#19680)

The cache applies only when a payload exists, which keeps memory flat, as k0kubun asked. The borrow comment and the
one-line field doc stay. The live body is fine. The item had the posted comment and the posted reply outside For Thomas,
with the reply marked "draft, not posted"; both now sit under For Thomas.

## Ranked proposals

| # | Item | Proposal | Fork SHA | Checks | Thomas decides |
| --- | --- | --- | --- | --- | --- |
| 1 | OP1 | -lean: one freeze in main's hook, no flag or ObjectSpace walk | `58c3765e8a` | AP 4,526 runs, ractors_test 21, RuboCop, 0 F/E | adopt it (claude-code and Astra pass, then lease-push and PATCH) |
| 2 | FLK1b | -lean without `&.` guards, and a fresh CI run | `7181059af1` | sqlite3:ractor 9,666 runs, 0 F; RuboCop | push it, or ask for a Buildkite retry only |
| 3 | MB1, CW2, RUBY19681 | bodies cut to the rules (317, 141, 208 words) | — | — | PATCH |
| 4 | RUBY19681, RUBY19659 | comment-only -lean heads | `5df7fefa50`, `2ec80c1bf2` | cargo check --tests; code diff empty | push (reruns CI, notifies) or leave the code |
| 5 | RUBY19492, RUBY19487, PR59574, K6, OP8, FLK1, FLK1b | one-clause body cuts | — | — | PATCH |
| 6 | E2 | -lean drops one test comment | `9bf31a08d7` | SQLite adapter 237 runs, 0 F; RuboCop | push to the draft, with the stacked-line SHA |
| 7 | RUBY19492 | the one neutral 14-day note | — | — | post it or not |
