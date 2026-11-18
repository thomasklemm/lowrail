# lowrail-profile matrix rerun on main (2026-11-18)

What [profile-review-2026-11-18.md](../../../../docs/upstream/profile-review-2026-11-18.md) listed as not rerun
after the review fixes: Writebook, Pingcrm and CodeTriage three ways (no gem, gem listed but off, profiled), one
`compare` per app against a real A/A pair, and the Lobsters YAML/DSL pair. Summary in
[profile.md](../../../../docs/profile.md#rerun-on-main-2026-11-18) and
[census.md](../../../../docs/upstream/census.md#validation-the-workloads-file-replaces-yaml-2026-11-18).

Lowrail: main `7ca0a20e` (the profiler, counter, workloads and census code are identical through `7891f47a`) with
the counter fix committed just before this directory ("lowrail-profile: count code evaluated from line -1
instead of dropping it"). Every capture below was taken with the fix, except the
first three CodeTriage captures (overwritten; their `compare` is quoted below). Orb: 2 CPUs, 4 GB, Linux x86-64;
PostgreSQL 17, Redis and memcached as local services; Chrome for Testing 157 for Pingcrm's system tests. Other
runs (the Lobsters census, the gem's tests) ran at the same time, so the suite and wall times in `summary.txt` and
`*.tail.txt` are not overhead measurements.

## Method

Fresh `script/corpus APP r-APP --source-only` copies at their corpus pins, `BUNDLE_FROZEN=true bundle install`,
the test database prepared the app's way. [scripts/b_safety.sh](scripts/b_safety.sh) runs the suite with
`SEED=1234` and `RUBYOPT=-r scripts/dump_features.rb` (every process writes `$LOADED_FEATURES` at exit):

* `plain`: the app's own Gemfile;
* `off`: `Gemfile.lowrail`, a copy with `gem "lowrail", path: …, group: [:development, :test], require: false`;
* `profiled`, `base2`, `head`: `bundle exec lowrail-profile --out DIR -- COMMAND` (two runs each) from that Gemfile,
  three invocations on the same code: `compare profiled head --aa base2` ([scripts/compare.sh](scripts/compare.sh)).

Per-test outcomes are the suite's verbose lines (`Class#test_name = 0.12 s = .`) without their time, sorted
(`*.outcomes`; profiled files hold both runs, deduplicated). [scripts/features_cmp.rb](scripts/features_cmp.rb)
compares each process's feature list, outside Lowrail, Bundler and RubyGems, with the base setup's processes.
[scripts/margin.rb](scripts/margin.rb) prints how many rows the gate compared and the closest ones to their floor
(compare's output lists only rows beyond it).

| App | Ruby, Rails, pin | Command |
| --- | --- | --- |
| [writebook](writebook) | 4.0.7, main `36e0f96b9d`, `7478e2c` | `bin/rails test -v` |
| [writebook-exclude](writebook-exclude) | same | `bin/rails test -v --exclude /test_unpublishing_a_book_revokes_the_disk_URL/` |
| [pingcrm](pingcrm) | 4.0.7, 8.1.4, `22464f8` | `bin/rails test:all -v` (`PATH` with Chrome for Testing as `google-chrome`) |
| [codetriage](codetriage) | 4.0.7, 8.1.4, `d1868f8` | `bin/rails test --verbose` |

## Results

* **Writebook**: 310 tests, identical per test in all setups: 307 pass, 2 skip, 1 error
  (`ActiveStorageAuthorizationTest#test_unpublishing_a_book_revokes_the_disk_URL_behind_a_page_upload`,
  `URI::Generic#request_uri`, the same without the gem). Every process (4 plain, 4 off, 8 per capture) loads the
  same features in the same order (`features.txt`). Because of that error every run's command exits 1, so
  `compare` exits 2 with `--aa` and without, as documented ("base's command exited [1,1]"). With the test excluded
  (309 tests, outcomes those of `plain` without it): exit 0, `gate: true`, no regression or improvement; 5,211
  lines and 25 actions compared, 22 actions without a warm value; closest row `PagesController#create` −9.00
  against 21.40.
* **Pingcrm**: 26 tests, all pass, identical per test. Every off and profiled process loads the same features in
  the same order as a second plain run (`features-plain2.txt`); the first plain run also loaded
  `vite_ruby/runner.rb` and `vite_ruby/io.rb` because Vite built `public/vite-test` during it (created 11:49:47,
  inside that run). compare: exit 0, `gate: true`, nothing beyond the floor; 2,962 lines and 11 actions compared,
  11 without a warm value; closest row `vite_ruby/builder.rb:77` −0.73 against 1.46.
* **CodeTriage**: 222 tests, 0 failures in every run; the 217 that print a per-test line are identical
  (`plain.outcomes` misses one because `ParseDocsTest` printed `git clone` output into its line on the copy's first
  run; `plain2` has it). Same features in every process; their order differs only in yard's 27 handler files, whose
  order is stable within a setup but differs between plain, off and profiled (`features-plain2*.txt`; off loads no
  Lowrail code). plain's first run also loaded `enc/trans/single_byte.so`, which `plain2` does not.
  compare: exit 0, `gate: true`; 8,477 lines and 18 actions compared, 5 without a warm value; closest rows at 62%
  of their floor (two mail lines −0.62 against 1.0, `BackgroundInactiveEmailJob#perform` +87.50 against 142.00). Without `--aa` the same pair lists that action as a
  regression (+87.50 against 78.0 from the spread inside the captures) and says it is not a gate (exit 0,
  `compare-noaa.md`).

**Fixed: dropped samples on CodeTriage.** Before the fix every CodeTriage run reported `dropped=1`, and compare
exited 2 on every pair:

```text
* base dropped samples ([1,1])
* head dropped samples ([1,1])
* the A/A report dropped samples ([1,1])
```

A counter built with a print at each drop showed the sample:
`site id=309 line=18446744073709551615 path=…/sidekiq-8.1.7/web/views/layout.html.erb`. Sidekiq's Web compiles
its ERB views with `class_eval …, path, -1`, and the counter read the line with `NUM2ULONG`, so −1 became 2⁶⁴−1
and hit the guard for line numbers that do not fit its key. Lines below 1 now count at line 0.
`test_code_evaluated_at_a_negative_line_is_counted` fails without the fix (`dropped 6 strings []`) and passes with
it. After the fix all six runs report `dropped=0`.

## Lobsters YAML/DSL pair ([lobsters](lobsters))

`script/census app` on a Lobsters clone at `366e211`, Ruby 4.0.9, interpreter, objects only, own Rails 8.1.3.1
(`own`/`own2`) and Rails main `c48c154e3f` (`main`/`main2`): the YAML from a worktree at `11804786`, the DSL
(`fixtures/census-app/lobsters.rb`) from main ([scripts/lobsters_pair.sh](scripts/lobsters_pair.sh), compared
with [scripts/compare_ab.rb](scripts/compare_ab.rb): medians of the GC-enabled windows, the masked SQL digest of
all four runs).

* Names: the same 11 in every run. SQL: every workload's masked SQL is the same in all four runs, on both Rails.
* Reads: within the moves between A/A runs (GET home, active and story move by about 75 between two runs of one
  copy, on both sides).
* XHR writes: +44.4, +39.2, +43.5 (own) and +34.9, +47.4, +38.4 (main), the known `Accept` change; with
  `headers: { accept: "text/html" }` on the three (`lobsters-ctl`) −4.8, +3.9, −2.1.
* Job: identical. **Mail: +3.0 on both Rails, A/A 0.0**, where the earlier validation recorded identical. +1.0 is
  rack-mini-profiler's `shorten_identifier` (`identifier.split('/')`, `railtie.rb:159`) on a template path one
  directory deeper in the DSL's copy (`~/lowrail-base` against `~/workspace/repo`): the YAML from a worktree at the
  same depth ([scripts/lob_depth.sh](scripts/lob_depth.sh)) gives +2.0, with traced objects (1,794.8) and every
  site identical. The other +2.0 are counted by `GC.stat` but traced at no line; the DSL at `738accc6` gives the
  same +2.0, so they date from the migration. The census runs a mail block with `instance_exec`, which allocates
  one VM-internal object per call on Ruby 4.0.9 where the YAML's lambda allocates none
  ([scripts/mailop.rb](scripts/mailop.rb), `instance_exec-allocations.txt`); the second object is not identified.
  Both are the census client's, constant per operation, not Rails' or the app's.
