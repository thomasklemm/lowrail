# Working on Lowrail

Read [docs/PLAN.md](docs/PLAN.md) first.

## Invariants

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

## Layout

Rust core in `src/` (Prism via `ruby-prism`, Rubydex as a crate), Ruby runtime
gem in `gem/`.
