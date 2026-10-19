# Lowrail — plan for the first iteration

Lowrail lowers what it can of a Rails application into specialized Ruby and
leaves everything else alone. It is deeply inspired by
[Roundhouse](https://github.com/rubys/roundhouse), but makes a different bet:

| | Roundhouse | Lowrail |
|---|---|---|
| Rails at runtime | replaced by a small Ruby runtime | the real Rails, every gem, unchanged |
| Supported subset | apps with zero error diagnostics | **every** Rails app; unsupported code just isn't lowered |
| Targets | ~12 languages | lowered Ruby (MRI ISeqs); Spinel maybe later |
| Knowledge of the app | static analysis of source | static analysis **plus a real boot** plus observed types |
| Implementation | Rust | Rust (Prism and Rubydex as native crates) |
| Correctness bar | emitted app passes its tests | the app's own test suite gives *identical per-test results* with Lowrail on and off |

## 1. Contract

1. **Boots everything.** Any Rails app with any gems boots and runs with
   Lowrail installed. A missing, stale, or incompatible build is a no-op, never
   an error.
2. **Identical test outcomes.** For every test, outcome with `LOWRAIL=1` equals
   outcome with `LOWRAIL=0`. This is checked by `lowrail verify`, not assumed.
3. **Every specialization is guarded.** Lowered code runs only while the boot
   facts it assumed still hold; otherwise the original body runs. Fallback is
   always the user's own code.
4. **No speed claim without a benchmark.** Performance claims cite a
   reproducible measurement against the same app without Lowrail, YJIT on.
5. **Diagnostics are a ledger.** "Not lowered, because …" is recorded per
   method; it is the equivalent of Roundhouse's warning ledger. There are no
   blocking errors: an app we cannot lower at all still runs.

## 2. Where the speed has to come from (open question #1)

Roundsnap (roundhouse#591) measured **no** throughput gain from ISeq delivery
alone, and Bootsnap already caches ISeqs. Roundhouse is fast because it
replaces Rails. Lowrail keeps Rails, so speed can only come from
**specializing code under facts that are fixed after boot** and that YJIT
cannot see or cannot assume:

- method resolution after boot (devirtualize `send`/`public_send`/`try`,
  `respond_to?` branches, delegation and `method_missing` chains);
- configuration read on hot paths (`config.x` branches, instrumentation with
  no subscribers, feature flags) — folded under a guard;
- schema and reflections (attribute access, type casting, association readers);
- callback chains and filter chains flattened per class;
- view rendering: template/partial resolution resolved at build time, locals
  known, helpers specialized;
- route generation (`*_path` helpers) specialized per route.

**Milestone M0 measures this before we invest further** (see §8). If the
specializable share of hot frames in real apps is small, the performance half
of Lowrail is a no-go and the type/MCP half stands alone.

## 3. Architecture

```
            build time (CI / deploy, like assets:precompile)
┌──────────────────────────────────────────────────────────────────┐
│  lowrail facts   boot app (RAILS_ENV=test, eager_load!) in Ruby,  │
│                  dump boot facts: modules, ancestors, method       │
│                  owners/source locations/visibility, schema,       │
│                  reflections, callback chains, routes, config      │
│  lowrail profile (optional) run test suite with type/hotness       │
│                  sampling → observed arg/return classes           │
│                         │                                          │
│                         ▼                                          │
│  Rust core: Prism parse ─► program model ◄─ Rubydex index          │
│           types = static ⊔ boot facts ⊔ observed                   │
│           lowering passes ─► guarded, line-preserving splices      │
│                         │                                          │
│  lowrail build   ruby helper compiles lowered files to ISeq        │
│                  binaries + manifest (facts per unit)              │
└──────────────────────────┬───────────────────────────────────────┘
                           │ .lowrail/manifest.json + iseq/*.bin
┌──────────────────────────▼───────────────────────────────────────┐
│ runtime gem  load_iseq hook (after Bootsnap): serve lowered ISeq   │
│              if source digest matches, else fall through           │
│              guards: per-unit state, reset by method_added/        │
│              include/prepend/extend hooks, lazily revalidated      │
└──────────────────────────────────────────────────────────────────┘
  lowrail verify  test suite LOWRAIL=0 vs 1, per-test identity,
                  fast-path hit counts, bisection → denylist
  lowrail mcp     types, method facts, "why not lowered", RBS/RBI
```

### 3.1 Boot facts

A Ruby helper boots the app exactly as its tests do and records what static
analysis of Ruby cannot know: every module and its ancestors, every method's
owner, `source_location`, visibility and parameters (including methods made by
`define_method`, `class_eval` strings, `delegate`, `attribute`, associations),
AR columns and reflections, callback chains, routes, and relevant config.
roundhouse#788 showed generated methods can be traced back to source spans;
Lowrail reuses that idea but keeps the real methods running instead of
materializing a replacement app.

### 3.2 Program model and types

Learned from Roundhouse: whole-program merging gives very precise types at
the bottom layer (schema → attribute types, associations → `Relation[T]`,
controller ivars → view locals), with a bounded fixpoint over return and
parameter types. Lowrail adds two sources Roundhouse does not have: boot facts
(ground truth for method resolution) and observed types from a test run.
Types are a hint for lowering only when backed by a guard; otherwise they feed
the MCP server and RBS/RBI generation.

### 3.3 Lowering = guarded, source-preserving specialization

A lowered method keeps its name, parameters, and original body; the
specialized body is added in front of it on the `def` line, so line numbers,
backtraces of the fallback, `instance_methods`, and `ancestors` stay exactly
as before:

```ruby
def title_for(record) if ::Lowrail::G[17] || ::Lowrail.check(17) then <specialized>; else
  original body unchanged
end; end
```

Each unit (here 17) lists its facts, e.g. "`Article#title` is owned by
`Article`, defined at article.rb:12, public". `G[17]` is `nil` (unchecked),
`true`, or `false`. Hooks on `method_added`, `singleton_method_added`,
`method_removed`/`undefined`, `append_features`, `prepend_features`, and
`extend_object` reset to `nil` every unit whose facts mention the affected
method name; the next call revalidates. Test doubles (`Minitest::Mock#stub`,
RSpec `allow(...).to receive`) therefore switch the method back to its
original body while stubbed, and back to the fast path afterwards.

Known holes, to be covered by `verify` and documented: a class that overrides
`method_added` without calling `super`, methods defined in C after boot, and
code that inspects ISeqs or `RubyVM::AbstractSyntaxTree.of`.

Passes are small and explicitly ordered, and each one records what it could
not lower and why (Roundhouse's ledger pattern).

### 3.4 Delivery

`RubyVM::InstructionSequence.load_iseq`, the seam Bootsnap uses, prepended
after Bootsnap. It covers app files **and** gem files, so Rails itself can be
specialized. The manifest is keyed by absolute path plus SHA-256 of the
source; Ruby description and compile options must match the build, else
Lowrail is a no-op. Off in development by default.

### 3.5 Verification

`lowrail verify` runs the app's suite twice (Minitest and RSpec reporters
ship with the gem), compares per-test outcome identities, and reports how
often each unit's fast path ran, so that "green" is not vacuous. A divergence
is bisected to the responsible unit, which goes on a per-app denylist with
the failing test as evidence.

### 3.6 Types, MCP and editor

Roundhouse's MCP tools (`type_at`, `can_be_nil`, `references`, `traceroute`,
`diagnostics`, `wont_lower`) carry over, backed by the richer model, plus:
`method_facts` (owner, source, generator of a generated method), `why_not_lowered`,
and RBS/RBI generation for app code. LSP comes after MCP.

## 4. Why Rust

We considered Go: a garbage collector makes the cyclic program model
(classes ↔ methods ↔ call sites ↔ types) simpler, which is why TypeScript's
compiler moved to Go. That move was a near line-by-line port of an existing
GC-based codebase. Our existing codebase is Roundhouse, in Rust, and both
libraries we depend on most are first-class there: Prism has official Rust
bindings (`ruby-prism`), and Rubydex *is* a Rust crate, which Go could only
reach through cgo plus a Rust toolchain. Rust also lets us reuse Roundhouse
pieces (ERB compiler, method catalog, parts of the analyzer).

Cycles are handled the way Rubydex does it: arenas and typed IDs instead of
owning pointers. If that turns out to dominate the effort, we revisit; the
CLI, gem, manifest and fact formats do not depend on the language.

The binary ships in platform-specific gems, like `tailwindcss-rails`.

## 5. Repository layout

```
src/main.rs         CLI: facts, profile, build, verify, mcp, bench
src/facts/          boot fact schema and loader
src/model/          program model (arenas + IDs), type inference
src/lower/          passes, splice planner, ledger
src/build/          ISeq compilation driver, manifest
src/verify/         differential test runner, bisection
src/mcp/            MCP server
gem/                runtime gem: loader, guards, fact dumper, reporters
testdata/apps/      corpus pins (real-blog, Campfire, Writebook, Mastodon, Lobsters)
```

## 6. Corpus and gates

Start with Roundhouse's corpus: real-blog (Rails 8.1.4, 21 tests, green
under real Rails), Campfire, Writebook, Lobsters, Mastodon. Each app is a
gate: `verify` must report identical outcomes, and the fast-path hit counts
are tracked over time.

## 7. Decisions still open

1. **Granularity:** whole-file ISeq with in-method splices (current design)
   vs. replacing methods after boot. The former keeps reflection unchanged;
   the latter avoids touching files.
2. **Scope:** app code only, or Rails and gems too. M0 data decides; the hook
   supports both.
3. **When to build:** deploy step only, or also a cached build for test runs
   in CI (needed for `verify`).
4. **Guard granularity:** per method name (now) vs. per (class, method).

## 8. Milestones

- **M0 — Measure.** Profile corpus apps under YJIT (request benchmarks and
  test suites), classify hot frames as specializable-under-boot-facts or not.
  Go/no-go for the performance half.
- **M1 — Vertical slice.** facts → Prism → one simple pass → ISeq →
  injection → real-blog identical under `verify`. Proves the pipeline and the
  guard model, not speed.
- **M2 — Verifier.** Minitest/RSpec reporters, per-test identity, fast-path
  counters, bisection, denylist; three corpus apps identical.
- **M3 — Types and MCP.** Program model with three type sources, MCP server,
  RBS/RBI generation.
- **M4 — Performance passes** in the order M0's data suggests, each with a
  benchmark.
- Later: LSP, Spinel.
