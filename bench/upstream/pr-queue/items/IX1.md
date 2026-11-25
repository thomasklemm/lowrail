---
id: IX1
repo: rails/rails
kind: fix
area: Active Record, schema statements (index definitions)
reviewer: "kamipo (#59850)"
branch: thomasklemm/index-definition-adapter-readers
head: "0f2f426a85b759ee74af71692a9651f7391a616f"
base: main
built_on: "cf0325a832"
depends_on: []
stacked_on:
alternative_of:
impact: "Unreleased since #59850 (merged 2026-11-18): IndexDefinition#lengths and #type raise NoMethodError on PostgreSQL, and all five adapter-specific readers on SQLite. Index-recreating migration helpers in GitLab and Mastodon (length: index.lengths), online_migrations 0.37 and active_record_doctor 2.1 (index.type; its issue #251) call them on any adapter. The fix restores 8.1's reader values on the abstract class; adapters keep overriding them. Census 11 (docs/upstream/rails-main-census-11.md#ix1)."
rank: 2
risky: false
state: built
pr:
note: "2026-11-25 (census 11): Ownership (2026-11-25): no rails/rails issue or PR (searched IndexDefinition, 59850, lengths opclasses); #59850 had no reviews or comments; not in our queue; not fixed on main cf0325a832; downstream report gregnavis/active_record_doctor#251 (sndrgrdn, 2026-11-20, open, no reply). built on main cf0325a832. New test fails on main on SQLite and PostgreSQL (NoMethodError 'lengths'), passes with the fix. migration/index_test, schema_dumper_test, schema_cache_test: SQLite 118 runs 0F, PostgreSQL (+ postgresql schema/adapter/active_schema tests) 373 runs 0F. Repro .amp/in/orb-backup/c11/repro/ix1_index_readers.rb: PG readers on the fix equal 8.1 byte for byte. Not covered: MySQL run, constructor keywords (cockroachdb builds IndexDefinition.new(opclasses:) and still raises; niche, record only), the schema cache that main dumps naming PostgreSQL::IndexDefinition, which 8.1 cannot load (rollback hazard, separate note). Needs: claude-code and thermos passes on this head, a call on whether kamipo prefers a deprecation over plain readers, and Thomas's OK. May qualify for the DECISIONS 'unreleased regression that breaks widely used apps or gems' exception."
passes: []
---

# Keep adapter-specific index readers on every `IndexDefinition`

#59850 moved `lengths`, `opclasses`, `type`, `include` and `nulls_not_distinct` into `MySQL::IndexDefinition` and `PostgreSQL::IndexDefinition`. Code that runs on any adapter still reads them on whatever `connection.indexes` returns, and on main that raises `NoMethodError`:

```ruby
# PostgreSQL
index = ActiveRecord::Base.lease_connection.indexes(:posts).first
index.lengths # 8.1: {}  main: NoMethodError
index.type    # 8.1: nil main: NoMethodError
```

Migration helpers that recreate an index after changing a column type do this, for example [GitLab's](https://github.com/gitlabhq/gitlabhq/blob/master/lib/gitlab/database/migration_helpers.rb) and [Mastodon's](https://github.com/mastodon/mastodon/blob/main/lib/mastodon/migration_helpers.rb) (`length: index.lengths`), and so do online_migrations and active_record_doctor ([gregnavis/active_record_doctor#251](https://github.com/gregnavis/active_record_doctor/issues/251)).

This defines the five readers on the abstract `IndexDefinition` with the values 8.1 returned for indexes that don't use them. The adapter subclasses keep their own readers, so nothing changes where the attribute is supported.
