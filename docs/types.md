# Boot-first types and MCP

Target: Ruby 3.4+ (development pins 4.0.7), Rails 8.1+.

Latest breadth check: [six-app slot ledger, ranked unknown causes and next-bet
estimates](types-breadth.md), with a real source-checked Fizzy MCP session.
It recovers 329 existing unknown slots as advisory static types; the blog stays
2/99/7/188. This is not a whole-app typing or runtime-support claim.

Next: [framework contracts and own-suite observed arguments](types-contracts.md)
recover 442 static slots and sample 843 previously unknown argument slots across
the same six workloads. The ledger separates static facts, partial failing-suite
evidence, unknown container members and all 13 investigated return flags.

Current: [types usefulness](types-usefulness.md) keeps the five-app denominator
fixed, samples bounded collection members, checks generated RBS with Steep,
and replays 100 independently grounded questions against real stdio MCP.

```sh
script/corpus real-blog
cargo run -- facts .corpus/real-blog
lowrail types --rbs .corpus/real-blog > /tmp/lowrail-app.rbs
cargo run -- types .corpus/real-blog --rbs .corpus/real-blog/sig/lowrail
rbs -I .corpus/real-blog/sig/lowrail validate
```

`types` reads existing `.lowrail/facts.json`; it does not boot or modify the
app. Stdout is a JSON object with a `methods` map keyed by `Class#method` or
`Class.method`, and source-read/parse diagnostics. Every return/parameter type
has a `name` (RBS notation) and `provenance` entries with `source` and `detail`.
Sources are `boot_fact`, `schema`, `rails_api`, `sorbet sig`, `inference`, and
`observed`. Existing `.lowrail/observed.json` samples are merged **after** static inference, never
fed back into it. Types remain advisory unless explicitly proven within an
analyzed body; a lowering consumer must still certify its execution context.

## Observed types

```sh
lowrail verify APP --observe-types
lowrail verify APP --observe-overhead # also one enabled/no-recorder control
lowrail observe APP --samples 16 --overhead # full definition/script census
```

Verify records only its first **on** run, using targeted method TracePoints,
not a global call hook; a global **raise** hook tracks exception-tainted
activations. The lightweight mode omits script capture and the all-module
definition census. The default cap is 16 sampled entries per method per
process (`LOWRAIL_OBSERVE_SAMPLES`); args are sampled at entry and receiver
ivars at accepted return events. In-flight calls drain before a capped hook
retires. Missing ivars are not nil observations. Sampling never calls
the object's own reflection/enumeration methods or runs SQL. Exact built-in
Arrays/Hashes supply at most eight entries per value, one level deep, using
bound native methods; subclasses and relations are never enumerated. Empty
containers give no member evidence. Member histograms remain observed and
cannot narrow a static generic; sampled contradictions remain conflicts.
Counts, calls, cap/saturation and raw class names survive in `observation`;
each typed slot also retains its class histogram in `samples`. Saturation
means **recording stopped**, not exhaustive coverage. Exceptions, recursion,
threads and uncalled methods can leave incomplete samples.

Ruby emits nil `:return` events during exception unwinding, sometimes after
`$!` has been cleared. The recorder taints active sampled frames when a raise
occurs in their fiber, including raises in untraced callees. Tainted nil events
are omitted, with an `exception_tainted_returns` counter; non-nil events and
entry arguments remain usable. This conservatively loses some genuinely
rescued normal nils. An ambient exception handled before a call does not
taint that new activation. Non-exception `throw`/non-local exits remain a
separate sampling limitation.

Merged observations attest `return_sampling: exception_tainted_nil_omitted_v1`
only when every process used that policy. Regenerate legacy observations;
old or mixed files cannot be retrospectively cleaned. The historical
[six-app argument experiment](types-contracts.md) remains argument-only.
The fresh [five-app return experiment](types-returns.md) publishes 1,864
observed return slots after classifying and withholding compatible raw flags.

Observations fill `untyped`, or annotate a static type without narrowing it.
A contradicting sample creates a `conflicts` row with method, slot, static
type, class and count; the original static contract is preserved in that row
and body proof withdrawn, even when the displayed answer adds possible nil.
`String?` plus String-only samples stays `String?`. Anonymous classes stay
`untyped`; model-specific Rails relation class names are rendered as advisory
`Relation[Model]`, not evidence about loaded elements. Regenerate facts and
observations after source changes; no source-freshness certificate is implied.

### Return nullability is separate from sampled classes

Every serialized type also has `nullability` and a human-readable
`nullability_note`, including `type_of` with/without a slot,
`type_at_position`, typed-facts JSON and RBS evidence comments.

| Nullability | Meaning |
|---|---|
| `nullable` | A static contract/possible return path allows nil, or nil was sampled at least once. A known candidate name is displayed with nil included. |
| `non_nil` | Non-nil on normal completion **under the advisory static contract**, not a runtime certificate. |
| `observed_nil_not_excluded` | **Observed, nil not excluded.** The name describes sampled classes, not an exhaustive non-nil return contract. Saturation never changes this. |
| `unknown` | No complete contract; nil is not excluded. |

