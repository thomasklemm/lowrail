# Lowrail

Lowrail lowers what it can of a Rails application into specialized Ruby and
leaves everything else alone. The real Rails and every gem keep running;
specialized methods are delivered as MRI instruction sequences at boot and
guarded by the boot facts they assume, falling back to the original code the
moment a fact stops holding.

Inspired by [Roundhouse](https://github.com/rubys/roundhouse). Status: planning
and first vertical slice. See [docs/PLAN.md](docs/PLAN.md) and, for how a
pass plugs in, [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Goals

- Every Rails app with every gem boots and runs with Lowrail installed.
- The app's test suite gives identical per-test results with `LOWRAIL=1` and
  `LOWRAIL=0`, checked by `lowrail verify`.
- One precise type model from static analysis (Prism, Rubydex), a real boot,
  and observed types, exposed through an MCP server and RBS/RBI generation.

## Complementary optimizations

Lowrail only applies changes it can guard exactly. Some well-known speedups
change observable behavior, so they stay the app's own decision. Lowrail
works next to them and does not turn them on:

- **YJIT** (`RUBY_YJIT_ENABLE=1` or `RubyVM::YJIT.enable`): recommended in
  production. Lowrail's guards and lowered methods are written for it.
- **Bootsnap**: works in any load order; Bootsnap caches the original
  bytecode, Lowrail serves its lowered bytecode.
- **Frozen string literals** (`# frozen_string_literal: true` or
  [Freezolite](https://github.com/ruby-next/freezolite)): fewer string
  allocations, but mutating a literal then raises `FrozenError`. Enable it
  only after your suite passes with it; Ruby 3.4+'s
  `-W:deprecated` warns on mutation of chilled literals. Lowrail compiles
  each file with the same options the app's loaders use, see
  [docs/loaders.md](docs/loaders.md).
