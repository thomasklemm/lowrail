# Proposed sealed enforcement by freezing

2026-10-21. **Design only, pending pricing.** The sealed-tier owner reviewed
this boundary and accepted it without required changes. That is not
implementation, guard-elision or form-integration approval. No new pass,
certificate, runtime flag handling or admission behavior is implemented here.
The existing guarded tier, sealed-v1, form refusal and seal-check ledger remain
unchanged. See [the freeze census](freeze-contract.md) for evidence.

## Seal point and publication

1. The app opts into `LOWRAIL_FREEZE=1` **independently of `LOWRAIL`**. Load
   any required runtime definitions symmetrically; do not install on-only
   ancestor hooks for the freeze seam. Both arms accept identical mutations
   raising and identical `frozen?` observations.
2. `initialize!` returns, including all `after_initialize` callbacks. The
   app completes its own eager load and declared natural request **and job**
   warmup. The first natural certified render runs original; Lowrail does
   not materialize missing schema, routes, view classes or templates to hurry
   admission. No `Seal.activate`, heap scan, autoload resolution or global
   production TracePoint is introduced.
3. At an explicit app-owned readiness barrier, before serving traffic or
   starting job workers, inspect the existing build proof against already
   populated state. Missing prerequisites stay named pending/refused, not
   permission to compile or invoke an app getter. Validate native availability,
   source/JIT compatibility, lexical refinement certificates, certified data
   graphs, and the complete ordinary **and singleton** ancestor closure.
   Test-holder exclusions are not valid production certificates.
4. Preflight the **whole selected union** before changing anything. A known
   missing/unsafe prerequisite refuses enforcement for that set, leaves it
   original/guarded, and reports a terminal reason after a bounded pending
   budget. Do not freeze a subset opportunistically. In particular, check
   the app's explicit acceptance of shared roots such as Object and Kernel.
5. Freeze the union using captured native operations, without an observer.
   Recheck the build facts after freezing, before publishing authorization.
   This catches a write racing the earlier snapshot. Publication is logical
   and atomic; Ruby's individual freezes are **not transactional**. The app
   must quiesce background writers too, not merely stop HTTP admission.
6. Only after successful enforcement and final proof matching may an
   independently eligible unit publish a freeze certificate. Freezing grants
   no eligibility, repairs no source mismatch and does not activate forms.
   Any future guard elision needs a versioned certificate; existing artifacts
   must never be interpreted as carrying one.

## Refusal versus failure

Before the first irreversible data/class freeze, refusal is safe: report it
and keep the existing original path. Attempts are bounded per named pending
reason, never a census repeated on every request. Do not replay an action or
helper that has already partially executed.

After any irreversible freeze, an exception, failed final fact check or loss
of quiescence is a **worker startup failure**: do not mark ready, publish a
partial certificate or claim fallback undoes it. Restart from a fresh process
with the contract disabled or prerequisites repaired. Likewise a live
post-seal violation raises under the accepted contract; it is not rescued as
successful guarded execution. Even unrelated original paths can depend on
Object/Kernel remaining mutable. Unsafe native extensions that bypass Ruby's
freeze semantics are outside the certified subset.

Keep `Native.exact_class?` at every live receiver boundary, including after
callback/helper argument evaluation; keep class-object identity where needed.
Refinements and nested mutable constants/config remain separately certified
or refused. Deep-freezing a data graph is also irreversible: a failed attempt
is not a preflight refusal. Retain all non-method guards and current hook
dependencies until an independently reviewed change removes them.

## Explain, doctor and audit output

Proposed separate fields/reasons (not existing SEAL rules):

| State | Explain/doctor result |
|---|---|
| Pending | `freeze_pending`: missing already-populated prerequisite, selected unit/holder, natural warm step and bounded retry state. |
| Preflight refused | `freeze_contract_refused`: exact missing closure/refinement/data/native/JIT proof; original path retained, no enforcement side effect. |
| Enforced | Contract version, source/JIT identity, selected units, full closure digest, accepted warm steps and observer-free enforcement point; **not** admission by itself. |
| Partial/final-check failure | `freeze_startup_failed`: process not ready, no admitted units; frozen subset and exception retained for diagnosis, restart required. |

Build eligibility, current activation refusal, enforcement status and historical
hits remain separate. Explain never runs a guard, getter or freeze. Doctor's
static memo/load/generator findings are hints; an app-owned production audit
before deployment supplies finite observed violations, not completeness proof.
Require successful request/job outcomes as well as zero FrozenError events.

`Lowrail::Seal.install` remains advisory test/verification observation;
`Seal::EPOCH` and the SEAL001–009 ledger are neither enforcement controls nor
freeze admission proofs. Test doubles keep their existing unoptimized-test
semantics. Freeze audit reports stay separate, include every raised/rescued
FrozenError with a backtrace, and explicitly list test-only exclusions when
used in test mode. No production exclusion may hide a required holder.
