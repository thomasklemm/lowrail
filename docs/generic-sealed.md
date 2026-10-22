# Generic token/collection inventory — bet G

2026-10-22. Structural admission improvement, not a new large optimization.
The [full research census](https://github.com/thomasklemm/lowrail/blob/88001c5eebea6fa221f7310bc87f471f5fb3f5fa/docs/generic-sealed.md)
and labeled raw-data export remain on `thomasklemm/generic-sealed`; this lean
candidate contains neither that export nor the Lobsters fixtures/prototype.

## Boundary

Token/collection formerly called the entire blog form inventory: absent
Article/Comment/ArticlesController stopped four non-blog apps with the misleading
`eager-loaded targets required` refusal. Fizzy then exposed an irrelevant I18n
1.14.6 versus 1.15.2 source pin. Neither render unit folds translations.

Token now records effective stock token/tag/tag_builder definitions and
visibility per loaded named controller, auditing ActionView/ActiveSupport only.
Admission reads already-cached view classes, never creates a view or receiver
singleton class; unknown holders fall back. Collection audits ActionView and
treats the view as opaque, forwarding it unchanged to live Template#render.
V1 artifacts keep their old scope. Both use the production mutation tripwire
and remain subject to the [sealed contract](sealed.md).

Form still requires its exact blog template, constructor/schema, FormBuilder,
literal field/options/config and English translation facts. Deleting
those facts would not make that generator generic. Link/template delivery
remains quarantined. The literal-options prototype is killed: Lobsters loses
allocations and its compiler seam correctly invalidates the blog certificate.
No certificate waiver, new template delivery seam or Ir cohort is included.

## Isolated screens: options prototype absent

Ruby 4.0.7 / Rails 8.1.4 interpreter. Two independent seeds, serial off-A/off-B/on
workers, three exact-response requests per route, 100 warmups and 100 untimed
allocation samples. Medians below use the same upper-middle convention.
These include symmetric observers and are not clean no-Lowrail Ir prices.

| GET | Seed 0 off-A / off-B / on | Seed 1 off-A / off-B / on |
|---|---:|---:|
| Fizzy buckets | 9070 / 9070 / 9066 | 9069 / 9069 / 9066 |
| Fizzy filtered bubbles | 22396 / 22396 / 22394 | 22398 / 22398 / 22393 |
| Fizzy account users | 5682 / 5683 / 5675 | 5684 / 5685 / 5674 |
| Fizzy workflows | 3869 / 3867 / 3869 | 3869 / 3870 / 3870 |
| Fizzy notifications | 3866 / 3866 / 3864 | 3867 / 3867 / 3864 |
| Fizzy bubble show | 18364 / 18364 / 18343 | 18365 / 18364 / 18344 |
| Campfire room | 15487 / 15490 / 15489 | 15488 / 15489 / 15489 |
| CASA anonymous sign-in | 2345 / 2345 / 2345 | 2345 / 2345 / 2345 |
| Blog show, form + token + collection | 2647 / 2647 / 2270 | 2647 / 2647 / 2271 |

Fizzy saves about 2–21 objects on five routes; workflows, Campfire and CASA are
neutral within A/A variation. Blog's ≈377-object saving is preserved. Whole
worker token/collection hits per seed: Fizzy 4066/1423, Campfire 524/0 (collection
active after a cold witness, warm fragment cache bypasses it), CASA 202/0
(collection pending, no natural call), blog 811/202 plus 202 form hits. A token
hit can be the empty/unprotected branch, not an allocation saving.

Literal status/body/all headers and captured holders/ancestry match off/off/on
at both seeds. CASA is schema-only anonymous sign-in, not case-management
coverage. Final workers have no entropy errors. Earlier rejected entropy and
prototype arms remain explicitly labeled in the full census, not credited.

### Campfire template IDs: the off/off control

In seed-0 off-A versus off-B the only post-request differing holder was
`ActionView::LookupContext::DetailsKey.@view_context_class`: one generated
ActionText content-template method differed only in its numeric name/original
name suffix, `___4506467662812209713_20472` versus
`___2455740143569929097_20472`. Both were anonymous-owner/public, with required
`local_assigns`, `output_buffer`, block `_`; ancestry and multiplicities matched.
Raw holder hashes were `cf4950b21be295a7d2404d4fab43dde44456f4394fbbfcc81336fa1740e02f4e`
and `7802eb3ab8ec91405adf44d21c7dcfe57f4745f342c4fa9845d374c9c0e7bd0f`.
Normalizing only that suffix gives
`d5c29862b5d04270828027931fd512fec3f2a17e20e9af8833639611b677a74f`
for all six off-A/off-B/on snapshots (two seeds), each 7,315 holders. Raw and
normalized hashes remain in the full export. This is demonstrated off/off
generation noise, not permission to hide an on-only method, owner or ancestor.
