`build_select` now appends the default `table.*` attribute to the manager's projections directly instead of going through `project`, which built a one-element splat Array each time. With Rails' own `SelectManager` the projections and SQL are the same, because `project` only converts Strings and Symbols; an override of `project` no longer sees the default star.

| `Post.all.to_a`, Callgrind instructions | Interpreter | YJIT | ZJIT |
| --- | ---: | ---: | ---: |
| main → this PR | −0.26% | −0.38% | no measurable difference |

One allocation fewer per default-star projection; shipit on ruby-bench builds 1,811 per iteration. Independent of #45864, which rewrites the same line; #59579 removed a similar rest Array from `where!`.

<details><summary>Method</summary>

SQLite in memory, GC disabled; Callgrind instructions for 500 loads of 20 records minus a 0-load run, two runs each, median; main against itself ≤ 0.01%. Ruby 4.0.9; ZJIT on Ruby master 9aa0898240. `Post.all.to_a` 291 → 290 allocations; lobsters builds 660 such projections per iteration. The line appears in allocation profiles of all 20 apps in [Lowrail](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/docs/upstream/ar-write-paths.md), my research project ([script](https://github.com/thomasklemm/lowrail/blob/d7ed9c36780d4393cb3da256b815938fe43a9dec/bench/upstream/ar_write_paths/ar.rb)).
</details>
