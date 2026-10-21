# Helper discovery: source census, not runtime coverage

2026-10-21. **Discovery only; no runtime/admission widening.** The agreed
controller-parametric link gate is not met: only CASA and Fizzy have non-blog
sites in the currently accepted shape delivered as `app/views/**/*.html.erb`.
Forms remain named refusals. Source shapes, template-delivery candidates,
successful lowering, admitted units and actual runtime hits are distinct.

The reusable [Prism census](../script/helper-census) produces the
[machine-readable report](helper-census.json). Every site records file/line,
helper, positional argument kinds/literal count, name/block shape, target
and target-argument kinds, literal/dynamic option keys and values,
partial/layout flags, candidate status and named refusal reasons. Per-helper
histograms and individual source/lock/tool hashes make the counts auditable.
`form_with` records both `model:` and `url:` when present; neither a reference
nor a dynamic route-helper argument proves a record's type.

## Corpus and counts

1,693 Ruby/ERB/Slim files, **742 sites: 537 link_to, 57 button_to,
141 form_with, 7 form_for**. All files compile/parse for this census; no
application code is evaluated and no application is booted by the census.
JS/Vue/TSX, dynamic `send`, and resolved method dispatch are outside its scope.
PingCRM's zero does not mean its Vue UI has no links.

| App | link_to | button_to | form_with | form_for | Current link shape, any source | Current HTML-ERB delivery candidates |
|---|---:|---:|---:|---:|---:|---:|
| Writebook | 52 | 10 | 15 | 0 | 0 | 0 |
| CASA | 280 | 17 | 76 | 0 | 32 | 29 |
| Redprints CFP | 1 | 0 | 0 | 0 | 0 | 0 |
| React Starter Kit | 2 | 0 | 0 | 0 | 0 | 0 |
| CodeTriage | 70 | 1 | 0 | 7 | 5 | 0 |
| PingCRM | 0 | 0 | 0 | 0 | 0 | 0 |
| Wikino | 45 | 2 | 12 | 0 | 1 | 0 |
| Fizzy | 78 | 24 | 36 | 0 | 1 | 1 |
| Blog | 9 | 3 | 2 | 0 | 8 | 8 |

The current link shape is a **bare call, literal String name, no block,
exactly three arguments, exactly one literal Symbol `class:` option with
a literal String value, target arbitrary, no splat/forwarding**. CASA has
three additional matches in Ruby helpers, CodeTriage five in Slim, Wikino one
in a component. None counts toward the HTML-ERB gate. CASA29 + Fizzy1 are
syntax/delivery bounds, not admitted units. An unchanged `SealedBuild.lower`
check actually lowers **CASA27**, Fizzy1, blog8; two CASA templates expose the
separate encoding defect below.

