An update that reaches both timestamp passes runs `record_update_timestamps` twice: in `Timestamp#_update_record` before the update callbacks, and in `Callbacks#_update_record` after the `before_update` callbacks, so a callback that changes the record still gets a fresh `updated_at` (#47767). In an ordinary update the second pass finds `updated_at` already changing and writes nothing, but it still read the current time first, which calls `with_connection` to reach the adapter's `default_timezone`.

This skips the timestamp columns that are already changing, gets the time when the first remaining column needs it, and reuses it for the rest. Clock reads whose result was never written are gone, and the remaining ones now happen after the skip check instead of before it. With the standard timestamp methods the written values are the same.

| `post.update!(views: n)`, Callgrind instructions per call | Interpreter | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| main | 1,183,587 | 542,188 | 589,258 |
| this PR | 1,166,927 (−1.4%) | 537,209 (−0.9%) | 580,995 (−1.4%) |
| Noise check: main run twice | −0.03% | +0.10% | −0.20% |

SQLite in memory, GC disabled. Each number is Callgrind instructions for 500 updates minus a 0-update run, divided by 500; two runs each, median. Ruby 4.0.9; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/bench/upstream/ar_write_paths/ar.rb)). In this benchmark an update allocates 190 → 189 objects; with `freeze_time`, explicit timestamps or timestamps turned off the counts differ. ruby-bench's apps don't update records in their measured loop, so it can't show this. The new tests cover one clock read per update, one shared time for `updated_at` and `updated_on`, and a `before_update` that restores `updated_at`, so the second pass has to write it. I found this while profiling the save path of Rails apps on Rails main for Lowrail, a research project of mine ([notes](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/docs/upstream/ar-write-paths.md)).
