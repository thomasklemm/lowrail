# Measurement matrix: Rails main, Ruby 4.0.7 and master, interpreter, YJIT and ZJIT

Thomas (2026-11-03) asked two questions. Should every Rails measurement also run ZJIT, so the 20 census apps turn up
ZJIT work and show how our own fixes behave there? And do the apps run against the frontier, meaning Rails main and
Ruby master (4.1dev)? This page records the answer and the matrix we use from now on.

## Where we stand

* **Rails main: yes, always.** `script/census` moves every app to the pinned Rails main commit with dependency-only
  overlays ([census.md](census.md)). Apps keep their own source; only Rails and the gems it needs change. Measuring
  the app's released Rails would tell us nothing we can still fix.
* **Ruby master: only in one-off reports.** The [JIT parity census](jit-parity-census.md) (L2) and the
  [Ruby 4.1 regression watch](ruby-4.1-regression-watch.md) (L3) ran the 9 census-4 apps on master. The 20-app
  census ([census 7](rails-main-census-7.md)) runs Ruby 4.0.7 only. The 11 PostgreSQL and Inertia apps have no
  master overlays yet.
* **ZJIT: never on all 20 apps.** ZJIT exists only on master builds. ZJIT CPU work (Z1, Z3, Z5–Z8) priced its
  candidates on ruby-bench railsbench, lobsters and shipit with Callgrind. ZJIT was run on apps only for the 9-app
  parity census and some per-bet checks.

## What ZJIT on the apps finds, and what it can't

* **Allocations** hardly depend on the mode. The useful number is ZJIT minus interpreter per source line, the
  parity method of L2. Rerun it once per Ruby pin, not in every census.
* **ZJIT stats counters** (fallback reasons, side exits, dynamic sends) are where 20 apps beat 3 benchmarks. They
  cover the long tail of ISEQs, gems ruby-bench doesn't load (Devise, Turbo, Sidekiq, Inertia and others), and
  breadth in the form "N of 20 apps hit this fallback". The ZJIT team weighs exactly that when we claim a tracker
  issue.
* **Instruction counts on app pages are not evidence.** Their A/A spread reaches ±7%, and Callgrind on JIT code is
  slow. Apps find the sites, ruby-bench prices them, as [bench.md](../bench.md) requires.
* **Rails changes made only "for ZJIT"** (less polymorphism, avoiding `send` or `...`) are a trap. The JIT should
  handle idiomatic code, such changes go stale as ZJIT improves, and Z3 found that the largest fallback bucket is
  profile loss at monomorphic sites, which is a ZJIT problem. A Rails change counts only if it also wins on Ruby 4.0.7
  (allocations or interpreter instructions). A ZJIT gain is then one supporting line.

## The matrix

| Cell (Rails × Ruby × mode → measurement) | Cadence | Evidence for |
| --- | --- | --- |
| main × 4.0.9 × interp + YJIT → allocations, SQL, A/A | every census and the daily watch (4.0.7 until 2026-11-03) | **Rails PRs**: maintainers and most apps run released Ruby |
| main × master × ZJIT → stats counters, exit and fallback traces (sample rate 20) | every census | **choosing ZJIT issues and PRs** |
| main × master × interp + ZJIT → allocations, A/A | per Ruby pin (weekly) | ZJIT parity sites; Rails PRs that need 4.1 (e.g. #59557) |
| main × master × interp + YJIT → boot, allocations, GC, A/A | every census, same pinned SHA as the ZJIT pass (recorded) | the 4.1 regression watch (L3 found 3 regressions); replaces a 4.1.0-preview1 column |
| ruby-bench × master × ZJIT → Callgrind Ir with A/A | per candidate | **the speed claim of a ZJIT PR** |
| our merged Rails PRs, revert tree × master × interp + ZJIT | once now, then per merge wave | do our savings carry over to ZJIT, and does any PR add ZJIT fallbacks |
| boot to warm, compile time, 3 large apps (Discourse, Mastodon, Chatwoot) | once per compile-speed bet | ZJIT compile-speed issues (Z6 had to use ruby-bench instead) |
| app's released Rails; Callgrind on app pages under a JIT; YJIT stats on master | skip | nothing to fix there; noise; YJIT gets correctness fixes only |

When Ruby 4.1.0 ships (December 2026), the routine allocation cell moves from 4.0.9 to 4.1, and master stays the
frontier.

## Rules for master runs

* **One Ruby pin per round.** Build a master SHA once a week, `--enable-zjit --enable-yjit`, release build. Record it
  in `meta.json`, give each pin its own A/A pair, and never compare across pins without one.
* **ZJIT warmup.** Use a longer warmup than census 7's 50 operations (start with 200). Gate on compiled ISEQs per
  operation ≈ 0, since Campfire still compiled 1.9 ISEQs per operation after 50. Record `--zjit-mem-size`, because
  Fizzy's exits change at 128 MB.
* **Clean counters.** Run the allocation and stats passes in separate processes (`--zjit-stats` changes what it
  measures). Accept a fallback reason only if it reaches ≥ 3 apps and its two runs differ by ≤ 5%.
* **Gems on master.** Extend the dependency-only overlays (`fixtures/corpus/ruby-41-watch`) to every app before the
  first 20-app round. Gems that don't build on master get the smallest version bump that builds, recorded per app.

## Tasks started (2026-11-03)

1. **F1, frontier census:** master overlays for all 23 configurations, the pin policy in census.md, then the first
   20-app round on Rails main × master: interpreter and ZJIT allocations with A/A, ZJIT stats, and a ranking of
   fallback and exit reasons by apps reached, with ownership checked against Shopify/ruby and ruby/ruby.
2. **F2, our Rails PRs under ZJIT:** the [combined-effect](combined-effect.md) revert tree, updated with census 7's
   merges, on master × interpreter + ZJIT: allocations, ZJIT stats, and ruby-bench Callgrind under ZJIT with A/A.
