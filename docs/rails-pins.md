# Audited Rails releases

The sealed and render passes certify stock Rails source. Which releases they accept is one reviewed table,
`Lowrail::RailsPins::RELEASES` (`gem/lib/lowrail/rails_pins.rb`). Any release not in it refuses at build and at
runtime (invariant 1), so a new security release is a safe no-op until someone adds it. Artifacts record the release
they were built on, and every unit refuses in a process on another release, including cached render and form
certificates (`Rails release changed; rebuild`) and endpoint units (silently kept original).

## The table

Each release row has:

- `files`: SHA-256 of each Rails source file whose method bodies a pass folds (`SealedBuild#stock?`).
- `gems`: the whole-`lib/` inventory hash per gem (`FormScaffoldInventory.source_inventory`); i18n is not part of
  Rails and stays a single pin (`FormScaffoldInventory::I18N`).

The six exact-version gates (endpoint build and runtime, sealed link build and runtime, form scaffold, render units)
all ask `RailsPins.release`. The test-certificate render goes through the form inventory. AR instantiate, AR plans,
preload and memo don't use the table: they audit or record their own sources.

Outside the gem, the same releases key:

- `fixtures/corpus/blog-entropy-controls.json` `rails`: per release, the retained blog's lock hash and the Rails
  runtime sources the entropy companions pin. `real-blog-r4` keeps one source tree; a release other than 8.1.4 swaps
  in its audited lock (`fixtures/corpus/real-blog-r4-rails-VERSION.Gemfile.lock`).
- `script/gate-gems` and `script/corpus` take `LOWRAIL_RAILS` (default 8.1.4). A gem home holds exactly one Rails,
  because unbundled fixtures load the newest installed one; `gate-gems` aborts otherwise.
- `script/gate` prepares one home and one corpus per release (`.lowrail/gate-gems/…-rails-VERSION`,
  `.corpus/rails-VERSION/`) and runs the gem suite in each. CI runs a matrix job per release.

## Adding a release

The table centralizes the pins, not the release work. A release needs its row and all of the following:

1. Install it into a fresh home: `LOWRAIL_RAILS=X script/gate-gems` with that `GEM_HOME`.
2. Hash the files and inventories (the algorithm in `source_inventory`), and diff every pinned file and gem against
   the previous release.
3. Re-audit every certified method in a changed file, and the callees it newly reaches; add those callees to each
   pass's primitive closure. Record the audit below.
4. Add the row, the entropy row (`bundle lock --update rails --conservative` on the retained blog; re-pin changed
   runtime sources after checking their declared random sites), the matrix entry, and `lowrail verify` evidence.

## 8.1.4.1 audit (2026-11-18)

Diff: [rails-8.1.4.1.md](rails-8.1.4.1.md). Of the pinned files only `action_view/helpers/tag_helper.rb` changed, and
in it only `TagBuilder#tag_options`.

**`TagBuilder#tag_options`.** For every key (and nested `data`/`aria` key) 8.1.4.1 computes
`name = Symbol === key ? key.name : key.to_s`, skips it when `name.blank?`, and passes `name` instead of `key` to
`tag_option`, `prefix_tag_option` and `boolean_tag_option`. `TAG_TYPES` is still looked up by the original key.

- For a String key, `to_s` returns the key itself. For a Symbol key, `Symbol#name` is the text `to_s` and
  interpolation produced before. The callees are unchanged and treat both alike: `xml_name_escape` starts with
  `name.to_s`, the `"class"` check uses `key.to_s`, and the rest interpolate. So output is identical for every
  key whose name is not blank.
- Output differs only for a key that is not `blank?` but whose name is, such as `:" "`: 8.1.4 emitted `="s"`,
  8.1.4.1 drops it (the security fix). Keys of other classes now have `to_s` called once more; no certified site
  passes one.
- Probe on both releases (token attributes, `class` array, `data`/`aria` hashes, boolean attributes, unsafe names,
  blank names): byte-identical output except the blank-name case.
