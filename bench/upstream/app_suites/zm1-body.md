### Deprecate passing a column name to PredicateBuilder#build_bind_attribute

Since #58479, the private [`PredicateBuilder#build_bind_attribute`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/relation/predicate_builder.rb#L128-L131) takes an Arel attribute, so callers that pass a column name, as on 8.1, raise `NoMethodError`. The change is unreleased, and these callers break:

- Zammad's [`User.by_login_case_sensitive`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/app/models/user.rb#L88) (develop) passes `:login`. Every login lookup raises, so about 2,500 of its specs fail on main; with this change they pass, apart from the new warning.
- authlogic 6.6.1's [`FindWithCase#sensitive_comparison`](https://github.com/binarylogic/authlogic/blob/9b8cfe8b14b9cc172d45c570f2823298b0bdf0ed/lib/authlogic/acts_as_authentic/queries/find_with_case.rb#L54) passes the login field as a String.
- Mastodon's [`Status::SafeReblogInsert`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/models/concerns/status/safe_reblog_insert.rb#L64) passes a String column name.

This accepts a String or Symbol again: it warns through `ActiveRecord.deprecator` and builds the bind from `table.arel_table[name]`, so the bind has the column's type as on 8.1. It stays a plain bind even when the column's type defines a comparison expression, because these callers build the left-hand side themselves. The only difference from 8.1 is the bind's name, which is now the resolved column name, as `where` gives. The test covers a Symbol, a String and a comparison-expression column.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md), part of my research project Lowrail).</sub>
