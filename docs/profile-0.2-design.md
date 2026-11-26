# lowrail-profile 0.2: a compare gate with a noise model, and `doctor` (design note)

Status: decided 2026-11-25 (*Decisions* below); nothing is implemented, and nothing in gem/ before 0.1 is released. 0.1 ships without a gate ([DECISIONS](DECISIONS.md),
[profile-gate-design](profile-gate-design.md)): compare is a report. Numbers come from
[bench/upstream/profile_release/2026-11-25-gate-0.2](../bench/upstream/profile_release/2026-11-25-gate-0.2/README.md):
[noise_gate.rb](../bench/upstream/profile_release/2026-11-25-gate-0.2/scripts/noise_gate.rb) and its output
[results.md](../bench/upstream/profile_release/2026-11-25-gate-0.2/results.md). It uses only captures already made for
0.1. On the same assignments its `aa1` rows reproduce 0.1's published numbers (Hackatime one process: 12.50% /
4.44%, plant 51.67%).

## Summary

* **Recommended: `range-2`, k = 4, with a self-check and a merged confirm.** The base is four one-process captures
  of two runs each. A row is flagged when head minus base exceeds max(2 × spread, floor). spread is the larger of
  the base's spread (all 8 runs) and head's own. The floor is 1 object for a line, and max(20, 0.1%) for an action.
  Before judging head, the job compares each base capture against the other three by the same rule. If any of those
  compares flags a row, the job **declines** to gate and exits 0. When head is flagged, CI profiles head again and
  fails only if a flagged row stays flagged with both heads merged into one of four runs.
* **What it measured.** No false CI failure on any app where k = 4 could be measured (Blog 0 of 6,664, fresh app 0
  of 6,720, Hackatime 0 of 26, Writebook 0 of 30). Plants caught 100% on the Blog and Writebook. On Hackatime they
  were caught 31%: the plant is below what its noise lets the gate see. Forem and parallel openstreetmap-website are
  declined, not falsely failed. Smallest regression found in 95% of heads: median action 20–36 objects per request,
  0.46–1.42% of the action (3.4% on the fresh app, whose actions are small).
* **Not good enough as a default.** On the hard apps the evidence is six captures each (Hackatime, Writebook).
  openstreetmap-website, Campfire and Forem have 3–4 captures, too few to measure k = 4 at all. Assignments reuse
  the same captures, so 0 of 26 is not 26 independent trials. Ship it in 0.2 as an opt-in `--gate`. The README's CI
  job stays a report until a calibration round has 8 serial captures each of Forem, openstreetmap-website, Campfire
  and Hackatime, and shows no false CI failure there (*Decisions*).
* **Parallel captures stay refused** (exit 2). Even with the self-check, Hackatime (2 workers) and Writebook (16)
  are declined 20–47% of the time at k = 4 (70–85% at k = 3), no plant is caught, and the smallest detectable
  regression is 5–16% of an action.
* **`doctor`**: eight checks, run before a capture without booting the app. Exit 0 means nothing found, 1 warnings,
  2 errors. Parallel workers (T3, T5, T6) and controller-only or request-less suites (T2) are field-test findings. The
  others come from reviews, not from T1–T10.

## 1. The gate

### Where 0.1's rule breaks

0.1's would-be gate (base, one A/A capture, head; threshold 2 × spread) samples the noise between captures once.
Three kinds of noise cross it, all visible in the receipts:

* **The split of parallel workers** (T3, T5, T6). It moves between captures and dominates there: openstreetmap-website
  with 8 workers 79% / 67% false alarms (one compare / CI job). One process removes it.
* **Data noise between runs, inside one process.** Hackatime's `LeaderboardsController#index` reads 7,882 or 7,905
  per run in every capture, and `Admin::AdminUsersController#index` 14,698–14,817. Each run lands on one of a few
  values, so a two-run capture lands on low, high or between. One A/A pair often sees one mode, and a head in the
  other fails (12.5% / 4.4%).
