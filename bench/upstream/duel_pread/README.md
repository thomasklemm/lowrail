# Duel's Linux counter on a perf fd: ESPIPE before, counts after (DUEL2, 2026-11-27)

`Native::Linux#read` read the perf_event_open(2) fd with `IO#pread(8, 0)`. A perf fd can't seek, so pread(2) fails
with ESPIPE on every read, and wherever Linux offers the counters Duel's instructions metric errors every benchmark.
Fix: `@io.sysread(8)` (read(2)), fork `thomasklemm/duel-ruby:pread-perf-fd` at `90bf2a5` (reviewed as `738d9ba`; only the test fake and message changed since), one commit on
`a09111e` (sferik main).

## Runs (GitHub runners, fork thomasklemm/hashie branch `pread/repro`, Ruby 4.0.10)

Duel cloned at each commit, `ruby -I/tmp/duel/lib`; logs in `runs.tar.gz`.

* **Matrix, run 45998150957** (`pread-repro-matrix.yml`): 24 `ubuntu-latest` + 4 `ubuntu-24.04-arm` jobs, each
  `sudo sysctl kernel.perf_event_paranoid=2`, then `Duel::Native::Counter.open` and 8 × `read` around a
  100,000-iteration loop.

  | Runner (jobs) | `a09111e` | `738d9ba`, instructions per loop |
  |---|---|---|
  | ARM, Azure Neoverse N2 `0xd49` (4) | `Linux`, `read` raised `Errno::ESPIPE: Illegal seek` | first loop 52,210,071–52,210,112, then 52,204,137 on every loop, all 4 runners (deltas between two reads) |
  | x86, AWS Xeon 6975P-C (3) | same error | 56,908,9xx, then 56,903,536–56,904,025 |
  | x86, Azure EPYC 7763/9V74/9V45, Xeon 6973P-C, 8370C, 8573C (21) | `Counter.open` nil (no counters) | nil |

* **ARM at the default paranoid, runs 45999176517 and 45999296054** (`pread-repro-arm.yml`, 2 jobs each): default
  `perf_event_paranoid` is 4 and `Counter.open` is nil on both commits; only the sysctl exposes the counters.
* **Duel end to end on ARM, run 45999296054** (2 jobs, after the sysctl): one benchmark, `--jobs 1 --processes 4`.
  `a09111e`: `ERROR work: Duel::Failed: base-1: Errno::ESPIPE: Illegal seek` at `native.rb:78:in 'IO#pread'`, 1
  error. `738d9ba`: `instructions 1.000 [1.000, 1.000] same`, 0 errors, in both jobs.

## Checks on 90bf2a5 (orb, Ruby 4.0.9)

`rake test` 927 runs, 0 failures, 100% line/branch/method coverage; the changed fake (a pipe) makes 2 tests error
with ESPIPE on `a09111e`. `mutant run --since origin/main -j 1`: 1 subject (`Duel::Native::Linux#read`), 16/16
killed. rubocop, standardrb, `rake typecheck` clean.
