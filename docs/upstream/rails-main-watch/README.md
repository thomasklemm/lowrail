# Rails main watch

A daily regression watch on rails/rails `main`: the [census](../census.md) (nine apps, ten configurations, 97
workloads, interpreter and YJIT) at current `main`, compared with the last recorded `main`, per workload and per
allocation line, with its own A/A floor, plus SQL and behavior controls. New or grown allocations and behavior
changes are attributed to the commit that introduced them. It exists because 2b88dc1995 (in #58663) changed
`Hash#index_with` block arguments on `main` and nobody noticed for seven weeks (fix: rails/rails#59555); the census
then measured allocations and SQL, not results.

```sh
script/census watch --jobs 8              # current main against baseline.json's commit
script/census watch --base SHA --head SHA # any range, e.g. to validate
```

Each run writes `YYYY-MM-DD.md` here (a short report), trimmed receipts for both ends in `data/SHA12.json.gz`,
updates `data/floors.json` and moves `baseline.json` to the measured head. When `main` has not moved since the
baseline, it prints `WATCH: … unchanged` and writes nothing. The last line is `WATCH: quiet` or `WATCH: MOVED`.

## What it compares

* **Pairs.** Each end is measured twice (`script/census run --aa`, labels `w-SHA12` and `w-SHA122`). A base measured
  in an earlier orb is read back from its trimmed receipts, so the census copies may be set up anew (`script/census
  setup --rails <baseline>`, services as in [census.md](../census.md)).
* **Workloads.** The census value (median GC-enabled objects per operation). A workload moved when all four
  base×head deltas exceed its floor in the same direction, by at least one object, and the traced (GC-disabled)
  count of the same operations moves the same way in all four. The floor is the largest A/A difference of that
  workload in either mode, either pair or any earlier run (`data/floors.json`), so write and job workloads with
  cache, timestamp or growing-data noise need a large move to count.
* **Lines.** Objects per traced operation per Rails line, summed over classes. Head lines are mapped to the base's
  numbering through `git diff -U0`, so a line that only shifted is the same line. A line added or changed in the range
  is *new*. A line moved under the same four-delta rule, with the larger of the workload floor and the line's own A/A.
  *Net file Δ* is the line's whole file over the same workload; a line that grew while its file stayed flat only moved
  (an allocation that moved from one line to another), and is listed but not counted as growth.
* **SQL.** Each workload's masked statement digest. A diff counts only when both pairs are internally stable.
* **Behavior controls.** [`watch_controls.rb`](../../../bench/upstream/census/watch_controls.rb) calls every Active
  Support core extension on Enumerable, Array, Hash, String, Symbol and Range with fixed receivers (including Hash,
  HashWithIndifferentAccess, Struct, Set and an Enumerable that yields two values), arguments and block shapes, and
  prints each result. Census 4 and 5's controls add Active Record relation SQL and results. Each runs twice per end in
  Blog's bundle; lines that differ within a pair are ignored.

## Attribution

Commits in range are `main`'s first parents. A new line is attributed by `git blame` at head to the commit that
wrote it, and to the merge that landed it. Everything else (a grown line, a workload without a moved line, an SQL or
control diff) is bisected. Each step measures only that workload in its own process at that commit (bisect receipts
are cached under `.lowrail/private/census/watch-bisect`), first over the merges, then inside the merged branch. The
metric is the line's file total (a workload's traced total, the SQL digest, or the control lines). A move that does
not reproduce in a one-workload process is reported as such and not bisected. `--bisect N` caps the bisections per
run (default 20).

Allocation counts only; no timing is inferred ([DECISIONS](../../DECISIONS.md)).

## Validation (2026-11-03)

[`validation/58663.md`](validation/58663.md): the watch over the six merges around #58663, from `c1aac32006` to
`91ea391a11`, as if run on 2026-09-15. Ruby 4.0.7, ten configurations, both modes; 23 minutes, both pairs and the
bisections included.

* **Behavior:** `watch_controls.rb` differs on 36 `Enumerable#index_with` lines, 12 each for Hash,
  HashWithIndifferentAccess and Struct receivers (`{a: 1}.index_with { |k, v| … }` now indexes `:a` with `v = nil`). Bisection
  over the merges and then inside the branch names 2b88dc1995 itself, the regression rails/rails#59555 fixed (merged 2026-11-03). The
  census 4 and 5 controls stay identical.
* **Allocations:** 163 of 194 workload×mode cells moved beyond A/A, 155 attributed to 2b88dc1995 and the rest to
  other #58663 commits (1fbedade58, 3be318dff8). The largest is +444 objects/op on Lobsters `GET story.json`, mostly
  `enumerable.rb:88` (the pair array per `index_with` element, +387). The pair array is still on main
  (`Array#index_with` since #59555): #59203 reverted the each-loop version for Ruby 4.1 hash embedding, and rails/rails#59557 (open) removes
  the pair arrays on Ruby 4.1 ([index-with-capacity](../index-with-capacity.md)).
* **Noise:** no SQL diff and no unstable SQL workload. Two rules came from earlier passes: a moved workload's traced
  count must agree (on this range a Fizzy YJIT `POST comment.json` rose +160 by its census value while its traced
  count fell), and the floor covers both modes (on main, Blog's broadcast job had a YJIT A/A of 0 and an
  interpreter A/A of 65).
  Masking the sign of numbers in the SQL control removed SolidCache `key_hash` flips, which had made 12 to 17
  workloads unstable and one look like a real diff.

## Daily run

The thread that owns the watch reruns `script/census watch --jobs 8` every 24 hours, commits the report and receipts
to `thomasklemm/rails-main-watch`, and reports only `WATCH: MOVED` runs. Services and copies are those of
[census.md](../census.md#services-and-apps); `setup --rails <baseline.json's commit>` rebuilds lost copies.
