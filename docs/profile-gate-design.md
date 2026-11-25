# lowrail-profile 0.1: the compare gate on parallel suites (design note)

Status: decided 2026-11-25: 0.1 ships without a gate ([DECISIONS](DECISIONS.md)); compare is a report. The serial
captures (below) held on OSM and Writebook but not on Hackatime. On main: compare refuses captures of several processes (exit 2),
T7's run deletion and path table, T8's `--timeout`. T1, T2 and T4 of the field test are fixed independently. Covers T3, T5 and T6 (false alarms), T7 (report size) and T8 (hangs) from the OSS field test.
Numbers: [bench/upstream/profile_release/2026-11-25-t3](../bench/upstream/profile_release/2026-11-25-t3/README.md).

## Why one A/A pair breaks on parallel suites

compare assumes two captures of unchanged code differ by noise, and that one more capture of the base (the A/A
report) samples it. With N process workers, a capture is also a *split*. Rails' parallelization hands the next test
to whichever worker is free, so the assignment follows timing. The split decides three things the counts depend on:

* **Which request warm leaves out.** Warm drops each process's first window of an action. With 19
  `NotesController#index` requests over 8 workers, which 8 are dropped decides the value: openstreetmap-website read
  8,063 and 7,624 warm objects per request in base and the A/A report, and 26,106 in head, with the same code.
* **Where one-time work lands.** A template compile or a cache fill runs once per process, in whichever request gets
  there first. So *all* objects per request moves too: `Oauth2AuthorizationsController#create` (9 requests over 8
  workers) read 3,583–3,748 in two captures and 4,264 in a third.
* **Which code paths run.** Each test sees the database and cache state that earlier tests in its worker left.
  Hackatime's `HeartbeatImportDumpJob#perform` reads 1,317–1,376 or 1,535 by capture, and
  `ReconcileActiveRepositoriesJob` reads 696, 848, 880 or 991. Writebook's ActionText `plain_text_conversion` lines
  read 283 or 0.18 objects per request.

The two runs of one capture mostly share a split, because their timing is alike. Between captures the split moves
among a few modes, and one A/A pair samples at most two of them. A head that lands in a third mode fails, whatever
the floor multiple. The fresh app's `journey/path/pattern.rb:77` line (5.57 or 7.14, by how two workers split seven
requests) was the first sign. On OSM, Hackatime and Writebook the effect is large.

## Options, measured

[scripts/options.rb](../bench/upstream/profile_release/2026-11-25-t3/scripts/options.rb) runs the gem's own
`Lowrail::ProfileCompare` over every assignment of distinct captures (300 sampled base assignments for the 24 fresh-app
captures). A false alarm is an unchanged head that exits 1. A plant is caught when a row matching it exits 1, in
both comparisons for the CI job (head profiled again on exit 1).

| App (captures) | Today: one A/A pair | Three base captures | Actions on *all* | One process per capture |
| --- | --- | --- | --- | --- |
| Blog, 1 process (12 + 3 planted) | 1.67% / 0.03%, plants 100% | 0.25% / 0%, plants 100% | 1.89% / 0.03% | (already one process) |
| Fresh app, 2 workers (24) | 0.82% / 0.16% (all assignments) | 0.08% / 0.02% | 0.86% / 0.12% | 0% / 0% (12 captures) |
| Campfire, 8 workers (3 + 2) | 0 of 6, plants 12 of 12 | too few captures | 0 of 6 | 8.3% / 0% (2 of 24, one action), k3 0 of 4; plants 100% |
| CodeTriage, Lobsters, 1 process (3 + 2 each) | 0 of 6, plants 100% | too few captures | 0 of 6 | (already one process) |
| OSM, 8 workers (4) | 79% / 67% | 1 of 4 | 83% / 67% | 0 of 24 / 0 of 24, plant 12 of 12 (4 + 1 planted, about 9.5 min each) |
| Hackatime, 2 workers (6 + 2) | 52.5% / 34.4%, plant 17% / 7% | 20% / 6.7%, plant 2.5% / 0% | 67% / 47% | **12.5% / 4.4%, plant 52% / 50%**; three base captures 3.3% / 1.7%, plant 40% |
| Writebook, 16 workers (6 + 2) | 26.7% / 11.7%, plant 0% | 5% / 0%, plant 0% | 50% / 26% | 0% / 0%, plant 100% / 100% (plant in `SessionsController#create`) |
| Writebook, 4 workers (6 + 2) | 2.5% / 0.56%, plant 0% | 0% / 0%, plant 0% | 11.7% / 3.3% | |

Each cell gives false alarms for one compare / the CI job. Writebook's plant is in `BooksController#index`, which
runs once per worker and so has no warm value. Its line rows move +0.4 against a floor of 1.0. The serial captures
plant `SessionsController#create` instead (64 requests per run): +55 against a floor of 20 of 1,607.

**Hackatime in one process.** Its false alarms are not the split: `Admin::AdminUsersController#index` (6 requests)
reads about 14,700–14,730 or 14,785–14,817 warm objects per request by capture, a 0.7% move the same code makes
with other data, and one A/A pair often sees only one of the two values. The plant adds +40–60 to
`LeaderboardsController#index`, whose unchanged captures read 7,882–7,916, so it is about twice the noise and
found half the time.

