# Bet G: generic render inventory, no literal-options pass

2026-10-22. **Keep the inventory split separately; kill the options prototype.**
Token and collection admission no longer require the blog's models, form,
schema, translations or template. This is a structural improvement, not a
second large optimization. The form generator remains intentionally narrow.
No default-tier change, certificate waiver, new template seam, Ir price or
main promotion is included. The coordinator decides whether to integrate.

The [data export](generic-sealed-data.json) retains all allocation/wall
samples, hit/fallback maps, runtime admissions, response/holder fingerprints,
build ledger and raw-result hashes. Cookies, bodies, credentials and DBs stay
private. Final isolated arms and rejected prototype arms are labeled separately.

## What actually refused

All four non-blog apps initially stop at the shared
`FormScaffoldInventory.check`: `eager-loaded targets required; keep lazy
applications original`. That wording conflates absent blog constants with
lazy loading. Lobsters has Comment but no Article/ArticlesController; Fizzy,
Campfire and CASA do not supply the blog trio. It is not evidence that these
production apps failed to eager-load.

| Unit / fact | Blog-specific inventory previously inherited | Required by the emitted work? / disposition |
|---|---|---|
| Form | `app/views/articles/show.html.erb`; one exact `form_with model: [@article, Comment.new]` block; commenter/body fields, Add Comment, exact class/rows options | **Yes for this generator.** Other templates/fields/builders are not supported merely by renaming its constants. Keep refusal. |
| Form constructor/schema | Stock Comment constructor, no initialize callbacks, nil commenter/body defaults, String/Text types, Article/Comment naming and polymorphic mappings | **Yes for its fused constructor/form.** Remain checked; not generalizable by deleting facts. |
| Form config/I18n | Stock FormBuilder; IDs on, local forms, no UTF8/exfiltration prefix, disable-with on; English labels, literal translation trees, Simple backend, no URL defaults | **Yes for its baked labels/config.** Remain checked. No claim of generic form lowering. |
| Token | All the above, ArticlesController's view class, and unrelated actionpack/AR/AM/I18n source inventories | **No.** Live token generation, masking, forgery helper, name conversion and configuration stay live. Derive effective token/tag/tag_builder facts for each loaded named controller; pin only dependencies consumed by the residue. |
| Collection | All the above, including the one ArticlesController view class | **No.** The view is opaque and is forwarded unchanged to live Template#render. Certify stock collection method/renderer and retain iterator, preloading, cache/local effects, events and returned objects. |
| Link/delivery | Separate blog-named controller/site assumptions; one literal class key; old template prepend | **Still refused/quarantined.** The unsafe template delivery is not re-enabled by this change. |

After removing the constant-name obstruction, Fizzy also exposed the false
`non-stock i18n source inventory` refusal: its I18n **1.14.6** differs from
the blog's **1.15.2** pin. Neither render unit folds translations. Token now
audits ActionView/ActiveSupport, collection ActionView, using the same
independently audited stock hashes and effective-body checks. Form still
audits its complete dependency set. Sources, lock and app class remain pinned.

The v2 token certificate records stock definitions and visibility per loaded
named controller. Runtime reads only already-cached `@view_context_class`
values after the first natural original operation; it constructs no view or
template and creates no receiver singleton class. Unknown later view classes
fall back. V1 verification certificates remain accepted under their original
scope. Collection v2 drops no live view send: it never interpreted the view.

## Isolated token/collection arm: saving, neutral or cost?

Production Ruby **4.0.7**, Rails **8.1.4**, interpreter. Each seed uses serial
off-A/off-B/on processes, three exact-response requests per route, then 100
warmups and 100 allocation samples per route. Fizzy uses its existing natural
login and six-GET fixture. Campfire uses its existing 133-message fixture and
natural login. CASA uses schema-only disposable PostgreSQL and the genuine
anonymous sign-in page, not an authenticated case-management workload.
Allocation windows retain real entropy/clocks; wall samples are informational.
These are screens with observer overhead, **not** clean no-Lowrail prices.

The table uses the worker's upper-middle sample, consistently across arms.