* **Noise between captures over many actions** (T9, Forem). 82 of Forem's 758 actions have capture means 20 or more
  objects apart: `Feeds::SourcesController#update` 18,676 / 18,330 / 18,330, `ResponseTemplatesController#update`
  15,028 / 15,028 / 15,154. This is not drift: only 17 of the 82 move monotonically in time order, where random
  order gives about 27. More captures are what sample it.

### Variants measured

For each app the script takes every set of k unchanged captures as base and every other unchanged capture as head
(and every ordered pair as head, head2 for the CI job). The planted captures are heads only. Per row it uses B (the
mean of the base runs), H (head's mean), hs (head's run spread) and the floor F above. Then:

| Variant | Threshold T (flag when H − B > T) |
| --- | --- |
| `aa1` | 0.1: B is the first capture only; T = max(2 × max(spread of both captures' runs, hs), F) |
| `range-c` | T = max(c × max(spread of all 2k base runs, hs), F), c = 2 or 3 |
| `env` | T = (highest base run − B) + max(hs, F): head must clear every base run by the floor |
| `pred99` | T = max(t(k−1, 99%) × sd(capture means) × √(1 + 1/k), F): a prediction interval |
| `rank` | T = max(highest base capture mean − B, F): a rank test across captures, with the floor |
| `… share 0.5%` | the action floor at 0.5% instead of 0.1% |
| `… r1` | each capture's first run only: `--runs 1` captures at half the cost |
| `… self-check` | decline when a leave-one-out compare inside the base flags |

The CI job is measured three ways: *any* (0.1's README: fail when the second compare flags anything), *same row*,
and *merged*, the one proposed here. Plant detection counts a planted head flagged on a row matching the plant;
for the CI job it uses the merged rule over both planted captures. The *smallest detectable regression* (d95) is, per
compared action, the added objects per request an unchanged head needs to be flagged in 95% of assignments. It is
given as the median over actions.

### Results

One-process captures. Each cell gives false alarms of one compare / of the CI job (merged), then plant caught
(one compare / CI). n/m counts assignments; the percentages are in results.md.

| App (captures, time each) | 0.1 rule (`aa1`) | `range-2` k3 | `range-3` k3 | `range-2` k4 | **`range-2` k4 + self-check** | `env` k4 + self-check |
| --- | --- | --- | --- | --- | --- | --- |
| Blog (12 + 3 planted, 5.5 s) | 21/1200 / 0/10800; plant 100% / 100% | 3/1080 / 0/8640; 100% | 2/1080 / 0/8640; 100% | 0/960 / 0/6720; 100% | **declined 1/120; 0/952 / 0/6664; 100% / 100%** | declined 16/120; 21/832 / 0/5824; 100% |
| Fresh app (12, ~10 s) | 0/1200 / 0/10800 | 0 / 0 | 0 / 0 | 0 / 0 | **declined 0/120; 0/960 / 0/6720** | 0 / 0 |
| OSM serial (4 + 1, 565 s) | 0/24 / 0/24; plant 12/12 | 0/4 / –; 4/4 | 0/4 / –; 4/4 | not measurable | **not measurable** (k3 + self-check: declined 0/4, 0/4, plant 4/4) | not measurable |
| Hackatime serial (6 + 2, 123–144 s) | 15/120 / 12/360; plant 52% / 52% | 2/60 / 2/120; 40% / 40% | 0/60 / 0/120; 0% | 0/30 / 0/30; 27% | **declined 2/15; 0/26 / 0/26; 31% / 31%** | declined 5/15; 1/20 / 0/20; 100% |
| Writebook serial (6 + 2, 67–79 s) | 0/120 / 0/360; plant 100% | 0/60 / 0/120; 100% | 0/60 / 0/120; 100% | 0/30 / 0/30; 100% | **declined 0/15; 0/30 / 0/30; 100% / 100%** | 0/30 / 0/30; 100% |
| Campfire serial (4 + 2, 123 s) | 2/24 / 0/24; plant 100% | 0/4 / –; 100% | 0/4 / –; 100% | not measurable | **not measurable** (k3 + self-check: declined 1/4, 0/3, plant 6/6) | declined 1/1 |
| Forem (3, 1,769–2,048 s) | **6/6** / – | not measurable | not measurable | not measurable | **not measurable** (k3 self-check: declined 1/1) | not measurable |

Smallest detectable regression for `range-2` k4 + self-check (d95, median over actions): Blog 21 objects per
request (0.46% of the action), fresh app 20 (3.4%, small actions), Hackatime 26 (1.37%), Writebook 36 (1.42%).
At k3, where k4 is not measurable: OSM 20 (0.48%), Campfire 38 (0.53%). A line needs its floor, 1 object per
request averaged over all requests. `range-3` raises the d95 by about 40% (Writebook 50, Hackatime 38, Campfire 54)
and misses Hackatime's plant entirely. `env` lowers the 90th percentile (Hackatime 153 against 270) and catches
Hackatime's plant, but declines a third of its base sets and every Campfire base set.

Rejected, with the reason measured:

* **Rank or permutation test across captures** (`rank`). With k captures and a head, a per-row p-value cannot go
  below 1/(k+1), 0.17 at k = 5, and an app has hundreds of rows that move. It fails 100% of unchanged Hackatime
  heads at every k and 17–37% on the Blog. A rank test across captures is not a gate at k ≤ 5.
* **Prediction interval from capture means** (`pred99`). An sd from 2–5 means is unreliable, and it leaves out
  head's own spread. It fails 83–93% of Hackatime heads at k3–k5 and 17% of Writebook's.
* **`--runs 1` captures** (`r1`) would halve the cost, but the spread between a capture's runs is half the noise.
  Without it, Hackatime fails 50–88% of heads, openstreetmap-website 75–83% and Campfire 75%. Captures keep two runs.
* **Higher action floor** (`share 0.5%`). With `range-2` it changes nothing on Hackatime; with `env` it removes
  Hackatime's false alarms only together with most of its plant (100% → 0–40%). Either way it more than triples
  the floor of large actions (Writebook's 90th-percentile d95 109 → 364).
* **k = 2 or 3 without a self-check.** Hackatime still fails 1.67% of CI jobs at k3 (`range-2`), and Forem fails
  every k = 2 variant (3 of 3).

Parallel captures, for 0.2's boundary (results.md, `*-parallel`). `range-2` k4 + self-check: Hackatime with 2
workers is declined 7 of 15 times, with no false alarm in 16 jobs and plant 0 of 16 (d95 15.8% of an action).
Writebook with 16 workers is declined 3 of 15, no false alarm in 24, plant 0 of 24 (d95 4.8%). openstreetmap-website
with 8 workers is declined 4 of 4 at k3. The fresh app with 2 workers is clean (0 of 45,600), but its actions are
tiny. The
noise model makes parallel captures harmless, not useful, so compare keeps refusing them (exit 2).

### Recommendation

**`range-2`, k = 4, self-check, merged confirm**, as an opt-in gate in 0.2:

1. `lowrail-profile compare --gate BASE1 BASE2 BASE3 BASE4 HEAD [--head2 HEAD2]`, each a report.json. It refuses
   (exit 2) fewer than 4 bases, captures of several processes, fewer than 2 runs, and bases or heads that differ in
   identity, seed, runs, Ruby or environment, as compare does today.
2. B is the mean of the 8 base runs. T = max(2 × max(spread of the 8 base runs, spread of head's runs), F). F is 1
   object for a line, and max(20, 0.1% of max(B, H)) for an action.
3. Self-check: each base against the other three, by the same rule. If any flags, the gate declines: exit 0,
   `declined: true` and a reason in the JSON, and the summary says so and which rows disagree between base
   captures. A declined job is a report.
4. A compare that flags exits 1. The CI step then profiles head again and runs compare with `--head2`, which
   merges both heads into one of four runs; the job fails only if that comparison exits 1 again, with a row the
   first compare flagged. No other exit code (*Decisions*, 2).
5. Reported per row: base runs, head runs, spread, floor, and the d95 of the row, so a reader sees what size of
   change the gate could have found.

Why this one: of everything measured, it is the only variant with no false CI failure on any set where it could be
measured. It turns the cases that break the other variants into a declined gate, not a red build: Forem's noise
between captures, and the split of parallel workers. It keeps the floors where 0.1 had them: d95 0.46–1.42% of an
action. What it does not do: it misses regressions at the size of an app's own noise. On Hackatime that is
`LeaderboardsController#index` +53 against runs 35 apart, caught 31%. And it is measured on too few captures of the
hard apps to promise a false-alarm rate. "0 of 26" on Hackatime has a 95% upper bound of about 11% even if the
assignments were independent, and they are not.

### How many captures, and what it costs

A job is 4 base captures, 1 head and 1 more head when the first compare flags. On unchanged code that never
happened in the receipts at k = 4. Captures run one after another on one runner. Captures on separate runners
would take the wall time of one capture, but whether counts move between machines is not measured. Caching the four
bases per merge base (key: merge-base SHA, Gemfile.lock, Ruby, runner image and seed; filled by a job on the main
branch) leaves 1–2 captures per pull request. Nothing in the receipts shows a time drift that would rule that out
(Forem: 17 of 82 monotonic). But no receipt compares captures made on different days or machines, so a cached base
is a hypothesis until measured.

| App | One capture | Job, 4 bases + head (+1 on a flag) | With cached bases | 0.1 README job (base, A/A, head, +1) |
| --- | ---: | ---: | ---: | ---: |
| Blog | 5.5 s | 28–33 s | 6–11 s | 17–22 s |
| Fresh app | ~10 s | ~50–60 s | 10–20 s | 30–40 s |
| Writebook | 67–79 s | 5.6–7.9 min | 1.1–2.6 min | 3.4–5.3 min |
| Campfire | 122–127 s | 10.2–12.7 min | 2.0–4.2 min | 6.1–8.5 min |
| Hackatime | 123–144 s | 10.3–14.4 min | 2.1–4.8 min | 6.2–9.6 min |
| openstreetmap-website | 554–588 s | 46–59 min | 9–20 min | 28–39 min |
| Forem | 1,769–2,048 s | 2.5–3.4 h (declined) | 30–68 min | 1.5–2.3 h |

The suite times are profiled captures of two runs. A plain serial suite takes a bit under half of one (Forem: 631 s
plain, 1,769–2,048 s profiled).

## 2. `lowrail-profile doctor`

`lowrail-profile doctor [--out DIR] [--json] [-- COMMAND...]` checks the app and the command a capture would run,
before the capture. It never boots the app or loads its code (invariant 7). It reads the environment,
`Gemfile.lock`, binstubs, `config/boot.rb` and test files (with Prism, which Ruby 3.3 ships), and asks the file
system about permissions without writing. Without a command it assumes `bin/rails test` (or `bundle exec rspec` when
there is a `spec/` but no `test/`). Each finding is an error or a warning. Exit 2 if there is an error (the capture
would fail, write outside `--out`, or produce evidence compare refuses), 1 if there are only warnings, 0 if nothing
is found. `--json` lists the findings with check, severity, message, file and line.

T numbers are the builder thread's numbering of the field test: T1–T4, T9 and T10 from the OSS sweep, T5 Hackatime,
T6 Writebook, T7 Sure, T8 Fizzy from the census. [oss-profile-sweep-1.md](upstream/oss-profile-sweep-1.md) numbers its
own T5–T8 differently: T5 jobs-only report, T6 missing report.json, T7 ledger, T8 install friction.

| Check | Detected by | Message (example) | Exit | Prevented |
| --- | --- | --- | --- | --- |
| **Parallel workers** | `PARALLEL_WORKERS` > 1, or unset while `test/test_helper.rb` calls `parallelize(workers: …)` (found with Prism; `:number_of_processors` read as `Etc.nprocessors`, and the parallelization threshold, 50 tests by default, compared with the test count). A command of `parallel_test`, `parallel_rspec`, `rake parallel:*`, `turbo_tests` or `flatware`. `CI_NODE_TOTAL` > 1 or `KNAPSACK_PRO_*`/`KNAPSACK_*` set (a CI split runs part of the suite). | `test/test_helper.rb:9 calls parallelize(workers: :number_of_processors): this capture would run 8 processes, and compare refuses captures of several processes. Profile with PARALLEL_WORKERS=1 (about 8× the suite time).` | 2 | T3 (openstreetmap-website), T5 (Hackatime), T6 (Writebook); T7's 3.3 GB per capture came from 16 workers |
| **Spring** | `bin/rails`, `bin/rake` or `bin/rspec` loads Spring (`load File.expand_path("spring", __dir__)` or `spring/binstub`) and `DISABLE_SPRING` is unset. Error if a Spring server is running (its socket under `$XDG_RUNTIME_DIR` or `Dir.tmpdir`, `spring-UID`), warning otherwise. | `bin/rails loads Spring and a Spring server is running: the tests would run in that server, outside lowrail-profile, and count nothing. Set DISABLE_SPRING=1 or run bin/spring stop.` | 2 (server running), 1 | No T finding: rc1 review (a warm Spring records no windows and exits 1; README troubleshooting) |
| **Only controller tests** | Of the test files the command selects: minitest classes inheriting `ActionController::TestCase`, or rspec `type: :controller` or `spec/controllers/` with `infer_spec_type_from_file_location!`. Against: `ActionDispatch::IntegrationTest`, `ActionDispatch::SystemTestCase`, `ApplicationSystemTestCase`, rspec `type: :request/:system/:feature` and their directories. Warns when controller tests are selected and are the majority. | `2,258 of 2,929 selected test files are controller tests (ActionController::TestCase), which never go through Rails::Engine#call: they count no requests. Only the 671 integration tests will. Profile request or system tests.` | 1 | T2 (Redmine counted 920 requests; Huginn's controller specs 0) |
| **No request or system tests** | The same classification finds no integration, request, system or feature test in the selection. | `None of the selected tests sends a request (no integration, request or system tests): the report will count jobs, mails and Cable actions only, and a run with none of those fails.` | 1 | T2 (Huginn: 0 requests, 89 jobs); the sweep's own T5 (a jobs-only report reads as requests) |
| **Bootsnap and cache paths** | `config/boot.rb` requires `bootsnap/setup` (or Gemfile.lock has bootsnap). Its cache directory (`BOOTSNAP_CACHE_DIR` or `tmp/cache`) is not writable: error. It is empty or missing: warning (run 1 fills it and run 2 reads it, so autoloads inside requests differ between runs and captures). Also lowrail-profile's own counter cache (`$XDG_CACHE_HOME` or `~/.cache`/lowrail/profile): not writable, or no C compiler (`RbConfig::CONFIG["CC"]` not on `PATH`) when the counter for this Ruby is not built yet: error. | `tmp/cache/bootsnap is empty: the first run compiles and caches every file it loads and the second does not, which the noise floor then absorbs. Run the suite once first, or restore tmp/cache in CI.` / `~/.cache is not writable: the first capture builds its counter there. Set XDG_CACHE_HOME.` | 2 / 1 | No T finding. Evidence: Bootsnap's `compile_cache/iseq.rb:103` moves between parallel fresh-app captures (results.md, `rank` k4); the counter cache is where the first capture fails on a read-only home |
| **Glob characters in paths** | `Gem.dir`, `Gem.path`, the bundle path and the gem's own directory contain `[ ] { } * ?`: warning. `--out` contains one: error. The capture still interpolates `--out` into `Dir[]`: `exe/lowrail-profile` deletes `Dir[File.join(out, "run*")]`, and `profile_report.rb` reads `Dir["#{dir}/run*"]`. | `--out "/tmp/g/{keep,x}" has glob characters: lowrail-profile would read and delete runs in /tmp/g/keep. Pick a path without [ ] { } * ?.` | 2 (`--out`), 1 (gem home) | No T finding: thermos-fable item 3 (gem home, fixed by listing the counter's sources in 61e2057c), thermos-opus must-fix 2 (`--out '/tmp/g/{keep,x}'` deleted another capture's runs) |
| **`--out` not writable** | The nearest existing ancestor of `--out` is not a writable directory (access(2), no test write). `--out` exists, is not empty and has no `.lowrail-profile` marker (the capture would abort). Free space on its file system below 1 GiB: warning. | `tmp/lowrail-profile exists and was not created by lowrail-profile: the capture would stop. Pick another --out or remove it yourself.` / `/ has 0.6 GiB free; a capture's runs can need gigabytes before the report deletes them.` | 2, 1 (space) | No T finding for permissions; the space warning is T7 (Sure: 3.3 GB per capture) |
| **Ruby or Rails below the floor** | `RUBY_ENGINE` is not `ruby`, `RUBY_VERSION` < 3.3, Windows, Gemfile.lock's `railties` < 7.2 or `rack` < 2. Without Gemfile.lock: warning (version unknown). | `Gemfile.lock has railties 7.1.5; lowrail-profile supports Rails 7.2 and later (Ruby 3.3 and later).` | 2, 1 (no lock) | No T finding: the floor app (Blog, Ruby 3.3 / Rails 7.2) and Solidus at the floor passed. The gemspec blocks Ruby < 3.3 at install, but nothing checks Rails |

`doctor` on its own exits 0, 1 or 2 as above; the README's CI job runs it first and stops on exit 2. A capture runs
the same checks first and prints their findings, errors included, as warnings, but never stops because of them:
parallel captures stay allowed as reports (*Decisions*, 3).

## Decisions

Coordinator under Thomas's delegation, 2026-11-25:

1. **0.2 gets `range-2` with k = 4 and the self-check as an opt-in `--gate`.** Before the 0.2 release a calibration
   round runs: 8 serial (`PARALLEL_WORKERS=1`) captures each of Forem, openstreetmap-website, Campfire and Hackatime
   (about 4.5 h, 1.3 h, 17 min and 18 min of profiling). Whether `--gate` later becomes the default, and the README's
   CI job fails builds, is decided only from those numbers.
2. **No exit 3.** With `--gate`, compare exits 1 when it flags something. The CI step's confirm run profiles head2,
   and the job fails only if the merged comparison (head and head2 as one head) exits 1 again. Declined to gate
   (noisy bases) is exit 0, with `declined: true` and a reason in the JSON and in the summary.
3. **Captures run doctor's checks first and print warnings, but never abort because of them**; parallel captures
   stay allowed as reports. `doctor` on its own exits 0/1/2 as in the table. Check 6's `--out` part drops out once
   0.1's `Dir.children` fix for `--out` (thermos-opus must-fix 2) is in; only the gem home part remains.

No implementation in gem/ before 0.1 is released.

## Calibration round (2026-11-26)

Receipts: [bench/upstream/profile_release/2026-11-26-calibration](../bench/upstream/profile_release/2026-11-26-calibration/README.md),
8 serial unchanged and 2 planted captures per app, gem built at `34a1a61f`, every run's per-test outcomes identical
to a plain run. `range-2` k4 + self-check, merged confirm (declined; false alarms one compare / CI job; plant; d95):

| App | Declined | False alarms | Plant | d95 median |
| --- | ---: | ---: | ---: | ---: |
| Forem | 65/70 | 6/20 / **2/60** | 10/10 | 41 (0.33%) |
| openstreetmap-website | 0/70 | 0/280 / 0/840 | 140/140 | 20 (0.46%) |
| Campfire | 31/70 | 33/156 / 0/468 | 78/78 | 26 (0.36%) |
| Hackatime | 5/70 | 0/260 / 0/780 | 129/130 | 27 (1.21%) |

**Recommendation: `--gate` stays opt-in in 0.2, not the default, and the README's CI job stays a report.** The
gate fails 3.3% of Forem's CI jobs on unchanged code and declines 93% of its base sets; k = 5 fails 2 of 72 and
declines 79%. The cause is rows whose value is set per capture, with no spread between runs (Forem
`Feeds::SourcesController#update` 18,330 or 19,022, Campfire `Users::BansController#create`). A spread built from
runs cannot see them until a base happens to hold both values. On openstreetmap-website and Hackatime the gate is
clean and sharp. A CI job costs 5–6 captures: about 9–11 min on Campfire and Hackatime, 41–49 min on
openstreetmap-website, 2.1–2.5 h on Forem.
