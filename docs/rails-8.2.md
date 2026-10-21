# Rails 8.2 alpha: compatibility and source drift

2026-10-21. **Stage 1 only. No sealed 8.2 admission, performance measurement,
Callgrind run or upstream post.** Defaults, quarantine and gem runtime are
unchanged. Stage 2 waits for the first 8.2 beta/RC and new, exact certificates.
RubyGems' live Rails API still reports **8.1.4**, published September 24; 8.2
here means an unreleased checkout, not a released version support claim.

## Pins and unchanged application behavior

The common Rails source is
[`36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e`](https://github.com/rails/rails/commit/36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e),
observed on `rails/rails:main` and selected on **2026-10-21**. Its commit time
is 16:53:50 UTC. Choosing the then-current main gives one reproducible early
warning target instead of three different moving alpha lockfiles. The source
comparison base is v8.1.4, peeled commit
[`c3466ea00d7121798e3aa3144ffdf7174b81d8cb`](https://github.com/rails/rails/commit/c3466ea00d7121798e3aa3144ffdf7174b81d8cb).
The tag's object ID is not the commit ID.

| New corpus entry | Application pin | Original Rails lock | Original defaults / schema |
|---|---|---|---|
| `campfire-r82` | [once-campfire af4dd9f](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5) | `e3d5c569d217c56c022b04acb127a8c24dbe9685`, 8.2 alpha | 8.2 / 8.2 |
| `fizzy-r82` | [Fizzy 77eada1](https://github.com/basecamp/fizzy/commit/77eada1c8ead75c39f7fda5c80f322bcf5a9adb5) | `4658033fa3b391ab8a928994e12a30257a0afa22`, 8.2 alpha | 8.1 / 8.2 (SQLite schema selected by the app) |
| `writebook-r82` | [Writebook 7478e2c](https://github.com/basecamp/writebook/commit/7478e2c7b109e688a6fa4745bac123e72b5cef84) | `3a4961048ad251b50991ae83135d760a8a9e8ae3`, 8.2 alpha | 7.2 / 8.0 |

Both current public Fizzy and Writebook **already depend on 8.2**; neither is
an older app artificially upgraded by changing its configuration. Fizzy's OSS
Gemfile resolves publicly without its separate SaaS bundle or private gems.
Their older `load_defaults` values are intentional upstream choices, not a
reason to patch application behavior. No app configuration, implementation,
test, asset or schema source is changed.

The three [dependency-only patches](../fixtures/corpus/) change only
`.ruby-version`, `Gemfile`, `Gemfile.lock`, following [compat.md](compat.md).
All use Ruby **4.0.7**, an exact Rails `ref`, and frozen resolved bundles.
Writebook additionally declares `benchmark`: its original mini_magick requires
this removed Ruby-4 default gem. The initial plain boot's `LoadError` is retained.
`bundle update rails` resolved the new source's transitive dependencies; full
changes/platforms are frozen in the patches, not deferred to future resolution.
All pre-existing corpus entries and 8.1.4 overlays remain unchanged, including
the original `campfire` and separate `campfire-r81`.

The tested Lowrail code is [6a8e5c9](https://github.com/thomasklemm/lowrail/commit/6a8e5c9b280d6e3b791166f7ba0c3faefe9ffcfc).
The required pre-publication pull/rebase incorporated the separately owned
Prism build fix [6dc269a](https://github.com/thomasklemm/lowrail/commit/6dc269a197718cb26d68f70eedc4bd214e707951).
These app receipts predate that fix; they are not fresh verification of the
post-rebase runtime. The source scanner/test was checked again after rebase.
Writebook's executions use `.corpus/writebook-r82-candidate`; the standard
`writebook-r82` entry was separately replayed source-only and its patched
dependency bytes checked, not misreported as a second tested checkout.

## Own-suite and default no-op gates

Seed **41231**, `PARALLEL_WORKERS=1`, `MT_CPU=1`, `LOWRAIL_VERIFY_LOADS=1`,
Ruby 4.0.7. Plain baselines have `LOWRAIL=0` and **no Lowrail preload**.
Each default artifact contains **zero units**; every on/off hit/fallback map
is empty. Verification compares test identities, not just aggregate counts.
These results cannot certify a fast path. Chrome for Testing 155.0.8059.79 /
Selenium runs the apps' real `test:system` suites, separately from `test`.

| App / suite | Plain baseline | Default off/on outcomes | SQL / loads | Verdict |
|---|---|---|---|---|
| Campfire / non-system | 634: 632 pass, 2 skip | Identical, same 634 identities | Own-thread digests equal; strict total-count rejection on one identity; 0 load differences / 0 unstable | SQL gate remains rejected |
| Campfire / browser | 30: 29 pass, 1 failure | Identical, 30 pass in both arms | 7,632 off queries; 13 total-count rejections, own-thread digests equal; 2 strict load-event differences / 32 unstable | Verify exit 1; plain baseline also not green |
| Fizzy / non-system | 1,787: 1,772 pass, 5 failure, 4 error, 6 skip | Identical, same 1,787 identities | 103,663 queries; 316 SQL-unstable identities, all reproduced off/off; 0 load differences / 0 unstable | Baseline negative control; not all raw SQL equal |
| Fizzy / browser | 42 pass | Identical, same 42 identities | 13,553 queries; 10 SQL-unstable identities; 0 stable load differences / 153 unstable | Browser no-op gate; controls below |
| Writebook / non-system | 310: 303 pass, 4 failure, 1 error, 2 skip | Identical, same 310 identities | 16,640 queries; 0 load differences / 0 unstable | Identical baseline failures, not support |
| Writebook / browser | 3 pass | Identical, same 3 identities | 377 queries; 0 load differences / 0 unstable | No-op browser compatibility |

The [JSON appendix](rails-8.2.json) retains every test identity/result, per-test
SQL digests/counts, load snapshot fingerprints, differences and control results.
No raw SQL, cookies, credentials, database rows or performance observations are exported.
Raw logs and complete receipts remain private in `.lowrail/private/rails-8.2/`.

### Differences and bounded controls

* **Campfire SQL:** `Room::MessagesCountLifecycleTest#test_concurrent_ensure!_repairs_leave_triggers_installed_and_counts_accurate`
  has 41 off versus 40 on queries, including the verifier's own repeat arms.
  Its **own-thread digest is identical**. In `SqlTrace.finish`, `n` is
  `own.size + other.size`, not an own-thread count: the strict verifier also
  compares that count. Six fixed isolated **off-only** executions (three
  off/off pairs, no retry-to-green) all pass with 40 and the same digest.
  They **do not reproduce count variation on this new pin**. The prior
  [Campfire investigation](campfire-bench.md#9-original-rails-82-alpha-compatibility-evidence)
  reproduced 40/41 off/off on its original Rails pin, but is not relabeled
  as evidence for this one. Current disposition: concurrency-sensitive
  other-thread count difference, **unresolved strict gate**, not proved
  Lowrail causation and not silently exempted. No reporter/runtime fix here.
* **Campfire plain browser:** the Trix-mention editing test fails its
  unchanged helper's expectation of three connected Cable stream sources
  (one found). This occurred with no Lowrail loaded; both instrumented arms,
  both finite controls and the setup-only diagnostic pass all 30 tests.
  The plain-versus-instrumented discrepancy is **unresolved**, not labeled
  app nondeterminism without a matching plain/plain control.
* **Campfire browser traces:** 13 raw SQL differences are counts, not
  own-thread digests. Seven counts also vary off/off; six do not in that
  pair. The verifier's existing instability classifier compares digests,
  not `n`, so all 13 remain strict rejections. There are 16 other-thread
  digest advisories. Of 32 unstable load-event entries, 12 reproduce off/off
  and 20 have on/on-only evidence. Two further **strict** event-sequence
  differences remain: `RoomScoped` at event 348 and
  `Rooms::InvolvementsController` at 349, off-only. Constant, Zeitwerk-path
  and hook sets match; this is not evidence of extra loaded constants.
  The verifier automatically runs one `LOWRAIL_UNITS=-1` setup-only arm
  (zero manifest units, no pass-group runs), flags `setup/source delivery
  (no active units)` and still exits 1. This is a **suspected setup/load-order
  compatibility issue**, not a proved runtime bug or reason to change
  runtime/admission in this task. Repro: the documented default Campfire
  build followed by `lowrail verify ... -- bundle exec rails test:system
  --seed 41231` with the recorded load-census/browser environment. All raw
  identities and controls are retained; no retry, exemption or fix follows.
* **Fizzy plain baseline:** five Vips loader-policy failures; four webhook
  errors calling `CGI.parse`, which is absent in this bundle's Ruby-4 load
  state. Writebook has four of the same Vips policy failures and one
  `URI::Generic#request_uri` error in the unpublishing/upload authorization
  test. These identities already fail without Lowrail. Installed libvips
  is Debian 8.14.1; no system library/app shim was changed to hide failures.
* **Fizzy SQL/load controls:** the verifier runs at most one extra off and
  one extra on arm, not an open-ended rerun loop. All 316 non-system SQL
  exclusions reproduce in the off/off pair. Browser controls have 10 SQL
  exclusions and 153 sequence-sensitive load-event entries; nine SQL
  exclusions reproduce off/off immediately. Two additional fixed off-only
  full-browser arms both pass 42/42, but **do not reproduce** the remaining
  Mermaid-refresh SQL variant. Its own-thread digest is `c6e414a3...` in all
  four off arms and the on-control, versus `68a874ee...` in the first on arm;
  all counts are 396 and other-thread digests match. Four load-event
  sequence/holder entries also have on/on-only, not off/off, evidence;
  three affect the raw off/on comparison, one only the on/on advisory set.
  The other 149 reproduce off/off. Constants, Zeitwerk paths and on_load-hook
  sets match; the raw differences are event sequence entries. The appendix
  names every unresolved entry.
  **The verifier exits 0 after its finite classifier, but those five entries
  are not certified app nondeterminism or a proved Lowrail bug here.** No
  further reruns, new exemptions or runtime changes are made to get green.
  Five browser other-thread SQL digest differences are advisory, not removed.
* **Writebook JIT diagnostic:** its default build boot enables YJIT, while
  test startup can be interpreter before Rails enables YJIT later. The
  receipt records the exact admission mismatch and both observed modes;
  zero units/hits still mean no-op compatibility, not successful delivery
  of optimized code. This is not a JIT-flat check or a speed claim.
* **Invalid harness cohorts:** the first Fizzy/Writebook browser attempts
  overlapped their own non-system verifier against the same SQLite files.
  Busy/constraint errors and those verifier receipts are retained as
  **invalid**, not attributed to Lowrail. One serialized replacement per
  app/suite follows completion; no overlapping process touches its DB.
  Reloading an already-populated Writebook schema also failed its foreign
  keys, including a same-process drop/create/load attempt. A new process
  against the owned, empty disposable SQLite files loads it successfully.
  No schema/config/test patch or SQL/load exemption was introduced.

## Public sealed build attempts

The command is `lowrail build APP --sealed --env production --jit interpreter`,
with a disposable production database and `SECRET_KEY_BASE_DUMMY=1`, never
an admitted production deployment. A build that stops before a builder runs
is **not** reported as that builder's successful refusal.

| App | Public build outcome | Meaning |
|---|---|---|
| Campfire | Exit 0; all four 8.1.4-pinned sealed units refused; one separate `memo/sha256` unit emitted | That Ruby/Digest-only memo is unexecuted/unverified here, not 8.2 sealed certification |
| Fizzy | Exit 0, zero units/files; four explicit 8.1.4 sealed version refusals | Successful refusal, not successful lowering |
| Writebook | Exit 1 before oracle boot: `The Redis cache store requires the redis-client gem version 0.28.0 or later.` | Its upstream/frozen lock has redis-client 0.22.2; production boot cannot reach sealed builders. Not a Lowrail compatibility bug or an 8.1.4-source refusal. |

The source-level 8.2 refusals remain exact: sealed link requires
`sealed pilot requires production Ruby 4.0.7 / Rails 8.1.4 blog`; form,
token and collection require `requires production Ruby 4.0.7 / Rails 8.1.4 blog`.
An alpha version number alone never admits changed sources. The known older
Prism `version: "current"` build issue was fixed by the Campfire thread in
the commit above, not duplicated or bypassed here. Build inventories are not
published units or hits.
Campfire's emitted memo file is `app/controllers/concerns/inline_script_hashes.rb`;
the default artifact used by both verifies remains the archived **zero-unit**
build, not this later sealed artifact. No sealed app suite is run or claimed.

Fizzy's other opt-in builders also decline: 74 instantiate `NameError`,
218 preload `NoMethodError`, and 16 AR-plan errors naming removed
`join_primary_key` on has-one/has-many reflections. These are ledgered
unsupported build boundaries, not default-run crashes or admitted 8.2 units.
Writebook's plain, no-preload production runner fails the same Redis
requirement, independently of the Lowrail oracle.

## Early-warning source inventory

[`script/rails-drift`](../script/rails-drift) reads two immutable Git trees
without booting either Rails or an app. All **15 registered pass families**
have evidence pointing to the builders' manifest `sources`, method facts or
closed inventories. A registry change refuses the script until its inventory
is reviewed. It compares the complete `lib` source envelopes for the Rails
components those facts use, including generated-method macros/constants,
Rails version constants and ERB templates. **These are conservative supersets,
not counts of actually reachable dependencies.**

The form/token/collection stock certificate itself hashes all Ruby source in
five Rails gems: restricting its audit to a few familiar helpers would miss
real certificate invalidation. Other broad envelopes deliberately over-report
unrelated changes instead of claiming a complete dynamic dependency analysis.
Each file has both SHA-256s, status and full diff; every lexical method,
constant assignment and generating macro has unchanged/changed/removed/added
status and before/after lines. Moved definitions appear removed at the old
holder and added at the new one, **not necessarily as an API removal**.
Whole-file hashes also cover inheritance, require order and generated bodies
that static member names cannot resolve. No whitespace/comment normalization
weakens the source certificates. The generated
[JSON inventory](rails-8.2-drift.json) and [short table](rails-8.2-drift.md)
are separate from the app result appendix.

### Decision-bearing drift, by unit

| Unit | Source status / concrete difference | Stage-2 action |
|---|---|---|
| `view/link_to` | Changed; `UrlHelper#link_to` removed from old holder, added under `NavigationHelper`; TagBuilder attribute append pipeline changed | Re-certify; quarantine remains |
| `route/path` | Changed; OptimizedUrlHelper accepts a sole `format`, `optimized_helper(args, format = nil)`, shareable helpers/routes; `parameterize_args`, Journey `format`/`required_parts` unchanged | Re-certify; quarantine remains |
| `memo/uri_join` | No Rails source dependency; URI/parser/Ruby certificate outside this diff | Recheck external sources/app admission, no inferred support |
| `memo/sha256` | No Rails source dependency; Digest/Ruby certificate outside this diff | Same |
| `digest/file_memo` | No Rails source dependency; File/Digest/Pathname/external-gem sources | Same |
| `active_record/preload_plans` | Changed AR/AM/AS source envelope, reflection/relations and generated attachment scopes; whole-source diffs retained | Re-certify complete model/association/type facts |
| `active_record/instantiate` | `attributes_builder` now delegates through `schema_context.attributes.builder`; `_load_from_sql` and `instantiate_instance_of` bodies unchanged, their source files changed; new SchemaContext dependencies | Audit new exact source pin/closure, never just add its hash |
| `active_record/ar_plans` | Changed query/planner/adapter/Arel and reflection source envelope, including SchemaContext changes | Re-certify planner/adapter/visitor/reflection closure |
| `inertia/config_bind` | `Hash#extract!` body unchanged; its file changed (documentation); broad AS envelope also changed | External Inertia/Ruby certificates still required; no new admission |
| `inertia/props` | No Rails source dependency; Inertia and native iterators are the certificate | External/app checks, not automatic 8.2 support |
| `endpoint/action` | Changed controller/view/template envelope and moved link helper | Re-certify; existing app/version boundary remains |
| `sealed/link_to` | Changed `STOCK` sources; tag options/escaping tables and moved helper owner; `content_tag_string` body unchanged | Re-certify sources, holder identities and literals |
| `sealed/form_scaffold` | Full five-gem STOCK inventory changed; `form_with` body unchanged does not rescue the certificate | New exact inventory, generated readers, app template/config/schema/I18n and passive admission checks |
| `sealed/token_tag` | Inherits full changed form inventory; token helper moved to NavigationHelper, tag attribute path changed | New token/escaping/holder certificate |
| `sealed/collection_render` | Inherits changed inventory; `collection_with_template` gains `&block`; new eligible shared-output-buffer path bypasses per-item rendered objects | New renderer/residue/events/notification certificate |

`PRE_CONTENT_STRINGS` and other literal tables have their own changed entries.
The full JSON keeps removals, unchanged members and added paths, not just this
selection. App templates, route defaults, schema/config, external I18n/gems
and Ruby/native facts are **outside the Rails-tree comparison** and remain
separate mandatory certificates. An unchanged byte slice is not proof of
unchanged resolution, visibility, state or mid-request behavior.

## Reproduction and refresh

```sh
# Fresh dependency-only app copies; existing 8.1.4 entries are separate.
script/corpus campfire-r82
DATABASE_ADAPTER=sqlite script/corpus fizzy-r82
script/corpus writebook-r82

# Inside each app: run suites SERIAL, never two processes against its SQLite DB.
env -u RUBYOPT LOWRAIL=0 RAILS_ENV=test PARALLEL_WORKERS=1 MT_CPU=1 \
  BUNDLE_FROZEN=true mise exec ruby@4.0.7 -- bundle exec rails test --seed 41231
# Then from the Lowrail repo (binary and native extension already built):
SEED=41231 PARALLEL_WORKERS=1 MT_CPU=1 LOWRAIL_VERIFY_LOADS=1 \
  mise exec ruby@4.0.7 -- target/release/lowrail build .corpus/campfire-r82
SEED=41231 PARALLEL_WORKERS=1 MT_CPU=1 LOWRAIL_VERIFY_LOADS=1 \
  mise exec ruby@4.0.7 -- target/release/lowrail verify .corpus/campfire-r82 \
  -- bundle exec rails test --seed 41231
# Repeat plain + verify with `test:system`, preserving each receipt first.
# SE_BROWSER_PATH points to the installed Chrome-for-Testing executable.

# Source-only input, when this clone does not yet exist:
git clone --filter=blob:none --no-checkout https://github.com/rails/rails \
  .corpus/rails-8.2-source
git -C .corpus/rails-8.2-source fetch origin tag v8.1.4
git -C .corpus/rails-8.2-source fetch origin 36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e
# Refresh by fetching deliberately and recording a new exact SHA, then:
mise exec ruby@4.0.7 -- ruby script/rails-drift .corpus/rails-8.2-source \
  v8.1.4 36e0f96b9d7a022755a53a2a9fb7a67ad4e3669e docs/rails-8.2-drift
mise exec ruby@4.0.7 -- ruby bench/rails_drift_test.rb
```

Use dedicated disposable Redis for Campfire's Cable/Resque, and the app's
SQLite OSS adapter for Fizzy. No external services, shared DBs or credentials
are required for these test fixtures. Do not rerun a rejected cohort until
green or reuse old receipts for a new lockfile/source pin. The scanner's
regression check distinguishes changed constants/methods, removals, additions,
ERB deletion and a changed source certificate with an unchanged method body.
