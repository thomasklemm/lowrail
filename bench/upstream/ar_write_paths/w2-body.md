`record_update_timestamps` now reads the clock only right before it writes the first timestamp column, instead of at the start of every pass. Written values are the same with the standard timestamp methods; clock reads whose result was never used are gone, and the rest now come after the skip check.

An update that reaches both timestamp passes (#47767) usually writes nothing in the second, but still called `with_connection` to reach the adapter's `default_timezone`.

| `post.update!`, Callgrind instructions | Interpreter | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| main → this PR | −1.4% | −0.9% | −1.4% |

Tests cover one clock read per update, one shared time for `updated_at`/`updated_on`, and a `before_update` that forces the second pass to write.

<details><summary>Method</summary>

SQLite in memory, GC disabled; Callgrind instructions for 500 updates minus a 0-update run, two runs each, median; main against itself ≤ 0.20%. Ruby 4.0.9; ZJIT on Ruby master 9aa0898240. 190 → 189 allocations in this benchmark (`freeze_time`, explicit timestamps or disabled timestamping differ). ruby-bench's apps don't update records in their measured loop. [Script](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/bench/upstream/ar_write_paths/ar.rb), [notes](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/docs/upstream/ar-write-paths.md) from Lowrail, my research project.
</details>
