# `Arel::Table.new(name)` deprecation path

The [PG census](pg-census.md) found that rails/rails `b1650993b0` (#57829) changed `Arel::Table.new(name)` to
`Arel::Table.new(name:)` with no deprecation and no CHANGELOG entry. On Rails main a positional name raises
`ArgumentError: wrong number of arguments (given 1, expected 0)`; it broke Docuseal and Discourse directly and CASA
through flipper 1.4.2 (the latest release).

**Result:** one small PR candidate, not opened.

| Branch | Commit | Base |
| --- | --- | --- |
| [`thomasklemm/arel-table-positional-name`](https://github.com/thomasklemm/rails/tree/thomasklemm/arel-table-positional-name) | [`ca18f00739`](https://github.com/thomasklemm/rails/commit/ca18f0073971ef468f971f0bde9a2e47ac6910f7) | rails/rails main [`b084108cf3`](https://github.com/rails/rails/commit/b084108cf3) (merge of #59572) |

## History and maintainer position

* **#57829** "Refactor Arel::Table to use keyword name: argument" (gmcgibbon, self-merged 2026-06-24). Motivation:
  after #57642 added `klass:`, the name became optional, so callers with only a class had to pass `nil`. The PR says
  "The class is nodoc so it is private API." No CHANGELOG, no deprecation.
* After the merge, **byroot** (Rails core) commented on 2026-07-01: "For the record this change broke Intercom. I know
  `Arel` isn't really public API but in practice a ton of people and gems do use it. … IMO we should probably support
  the old positional argument with a deprecation, otherwise I doubt I'll be the only one to run into this."
  **joelhawksley** (2026-10-05): it broke GitHub too; "an easy fix in a single file so I'm indifferent about doing a
  deprecation cycle." No maintainer replied against a shim, and nobody has proposed one.
* Searches of rails/rails PRs and issues ("Arel::Table positional", "Arel::Table deprecation", "Arel::Table.new name
  keyword", and others) found no shim PR, no issue and no rejection. #57829 is the only hit.
* The change is on main only: `8-1-stable` still has `initialize(name, as: nil, klass: nil, type_caster: …)`. So the
  break lands for everyone upgrading to 8.2, and a deprecation before 8.2.0 keeps 8.1 code working.
* **Old forms:** `as:`, `klass:` and `type_caster:` were already keywords in 8.1 (and `as:` in every Arel since 6.0),
  so the positional table name is the only form to restore.
* **How Rails treats Arel:** `module Arel # :nodoc: all`, so no API docs and no stability promise. But Arel changes
  reach the Active Record CHANGELOG when users notice them (for example the `Arel.sql` binds entries), and a core
  member asked for this deprecation. A CHANGELOG note alone would document the break without avoiding it; the shim
  is ten lines, so the PR does both.

## Callers found

| Caller | Call | Affected on Rails main |
| --- | --- | --- |
| flipper-active_record 1.4.2 (latest) | `::Arel::Table.new(@feature_class.table_name.to_sym)` in `Adapters::ActiveRecord#get_all` | Yes (fixed on flipper main, flipper#1003, unreleased) |
| Docuseal `6c416dd` | `Arel::Table.new(:webhook_urls)` | Yes |
| Discourse `0f52471` (json_api_kit) | `Arel::Table.new(table_name)` | Yes |
| Intercom, GitHub | (per #57829 comments) | Yes, fixed in-app |
| cancancan 3.7.0 | `Arel::Table.new(@model_class.send(:table_name))` in `sanitize_sql_activerecord4` | **No.** Only `ActiveRecord4Adapter` (AR < 5.0) reaches it; `ActiveRecord5Adapter` overrides `sanitize_sql`. The PG census listed it; that was wrong. |

## The change

```diff
-    def initialize(name: nil, as: nil, klass: nil, type_caster: klass&.type_caster)
+    NOT_GIVEN = Object.new.freeze # :nodoc:
+    private_constant :NOT_GIVEN
+
+    def initialize(positional_name = NOT_GIVEN, name: nil, as: nil, klass: nil, type_caster: klass&.type_caster)
+      unless NOT_GIVEN.equal?(positional_name)
+        raise ArgumentError, "Pass the table name either positionally or as name:, not both." if name
+
+        ActiveRecord.deprecator.warn(
+          "Passing the table name to Arel::Table.new as a positional argument is deprecated " \
+          "and will be removed in Rails 9.0. Use Arel::Table.new(name: table_name) instead."
+        )
+        name = positional_name
+      end
+
       raise ArgumentError, "A name or klass is required." unless klass || name
```

* A sentinel rather than `nil` as the default, so 8.1's `Arel::Table.new(nil, klass: Model)` also warns (and keeps
  working).
* Positional name plus `name:` raises: that combination never worked, and silently preferring one would hide a bug.
* `require "active_record/deprecator"` at the top of `arel/table.rb`, because Arel's own tests (and `require "arel"`)
  load Arel without Active Record. The sentinel is frozen, so the table stays Ractor-shareable.
* Removal in Rails 9.0, the version other current Active Record deprecations name.
* CHANGELOG entry in Active Record. Tests in `test/cases/arel/table_test.rb`: positional name with `as:` (warning
  text, `name`, `table_alias`, equality with the keyword table, generated SQL), positional `nil` with `klass:`,
  both forms raising, and no warning for `name:`. On main all four fail (3 errors, 1 failure).

## Verification

Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`, base `b084108cf3` and the branch, in the same orb:

| Suite | base | branch |
| --- | --- | --- |
| `rake test:arel` | 808 runs, 1,375 assertions, 0 F, 0 E | 812 runs (+4), 1,388 assertions, 0 F, 0 E |
| `rake test:sqlite3` | 10,258 runs, 0 F, 4 E, 52 skips | 10,262 runs (+4), 0 F, 4 E, 52 skips |
| `rake test:postgresql` (PostgreSQL 15) | 11,178 runs, 40,483 assertions, 0 F, 0 E, 31 skips | 11,182 runs (+4), 40,524 assertions, 0 F, 0 E, 31 skips |

The 4 SQLite errors are the same on both: structure dump/load tests that shell out to the `sqlite3` CLI, which this
orb lacks. RuboCop on both changed files: no offenses.

**flipper 1.4.2** ([`flipper_repro.rb`](../../bench/upstream/arel_table_positional/flipper_repro.rb), the released
flipper-active_record adapter on SQLite, `enable(:search)`, `enable_percentage_of_actors(:beta, 25)`, then `get_all`):

* base: `ArgumentError: wrong number of arguments (given 1, expected 0)`.
* branch: `{"search" => {boolean: "true"}, "beta" => {percentage_of_actors: "25"}}` with two deprecation warnings
  (one per `Arel::Table.new`).

CASA itself was not booted: the PG census app copies aren't set up in this orb, and its boot path into flipper is
the same `get_all` call.

## Draft (not opened)

**Deprecate a positional table name in `Arel::Table.new`**

> #57829 made the table name of `Arel::Table.new` the `name:` keyword, so `Arel::Table.new(:users)`, which Rails 8.1
> and earlier accept, now raises `ArgumentError` on main. Arel is nodoc, but gems and apps call it: flipper 1.4.2 (its
> latest release) fails in `Flipper::Adapters::ActiveRecord#get_all`, and so do Discourse and Docuseal; the comments
> on #57829 report Intercom and GitHub.
>
> A positional name now keeps working with a deprecation warning and behaves exactly as `name:`, as suggested in
> #57829. Passing both raises, since that never worked. `as:`, `klass:` and `type_caster:` were already keywords, so
> nothing else changes.
>
> | `Arel::Table.new` | 8.1 | main | this PR |
> | --- | --- | --- | --- |
> | `(:users)` | works | `ArgumentError` | works, deprecated |
> | `(nil, klass: User)` | works | `ArgumentError` | works, deprecated |
> | `(name: :users)` | — | works | works |
>
> flipper-active_record 1.4.2's `get_all` runs again on this branch.

## Limits

* Local suites only; no hosted CI run was asked for (the fork's CI runs on push).
* No Thermos review yet: per [DECISIONS](../DECISIONS.md) every PR gets one before opening.
