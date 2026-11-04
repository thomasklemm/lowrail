Title: **Accept bind values in `where!` and `having!` again**

#59579 changed `where!` and `having!` from `(opts, *rest)` to `(opts, rest = FROZEN_EMPTY_ARRAY)`, so that `where` and `having` could pass their binds as one array. The change is unreleased.

Code that calls the bang methods with bind values now breaks:

| Call | 8.1 | main |
| --- | --- | --- |
| `where!("id = ?", 1)` | `WHERE (id = 1)` | `NoMethodError: undefined method 'empty?' for an instance of Integer` |
| `where!("id = ? OR id = ?", 1, 2)` | `WHERE (id = 1 OR id = 2)` | `ArgumentError` |
| `where!("id IN (?)", [1, 2])` | `WHERE (id IN (1, 2))` | `ActiveRecord::PreparedStatementInvalid` |
| `where!("url ILIKE :url", url: "%x%")` | `WHERE (url ILIKE '%x%')` | `WHERE ((url ILIKE :url))`, with no error |

Discourse's `Permalink.filter_by` uses the last form, so its admin search silently finds nothing. Canvas's SIS exporter and crono_trigger's web UI pass `?` binds. Gems that override `where!(opts, *rest)` and call `super`, such as mobility and active_record-acts_as, now also receive `rest` nested one level deeper.

This restores the splat signatures and has `where`, `having` and `merge(where: [...])` splat their arguments into them, as in 8.1, so permitted params are checked and overrides are reached as before. Only the frozen default in `build_where_clause` stays. The new test errors without the fix.
