# Unreleased regressions on Rails main versus 8-1-stable (2026-11-04)

This round looked for methods that got more expensive on Rails main and were never released. AP-2 (the
`_all_renderers` Set union, C12) is covered elsewhere and was skipped.

## Setup

- **Pins.** main `6c23cb8f2a` (rechecked against `7a78da5a55`; `attribute_set.rb` and `persistence.rb` are
  unchanged), 8-1-stable `6e09124217`, merge base `8ae3d84277`, with 2,338 first-parent commits in between.
- **Ruby and heap.** Ruby 4.0.9 with a fixed heap (`RUBY_GC_HEAP_*` from `/tmp/reg/heap.sh`); ZJIT runs used Ruby
  master `9aa0898240`.
- **Census.** `script/census` (allocations) and `script/cpu-census` (Callgrind instructions), each run twice per
  branch as an A/A.
  - Apps: blog, writebook, codetriage, pingcrm, redprints-cfp and react-starter-kit, plus lago, sure, casa and
    hackatime on PostgreSQL.
  - Excluded because they don't run on 8.1: campfire (`load_defaults "8.2"`), fizzy (listener error), lobsters
    (HTTP 500) and loomio (HTTP 422). mastodon and docuseal didn't build (`idn-ruby`).
- **Tooling.** Per-method diffs come from `bench/upstream/main_regressions/method_diff.rb`. Per-call instructions
  come from `ir.sh` with `micro.rb` and `app_micro.rb` (Callgrind, N=2000, `event_reporter.debug_mode = false`).

## Census result: main is faster overall

| | 8.1 → main |
| --- | --- |
| Allocations per op, median over all workloads | −404 objects (PostgreSQL apps −1,656) |
| Interpreted instructions per app, median range | −1% to −11% |
| YJIT instructions per app, median range | −1% to −17% |
| Workloads slower beyond A/A | 1: codetriage `perform SendSingleTriageEmailJob`, +6.1% |

The codetriage job is slower because the app sets `config.log_level = :debug` in production. Main ties
`Rails.event.debug_mode` to `log_level == "debug"`, where 8.1 used `Rails.env.development?`, so main builds the debug
structured events (SQL, render) for this app. That is intended and a consequence of the app's config.

## Methods that grew, and why

