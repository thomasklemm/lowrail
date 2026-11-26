# Hackatime and Writebook captures behind the compare decision (census field test)

These are the census field test's Hackatime and Writebook captures that [../README.md](../README.md) and
[docs/profile-gate-design.md](../../../../../docs/profile-gate-design.md) measure: 6 unchanged and 2 planted
per set. The record is now committed here; the earlier pointer to `oss_profile_sweep_1/` held only OSM's captures.

The gem is lowrail-profile 0.1.0.rc1, built at lowrail `aa4422c8` (sha256 `f569d5f5…a86d31`) and installed with
`gem install --local` plus one Gemfile line. Every capture runs `bin/rails test -v` with seed 1234 and 2 runs, and
every run exited 0. The app tree was unchanged after each unchanged capture.

* Hackatime: `74deec4`, Ruby 4.0.6, Postgres.
* Writebook: `be1f8fc`, Ruby 4.0.7, SQLite.

| Set | Workers | Unchanged | Planted (`planted.patch`, the same in both) |
| --- | --- | --- | --- |
| [hackatime](hackatime) | 2 (the app's default) | `u1`–`u6` | `planted`, `planted2`: `LeaderboardsController#index` |
| [writebook](writebook) | 16 (the app's default, one per CPU) | `u1`–`u6` | `planted`, `planted2`: `BooksController#index` (runs once per process: no warm value) |
| [writebook-w4](writebook-w4) | `PARALLEL_WORKERS=4` | `u1`–`u6` | `planted`, `planted2`: `BooksController#index` |
| [hackatime-serial](hackatime-serial) | `PARALLEL_WORKERS=1` | `s1`–`s6` | `splanted`, `splanted2`: `LeaderboardsController#index` |
| [writebook-serial](writebook-serial) | `PARALLEL_WORKERS=1` | `s1`–`s6` | `splanted`, `splanted2`: `SessionsController#create` (64 windows per run) |

The plant is `20.times { ERB::Util.html_escape("a<b") }` as the action's first line. The planted captures' patch,
shown only for its `app/` hunk, is in each set's `planted.patch` or `splanted.patch`.

Each capture directory holds the capture's `capture.json` and `command.txt`, plus `report.json.gz` (its `report.json`
gzipped, which `options.rb` and `gate.rb` read). rc1 writes no `measured.json`. `wall.txt` has each capture's exit
code and wall time; the serial sets ran one after another, and the parallel sets ran beside other apps' suites.
The raw runs were deleted to save disk space. Only Hackatime `u1`'s runs survive, as
[hackatime/runs-u1.tar.xz](hackatime/runs-u1.tar.xz): `run1` is 8.4 MB and `run2` 96 MB of TSV in rc1's format (before T7's format 3).

## Replay

`options.rb` leaves out compare's refusal of multi-process captures (`abf515d3`) and reads format 2 reports as
format 3, so main's `gem/lib` replays all five sets: they reproduce `../options-*.txt` byte for byte. The `gem/lib`
of `3c878c94`, the design note's commit, does too. From this directory's parent:

```sh
ruby -I../../../../gem/lib scripts/options.rb \
  "Hackatime, 2 workers" 'LeaderboardsController#index|output_safety|erb/util' \
  census/hackatime/u{1,2,3,4,5,6} -- census/hackatime/planted census/hackatime/planted2
```

`scripts/run_options.sh SET` runs each set with its name and regex from here.
