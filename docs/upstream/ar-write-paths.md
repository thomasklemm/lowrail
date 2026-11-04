# Active Record write paths: a candidate round (2026-11-04)

A round on the save/update path: dirty tracking, timestamps, `_create_record`/`_update_record`, validations,
callbacks, transaction bookkeeping, `touch`, `insert_all`/`upsert_all`, plus three Active Record/Arel leads from the
census backlog (C6-2, `SelectManager#project`, `Arel.sql`). Same rules as [AR-1](ar-request-paths.md), plus the
readability checks of 2026-11-04 in [DECISIONS](../DECISIONS.md#readability-gate-l0l3) (cold read, shape checklist,
flog/RuboCop numbers, the changed code described in plain sentences).

**Status 2026-11-04 13:55 UTC:** W2 opened as [rails/rails#59616](https://github.com/rails/rails/pull/59616)
(head `ef0266d0d6`); W3 opened as [rails/rails#59618](https://github.com/rails/rails/pull/59618) at 14:11 UTC (head
`c4f465b7b2`), from the coordinator orb after PR creation recovered.

**Result.** Two candidates, W2 (update timestamps) and W3 (default star projection), passed the Sol round with
fixes (2026-11-04) and are ready to open on rails/rails main `9cf3693a0a`; **PR creation is blocked** for this account
(GitHub refused `CreatePullRequest` after 13 PRs that day; one attempt for W2, none for W3). W1 was built, measured and dropped after the adversarial round; the other leads were rejected or
parked (below).

| # | Rails branch @ SHA (fork, pushed) | Change | Per call |
| --- | --- | --- | --- |
| W2 | [`thomasklemm/update-timestamps-time-when-written`](https://github.com/thomasklemm/rails/tree/thomasklemm/update-timestamps-time-when-written) @ `ef0266d0d6` | `record_update_timestamps` reads the clock only when it writes a timestamp column, plus three tests | `post.update!` 190 → 189 objects in the micro, −0.9% to −1.6% instructions |
| W3 | [`thomasklemm/build-select-star-projection`](https://github.com/thomasklemm/rails/tree/thomasklemm/build-select-star-projection) @ `c4f465b7b2` | `build_select` appends the default `table.*` projection instead of calling `project(node)` | −1 object per default-star projection; −0.26% / −0.38% instructions (interpreter / YJIT), ZJIT no measurable difference |

Both rebased onto rails/rails main `9cf3693a0a` (no commits on the touched files since `9b116f1fed`, where they were
measured), one commit each, authored and committed by Thomas Klemm. Final bodies:
[`w2-body.md`](../../bench/upstream/ar_write_paths/w2-body.md), [`w3-body.md`](../../bench/upstream/ar_write_paths/w3-body.md)
(links pinned to Lowrail `d7ed9c3678`). Shortened on 2026-11-04 under DECISIONS' "Short PR bodies": W2 244 → 127 words
above the `<details>` (157 with it), W3 210 → 116 (145); Sol's facts kept as clauses, method and noise checks moved
into `<details>`. Patches:
[`bench/upstream/ar_write_paths`](../../bench/upstream/ar_write_paths/).

## Pins and method

As in [ar-request-paths](ar-request-paths.md#pins-and-method): Rails main `9b116f1fed`, worktrees `main` and `aa`
for the A/A, Ruby 4.0.9 interpreter and YJIT, Ruby master `9aa0898240` interpreter and ZJIT; Callgrind
(Ir(500) − Ir(0)) / 500, median of two runs per variant and mode. New micro cases in
[`ar.rb`](../../bench/upstream/ar_write_paths/ar.rb): `touch`, `update_columns`, `vupdate`/`vcreate` (a model with
presence, length and numericality validations), `touch_parent` (`belongs_to touch: true`), `insert_all` (10 rows),
`upsert_all`, `create_destroy`. Differential: [`diff_write.rb`](../../bench/upstream/ar_write_paths/diff_write.rb)
(create, update, clean save, a `before_update` that dirties the record, explicit `updated_at`/`updated_on`,
`touch: false`, `touch`, `touch(time:)`, `record_timestamps = false`, a table without timestamps, a child with
`touch: true`, nested `requires_new` rollback, an exception rollback, partial updates off; every attribute,
`saved_changes`, the commit/rollback callback log and every SQL statement, with `Time.now` stepping a second per
operation). App census: `script/census` (allocations) on Blog, Fizzy, Campfire and Writebook (41 workloads, 7 of them
form posts), with A/A. ruby-bench counts with [`lowrail_wcount.rb`](../../bench/upstream/ar_write_paths/lowrail_wcount.rb)
and objects per iteration with [`lowrail_star.rb`](../../bench/upstream/ar_write_paths/lowrail_star.rb).

## Where a save spends its time

TracePoint call counts on `post.update!` (1,710 Ruby calls) and `post.save!` with no changes (737), and stackprof
over `update`, `save_nochange` and `create`. Per `post.update!`, interpreter / YJIT on Ruby 4.0.9:

| Piece | Interpreter | YJIT |
| --- | ---: | ---: |
| `post.update!` | 306 µs | 110 µs |
| `Post.current_time_from_proper_timezone` | 2.0 µs | 0.5 µs |
| of which `Post.with_connection {}` | 1.6 µs | 0.4 µs |
| `has_changes_to_save?` on a clean record | 5.2 µs | 3.1 µs |

`with_connection` runs 8 times per `update!`: twice in `with_transaction_returning_status`/`add_to_transaction`,
twice in `current_time_from_proper_timezone`, and in `_update_row`, `_update_record` and the query path.

## W2: read the update time only when a timestamp is written

`record_update_timestamps` runs twice per update: from `Timestamp#_update_record`, and again from
`Callbacks#_update_record` after the `before_update` callbacks (added in f2d622adeb so a callback's changes get a
fresh `updated_at`). In an ordinary update the second pass finds `updated_at` already changing and writes nothing,
but main still read the time first (`with_connection`, `default_timezone`, `Time.now`).

```ruby
current_time = nil

timestamp_attributes_for_update_in_model.each do |column|
  next if will_save_change_to_attribute?(column)
  current_time ||= current_time_from_proper_timezone
  _write_attribute(column, current_time)
end
```

**In plain sentences.** For each update timestamp column: skip it if it is already changing; otherwise read the
current time the first time it is needed, and write it. (First shape inlined the `||=` into the
`_write_attribute` argument; split out after the readability rules of 2026-11-04.)

| `post.update!(views: n)`, instructions per call | main | A/A | W2 | Change |
| --- | ---: | ---: | ---: | ---: |
| interpreter 4.0.9 | 1,183,587 | −0.03% | 1,166,927 | −1.41% |
| YJIT 4.0.9 | 542,188 | +0.10% | 537,209 | −0.92% |
| interpreter master | 1,211,103 | −0.26% | 1,192,077 | −1.57% |
| ZJIT master | 589,258 | −0.20% | 580,995 | −1.40% |
| `belongs_to touch: true` child update, interpreter / YJIT / master / ZJIT | | +0.02% / +0.10% / +0.00% / +0.17% | | −0.96% / −0.88% / −1.03% / −0.73% |

Objects: `update` 190 → 189, `vupdate` 184 → 183, `touch_parent` 271 → 270; `create`, `save_nochange` unchanged.
The `Time.now` count in the differential drops 160 → 150; nothing else differs (interpreter, YJIT, ZJIT).

**App census (allocations).** 41 workloads on four SQLite apps: interpreter 11 workloads moved ≤ −1 (A/A 9), YJIT
6 (A/A 6); Fizzy's card update −82 objects in both modes (A/A floor −48 / −2). Most workloads don't update a record,
so the census as a whole is inside its A/A. ruby-bench can't show W2: none of railsbench, lobsters or shipit updates
a record in its measured iteration (0 passes counted).

**App census (CPU).** `script/cpu-census`, interpreter, same four apps, base `cw2` with A/A twin `cw`, W2 as `cwts`
(W2 is the only commit between them). Median over 41 workloads −0.01% (A/A −0.00%), |Δ| p90 0.54% (A/A 0.34%), no
workload ≤ −1%. Campfire, Fizzy and Writebook sit inside their A/A. Blog drifts +0.54% median, but its object
counts move on paths W2 doesn't touch (POST comment 1944 → 2296, broadcast job 804 → 1227), so that is app state
between runs, not W2. No app-level CPU claim.

**Exactness.** Primary and adversarial subagent rounds. Same rows, `lock_version`, counters and errors for: dirty
update; explicit `updated_at`, `updated_on`, both; clean save; `before_update` dirtying a clean record, restoring or
setting `updated_at`; `save(touch: false)`; `record_timestamps = false`; partial updates off; `touch`,
`touch_later`, `update_columns`, `update_attribute`, `increment!`; `belongs_to touch: true` with a counter cache;
`StaleObjectError`; `alias_attribute :updated_at, :modified_at`; `travel_to`; `default_timezone = :local`. Two
updated columns still get the same time. Differences only from accepted categories: an override of the nodoc
`current_time_from_proper_timezone` that counts or fails on its own calls, and a redefined `Time.now` that returns a
new value per call (fewer calls, so later values shift). `test:sqlite3` 10,281 runs, 0 failures, 0 errors; RuboCop
clean. No overlapping PR or issue (`record_update_timestamps`, `current_time_from_proper_timezone`,
`updated_at timestamp twice`); `timestamp.rb` unchanged on main since 2026-11-01 (Markdown); no open PR touches it (file scan of all 1,257 open
PRs), and the three open PRs touching `callbacks.rb` don't touch `_update_record`.

**Readability.** L1 (reviewer): one more line, a lazy-initializer idiom with precedents
(`alias_tracker.rb:29-35`, `calculations.rb:633-637`); `_create_record` above still reads eagerly, which the commit
message explains (one pass there). Shape checklist met; no new names. flog 11.4 → 11.8; RuboCop Metrics: no
offenses before or after.

## W3: append the default star projection without a rest Array

`build_select`'s default branch, taken by every relation that selects all columns, called
`arel.project(table[Arel.star])`; `project(*projections)` allocates a one-element Array for the splat. `project`
only turns Strings and Symbols into `SqlLiteral`, and the star attribute is neither.

```ruby
arel.projections << table[Arel.star]
```

**In plain sentences.** With no select values and no column list to enumerate, add `table.*` to the select
manager's projections.

| Instructions per call | interpreter 4.0.9 | YJIT 4.0.9 | interpreter master | ZJIT master |
| --- | ---: | ---: | ---: | ---: |
| `Post.all.to_a` (20 records), main | 860,144 | 417,352 | 891,290 | 413,499 |
| W3 | −0.26% | −0.38% | −0.24% | −0.35% |
| A/A | −0.01% | +0.01% | +0.29% | −0.00% |
| `Post.where(author_id:).limit(5).to_a`, W3 | −0.44% | −1.65% | −0.51% | +0.04% |
| A/A | +0.00% | +0.84% | −0.23% | −0.12% |

Objects: −1 per relation load in every mode (reviewer: `Post.all.arel` 17,002 → 16,002 per 1,000 interpreted,
18,002 → 17,002 YJIT, 17,002 → 16,002 ZJIT). ruby-bench: star projections per iteration railsbench 30, lobsters
660, shipit 1,811; objects per iteration with `build_select` redefined in both variants, lobsters 662,465 →
661,159 and shipit 1,170,985 → 1,167,347 (two runs each, within 3 objects). That is two objects per call there,
because Rails 8.1's `project` still copies with `map`; main has `map!` (0eef4cbb83), so on main it is one.
ZJIT on `where_to_a` is flat (+0.04% against an A/A of −0.12%); no ZJIT loss.

**Exactness.** `projections` is `@ctx.projections`, the Array `project` concatenates into; not frozen, cloned by
`initialize_copy`; `build_select`'s only caller passes a fresh `SelectManager`; `build_arel` ignores the return value
(now the Array instead of the manager). Nothing in Rails or the installed gems overrides `project` or
`build_select`. `test:sqlite3` 10,281 runs, 0 failures, 0 errors on `9cf3693a0a`; RuboCop clean. **Overlap:** open #45864
(`Relation#select_append`, 2022) rewrites the same line to `arel.project(*default_select_values)`; W3 is
independent of it, and whichever lands second needs a one-line rebase (the first pass of these notes missed it; Sol
found it). No other open PR touches `build_select`'s star line.

**Readability.** L1 (reviewer); the other two branches keep `project(*...)` (the `select_values` branch needs its
String conversion). Same shape as kamipo's 401f146f41 (caller-side, not an Arel signature change). flog 35.5 →
36.9 (a method call replaced by an attribute read plus `<<`); RuboCop Metrics: no offenses.

## Sol round (2026-11-04, run by the coordinator)

Verdict on both: open after fixes, code unchanged.

* **W2.** The order changes from "clock, columns, dirty check, write" to "columns, dirty check, clock, write": clock
  side effects and exceptions disappear when nothing is written, a clock override that touches attributes runs after
  the skip decision, and `||=` retries a clock that returns nil or false (main writes nil to both columns). Accepted,
  no flag for falsy clocks; the body says unused clock reads are removed and the remaining ones move, and that values
  are the same with the standard timestamp methods. Tests added to `timestamp_test.rb` (+34 lines): one clock read
  per changed update (fails on main: 2 calls), one shared time for `updated_at`/`updated_on`, and a `before_update`
  that restores `updated_at` so the second pass must write. Body: "an update that reaches both timestamp passes",
  "calls `with_connection` to reach the adapter", "190 → 189 allocations in this benchmark", Callgrind instructions
  only. Plain description (Sol's): skip explicitly changed timestamp columns, get the time when the first remaining
  column needs it, reuse it for the rest; precedent `AliasTracker.initial_count_for`. `test:sqlite3` 10,284 runs, 0
  failures, 0 errors.
* **W3.** #45864 overlap (above). Exactness limited to Rails' own `SelectManager`: a prepended or overridden
  `project` no longer sees the default star, an overridden `projections` returning a copy would lose it, and
  `build_select` returns the Array in that branch (the caller ignores it). Body says the bypass openly, scopes the
  saving to "each default-star projection", keeps instruction figures to the micro, and gives ZJIT as no measurable
  difference. 401f146f41 (#59579) is cited only as a rest-Array precedent.

## Dropped, rejected, parked

| Candidate | Numbers | Why not |
| --- | --- | --- |
| **W1**: `with_transaction_returning_status` registers the record on the connection it holds (`connection.add_transaction_record(self, …)`) instead of `add_to_transaction`, which checks it out again | `update!` −2.50% / −1.18% (interp / YJIT), `create` −1.17% / −0.73%; ZJIT one run +4.2%, the other −1.2% (main runs 587–590k) | The adversarial round showed a difference through the documented `implicit_persistence_transaction` hook: an override that runs the block on another shard (`connected_to(shard: :other) { … }`) loses `after_commit` on main → candidate (main registers the record where the write happens). Exact only as a deliberate contract change, a maintainer's call. |
| C6-2 preloader class lists in place | census 6: −11 / −14 per preload, 17 apps (on top of #59564) | Cherry-picks onto main cleanly (`git merge-tree` clean), but conflicts with our open #59564 in the same lines; opening it would make one of the two conflict. Parked until #59564 merges. |
| `Arel.sql` empty rest and kwrest | `Arel.sql("x")` 6 objects, `SqlLiteral.new("x", retryable: false)` 4; the rest Array and kwrest Hash are the difference (ZJIT on master already elides the empty rest, not the kwrest) | Public method; avoiding them needs a signature change (`where!`'s form doesn't fit a public API). |
| `any_changes?` → `LazyAttributeSet#keys` | 3 of 5 `keys` calls per `update!`; `has_changes_to_save?` 5.2 µs / 3.1 µs clean | Lives in the attribute set that open #59141 (tenderlove) rewrites; would conflict. |
| `current_time_from_proper_timezone`'s `with_connection` itself | 1.6 µs of 2.0 µs per call | Reading `default_timezone` needs the adapter; caching it per class would miss per-connection config and `connected_to` switches. W2 removes the wasted call instead. |
| `ValidationContext` per `valid?` | 1 object per validated save | Created lazily once per record and reused; not per call. |
| `apply_seconds_precision` → `Time#change` (Rationals on create) | 8 + 6 Rationals per `create` | `change(nsec:)` builds the time through Rationals by design; a faster path is an Active Support `Time#change` question, not exact as a one-liner. |
| `insert_all`/`upsert_all` | 196 / 113 objects | The objects are per row and per value (quoting, the SQL String, `keys.sort!` in `verify_attributes`); nothing repeated. |

## PR bodies (final)

The final bodies, after the outsider read and the Sol round, are
[`w2-body.md`](../../bench/upstream/ar_write_paths/w2-body.md) and
[`w3-body.md`](../../bench/upstream/ar_write_paths/w3-body.md). Titles: "Read the update timestamp only when it is
written" and "Append the default star projection without a rest Array".

## Limits

* Micro cases on SQLite in memory and four-app allocation and CPU censuses, not request time. The CPU census shows
  no app-level change for W2.
* Reviews were subagents; the Sol round runs in the coordinator thread.
