# RK3 on the exact head: cohort manifest

Declared 2026-11-18 before the declared cohorts ran (a WARM=5/N=2 pipeline smoke test ran earlier and is not evidence), committed with the results. Each cohort runs once. A rejected
cohort stays recorded and is not rerun.

Head `c0a8e93011` (thomasklemm/rack, decode `9285fa0f4d` + escape `c0a8e93011`) against rack main `da90464e3f`.
Ruby 4.0.9, pinned Valgrind 3.19.0 with the 512 MiB brk reservation (`script/bench-valgrind ~/w/valgrind-brk512`,
manifest kept with cohort M as `valgrind.json`; the request cohorts used the same prefix), `--verbose` logs kept. Every count is the trailing `totals:` line of
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

Each cohort ran once, all three accepted. No Valgrind log has a brk overflow, every dump has a `totals:` line (the
process-exit dumps of the request runs are all `totals: 0`; in the micro dumps `summary:` equals `totals:`), and no
process failed. A launch before the scripts existed started nothing and measured nothing.

**Cohort M** ([`../body/RK3-head`](../body/RK3-head/table.md), `valgrind.json` equal to the prefix's manifest): every
cell is claimed; YJIT cells are JIT-flat in all 6 windows.

| Interpreter, per call | Main (A/A) | Head | Change | Objects |
| --- | ---: | ---: | ---: | --- |
| `parse_nested_query` | 184,866 / 184,536 (0.18%) | 121,136 | −34.4% | 100 → 51 |
| `parse_cookies_header` | 71,386 / 71,466 (0.11%) | 36,470 | −48.9% | 34 → 17 |
| `set_cookie_header` | 103,951 / 104,199 (0.24%) | 28,580 | −72.5% | 29 → 15 |

YJIT: −42.5% (A/A 0.11%), −52.0% (0.02%), −74.8% (0.09%), same objects.

**Cohort R-interp** ([`interp/results.txt`](interp/results.txt), [`interp/table.md`](interp/table.md)): accepted,
worst A/A 0.27%.

| Workload | A/A | Main | Head | Change | Objects main → head |
| --- | ---: | ---: | ---: | ---: | --- |
| blog PATCH article (redirect) | 0.27% | 4,692,856 | 4,433,253 | −5.53% | 1433.0 → 1281.7 |
| pingcrm PUT contact (Inertia redirect) | 0.23% | 7,107,335 | 6,879,118 | −3.21% | 1824.3 → 1717.4 |
| blog GET article | 0.05% | 8,338,573 | 8,210,414 | −1.54% | 2020.8 → 1958.6 |
| codetriage GET repo | 0.12% | 14,880,426 | 14,726,281 | −1.04% | 3264.1 → 3198.6 |
| blog GET articles.json | 0.02% | 4,233,873 | 4,233,067 | within A/A | 1126.6 → 1126.6 |

**Cohort R-yjit** ([`yjit/results.txt`](yjit/results.txt), [`yjit/table.md`](yjit/table.md)): accepted, worst A/A
0.40%, every window `jit 0/0` after one settling window.

| Workload | A/A | Main | Head | Change | Objects main → head |
| --- | ---: | ---: | ---: | ---: | --- |
| blog PATCH article (redirect) | 0.37% | 2,574,045 | 2,315,864 | −10.03% | 1437.7 → 1286.8 |
| blog GET article | 0.33% | 4,752,210 | 4,621,296 | −2.75% | 2033.7 → 1969.7 |
| pingcrm PUT contact (Inertia redirect) | 0.40% | 4,084,924 | 3,861,941 | −5.46% | 1834.0 → 1728.4 |
| blog GET articles.json | 0.24% | 2,217,952 | 2,210,626 | −0.33% | 1135.6 → 1135.6 |

The YJIT JSON control is −0.33%, just outside its 0.24% A/A, with identical objects; it is not attributed to the
change and not used. The body takes the micro table's interpreter rows and the YJIT range over the three requests
that read or write the session cookie, rounded to what the A/A supports: 3% to 10%.

Per-process files in `interp/raw` and `yjit/raw`: the exact command and environment (`.cmd`), the verbose Valgrind
log, and stderr (`OBJS`, `JIT`, `SETTLE`); the dumps are in each cohort's `callgrind-dumps.tar.xz`.