* **A. One process per capture** (`PARALLEL_WORKERS=1`, and compare refuses captures of several processes with exit
  2): the split disappears, and the order is the seed's. Where measured, false alarms are at or near zero and the
  floors stay small (an action's 20 objects, 0.1–0.8% of it). The cost is suite time. OSM's 81 s on 8 workers is
  about 10 min serial, so the CI job (three captures of two runs, a fourth on exit 1) takes about an hour. A
  `--runs 1` capture would halve that, but then a capture has no spread of its own.
* **B. Several base captures** (base's value their mean, its noise their spread): it helps where the split has few
  modes (Writebook 4 workers, the Blog) and not where it has many (Hackatime still 20% / 6.7%, OSM 1 of 4). Its floor
  grows with the modes (Hackatime's median action floor 126 → 271 objects), so plants fall below it. It costs one
  more capture per run.
* **C. Actions on *all* instead of warm**: worse on every app, because one-time work moves with the split too.
  Rejected.
* **D. Mark rows whose sample composition differs as not comparable**: not measured. It needs a new record per
  window (which test or request was each process's first) that no report has. On OSM nearly every action runs in
  every worker, so most rows would be marked, which is A's coverage with more machinery.
* **E. A deterministic split** (pin each test to a worker by index): it changes how the suite runs, by replacing
  Rails' executor, which is against "the suite runs as it would". Not for 0.1.
* **F. No gate on parallel captures in 0.1**: compare without `--aa` lists changes and exits 0. With `--aa` it
  exits 2 on captures of several processes.

## How small a regression the gate finds

* One process: an action change of 20 objects per request, or 0.1% of the action if that is larger (Campfire's
  `RoomsController#show`: +44 against a floor of 26 of 25,843; CodeTriage +39 against 20; Lobsters +60 against 20).
  A line needs 1 object per request *averaged over all requests*, so a change in one action shows on its lines at
  that action's share. The Blog's `html_escape` plant moves `output_safety.rb:228` by +1.7 and is caught.
* Hackatime (2 workers): the plant adds +50–63 to `LeaderboardsController#index` (8,260 objects) against a floor of
  80–98, and its line +0.6 against 1.0. It is not reliably found (17% / 7%). The median action floor is 126 objects
  (7.4% of the action); the A/A pair sets it, and it is still too small to stop the false alarms.
* Writebook (16 workers): the plant's action has no warm value, and its line moves +0.4. It is not found. OSM
  (8 workers): the median action floor is 474 objects (9% of the action), and 79% of unchanged heads still fail.

## Recommendation

**A, with F as the boundary.** 0.1 gates only captures of one process. compare exits 2 on a capture of several
processes, naming `PARALLEL_WORKERS=1` (the T3 change, held back as [t3-held-compare.patch](../bench/upstream/profile_release/2026-11-25-t3/t3-held-compare.patch): its test fails without it).
The README's CI job sets `PARALLEL_WORKERS: 1` and states the suite-time cost. Parallel captures stay useful as a
report and as compare without `--aa`. B is an optional later improvement on one-process captures (the Blog 1.67% →
0.25%), not a fix for parallel ones. This depended on the serial captures. OSM and Writebook hold (0 false alarms,
every plant caught); Hackatime does not (12.5% / 4.4%), above the Blog's 1.67% / 0.03% and the fresh app's 0 / 0.
By the decision, 0.1 therefore ships without a gate: compare is a report.

## T7: report size and memory

Sure (16 workers): run 2 (attribution) writes 16 TSVs of about 240 MB, 3.3 GB per capture, and the report takes
about 6 min at 7.1 GB RSS. Measured on Campfire (one process): run 2's TSV is 51 MB for 180,789 attribution rows.
Absolute paths are 81% of its bytes, and it gzips 12×; report.json is 3.4 MB. Splitting the rows into their two-way
projections would save only 15% (153,816 pairs). Proposal, smallest first:

1. Delete `run*/` after a report is written, unless `--keep-runs`. compare reads only report.json, so the CI job
   keeps four files of a few MB.
2. Write each file path once per TSV (a `P id path` table) and ids in rows: about 5× smaller on disk and to parse.
3. Read TSVs one at a time into integer-keyed totals, not row arrays, so memory follows unique keys rather than
   rows × processes.

Under A, a capture is one process: one TSV instead of 16, about the size of their union.

## T8: hangs

Fizzy hangs in about 1 of 14 profiled runs, in a require/autoload deadlock with turbo-rails' `ThreadDebouncer`,
with no lowrail frame on the stack; whether plain runs hang too is open. Proposal: `--timeout SECONDS` per run. With
it, the command starts in its own process group, and lowrail-profile forwards `INT` and `TERM` to it. At the
deadline it sends `TERM`, then `KILL` after 10 s, and exits 124 (as `timeout(1)` does). capture.json records the
run as `timeout`, and compare treats it as a failed run (exit 2). No default timeout: CI jobs have their own, and
the flag makes the failure clean and named.

## To decide

1. A for 0.1 (gate only one-process captures, at the cost of serial suite time), or F (no gate in 0.1).
2. Whether 0.1 includes T7's items 1–3, or only item 1.
3. `--timeout` in 0.1.
