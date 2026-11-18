# Audited Rails releases

The sealed and render passes certify stock Rails source. Which releases they accept is one reviewed table,
`Lowrail::RailsPins::RELEASES` (`gem/lib/lowrail/rails_pins.rb`). Any release not in it refuses at build and at
runtime (invariant 1), so a new security release is a safe no-op until someone adds it.

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

Link has no verification-tier unit on either release (build refusal `verification_literal_table_observer_unavailable`),
and form refuses at activation by design, as recorded in [test-certificate-render.md](test-certificate-render.md).
Their production paths, and the endpoint prototype, are covered on each release by the public regressions that
assert non-zero hits (SealedLinkTest, FormScaffoldTest, EndpointTest, BlogProductionTest), run against that release's
gem home and corpus.

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
