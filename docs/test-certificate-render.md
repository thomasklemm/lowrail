# Verification-only token and collection admission

This is an **isolated review candidate**, not main-integration approval or a
production/speed claim. It extends `sealed-test-v1`; it does not borrow a
production witness or the global Seal epoch. The published AR and eager-loading
records in [test-certificate.md](test-certificate.md) remain historical evidence,
including their explicit token/collection refusals.

## Boundary

The explicit pass allowlist now accepts token/collection only with a version-1
`verification_render` certificate from the test-only builder. A production
`data` certificate cannot substitute for it. Preload is still refused; link and
form retain their existing explicit refusals. Both cross-environment refusal
strings and behavior are unchanged.

Discovery still runs the original suite before inspecting naturally available
holders. Their identities are captured **before** disposable synthetic form
inventory. The stock audit is build-only: runtime admission never calls
Materialize, eager loading, form inventory, Seal installation or Seal activation.
Production render/build/admission/setup files are unchanged relative to the
upstream base, which includes the published token continuation safety fix.

Both units start pending. Actual worker-1/nonforked executor, environment,
config, compiler, JIT, Bootsnap and source-set policy must match before activation.
The first complete original operation supplies its actual context; only then
are method/super-chain/visibility/ancestry and named constant snapshots published,
with active authority published last. A targeted, symmetric return observer
supplies the actual collection renderer, not just the view from the shared tail
seam. A completed operation on a renderer subclass cannot authorize the canonical
renderer. No request, renderer, template, collection or view instance is retained.

## Assumptions and live work

| Unit | Folded assumptions | Kept live / refusal boundary |
|---|---|---|
| Token | Stock effective `token_tag`, `tag`, validation, cached `tag_builder`, `tag_options`/`tag_option`, escaping and primitive method/super chains; visibility/ancestry; exact frozen literal-table/regexp bindings and namespace paths | Protection check, generation, name conversion and autocomplete config run in stock order, once. Explicit tokens, unknown options, foreign views/builders and non-exact String results stay original or use the saved-attribute continuation. |
| Token factory | Only stock or the existing independently compiled source-delivery certificate, with matching actual body and loader-served source | This is not a generic unwrap or link activation. The cached actual builder must be exact and tied to this view, both before and **after** the live prefix. A late foreign builder uses stock `tag` with saved values, never replays `token_tag`. |
| Collection | Stock effective `collection_with_template` body/super chain and lookup ancestry; canonical `ActionView::PartialIteration` binding and absence of lexical/ancestor shadows | Only truthy-template/no-layout branches disappear. Size, iterator/preloading, locals, cache keys, template rendering, result construction, events, callbacks, errors and iteration methods remain live. Constant lookup still precedes the live size callback. Unknown renderer/view holders, missing templates and layouts remain original. |
| Both | Actual native holder primitive and certified sources; runtime/app policy and source membership | Missing/unknown authority refuses. Each unit has its own monotonic verification epoch; a real dependent mutation retires that unit permanently, including after restoration. Unrelated fixture data, subscribers and unknown input holders do not retire an otherwise valid unit. |
| PID/tier | No inherited or cross-tier authority | Child counters start at zero; inherited active/pending handles are revoked and stay original. Tier/opt-in/policy refusal revokes both units. The production Seal epoch is neither borrowed nor reset. |

Named constant observation includes namespace bindings, not just their current
values, and does not autoload unrelated constants. Constant replacement/removal,
method/body/visibility or lookup-chain changes are checked before use and by
passive mutation observation. Restoration cannot clear a retired decision.

## Limits that remain explicit

- The blog's unchanged `test.rb` disables forgery protection. Own-suite token
  hits on the empty branch **do not cover the protected/priced token branch**.
  Separate public contract probes exercise a live protected continuation; they
  are not represented as unchanged-own-suite coverage.
- Link, form and preload remain refused. This is not complete three-render-unit
  own-suite coverage, nor the old 20-unit production domain.
- Only actual worker 1/nonforked execution is certified. Parallel workers and
  production admission remain separate work.
- Default Rake-backed CI invocations still observe `eager_load=false`; the
  documented explicit-path invocation is needed to exercise true eager loading.
- No measurements or cohorts were run and no price is attached to this source.

The public certificate regressions exercise first-original authorization,
foreign-renderer refusal, once-only generation/name conversion, late builder
replacement and restoration, mid-generation method mutation, sticky method/table/
lexical-constant retirement, lookup before a mutating size callback, live iteration,
layout fallback, reentry, errors, live data/subscribers, fork clearing and tier/
opt-in restoration refusal. The prior config/builder/Bootsnap/schema/source-set
and parallel-policy regressions are retained.