| App / GET | Seed 0: off-A / off-B / on | Seed 1: off-A / off-B / on | Interpretation |
|---|---:|---:|---|
| Fizzy buckets | 9070 / 9070 / 9066 | 9069 / 9069 / 9066 | Small allocation saving |
| Fizzy filtered bubbles | 22396 / 22396 / 22394 | 22398 / 22398 / 22393 | Small allocation saving |
| Fizzy account users | 5682 / 5683 / 5675 | 5684 / 5685 / 5674 | Small allocation saving |
| Fizzy workflows | 3869 / 3867 / 3869 | 3869 / 3870 / 3870 | Neutral within A/A variation |
| Fizzy notifications | 3866 / 3866 / 3864 | 3867 / 3867 / 3864 | Small allocation saving |
| Fizzy bubble show | 18364 / 18364 / 18343 | 18365 / 18364 / 18344 | Largest non-blog saving: about 21 objects (0.11%) |
| Campfire room | 15487 / 15490 / 15489 | 15488 / 15489 / 15489 | Neutral |
| CASA `/users/sign_in` | 2345 / 2345 / 2345 | 2345 / 2345 / 2345 | Neutral |
| **Blog `/articles/1`, form + token + collection** | **2647 / 2647 / 2270** | **2647 / 2647 / 2271** | **Existing ≈377-object saving retained; options absent** |

The blog means are 2646.84 / 2646.96 / 2269.95 and
2647.23 / 2647.12 / 2270.86: reductions **376.95** and **376.32** against the
mean of off controls. We retain the one-object second-seed median variation;
we do not substitute a rerun or claim a new instruction-price confirmation.

| Arm, each seed | Token hits / collection hits | Other hits / admission |
|---|---:|---|
| Fizzy, entire worker (login + companions + warmups + samples) | 4066 / 1423 | Both active, one passive witness each; zero recorded fallbacks |
| Campfire room worker | 524 / 0 | Both active; collection witnessed cold, then bypassed by warm fragment cache; zero recorded fallbacks |
| CASA sign-in worker | 202 / 0 | Token active; collection pending, zero attempts: no natural collection call |
| Blog show worker | 811 / 202 | Form 202 hits; all three active; zero recorded fallbacks |

Hits include warmup/companions and are not per-request rates. Token admission
can hit the unprotected/empty branch without eliminating allocations; a hit
alone therefore does not explain or establish a saving. Collection
only deletes nonnil-template/no-layout branches, retaining the same allocating
loop; its admission is not partial-render elimination.

