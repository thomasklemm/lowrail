---
id: CW1
repo: rails/rails
kind: fix
area:
reviewer:
branch: thomasklemm/where-empty-condition-binds
head: "971ebc0e9b10706bbf16c27b6c1f1c6eedaf644f"
base: main
built_on: "224f5b1563cc9a7da0fe69ff1ce92bb0c1c74a48"
depends_on: []
stacked_on:
alternative_of:
impact: see docs/upstream/contributions.md
rank:
risky: false
state: ready
pr: 59642
note: "2026-11-06: reply to matthewd posted (discussion_r4492126885) offering option B (thomasklemm/where-group-bound-literals 10346a258e, explicit bound-node grouping fix since 7.1) with this exact-8.1 head as fallback; title/body updated to this head. 2026-11-06 16:44 UTC matthewd (4495087542): \"I think that alternative branch is the better fix.\" PR switched to option B 10346a258e (force-push with lease on 805ab06262), retitled, body rewritten, replied \"Switched the PR to it.\" (discussion_r4495214214). 805ab06262 remains the exact-8.1 fallback commit. 2026-11-10: rebased onto main 224f5b1563, head 971ebc0e9b, force-pushed with lease on 10346a258e. Only CHANGELOG conflicted; CW1 entry first, main entries unchanged. SQLite PR tests: 3 runs, 21 assertions; focused relation/where-clause, sanitize and bind tests: 1,094 runs, 3,197 assertions, 0 failures/errors, 1 existing SQLite skip. RuboCop 1.90.0: 4 files, no offenses. Thomas author/committer, no trailers. PR remains ready and mergeable; title/body unchanged, no comment posted."
passes: []
---

# Group bound SQL literals in `WhereClause` like other SQL literals

`WhereClause` groups String and `SqlLiteral` predicates so that a top-level `OR` can't escape a neighbouring `AND`, but it doesn't group `BoundSqlLiteral`. Placeholder conditions were only safe because #51139 gave the bound literals it builds textual parentheses. An explicitly passed bound node has been emitted bare since 7.1: `Item.where(Arel.sql("n = ? OR n = ?", 1, 3)).where(n: [2, 3])` produces `WHERE n = 1 OR n = 3 AND "items"."n" IN (2, 3)` and returns extra rows. The same happens through `merge`, association scopes, STI, `having`, `eager_load` join conditions, `invert_where`, `update_all` and `delete_all`.

#58427 moved those parentheses ahead of placeholder dispatch, so string conditions that are sanitized into plain SQL got them too, on top of `WhereClause`'s grouping. Their SQL changed, identical conditions stopped deduplicating on merge, and `Post.where(author_id: 1).where("", {})` produced `AND (())`.

This groups `BoundSqlLiteral` in `WhereClause` like `SqlLiteral` and drops the textual parentheses, so `where` and `having` group both in one place. Results change only for explicit bound nodes. SQL text also changes in two places: placeholder conditions under `where.not` and `or` lose a redundant pair, which is 7.1's output again, and an explicit bound node that carries its own parentheses gains one. A string condition and the same explicit bound node now compare equal. `find_by_sql` and `count_by_sql` stay unwrapped.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/where-parens-history.md), part of my research project Lowrail).</sub>
