# lowrail-profile for any Rails team: release plan

Status: M1–M4 built, 2026-11-25 (release candidate 0.1.0.rc1, unpublished); M5 (independent review) next, M6 only
on Thomas's approval. Support floor reached: Ruby 3.3 and Rails 7.2 (CI matrix 3.3/3.4/4.0 × 7.2/8.0/8.1, macOS,
Ruby head). Proof: [profile.md](profile.md#release-candidate-proof-from-the-built-gem-2026-11-25). §1 describes the
tool before this work.

[PLAN.md §0.7](PLAN.md#0-what-changed-since-this-plan-2026-10-20) moved Lowrail to discovery first: runtime lowering
is parked, and measurements feed upstream fixes and advisory types/MCP. This is the third bet: make
[`lowrail-profile`](profile.md) a tool a Rails team installs on its own app to see avoidable work per request, job,
mail and Action Cable action, in its code and its gems, on the evidence standard Lowrail holds itself to.

## 1. What exists

Read from `gem/exe/lowrail-profile`, `gem/lib/lowrail/profile*.rb`, `workloads.rb`, `load_hooks.rb`,
`gem/ext/lowrail_profile/lowrail_profile.c`, [profile.md](profile.md), the
[2026-11-18 reviews](upstream/profile-review-2026-11-18.md) and the history from `60d9c677` (2026-11-17, allocation
profile from inside the app) to `68b4ee07` (2026-11-18, rerun of Writebook, Pingcrm, CodeTriage and the Lobsters
YAML/DSL pair).

**What it measures.** Exact object allocation counts (no sampling) per source line, object type and window, from one
internal `NEWOBJ` tracepoint in a 650-line C extension that keeps counts in C memory and allocates nothing. Windows
are requests (`Rails::Engine#call`, named by the first `dispatch`), jobs (`perform_now`, plus `execute` for argument
deserialization), mail build and delivery, and Cable `perform_action`/`subscribe_to_channel`. Hooks are prepended
from Active Support `on_load`, so nothing loads earlier (invariant 7). A second run walks the stack with
`rb_profile_frames` to charge every allocation to its nearest app frame. It does not measure time, instructions or
retained memory.

**What it reports** (`report.md` and `report.json`):

* Your code: per app line, the framework and gem objects below it per request, its own apart, the lines and actions
  it reaches.
* Actions: objects per request per controller action, job, mailer action and channel action, warm (first request
  per process left out) and all, with run-to-run Δ.
* Top lines outside the app, by gem, with reach, Δ, the app lines that lead there, † for `<internal:…>` code charged
  to its caller, and dev/test-mode work (debug logging, error pages, template compilation, asset lookup, reload
  checks) in its own table.
* Ledger matches: an upstream pull request from the [contributions ledger](upstream/contributions.md) that changes
  that very line (same repository, file and method, the line's code among those the pull request removes or adds),
  with what it means for the version the lockfile runs ("open upstream work", "fixed in 8.2.0", "merged … not
  released yet"). On Campfire, 19 matches, each checked by hand.
* `compare BASE HEAD --aa BASE2`: exit 1 on growth beyond a noise floor from an A/A pair, 2 on invalid evidence (a
  failing suite, one run, other command, seed, Ruby or environment, dropped samples, unfinished windows, a malformed
  report), 0 otherwise; without `--aa` it lists and never gates.
* `--record` writes the suite's 20 most frequent request shapes as `lowrail/workloads.rb` (filtered through
  `filter_parameters`, values as literals, only replayable GETs enabled), and `--workloads` replays that file
  through the full stack in the current `RAILS_ENV`, with the census's client.

**Evidence so far.** Five corpus suites (Campfire, Lobsters, Writebook, Pingcrm, CodeTriage) gave identical
per-test outcomes plain, with the gem listed but off, and profiled, with the same load order in every process
(differences explained: yard's `Module#constants` walk, cold first runs). An A/A `compare --aa` exits 0 on Campfire,
Writebook (with its pre-existing failing test excluded), Pingcrm and CodeTriage; a planted `html_escape` loop in
`RoomsController#show` exits 1 with exactly the three expected rows. Against the census on the Blog's GETs in
production, per-line counts agree within about 1%. Overhead: 0–11% of suite time on the counting run, 1–45% on the
attribution run. Six review rounds (F1–F14, C1–C6, D1–D6, E1–E3, AA1) ended in "nits, no must-fixes" plus the fixed
AA1. `gem/test/profile_test.rb` runs 15 tests; without Rails installed 10 of them skip (checked here: 15 runs, 64
assertions, 10 skips).

### How a stranger installs and runs it today

```ruby
gem "lowrail", git: "https://github.com/thomasklemm/lowrail", glob: "gem/*.gemspec", group: [:development, :test], require: false
```

then `bundle exec lowrail-profile -- bin/rails test`. The first run compiles the counter into
`~/.cache/lowrail/profile/RUBY-BUILD/DIGEST/`, outside the app.

### What breaks or is Lowrail-internal

| Problem | Where | Effect on a stranger |
| --- | --- | --- |
| `required_ruby_version >= 4.0` | `gem/lowrail.gemspec` | Most teams run Ruby 3.3 or 3.4: Bundler refuses the gem. `Ractor.main?` (profile.rb) needs 3.4. Nothing was tested below 4.0.7. |
| One gem called `lowrail`, summary "Guarded, boot-fact specialization of Rails apps delivered as ISeqs" | gemspec | The team installs a lowering runtime to get a profiler: 70 files, 12,826 lines under `lib/lowrail`, of which the profiler needs 6. Reviewers of the Gemfile change see "specialization". |
| Git source only | README, profile.md | Bundler clones the whole repository, whose `.git` is 168 MB (corpus receipts, bench logs), into every CI cache. |
| Ledger default is the checkout's `docs/upstream/contributions.md` | exe, `ProfileReport#ledger_index` | Works only because the git gem is a full checkout. Packaged with `spec.files` it would silently lose every ledger match (`docs/` is not in the gem). The index is 860 KB and goes stale. |
| Rails tested only at 8.1.4, 8.1.4.1 and main | `.github/workflows/ci.yml` | Rails 7.2/8.0 hooks (`deliver_mail`, `action_cable_channel` on_load, `dispatch`) are unverified. The 10 Rails tests skip in CI jobs without Rails installed. |
| Linux only | orb and CI | macOS developers (most local runs) and its clang toolchain are unverified; Windows is not considered. |
| Internal pointers in user text | profile.md, README, report | `script/census`, `script/cpu-census`, `script/corpus`, `mise exec`, "the orb this was developed in", `bench/upstream/…` receipts, "Lowrail's contributions ledger", census key names. These describe this repository, not the user's tool. |
| Docs are evidence logs | profile.md (502 lines) | Install, use, guarantees, review history and corpus tables are interleaved. A team cannot find "what is promised" in one place. |
| `--workloads` sends real writes, real jobs, real mail | profile_workloads.rb | Correctly documented, but a dangerous default for a first-time user in a shared staging database. |
| Report schema is unversioned in docs | report.json, capture.json `format: 1` | compare checks "this version of lowrail-profile", so any release breaks every saved base. Fine for CI (profiles base and head in one job), surprising for anyone who stores bases. |

None of these is a correctness bug in what was reviewed; they are packaging, compatibility and wording.

## 2. What Rails teams use today

From their public documentation as known on 2026-11-25; not rerun here.

| Tool | What it gives | Unit | Where |
| --- | --- | --- | --- |
| rack-mini-profiler | Per-request timing badge, SQL, flamegraph (stackprof), memory (`?pp=profile-memory`, memory_profiler) | one request at a time, interactive | dev, sometimes production |
| stackprof | Sampling CPU/wall/object profiles | a process or block | anywhere |
| vernier | Sampling wall profiler with threads, GVL, GC, allocation sampling and Rails markers, Firefox Profiler UI | a process or block | anywhere |
| memory_profiler | Allocated and retained objects and bytes by gem, file, location, class | a block; slow (`trace_object_allocations`) | dev |
| derailed_benchmarks | Boot memory per gem; `perf:objects`/`perf:mem` (memory_profiler over N hits of one endpoint), `perf:ips`, `perf:library` (compare two revisions of a gem) | one endpoint | production env, locally |
| test-prof | Where suite time goes (factories, events, per-example) | test suite | test |
| bullet, prosopite | N+1 and unused eager loading | requests | dev/test |
| AppSignal, Scout, Skylight, New Relic, Datadog | Production timing per endpoint, traces, sometimes allocations per request, N+1 hints | real traffic, sampled | production, hosted |

**What only lowrail-profile does**, as far as the list above shows:

1. **Exact counts per action across a whole run.** Every allocation inside every request, job, mail and Cable action
   of the team's own suite (or a replayed request mix), aggregated per action and per line, warm apart from
   first-hit. The others either sample (stackprof, vernier, APMs) or profile one request or block (mini-profiler,
   memory_profiler, derailed).
2. **Framework and gem cost charged to the app line that caused it.** "Your code" ranks app lines by the Rails and
   gem objects allocated beneath them per request. Flamegraphs show the same stacks but leave the aggregation to the
   reader, per request.
3. **A CI gate with a measured floor that refuses bad evidence.** An A/A pair sets the noise floor per row, and
   anything that is not comparable (failing suite, other command, seed or Ruby, dropped samples) exits 2 instead of
   green. No tool above ships an allocation regression gate; derailed's `perf:library` compares two revisions
   without a floor or refusal.
4. **Upstream fix status per line.** A costly gem line links to the pull request that changes it and whether the
   app's locked version already has it, is behind a release, or waits on an open pull request. The team learns
   "upgrade rack to 3.2.9" or "this is open upstream work", not only "this line is hot".
5. **Dev/test-mode work separated.** Debug logging, error pages, template compilation, asset lookup and reload checks
   are reported apart, so a suite profile is not mistaken for production cost.
6. **No app change and an explicit no-op path.** One Gemfile line with `require: false`; nothing loads unless the
   command runs; a counter that fails or mismatches hooks nothing; per-test outcomes and load order were checked
   identical on five real suites.

What it does not do and the others do: time, CPU, retained memory, SQL, production traffic, flamegraphs. The release
should say so in its first paragraph and recommend pairing it with vernier or the team's APM.

## 3. The smallest release a real team could use: `lowrail-profile` 0.1

### Packaging

**A second gemspec, `gem/lowrail-profile.gemspec`, named `lowrail-profile`**, next to `lowrail.gemspec` in the same
directory. It lists only:

* `exe/lowrail-profile`;
* `lib/lowrail/profile.rb`, `profile_report.rb`, `profile_compare.rb`, `profile_workloads.rb`, `workloads.rb`,
  `load_hooks.rb`;
* `ext/lowrail_profile/*`;
* `data/contributions-index.json`: a snapshot of the ledger index trimmed to the fields the report reads, taken at
  release by `script/profile-ledger`, with its date printed in the report ("ledger of 2026-12-…").

The files stay where they are, so the census and the `lowrail` gem keep sharing `workloads.rb` and `load_hooks.rb`
without a copy, and `Lowrail::Profile` keeps its namespace. No lowering code is in the package, which a test checks
against `spec.files`. The `lowrail` gem keeps its own gemspec; it stops listing `exe/lowrail-profile`, so the two
gems never both install the executable.

Rejected: keeping it inside the `lowrail` gem (ships 12,800 lines of a parked runtime and the wrong summary), and a
separate repository (moves shared files and loses the census's single workloads client, the thing review F10 fixed).

**Distribution.** Recommended: rubygems.org, because the alternative (Bundler's git source) clones a 168 MB
repository. The gem is then `gem "lowrail-profile", group: [:development, :test], require: false`. A git source with
`glob: "gem/lowrail-profile.gemspec"` still works for anyone who wants main. Publishing is Thomas's decision and is
not part of this plan's work.

**Native extension.** Keep the current model: compiled on first run into the cache, outside the app, keyed by Ruby
build and source digest, never during boot. Do not use `spec.extensions`: a compile failure at `bundle install`
would break the team's install, while today it only stops the profiler with a clear message. Linux and macOS are
supported; Windows is refused with a message.

**Compatibility floor.** Recommended: Ruby 3.3+ (3.3 is maintained until March 2027) and Rails 7.2+, each only after
M2 proves it on a real suite. `Ractor.main?` needs a fallback on 3.3. If M2 shows 3.3 or 7.2 needs more than small
fallbacks, the floor rises to Ruby 3.4 / Rails 8.0 and the release says so.

### CLI (unchanged except as noted)

```sh
bundle exec lowrail-profile -- bin/rails test        # or: -- bundle exec rspec
bundle exec lowrail-profile report                   # rebuild from tmp/lowrail-profile
bundle exec lowrail-profile compare base.json head.json --aa base2.json
bundle exec lowrail-profile --record -- bin/rails test          # experimental
RAILS_ENV=… bundle exec lowrail-profile --workloads             # experimental, writes need --allow-writes
```

Additions, all small:

* `--help` and `--version`.
* `--workloads` requires `--allow-writes` (or the request file has only GETs), because it sends real writes, jobs and
  mail. It refuses `RAILS_ENV=production` with a non-local database host unless that flag is also given.
* `--no-ledger` and `--ledger FILE` (a newer index).

### Output

`report.md` (terminal and GitHub step summary) and `report.json`, unchanged in content. The release:

* documents `report.json`'s fields as schema 1 (what compare reads);
* says in the report's header what it is ("objects allocated, not time"), the ledger date, the Ruby, Rails and
  environment, and how many requests, jobs and mails were counted;
* removes Lowrail-internal words from user text: census key names stay as keys, but the report explains them once;
  `script/…` and orb references go.

No HTML report in 0.1: markdown renders in GitHub, editors and terminals, and the JSON is there for anyone who wants
more.

### Docs

Split [profile.md](profile.md) into:

* `gem/README-profile.md` (shipped as the gem's README): install, three commands, what the numbers mean, what it is
  not, the guarantees below, CI recipe, troubleshooting. Target under 250 lines.
* `docs/profile.md`: the evidence (corpus tables, reviews, reruns), linked from the README's guarantees.

### Guarantees, stated as tested

1. **No app changes.** It writes only inside `--out` (a directory it created or an empty one) and the `--record`
   target; it never edits the Gemfile, config or code. Checked by a test that diffs the app tree before and after.
2. **No lowering.** The package contains no lowering code (checked against `spec.files`) and never requires
   `lowrail/setup`.
3. **Off means off.** With the gem listed and `require: false`, an app process that the command did not start loads
   no Lowrail file (existing gemspec test, extended to the new gemspec).
4. **Same outcomes.** Per-test outcomes and load order identical plain, listed-but-off and profiled, on every app in
   §4. This is a corpus claim, not a promise for every app; the README says which apps and versions, and how a team
   checks its own (run the suite plain and profiled with a fixed seed and diff the per-test results).
5. **Exit status passes through** (the profiled command's statuses are recorded; a failing report never changes
   them) and **compare never turns invalid evidence green** (exit 2).
6. **Counts, not time.** No speed claim is made or implied; a line with many objects is a place to look.

## 4. Proof on three corpus apps

The proof is of the install path a stranger takes, not of a Lowrail checkout:

* Build the package with `gem build gem/lowrail-profile.gemspec`, install it from a local path into a fresh
  `script/corpus` copy whose Gemfile gains only the one line, in a shell with no Lowrail checkout on `RUBYLIB` and an
  empty `~/.cache/lowrail`.
* Follow only the gem's README.

Apps, chosen to cover what teams differ on:

| App | Why |
| --- | --- |
| Campfire | Minitest with parallel workers, Action Cable, jobs, a planted regression already measured |
| Lobsters | RSpec, mail, rack-mini-profiler loaded in every environment, Ruby 4.0.9 |
| CodeTriage | Sidekiq (ERB evaluated from line −1), jobs, a small fast suite; and run on the lowest supported Ruby/Rails pair if its lockfile allows, otherwise a fourth app at the floor |

Per app, recorded as receipts under `bench/upstream/profile_release/`:

1. Per-test outcomes and `$LOADED_FEATURES` order identical plain, off and profiled (seed 1234), as in
   [profile.md](profile.md#rechecked-after-the-review-fixes-2026-11-18).
2. `compare BASE HEAD --aa BASE2` on three unchanged invocations exits 0; the closest row as a share of its floor.
3. A planted change (the `html_escape` loop in one action) exits 1 with only the expected rows; a different command
   or seed exits 2.
4. Overhead of both runs against the plain suite.
5. Ledger matches spot-checked by hand against the pull request diff (at least five per app where there are five).
6. The app tree after the run equals the tree before, except `tmp/lowrail-profile`.
7. The GitHub Actions recipe from the README run once for real on a fork of one app (base twice, head once), with the
   planted change failing the job and the unchanged head passing it.

Plus a macOS run of Campfire's suite (GitHub `macos-latest`) for the extension build and outcomes.

## 5. Milestones

| # | Milestone | Size | Done when |
| --- | --- | --- | --- |
| M0 | Thomas's decisions (§7) | — | answered |
| M1 | Package: `lowrail-profile.gemspec`, trimmed ledger snapshot and loader, `--help`/`--version`, `--no-ledger`, `--workloads` write guard, `lowrail.gemspec` drops the executable, packaging test (`spec.files` has no lowering code; built gem runs from a temp install without the checkout) | S, 2 days | `gem build` + install + Blog suite profile from the built gem |
| M2 | Compatibility: CI matrix Ruby 3.3/3.4/4.0 × Rails 7.2/8.0/8.1 with Rails installed so the 10 Rails tests run, `Ractor.main?` fallback, macOS job | M, 3–5 days | matrix green, or the floor raised with the reason recorded |
| M3 | User docs and output: README for the gem, report header, schema 1 doc, internal references removed, profile.md becomes the evidence page | S, 2 days | a reader can install and read a report from the README alone |
| M4 | Corpus proof (§4) on three apps from the built gem, plus macOS and the real Actions run | M, 3–4 days | receipts committed, tables in profile.md |
| M5 | Independent review (Thermos) of the release candidate and its packaging, fixes, confirm review | S–M, 2–3 days | verdict "nits" or better |
| M6 | Release: version 0.1.0, changelog, tag, publish | S, under a day | only on Thomas's explicit approval |

About three weeks of work before M6. M1 and M3 can run in parallel; M4 needs M1 and M2; M5 needs M4.

## 6. Risks

* **Ruby floor.** Most teams are not on Ruby 4.0. If 3.3/3.4 need more than small fallbacks (Ractor API, fiber and
  thread internals the C extension relies on, `rb_profile_frames` behavior), the floor rises and the audience
  shrinks.
* **The `NEWOBJ` internal event.** It is in `ruby/debug.h` and used by `objspace`, but an internal event; a future
  Ruby could change when it fires. Mitigation: the API check already refuses a mismatched counter; add Ruby head to
  the CI matrix as an allowed failure.
* **Counts are not time.** Teams ask "how many milliseconds". A report that ranks lines by objects can point at work
  that is cheap. Mitigation: say it plainly, keep the dev/test table apart, recommend vernier/APM for time.
* **Suite profiles are not traffic.** A suite requests what tests need (the Blog's I18n lines led its suite profile
  and not the census). Mitigation: the Actions view and `--workloads`; the README says so.
* **Overhead up to 45%** on the attribution run of allocation-heavy suites, which matters for CI minutes (the gate
  needs three suite runs of two runs each). Mitigation: document `--runs`, and measure an option to attribute only
  in the head run.
* **Floor heuristic.** The action floor's multipliers come from Campfire; one A/A pair is one sample, not a bound.
  A noisy app can fail the gate on unchanged code. Mitigation: the README says how to read a failure and how to rerun
  the A/A pair; collect floors from the three apps in M4.
* **`--workloads` safety.** Real writes against the wrong database would be the worst possible first experience.
  Mitigation: experimental label, explicit write flag, production host refusal.
* **Ledger staleness and scope.** The ledger covers what Lowrail's contributors touched, not every fix; a stale
  snapshot says "open" for something merged since. Mitigation: date in the report, `--ledger` for a newer file,
  refresh per release.
* **Support load.** A public tool brings issues from apps nobody here has run. Mitigation: issue template asking for
  `report.json`, `capture.json` and the command; a stated support matrix.
* **Trust and naming.** "Lowrail" is known as an app-lowering project; teams may assume the profiler changes their
  app. Mitigation: separate gem name and README first line "never changes or lowers your app"; consider a name
  without "lowrail" (decision 1).

## 7. Decisions for Thomas

1. **Package and name.** Recommended: a second gemspec `lowrail-profile` in `gem/` (shared files, no lowering code).
   Alternatives: keep it in the `lowrail` gem; a new name without "lowrail".
2. **Distribution for 0.1.** Recommended: rubygems.org (a git source clones 168 MB). Alternative: git-only 0.1 for a
   few named teams first.
3. **Support floor.** Recommended: Ruby 3.3+, Rails 7.2+, if M2 holds; otherwise 3.4/8.0. Alternative: 4.0 and
   Rails 8.1 only (no compatibility work, small audience).
4. **What ships in 0.1.** Recommended: suite profile, report and compare as supported; `--record` and `--workloads`
   as experimental behind the write flag. Alternative: leave them out of 0.1.
5. **Ledger in the package.** Recommended: a dated snapshot of the index. Alternative: off by default and fetched on
   request (network access from a profiler).
6. **Proof apps.** Recommended: Campfire, Lobsters, CodeTriage, plus a floor-version app if CodeTriage cannot run
   there.
