# Lowrail

Lowrail lowers what it can of a Rails application into specialized Ruby and
leaves everything else alone. The real Rails and every gem keep running;
specialized methods are delivered as MRI instruction sequences at boot and
guarded by the boot facts they assume, falling back to the original code the
moment a fact stops holding.

Inspired by [Roundhouse](https://github.com/rubys/roundhouse). Status: planning
and first vertical slice. See [docs/PLAN.md](docs/PLAN.md).

## Goals

- Every Rails app with every gem boots and runs with Lowrail installed.
- The app's test suite gives identical per-test results with `LOWRAIL=1` and
  `LOWRAIL=0`, checked by `lowrail verify`.
- One precise type model from static analysis (Prism, Rubydex), a real boot,
  and observed types, exposed through an MCP server and RBS/RBI generation.
