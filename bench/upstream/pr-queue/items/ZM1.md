---
id: ZM1
repo: rails/rails
kind: restore
area: Active Record predicate builder
reviewer: "matthewd (author of #58479)"
branch: thomasklemm/bind-attribute-column-name
head: "0db82ad5cc"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: "Zammad's login lookups (2,498 specs), authlogic 6.6.1, Mastodon's reblog insert and DocuSeal stop raising NoMethodError; fixes unreleased #58479"
rank: 2
risky: true
state: closed
pr: 59663
note: "opened as draft 2026-11-05; supersedes M1's record-only; earlier heads 72d0b21869, ebbb6c49be; body shortened 2026-11-05 per DECISIONS PR descriptions, dropped: Zammad's 2,498 failing specs, the 300 Ir (+1.2%) is_a? cost, alias and comparison-expression types and the model-less test, in docs/upstream/app-suites.md#zammad"
passes:
  - {reviewer: skeptic, head: unrecorded, date: 2026-11-05, verdict: nits, open: "first round, applied"}
  - {reviewer: sol, head: "72d0b21869", date: 2026-11-05, verdict: changes, open: "8.1's bind construction, the hot-path check, tests and body applied; Restore support CHANGELOG wording not"}
  - {reviewer: skeptic, head: unrecorded, date: 2026-11-05, verdict: nits, open: "second round, applied"}
  - {reviewer: astra, head: "ebbb6c49be", date: 2026-11-05, verdict: nits, open: "round 2: approve, no must-fix; three test/body nits applied in 0db82ad5cc"}
  - {reviewer: sol, head: "0db82ad5cc", date: 2026-11-05, verdict: approve, open: ""}
  - {reviewer: astra, head: "0db82ad5cc", date: 2026-11-05, verdict: nits, open: "production code and CHANGELOG verified unchanged; nits: assert_equal on the full type in the model-less test, assert_same type_caster in the duck-typed test"}
  - {reviewer: skeptic, head: "0db82ad5cc", date: 2026-11-05, verdict: nits, open: "optional: the is_a? ordering comment; clearer Rails 8.1 and earlier wording in message and CHANGELOG; alias test restates main; 300 Ir figure not rechecked"}
---

# Accept a column name in build_bind_attribute again, deprecated

Since #58479, the internal [`PredicateBuilder#build_bind_attribute`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/relation/predicate_builder.rb#L128-L131) takes an Arel attribute, so callers that pass a column name, as on 8.1, raise `NoMethodError`. The change is unreleased, and these callers break: Zammad's [`User.by_login_case_sensitive`](https://github.com/zammad/zammad/blob/64e70ff1590358310c463637018497413cc4aabf/app/models/user.rb#L88) (develop) passes `:login`, so String login lookups through this scope raise, and authlogic 6.6.1's [`FindWithCase#sensitive_comparison`](https://github.com/binarylogic/authlogic/blob/9b8cfe8b14b9cc172d45c570f2823298b0bdf0ed/lib/authlogic/acts_as_authentic/queries/find_with_case.rb#L54) and Mastodon's [`Status::SafeReblogInsert`](https://github.com/mastodon/mastodon/blob/ca2f092f4f580b1993bae3ac4f4742b748f18ad1/app/models/concerns/status/safe_reblog_insert.rb#L64) pass a String.

For a String or Symbol, this warns through `ActiveRecord.deprecator` and returns the same bind as 8.1. Arel attributes pay one extra `is_a?`. On 8.1 an Arel attribute falls back to the default value type, so the message tells code that supports Rails 8.1 and earlier to keep passing the column name there.

---

<sub>Found by running the test suites of open-source Rails apps on Rails main and 8-1-stable side by side ([record](https://github.com/thomasklemm/lowrail/blob/e69e4ffa6e4d571ef8fb36df56a84a316e3723ac/docs/upstream/app-suites.md#zammad), part of my research project Lowrail).</sub>
