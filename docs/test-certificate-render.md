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

## Own-suite evidence

The default 12-arm matrix and a separate explicit-path 12-arm matrix use
off/on-cold/on-warm, CI unset/1, ordinary/system suites, seed 41231 and actual
worker 1. All **24 exits are zero**, with identical 21 ordinary or 2 system
test identities/outcomes. Every unit, zero, refusal, branch count and naturally
loaded model is retained in [test-certificate-render-results.json](test-certificate-render-results.json).

On-cold and on-warm counters agree in both CI modes unless noted:

| Unit | Ordinary H/F/D | System H/F/D |
|---|---|---|
| Article instantiate | 30/1/0 | 18/1/0 |
| Comment instantiate | 9/1/0 | 8/1/0 |
| Link (refused) | 0/23/0 | 0/43/0 |
| Form (refused) | 0/1/0 | 0/6/0 |
| Token | 11/3/0; **13/1/0 in explicit-path CI=1** | 27/1/0 |
| Collection | 1/1/0 | 4/6/0 |

All off counters are zero. Link/form retain respectively
`verification_literal_table_observer_unavailable` and
`verification_form_config_schema_translation_observer_unavailable`. Preload
has no test unit and its build-only refusal remains in the artifact ledger.
Collection fallbacks are retained, not reported as complete branch coverage.

The token branches are original-empty 3 / fast-empty 11 in ordinary lazy
execution, or 1 / 13 in true-eager execution, and 1 / 27 in system execution.
Off sees 14 original-empty calls ordinary or 28 system. **Original generation,
original tag, protected fast path and continuation fallback are zero in every
own-suite arm**. Thus the extra token hits certify only the empty-token branch.
Original branch counters are targeted stock-body line observations, not proof
that every expression on an observed line executed.

Default Rake-backed CI still observes eager_load=false. Explicit-path CI=1
observes true and naturally exposes 31 named AR subclasses instead of 3.
Only Article and Comment have schema/attribute generation in these inventories;
the additional framework holders have neither, and gain no AR test authority.
The naturally available eager context permits earlier token authorization,
not extra protected-token coverage. App configuration and tests are unchanged.

## Retained failures and diagnosis

The first expanded-admission matrix is a **rejected** record: all four on-system
arms failed while off and ordinary arms passed. A fixed three-arm isolation
then passed with AR only and failed with token-only and collection-only
admission. The expanded mutation observer was scanning every watched Module
for ordinary live array/hash/string writes, though those objects cannot be
its method/constant lookup destinations. The correction skips non-Module
receivers after the separate app-config check; no watched holder, assumption,
source check, timeout or test is removed. Both complete corrected matrices
above pass. The rejected matrix and isolation outcomes remain in the results
JSON. This does **not** establish a cause for the earlier historical warm-link
timeout, whose separate six-run diagnosis remains unestablished under concurrent
load, not disproved; those records were
[published separately](https://github.com/thomasklemm/lowrail/commit/ccea6df6addc6958b6dbdadccc5e6c6f11727032).

An earlier affected-gem run also retained 50 tests / 905 assertions with one
production cold-gate failure and four missing-loader-prerequisite skips. Its
regenerated app source pin differed from the unchanged production companion
pin. The retained source archive from the sealed owner validates against the
published pin `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`;
the strict rerun selects that disposable corpus and installs the missing
require-hooks/freezolite prerequisites. No pin or comparator is relaxed.
An unchanged-test diagnostic reproduction retained the failing worker's exact
`app source pin mismatch` error before on execution.

## Final checks

- `cargo test --locked`: 39 unit, 2 types/MCP and 8 verifier tests pass. The
  real-blog types/MCP corpus test and its `rbs -I OUT validate` run were also
  exercised with the retained fixture's test database prepared. The first
  optional attempt on its source-only extraction failed with no model facts;
  public `db:test:prepare` and fresh facts supplied that missing prerequisite,
  without changing source or the production source pin.
- Strict affected gem checks: **50 tests / 1626 assertions**, no failures,
  errors or skips, including all four formerly missing loader prerequisites,
  both public production render regressions and all nine certificate tests.
- `lowrail verify APP -- ruby bin/rails test test/controllers test/models
  --seed 41231`, with the explicit-path CI=1 certificate: **21 identical per-test
  outcomes, 53 hits across four units** (30/9/13/1); all six fallbacks/refusals
  remain reported. SQL tracing was explicitly disabled in this invocation;
  there is no SQL-equivalence claim from it.
- A disposable public-operation probe replaces the native actual-holder
  predicate before the first original request. The replacement is **never
  invoked** (0 calls), both requests return 200, both render units refuse with
  zero hits, and restoring the primitive cannot revive them. The temporary
  probe passes 1 test / 8 assertions; it is validation, not a kept extra suite.

All checked runtime/build/test source digests and validation log hashes are
recorded with the matrices. The branch remains isolated and unpublished pending
the sealed owner's review and a separate main-integration decision. No
Prism.find adoption is included.
