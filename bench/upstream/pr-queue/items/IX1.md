---
id: IX1
repo: rails/rails
kind: fix
area: Active Record, schema statements (index definitions)
reviewer: "kamipo (#59850)"
branch: thomasklemm/index-definition-adapter-readers-2
head: "30368145ecb76500e10ae487c4ffff219b1403d7"
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
note: "2026-11-25 (builder, thermos-sol fix list): rebuilt as thomasklemm/index-definition-adapter-readers-2 @ 30368145ec on cf0325a832 with script/commit (Thomas author and committer, no trailers); the two-line comment above the readers deleted, code otherwise identical to 0f2f426a85; body: change paragraph first, :nodoc: noted, released-version line permalinks from the census record, doctor kept apart from the index-recreating helpers. Same commands as the pass: SQLite 116 runs 1383 assertions 0F 0E 5 skips; PostgreSQL 373 runs 2294 assertions 0F 0E 1 skip; the new test with the five readers reverted errors on both adapters (NoMethodError lengths). Old branch thomasklemm/index-definition-adapter-readers left as is. Needs a confirm pass on this head. Earlier: 2026-11-25 (census 11): Ownership (2026-11-25): no rails/rails issue or PR (searched IndexDefinition, 59850, lengths opclasses); #59850 had no reviews or comments; not in our queue; not fixed on main cf0325a832; downstream report gregnavis/active_record_doctor#251 (sndrgrdn, 2026-11-20, open, no reply). built on main cf0325a832. New test fails on main on SQLite and PostgreSQL (NoMethodError 'lengths'), passes with the fix. migration/index_test, schema_dumper_test, schema_cache_test: SQLite 118 runs 0F, PostgreSQL (+ postgresql schema/adapter/active_schema tests) 373 runs 0F. Repro .amp/in/orb-backup/c11/repro/ix1_index_readers.rb: PG readers on the fix equal 8.1 byte for byte. Not covered: MySQL run, constructor keywords (cockroachdb builds IndexDefinition.new(opclasses:) and still raises; niche, record only), the schema cache that main dumps naming PostgreSQL::IndexDefinition, which 8.1 cannot load (rollback hazard, separate note). Needs: claude-code and thermos passes on this head, a call on whether kamipo prefers a deprecation over plain readers, and Thomas's OK. May qualify for the DECISIONS 'unreleased regression that breaks widely used apps or gems' exception."
passes:
  - {reviewer: thermos-sol, head: "0f2f426a85b759ee74af71692a9651f7391a616f", orb: "T-01a212b7-add7-770d-90b0-f74112d7d64c", date: 2026-11-25, verdict: changes, open: "Both rubrics applied directly, without delegation. No functional defect found in the five fallback readers; SQLite 116 runs/1383 assertions/5 skips and PostgreSQL 373/2294/1 skip, both 0 failures/errors. New test errors without the readers on both adapters; live reader values match 8-1-stable, including non-default PostgreSQL overrides. Must fix before opening: delete the redundant added comment, remove Amp-Thread-ID from the commit, replace drifting caller links with released-version line permalinks, disclose the private API, and separate active_record_doctor's detector from index-recreating migration helpers. Detailed sentence audit, ownership/deprecation assessment and caller pins: docs/upstream/rails-main-census-11.md#ix1. No Rails changes made."}
---

# Keep adapter-specific index readers on every `IndexDefinition`

#59850 moved `lengths`, `opclasses`, `type`, `include` and `nulls_not_distinct` into `MySQL::IndexDefinition` and `PostgreSQL::IndexDefinition`. This defines the five readers on the abstract `IndexDefinition` again, with the values 8.1 returned for indexes that don't use them. The adapter subclasses keep their own readers, so nothing changes where an attribute is supported.

`IndexDefinition` is `:nodoc:`, but code that runs on any adapter reads these attributes on whatever `connection.indexes` returns, and on main that raises `NoMethodError`:

```ruby
# PostgreSQL
index = ActiveRecord::Base.lease_connection.indexes(:posts).first
index.lengths # 8.1: {}  main: NoMethodError
index.type    # 8.1: nil main: NoMethodError
```

Migration helpers that recreate an index after changing a column's type pass `length: index.lengths`: [GitLab v19.5.1](https://github.com/gitlabhq/gitlabhq/blob/449ed2875c2e3c4b51169484b799f4f803194ab5/lib/gitlab/database/migration_helpers.rb#L602-L606), [Mastodon v4.7.6](https://github.com/mastodon/mastodon/blob/a593c9420d2ff4664d448a9cb71bf8ed4ff0c29a/lib/mastodon/migration_helpers.rb#L666-L670) and [online_migrations 0.37.0](https://github.com/fatkodima/online_migrations/blob/82e264fd468158c6a4f68a866dbc5261e9b96b24/lib/online_migrations/change_column_type_helpers.rb#L437-L449), which also reads `index.opclasses`. Separately, [active_record_doctor 2.1.0](https://github.com/gregnavis/active_record_doctor/blob/62882337c817f0b9ca13df996c4cc8c804cfe29f/lib/active_record_doctor/detectors/extraneous_indexes.rb#L73-L77) compares `index1.type != index2.type` to find redundant indexes ([gregnavis/active_record_doctor#251](https://github.com/gregnavis/active_record_doctor/issues/251)).
