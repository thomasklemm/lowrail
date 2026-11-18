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