A separate bounded may-nil walk retains missing `if`/`unless` branches,
early returns (also inside unsupported blocks), safe navigation and
short-circuit returns even when the full body cannot be typed. Nullable
column/finder contracts remain nullable. This does **not** infer a complete
return type, feed observations into inference, upgrade evidence, change
slot identities/statuses, or suppress contradictions. Nil nested inside an
Array/Hash is not confused with a nullable outer container. The Rust candidate
and conflict contract remain unchanged; JSON and RBS signatures include any
additional known nil possibility. Unmodeled bodies remain explicitly sampled
or unknown, never silently non-nil.

## Typed-facts build API (format 1)

Before builders run, `lowrail build` writes `.lowrail/typed_facts.json` and
includes the same object as `units.json["typed_facts"]`. It contains `format`,
`methods`, `conflicts`, `diagnostics`. No existing lowerer consumes it yet.
Rust callers use `TypeModel::fact(target, slot)`; Ruby builders can read
`methods[target]["return_type"]`, `["parameters"]` (find by name), or
`["ivars"]["@articles"]`. Slots are `return`, `arg:name`, `ivar:@name`.
Every type has `name`, `provenance`, `evidence`, and `samples`:

| Evidence | Consumer contract |
|---|---|
| `proven_body` | Literal/local assignment proof **within the analyzed method body**. No value-class check needed there; still certify the unchanged effective method/source and execution context with the normal pass guard. `proven_type()` returns the name only for this case. |
| `static` | Schema, boot catalog, declared Sorbet sig, or call-based inference. Needs method/schema/config certificates and, when applicable, live value checks. Storage nullability is not a Ruby-object invariant. |
| `observed` | Sample-only type. Needs a live value/shape check and the usual semantic certificates; never returned by `proven_type()`. |

Per-method ivars describe exit state, not view-entry dominance. Calls kill
static ivar knowledge because they can mutate the receiver. An observed
Article argument does **not** prove stock AR `to_param`; use the resolved
boot method plus a live lookup/epoch certificate. This API supplies type
candidates, not a method-implementation certificate or a runtime guard.

Roundhouse reference: its `Ty` lattice and post-fixpoint `MethodDef.signature`
stamping keep consumers consistent; its call-site "observations" are static,
not runtime samples. Lowrail likewise keeps provenance/counts outside the
type union and proof separate from precision.

## What is modeled

- Columns seed nullable reader types (`String?`, `Integer?`, `bool?`,
  `BigDecimal?`, `Date?`), including primary keys: even a `NOT NULL` column
  can be unset on an unsaved record. The storage `null` fact is retained in
  provenance, not mistaken for a Ruby-object invariant. Time columns allow both
  `Time` and `ActiveSupport::TimeWithZone`, because the dump does not pin time-zone-aware
  attribute configuration. Unknown/custom/JSON types stay `untyped`. Schema
  nullability describes storage, not the state of every unsaved Ruby object.
- Attribute API readers are nullable, because the facts do not capture their
  defaults. Aliases copy the underlying type. Writers accept and return
  `untyped`: Active Record casts inputs, and a writer invoked with `send`
  returns the input, not necessarily the cast reader value.
- Singular associations are `Target?`, even for required `belongs_to`:
  presence validation does not guarantee an association on an unsaved object.
  Collections are `ActiveRecord::Associations::CollectionProxy[Target]`.
- Common AR query class methods and booted named scopes return
  `ActiveRecord::Relation[Model]`. Prism recognizes literal `scope :name` and
  `enum :name` declarations in the model's source file. Enum readers are
  `String?`. The boot census's generated enum module also supplies predicates
  (`bool`), with actual prefix/suffix names, including non-identifier labels.
  Bang methods and enum-generated scopes/mappings are not newly inferred.
  Owner/source-matched `where` calls distinguish the zero-argument WhereChain
  from a Relation with conditions; `exists?` returns bool. Block-form `unscoped`
  is not seeded: it returns the block's result.
- Controller actions and method-based `before_action` callbacks have roles
  in the model. Their returns remain `untyped` unless a simple body is known;
  an action is not assumed to return the HTTP response.
- Each named route gets `Lowrail::RouteHelpers#name_path` and `#name_url -> String`,
  included in the exported controller declarations.
  Parameters are permissive because route facts do not describe the full
  polymorphic/positional/keyword calling convention.
- Source-matched Sorbet wrappers recover adjacent `sig` declarations and the
  original `def` parameter shape with Prism, including inherited controller
  copies. Known class names, Boolean, nilable/unions, arrays/hashes and bounded
  static type aliases are advisory `static`, source **`sorbet sig`**, never
  proof. Unsupported expressions remain `untyped`; `void` does not constrain
  the Ruby result. No sig block or application method is executed.

Boot method parameters replace guessed parameter lists where available;
owner/source-matched Rails API signatures replace generic delegation shapes.
Prism matches boot source locations and original method names, then propagates
simple literals, attribute/association reads, ordinary calls and local/ivar
assignments through up to eight synchronous return-inference rounds. Custom
reader bodies take precedence over schema seeds. Bounded conditionals join
both arms (including nil for a missing arm); containers keep unknown members
untyped, and interpolation returns String on normal completion. These compound
results are static, not proof. An unknown value need not hide a known sequence
tail, but advisory predecessors withdraw the tail's body-proof label. Unknown
control flow, blocks, safe navigation, splats, forwarding and recursive unknowns remain
`untyped`. Argument values are not inferred; a bounded argument grammar rejects
nested control flow, and argument-bearing calls discard local/ivar knowledge.
This is not whole-program parameter inference, controller-to-view ivar flow,
or validation of source freshness. Regenerate facts after changing the app.

