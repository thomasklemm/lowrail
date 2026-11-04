# Active Record write paths: a candidate round (2026-11-04)

A round on the save/update path: dirty tracking, timestamps, `_create_record`/`_update_record`, validations,
callbacks, transaction bookkeeping, `touch`, `insert_all`/`upsert_all`, plus three Active Record/Arel leads from the
census backlog (C6-2, `SelectManager#project`, `Arel.sql`). Same rules as [AR-1](ar-request-paths.md), plus the
readability checks of 2026-11-04 in [DECISIONS](../DECISIONS.md#readability-gate-l0l3) (cold read, shape checklist,
flog/RuboCop numbers, the changed code described in plain sentences).

**Result.** Two candidates queued, waiting for the Sol round: W2 (update timestamps) and W3 (default star
projection). W1 was built, measured and dropped after the adversarial round; the other leads were rejected or
parked (below).

| # | Rails branch @ SHA (fork, pushed) | Change | Per call |
| --- | --- | --- | --- |
| W2 | [`thomasklemm/update-timestamps-time-when-written`](https://github.com/thomasklemm/rails/tree/thomasklemm/update-timestamps-time-when-written) @ `d4db9330ca` | `record_update_timestamps` reads the clock only when it writes a timestamp column | `post.update!` −1 object, −0.9% to −1.6% instructions |
| W3 | [`thomasklemm/build-select-star-projection`](https://github.com/thomasklemm/rails/tree/thomasklemm/build-select-star-projection) @ `600a0192dc` | `build_select` appends the default `table.*` projection instead of calling `project(node)` | −1 object per relation load; −0.2% to −0.4% instructions |

Both on rails/rails main `9b116f1fed`, one commit each, authored and committed by Thomas Klemm. Patches:
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

**Exactness.** Primary and adversarial subagent rounds. Same rows, `lock_version`, counters and errors for: dirty
update; explicit `updated_at`, `updated_on`, both; clean save; `before_update` dirtying a clean record, restoring or
setting `updated_at`; `save(touch: false)`; `record_timestamps = false`; partial updates off; `touch`,
`touch_later`, `update_columns`, `update_attribute`, `increment!`; `belongs_to touch: true` with a counter cache;
`StaleObjectError`; `alias_attribute :updated_at, :modified_at`; `travel_to`; `default_timezone = :local`. Two
updated columns still get the same time. Differences only from accepted categories: an override of the nodoc
`current_time_from_proper_timezone` that counts or fails on its own calls, and a redefined `Time.now` that returns a
new value per call (fewer calls, so later values shift). `test:sqlite3` 10,281 runs, 0 failures, 0 errors; RuboCop
clean. No overlapping PR or issue (`record_update_timestamps`, `current_time_from_proper_timezone`,
`updated_at timestamp twice`); `timestamp.rb` unchanged on main since 2026-11-01 (Markdown).

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
`build_select`. `test:sqlite3` 10,281 runs, 0 failures, 0 errors; RuboCop clean. No overlapping PR.

**Readability.** L1 (reviewer); the other two branches keep `project(*...)` (the `select_values` branch needs its
String conversion). Same shape as kamipo's 401f146f41 (caller-side, not an Arel signature change). flog 35.5 →
36.9 (a method call replaced by an attribute read plus `<<`); RuboCop Metrics: no offenses.

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

## PR bodies (drafts, reviewed)

Checked by a separate reader against the receipts (every number recomputed, PR references confirmed) and for an
outsider's reading; its corrections are applied. The links resolve once this page is on Lowrail main.

### W2: Read the update timestamp only when it is written

> Every update runs `record_update_timestamps` twice: once in `Timestamp#_update_record` before the update callbacks, and again in `Callbacks#_update_record` after the `before_update` callbacks, so a `before_update` that changes the record still gets a fresh `updated_at` (#47767). In an ordinary update the second pass finds `updated_at` already changing and writes nothing, but it still reads the current time first, which checks out the connection to read its `default_timezone`.
>
> This reads the time just before the first timestamp column is written. A pass that writes nothing no longer reads the clock, and a pass that writes both `updated_at` and `updated_on` still gives them the same time.
>
> | `post.update!(views: n)`, instructions per call | Interpreter | YJIT | ZJIT |
> | --- | ---: | ---: | ---: |
> | main | 1,183,587 | 542,188 | 589,258 |
> | this PR | 1,166,927 (−1.4%) | 537,209 (−0.9%) | 580,995 (−1.4%) |
> | Noise check: main run twice | −0.03% | +0.10% | −0.20% |
>
> SQLite in memory, GC disabled. Each number is Callgrind instructions for 500 updates minus a 0-update run, divided by 500; two runs each, median. Ruby 4.0.9; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/ar_write_paths/ar.rb)). One object fewer per update (190 → 189). ruby-bench's apps don't update records in their measured loop, so it can't show this. I found this while profiling the save path of Rails apps on Rails main for Lowrail, a research project of mine ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ar-write-paths.md)).

### W3: Append the default star projection without a rest Array

> Every relation that selects all columns builds `SELECT "posts".*` through `arel.project(table[Arel.star])`. `project(*projections)` allocates a one-element Array for the splat on each call, and its only other work, turning Strings and Symbols into SQL literals, doesn't apply to the star attribute.
>
> This appends the star attribute to the select manager's projections directly, so no Array is built. #59579 removed a similar per-call rest Array from `where!`. The other two branches still call `project`, which converts any Strings or Symbols among their columns.
>
> | `Post.all.to_a`, 20 records, instructions per call | Interpreter | YJIT | ZJIT |
> | --- | ---: | ---: | ---: |
> | main | 860,144 | 417,352 | 413,499 |
> | this PR | 857,888 (−0.26%) | 415,772 (−0.38%) | 412,040 (−0.35%) |
> | Noise check: main run twice | −0.01% | +0.01% | −0.00% |
>
> SQLite in memory, GC disabled. Each number is Callgrind instructions for 500 loads minus a 0-load run, divided by 500; two runs each, median. Ruby 4.0.9; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/ar_write_paths/ar.rb)). One object fewer per relation load in every mode (`Post.all.to_a` 291 → 290 interpreted). On ruby-bench, shipit builds this projection 1,811 times per iteration and lobsters 660 times. I found this in allocation profiles of 20 Rails apps on Rails main for Lowrail, a research project of mine, where the line shows up in all 20 ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ar-write-paths.md)).

## Limits

* Micro cases on SQLite in memory and a four-app allocation census, not request time. The app CPU census for W2 is
  below if it finished in this round.
* Reviews were subagents; the Sol round runs in the coordinator thread.
