# lowrail-profile 0.2 gate: calibration round (2026-11-26)

The calibration round that [docs/profile-0.2-design.md](../../../../docs/profile-0.2-design.md) (*Decisions*, 1)
requires before `--gate` can become the default: 8 serial (`PARALLEL_WORKERS=1`) unchanged captures and 2 planted
captures each of Forem, openstreetmap-website, Campfire and Hackatime. [results.md](results.md) is the output of
[scripts/noise_gate.rb](scripts/noise_gate.rb), the 0.2 receipts' script with this round's sets and the same rules.

**Result: `--gate` (`range-2`, k = 4, self-check, merged confirm) does not become the default in 0.2.** On Forem it
fails 2 of the 60 CI jobs it gates on unchanged code, and it declines 65 of 70 base sets. k = 5 does not help.

## Numbers

Assignments are exhaustive (8 unchanged captures: 70 base sets of 4, 56 of 5). False alarms: one compare / CI job
(merged confirm). Plant: one compare / CI job. d95: the median over actions of the smallest regression flagged in 95%
of assignments (objects per request, share of the action). Job time: 4 bases + head, +1 head when the first compare
flags (k = 5: 5 bases).

| App (capture) | Variant | Declined | False alarm: one / CI | Plant: one / CI | d95 median | Job time |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Forem (1,512 s) | `aa1` (0.1 rule) | – | 220/336 (65%) / 261/1680 (15.5%) | 112/112 / 112/112 | 44 (0.36%) | 1.2–1.7 h |
| | `range-2` k3 | – | 102/280 (36%) / 55/1120 (4.9%) | 100% / 100% | 43 (0.34%) | 1.7–2.1 h |
| | **`range-2` k4 + self-check** | **65/70 (93%)** | **6/20 / 2/60 (3.3%)** | 10/10 / 10/10 | 41 (0.33%) | 2.1–2.5 h |
| | `range-2` k5 + self-check | 44/56 (79%) | 6/36 / 2/72 (2.8%) | 24/24 / 24/24 | 42 (0.33%) | 2.5–2.9 h |
| openstreetmap-website (486 s) | `aa1` | – | 0/336 / 0/1680 | 100% / 100% | 21 (0.48%) | 24–32 min |
| | `range-2` k3 | – | 0/280 / 0/1120 | 100% / 100% | 20 (0.46%) | 32–41 min |
| | **`range-2` k4 + self-check** | **0/70** | **0/280 / 0/840** | 140/140 / 140/140 | 20 (0.46%) | 41–49 min |
| | `range-2` k5 + self-check | 0/56 | 0/168 / 0/336 | 100% / 100% | 20 (0.46%) | 49–57 min |
| Campfire (100 s) | `aa1` | – | 53/336 (16%) / 15/1680 (0.89%) | 100% / 100% | 27 (0.39%) | 5–7 min |
| | `range-2` k3 | – | 34/280 (12%) / 6/1120 (0.54%) | 100% / 100% | 25 (0.36%) | 7–8 min |
| | **`range-2` k4 + self-check** | **31/70 (44%)** | **33/156 (21%) / 0/468** | 78/78 / 78/78 | 26 (0.36%) | 8–10 min |
| | `range-2` k5 + self-check | 35/56 (63%) | 21/63 / 0/126 | 42/42 / 42/42 | 26 (0.35%) | 10–12 min |
| Hackatime (107 s) | `aa1` | – | 32/336 (9.5%) / 58/1680 (3.5%) | 96/112 (86%) / 86% | 28 (1.24%) | 5–7 min |
| | `range-2` k3 | – | 5/280 (1.8%) / 8/1120 (0.71%) | 96% / 96% | 28 (1.21%) | 7–9 min |
| | **`range-2` k4 + self-check** | **5/70 (7%)** | **0/260 / 0/780** | 129/130 / 129/130 | 27 (1.21%) | 9–11 min |
| | `range-2` k5 + self-check | 0/56 | 0/168 / 0/336 | 112/112 / 112/112 | 27 (1.22%) | 11–13 min |

`env` k4 + self-check, for comparison: no false alarm anywhere, but it declines every Forem base set (70/70).
`range-2` k4 without the self-check: Forem 3.57% (30/840) false CI failures, Campfire 0.12% (1/840).

The 0.1 README job (`aa1`: base, A/A, head, +1) costs 3–4 captures: Forem 1.2–1.7 h, OSM 24–32 min, Campfire and
Hackatime 5–7 min.

## What breaks the gate: modes per capture

Every Forem false alarm, and Campfire's one-compare flags, come from rows whose value is fixed for a whole capture
and moves between captures, with no spread between the capture's two runs:

* Forem `Feeds::SourcesController#update` (2 requests): 18,330 in s1, s2, s4–s6 and s9, 19,022 in s7 and s8, both
  runs alike (+692, 3.8%). `Admin::BillboardCampaignsController#show` (6): about 20,642, or about 20,745 in s9 and
  in s6's second run.
* Campfire `Users::BansController#create` (5): 7,818–7,825 in seven captures, 7,843.5 / 7,841.5 in s3.

`range-2`'s spread is built from runs, so a base whose four captures all sit in one mode has spread 0, and a head in
the other mode clears the floor of 20. The self-check catches this only when the base itself holds both modes. On
Forem that is 93% of base sets, so the gate is mostly a report there, and the rest still fail. The receipts' T9
(Forem's 82 actions with capture means 20+ apart) is this effect; it is not drift in time (s7/s8 are high, s9 is low
again).