## RBS output

`lowrail types --rbs APP` writes standalone RBS to **stdout**, without changing
the app or booting Ruby. It concatenates the support declarations followed by
the app declarations. The existing `lowrail types APP --rbs OUT_DIR` interface
still writes separate `OUT_DIR/app.rbs` and `lowrail_support.rbs`, with the
type model as JSON on stdout. Both use the same renderer as MCP `export_rbs`.
Output is deterministic for the same facts, source and observation snapshots.

For workloads that must not contain Lowrail output, collect facts externally
and use `lowrail types APP --facts EXTERNAL_JSON --rbs EXTERNAL_DIR`. The facts
loader still resolves paths from the facts file's recorded app root; no boot
or app write is performed. Observations, if any, are read from APP as before.

Each **slot**, not the whole signature, has a JSON RBS comment:

```rbs
# lowrail return: {"status":"static","scope":null,"sample_count":0,"fact":{"name":"String?","provenance":[{"source":"schema","detail":"articles.title: type=Some(\"string\"), null=true"}],"evidence":"static","samples":{}}}
def title: () -> String?
```

| Slot status | Meaning |
|---|---|
| `proven` | Existing `ProvenBody` evidence, with an explicit **body-local** scope. This does not certify effective lookup, unchanged source or the surrounding execution, much less a whole signature. |
| `static` | Advisory schema, boot catalog or inference; original sources/details are retained. Schema nullability is a storage fact, not an invariant of every unsaved Ruby object. **Static is not certified.** |
| `observed` | Sample-derived type. `sample_count` and the original class histogram remain visible; neither finite samples nor saturation prove exhaustive coverage. |
| `unknown` | `untyped`, including unknown/custom types and unsupported bodies. No guessed value or element type. |

Comments and MCP JSON use exactly the same slot object. Static slots may also
have samples, without becoming observed-only or narrowing their static type.
Contradictions stay in `conflicts` and withdraw body proof. Parameters use
`arg:NAME` slots, including untyped rest/block parameters; RBS block input and
return types stay untyped. There is **no whole-signature status**.

### Per-app slot coverage

`types APP` JSON (format 1), MCP `export_rbs`, and the `# lowrail coverage:`
comment in `app.rbs`/standalone stdout contain the same `coverage` object:
`{"proven":2,"static":55,"observed":11,"unknown":176}` for the blog snapshot
below. Count each modeled return and argument slot once, not its sample
multiplicity; exclude ivar facts, roles, support stubs and unmodeled methods.
Counts include modeled receivers that cannot be declared in RBS; those still
have explicit export diagnostics. All four keys are present even at zero.
This is coverage of the existing type model, including its framework entries,
not a fraction of all app behavior or a lowering certificate. Static plus
samples still counts as static. The table below reports these disjoint slot
counts, unlike the older overlapping source counts in the quality ledger.

MCP `export_rbs` takes no arguments and returns `format: 1`, `coverage`, `files` (the two
RBS filenames mapped to content), `signatures` (method IDs mapped to `rbs`
and `slots`), `diagnostics`, and `conflicts`. It reads the server's existing
facts/samples, refreshes on content changes and never writes files. For example:
`{"name":"export_rbs","arguments":{}}`.

The support file supplies a bounded, boot-owner/source-matched real-Rails API
catalog for relation chains, controller parameters and common macro/call shapes,
plus minimal TimeWithZone, Date, BigDecimal and Tempfile declarations and name-only stubs for
namespaced external classes introduced by observations (e.g. strong parameters
and safe strings). Array, Hash, Set and Queue samples do not infer element
types. Namespace class/module kinds come from boot facts even when the namespace
has no modeled methods. Empty app helpers/classes and actual superclass chains
are declared from boot facts. Omit the support file when loading full Rails/stdlib
signatures. This is generated member information,
not a complete Rails signature distribution. Existing files with these two
names in the chosen output directory are overwritten; other files are left
alone. Tests invoke `rbs validate` when the executable is available.

Unrepresentable receiver names such as `Pagy.ancestors[0]` remain explicit
export diagnostics, not invalid RBS declarations or invented constant names.
The JSON type model still preserves the original entries.

### Export validation — 2026-10-21

Ruby 4.0.7 / RBS 4.2.0: both split files and concatenated stdout parse with
`RBS::Parser.parse_signature`; split exports pass `rbs -I DIR validate`.
The real MCP text/structured output round-trips, its files equal the legacy
file export, and their concatenation equals `types --rbs APP` byte for byte.
The coverage follow-up rechecks these equalities, the JSON/RBS/MCP counts,
parsing and validation on both apps. All exports and logs are outside the
source apps. This is signature validation, not a complete Rails type check.

