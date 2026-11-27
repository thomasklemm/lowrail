# Working on Lowrail

Lowrail measures real open-source Rails apps on Rails main and upstreams small, exact fixes for the avoidable work
it finds, in Rails, Ruby/ZJIT and gems ([README](README.md)). Read [docs/DECISIONS.md](docs/DECISIONS.md) first: it
holds the rules for upstream work, and its first section lists what needs Thomas.

## Rules

1. **Nothing goes upstream without Thomas** unless DECISIONS names a standing approval for that action. Never comment
   on other people's PRs or issues without his approval of that specific comment. Orbs draft and report to the
   coordinating thread; they don't post, ping or notify Thomas.
2. **Upstream PRs go through the queue.** One file per candidate in `bench/upstream/pr-queue/items/`; open only with
   `script/pr-queue open ID`, which checks caps, ownership and review passes on the exact head. Never work around a
   refusal.
3. **Claims need evidence you ran.** Every measured number (allocations, instructions, time) in a body or record comes from a kept
   run with an A/A control
   (`script/upstream-bench`, `script/census`, [docs/bench.md](docs/bench.md)), on one Ruby pin per comparison.
   Commit the raw data, or an archive of it, before reporting done. Allocation and instruction counts are not time.
4. **Exact means exact.** An upstream change behaves as before for every caller the contract covers: run the
   exactness checklist and a differential probe (DECISIONS, Review gates) before review.
5. **Record what was not done and why**: held items, closed PRs and dropped candidates stay in the queue and the
   [ledger](docs/upstream/contributions.md). Don't hide gaps.
6. **Commits** are Thomas Klemm's as author and committer, with no trailers: `script/commit -F MSGFILE`. Lowrail commit
   messages name upstream work by queue item ID, never `owner/repo#N` or a PR URL. Run `script/install-fork-hooks DIR`
   on every fork clone before its first push.
7. **Upstream text is short and plain**: PR descriptions, code comments and tests follow DECISIONS, Pull requests.
   Nothing internal (queue IDs, census numbers, reviewer names, Lowrail) goes upstream.

## Layout

* `script/`: census, `pr-queue`, `ownership`, `upstream-bench`, `commit` and the other tools.
* `bench/upstream/`: queue items and raw data per topic. `docs/upstream/`: census rounds, bets, leads, the ledger.
* `gem/lowrail-profile.gemspec`: lowrail-profile, the allocation profiler for any Rails app
  ([gem/README-profile.md](gem/README-profile.md)). It ships no lowering code.
* **Paused:** the Rust core in `src/` and the lowering runtime in `gem/` (`lowrail.gemspec`, `lowrail/setup` and the
  lowering passes). Leave them unchanged unless Thomas resumes them ([docs/PLAN.md](docs/PLAN.md),
  [docs/prototype.md](docs/prototype.md)).

## Lowering invariants (`src/` and the lowering parts of `gem/`)

These hold for any change to the paused engine:

1. **Never break an app.** A missing, stale, or incompatible build must be a
   silent no-op. Any lowered method keeps its name, parameters, visibility,
   and original body as fallback.
2. **Every specialization is guarded** by the boot facts it assumes, listed in
   the manifest. No unguarded assumption about method resolution, schema, or
   config.
3. **Support claims need `lowrail verify`**: identical per-test outcomes with
   Lowrail on and off, and non-zero fast-path hits for the units claimed.
4. **Speed claims need a benchmark** against the same app without Lowrail,
   using `lowrail bench` ([docs/bench.md](docs/bench.md)): interpreter
   instruction counts with fixed heap and passing A/A/heap controls are
   primary. YJIT (and later ZJIT) results count only when every measured
   window passes the JIT-flat gate. Rejected cohorts are recorded, not rerun
   until green.
5. **Record why something was not lowered.** The ledger is the progress
   measure; do not hide gaps.
6. **Exact means exact mid-request too.** A check at entry does not cover
   code that the lowered region evaluates later (helper arguments,
   `to_param`, callbacks). Either certify each such boundary or refuse.
7. **Preserve lazy loading.** Lowrail never forces loading of app/framework
   constants or runs on_load hooks earlier than the app would; passes observe
   already-loaded constants and subscribe to Zeitwerk/ActiveSupport on_load.