Hackatime and openstreetmap-website have no such rows at k = 4. Hackatime's plant (+60 on `LeaderboardsController#index`,
about 7,885) is now caught 99%, where the 0.2 receipts had 31%. There the action's two runs were 23–35 apart in
four of six captures; here 1–26, median 4. Those captures ran beside three other suites, but whether that caused the
wider spread is not checked.

## Setup and captures

* Gem: `gem build lowrail-profile.gemspec` in `gem/` at Lowrail main `34a1a61f`, `lowrail-profile-0.1.0.rc1.gem`,
  sha256 `e9ac10e62bee560b26dd6441fc2cb2bd7baa35993380d1b1e04dea0712eaaac5`. Main has since changed gem/
  (`644c99e4`); these captures are of the 34a1a61f build.
* One 16-CPU orb. Campfire, Hackatime and openstreetmap-website ran beside each other and beside Forem's first
  captures (load average 2–4.3); Forem's later captures ran alone. Times in `captures/*/wall.txt`.
* Each app as its field-test receipts set it up ([scripts](scripts)):
  * **Campfire** `af4dd9fd` (`script/corpus campfire rc-campfire`, Ruby 4.0.7, SQLite, Redis), through M4's
    `proof.sh` as `2026-11-25-t3/scripts/serial.sh` ([campfire.sh](scripts/campfire.sh)): `bin/rails test -v`,
    `SEED=1234`, the plant `20.times { ERB::Util.html_escape("a<b") }` in `RoomsController#show`, identical to
    `2026-11-25-t3/campfire/planted.patch`.
  * **Hackatime** `74deec42` (`script/corpus hackatime ft-hackatime --source-only`, its own lock with Rails
    8.1.3.1, Ruby 4.0.6, PostgreSQL 17, `TEST_DATABASE_URL=postgres:///ft_hackatime_test`), through `proof.sh` as
    the census field test ([hackatime-setup.sh](scripts/hackatime-setup.sh), [hackatime.sh](scripts/hackatime.sh)).
    Plant: the same line in `LeaderboardsController#index`, as `2026-11-25-t3/census/hackatime-serial/splanted.patch`.
    The field test reached Postgres as `user@localhost`; this orb's Postgres asks localhost for a password, so it
    uses the socket.
  * **Forem** `c5bd9e11` (Ruby 3.3.14, Rails 8.0.5, PostgreSQL 17 with pgvector, Redis, Node 22) and
    **openstreetmap-website** `20ae45ec` (Ruby 4.0.9, Rails 8.1.4.1, PostgreSQL with PostGIS, memcached) as the OSS
    sweep did ([forem-setup.sh](scripts/forem-setup.sh), [osm-setup.sh](scripts/osm-setup.sh),
    [app.sh](scripts/app.sh)): the Gemfile line committed locally,
    `bundle exec lowrail-profile --out tmp/cal-SN -- bundle exec rspec spec/requests --format documentation` and
    `-- bin/rails test -v`. OSM's plant is the sweep's `osm-s5.patch` (`Array.new(200) { Object.new }` in
    `NotesController#index`). Forem's is the receipts' line at the top of `StoriesController#index`, its busiest
    named action (235 requests).
* Per capture: `capture.json`, `command.txt`, `report.json.gz` (gzip -9n of report.json), `planted.patch` /
  `planted2.patch`, `wall.txt` (exit code and wall time of each step, tree check), and `outcomes.txt`.

## Outcomes against a plain run

One plain run per app (its own Gemfile, seed 1234), then the per-test outcomes of both runs of every capture,
compared with [outcomes_check.sh](scripts/outcomes_check.sh). Minitest logs are parsed by
[mt_outcomes.rb](scripts/mt_outcomes.rb), which pairs each test with its result even when stderr (Postgres notices,
ffmpeg, Ruby warnings) is written mid-line; Forem's RSpec log by the sweep's `outcomes.rb`.

| App | Plain | Captures | Tree |
| --- | --- | --- | --- |
| Forem | 5,278 examples, 8,469 outcome lines, 0 failures | identical in both runs of s1, s2, s4–s9, planted, planted2 | unchanged |
| openstreetmap-website | 2,757 runs, 0 failures | identical in all 20 runs | unchanged |
| Campfire | 634 runs (2 skips), 0 failures | identical in all 20 runs | unchanged |
| Hackatime | 794 runs, 0 failures | identical in all 20 runs | unchanged |

Two Forem captures were rejected and replaced (`captures/forem/s3-rejected`, `s6-rejected`: capture.json and
command.txt only), because compare refuses a capture whose command did not exit 0:

* The first s3 and s6 each failed one flaky example in run 1, both tie orders between equal sort keys:
  `spec/requests/api/v1/articles_spec.rb:2005` (two articles found in the other order) and
  `spec/requests/api/v0/follows_spec.rb:61` (two tags with equal points). The plain run and every other run passed
  them.
* Run 2 of the first s6 failed 3,034 examples with `Errno::EMLINK`: Forem's specs leave a directory per user id in
  the gitignored `public/uploads/user/profile_image`, which reached ext4's 65,000-link limit after about 11 suite
  runs. app.sh now deletes `public/uploads` before each step. s6 was rerun, and s9 replaces s3.

## Replay

From `scripts/`, with Ruby 4.0.7: `ruby noise_gate.rb > ../results.md` (about 2 min).
`VARIANTS='^range-2 k4 self-check$' ruby noise_gate.rb forem` prints one variant for one app.