| App | Exported signatures | Proven / static / observed / unknown **slots** | Diagnostics / conflicts |
|---|---:|---:|---:|
| Rails 8.1.4 blog (`real-blog-r4`) | 161 | 2 / 55 / 11 / 176 | 0 / 0 |
| Wikino Rails 8.0.5.1 ([pinned source](https://github.com/wikinoapp/wikino/commit/25255d2d6c808df6672e293661ea797a76c6d2a9), `rails/`) | 1,436 | 0 / 367 / 1 / 3,707 | 38 / 0 |

Observations: `LOWRAIL=0`, types-only recorder, four samples/method, seed
41231, one worker. Blog: 21 tests/54 assertions pass, 13 sampled methods;
Wikino: **11-example subset** (topic card component and attachment processing
service), all pass, two sampled methods. These are bounded untimed inputs,
not measured cohorts, exhaustive type coverage or lowering support claims.
The blog's first merge correctly refused a legacy facts snapshot from a
different root; a fresh facts dump was used, not rewritten evidence.
Wikino's 38 existing raw-ERB inference diagnostics remain visible; no ERB
type is fabricated to silence them. Regressions cover a schema reader,
observed return/argument counts, body-local proof, unknown helper slots,
contradictions, invalid receiver diagnostics and read-only MCP refresh.

### One disposable Steep check — non-gating

Steep **2.1.0** and RBS **4.2.0** installed cheaply in a separate temporary
bundle on Ruby 4.0.7 (24 gems). Ran **once**, with the generated blog RBS and
unchanged copies of `app/models`, `app/controllers` and `app/helpers`:

```ruby
# Disposable Steepfile, not an app or repository configuration change
target :blog do
  signature "sig" # generated app.rbs and lowrail_support.rbs
  check "app/models"
  check "app/controllers"
  check "app/helpers"
end
```

`bundle exec steep check -j 1 --no-daemon` exits **1: 51 problems in 9 files**:
42 `Ruby::NoMethod`, 8 `Ruby::UnknownConstant` warnings and 1
`Ruby::UnexpectedPositionalArgument`. Missing declarations include Rails base
classes, macros, `params`, `render`, relation methods and inherited AR
construction; the positional-argument error is `Article.new(article_params)`
without its Rails constructor signature. Empty helper modules have no modeled
members/declaration. Generated member information and name-only support stubs
are not a Rails RBS distribution. No signatures were invented, warnings
suppressed or Rails collection installed to make this check pass.

This is an integration limitation, **not a passed source type check**, and
does not change the successful RBS parse/validate results. Steep is not a gate
or repository dependency. The original install/check logs and exit status
remain in `.lowrail/private/type-export/followups/steep-{install,check}.log`
and `steep-exit.txt`; disposable bundle/source copies are removed afterward.

### Rails API follow-up — 2026-10-21

Reused the **same facts and observations**, not a fresh recording. The runtime
gem and lowering are unchanged; no benchmark, Callgrind or measurement
cohort was run. Ruby 4.0.7, RBS 4.2.0, Steep 2.1.0.

The complete original blog unknown ledger is:

| Cause | Unknown slots |
|---|---:|
| Framework/engine controller and callback returns | 78 |
| Framework arguments (`send_stream`, live-stream configuration) | 8 |
| Casting writer inputs/results | 26 |
| Primary-key readers (previously rejected stock AR owner) | 2 |
| Query delegation arguments | 32 |
| Permissive route arguments | 30 |
| **Total** | **176** |

Empty app helpers were **unmodeled**, not hidden unknown slots. App action
returns already had body/observation evidence; no controller-to-view dominance
or helper types are invented. The full Wikino ledger (not just a sample) finds
**2,079 argument + 693 return slots behind Sorbet runtime wrappers**, 336
casting writer slots, 334 query/scope arguments, 178 other framework returns,
36 route arguments, 18 primary-key readers, 19 other framework arguments,
7 other singleton returns, and 3 app arguments/4 app returns. In particular,
`ControllerConcerns::Authenticatable#current_user_record` and its inherited
controller copies resolve to `sorbet-runtime/.../_methods.rb`, not their app
body locations. Declaring those returns from names would be guessing.

Roundhouse references: `src/ingest/model.rs` (`ty_of_column_slot`,
`expand_enum_decl`), `src/lower/model_to_library/schema.rs` (readers and
constructors), [`src/catalog/mod.rs`](https://github.com/rubys/roundhouse/blob/main/src/catalog/mod.rs)
(class/relation receiver contexts), and
`src/lower/controller/actions.rs` (callback/view flow). Reuse its bottom-up
schema → framework API → caller propagation, **not** its replacement-runtime
RBS: real Rails returns CollectionProxy/Relation, casts writer inputs, allows
nil on unsaved records, and overloads `find` for arrays and blocks.

Added the bounded catalog in `src/types/rails.rs`: advisory `rails_api` facts
name the gem/version, source file and resolved boot owner. Stock AR `new`
accepts optional attributes and a block; block-free `find` returns
`Model | Array[Model]`, and `find_by` is nullable. Constructor, query and
generated enum-predicate types propagate into simple callers; calls never
promote callee facts to body proof. Custom owners/bodies win. Versions outside
Rails 8.0/8.1 or replaced source locations do not receive these API facts.
Anonymous model ancestors retain their boot order; ambiguous erased holder
identities leave enum predicates untyped rather than skipping a possible override.
`render`, parameter extraction, macro results and wrapped `redirect_to` retain
`untyped`; known call shape is useful without pretending to know its result.
No upstream RBS distribution is imported or installed in the app. Full
collection import, enum mappings/bang methods and controller-to-view flow
remain follow-ups. The next section records Sorbet and callback-self recovery.

| App | Signatures before → after | Proven/static/observed/unknown before → after |
|---|---:|---|
| Blog | 161 → 167 | 2/55/11/176 → **2/69/7/158** |
| Wikino | 1,436 → 1,504 | 0/367/1/3,707 → **0/471/1/3,545** |

Denominators change: blog has **4 existing unknown slots → static**, 4
observed returns → static with samples retained, and 6 newly modeled typed
returns. Wikino has **36 existing unknown slots → static** and 68 new typed
returns. The rest of the unknown reduction is accurate query-delegation shape
(including zero-argument `none`), **not recovered argument value types**.
Support-file members are excluded from these counts as before. Proven counts
are unchanged; both apps retain zero conflicts and pass `rbs -I OUT validate`.
Wikino's 38 raw-template diagnostics remain visible.

On unchanged copies of the same blog models/controllers/helpers and the same
Steepfile above, the old export reproduces **51 problems** (42 `Ruby::NoMethod`,
8 `Ruby::UnknownConstant`, 1 `Ruby::UnexpectedPositionalArgument`). The new
export has **6 `Ruby::NoMethod` problems in 4 files**, exit **1**, no unknown
constants or constructor argument error. Remaining: Turbo `broadcasts_to`
(2), callback block-self `article` (2), Importmap
`stale_when_importmap_changes` (1), controller route mixin `articles_path` (1).
These are still limitations, not a green Steep gate; no warnings are suppressed.
Exports, exact input snapshots, complete unknown ledgers and before/after
Steep logs are retained privately in `.lowrail/private/type-sources/`.
`cargo test --locked`: **47 passed**. Affected gem tests (`facts`, `materialize`,
`observe`, strict mode, seed 1729): **21 runs, 246 assertions, 0 failures/errors**,
one named optional skip (`MaterializeCorpusTest#test_campfire`, app absent).
Both apps' real MCP exports equal the split CLI files and standalone stdout.

## Sorbet and framework signatures follow-up — 2026-10-21

Same unchanged facts/observation snapshots and corpus revisions as above;
Ruby 4.0.7, RBS 4.2.0 and Steep 2.1.0. This is advisory type tooling only:
runtime loading, guards and lowering are unchanged. No measurement cohorts
were run. Public source contains no app snapshots or private logs.

Prism recovers **all 693 original wrapped Wikino methods**, using declared
sigs rather than method names or wrapper bodies. Of their original 2,772
unknown slots, **517 return slots become static**; the other **176 returns
remain unknown** (110 explicit `T.untyped`, 66 `void`). Their **2,079 wrapper
forwarding placeholders disappear**, replaced by **136 real, statically typed
arguments**. Placeholder removal is a shape correction, not 2,079 recovered
argument value types. Another **397 previously unmodeled declared methods**
become visible. Across all 1,090 recovered signatures, **777 returns + 431
arguments = 1,208 slots** have static Sorbet types. Sources retain the sig
file/line, expression, alias locations where used, and boot gem version.

The optional boot-registry reader inspects **already-built** entries of
`sorbet-runtime 0.5.12435` only. It does not call `signature_for_method`, run
pending sigs, initialize lazy type objects, require/autoload constants or call
application methods. Raw simple types and original parameters/source survive
as `sorbet_sig` method metadata; other versions/layouts and stale entries are
refused. Source parsing is preferred. **These Wikino gains use Prism alone**
on the existing snapshot; registry recovery is checked with real Sorbet in a
separate subprocess. Sorbet is a pinned **development**, not runtime, dependency.
Checks and declarations are not proof, even with a literal body or runtime
validation enabled. Generic/proc/dynamic forms, missing constants and ambiguous
declarations remain unknown or unmodeled, with provenance/diagnostics retained.
Samples preserve counts and contradictions without mistaking `::String` for
a different class or pretending an Array/Hash class sample describes elements.

Booted named routes supply both path and URL signatures and controller mixins.
Source/version-matched advisory support adds Turbo `broadcasts_to` and
`broadcast_replace_to` (blog **turbo-rails 2.0.23**) and Importmap
`stale_when_importmap_changes` (**importmap-rails 2.2.3**). Results stay
`untyped`. Supported catalog families are Turbo 2.0.x and Importmap 2.1/2.2.x;
overridden owners/sources or other versions do not receive these signatures.
AR 8.0/8.1 `after_create_commit`/`after_destroy_commit` use RBS's explicit
block `[self: ::Model]`, rather than silencing the callback body with `untyped`.

| App | Signatures before → after | Proven/static/observed/unknown before → after |
|---|---:|---|
| Blog | 167 → 197 | 2/69/7/158 → **2/99/7/188** |
| Wikino | 1,504 → 1,937 | 0/471/1/3,545 → **0/1,715/1/1,129** |

Blog's added 30 URL helpers each introduce a static return and a permissive
unknown argument: the denominator grows; none of its old unknown slots is
claimed recovered. Wikino likewise adds 36 URL helpers. Framework support
members are excluded from app-slot coverage as before. Proven counts stay
**2 and 0**, conflicts stay zero, and Wikino's 38 raw-template diagnostics
remain visible. Both apps pass `rbs -I OUT validate`; real MCP and split/standalone
CLI exports agree.

The old blog export reproduces **6 Steep problems / 4 files**, exit 1; the
new export has **2 problems / 1 file**, also exit 1. The remaining diagnostics
are `Comment`'s two callback calls to `article.broadcast_replace_to`: self is
now correctly `Comment`, but `article` is honestly **`Article | nil`**. Article's
Turbo method is declared; nil has none. Even though the app rescues these calls,
Steep still reports them. Do not narrow the association or suppress the errors
to manufacture a green gate. The cumulative change is **51 → 6 → 2**,
still advisory/non-gating.

Validation: `cargo test --locked` **48 passed**; affected gem tests (`facts`,
`materialize`, `observe`, strict, seed 1729) **22 runs / 255 assertions / no
failures or errors**, one named optional skip (Campfire app absent). Disposable
Steep copies are removed; exact inputs, full exports, slot-identity transitions
and logs remain ignored, not published.

## Type quality ledger — 2026-10-20

Ruby 4.0.7, RBS 4.2.0; corpus revisions are pinned in `script/corpus`.
`real-blog-r4` is the generated Rails 8.1.4 blog. Other app labels below map to
`pingcrm`, `redprints-cfp`, `react-starter-kit`, and `campfire` respectively.
These are type coverage measurements, **not** lowering or application support
claims. Only real-blog has the recording-on equivalence gate in this round.

"Methods" counts signatures in `lowrail types`; "boot entries" counts all
method entries across the boot dump, including framework/gem modules, not just
the modeled subset. Return columns count non-`untyped` returns carrying each
source (once per method/source). Sources **overlap** and must not be added.
Conflicts count contradictory method/slot/class rows; each row retains its
sample multiplicity. Zero conflicts does not imply exhaustive observations.

| App | Methods / boot entries | Typed returns | boot_fact | schema | inference | observed | Conflicts | `rbs validate` |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| real-blog-r4 | 161 / 50,496 | 68 | 55 | 11 | 2 | 13 | 0 | Pass |
| PingCRM | 440 / 55,048 | 157 | 90 | 61 | 6 | 0 | 0 | Fail: synthetic `Pagy.ancestors[0]` receiver |
| Redprints | 2,812 / 68,264 | 439 | 278 | 146 | 9 | 81 | 0 | Fail: synthetic `Builder.ancestors[0]` receiver |
| Starter | 234 / 49,722 | 104 | 83 | 13 | 7 | 39 | 0 | Pass |
| Campfire | 3,056 / 61,740 | 991 | 802 | 125 | 56 | 558 | 0 | Pass |

Observed-only returns (previously untyped) are **11 / 0 / 80 / 34 / 535** in
table order. Sampled method counts are **13 / 0 / 81 / 39 / 558**. The two RBS
failures also reproduce with observations absent: the static catalog contains
synthetic non-constant receiver names. They are not filtered away or counted
as valid RBS. The corpus check also caught and fixed class namespaces being
redeclared as modules, Queue generic redeclarations, and missing Set/Tempfile
type shapes introduced by samples.

Observation scope, all with seed 41231 and one worker:

- real-blog: `lowrail verify APP --observe-overhead`; **21 tests**, identical
  outcomes and **125 ordered SQL queries**, **57 hits / 0 fallbacks**. The
  enabled/no-recorder control also matched outcomes and SQL. Recording took
  **2.1861s vs 2.0754s (+5.33%)**, including startup. The preceding 16-sample
  pair was **2.3085s vs 2.0863s (+10.65%)**. These are noisy wall-time pairs,
  not a stable performance estimate or a speed claim.
- PingCRM: `bin/rails test`: **1 test / 1 assertion**, no application methods
  called by this suite. Its empty observed column is a coverage gap.
- Redprints: RSpec excluding `spec/system/**/*`: **50 examples**, green.
- Starter: same non-system RSpec scope: **35 examples**, green.
- Campfire: `bin/rails test`: **634 tests / 3,856 assertions / 2 skips**, green.

The non-blog runs used dedicated `lowrail observe` with
`LOWRAIL_OBSERVE_TYPES_ONLY=1 PARALLEL_WORKERS=1`, capped at 16 samples per
method/process. Refresh a row by regenerating facts, running its stated
observation scope, then `lowrail types APP --rbs OUT` and `rbs -I OUT validate`.
No baseline or diagnostic is suppressed to make the table green.

## Stdio MCP

```sh
cargo run -- mcp .corpus/real-blog
```

The server uses newline-delimited JSON-RPC 2.0 over stdin/stdout (not LSP
Content-Length framing). Stdout is protocol-only. It supports initialization,
the initialized notification, ping, tools/list and tools/call; it never boots
the app or evaluates Ruby. Clients can launch the built `lowrail` executable
with arguments `["mcp", "/absolute/app/path"]`.

Tools:

| Tool | Arguments | Result |
|---|---|---|
| `type_of` | `target`: `Article#title`, `Article.all` or `article_path`; optional `slot`: `return`, `arg:name`, `ivar:@name` | Signature/types, provenance, counts, evidence, conflicts; a slot query includes `proven_type` (name or null) |
| `type_at_position` | `path` inside APP, `line`, `column`: one-based UTF-8 byte coordinates at a method-name token | Advisory def/call return, target/signature/evidence; dynamic receivers, ambiguous contexts and unsupported nodes explicitly unavailable, never guessed |
| `find_definition` | `target`: `Class#method` or `Class.method` | Resolved boot source path/line and origin; generated methods report generator sites, native methods have no source location |
| `callers` | `target`: `Class#method` or `Class.method` | Boot-resolved calls/references in indexed Ruby and fresh templates; callback/delegate/literal reflection kinds, physical `location` and receiver `dispatches`; unresolved candidates separate, always incomplete |
| `view_locals` | `path`: boot template identifier, app-relative path or virtual path | Literal partial-render local names/types, collection/object bindings, strict locals and controller exit-ivar context; changed/missing templates refuse; no callback/dominance guarantee |
| `export_rbs` | none | RBS files and the same per-slot proven/static/observed/unknown evidence as RBS comments, plus diagnostics/conflicts; no writes |
| `method_facts` | `target`: `Class#method` or `Class.method` | Resolved boot method, owner/source/parameters/ISeq kind and existing origin classifier result |
| `model` | `name`: model class | Raw columns, attributes, associations, callbacks; validations if recorded in the facts |
| `routes` | optional `name`, `path`, `controller` substrings (combined with AND) | Matching routes, in route-set order |
| `lowering_ledger` | none | Current `.lowrail/ledger.json`, or an explicit missing-ledger result |
| `lowering_status` | `target`: `Class#method` or `Class.method` | Matched ledger sites and original reasons; `lowered`, `refused`, `mixed`, or `not_recorded` |
| `explain_unit` | integer `id`; optional `dir`, `stats` | Build unit, complete certified facts/payloads, guards, associated ledger sites and recorded counters; typed `outputSchema` |
| `explain_site` | `location`: `path:line`; optional `dir`, `stats` | Exact ledger site(s), associated units, or explicit `left_original/not_recorded`; same typed `outputSchema` |
| `verify_stats` | none | Last completed verify's pass/unit hits and fallbacks, command, equivalence result, recorder overhead and `matches_current_manifest` |
| `diagnostics` | none | Source-read/parse diagnostics and static/observed type conflicts |

`callers` is a **partial reference set**, not a complete caller list. Its
`summary` says this explicitly. Named callback registrations and bodies,
delegates to statically typed receivers or `class`, native literal-symbol
`send`/`public_send` and method references, ordinary lexical blocks and boot
inheritance are indexed. Constructors keep concrete receiver identity:
`Child.new` is not a call of `Parent.new` merely because their native owner
matches. ERB masks retain source coordinates; HTML/comments are not Ruby.
Changed templates and unsupported handlers are unavailable, not stale answers.
Untyped template locals/ivars and dynamic receiver/name candidates remain
unresolved. Callback/delegate/method-reference edges indicate possible dispatch,
not guaranteed execution. Custom block rebinding and unindexed/dynamic code
can add callers; this is not a closed-world graph.

For example, a tools/call request after initialization:

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"type_of","arguments":{"target":"Article#title"}}}
```

Facts and observations are compared by file contents on each data-tool request and the cached
model is rebuilt on changes, even if mtime/size are unchanged. A malformed or
missing facts replacement produces a tool error, never a stale successful answer;
removing observations removes their types, and malformed observations error.
Later requests retry reading the file. The ledger is read for every ledger
request. Changes to source files referenced by boot facts also refresh the type
model. This is not live lookup/source certification: regenerate facts when
definitions, owners or source locations change.
Tool failures use MCP `isError`; protocol failures use JSON-RPC error codes.

Method status matches an explicit method target, or source-file ledger sites
within the actual Prism `def` span resolved from boot facts. It does not
attribute a neighboring method's sites to the whole file. An absent ledger
row means **not recorded**, not a fabricated refusal. Site-level `mixed`
does not claim a whole method was replaced. Template-to-action attribution
is not inferred without an explicit method-target row.

Verify atomically persists `.lowrail/verify/last.json` on completed runs,
including non-identical ones. Pass counters are bound to the manifest captured
before execution. MCP rereads the report and current manifest every request;
build mismatch is visible, not relabeled as current coverage. This comparison
is not a source-freshness certificate. Raw per-unit counters remain available.

Real client check: the official Python MCP SDK **2.3.0** completed initialize,
initialized notification, tools/list, calls to `type_of` (exit ivar with
observed evidence and null proof), `lowering_status`, `verify_stats` (57 hits)
and `diagnostics`, then clean stdio shutdown. `cargo test --test types_mcp`
also launches the real executable over stdin/stdout and validates blog RBS.

The current fact dumper does not record validations or enum mappings. Missing
validations are reported as unavailable, not as an empty validated set.
Diagnostics are not a substitute for the lowering ledger or `lowrail verify`.

## Explain a build, not an inferred promise

```sh
lowrail explain APP                         # current persisted selection, all units/sites
lowrail explain APP --unit 18               # IDs belong to this artifact only
lowrail explain APP --site app/views/articles/show.html.erb:42 --json
lowrail explain APP --pass active_record/instantiate
lowrail explain APP --dir .lowrail-other --stats /absolute/stats.json.PID
```

All explanation entry points use one read-only report, with no Ruby process,
autoloads, live guard evaluation, build or test run. `doctor` prints it as
step 6 and saves it in `doctor.json["explanation"]`; the doctor command itself
still boots and runs its normal baseline. MCP returns the same report in
`structuredContent` and text, advertising the
[versioned JSON Schema](../src/explain.schema.json) in `tools/list`.
Example: `{"name":"explain_unit","arguments":{"id":18}}` or
`{"name":"explain_site","arguments":{"location":"app/views/articles/show.html.erb:42"}}`.
Relative `dir`, `stats` and site paths are relative to APP in both CLI and MCP.

`location.origin` distinguishes a ledger's source site (`ledger`) from an
exact target's recorded constant or method definition (`boot_constant` or
`boot_method`). The latter are definition context, **not claimed call sites**:
CRM's class-level instantiate refusal can be queried at `Contact`'s definition
line, but is not attributed to neighboring definitions or every line in its
file. An unrecorded lookup has origin `query`; unavailable locations are null.

The report joins existing manifest/ledger artifacts and uses **`facts::load`**
for both fact formats and their shared typed path resolution. It does not
duplicate Ruby's compatibility/admission validator or turn advisory types
into certificates. `certified_facts` and `certificates` are the unit's actual
recorded payloads; the dump's `yjit` flag is shown separately from the
manifest's authoritative **`certification_jit`**. Guards distinguish admission,
the sealed contract, activation and call-time checks; they are descriptions,
not a new certification engine.

`activation_refusal` is the **current runtime policy**, separate from that
historical build decision and its counters. The form certificate remains
build-eligible but currently refuses production activation because its
controller/view/I18n/ERB recertification would change app behavior. This reason
is shown even without stats, in CLI, doctor and MCP. Recorded stats also retain
`unit_refusals` by unit ID (including intentional 0/0 with no installed variant);
stale/unbound stats are still labeled, not attributed as current activation.
Link admission requires app-owned objspace loading and an already-cached view
class; it never materializes either. See [the readiness fix](sealed-verification.md#current-runtime-passive-admission-or-explicit-refusal).

Site states describe the **build**, not whether the running app activated it:

- `lowered`: a lowered ledger site maps to an emitted manifest unit.
- `refused`: preserves the ledger's pass, reason code and full detail (CRM's
  unaudited Rails 8.0 instantiate is `rails_implementation`). Refusals have
  sites, not invented unit IDs.
- `ledgered`: warning/survey metadata remains visible, not relabeled refusal.
- `left_original`: `not_recorded` at an unrecorded queried location, or
  `not_emitted` when ledger eligibility did not produce a manifest unit.
  The original ledger row/copies remain available; neighboring refused sites
  do not inherit a lowered unit's counters.

New builds record the exact `selected_passes`, including an empty selection.
Older artifacts report selection **unknown**, never guessed from units or
whole-pass quarantine rows. Unit IDs (including the pilot's form unit 18)
can change when a build emits different earlier units. Source/guard freshness
is not implied by any explanation.

By default counters/JIT observations come from `.lowrail/verify/last.json`.
They attach to units only if its captured manifest equals the current raw
manifest. A mismatch is `stale_manifest`, with raw counts retained separately;
an explicit runtime Stats snapshot is `unbound_snapshot`, likewise not silently
attributed to current IDs. A matching report is `current_manifest`, still a
historical snapshot rather than a live guard check. Missing stats yield null
counts, **not fabricated zeroes**. Per-site counts do not exist; site records
link to their unit's aggregate counters.

Whole-artifact `delivery_refusal` and observed runtime refusals remain distinct
from successful build eligibility. `jit_mode_mismatch` is emitted only for an
**observed refusal**, preserving its certification/admission/current modes and
message; a later diagnostic drift is not invented into a refusal. Bundlebun
keeps `bundlebun_load_order`; other runtime messages preserve their detail
under `runtime_refusal`. No compatibility or guard check is weakened.

Regressions cover form unit 18 with its exact-site certificate/guards, CRM's
Rails implementation refusal, mode-mismatch admission, stale/missing counters,
compiler-dropped units, neighboring sites and a typed MCP transport round trip.
An untimed fresh blog build/doctor/MCP check also validates both tool outputs
against JSON Schema and compares CLI/MCP JSON exactly. The current copied
`RealBlog` fixture emits form unit **3**; the older `sealed/link_to` pilot
separately refuses because it requires `RealBlogR4`. The form's two-example
production check has identical outcomes/4 queries but form **0 hits/0 fallbacks**
(no activation claim), with 4 AR hits. The unit-18 schema regression does not
relabel those observations.
Actual interpreter-artifact/YJIT-startup refusal is separately recorded. No
measured cohort or speed/support claim follows.

Follow-up: both probe examples **do render** the show form. With the original
Minitest/reporters preload, the archived interpreter artifact refuses form
activation (`boot inventory changed; rebuild`), so `form_with` stays owned by
Rails and records 0/0. Without that preload the same artifact activates
`FormScaffold::Variant` and records a form hit. This is not the independent
`RealBlogR4` link pilot restriction. The activation mismatch and explanation
were handed to the sealed owner; no sealed/runtime check was relaxed here.
