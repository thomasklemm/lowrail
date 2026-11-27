# Status

Decisions on what to pursue, park or reject: [DECISIONS.md](DECISIONS.md).

Living summary of what works, what was learned, and what is next. Details
live in the linked docs; numbers come from executed runs, dated.

## At a glance (2026-11-27)

| Area | State |
|---|---|
| **Direction (2026-11-02)** | **Discovery first, lowering parked.** Lowrail measures real apps on Rails main and upstreams small, exact fixes in Rails, Ruby and its JITs, and gems; correctness work (app and gem suites on main against 8-1-stable, Ruby master) runs alongside. No request speedup is claimed. [Decision and stop list](DECISIONS.md#lowrail-reoriented-toward-upstream-fixes-and-advisory-types-2026-11-02) |
| **Contributions (2026-11-27, 19:11 UTC)** | PRs created since 2026-10-19 (Lowrail's first commit), without roundhouse-rb, argos-ri and own repositories: 234 opened, 138 merged, 43 open (no drafts), 53 closed, in 40 repositories. rails/rails 118 opened, 91 merged, 1 open (#59565), 26 closed; ruby/ruby 44 opened, 17 merged, 8 open, 19 closed; 38 other repositories 72 opened, 30 merged, 34 open, 8 closed. All time rails/rails: 92 merged (91 since 2026-10-19 plus #7260 from 2012), 7 of them on 2026-11-27. Open work: all 43 open PRs wait on maintainers, none on us; no open queue item is ready to open. Per-repository table and whom each open PR waits on: [counts](upstream/contributions.md#counts-2026-11-27). Each PR's own result is in the [ledger](upstream/contributions.md); open work in the [PR queue](../bench/upstream/pr-queue/README.md). |
| **Combined effect, round 4 (2026-11-27)** | Rails main `088fc0cf61` against the same commit with 78 of our 85 merged rails/rails PRs reverted (the same five as in round 3 can't be reverted cleanly and stay in both trees). Ruby 4.0.10: census allocations −6.60% interpreted / −6.53% YJIT (105 workloads, eleven apps, A/A ≤ ±0.03%); ruby-bench objects per iteration −5.1% to −15.6%; interpreted instructions per iteration −2.88% railsbench, −9.52% shipit and −0.92% lobsters (A/A ≤ 0.10%). No YJIT instruction row is claimed (not JIT-flat). Ruby master: −7.08% / −6.99% interpreted / ZJIT (79 workloads, eight apps). Reverting our 17 merged ruby/ruby commits leaves interpreted census allocations flat and saves 0.12% under ZJIT. The WhereClause, database-statement, Merger and PostgreSQL type-map PRs carry 62% of the attributed saving. Allocation and instruction counts only ([combined effect](upstream/combined-effect.md#round-4-every-merged-pr-on-rails-main-2026-11-27)). |
| **Latest census: 12 (2026-11-27)** | Rails main `088fc0cf61` against v8.1.4.1, 8 apps, 71 workloads, Ruby 4.0.9: median −8.54% interpreted instructions per request (69 of 71 faster beyond 1%, 614 fewer objects per request, median). Against census 11's main: −1.72%. One workload is slower than 8.1: codetriage `perform SendSingleTriageEmailJob`, +3.42%, the debug-level event reporter from #56213, judged deliberate. Hot work that moves whole requests is ranked by mean share and reach ([census 12](upstream/rails-main-census-12.md)). |
| **Ruby 4.1 (2026-11-27)** | Ruby master `f3e180b5eb` against 4.0.9, each app's own suite compared per test. The 9 light apps (Blog, Campfire, CodeTriage, Fizzy, Writebook, Hackatime, Thinkroom, React starter kit, Redprints) show no outcome differences in 36 of 36 comparisons ([light slice](upstream/ruby41-differential-409.md)). The heavy apps show 4 master-only differences from Ruby itself, none a JIT effect, two of them app bugs or app test setup: Flow 1 (`Time.iso8601` keeps Feb 30, a known regression, fix in review), Sure 2 (Mocha `ENV.stubs` raises `Ractor::IsolationError`), Discourse 17 (frozen `Symbol#to_s`), CASA 1 (default gems activated before `bundler/setup`). Chatwoot did not run, Lago ran in the interpreter only ([heavy apps](upstream/ruby41-differential-409-heavy.md)). Ruby 4.1 ships 2026-12-25. |
| **Rails main breaks two corpus apps** | Fizzy's `uuid_primary_keys.rb` recurses and activerecord-typedstore 1.6.0 raises in Lobsters after #59141; the census copies carry local workarounds; not reported as of 2026-11-14 and not rechecked since, and [ZJIT gap census 2](upstream/zjit-gap-census-2.md#not-measured) still lists both as failing on main ([ruby-master-round-2](upstream/ruby-master-round-2.md#6-railsrails59141-shared-attribute-readers-under-yjit-and-zjit)). |
| **Ruby pin 4.0.10 (2026-11-27)** | Census and Rails PR evidence run on Ruby 4.0.10 (4.0.9 from 2026-11-03); comparisons already running finish on 4.0.9, and every A/A and main-versus-branch pair runs on one pin. Ruby 4.1 is measured on pinned Ruby master with its SHA recorded ([DECISIONS](DECISIONS.md#evidence-and-measurement)). |
| **PR queue (`script/pr-queue status`, 2026-11-27)** | 164 items: 49 ready (open PRs), 2 built (HM2, UR1), 25 held, 51 merged, 29 closed, 8 superseded. Each held item's note says why and what unblocks it; the [lead sweep](upstream/lead-sweep-2026-11-27.md) re-checked most of them against GitHub and current code. [Queue](../bench/upstream/pr-queue/README.md) |
| **Lowering prototype** | Parked since 2026-11-02, unchanged; its last state and its former STATUS sections (moved on 2026-11-27) are on the [prototype page](prototype.md#lowering-sections-moved-from-statusmd-2026-11-27). |

## Next

The three bets and Next (a)–(d), as set by Thomas on 2026-11-25 ([DECISIONS, Bets](DECISIONS.md#bets), the source of truth):

* **Three bets in parallel:** ZJIT gaps on real apps beyond k0kubun's zjit-headline2; unreleased Rails 8.2 regressions
  (rails-main-census-11); lowrail-profile for any Rails app. The coordinator runs and reviews them.
* **(a)** lowrail-profile on 5–8 unfamiliar open-source apps, costly gem lines turned into upstream fixes.
* **(b)** Correctness before Ruby 4.1: weekly differential of the census app suites on Ruby master (interpreter, YJIT,
  ZJIT) and on zjit-headline2, minimized and bisected.
* **(c)** A list of our open rails/rails PRs that could close or be bundled, for Thomas.
* **(d)** Tooling: ownership check before opening, raw-data retention before archiving a thread, a trailer-refusing
  pre-push hook in fork checkouts.
* ZJIT performance asks pause: zjit-headline2 is ahead of YJIT on every measured app.
* lowrail-profile 0.1: no release, not even rc1, before an intensive field test on all census apps; the release needs
  Thomas ([profile-release-plan](profile-release-plan.md)).

Open from the [lead sweep](upstream/lead-sweep-2026-11-27.md) (2026-11-27), nothing posted or pushed:

* **TO1** stays held as a parked idea: the ZJIT `f.text_field` loss is explained (buffer reallocation on long attribute
  lists), and sizing the buffer up front would make the change L2 for a sub-1% per-field effect.
* **Two Ruby correctness repros** that need Thomas as new issues (the `shareable_constant_value` kwsplat `NoMethodError`
  and the unused `Kernel#==` refinement, where ZJIT diverges from the interpreter).
* **ZL3:** cite our merged OTS1 (ruby/ruby#19982) as precedent when asking the ZJIT team again on Shopify/ruby#776.
* **`Mime::Type.parse`:** parked until a request-level share is measured on an app with Rails main's 8.2 defaults.

Lowering priorities of 2026-10-20 and the older follow-ups are in [prototype.md](prototype.md#next-2026-10-20-as-statusmd-listed-it).
