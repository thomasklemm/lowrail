# lowrail-profile 0.1.0.rc1: the compare gate on parallel suites (2026-11-25)

Receipts for [docs/profile-gate-design.md](../../../../docs/profile-gate-design.md) (field-test findings T3, T5, T6).

* [scripts/options.rb](scripts/options.rb) runs the gem's own `Lowrail::ProfileCompare` for each design option over
  every assignment of distinct captures to base (one or three captures), head and head2, and reports false alarms
  for one compare and for the README's CI job, plant detection, and the median floors. Its per-set outputs are
  `options-*.txt`, written by [scripts/run_options.sh](scripts/run_options.sh) `SET`.
* New captures, made with `PARALLEL_WORKERS=1` through [scripts/serial.sh](scripts/serial.sh), from a gem built at
  lowrail main `a4bc8d5a` (T1 and T2, sha256 `65a01b1f…` with the held T3 compare change; capture code as on main):
  * [fresh-81](fresh-81): the fresh Rails 8.1 app of the final receipts (two process workers there), captured 12
    times in one process (`s1`–`s12`), each from emptied tables.
  * [campfire](campfire): Campfire `bin/rails test -v`, 4 unchanged captures in one process (`s1`–`s4`) and 2 with the
    M4 plant (`planted`, `planted2`), through the M4 proof.sh. Every run exited 0, and the tree was unchanged.
* Earlier captures are read from their receipts: the Blog (M4, fixes, confirm-opus), the fresh app with two workers
  (final `c1`–`c24`), and Campfire with 8 workers, CodeTriage and Lobsters (M4 and final `planted2`).
* The OSM, Hackatime and Writebook captures come from the field-test threads. Hackatime and Writebook are in
  [census](census) (report.json.gz, capture.json, command.txt, plant patches, wall times), where `run_options.sh`
  reads them; OSM's are in [oss_profile_sweep_1/osm](../../oss_profile_sweep_1/osm) (`base`, `aa`, `head`,
  `head2` with 8 workers, `s1`–`s5` in one process). `scripts/options.rb` leaves out
  compare's refusal of captures of several processes (`abf515d3`) and reads format 2 reports as format 3, so the
  parallel sets replay with main's `gem/lib` too; with the `gem/lib` of `3c878c94` they replay as published. OSM:
  openstreetmap-website 20ae45ec, Ruby 4.0.9, Rails 8.1.4.1, `bin/rails test -v`, 8 workers, 4 unchanged captures.
  Hackatime (2 workers) and Writebook (16 and 4 workers): 6 unchanged and 2 planted each, from the gem at
  `aa4422c8` (sha256 `f569d5f5…`).
