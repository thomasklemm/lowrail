# Lowrail

Lowrail boots a Rails application, learns what is fixed after boot, and
delivers specialized Ruby for the parts it can prove equivalent, as MRI
instruction sequences. The real Rails and every gem keep running. Anything
Lowrail cannot prove stays the app's own code, and every refusal is recorded
with its reason.

Inspired by [Roundhouse](https://github.com/rubys/roundhouse), with a
different bet: keep the real framework, lower only what can be guarded
exactly, and measure every claim. See [docs/PLAN.md](docs/PLAN.md) for the
why and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how a pass plugs in.

## Status (2026-10-20)

**Research prototype. No production speedup today.**

- **Correctness machinery works.** `lowrail verify` runs an app's own suite
  with Lowrail off and on and compares per-test outcomes and ordered SQL.
  The pinned Rails 8.1.4 framework suites are a standing gate
  ([rails-suite.md](docs/rails-suite.md)). Five original corpus apps retain
  identical outcomes/SQL. The expanded [gem-breadth corpus](docs/compat.md)
  found and fixed early-autoload bugs; the stricter load census still
  rejects Redprints' require-hooks adapter change. No universal support
  claim follows from the green outcome comparisons.
- **The default build lowers nothing.** The two former default passes,
  `view/link_to` and `route/path`, are quarantined. Warmed apps could
  observe stale helpers when code changed mid-request
  ([counterexamples](docs/passes/endpoint.md#source-arm-quarantine)). That cost
  the blog about 6 % on `/articles`, and we accept the loss.
- **Guarded opt-in passes** are [`inertia/props`](docs/passes/props.md) and
  the conservative `endpoint/action` slice; neither has an accepted
  whole-request win. Memo, digest memo, AR plans, preload plans and
  `inertia/config_bind` are now **sealed-only**: suppressed mutation hooks
  defeat their cached facts ([audit](docs/passes/suppressed-hooks.md)).
- **Where speed could come from is measured.** On the blog, rendering is
  25–34 % of a request, events 3–4 %, routing and middleware about 2 %.
  Handwritten endpoint ceilings are −26 % (index) and −37 % (show) with
  events kept. They are upper bounds, not delivered results
  ([layer study](docs/passes/layer-ceiling.md)). Checking from the call site
  costs more than the work it saves
  ([cost gate](docs/passes/endpoint.md#show-section-cost-gate-stop-before-runtime-implementation)).
- **Types and MCP work.** `lowrail types` and `lowrail mcp` serve boot facts,
  typed facts (proven, static or observed), refusal reasons and the last
  verify hits ([types.md](docs/types.md)).

Every pursued, parked and rejected idea is in
[docs/DECISIONS.md](docs/DECISIONS.md). Dated evidence is in
[docs/STATUS.md](docs/STATUS.md).

## Direction

Two tiers, so that every app keeps running and apps that opt in can go
further:

| Tier | Who | Promise | State |
|---|---|---|---|
| **guarded** (default) | any Rails app, any gem | identical test outcomes; specializations guarded and refused when not exact | works; currently lowers nothing by default |
| **sealed** (opt-in) | apps that accept a contract: no code, subscriber, config or route mutation after boot, among others | compile endpoints ahead of time without per-call checks; `lowrail seal-check` runs the app's suite and lists every violation with `file:line` and the code change that fixes it | being designed ([decision](docs/DECISIONS.md#architecture)) |

Apps that do not meet the sealed contract still run in the guarded tier. The
tooling explains why and what to change.

## Target matrix

| Axis | Primary | Secondary / diagnostic |
|---|---|---|
| Rails | 8.1.4 | 8.2 alpha (Campfire's pin) |
| Ruby (minimum 4.0) | 4.0.7 (`mise.toml`) | 4.1 preview ([separate compatibility matrix](docs/ruby-4.1.md)) |
| Execution | interpreter instruction counts (Callgrind, fixed heap, A/A controls) | YJIT under a strict JIT-flat gate; ZJIT being added, diagnostic only |

How to read and reproduce measurements: [docs/bench.md](docs/bench.md).

## Usage

Lowrail is not published as a gem. Use it from a checkout, on a disposable
copy of your app or in CI. Do not use it in production yet.

```sh
# 1. Toolchain: a Rust toolchain and the Ruby pinned in mise.toml
cargo build --release            # CLI at target/release/lowrail

# 2. Boot facts and a build (writes APP/.lowrail/)
lowrail facts path/to/app
lowrail build path/to/app [--env test|production]   # default selection
lowrail build path/to/app --passes default,+props,+endpoint

# 3. Prove it: your suite off vs on, per-test outcomes + ordered SQL
lowrail verify path/to/app     # prints its test seed to stderr; SEED=… to fix it

# 4. Types and tooling
lowrail observe path/to/app    # record observed types from a test run
lowrail types path/to/app --rbs sig/lowrail
lowrail mcp path/to/app        # read-only MCP server over stdio

# 5. Measurements (see docs/bench.md before trusting a number)
lowrail bench path/to/app --pass NAME
```

The runtime loads without app or Gemfile changes:

```sh
RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails test
```

Alternatively, add `require "lowrail/setup"` in `config/boot.rb`, before or
after Bootsnap. `LOWRAIL=0` disables it. A missing, stale or incompatible build
is a silent no-op, and an artifact containing quarantined passes is refused
with `Lowrail.refusal_reason`. In development it is off unless `LOWRAIL=1`.
`LOWRAIL_DEBUG=1` prints refusals.

`--passes` must start with `default` or `all-opt-in`, then applies
`+name`/`-name` in order. Names are the stable
`area/name` identifiers in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
Short aliases are `memo`, `preload_plans`, `ar_instantiate`, `ar_plans`,
`digest_memo`, `inertia_config`, `props` and `endpoint`, but only `props` and
`endpoint` remain eligible for guarded selection. The others refuse even in
`all-opt-in`; old mixed artifacts refuse as a whole. Sealed research builds
use `--sealed --env production` and require explicit production acceptance
of the [sealed contract](docs/sealed.md); test processes stay original-only.
File formats are documented in [docs/FORMATS.md](docs/FORMATS.md).

`LOWRAIL_VERIFY_LOADS=1 lowrail verify APP` also compares non-autoloading
constant censuses, Zeitwerk-loaded paths and executed Active Support load
hooks at the first test and after the suite, including load/hook order.
Reproducible differences fail verification and automatically probe each pass;
off/off and on/on variation is reported separately as advisory noise.
This observer is opt-in because its snapshots and boot hooks have a cost;
the corpus compatibility checks enable it. Snapshot time is in the report.

## Complementary optimizations

Lowrail only applies changes it can guard exactly. These stay the app's own
decision, and Lowrail works next to them:

- **YJIT** (`RUBY_YJIT_ENABLE=1`): recommended in production. Lowrail measures
  under it too, but its primary gate is interpreter instruction counts,
  because whole-request YJIT windows do not yet pass our compiler-state gate.
- **Bootsnap**: works in any load order. Bootsnap caches the original
  bytecode, and Lowrail serves its lowered bytecode.
- **Frozen string literals** (`# frozen_string_literal: true` or
  [Freezolite](https://github.com/ruby-next/freezolite)): fewer allocations,
  but mutating a literal then raises. Enable it only after your suite passes
  with it. Lowrail compiles each file with the same options the app's loaders
  use ([loaders.md](docs/loaders.md)).

## Docs

| Read | For |
|---|---|
| [PLAN.md](docs/PLAN.md) | goals, contract, why this design |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | pipeline, pass contract, registry |
| [DECISIONS.md](docs/DECISIONS.md) | what is pursued, parked or rejected, plus the stacking backlog |
| [STATUS.md](docs/STATUS.md) | dated evidence log |
| [compat.md](docs/compat.md) | pinned real apps, gem breadth, baseline failures, load-order findings and verify results |
| [bench.md](docs/bench.md) | measurement protocol and results |
| [types.md](docs/types.md) | typed facts, MCP and RBS |
| [docs/passes/](docs/passes/) | one study per pass or idea |
| [rails-suite.md](docs/rails-suite.md), [ar-equivalence.md](docs/ar-equivalence.md) | framework-suite and Active Record gates |
