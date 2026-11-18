# Rails 8.1.4.1 and the 8.1.4-certified passes

Status 2026-11-18: built. 8.1.4.1 is now in the per-release table in [rails-pins.md](rails-pins.md), which also
records the `tag_options` audit and the verify results. `lowrail verify` supports on 8.1.4.1 only the retained blog's
verification-tier units: Article and Comment instantiate, token (empty/unprotected branch) and collection. Link, form
and the endpoint prototype make no 8.1.4.1 support claim. The analysis below is what led to it.

Rails 8.1.4.1 (2026-11-04) is
the current 8.1 security release. On it, every pass that requires Rails 8.1.4
exactly refuses (`unsupported_rails_version` and similar). An up-to-date app
gets the original code everywhere: safe (invariant 1), but those passes then
do nothing in practice.

## What refuses on 8.1.4.1 today

| Pass | Gate | Where |
|---|---|---|
| endpoint prototype | `Rails.version != "8.1.4"` | `endpoint_build.rb:36`, `endpoint.rb:49` |
| sealed link (`sealed/link_to`) | `Rails.version == "8.1.4"` and `SealedBuild::STOCK` file pins | `sealed_build.rb:53`, `sealed.rb:82` |
| sealed form scaffold | `Rails.version == "8.1.4"` and `FormScaffoldInventory::STOCK` per-gem inventories | `form_scaffold_inventory.rb:43` |
| render units (token tag, collection render) | `Rails.version == "8.1.4"` and the same inventories | `render_units_build.rb:13-15` |
| test-certificate render | `FormScaffoldInventory.check` (version and inventories) | `test_certificate_render_build.rb:23` |

These passes are not affected: AR instantiate (its four `AUDITED` files are
byte-identical in 8.1.4.1, and the version is recorded at build time), AR plans
and preload (they record the build's Rails version and source hashes), and the
memo pass (it certifies uri, not Rails).

## The diff, measured

The diff compares the installed gems (`lib/**/*.rb`, plus `app/` for engines)
of 8.1.4 and 8.1.4.1. Changed lines are counted without context lines.

| Gem | Changed files | Changed lines | Files a pass certifies |
|---|---|---:|---|
| actionview | `tag_helper.rb`, `sanitize_helper.rb`, `text_helper.rb`, `gem_version.rb` | 52 | `tag_helper.rb` (`TagBuilder#tag_options`) |
| actionpack | `metal/live.rb`, `metal/rendering.rb`, `strong_parameters.rb`, `mime_negotiation.rb`, `cookies.rb`, `remote_ip.rb`, three session stores, `gem_version.rb` | 172 | none directly; `metal.rb` and `polymorphic_routes.rb` are unchanged |
| activesupport | `inflector/methods.rb` (`safe_constantize`'s rescue), `message_pack/extensions.rb`, `gem_version.rb` | 28 | none (`blank.rb`, `erb/util.rb` and `output_safety.rb` are unchanged) |
| activemodel, activerecord | `gem_version.rb` only | 2 each | none |
| activestorage, actionmailbox | security fixes outside every pass | not counted | none |

Only one certified method body changed: `TagBuilder#tag_options` (8.1.4.1 lines
239-283). For each key it now computes `name = Symbol === key ? key.name :
key.to_s`, skips keys whose name is blank, and passes `name` instead of `key` to
`tag_option`, `prefix_tag_option` and `boolean_tag_option`. Output differs only
for keys whose string form is blank but that are not `blank?` themselves, such as
`:" "`. For non-blank String and Symbol keys, which are all the certified
link, token and form sites use, the HTML is unchanged. `tag_option`,
`content_tag_string`, `TagBuilder#initialize`, `url_helper.rb` (including
`token_tag` at line 770 and the test certificate's line offsets 774/780/782) and
the ActiveModel naming lines are byte-identical.

The second visible behavior change is `ActionController::Rendering#_set_vary_header`
(it now merges `request.vary_headers` into an existing `Vary`). No pass replaces
the response path. The endpoint prototype still runs the original `process`, so
that change stays live.

## New pins 8.1.4.1 would need

| Pin | 8.1.4 | 8.1.4.1 |
|---|---|---|
| `SealedBuild::STOCK["action_view/helpers/tag_helper.rb"]` | `7bca8efe…a16c31` | `237a725fd719c0ba0c8330a60979ef15eb77733ccf725fe3717cce2698d50673` |
| `FormScaffoldInventory::STOCK["actionview"]` | `b7135e37…dd35fd` | `af456c211b19686cd832f934370795ccf288e66f3571fa847570bbf36c8afe59` |
| `…["actionpack"]` | `aa7b3eda…609844` | `a8fe1909000317fc4659b1feaeba914203e8a0580bd1a4e0c82cc8b0fc8deb60` |
| `…["activemodel"]` | `2927864a…edb39b` | `95b64a7fe85cb79cccf58f7a7861ba1cb06e80dcac9f9df04099bcac1fe205b6` |
| `…["activerecord"]` | `71e11e0f…7d3d6c` | `4393eb4811f3dc2e996544761b157886770d6a78e8167072f8f5e06d689ae5d8` |
| `…["activesupport"]` | `7b52dc2e…0a1f7` | `7ac516ca5e0fe83c67a41f4b0c39d40077a0d314eee5e61ae34f8d935f1180b4` |
| `…["i18n"]` | unchanged | unchanged |

The inventories hash every file in each gem's `lib/`, so activemodel and
activerecord change through `gem_version.rb` alone. Computed with the same
algorithm as `FormScaffoldInventory.source_inventory`, the 8.1.4 values above
reproduce today's pins.

## Is certifying 8.1.4.1 as well small?

The code is small. The evidence is the larger part.

- **Code, about 10 lines:** in the six version gates, accept 8.1.4.1 as well
  (runtime checks should keep comparing against the version the manifest
  recorded). Allow a second `tag_helper.rb` pin. Key `FormScaffoldInventory::STOCK`
  by Rails version, with the five new inventories above. Before adding the
  pins, re-audit `tag_options` (the review summarized above) and the closure of
  the five changed actionpack/activesupport files against each inventory's
  method list.
- **Evidence, the larger part:** invariant 3 needs `lowrail verify` with
  non-zero hits on 8.1.4.1, and the sealed and render passes are proved on the
  retained `real-blog-r4` specimen, whose lock (and entropy pin
  `lock_sha256`) is 8.1.4. Certifying 8.1.4.1 needs a second retained
  specimen, or a second lock with its own entropy pin, running those gates.
  The gate and CI would also need a second gem home with 8.1.4.1 only, because
  unbundled fixtures load the newest installed Rails. A per-release table
  keeps the pins in one place, but each security release still needs its own
  lock, entropy row, CI entry, closure audit and `lowrail verify` run.