| Method or site | Cause | Verdict |
| --- | --- | --- |
| `index_with` | `to_h` path | covered by our open #59557 |
| `IndexedRow::Mutable#new_empty_mutable_row` | IndexedRow work | intended architecture |
| EventReporter, QueryIntent, RetryBudget | new features | intended |
| `build_default_scope` `method(:default_scope).owner` | memoization removed in e1caec4954 (Ractor ivars) | intended; maintainer called it "same-ish" |
| `csrf_token_hmac` key dup | #59430 | intended, a security fix |
| `append_sec_fetch_site_to_vary_header` | new CSRF feature | intended |
| `find`, many small steps (bisect in `/tmp/reg/hist-find.txt`) | QueryIntent (#55897, #56129, #56267, #58049, #58479), Ractor ivars (#57642), polymorphic cache (#58520), Ractor safety (#58643 neighbourhood) | intended architecture; later commits recover part of it |
| `update` +14% (953,326 → 1,090,082 Ir) | bisected below | one accidental step → **R1** |

**`update` bisect** (`/tmp/reg/hist-update.txt`):
- 9d4f4fa60c, Ractor-safe `class_attribute`: +7.7k, intended.
- 7f2e541d4b, `RETURNING` on update: +15k. Stubbing `returning_columns` recovers only about 12k, so the rest is
  feature cost.
- #57642: +11.6k, intended.
- The #58049 / #58479 window: +21k, intended.
- **a19ef01cb3 "fix `deep_dup` and `map` return type" (merged in da27ee26de): +78k, +7.6%.** This is the largest
  single step.

## R1: keep LazyAttributeSet copies marked as materialized (held)

**Cause.** a19ef01cb3 changed `LazyAttributeSet#map` and `#deep_dup` to return a `LazyAttributeSet`, so the copy has
the right class. The copy is built from `attributes`, which is fully materialized, but it starts with
`@materialized = false`. After every save, `forget_attribute_assignments` calls `@attributes.map(&:forgetting_assignment)`.
On the copy:
- the next `#keys` recomputes `values.keys | types.keys | @attributes.keys` and checks each name;
- `attributes` runs materialization again;
- dirty tracking checks every column: 7 instead of 2 in the micro.

TracePoint confirms the extra calls.

**Fix.** Fork branch
[`thomasklemm/lazy-attribute-set-materialized-copies`](https://github.com/thomasklemm/rails/tree/thomasklemm/lazy-attribute-set-materialized-copies)
@ [`c69bbee5b7`](https://github.com/thomasklemm/rails/commit/c69bbee5b70116510ec8dd8a94e3c30a38f553f5) on main
`7a78da5a55`, 9 lines in `attribute_set.rb`. Patch:
[r1-lazy-attribute-set-materialized-copies.patch](../../bench/upstream/main_regressions/patches/r1-lazy-attribute-set-materialized-copies.patch).

Described as sentences:
- `initialize` takes `materialized:`, which defaults to false, and stores it.
- `deep_dup` and `map` build their copy from materialized attributes, so they pass `materialized: true`.
- `keys` on a materialized set returns `AttributeSet#keys`, because materializing puts every key in `@attributes`
  in this order.

The change keeps a19ef01cb3's purpose: the copies are still `LazyAttributeSet`s. An alternative that returned a plain
`AttributeSet` (x3, 1,036,703 Ir) was rejected because it undoes that commit.

**Numbers.** Callgrind instructions per call, Ruby 4.0.9:

| Case | main | R1 | |
| --- | --- | --- | --- |
| `update` interpreted | 1,072,976 | 1,025,173 | −4.5% |
| `update` YJIT | 502,028 | 462,701 | −7.8% |
| `create_rollback` interpreted | 1,378,084 | 1,377,184 | flat |
| `find`, `attributes`, `as_json`, `new_model` | | | flat (≤ ±0.3%) |

The smallest common input is any `save` or `update` of a loaded record. Creating a record and read-only paths are
unaffected.

**Checks done.**
- `diff_attrset.rb`: 517 observable lines identical on main and R1, on the 4.0.9 interpreter, 4.0.9 YJIT and master
  ZJIT, after masking wall-clock timestamps and object addresses. It covers saves, in-place mutation, serialized and
  store attributes, partial selects with and without `lock_version`, extra columns, virtual attributes, dup and
  clone, YAML and Marshal round trips, rollback, `becomes`, freeze and destroy.
- Active Model suite: 1,250 runs, 0 failures. Active Record sqlite3 dirty, attribute methods, persistence,
  attributes, locking, serialized, store, YAML, Marshal and transactions tests: 811 runs, 0 failures, 1 skip.

**Not done**, because R1 is held: the A/A Callgrind pair, ZJIT Ir, the review subagents, the outsider read and the
Sol round.

**Why it is held.** Open [#59141](https://github.com/rails/rails/pull/59141) ("Use an Array for storing Active Record
attributes"), by the author of a19ef01cb3 and updated 2026-11-03, rewrites these exact lines: `map`, `deep_dup`,
`keys` and the materialization state. Its `map` does `materialize; dup.transform_attributes!`, so its copies already
stay materialized. Under the DECISIONS rule, an open PR on the same code means the idea is taken. Open
[#58002](https://github.com/rails/rails/pull/58002) also rewrites `keys`, for a fresh row rather than a copy.

Measured on #59141's head `e5dc0b4338` and its base `1105756f42`, which already contains a19ef01cb3. Interpreted
instructions:

| Case | #59141 base | #59141 head | |
| --- | --- | --- | --- |
| `update` | 1,091,164 | 1,152,738 | +5.6% |
| `create_rollback` | 1,379,649 | 1,458,165 | +5.7% |
| `find` | 264,137 | 227,370 | −13.9% |

**A/A control (2026-11-04).** Two separate worktrees each of base `1105756f42` and head `e5dc0b4338`,
interpreter, Ruby 4.0.9, fixed heap (`RUBY_GC_HEAP_{0..4}_INIT_SLOTS` 400k/200k/100k/50k/20k), N=2000:

| Case | base A | base A′ | A/A | head B | head B′ | head vs base |
| --- | --- | --- | --- | --- | --- | --- |
| `update` | 1,089,758 | 1,089,774 | 0.0015% | 1,151,682 | 1,151,547 | +5.7% |
| `create_rollback` | 1,379,703 | 1,380,099 | 0.03% | 1,460,459 | 1,460,556 | +5.9% |
| `find` | 263,409 | 263,907 | 0.19% | 227,083 | 227,316 | −13.8% |

The write-path cost holds far above A/A. **It is not the a19ef01cb3 cause:** the head's `map` is
`materialize; dup.transform_attributes!`, and `dup` keeps `@materialized`. TracePoint per `update` shows the head
instead making many name-to-index lookups (`index_for_name` 73, `indexes` 79, `lookup` 66, `attribute_at` 45), and
its `keys` (3 calls) still recomputes `row_keys | type_keys | cached_names` with an `initialized?` check per name on a
materialized set. Which of these carries the instructions was not measured.

So on the write path #59141 adds about 6% instead of recovering the a19ef01cb3 step; `find` gets 14% cheaper.
A comment with these numbers was posted on #59141 at 17:16 UTC and deleted unanswered shortly after: we
don't comment on others' PRs without Thomas's approval.

R1 can open on its own if #59141 closes, or once it merges, if its `keys` still recomputes after a save.

## Rejected

- x3, `map` returning a plain `AttributeSet`: it undoes a19ef01cb3's purpose.
- A `find` candidate: the cost is spread over intended QueryIntent and Ractor architecture, with no single
  accidental step.
- codetriage +6.1%: a consequence of the app's config, not an accident.
