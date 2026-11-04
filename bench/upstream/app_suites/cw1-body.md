### Keep dropping an empty where condition that comes with values

`where("", values)` added nothing to the query on 8.1. Since #58427, `build_where_clause` [wraps the condition in parentheses](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/relation/query_methods.rb#L1995) before the [fallback that leaves it unchanged](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/activerecord/lib/active_record/sanitization.rb#L215), so the empty condition becomes `()` and the database rejects the query:

```ruby
Post.where(id: 1).where("", {}).to_a
# 8.1:  SELECT "posts".* FROM "posts" WHERE "posts"."id" = 1
# main: ... WHERE "posts"."id" = 1 AND (()) => syntax error
```

Chatwoot's [`FilterService#query_builder`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L189) (develop) builds the condition and its named values separately and calls `where(@query_string, @filter_values)`, with `@query_string` [starting as `''`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/filter_service.rb#L20). With no filters, its conversation filter now fails.

An empty condition is now used as it is, as when no values are given, so the where clause drops it again. Non-empty conditions are unchanged. The new test passes empty, named and positional values with an empty condition.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