All final isolated workers have equal literal status/body digest/**all
headers** at both seeds, with empty entropy-error lists. The captured named
modules/classes, existing singleton holders and cached view classes compare
equal before/after off-A/off-B/on, including Module's hooks and method
owner/name/parameters/visibility. Campfire's raw post-request method names
also differ in **A/A** solely in an ActionText compiled-template hash suffix;
the export preserves raw fingerprints and the explicitly template-ID-normalized
comparison. It preserves method multiplicity, not a lossy name-keyed map.
This is finite metadata evidence, not equivalence for arbitrary introspection.

### Campfire's generated template IDs differ without Lowrail

In seed 0 **off-A versus off-B**, every before-request holder matches. After
the requests, the only differing holder is
`ActionView::LookupContext::DetailsKey.@view_context_class`. Exactly one
method's name and original name differ; the shared prefix is
`__home_user__local_share_mise_installs_ruby_______lib_ruby_gems_______gems_actiontext_______app_views_action_text_contents__content_html_erb`.

| Off arm | Raw suffix | Owner / visibility / parameters |
|---|---|---|
| off-A | `___4506467662812209713_20472` | anonymous / public / required `local_assigns`, required `output_buffer`, block `_` |
| off-B | `___2455740143569929097_20472` | anonymous / public / required `local_assigns`, required `output_buffer`, block `_` |

Both holders have identical ancestry and method multiplicities. Their raw
post-request metadata hashes are
`cf4950b21be295a7d2404d4fab43dde44456f4394fbbfcc81336fa1740e02f4e`
and `7802eb3ab8ec91405adf44d21c7dcfe57f4745f342c4fa9845d374c9c0e7bd0f`.
Normalizing only the generated numeric suffix in the name/original name gives
`d5c29862b5d04270828027931fd512fec3f2a17e20e9af8833639611b677a74f`
for all six off-A/off-B/on snapshots (both seeds), each with **7,315 holders**.
The export retains both raw and normalized hashes. This is a demonstrated
off/off generated-ID difference, not permission to remove an on-only method,
owner, ancestor or duplicate from the comparison.

The first CASA diagnostic had equal responses but **rejected entropy
coverage**: a Bugsnag 6.30.0 internal session UUID was undeclared and the
request count incorrectly included login. It remains in the export as
`casa-isolated-screen`, not credited. Source audit identified exactly
`Bugsnag::SessionTracker#start_session`; the final companion adds its own
source-pinned stream and declares three GETs. No runtime behavior/configuration
or certificate changed. The final data are `casa-isolated-screen2`.

## Ranked exposure: do not confuse inclusive pools with savings

1. **Existing blog form fusion: ≈377 saved objects/request**, preserved above.
   This is the only large achieved saving here; another app's form cannot use
   that budget without its own constructor, builder, label/config and site plan.
2. **Literal tag/option intermediates: large gross pools, no accepted new
   saving.** The independently published
   [bet D census](https://github.com/thomasklemm/lowrail/blob/22c7891ed8f518458673b5d9eef9dee26c0921fe/docs/default-tier-census.md)
   finds tag-option Strings 95 / 240 / 370 / 381 per request on its blog /
   Fizzy-buckets / Lobsters-front / Campfire-login fixtures, and option-output
   Strings 36 / 97 / 114 / 170. Those are **different fixtures**, overlap live
   output/escaping work and are not all literal or removable. CASA's analogous
   allocation pool was not profiled; its 76 static forms are not an object budget.
3. **New generic token admission: 0–≈21 observed objects/request saved** in
   this six-route Fizzy screen; neutral Campfire/CASA. It is not the hundreds
   of objects of whole-form fusion.
4. **Collection: zero demonstrated removable objects.**
   [Bet L](https://github.com/thomasklemm/lowrail/blob/59211cadf4e6d8ead1c7fa4462e947ccf5765e56/docs/lobsters-sealed.md)
   measures Lobsters front collection **72% inclusive allocations** but only
   **27 self objects/request**, all retained by this branch-deletion variant.
   Its already generic collection extension is allocation-neutral. Lobsters
   anonymous front/story have **zero form/token calls**; those refusals lock
   away zero work on those routes, not an unknown giant form saving.

No sums or exact removable credit are inferred from overlapping gross pools.
Campfire room versus login and Fizzy rich vector versus one-bucket discovery
must not be compared as if they were the same request. The new warm-room and
sign-in neutral measurements are the relevant acceptance evidence here.

## Why the literal-options experiment was killed

The removed prototype considered bare link_to/content_tag calls with literal
String-valued scalar options, preserving live argument evaluation and URL
generation, then emitting literal attribute fragments inside a specialized
helper. It found 9 syntax sites on blog, 13 on Lobsters and 3 on Fizzy;
Campfire's handler-code grammar was unsupported by the pinned parser.
Other helpers, blocks, dynamic/nested data/aria, method/remote/href and
non-String option values remained named refusals, not silently generalized.

It was not a profitable general sealed pass. Lobsters regressed
14293 / 14293 → 14547 on `/` (seed 1 on 14546), story
3688 / 3688 → 3711. The combined Fizzy arm's account-users page regressed
5683 / 5682 → 5705 even though other routes saved small amounts. Campfire
was neutral. Blog 2647 / 2647 → 2668 was **not a preservation screen**:
its form correctly refused the changed compiler. The isolated rerun above,
not this invalid combined stack, establishes preservation.

The tested cold Loader edit inside Template#compiled_source kept its original
owner/name/parameters and original-body fallback; it was not a template
prepend. However the delivery/compiler certificates were not compositional
with the existing form. Earlier holder snapshots also did not retain all
generated-method multiplicities. Equal responses and selected ancestry are
not grounds to weaken either certificate. **Remove the prototype, registration,
Loader edits and seam; do not ship or price it.** Bet D built no competing
seam and ended as a census kill. No new seam remains in this branch.

## Pins, reproduction and limits

Base runtime:
[f257ddd](https://github.com/thomasklemm/lowrail/commit/f257ddd1d35284b1da4daad201852ab8cc2ee32e).
Apps: retained `script/corpus real-blog-r4` recipe;
[Fizzy 6f1d200](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9),
[Campfire 02023b0](https://github.com/basecamp/once-campfire/commit/02023b0f0cafc4d66e06e43be072cf4d6ca328fa),
[CASA b584d2e](https://github.com/rubyforgood/casa/commit/b584d2e6e6ebffe382f34c2ec202d20384d035ca),
[ruby-bench 351a39b](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716).
Only existing dependency overlays are used. No app source/config patches,
upstream offers or Lobsters generated code are included. All Lowrail artifacts
use the **existing private external-output build protocol** outside app trees;
no output-directory CLI feature was added. Lobsters wrapper/lock/entropy files
are byte-identical copies of bet L's already published dependencies in Lowrail.
Runtime cache/log/DB writes are ordinary disposable workload output.

The [driver](../bench/experiments/generic_sealed.rb) exposes
`build APP NEW_EXTERNAL_ARTIFACT [token,collection]` and
`screen KIND APP STATE ARTIFACT NEW_OUTPUT` through Ruby 4.0.7. Build with the
same per-app environment returned by `GenericSealed.environment`; the existing
Fizzy/Campfire fixture preparers supply external state, and
`fixtures/corpus/blog_show_get_only.rb` supplies the blog seed. Blog selects
`form,token,collection`. CASA's `prepare-casa` requires the dedicated empty
local `lowrail_corpus_casa_g` database on port 55432 and external credential
state; precompile its unchanged assets with Ruby 4.0.7 / Node 24 first.
Set `G_CASA_STATE` to that external state for the builder preload. Workers
receive the copied external credentials automatically. No deployed credentials,
jobs, authentication bypass, user data or seed-task changes are involved.
Campfire's upstream Redis URL requires its dedicated disposable localhost
Redis; the driver clears only that server between workers.

`report PRIVATE_RUN_ROOT NEW_JSON` exports the labeled evidence without
cookies/bodies/DBs. Raw unsuccessful boot/fixture iterations remain private;
the rejected CASA companion and rejected options measurements remain explicit
in the export. No instruction cohort was run, no retry/exclusion could make
an Ir gate green, and Lobsters cache-TTL noise was never used for a price.
These request companions are **not** a new whole-app `lowrail verify` support
claim. No non-blog support or request-speed claim is promoted from these screens.

## Review and local gates

The inventory is a separate
[commit](https://github.com/thomasklemm/lowrail/commit/7dc57b53ae4db8108ffb665c80b76258f1e87b17),
rebased onto
[e05238f](https://github.com/thomasklemm/lowrail/commit/e05238f2cdb45ea6b419966427e4dd20b6cd5a7d),
which includes the mandatory six-suite bench gate. The allocation screens
precede review-only changes to the build audit's cache/root scope and the
shared passive-admission body validator. No emitted or per-request fast-path
body changed; those rows are not represented as a rerun on the published SHA.

The strengthened public non-blog regression passes **1 test / 24 assertions**:
stock and custom-helper controllers coexist, output/escaping stay live, and
collection still hits when a global token override refuses the token unit.
`mise exec ruby@4.0.7 -- cargo test --locked` on the rebased inventory passes
**51 tests** (41 unit + 2 types integration + 8 verify), no failures.
Re-exporting the private raw screens reproduces the published JSON byte for
byte; all four final isolated arms pass both seeds' response, entropy and
recorded full-holder/ancestry comparisons under the stated template-ID rule.

The complete primary gem suite, from `gem/`, runs without test filters:

```sh
LOWRAIL_STRICT_GATES=1 mise exec ruby@4.0.7 -- rake test TESTOPTS='--verbose --seed=1729'
```

It exits 0 in 2,254.43 seconds: **194 tests / 6,956 assertions / 0 failures /
0 errors / 3 named skips**. The skipped optional integrations are not coverage:

- `MaterializeCorpusTest#test_campfire`: `.corpus/campfire` is absent; the
  separate `campfire-r81` workload is not that fixture.
- `RailsSuiteReportTest#test_profiling_preserves_backtrace_cleaner_results`:
  the external Rails v8.1.4 bundle is not prepared.
- `RailsSuiteReportTest#test_separate_build_does_not_change_view_primary_key_results`:
  the external Rails v8.1.4 checkout is not prepared.

An earlier non-strict full run passed 194 tests / 3,624 assertions with 20
named prerequisite skips. Missing primary gems and `real-blog` were then
prepared; the strict result above supersedes that partial-coverage result.
Ruby 4.1 and the optional external Rails-suite integrations were not run.

Thermos ran independent correctness/security and maintainability reviews on
that inventory commit. Maintainability approved after the shared validator,
per-audit cache/root reset and mixed-controller regression. The correctness
review's one proposed source-pin leak was **retracted**, not waived: builders
finish synchronously; the form's full six-gem audit and all its `stock_fact`
calls finish before token/collection; a narrowed root rejects excluded paths.
An isolated negative control confirms that collection's audit rejects an AR
method, a fresh full audit restores its stock fact, and a modified copied AR
source tree is refused as `non-stock activerecord source inventory`. The
copy is temporary, outside app trees, and removed. No confirmed correctness
or maintainability blocker remains; static review is not runtime coverage.

All six top-level `bench/*_test.rb` suites run in separate processes with
`LOWRAIL_STRICT_GATES=1 mise exec ruby@4.0.7 -- ruby "$test" --verbose --seed=1729`.
Valgrind and its headers are present; no counter-boundary test is skipped.

| Suite | Tests | Assertions | Failures / errors / skips |
|---|---:|---:|---|
| ar_diagnostics | 2 | 16 | 0 / 0 / 0 |
| callback_survey | 1 | 10 | 0 / 0 / 0 |
| pass | 17 | 243 | 0 / 0 / 0 |
| profile_summary | 1 | 9 | 0 / 0 / 0 |
| rails_drift | 1 | 11 | 0 / 0 / 0 |
| request_pairs | 17 | 312 | 0 / 0 / 0 |
| **Total** | **39** | **601** | **0 / 0 / 0** |

These exercise synthetic harness/counter boundaries, not a new app Ir cohort.
