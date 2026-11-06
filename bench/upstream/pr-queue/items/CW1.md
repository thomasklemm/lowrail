---
id: CW1
repo: rails/rails
kind: fix
area:
reviewer:
branch: thomasklemm/where-empty-condition-binds
head: "805ab062624df73231d665c0fcf0131ec36d9ee0"
base: main
built_on:
depends_on: []
stacked_on:
alternative_of:
impact: see docs/upstream/contributions.md
rank:
risky: false
state: ready
pr: 59642
note: "2026-11-06: reply to matthewd posted (discussion_r4492126885) offering option B (thomasklemm/where-group-bound-literals 10346a258e, explicit bound-node grouping fix since 7.1) with this exact-8.1 head as fallback; title/body updated to this head."
passes: []
---

# Parenthesize only bound string conditions in `where` and `having`

#58427 moved the parentheses ahead of placeholder dispatch when it shared bind handling between `where` and `find_by_sql`/`count_by_sql`. That also wrapped string conditions without placeholders, which are sanitized into plain SQL and already grouped by `WhereClause`. They now get a second pair, which changes their SQL and stops identical conditions from being deduplicated on merge. An empty condition with values is no longer dropped when chained onto another condition: `Post.where(author_id: 1).where("", {})` produces `AND (())`.

This passes the original condition to `bound_sql_literal_for` and has `where`/`having` ask it to wrap only the bound literals it builds, so those conditions generate the same SQL as on 8.1. `find_by_sql`/`count_by_sql` keep their binds.

Chatwoot's [`FilterService#query_builder`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L189) is one caller: it builds the SQL string and its values separately, then passes both to `where`. The string [starts empty](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L20), so an empty filter payload reaches this path on an already-scoped relation.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
