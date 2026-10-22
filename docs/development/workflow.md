# Bet-thread workflow

Every bet follows these rules, including branch-only prototypes. A green own
suite is necessary evidence, not proof of exactness or production admission.
Keep measured scope, baseline failures and unclosed obligations visible.

## Day one: try to disprove the optimization

- Run off/off exactness at **two independent seeds first**: status, body,
  all headers, ordered SQL and the other effects the proposed region removes.
  Resolve or explicitly refuse unstable comparisons before crediting on/off.
- After admission, replace a **transitive method** whose work is bypassed,
  then separately prepend a module on its lookup path. Test the real consumer,
  with diagnostic shadows off; require original behavior or visible refusal
  and fallback, not stale hits. An entry check or handwritten direct-method
  list does not certify later dispatch.
- First-render other routes, partials and layouts after admission. Preserve
  lazy loading and inspect holders/ancestry, not only response equality.
- Use asymmetric aliasing, frozen-object, subclass and Unicode witnesses.
  Check ownership, retained identities, mutation, evaluation order and
  once-only conversions at the actual boundary being optimized.
- Run the app's unchanged own suite as well. Equal failing outcomes are
  equivalence evidence, not a green suite; green outcomes do not discharge
  the counterexamples above.

## Review, then gate the exact head

Complete **Thermos and its in-scope fixes before the final gate run**. For an
upstream candidate, also complete semantic review before handing it off for
a PR. A finding is closed by a reproduced witness and a verified fix, not by
a green summary or a changed expectation.

Gates cover only the **exact tested head and environment**. Rebuild after
code changes or integration, and rerun affected gates after review fixes or
merges; an earlier green SHA does not cover the final tree. Keep per-suite
test/assertion/example counts, failures, errors and **named skips/pending
cases**, plus Ruby, seed, commands and `MT_CPU`. Do not reconcile differing
totals by dropping tests or counting skipped integrations as coverage.

Use a **Rack-3-only `GEM_HOME` for each Ruby** for the unbundled Rails gates;
keep `GEM_PATH` from falling back to a shared legacy Rack home. Preserve
other workloads' gems. Follow [testing.md](testing.md) for strict gates,
separate benchmark suites, required fixtures and prerequisite preparation.

## Publication and upstream handoff

- **Published branches merge, never rebase.** Refresh and merge the target
  into a published bet branch, preserve contributor ancestry and rerun
  affected gates on that integrated head. Never rewrite published history.
- Make upstream-bound commits with `/usr/bin/git`, bypassing automatic
  trailers. Verify both identities before committing:

  ```sh
  export GIT_AUTHOR_NAME="Thomas Klemm" GIT_AUTHOR_EMAIL="github@tklemm.eu"
  export GIT_COMMITTER_NAME="Thomas Klemm" GIT_COMMITTER_EMAIL="github@tklemm.eu"
  /usr/bin/git var GIT_AUTHOR_IDENT
  /usr/bin/git var GIT_COMMITTER_IDENT
  /usr/bin/git -c core.hooksPath=/dev/null -c user.name="Thomas Klemm" -c user.email="github@tklemm.eu" commit -m "Describe the change"
  /usr/bin/git log -1 --format=%B
  ```

  Keep the message trailer-free; inspect the resulting author and committer
  too. Attribution and push/PR authorization are separate obligations.
- **Only a separate PR thread opens upstream PRs**, after Thermos and
  semantic review are complete. A bet thread publishes its evidence and
  exact-head handoff; it does not open an upstream PR itself.
- Verify **every commit and thread link before reporting**. Resolve commit
  objects with `git cat-file -e SHA^{commit}`, check linked paths at that
  commit and check remote visibility. Open referenced thread links with
  the thread-reading tool; do not guess IDs. Link branch evidence to its
  full pinned GitHub URL, not a nonexistent main-worktree path. Report the
  actual delivery state and never present a branch-only result as on main.
