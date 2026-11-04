A relation that selects all columns builds `SELECT "posts".*` through `arel.project(table[Arel.star])` in `build_select`. `project(*projections)` allocates a one-element Array for the splat on each call, and its only other work, turning Strings and Symbols into SQL literals, doesn't apply to the star attribute.

This appends the default star to the manager's projections directly instead of going through `project`, so that temporary Array isn't built for each default-star projection. With Rails' own `SelectManager` the projections and SQL are the same; an override of `project` no longer sees the default star. The other two branches still call `project`. #59579 removed a similar rest Array from `where!`. This is independent of #45864 (`select_append`), which rewrites the same line; whichever lands second needs a one-line rebase.

| `Post.all.to_a`, 20 records, Callgrind instructions per call | Interpreter | YJIT |
| --- | ---: | ---: |
| main | 860,144 | 417,352 |
| this PR | 857,888 (−0.26%) | 415,772 (−0.38%) |
| Noise check: main run twice | −0.01% | +0.01% |

SQLite in memory, GC disabled. Each number is Callgrind instructions for 500 loads minus a 0-load run, divided by 500; two runs each, median, on Ruby 4.0.9 ([script](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/bench/upstream/ar_write_paths/ar.rb)). ZJIT on Ruby master 9aa0898240 shows no measurable difference. One allocation fewer per default-star projection (`Post.all.to_a` 291 → 290). On ruby-bench, shipit builds this projection 1,811 times per iteration and lobsters 660. I found this in allocation profiles of 20 Rails apps on Rails main for Lowrail, a research project of mine, where the line shows up in all 20 ([notes](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/docs/upstream/ar-write-paths.md)).
