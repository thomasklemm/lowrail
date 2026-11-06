---
id: CW1
repo: rails/rails
kind: fix
area:
reviewer:
branch: thomasklemm/where-empty-condition-binds
head: "41b234e19c7c2690b70098e054d21b39896fba82"
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
note:
passes: []
---

# Keep dropping an empty where condition that comes with values

#58427 moved parentheses ahead of placeholder dispatch when sharing bind handling between `where` and `find_by_sql`/`count_by_sql`. That also wrapped sanitizer fallback conditions, breaking chained empty conditions and changing generated SQL and predicate deduplication for other strings using the fallback.

Pass the original condition to sanitization and wrap only bound literals for `where`/`having`. This restores the previous fallback behavior while retaining `find_by_sql`/`count_by_sql` binds. Chatwoot's [`FilterService#query_builder`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L189) is one caller: it builds the SQL string and its values separately, then passes both to `where`. The string [starts empty](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L20), so an empty filter payload reaches this path on an already-scoped relation.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
