# lowrail-profile 0.2 gate candidates, evaluated on the 0.1 receipts (2026-11-25)

Receipts for [docs/profile-0.2-design.md](../../../../docs/profile-0.2-design.md). No new captures: every number
comes from captures made for 0.1.

* [scripts/noise_gate.rb](scripts/noise_gate.rb) evaluates the candidate gates over every assignment of distinct
  unchanged captures of one app to k base captures (k = 2–5), head and head2 (120 sampled base sets, seed 1, where
  there are more). It reads report.json warm vectors itself and does not load the gem (the builder thread is
  changing gem/). Run it from `scripts/` with Ruby 4.0.7: `ruby noise_gate.rb > ../results.md` (about 5 min). The
  `aa1` rows are 0.1's rule. On Hackatime they reproduce
  [options-hackatime-serial.txt](../2026-11-25-t3/options-hackatime-serial.txt) exactly (12.50% / 4.44%, plant 51.67% /
  50%), and `range-2 k3` reproduces its `k3` (3.33% / 1.67%, plant 40%).
* [results.md](results.md) is its output: one table per app, then the worst case across the one-process apps.
* [captures/](captures): the Hackatime and Writebook captures behind the 0.1 decision, which until now existed only
  in the builder thread's orb (`.amp/in/orb-backup/census/`). They are gzipped report.json files and nothing else
  (no capture.json was kept). First 16 hex digits of the sha256 of each uncompressed report.json:

  | Set | Captures (sha256 prefix) |
  | --- | --- |
  | hackatime-serial (`PARALLEL_WORKERS=1`, 123–144 s each) | s1 3c906ba20462127b, s2 f863d513b15030e6, s3 4ab629ec88089224, s4 4527da2c637f7dc3, s5 3837d2dfc7a79e30, s6 81b510cdf9ab281c, splanted e2089ee15b1c4886, splanted2 1a699f3fdc8ca03c |
  | writebook-serial (`PARALLEL_WORKERS=1`, 67–79 s) | s1 5ae0a0b29abec8c3, s2 9e25f5f552a87735, s3 a4be8c5d81e8cabe, s4 34b1978e2c9df054, s5 a106b240a41693c8, s6 7d1fb3438bebe578, splanted 03bf36777f9fcc28, splanted2 5f42b6a9238e8264 |
  | hackatime-parallel (2 workers, about 80 s) | u1 dbdd80f215209384, u2 4a37d2863f8ecc00, u3 caf3145331085659, u4 5fc054ac92119dc4, u5 40b8059e48d56158, u6 354860228f55ffa6, planted 5980710d8a7a4620, planted2 b89858c5f3dfe646 |
  | writebook-parallel (16 workers, about 30 s) | u1 f2bc8c25886c82c9, u2 a5068f71b0700560, u3 ce69db598b222c49, u4 78c17cb5548b3033, u5 24ae84c4d3aec77f, u6 6c5ef3681dd825e5, planted 75fb79f38649e913, planted2 a4adb8f304d8fa2c |

  The plants are the ones of [options-*.txt](../2026-11-25-t3): `LeaderboardsController#index` on Hackatime (+40–60
  objects per request), `SessionsController#create` on serial Writebook and `BooksController#index` on parallel
  Writebook. Capture times are the census thread's, measured on an orb shared with other runs, so they are upper bounds.
* All other captures are read where they are committed: the Blog (`2026-11-25{,-fixes,-confirm-opus}/blog-floor`),
  the fresh app (`2026-11-25-t3/fresh-81/s1–s12` serial, `2026-11-25-final/fresh-81/c1–c24` with 2 workers),
  Campfire (`2026-11-25-t3/campfire`), and openstreetmap-website (`osm/s1–s5` serial, `osm/{base,aa,head,head2}` with
  8 workers) and Forem (`forem/{base,aa,head}`) under `../../oss_profile_sweep_1/`.
