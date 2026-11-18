# RK3 on the exact head: cohort manifest

Declared 2026-11-18 before any measured process ran, committed with the results. Each cohort runs once. A rejected
cohort stays recorded and is not rerun.

Head `c0a8e93011` (thomasklemm/rack, decode `9285fa0f4d` + escape `c0a8e93011`) against rack main `da90464e3f`.
Ruby 4.0.9, pinned Valgrind 3.19.0 with the 512 MiB brk reservation (`script/bench-valgrind ~/w/valgrind-brk512`,
manifest in each cohort's `valgrind.json`), `--verbose` logs kept. Every count is the trailing `totals:` line of
its Callgrind dump, not `summary:` or the log's `Collected`.

## Cohort M: micro (body table)

```sh
mise exec ruby@4.0.9 -- script/upstream-bench --out bench/upstream/rk3/body/RK3-head \
  --base /home/user/up/rack-main --candidate /home/user/up/rack --ruby 4.0.9 \
  --valgrind /home/user/w/valgrind-brk512 --modes interp,yjit --names main,branch bench/upstream/rk3/RK3_body.rb
```

The same three cases as the body's table (`RK3_body.rb`, unchanged). Fixed heap floors, GC off in the windows,
N = 2000 minus N = 0, base / candidate / base per cell (A/A = main vs. main). Changed in `script/upstream-bench`
before this run: it keeps each dump in `raw/` and reads its `totals:` line.

* Rejected as a whole on a brk overflow in any log (the script aborts) or a failed process.
* A cell is claimed only when its change exceeds its A/A; a YJIT cell only when every window is JIT-flat. The body
  uses the interpreter rows only.

## Cohorts R-interp and R-yjit: whole requests on full checkouts

Each app's census copy (blog on Rails `4500a94c34`, pingcrm and codetriage on Rails `50c54eed06`, as before) runs a
census Gemfile variant that pins `rack` to the git commit: main `da90464e3f` or head `c0a8e93011` (`prep.rb`
checks the loaded Rack, its revision and the guard line, and that the two variants resolve identical third-party
gems: [`prep.txt`](prep.txt)). Nothing is overlaid after boot.

```sh
cd bench/upstream/rk3/head
NOGC=1 GLIBC_TUNABLES=glibc.malloc.mxfast=0 ./batch.sh $PWD/interp interp ../req/wl-interp.txt
NOGC=1 WARM=1000 FLAT=40 ./batch.sh $PWD/yjit yjit ../req/wl-yjit.txt
```

Workloads as before: interp blog PATCH article, pingcrm PUT contact, blog GET article, codetriage GET repo, blog
GET articles.json (control); YJIT the same without codetriage. 20 measured requests per process, counting only
`Rails.application#call`, GC off; 200 warm-up requests in the interpreter, 1,000 plus up to 40 settling windows
under YJIT. Per workload one process each of main, main, head, main; A/A = (max − min) / mean of the three main
runs. Interpreter with glibc fastbins off (as the accepted earlier cohort, after two default-allocator cohorts were
rejected for fastbin consolidation), YJIT with the default allocator (as its accepted earlier cohort). R-interp,
then R-yjit, one chain; cohort M runs alongside it (two CPUs).

* Rejected as a whole on a brk overflow in any log, a failed process, or any workload with A/A above 1.0%.
* R-yjit is also rejected if any measured window compiled or invalidated (`jit` not `0/0`).
* A workload's change is claimed only when it exceeds its A/A.

## What changed from the earlier request runs

* The full head checkout replaces the method overlay on Rack 3.2.7: base is rack main `da90464e3f`, not 3.2.7.
* No decode-only column: the earlier `rk3.rb` (first commit's methods alone) has no full-checkout counterpart
  here, so only main vs. head is measured.
* The pinned 512 MiB-brk Valgrind with brk refusal and `totals:` replaces the stock `valgrind` and dump sums.

## Results

Filled in after the runs.