- New callees: `Symbol.===` (Module#===) and `Symbol#name`, both native. They are added to the primitive closure of
  the sealed link, token render, test-certificate render and form inventory, so a redefinition refuses.

Verdict: the certified link, token and form sites only use literal String and Symbol keys, so the folded output is
unchanged on 8.1.4.1. Other 8.1.4.1 changes (`_set_vary_header`, `strip_tags`, `safe_constantize`, cookies and
session stores) are outside every certified method and stay live.

The entropy companions pin two changed runtime sources, `session/abstract_store.rb` (a default `same_site` proc) and
`cookies.rb` (upgraded-cookie tracking). Their declared random sites, `generate_sid` and the cookie cipher IV, are
unchanged; both files are re-pinned for 8.1.4.1.

## Verify evidence (2026-11-18)

The retained blog per release (`.corpus/real-blog-r4` and `.corpus/rails-8.1.4.1/real-blog-r4`, the same source with
each release's lock), verification tier (`lowrail build --sealed --verify-test --env test --jit interpreter`, worker 1,
CI=1, SQL trace off), then `lowrail verify APP -- ruby bin/rails test --seed 41231`:

| Release | Outcomes | Units built | Hits (Article / Comment / token / collection) | Refused at activation |
|---|---|---|---|---|
| 8.1.4 | 21 of 21 identical | 5 | 30 / 9 / 11 / 1 = 51 | form (`verification_form_config_schema_translation_observer_unavailable`) |
| 8.1.4.1 | 21 of 21 identical | 5 | 30 / 9 / 11 / 1 = 51 | form (same) |
| 8.1.4.1 without its table row (control) | 21 of 21 identical | 2 (AR only) | 30 / 9 / – / – = 39 | – |

Supported on 8.1.4.1 under invariant 3 are therefore only these verification-tier units on the retained blog:
Article and Comment instantiate, token (its 11 hits take the empty/unprotected branch) and collection. Link has no
verification-tier unit on either release (build refusal `verification_literal_table_observer_unavailable`), and form
refuses at activation by design ([test-certificate-render.md](test-certificate-render.md)). No link, form or endpoint
support is claimed on 8.1.4.1: SealedLinkTest asserts quarantine, no link unit and zero hits, and form's isolated
production regression hits do not replace `lowrail verify`. The suite passing in the 8.1.4.1 home shows only that
those paths stay correct there.

### Release binding (fix round, 2026-11-18)

Before this fix the render certificates (`render_units_build.rb`, `test_certificate_render_build.rb`) and the form
inventory did not record the build's Rails release, so an artifact built on 8.1.4.1 still admitted token and
collection in a process reporting another release. Reproducer: an ordinary 8.1.4.1 verification artifact, verified
with `RUBYOPT` preloading `bundler/setup`, `rails` and `Rails.define_singleton_method(:version) { "8.1.4.2" }`.

| Code | Outcomes | Hits (Article / Comment / token / collection) | Activation refusals |
|---|---|---|---|
| 33f044c2 | 21 of 21 identical | 0 / 0 / 11 / 1 = 12 | form |
| with the binding | 21 of 21 identical | 0 / 0 / 0 / 0 | form; token and collection `verification_render_Rails_release_changed;_rebuild` |

AR already compared its recorded release and took no hits in either run.

Each certificate now stores `rails_version` and its admission compares it with `Rails.version`, as AR does. The public
regressions `TestCertificateTest#test_render_missing_or_mismatched_view_context_certificate_stays_original` (mode
`release`) and `FormScaffoldTest#test_render_units_without_blog_models_templates_or_form_inventory` (production token
and collection under a redefined release) fail on 33f044c2 and pass on both homes. An ordinary 8.1.4.1 verify after
the fix still records 51 hits (30 / 9 / 11 / 1).

The endpoint prototype had the same gap between two allowed releases: built on 8.1.4.1 and run as 8.1.4, both
actions activated (b96620b3 review). Its units now store `rails_version` too, and `Endpoint.activate` drops units whose
release differs or is missing. `EndpointTest` mode `release` builds on one allowed release and runs as the other; on
b96620b3 it takes 2 hits in both homes, with the fix 0 hits and the original responses.

## Confirm review (2026-11-18)

Reviewer: **thermos-sol**, both correctness/security and maintainability rubrics, applied directly without other
reviewers. Commit: `33f044c2744e5d1911c0f0866c6b60e78265e74a`; context: `daf40fd7`, `b1769608`, `db0ca737`.
**Verdict: not confirmed as written.** Current-release equivalence is reproduced; two claims need correction.
No gem code was changed by this review.

**Must-fixes:**

1. **Correct the support claim above.** `SealedLinkTest` explicitly requires no link unit and zero hits because
   delivery remains quarantined. Invariant 3 permits the retained blog's verification-only Article/Comment
   instantiate, token and collection claims, not link, form or endpoint support. Token's 11 hits exercise the
   empty/unprotected branch. Form's isolated production regression hits do not substitute for `lowrail verify`.
2. **Bind cached render authority to its audited release before promising unconditional runtime refusal.** Preload
   `bundler/setup`, `rails`, then `Rails.define_singleton_method(:version) { "8.1.4.2" }` before verifying an ordinary
   8.1.4.1 artifact. With files/lock unchanged, token/collection still take **11/1 hits**; AR refuses. The render
   certificates (`render_units_build.rb`, `test_certificate_render_build.rb`) and admissions omit the build's Rails
   version; form has the same omission. This is a **pre-existing gap**, not an introduced HTML divergence or an
   actual future-gem test. Add recorded-release admission and cached-artifact negative tests. Conventional upgrades
   also encounter source-path/body checks, which passed the controls below.

**Executed evidence.** Ruby 4.0.7, interpreter, `ruby -S rake test TESTOPTS='--verbose --seed=1729'`, strict gates:

- 8.1.4: 226 tests, 7324 assertions, four failures, no errors, one missing-Campfire skip. The setup-created
  `real-blog` locks 8.1.4.1; the three facts cases and E2E case fail against the isolated 8.1.4 home. All four
  pass against a disposable copy locally re-locked to 8.1.4 (35 assertions, no skips). Original corpus preserved.
- 8.1.4.1: 224 tests, 7341 assertions, no failures or errors, one missing-Campfire skip; the two Rails-checkout
  cases are excluded as in `script/gate`. Neither local run is an unqualified full-gate pass.

Both releases independently reproduced `lowrail verify`: 21 identical outcomes, 51 hits (30/9/11/1), form refused.
Runtime set `RAILS_ENV=test LOWRAIL_SEALED=1 LOWRAIL_VERIFY_TEST=1 PARALLEL_WORKERS=1 CI=1`, SQL trace off, and
`LOWRAIL_DIR` to the verification artifact. `cargo build --locked`, GateTest and the entropy source/lock regression
passed. Exact-head CI 44311944289 passed 209 tests per release; corpus exclusions are not integration coverage.

Positive file/inventory pins passed in both homes. Cross-release labels and patched files with unchanged version
strings refused; a future label refused all changed build gates and endpoint/sealed activation. A mixed home made
`gate-gems` exit 1. An 8.1.4 lock with loaded 8.1.4.1 sources refused entropy controls; an altered cached-artifact
lock preserved 21 outcomes with zero hits. Requiring `rails_pins` alone loaded only that file, not Rails or hooks.

**Re-audit and design.** Stock nonblank String/Symbol keys produced identical HTML; top-level and nested blank
Symbol names differed as documented. Folded link keys are literal and the converted hash is rechecked; token
constructs fixed keys and rechecks epoch/holders after live generation/conversion; form accepts the fixed scaffold.
Dynamic values are not keys. Both Symbol calls join all four closures. Entropy random sites are unchanged.

Surviving guards have concrete roles: release allow-list (unaudited code), source/body pins and inventories
(patches/transitive changes), Symbol primitives (new folded dispatch), source/lock/entropy checks (stale specimens),
and one-release homes (unbundled activation); existing Ruby/environment/native/lazy boundaries remain necessary.
The independent-pin and checkout-exclusion comments explain why; shorten/remove the new table header and
environment/matrix labels under DECISIONS' one-line/why rule. No structural maintainability blocker was found.
The table centralizes pins, not release work: a lock, entropy row, CI entry, closure audit and fresh verification
remain necessary. Setup refused the mixed primary home; 8.1.4 used a clean disposable physical copy instead.

### Fix-round confirm (2026-11-18)

Reviewer: **thermos-sol**, correctness/security and maintainability rubrics applied directly, without other threads
or reviewers. Commit: `b96620b31998391ca8cd3cfcb1cddc72f8d3f586`, following the confirm of `33f044c2` above.
**Verdict: not confirmed as written.** The named render/form fixes work, but the unconditional release-binding
claim still exceeds the endpoint artifact's admission contract. This review changes no gem code.

**Must-fixes:**

1. **P2 — Bind endpoint artifacts too, and correct the opening guarantee until then.**
   `EndpointBuild.build` (`gem/lib/lowrail/endpoint_build.rb:89–94`) records no build release;
   `Endpoint.activate` (`gem/lib/lowrail/endpoint.rb:51–57`) asks only whether the running release is in the table,
   then checks sources and method signatures. Using `EndpointTest`'s app and build/compiler path, an artifact built
   on 8.1.4.1 still activates both actions when `Rails.version` is redefined to the other allowed release, 8.1.4,
   before `lowrail/setup`: two endpoint hits, two HTTP 200 responses, identical bodies/effects, no refusal.
   The ordinary 8.1.4.1 control also takes two hits. This is a pre-existing admission omission exposed by the
   requested complete inventory, not an introduced HTML divergence or an actual cross-gem execution. It contradicts
   the newly added assertion that every artifact records its release and every unit refuses another one.
   Record and compare the endpoint build release, silently refuse older artifacts lacking it, and add an
   allowed-to-allowed regression; testing an unknown future label only exercises the allow-list.
2. **P3 — Delete the new narrative test comment** at `gem/test/form_scaffold_test.rb:118` ("A process on another
   Rails release..."). It restates the following setup/assertions rather than explaining a reason a reader would
   otherwise miss. DECISIONS' comment rule explicitly includes tests and makes this a required change, not a nit.

**Closed items and executed controls:**

- The 8.1.4.1 support sentences now name only the retained blog's verification-tier Article/Comment instantiate,
  token's empty/unprotected branch and collection. They make no link, form or endpoint support claim. The
  table-only wording now lists the separate lock, entropy row, CI entry, closure audit and verification work.
- Rebuilt the retained 8.1.4.1 blog with `lowrail build --sealed --verify-test --env test --jit interpreter`, then
  `lowrail verify APP -- ruby bin/rails test --seed 41231`, with worker 1, CI=1 and SQL trace off. Ordinary control:
  **21 identical outcomes, 51 hits (30/9/11/1)**. The original `RUBYOPT` reproducer reporting 8.1.4.2 now gives
  **21 identical outcomes, zero hits**, with token/collection recording
  `verification_render_Rails_release_changed;_rebuild`. Rebuilding/running the same mismatch with 33f044c2 gives
  **21 identical outcomes, 12 hits (0/0/11/1)**. No actual future Rails gem was substituted.
- Deleted just `verification_render.rails_version` from the new artifact: **21 identical outcomes, 39 AR hits,
  zero render hits**, `verification_render_observation_unknown`, no escaped exception. In an isolated production
  scaffold, removed the release key from render certificates, form inventory, and both, separately. Each affected
  unit refused with zero hits; unaffected units remained active. Ordinary control hits all three units. Reporting
  8.1.4.2 refuses all three. All cases preserve complete response objects against off, with no escaped exception
  or Lowrail warning. Missing keys take the existing rescue paths; no schema-version bump is needed for refusal.
- Overlaid the two current test files on an archived 33f044c2 checkout with its original gem runtime and rebuilt
  CLI. In **both** isolated release homes, the two extended tests fail: verification render reports
  `invalid dispatch certificate admitted`; production render expects zero hits but gets two. The missing and
  mismatched view-context modes run before the new release mode, which is the failing case.
- `script/corpus real-blog` accepts a disposable correctly pinned/locked specimen and refuses each of an
  independently wrong Gemfile and wrong lock. The actual stale generated blog is also refused. Setup and
  `script/gate --prepare` invoke this path, so they inherit the check. Pinned corpus sources/locks were not edited.

**Strict gem suites.** Ruby 4.0.7, interpreter, `LOWRAIL_STRICT_GATES=1`, `MT_CPU=8`,
`ruby -S rake test TESTOPTS='--verbose --seed=1729'`, using isolated release homes:

- 8.1.4: **226 tests, 7359 assertions, one failure, no errors, one missing-Campfire skip**. The sole failure is
  `ObserveCorpusTest#test_real_blog_suite`: this review's disposable corpus used a symlink to `real-blog-r4`, while
  the observer filters source paths by the textual `LOWRAIL_OBSERVE_ROOT`. Reproduced the missing controller
  samples, then reran that same test against a physical copy of the retained app: **11 assertions, no failures,
  errors or skips**. This is a review-fixture path mismatch, not a change in b96620b3; the raw suite is not green.
- 8.1.4.1: **224 tests, 7353 assertions, no failures or errors, one missing-Campfire skip**. The two Rails-checkout
  report cases are excluded as in `script/gate`. Neither local result is an unqualified full-gate pass.

Both extended regressions pass in both current homes and fail on 33f044c2 as above. `cargo build --locked`,
`bash -n script/corpus` and `git diff --check` pass. CI run 44326627232 is successful on the exact b96620b3 head:
209 tests per release, 6321/6322 assertions, no failures/errors/skips; its corpus exclusions are not integration
coverage. Initial setup refused the mixed primary gem home and stale generated blog; the review used a disposable
physical primary-home copy and an exactly pinned/re-locked generated-blog copy, leaving setup files unchanged.

**Complete runtime admission inventory.** Traced `Passes::REGISTRY`, verification-tier installation, manifest/file
delivery and their builders. AR instantiate and AR plans already compare recorded Rails releases; preload also
does, and its entire artifact is currently quarantined. Production token/collection, verification render and form
now compare the recorded release. Sealed link lacks a recorded-release comparison but manifest admission refuses
the entire artifact before any installer or lowered-file delivery; source link/route passes and nonempty generic
template delivery are likewise quarantined. Memo and digest memo specialize URI/Digest rather than Rails-release
bodies. Inertia props specializes native Hash iteration over pinned Inertia code; Inertia config certifies the
Inertia version/schema and the exact Active Support `Hash#extract!` implementation/source instead of choosing a
Rails-release implementation. Neither makes the table's release-specific claim. Endpoint is the remaining live
table-gated artifact with no build-release comparison.

**Design and claims.** The three new comparisons belong at their existing admission boundaries, each before
granting fast-path authority; their distinct artifact shapes do not warrant a shared wrapper. Recording the
release and refusing a missing key protect real build facts, not hypothetical internal states. The corpus check
guards reused generated input, not just initial generation. These guards satisfy DECISIONS; the single added test
comment does not. No structural regression, unjustified abstraction, new file over 1,000 lines or additional
maintainability blocker was found. Every changed documentation sentence was checked against code and executed
evidence; the opening universal artifact/refusal sentence is the exception identified above.

### Endpoint fix confirm (2026-11-18)

Reviewer: **thermos-sol**, both rubrics applied directly without other threads or reviewers. Commit:
`53f9b7118eebf5026a3a7788c0cd1cee64c5a492`; scope: the two b96620b3 must-fixes and the opening refusal sentence.
**Verdict: confirmed for this scope. Must-fixes: none.** No gem code was changed by this confirm.

- **P2 closed.** Each endpoint unit records `Rails.version`; admission compares it before source checks, factory
  evaluation or wrapper installation. A missing key compares unequal and silently drops that unit. In both isolated
  homes, `ruby -Igem/lib:gem/test gem/test/endpoint_test.rb --verbose --seed=1729` passes **114 assertions, no
  failures/errors/skips**. The same current test over archived b96620b3 gem code fails in both homes: the new
  `release` case expects empty hit/fallback maps but gets one hit per action. Both allowed-release directions
  are therefore covered, not just the unknown-release allow-list case.
- Independent fresh-artifact probes in each home pass **33 assertions**: matching release takes two hits;
  reporting the other allowed release or deleting both release keys takes zero. Removing or mismatching only
  the first unit's key preserves the second unit's one hit. Every case keeps both HTTP responses, bodies and
  callback effects identical to the matching control, with empty stderr and no escaped exception.
- **P3 closed.** The flagged form-test comment is removed, with no replacement narrative comment. The new
  equality protects the documented cached-build contract in the existing per-unit filter; no helper or extra
  abstraction is warranted. No correctness/security or structural maintainability blocker remains in this diff.

The opening refusal sentence is now supported for this document's audited Rails-specific admissions: the other
live Rails-specific artifacts already compare their recorded release, and quarantined delivery refuses before
admission. Rails-independent memo/Digest/Inertia authority remains as described above; this adds no support claim.
CI 44341006335 was independently checked: both release jobs succeeded on the exact 53f9b711 head. Full strict gem
suites were not repeated for this short confirm; the builder's reported 226/224 runs with one Campfire skip each
are not represented here as an independent full-suite result. `git diff --check` passes.
