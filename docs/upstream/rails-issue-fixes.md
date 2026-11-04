# Rails issue fixes: triage of open rails/rails bug reports (2026-11-04)

Goal: fix real bugs that users reported, as small and obvious changes. Scope: open rails/rails issues created since
2025-11-04, plus older open issues with activity since 2026-01-01. Left out: feature requests, docs and performance
reports; issues with an open PR attached or a linked fix (cross-referenced open PRs, checked one by one); issues a
maintainer called intended behaviour; anything security-related (Rails' private process). Every remaining issue's
reproduction ran on rails/rails main [`9b116f1fed`](https://github.com/rails/rails/commit/9b116f1fed) with Ruby
4.0.9, SQLite in memory and PostgreSQL 15.

**Result.** 132 open issues were in scope and only one fix qualified, not the three to five aimed for. Almost every
reproducible bug already has an open PR (89 of the 132). Of the eleven issues left after the filters, five still
fail on main and two more fail in their reporters' own tests; only one of them has a small fix that changes nothing else:

| Fix | Issue | Branch @ SHA | Size | Status |
| --- | --- | --- | --- | --- |
| I1: grouped keys of columns unknown to the schema are cast from the result | [rails/rails#48420](https://github.com/rails/rails/issues/48420) | [`thomasklemm/grouped-keys-unknown-table-type`](https://github.com/thomasklemm/rails/tree/thomasklemm/grouped-keys-unknown-table-type) @ [`0cd841c0c1`](https://github.com/thomasklemm/rails/commit/0cd841c0c16340b573a4b551af69f4b756c97648) on main `9b116f1fed` ([patch](../../bench/upstream/rails_issue_fixes/patches/i1-grouped-keys-unknown-table-type.patch)) | lib +4/−1, three tests, CHANGELOG | **Opened as [#59609](https://github.com/rails/rails/pull/59609)** 2026-11-04; head `3f0b28f7ef` after Sol's nits and the readability rewrite ([ledger](contributions.md#open)) |
| IW: Array subclasses' `index_with` indexes what `each` yields again (census backlog finding 3) | none | [`thomasklemm/index-with-array-subclass-each`](https://github.com/thomasklemm/rails/tree/thomasklemm/index-with-array-subclass-each) @ [`2486c9d447`](https://github.com/thomasklemm/rails/commit/2486c9d4471155ca219571efa32eac0fb7c01d4e) on main `9b116f1fed` ([patch](../../bench/upstream/rails_issue_fixes/patches/iw-index-with-array-subclass-each.patch)) | lib +5/−2, test +6 | Lead, not opened (coordinator agreed): +5.3% instructions per plain-Array call for a case Ruby's own Array methods don't honour either ([below](#census-backlog-findings-c14)) |

## Triage

Issues that passed the filters, with their reproduction on main:

| Issue | Still failing on main? | Cause | Size of fix | Decision |
| --- | --- | --- | --- | --- |
| [#48420](https://github.com/rails/rails/issues/48420) grouped `count` keys from a joined subquery are Strings (PostgreSQL, since 7.0.5) | Yes: `group("ranges.range").count` keys are `String`, `group("tsrange(...)")` keys are `Range` | Since #46923 (backported to 7.0.5 as #48091) the key type comes from the group column's Arel attribute first; for a table the schema cache doesn't know, `TypeCaster::Connection` returns `ActiveRecord::Type.default_value`, which casts nothing, so the result's column type is never used | +3/−1 in `execute_grouped_calculation` | **Built (I1).** The author of an earlier attempt (#58150) closed it as stale on 2026-08-29, unreviewed; it fell back through the root model's attribute types, which our test rules out |
| [#54812](https://github.com/rails/rails/issues/54812) Action Text body dirty with a literal `\u00A0` stored before 7.1 | Yes: `body_changed?` is `true` right after loading | The serialized dirty check compares the raw stored HTML with the canonical re-serialization (`&nbsp;`) | 1 line (`serialize :body, ..., comparable: true`), but `body_changed?` on a loaded 1.8 KB body goes from 1.3 µs to 607 µs (parses the stored HTML on every check) | Not built: the one-line fix costs about 450× per dirty check; a cheaper design is not small. The closed #57214 got the same performance question and no answer |
| [#50971](https://github.com/rails/rails/issues/50971) `dup` marks every attribute `came_from_user?` | Yes, for new and persisted records (a comment says it was fixed in 8.0; it was not on main) | `ActiveModel::Dirty#init_attributes` wraps every attribute with `with_value_from_user` | 1 line (`other.persisted?` guard) | Not built: that guard was 788330ec98 (byroot), which its author reverted two weeks later (7d69f241bf) without a stated reason; low impact |
| [#58499](https://github.com/rails/rails/issues/58499) `allow_browser versions: :modern` blocks Opera for Android | Yes: the issue's user agent gets the 406 page | The useragent gem reports Opera for Android's own `OPR/` version (80–100) against the desktop minimum 106 | Needs gshutler/useragent#74 (open) plus a Rails decision on versions for mobile Opera | Not built: depends on another gem and on a design choice; Action Pack area (C12) |
| [#59168](https://github.com/rails/rails/issues/59168) `ractorize!` in the test environment: `LazyRouteSet` reloads routes on the frozen app | Not run here (needs `RACK=head`); the reporter's railties test fails on main `3199273249` | `LazyRouteSet#call` memoizes a new routes reloader on the frozen application | Small, but the reporter asks maintainers which of three directions they want | Not built: waiting for maintainer direction; #59186 only covers the eager-load half |
| [#59153](https://github.com/rails/rails/issues/59153) Herb templates fail to compile in a non-main Ractor | Not run (reporter's Action View test) | herb 0.11 is not Ractor-safe (marcoroth/herb#2805) | Rails-side workaround is a design choice | Not built: external gem |
| [#58506](https://github.com/rails/rails/issues/58506) `assign_attributes` with `has_many_attached` doesn't store files | No: two contributors could not reproduce on main or 8.1.2; no script | — | — | Not reproducible |
| [#58413](https://github.com/rails/rails/issues/58413) 8.1.3.1 boot aborts when image_processing 2.x lacks ruby-vips | No: fixed on main (#57403) and 8-1-stable (#58414) | — | — | Already fixed |
| [#58069](https://github.com/rails/rails/issues/58069) intermittent `FrozenError` on autoload paths at boot | No reproduction (reporter could not make one; fxn: the freeze is a deliberate safety check) | — | — | Not reproducible |
| [#57926](https://github.com/rails/rails/issues/57926) Mysql2 "connection in use by Fiber" after 8.1 | No reproduction or backtrace | — | — | Not reproducible |
| [#15854](https://github.com/rails/rails/issues/15854) eager loading associations with `limit`/`group`/`offset` | Yes: `Blog.includes(:limited_posts)` gives sizes `[2, 0]` instead of `[2, 2]` | Eager loading can't apply per-owner limits | Window functions per adapter, or a new error | Not built: known limitation, not small |

Left out before running anything:

* **Open PR attached or linked fix (89):** #59581, #59540, #59517, #59480, #59457, #59439, #59419, #59359, #59215,
  #59193, #59173, #59152, #59146, #59136, #59055, #59037, #59028, #59019, #58990, #58945, #58940, #58939, #58930,
  #58920, #58887, #58865, #58851, #58838, #58796, #58736, #58705, #58624, #58564, #58516, #58500, #58492, #58478,
  #58477, #58472, #58440, #58365, #58327, #58313, #58155, #57950, #57923, #57904, #57631, #57596, #57464, #57387,
  #57068, #57042, #56978, #56952, #56950, #56861, #56810, #56480, #56373, #56094, #55168, #53448, #51217, #48671,
  #36965, #33155, #3508, #29078, #31045, #42941, #44652, #44790, #47913, #50916, #50960, #51817, #52061, #52279,
  #52862, #50258, #54096, #55756, #52645, #41811, #48878, #54841, #55923, #53602.
* **Intended or settled by a maintainer or the docs:** #58737 (skipkayhil: expected, fix it in the gem that loads
  `ActiveJob::Arguments` early), #58523 (the repro set `config.timezone` instead of `config.time_zone`; 8.1 keeps
  time-only values on a fixed date by design), #46419 (documented since #49394), #49762 (fatkodima, jonathanhefner:
  store accessors are not attributes), #58732 (documented `has_one` replacement), #57109 (documented calendar),
  #16452 (intentional check), #54177 (the group-and-having case is fixed by #57601; fatkodima closed the group-only
  follow-up #58000), #46521, #46797, #40855, #20676 (open design questions, no small fix).
* **Security:** #34961, #51580, #56948, #51082, #59545, #59546, #41148, #52001, #55695 (#59215 also has an open PR).
* **Features, docs and performance:** #33270, #50193, #50448, #50451, #50759, #52459, #25333, #54943, #56163,
  #56615, #57781 (allocation regression being fixed by byroot and czj).

## Census backlog findings (C14)

The coordinator added two unreleased regressions from [census-backlog](census-backlog.md#correctness-findings)
(Lowrail main `2b7d743`). Both reproduce on main `9b116f1fed` and not on v8.1.4.1 (Ruby 4.0.9; v8.1.4.1 loaded from a
worktree of the tag). No rails/rails issue or PR covers either besides our own #59565 and #59557 (searched 12:20 UTC:
`find_by_sql`, `count_by_sql`, `index_with`, the two commit SHAs).

| Finding | Still failing on main? | Cause | Size of fix | Decision |
| --- | --- | --- | --- | --- |
| PG `find_by_sql`/`count_by_sql` with typed literals (`DATE :d`) or untyped binds (`:x IS NULL`) | Yes: `PG::SyntaxError … at or near "$1"` and `PG::IndeterminateDatatype`; v8.1.4.1 returns `2026-01-02` and `true` ([repro](../../bench/upstream/rails_issue_fixes/repro_find_by_sql_typed_literal.rb)) | #58427 (kamipo, merged by himself) sends array-form values as bind parameters, deliberately, for parity with `where`, which has failed the same way since #51139 (Rails 7.2) | A code fix is a revert of #58427's design or keyword-based interpolation, which our own record found inexact; option 1 there is a CHANGELOG note | **Not built.** It reverses a deliberate design that byroot and matthewd confirmed for `where` (#52643, #55439). Our open #59565 is the mitigation byroot offered (a hint in the error). A CHANGELOG addition to #58427's entry, naming `CAST(:x AS type)`/`:x::type`, is the one small step left; it is documentation, not a bug fix, so it is left for Thomas to decide |
| `Array#index_with` ignores an overridden `each` on Array subclasses | Yes: `Tens[1, 2].index_with { _1 }` is `{1=>1, 2=>2}` on main, `{10=>10, 20=>20}` on v8.1.4.1 | byroot's 2b88dc1995 (unreleased) switched `index_with` to `to_h`; our merged #59555 (6235de2236) restored `each` for `Enumerable` but kept `to_h` in a new `Array#index_with`, and `Array#to_h` reads the elements directly | +5/−2: subclasses call `super` (Enumerable's `each` loop, identical to 8.1's); test extended | **Built (IW), recommended not to open** (see below) |

**IW and our open #59557.** The regression is not caused by #59557, but #59557 depends on it: it rewrites the same
`Array#index_with`, says "Ruby 4.0 and Array subclasses keep `to_h`", and adds
`test_index_with_array_subclass_overriding_each_and_size`, which pins main's behaviour (a `reverse_each`-overriding
subclass indexes in storage order). IW conflicts with #59557 textually and in that test. If IW were opened and
merged, #59557 would have to drop its subclass `to_h` branches (which get simpler) and flip that test.

**Why IW is not recommended.** The `instance_of?(Array)` check runs on every plain-Array `index_with` (column
indexes of every query result, `serializable_hash`, `attributes_with_values`): Callgrind per `%w[id title body]
.index_with(nil)`, 3,000 calls minus none, Ruby 4.0.9, GC disabled: 6,417 → 6,758 instructions interpreted (+5.3%),
6,012 → 6,172 with YJIT (+2.7%) ([script](../../bench/upstream/rails_issue_fixes/ir_index_with.rb)). In exchange it
helps only an Array subclass that overrides `each`, which Ruby's own `Array#map`, `#to_h` and `#select` ignore too, so
main's behaviour matches core Array semantics. byroot chose `to_h` for Array deliberately (hash presizing on Ruby 4.1),
and amatsuda reverted an `each` loop for the same reason (#59203). A plain Array with a singleton `each` is also still
ignored after IW. Checks: the extended test fails on main and passes with IW; Active Support suite 6,895 runs, 0
failures, 0 errors; the subclass path is textually identical to 8.1.4.1's `Enumerable#index_with`. No reviewer round
was run, because it is not queued to open; it would need one (and a Sol review) if Thomas wants it.

## I1: grouped keys of columns unknown to the schema

```ruby
Booking.joins("JOIN (SELECT tsrange(timestamp '2020-01-01', timestamp '2020-01-02') AS range) ranges ON TRUE")
  .group("ranges.range").count
# main: { "[\"2020-01-01 00:00:00\",\"2020-01-02 00:00:00\")" => 1 }
# I1:   { 2020-01-01 00:00:00 UTC...2020-01-02 00:00:00 UTC => 1 }
```

The change, in `execute_grouped_calculation`:

```ruby
type = col_name.try(:type_caster)
type = calculated_data.column_types.fetch(aliaz, type) if type.equal?(Type.default_value)
types[aliaz] = type || type_for(col_name) { calculated_data.column_types.fetch(aliaz, Type.default_value) }
```

**Why it is exact.** Only `TypeCaster::Connection` (the table built for a table name with no model) returns
`ActiveRecord::Type.default_value`; a model's `attribute_types` default to `ActiveModel::Type.default_value`, a
different frozen instance, so `equal?` never matches for model columns, untyped `attribute :x`, an explicit
`ActiveModel::Type::Value.new`, or joined association models. For a PostgreSQL column of an unknown OID, the schema
type and the result type are the same default, so nothing changes. MySQL results carry no column types, so the fetch
returns the old type. The SQL-expression path (`type_for`) is untouched.

**What changes beyond PostgreSQL ranges** (reviewer probes, all now matching what grouping by the expression itself
returns on main): on PostgreSQL, `date`, `int[]`, `interval`, `money` and `inet` keys of subquery columns are cast
(`Date`, `Array`, `Duration`, `BigDecimal`, `IPAddr`); on SQLite, a subquery that selects a typed column now gives
`true` instead of `1` and a `Date` instead of `"2020-01-01"` (verified here); CTEs and `async_count` are fixed the
same way. Before 7.0.5 these keys were cast from the result too (v7.0.4.3 had only the `type_for` fallback), so this
restores old behaviour; the CHANGELOG entry says so.

**Adversarial round** (subagent, PostgreSQL with and without prepared statements, SQLite; every grouped operation
and their async forms; enums, custom and untyped attributes, `alias_attribute`, serialized columns, ignored columns,
domains, composite and PG enum types, composite keys, belongs_to grouping, `schema_cache.clear!`): two low-severity
differences beyond subqueries and CTEs, both accepted. D1: a model column whose type the adapter doesn't recognise
(SQLite untyped or unknown declared type, PG composite, `pg_lsn`) also stores `ActiveRecord::Type.default_value`, so
when a `from` subquery replaces that column with a typed one, its keys are now cast from the result (`[0,
"2020-01-02"]` → `[false, Date]`); the same bug class, and the body now says "whenever the column's type is that
placeholder". D2: a type registered for such an OID after the schema loaded now reaches grouped keys but not `pluck`
or reads (needs late `register_type`; contrived). Also in the mechanism: a string join that aliases a real table
(`JOIN owners o2`) now casts `o2.born` from the result instead of returning a String. Nothing else differed.

**Not covered, left for later:** `pluck`/`pick` of such a column have the same bug in `type_cast_pluck_values`
(a separate PR, one concern each); a subquery alias that matches a model's table or association name
(`from("(...) bookings")`) still goes through `TypeCaster::Map` and stays uncast.

**Checks.**

* Regression test (`calculations_test.rb`, PostgreSQL only, because SQLite has no range type): fails on main with
  String keys, passes with the fix. It names the subquery column `status`, which collides with `accounts.status`
  (a string column), so a fix that falls back through the root model's attribute types (as #58150 did) fails it too;
  verified by running that variant.
* Active Record suite on PostgreSQL: 11,203 runs, 0 failures, 0 errors. On SQLite: 10,281 runs, 0 failures,
  4 errors, all four in `SqliteStructureDumpTest`/`SqliteStructureLoadTest` because the orb has no `sqlite3` command
  line tool. MySQL not run (no server in the orb). `calculations_test.rb` also passed on separate databases in the
  review (248 runs PostgreSQL, 246 SQLite).
* Readability: L1 (two lines in an existing loop; the `equal?` against the default type is the one unusual part).
* Review: a separate subagent reviewer on both rubrics: approve with nits on correctness (document the SQLite and
  CTE key changes, done in the CHANGELOG), approve on the test, L1. A second pass checked the body's facts and
  outsider readability; its corrections are in the body below. Adversarial round: see above.
* No open PR for #48420 at 2026-11-04 12:15 UTC (`gh pr list --search 48420`, and the issue's cross-references show
  only the closed #58150).

### Readability record (DECISIONS readability gate and plain description, applied after opening)

The opened head `c61c7ede78` had `type = …; type = … if type.equal?(…)`, a reassignment inside a conditional
modifier. Head `3f0b28f7ef` (amended, force-pushed once, PR body updated; full AR suite again green: PostgreSQL
11,205 runs 0 failures, SQLite 10,283 runs 0 failures, the same 4 `sqlite3`-CLI errors) assigns the key type in one
`if / elsif / else`:

```ruby
type = col_name.try(:type_caster)
# A column unknown to the schema has the placeholder Type.default_value (hence equal?); use the database type.
types[aliaz] = if type.equal?(Type.default_value)
  calculated_data.column_types.fetch(aliaz, type)
elsif type
  type
else
  type_for(col_name) { calculated_data.column_types.fetch(aliaz, Type.default_value) }
end
```

Plain description, one sentence per branch:

1. A column whose type is the placeholder for a column unknown to the schema takes the type the database reports.
2. A column with any other type keeps it.
3. An SQL expression, which has no type of its own, takes the model attribute's type of that name, or the database's
   type if the model has none (unchanged from main).

A first three-branch draft put the `nil` case first and the comment between `if` and `elsif`; reordering put the
comment next to the check it explains. Cold read (a subagent that had not seen the change): each branch stated
correctly in one sentence, L1 ("close to L2"), noting that branches 1 and 3 both end at the database type. Its
proposed merge of the two fallbacks (`type ||= type_for { nil }`, then one placeholder check) would also send model
attributes whose type is the placeholder through the database type, a behaviour change, and reassigns inside a
conditional, so it was not taken; the comment now says why the placeholder falls back.

Metrics for `execute_grouped_calculation` (signal only; main → head): flog 194.4 → 203.0; RuboCop AbcSize 127.5 →
132.0, CyclomaticComplexity 33 → 34, PerceivedComplexity 36 → 38, MethodLength 80 → 84.

### Sol review and PR body as opened

Sol (run by the coordinator): approve; it fixes #48420, keeps #46923's joined-column fix, and leaves MySQL unchanged
(its results carry no column types). Nits applied in `c61c7ede78` (amended into the one commit, rebased on main
`9b116f1fed`, `git merge-tree` clean): a one-line comment on the identity check; tests for a SQLite/PostgreSQL CTE
selecting a typed column (fails on main on both), a mixed known/unknown two-column grouping, and an explicit
`ActiveModel::Type::Value` that must stay as supplied (fails if `equal?` is replaced by `==`); body wording. A
subquery's `created_at` with time-zone-aware attributes now groups as a UTC `Time`, while `group(:created_at)` stays
`TimeWithZone` (checked). No competing PR at 12:40 UTC. Opened as
[#59609](https://github.com/rails/rails/pull/59609); the body below is the current one (updated with the plain description):

> Fixes #48420.
>
> On PostgreSQL, grouping by a column of a joined subquery returns String keys, while grouping by the same expression directly casts them:
>
> ```ruby
> Booking.joins("JOIN (SELECT tsrange(timestamp '2020-01-01', timestamp '2020-01-02') AS range) ranges ON TRUE")
>   .group("ranges.range").count
> # main:    { "[\"2020-01-01 00:00:00\",\"2020-01-02 00:00:00\")" => 1 }
> # this PR: { 2020-01-01 00:00:00 UTC...2020-01-02 00:00:00 UTC => 1 }
> ```
>
> Since #46923 (backported to 7.0.5 in #48091), a grouped key's type comes from the group column's Arel attribute first. When the schema cache doesn't know its table, as for a subquery alias or a CTE, that type is the placeholder `ActiveRecord::Type.default_value`, which casts nothing, so the type the database reports for the result is never used. Now a column whose type is that placeholder takes the result's type, a column with any other type keeps it, and an SQL expression still takes the model attribute's type of that name or the result's. This also fixes SQLite subqueries and CTEs that select a typed column (booleans came back as `1`, dates as `"2020-01-01"`). An explicit `ActiveModel::Type::Value` and same-named columns of joined models (the case #46923 fixed) keep their type. The result's metadata supplies the database type, not the model's time zone wrapper, enum or serializer: a subquery's `created_at` becomes a UTC `Time`, not a `TimeWithZone`. `pluck` has the same bug on another path; I left it for a separate PR.

## Second round: one level deeper (2026-11-04)

The eleven issues still open after the filters, and the "intended" ones users keep reporting, were rechecked for a
fix, a doc fix or a clearer error. The open-PR check now uses GitHub's search API: `gh search` in this orb silently
returned nothing (it needs the `read:org` scope), so the first round relied on cross-references only. Result: no
new candidate.

| Issue | Deeper finding | Decision |
| --- | --- | --- |
| #15854 eager loading with `limit` | The API docs say the limit "will be ignored, returning all the associated objects"; on main that holds for `eager_load` only (`[3, 3]`), while `includes`/`preload` apply one limit to all owners (`[2, 0]`) ([repro](../../bench/upstream/rails_issue_fixes/repro_15854_preload_limit.rb)) | Not built: kamipo's open [#58815](https://github.com/rails/rails/pull/58815) runs the scope per owner in `preload` (behind `respect_association_scope_limits`), not cross-referenced from the issue; a doc fix would conflict with it |
| #58737 (and #56090, #55998) custom Active Job serializers ignored when a gem loads `ActiveJob::Arguments` early | Registering inside `ActiveSupport.on_load(:active_job_arguments)` works in both load orders and stays deferred ([repro](../../bench/upstream/rails_issue_fixes/repro_custom_serializers_early_load.rb)), but it calls `ActiveJob::Serializers.add_serializers`, which is `:nodoc:`, and skipkayhil pointed reporters to public API only. The early load is what `guard_load_hooks` / `action_on_early_load_hook` reports; it misses loads before the application class exists, which open #58334 (for #58327) fixes | Not built: the clearer error is #58334; a guide recommending a `:nodoc:` method is not ours to add |
| #54812 Action Text dirty with legacy ` ` | A cheaper fix would have `ActionText::Content.dump` return the stored HTML for unchanged content, but that also stops canonicalizing user-supplied HTML on save | Not built: no exact fix cheaper than `comparable: true` (607 µs per check) |
| #16452 constant alias as association class | Main raises "Missing model class Author for the Post#author association" although `Author` exists (as `User`) | Not built: a clearer message is possible in `compute_type`, but the issue has no reactions or duplicates since 2014 |
| #50971, #58499, #59168, #59153 | No open PR found by text search; reasons from the first round stand (reverted guard; useragent#74; maintainer direction asked; herb gem) | Unchanged |
| #46419, #49762, #58732, #57109, #58523, #54177 | Documented already, or a docs PR is open (#59007, #58744, #58761, #57114), or fatkodima rejected the remainder (#58000) | Unchanged |

## P1: plucked columns unknown to the schema (2026-11-04)

Follow-up to the `pluck` gap named in #59609's body. Branch
[`thomasklemm/pluck-unknown-table-type`](https://github.com/thomasklemm/rails/tree/thomasklemm/pluck-unknown-table-type) @
[`f1bd724f3d`](https://github.com/thomasklemm/rails/commit/f1bd724f3dfe2aab92b6d482ba79f19cf06e4180) on main
`6c23cb8f2a` ([patch](../../bench/upstream/rails_issue_fixes/patches/p1-pluck-unknown-table-type.patch)); lib +8/−1,
CHANGELOG. **Opened as [#59621](https://github.com/rails/rails/pull/59621)** 2026-11-04 at head `8d29f4b6f0` after Sol's fixes (tests for an explicit `Value` type, a mixed pluck, `pick` and a result without column types; the comment now reads "Prefer the result type only for the default placeholder, preserving explicit types."; body and CHANGELOG say "when the adapter reports result column types"). The body as opened replaces the draft below.

**Reproduction** ([script](../../bench/upstream/rails_issue_fixes/repro_pluck_unknown_table.rb)): a subquery that selects
`rooms.day` (date) and `rooms.open` (boolean), plucked as `pluck("s.d", "s.o")`.

| Version (Ruby) | PostgreSQL `pluck` | SQLite `pluck` | PostgreSQL `group("s.d")` keys |
| --- | --- | --- | --- |
| main `6c23cb8f2a` (4.0.9) | `["2020-01-01", true]` | `["2020-01-01", 1]` | `"2020-01-01"` |
| 8-1-stable (4.0.9) | same | same | `"2020-01-01"` |
| v7.0.5 (3.2.11) | same | same | `"2020-01-01"` |
| v7.0.4.3 (3.2.11) | same | same | `Date` |
| with P1 | `[Date, true]` | `[Date, true]` | unchanged (that is #59609) |

So `pluck` is **not a 7.0.5 regression**: 7.0.4.3 returns the same raw values (it has used `column.try(:type_caster)`
since 71f0df943d, 2020). The table also confirms #48420's 7.0.5 regression on PostgreSQL. On SQLite, grouped keys were
uncast in 7.0.4.3 too, so #59609's CHANGELOG phrase "again, as before Rails 7.0.5" is accurate for PostgreSQL only;
reported to the coordinator, not changed on the open PR.

**Search** (GitHub search API, 2026-11-04): "pluck subquery type cast", "pluck joined subquery string", "pluck type
cast unknown table", "pluck CTE", "pluck tsrange", "type_cast_pluck_values": no open issue or PR except #59609.

**Plain description**, one sentence per branch of the new `if / elsif / else` in `type_cast_pluck_values`:

1. A column whose type is the placeholder for a column unknown to the schema takes the type the database reports,
   or keeps the placeholder when the adapter reports none (MySQL).
2. A column with any other type keeps it.
3. An SQL expression is looked up by its result name on the model, then the joined models, then the result (unchanged).

Same shape and comment as #59609. Cold read (subagent): each branch stated correctly, shape checklist passes, L1;
nit: "(hence equal?)" is terse, kept identical to #59609 for consistency. It confirmed `|| type` is needed (MySQL and
trilogy results carry no column types, so `column_types[i]` is `nil`), and that `ids`, `pluck(:id, "expr")`, async
pluck and the `pluck("*")` branch are unchanged; `pick` gains the fix through `pluck`.

**Checks.** The test (SQLite and PostgreSQL) fails on main (`["2004-04-15", 0]` on SQLite, `"2004-04-15"` on
PostgreSQL) and passes with P1. A wrong fix that drops the placeholder and falls back to `model.attribute_types` by
name fails it on SQLite (the CTE's `written_on` is `approved`, which collides with Topic's datetime `written_on`).
AR suite: PostgreSQL 11,203 runs, 0 failures; SQLite 10,282 runs, 0 failures, the same 4 `sqlite3`-CLI errors.
`git merge-tree` is clean against main; against #59609 only the two CHANGELOG entries at the top conflict. Per
"Correctness fixes: readable first" nothing was measured beyond reasoning: the change adds one `equal?` per plucked
column per query, not per row.

### Body (draft, about 170 words)

> `pluck` and `pick` now cast a column of a joined subquery or CTE with the type the database reports for the result, instead of returning the raw value:
>
> ```ruby
> Topic.with(read: Topic.select(:id, :last_read)).joins("JOIN read ON read.id = topics.id").pluck("read.last_read")
> # main:    ["2004-04-15"]   (SQLite also returns booleans as 1)
> # this PR: [Thu, 15 Apr 2004]
> ```
>
> A plucked column's type comes from its Arel attribute first. For a table the schema cache doesn't know, that type is the placeholder `ActiveRecord::Type.default_value`, which casts nothing, so the result's column type was never used. Now a column whose type is that placeholder takes the result's type, a column with any other type keeps it, and an SQL expression is looked up by name as before. This is the change #59609 makes for grouped keys (#48420), on the path `pluck` takes; unlike that one it is not a regression, since 7.0.4.3 returns the same raw values. MySQL is unchanged because its results carry no column types, and the type is the database's, not the model's time zone wrapper or serializer.
