### Accept bind values in `where!` and `having!` again

#59579 changed `where!` and `having!` from `(opts, *rest)` to `(opts, rest = FROZEN_EMPTY_ARRAY)`. Both are `:nodoc:` and the change is unreleased, but applications and gems call them with bind values or override them and call `super`:

- [Discourse](https://github.com/discourse/discourse/blob/0f746ecc2eb1a601ba3bd1e5bcff3e7019ef509e/app/models/permalink.rb#L92): `permalinks.where!("url ILIKE :url OR external_url ILIKE :url", url: "%#{url}%")`
- [Canvas](https://github.com/instructure/canvas-lms/blob/1c9f0bb8013ed69c4f2efe11fd483025469b7e6c/gems/plugins/account_reports/lib/account_reports/sis_exporter.rb#L382-L385): `courses.where!("(courses.workflow_state='deleted' AND courses.updated_at > ?) …", 120.days.ago)` (shortened)
- [crono_trigger 1.0.0](https://github.com/joker1007/crono_trigger/blob/ebd776373eb3ad2b9bbd4af81cf2f9b153071c50/lib/crono_trigger/web.rb#L178): `rel.where!("executed_at >= ?", Time.parse(params[:from]))`
- [mobility 1.3.2](https://github.com/shioyama/mobility/blob/a776667737cf0bd1645db83cd6b3d1447e566812/lib/mobility/plugins/active_record/query.rb#L132) and [active_record-acts_as 5.2.0](https://github.com/chaadow/active_record-acts_as/blob/875cd6d8aa5e36c8eeb2272b2d0e09f0100846ce/lib/active_record/acts_as/querying.rb#L4): `def where!(opts, *rest)`

On main:

| Call | Result |
| --- | --- |
| `where!("id = ?", 1)` | `NoMethodError` |
| `where!("id = :id", id: 1)` | `:id` stays in the SQL; PostgreSQL raises a syntax error |
| `where("id = ?", 1)` with an override | the override receives `rest = [[1]]` |
| `merge(where: [permitted_params])` | `ArgumentError` |

This restores the splat signatures, and `where`, `having` and `merge` splat into them again, as in 8.1. The other allocation optimizations from #59579 remain. The tests cover `?`, named and Array binds, an override, and `merge` with permitted params.

---

<sub>Found by diffing the public and `:nodoc:` API of Rails 8-1-stable and main against gem and app callers ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/api-regressions.md), part of my research project Lowrail).</sub>