Pins match the existing [compatibility corpus](compat.md) and
[seven-app eligibility probe](sealed-verification.md#real-app-get-eligibility-after-passive-form-activation),
plus Fizzy. Wikino is
[`25255d2`](https://github.com/wikinoapp/wikino/commit/25255d2d6c808df6672e293661ea797a76c6d2a9),
under `rails/`, with the checked-in dependency-only wrapper. Full upstream
revisions and frozen overlay lock hashes are recorded per app in the JSON.
The blog is the coordinator's exact prepared `real-blog-r4` source archive,
not a newly generated approximation: app/config/lib/Gemfile.lock, no master
key, credentials, DB or storage. Archive SHA256:
`5469bef570e25be29f8bf6b80e856faf2fc6f8dd9e258327c6b60a5ba3dd3454`;
blog lock SHA256:
`a0b681d52555b3493ff62ef3f9b6ef386ed09ca314f89d807d2f3a7129fec8a2`.

## Top three additional HTML-ERB shapes

These disjoint groups are bare `link_to` calls in `app/views/**/*.html.erb`,
excluding the existing accepted shape. They are **syntax/delivery opportunity
bounds**, not runnable units: boot, owner provenance, Rails source domain and
full exactness certification still apply. Wikino is outside Rails8.1.4;
Writebook still fails production boot. Zero entries are shown explicitly.

| Additional shape | Writebook | CASA | Redprints | Starter | CodeTriage | PingCRM | Wikino | Fizzy | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Block, sole `class:` key, dynamic value | 0 | 87 | 0 | 0 | 0 | 0 | 0 | 0 | **87** |
| Block, sole `class:` key, literal value | 27 | 20 | 0 | 0 | 0 | 0 | 4 | 23 | **74** |
| Non-block call-expression name, sole literal `class:` | 0 | 22 | 0 | 0 | 0 | 0 | 11 | 2 | **35** |

Excluding the unsupported Rails domain gives 87 / 70 / 24; this still does
not erase Writebook's boot failure or certify any remaining site. The blog
is excluded from additional coverage (it has one shape-3 site).
Block links, regardless of options, total
Writebook48, CASA156, CodeTriage13, Wikino19, Fizzy49.

Certification requirements, **not implemented**:

1. **Dynamic-class block (87).** Targets: 56 path helpers with dynamic
   arguments and 31 no-argument path helpers. Leave target, defaults,
   `to_param`, options conversion and block capture live, in stock order,
   once. A residual needs owner-scoped view/capture/output-buffer and block
   provenance, identical exceptions/nonlocal control flow, and exact class
   normalization/blankness/safety/encoding/escaping. A dynamic class is not a
   preescaped literal; without these facts retain live tag rendering. No
   I18n/config value may be folded merely because it was seen at boot.
2. **Literal-class block (74).** Targets: 37 no-argument paths, 32 paths with
   dynamic arguments, four record-shaped references, one other call. Keep
   capture and URL generation live once. Certify the same actual view,
   capture/output-buffer, helper, TagBuilder/native constructor and literal
   classification/regex dependencies as the original residual, plus the
   block boundary. Literal class does not prove captured content is a plain
   safe String. No record/route/config/I18n invariance follows from it.
3. **Call-expression name (35).** Keep the name call (including `t`, I18n or
   model methods), target, URL/defaults/`to_param` and options conversion
   live once. Certify or guard the returned name's actual type, safe-buffer
   behavior, encoding and escaping; otherwise retain live content rendering.
   Do not pretranslate names or assume locale/config is boot-fixed.

For all three, failure before original work uses original `link_to` with
already evaluated arguments. After conversion/capture, use a **local stock
continuation** with captured values, or retain the entire original path
from the outset. Never replay `link_to`, its block, conversion or user code
after a partially executed attempt. An unproved boundary stays a refusal.

## Non-shape blockers, separately counted

| Blocker | Source sites behind it | Current link-shape matches | What fixing only this blocker establishes |
|---|---|---:|---|
| CodeTriage Slim delivery | 55 links + 7 form_for = **62** | **5** | Five handler opportunities; still no generic controller certificate. Slim needs its actual handler/compiler/compiled-container and natural delivery provenance. Static Slim parsing is not ERB delivery. |
| Wikino app/components / ViewComponent | 17 links + 1 form_with = **18** | **1** | One component opportunity, also blocked by Rails8.0.5.1. A controller certificate is not component view/capture/locals/compiler provenance. |
| Rails version/source domain | Redprints8.1.3: 1 link; Wikino8.0.5.1: 45 links + 2 buttons + 12 forms = **60** | **1**, the Wikino component | **Zero** existing app/views HTML-ERB candidates unlocked by version widening alone. Requires independently audited stock bodies/literal semantics/residuals, not accepting a version string. |

These overlap: do not add component and version counts. The 62/18/60 include
forms/buttons needing new generators. Slim/components/unsupported Rails do
**not** turn two apps into the agreed three-app gate. Generic controller
discovery alone does not certify a site either.

## Where the inventory is closed

Audited unchanged implementation at
[`23b13ba`](https://github.com/thomasklemm/lowrail/commit/23b13ba),
following the seven-app probe in
[`08d690e`](https://github.com/thomasklemm/lowrail/commit/08d690e).

| Code / predicate | Blog shortcut or safety requirement? |
|---|---|
| sealed_build.rb build: production Ruby4.0.7 / Rails8.1.4; independent STOCK hashes; actual-holder native binary | **Safety domain.** Wording includes “blog”, but other Rails versions cannot use the same audited residual. |
| Same build: loaded_constant("ArticlesController"), its view_context_class, all templates through its view paths, guessed basename/counter/iteration locals | **Blog discovery shortcut.** Actual view/controller/resolver/locals provenance remains required. Do not substitute an arbitrary representative controller. |
| Same build: one target/controller ArticlesController unit; sealed.rb caches that unit/view class | **Closed certificate representation**, not just a filename filter. Generic discovery needs concrete owner-scoped certificates and dispatch. |
| Same build: stock effective helper owners/bodies/visibility, TagBuilder/native constructor, primitive bodies, literal/regex tables, source/delivery signatures | **Safety requirements.** Never learn effective overrides as “stock” from a modified boot. |
| Same lower: literal name + single literal class + no block/splat; visits outer bare link calls without descending into them | **Current generator boundary.** Required by this literal-folding residual. Arbitrary target stays live, not a route/model specialization. |
| sealed.rb: request epoch, per-hit view?/link?, actual-holder checks and WeakKeyMap builder provenance | **Safety requirements.** A source shape does not authorize a hit. |
| form_scaffold_build.rb: exact SOURCE, articles/show, one block; form_scaffold_inventory.rb: Article/Comment schema/defaults/readers/callbacks/model names, English I18n, config, polymorphic caches | **Blog workload with real safety assumptions.** Cannot discard exact-body check without a different generator/certificate. |
| form_scaffold_admission.rb: passive fixed cache/holder checks; form_scaffold.rb: article_comments_path, commenter, body, Add Comment | **Hard-coded generated operation**, not generic form_with. Routes/models/config inventory alone cannot generalize it. Preserve first-natural-original witness and fallbacks. |

Files above are under `gem/lib/lowrail/`. `button_to` and `form_for` have no
equivalent certified generator. The census names
`button_to_generator_not_implemented`, `form_for_generator_not_implemented`
and `form_requires_exact_scaffold_body_and_build_certificate` explicitly.

## Generic discovery proposal — parked, no runtime code

Build-time discovery could enumerate the booted app's finite controllers,
routes/view paths and concrete template/locals contexts. Shared partials,
layouts, mailers, components, engines and custom resolvers need explicit
owner/context sets; unknown/dynamic ownership refuses. Do not assign every
template to one controller. Routes/models/config identify contexts or facts;
they do not license folding URL generation, to_param, defaults, locale or
model behavior. The link residual need not fold any of those values.

Each unit needs the actual controller/view, compilation container,
handler/resolver/locals shape, stock helper/primitive/native constructor
bodies, literal/regex dependencies, unchanged source and delivery signatures.
Separate discovered/lowered/admitted. Name unknown owner/locals, unsupported
handler/Rails source, custom helper/builder and uncertified form refusals.

Production activation belongs to the sealed owner: **observe the first
natural, wholly original execution** for that concrete owner. Never call a
runtime inventory builder, load constants, query ObjectSpace, do lookups/SQL,
force materialization or add on-only ancestry. Unknown/unwitnessed owners
remain original. Preserve all per-hit guards and stage-correct fallbacks.
The AR test certificate does not authorize link/form or token/collection.
No generic runtime change is authorized by this report.

## CASA: a named disposable production boot fixture

Observed on the unchanged pin with its frozen Rails8.1.4 overlay:

| Setup | Production result |
|---|---|
| SECRET_KEY_BASE_DUMMY=1, no master key | Exit1, missing encryption key; dummy secret_key_base does not satisfy require_master_key. |
| Generated RAILS_MASTER_KEY, original encrypted credentials | Exit1 InvalidMessage; AR's encryption initializer reads credentials. Random key cannot decrypt app ciphertext. |
| Matching external file/key only | Credentials pass; next fails on missing Azure access key. |
| Matching external file/key + dummy Azure env + schema-only local PG | Exit0: production/eager_load/require_master_key true, Rails8.1.4, Ruby4.0.7/YJIT, Lowrail0. |

Reproduce on an isolated corpus copy and **fresh empty local disposable DB**:

```sh
script/corpus casa casa-boot --source-only
# PostgreSQL must already run locally; use its actual port/user.
createdb -h 127.0.0.1 -p 55432 -U user lowrail_corpus_casa_boot
LOWRAIL_CORPUS_DATABASE_URL=postgresql://user@127.0.0.1:55432/lowrail_corpus_casa_boot \
  script/corpus casa casa-boot --casa-production-boot-fixture
```

This is a **boot fixture, not the app's credentials**. The option installs
the frozen bundle, loads only the checked-in schema via standalone AR, and
boots without seeds/assets/requests/jobs. It refuses non-local or
non-lowrail_corpus_casa_* DB URLs and nonempty DBs; use a new DB for repeats.
It leaves app files untouched, generates a matching key/encrypted file in a
private external temporary directory, sets public credentials.content_path
and key_path before initialization, and removes the pair on exit. It leaves
require_master_key=true, sets a dummy BASE_URL and generated dummy Azure
values, disables mail through the app's existing APP_ENVIRONMENT switch and
disables Scout. No keys are printed/committed. This proves neither real
credentials/storage/deployment compatibility nor adapter support.

The named option succeeds; repeating against its nonempty DB refuses.
Separately, unchanged runtime-build under equivalent fixture boot returned
**0 link / 0 form units**, retaining missing ArticlesController/scaffold
target reasons. Fixture boot is not discovery generalization or hit coverage.

## Writebook: leave production boot red

The unchanged app reproduces NoMethodError
ActiveRecord::Base.sqlite3_production_warning= at
config/environments/production.rb:66 with the frozen Rails8.1.4 overlay.
Its original Rails
[`13d5f872`](https://github.com/rails/rails/commit/13d5f87208921cc5139cd53b280c42f23c334826)
had a shim deleting the obsolete config key before applying AR config;
Rails removed it in
[`2cc6cd2`](https://github.com/rails/rails/commit/2cc6cd2b18c272a3221dde13128236052223538e).
This is an overlay/version mismatch, not a Lowrail-caused exception. No app
patch or nonexistent setter shim was added. Pinning an external overlay to
the original Rails is possible, but outside the audited8.1.4 domain. The
coordinator chose **leave red**, not repin. A green test baseline is not a
production boot; the Rails-version domain is a separate later item.

## Separate lowerer defect: non-ASCII Devise link names

CASA app/views/devise/passwords/edit.html.erb:39 and new.html.erb:40 each have
an otherwise accepted link_to "← Back to sign in", target, class: literal.
File source, Erubi output and Prism name literal are **UTF-8**, with non-ASCII
bytes. Class is ASCII-compatible UTF-8. SealedBuild.lower creates
output=source.b.dup (**BINARY/ASCII-8BIT**), then inserts a UTF-8 replacement
containing the name at gem/lib/lowrail/sealed_build.rb:247. The byte-offset
splice raises Encoding::CompatibilityError before final force_encoding.

Minimal reproduction, no app/boot:

```sh
mise exec ruby@4.0.7 -- ruby -Igem/lib -raction_view -rlowrail/sealed_build -e '
  Lowrail::SealedBuild.lower(%("•"; link_to "← Back", "/", class: "nav"))
'
```

This exits1 at the splice, not at parse/shape rejection; an ASCII name
control lowers. Builder exception/refusal is correct but this is a **real
lowerer defect**, reducing CASA29 delivery shapes to27 before admission.
The coordinator authorized an independent fix/regression commit after this
publication: byte-correct encoding-preserving splicing, with multibyte
content around the replacement. No shape or admission widening follows.

## Reproduce the census

```sh
for app in writebook casa redprints-cfp react-starter-kit codetriage pingcrm wikino fizzy; do
  script/corpus "$app" --source-only
done
# Restore the exact prepared blog archive to .corpus/real-blog-r4 separately.
mise exec ruby@4.0.7 -- ruby script/helper-census \
  writebook=.corpus/writebook casa=.corpus/casa redprints=.corpus/redprints-cfp \
  starter=.corpus/react-starter-kit codetriage=.corpus/codetriage \
  pingcrm=.corpus/pingcrm wikino=.corpus/wikino/rails fizzy=.corpus/fizzy \
  blog=.corpus/real-blog-r4 > docs/helper-census.json
mise exec ruby@4.0.7 -- ruby -Igem/test gem/test/helper_census_test.rb
bash -n script/corpus
```

Fresh generated blog source-only preparation refuses
generated_blog_requires_prepared_source: its upstream generator itself
prepares a DB. Reuse the exact prepared source. Census tools: Prism1.9.0,
ActionView8.1.4/Erubi1.13.1, Slim5.2.1/Temple0.10.7/Tilt2.9.0/Sass3.7.4.
These compile syntax only, **not** the app's certified runtime compiler.
JSON records loaded versions. Slim positions are generated Ruby lines;
ERB/Ruby retain source lines. Identical scans produce byte-identical JSON.
No timing, Callgrind, performance cohort, request replay, own-suite
equivalence or support claim is part of this publication.
