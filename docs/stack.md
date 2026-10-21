# Stack bet — admission and interaction ledger

2026-10-21. Exploration on `thomasklemm/stack`; no main/default change.
The bet is that small exact reductions compose even when individual wall-time
effects are below noise. Allocation reduction is admission evidence, not a
latency claim. An instruction increase cannot be hidden by fewer allocations.

## Protocol

Use the shared `script/screen` from `thomasklemm/native-yjit-bench`
(`ff46f99517f6a1fcb9dfc3ab3e132616be100457`), not another request harness.
Every comparison retains all three off-A/on/off-B rounds, a separate counted
probe, raw A/A spread, integer allocation samples, GC counts/time, RSS, boot
and actual YJIT state. Use larger declared warmup/sample counts than the short
defaults; effects inside the A/A band are unresolved, not wins or kills.
Pinned entropy companions are untimed and compare actual status, body and
all-header digests; timed requests retain native entropy. Hardware instruction
counters are unavailable in this orb environment.

Admission needs identical outputs, DB state and own-suite results, named
refusals, and non-increasing deterministic cost on each admitted app. A green
suite with zero fast-path hits does not certify the candidate. Production
sealed units refuse test processes: existing compatibility results do not
close their active own-suite gap. Screens below can therefore remain
**provisional**, even when their deterministic result is favorable. Nothing
here reaches main without the unchanged correctness gates and Thermos.

Build each selection normally with the public CLI and a pass denylist; do
not prune a manifest or remove guards. Measure off/full stack, each component
alone, and full stack minus each component. Define saved objects as off minus
on; a leave-one-out saving is (stack minus component) minus full stack.
Compare that marginal with the standalone saving to classify overlap or
synergy. Do not sum isolated micro results or mix fixtures/modes.

## Candidate inventory

`—` means not measured, never zero. “Pending” is not admission.

| Component | Apps active / eligible | Deterministic delta alone | Delta inside stack | Leave-one-out delta | Status |
|---|---|---|---|---|---|
| Existing sealed form scaffold | Blog show, retained fixture only | — | — | — | Pending local screen; active own-suite gap retained |
| Existing sealed token tag | Blog show, retained fixture only | — | — | — | Pending local screen; live-token continuations retained |
| Existing sealed collection render | Blog show, retained fixture only | — | — | — | Pending local screen; live lookup/events retained |
| Existing sealed AR instantiation | Blog / Campfire r81 / Fizzy / Lobsters: determine natural hits | — | — | — | Pending per-app admission; historical blog instruction loss is not erased |
| Props `frozen_split` (`dd844dd`) | None of these four apps use Inertia | Isolated interpreter micro −0.460571% Ir, not request credit | — | — | Excluded: frozen-holder tier not implemented; do not freeze app holders to admit it |
| B fused views | Blog show/index | +113.14 / +136.20 objects/request in B's screen | B's fused+sealed screen still increases objects | — | Excluded: killed at deterministic cost gate; no integration |
| D freeze method epoch | None | TracePoint +71.326 objects/request; incomplete singleton seal | — | — | Excluded: killed as unsafe; visibility/refinement/suppressed-hook holes |
| E subset callbacks | None admitted | — | — | — | Await exact screened result; census is not a certificate |
| F AR callsite compile | None admitted | Query micros only, not request credit | — | — | Await request screen and active own-suite/DB gates |
| G framework fold | None admitted | — | — | — | Notification/CSP elisions fail exactness witnesses; no candidate delivered |
| H boot image | None admitted | — | — | — | Await successful boot screen and correctness gates |
| Fizzy bench block-link | None | +0.403071% interpreter Ir (`8385e0c`) | — | — | Excluded: deterministic loss and no production admission |

Inventory comes from the bet branches and their full thread histories, not
their titles. New exact screened candidates may replace pending rows; do not
duplicate their implementation work.

## Corpus and retained boundaries

- **Blog:** original retained archive SHA256
  `b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`;
  source `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`;
  lock `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
  Fresh `BlogShowGetOnly` data, not an old job-bearing seed. Initial runtime
  is before the pending `view.send` correction; any such numbers are pre-fix.
- **Campfire r81:** `02023b0f0cafc4d66e06e43be072cf4d6ca328fa`, dependency-only
  Rails 8.1.4 overlay, original `CampfireScenario` fixtures and authentication,
  dedicated disposable Redis. Room STI rows remain original. Queued POST
  delivery is not completion-certified; cold entropy/browser SQL refusals stay.
- **Fizzy:** `6f1d200316ec3bae91d32c557d88647300807ee9`, dependency-only
  overlay, original six-GET fixture/vector. Use `--exploration-only` with an
  independently built public artifact, never the rejected block-link specimen.
  Cache clocks, lazy cached binds and background completion remain boundaries.
- **Lobsters:** ruby/ruby-bench `351a39b77e6c06f4f4fa03148639b10a6bb0c716`,
  canonical dependency wrapper from C; shipped DB SHA256
  `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
  Never schema-load the historical SQLite-incompatible schema. Anonymous
  `/newest`, `/active`, `/recent`, `/hottest` are A's vector, not C's broader one.

## Measurements and pricing decision

Local screens are being prepared. No stack saving, additive interaction,
cross-app win, native latency gain or supported component is claimed yet.
Propose at most **one** whole-stack Callgrind/README price to the coordinator
only after a clear screen (>3× A/A wall noise or solid deterministic reduction)
and the correctness/admission boundaries are resolved. No Callgrind is launched
by this exploration ledger.
