# Rubydex: where Lowrail should contribute

Research snapshot: **2026-10-21, 17:10 UTC**. Repository/API inspection,
executable Ruby oracles, Rust graph probes, and source-only measurements on
all nine requested apps. No Lowrail runtime, admission, dependency, or app
implementation changes. No upstream issue, PR, fork, review, or comment was
created. The [machine-readable appendix](rubydex-data.json) preserves source
pins/hashes, individual measurements, comparison results, and probe sources.

## Recommendation

**Yes, contribute upstream, but not a new Rails indexer or a parallel Prism
migration.** The three highest-value contributions are:

1. **Help land Prism 2 stable, already owned by
   [#1077](https://github.com/Shopify/rubydex/pull/1077) and
   [#1078](https://github.com/Shopify/rubydex/pull/1078).** The merged migration
   already provides an escape from Lowrail's old-pin dependency conflict:
   its `^2.0.0-rc.2` requirement accepts stable 2.0.0. #1078 makes the stable
   version explicit; its merge is not a prerequisite to trying a newer pin.
   Offer corpus results/review, not another migration PR.
2. **Supply runtime-oracle tests for Concern and resolution-dependent DSLs,
   then implement a small agreed compiler contribution under
   [#958](https://github.com/Shopify/rubydex/issues/958).** A reproduced Concern
   case has both wrong ancestry order and wrong method ownership. Cooperate
   with draft [#1030](https://github.com/Shopify/rubydex/pull/1030); do not
   hard-code every Rails macro into Rust or invent a second plugin registry.
3. **Improve constant-resolution correctness and explicit namespace evidence.**
   First help existing [#1074](https://github.com/Shopify/rubydex/pull/1074)
   and [#1080](https://github.com/Shopify/rubydex/pull/1080); then discuss an
   opt-in namespace adapter in [#997](https://github.com/Shopify/rubydex/issues/997).
   A synthetic namespace declaration fixes the reproduced implicit-namespace
   merge without teaching the core that every directory is a Ruby module.

The important correction to the premise: **Lowrail currently uses no Rubydex
API at all.** It pins and resolves/builds the dependency, but there are no
`rubydex::` imports or calls in `src/`, `tests/`, or `gem/`. README/PLAN describe
the intended architecture, not an implemented Rubydex integration. Consequently
graph improvements currently save **zero Lowrail request work**. Their value
is future static discovery/provenance, reduced duplicate indexing, and the
immediate Prism dependency unblock. None replaces boot certificates.

## 1. What Lowrail actually does

Inspected Lowrail
[`060f85e`](https://github.com/thomasklemm/lowrail/commit/060f85e21e35f192ac6312f6bb2499b130b32dac),
including README, PLAN, candidates, types and DECISIONS. Inventory command:

```sh
rg -n -i rubydex src tests gem Cargo.toml README.md docs/PLAN.md
```

The implementation directories return no matches. `Cargo.toml` pins
[`d8ff475`](https://github.com/Shopify/rubydex/commit/d8ff47595223571588ae40cb748f43cef6a9dfaf),
Rubydex 0.4.1, whose Rust manifest requires `ruby-prism = "1.9.0"`.

| Facts / consumer | Actual owner and contract | Rubydex API used today | Possible future substitution |
|---|---|---|---|
| Constants and loaded modules | [`gem/lib/lowrail/facts.rb`](../gem/lib/lowrail/facts.rb): ObjectSpace census, bound core reflection, constant source locations | None | Static declarations/references can add candidates; cannot establish loaded constant identity, autoload timing, or actual require order |
| Instance/singleton ancestors | Same file captures actual ordered chains and anonymous/generated holders; [`src/types/mod.rs`](../src/types/mod.rs) resolves through those boot chains | None | Reconcile static chains with boot chains, preserving unresolved/anonymous distinctions; do not make static ancestry authoritative |
| Method existence, owner, visibility, aliases, parameters | Bound reflection and UnboundMethod source/original name in `facts.rb`; generated script identities linked by [`src/facts/generated.rs`](../src/facts/generated.rs) | None | Graph definitions can explain provenance and aliases; boot still decides the effective implementation |
| Source origin and macro hints | [`src/facts/origin.rs`](../src/facts/origin.rs): cached Prism `SourceIndex`, definitions, enclosing definitions, call sites, byte spans; `Classifier` joins boot source to those hints | None | A shared source/declaration index could remove part of this extraction, not its runtime join or exact identity checks |
| Advisory types | [`src/types/mod.rs`](../src/types/mod.rs), [`rails.rs`](../src/types/rails.rs): schema/reflections/routes and owner/source/version-matched Rails catalog; samples merged separately | None | Declarative types can enrich candidates; cannot prove value classes, schema reader behavior, or mid-request lookup |
| Body inference and source DSLs | [`src/types/infer.rs`](../src/types/infer.rs): separate Prism index, literal scope/enum handling and up to eight synchronous inference rounds | None | Share declaration extraction; keep executable body analysis and conservative inference in Lowrail |
| Sorbet signatures | [`src/types/sorbet.rs`](../src/types/sorbet.rs): another Prism index, adjacent sig/def, lexical type aliases, source-matched wrapped methods; optional read-only registry facts from Ruby | None | Lossless signature associations could replace extraction, not evidence policy or wrapper/source matching |
| MCP and RBS export | [`src/mcp/tools.rs`](../src/mcp/tools.rs): boot/type-model queries and RBS rendering; its own Prism `method_span` walk for real def spans | None | Could consume a shared source index; Lowrail does not proxy Rubydex's MCP or query engine |
| Build/lowering | [`src/build/mod.rs`](../src/build/mod.rs) writes advisory typed facts; route/view/memo lowerers and Ruby builders analyze bodies/compiled sources | None | A declaration graph is not an evaluation-order, mutation, delivery, or admission certificate |

These Prism walks overlap in file parsing, lexical ownership, method spans and
macro discovery. They also have genuinely different jobs. Replacing all of
them with a declaration graph would lose executable expressions and exact
source/boot associations. Boot facts are the primary design, **not an
emergency fallback from a failed Rubydex query**. Neither static DSL expansion
nor sampled types can license lowering. In particular, preserve lazy loading:
an adapter must observe already available data, not autoload app constants or
run callbacks to make a graph agree.

## 2. Upstream architecture, direction and contribution boundary

Inspected full source/history at main
[`c69a742`](https://github.com/Shopify/rubydex/commit/c69a742c9097a2a5c13f97726abda55b0507121b)
(0.4.2), the Lowrail pin, and exact #1078 head
[`06e61c1`](https://github.com/Shopify/rubydex/commit/06e61c1400cf3751a3aa4b42fd815b82b3909b43).
Also paginated all issues/PRs, then read the relevant discussions, changes and
checks. Statuses below are snapshots, not promises about later merges.

The [architecture](https://github.com/Shopify/rubydex/blob/c69a742c9097a2a5c13f97726abda55b0507121b/docs/architecture.md)
is parallel file-local indexing, LocalGraph merge, then dependency-ordered
fixed-point resolution. Definitions are source occurrences; declarations
combine their semantic identity. References, names, namespaces, mixins and
ancestors are connected through typed hashed IDs and maps. Partial ancestry
is representable; it must not be silently promoted to complete ancestry.

The Rust crate is the implementation; `rubydex-sys` provides FFI, the C native
extension exposes the Ruby API, and CLI/query/MCP consumers share the graph.
Read-only Cypher queries and existing source/location/visibility APIs already
exist. Ractor sharing inside a Ruby process is also supported; that is not a
persistent cache or cross-process sharing. A frozen graph can still be mutated
through its lock, so consumers must coordinate snapshot consistency.

The operation backend introduced by merged
[#798](https://github.com/Shopify/rubydex/pull/798) is currently
AST → operations → applier → LocalGraph. Feeding ordered operations directly
into unified analysis is the direction under discussion, not a completed VM
or stable public plugin API. Maintainers' explicit requirements in
[#958](https://github.com/Shopify/rubydex/issues/958#issuecomment-5479655489)
and its discussion are significant:

- DSL effects can change ancestors and ordinary constant lookup; they belong
  in the same dependency/convergence loop, not graph surgery afterward.
- Match resolved receiver identity/aliases, not just a call's spelling.
- Express compilers as data/IR rather than baking every gem into Rust.
- Avoid Ruby callbacks serializing parallel indexing behind the GVL.

[#1030](https://github.com/Shopify/rubydex/pull/1030) is **open, draft**, a
resolution-dependent compiler-boundary prototype. It tests semantic receiver
selection and dependency edges with `Struct.new`; authoritative replay,
ordered execution, blocks, implicit receivers and the public registry remain
open. Closed [#418](https://github.com/Shopify/rubydex/issues/418) and
[#497](https://github.com/Shopify/rubydex/issues/497) are earlier explorations,
not proof that a Rails extension API shipped. The
[Ruby LSP adoption roadmap #669](https://github.com/Shopify/rubydex/issues/669)
has most language features checked off, but Tapioca add-on migration remains
open. This is an indexing substrate for tools, not a promise of a Rails
runtime emulator or complete type checker.

### Contribution mechanics

Rubydex is [MIT licensed](https://github.com/Shopify/rubydex/blob/c69a742c9097a2a5c13f97726abda55b0507121b/LICENSE.txt).
Its [contribution guide](https://github.com/Shopify/rubydex/blob/c69a742c9097a2a5c13f97726abda55b0507121b/CONTRIBUTING.md)
and [agent guidance](https://github.com/Shopify/rubydex/blob/c69a742c9097a2a5c13f97726abda55b0507121b/AGENTS.md)
describe Rust tests/clippy/formatting under `rust/`, Ruby native compilation,
Ruby tests and RuboCop. Changes should cover both indexing backends, Rust
resolution and any Ruby/FFI API affected; reference/update the documented
Ruby behaviors. Start with a small reproduction and design agreement where
IR/plugin boundaries are unsettled. Maintainers own releases; do not run
local release/publish commands as a contributor.

The repository's
[CLA workflow](https://github.com/Shopify/rubydex/blob/c69a742c9097a2a5c13f97726abda55b0507121b/.github/workflows/cla.yml)
runs Shopify's CLA action. The human contributor must complete the applicable
agreement at [cla.shopify.com](https://cla.shopify.com/) if not already covered;
license permission does not substitute for CLA approval. No agreement was
signed or contributor status assumed in this task.

## 3. Ranked opportunities

Effort estimates are engineering judgment for a reviewed/tested contribution,
not upstream commitments: **S** ≈ 1–3 days, **M** ≈ 1–2 weeks, **L** ≈ several
weeks or design-dependent. All benefits except the dependency unblock require
a future, separately reviewed Lowrail integration.

| Rank | Candidate and Lowrail impact | Effort / fit | Existing overlap and recommendation |
|---|---|---|---|
| **1** | Prism 2 stable: escape Lowrail's old-pin native parser conflict; merged main already permits one stable parser version | S for review/corpus evidence; migration itself already implemented. Excellent core fit | #1077 merged; #1078 open. Help existing work; no duplicate issue/PR or mandatory wait for #1078 |
| **2** | Correct Concern/DSL ownership and ancestor effects; shared literal generated declarations | S for reproductions, L for a general compiler boundary. Excellent fit as IR, poor fit as Rails-specific Rust branches | #958, draft #1030, define_method #583, singleton #937. Offer oracle fixtures, then one agreed literal compiler/focused correction |
| **3** | Constant resolution plus explicit namespace evidence: avoid merging distinct classes; make future source-to-boot reconciliation credible | S for existing core fixes/review, M for adapter design. Core lookup fits; loader conventions must be opt-in | #1073/#1074, #1063/#1080, Zeitwerk #997. Extend existing work, not a generic “support Zeitwerk” issue |
| **4** | Lossless declared-signature/type associations (RBS first, then bounded Sorbet) reduce duplicate extraction and enrich advisory MCP types | M–L, needs API agreement. Indexing annotations fits; becoming a type checker does not | RBS already indexed but types discarded; #628 covers type-name references, not type retention. Discuss a narrow retention issue before implementation |
| **5** | Precise source/provenance APIs and comment attachment reduce local span/association walks | S–M, strong fit if memory cost bounded | #835 source API, #844 RHS spans, #837 mixin locations, Prism migration. Extend existing APIs/issues; no claim that offsets are absent |
| **6** | ERB indexing adds helper/reference candidates and avoids parsing raw markup as Ruby | M to test/help current extraction, L for ActionView-aware binding. Extraction fits; runtime compiled-view semantics stay external | #1064 open. Help it; do not write a competing ERB extractor or treat extracted references as view type flow |
| **7** | Incremental recomputation, shared/cached graph: future MCP freshness and amortized indexing | L, good upstream fit, low demonstrated Lowrail urgency | #960, #957, #869, draft #979; #1009 closed **unmerged**. Add differential edit tests after graph integration, not a new cache implementation now |
| **8** | Generic time/RSS optimization | S for measurements, L without a specific hotspot. Good fit but no measured bottleneck on these source-only apps | #826 metrics, #864 memory accounting. Contribute reproducible workloads; reject speculative optimizer/cache work justified by these small timings |

### 1 — Prism 2: an actual blocker, but already owned

[Prism 2.0.0](https://github.com/ruby/prism/releases/tag/v2.0.0) was published
October 21. Lowrail's direct `ruby-prism` 2 upgrade conflicts with its pinned
Rubydex `^1.9` dependency: both `ruby-prism-sys` versions declare
`links = "prism"`. Cargo cannot resolve both native libraries in one graph.
This is not an AST adaptation failure. The Prism thread reproduced the
resolver failure and restored Cargo. This research independently reproduced
it with `cargo metadata --offline` in a disposable crate against the pinned
source (exit 101), without changing Lowrail's manifest.

**Do not overstate the blocker:** the same disposable probe against captured
upstream main succeeds (exit 0) and selects exactly one `ruby-prism 2.0.0`
and `ruby-prism-sys 2.0.0`. Cargo's `^2.0.0-rc.2` requirement accepts stable
2.0.0. The old Lowrail pin is the dependency blocker; waiting for #1078 is
**not strictly required** to attempt the Rust migration on a newer upstream
pin. This is dependency resolution, not a compiled Lowrail migration or
permission to update its pin. Manifests/logs are retained in the appendix.

- **#1077 merged October 20:** migrates Rubydex to 2.0.0-rc.2 and adapts the
  breaking APIs. Captured main still has that requirement.
- **#1078 open, not draft:** stable 2.0.0 dependency/lock update, head linked
  above. Against captured main its substantive diff is the version/lock bump,
  not a second AST migration. The PR branch predates the 0.4.2 version bump,
  so its CLI reports 0.4.1; identify the build by Git SHA, not this label.
- **Checks:** all 36 check-run records retrieved (including repeated workflow
  runs): 35 success, one skipped Dependabot check, none failed/pending. Ruby
  platforms, lint, top-gem indexing, leak checks, CodeQL and CLA are green.
  No submitted reviews at inspection. GitHub says `mergeable: true`,
  `mergeable_state: blocked`. Protection/rules access was unavailable, so the
  exact remaining maintainer/review gate is **unverified**, not a known code
  blocker. Do not invent a failure to fix.

Built its release CLI and ran `cargo test --locked --manifest-path
PR_WORKTREE/rust/Cargo.toml --lib`: **1,157 Rubydex + 12 rubydex-sys tests
passed**, zero failures. This is the workspace library suite, not a local
Ruby-extension, CLI or doctest run. Upstream CI covers additional surfaces.
All nine source-only graph comparisons and timings are below. These results
are useful evidence to offer on #1078 **after authorization**. A focused fix
is warranted only if a concrete regression is found; none was found in the
compared graph projection. Lowrail can separately choose a validated newer
pin, update its direct requirement and test its own Rust API migration; the
merged rc migration already makes stable dependency unification possible.
No dependency was changed here; the Ruby-only Prism upgrade belongs to the
other thread, which was notified of this resolution result.

### 2 — Ancestors and declarations: refine the proposed scope

Ordinary `include`/`prepend`/`extend`, singleton namespaces, visibility,
`alias`/`alias_method` and `attr_*` already have implementations and tests.
Do **not** file a blanket “add mixins/visibility/aliases” request.

Executed a deliberately asymmetric fixture against Ruby 4.0.7 and
ActiveSupport 8.1.4, and both Rubydex revisions:

```ruby
module First
  extend ActiveSupport::Concern
  included { include Left }
  class_methods { def from_concern; end }
end
module Second
  extend ActiveSupport::Concern
  include First
end
class Host
  include Second
end
```

`Left` is an ordinary previously defined module. Results:

| Boundary | Ruby / ActiveSupport oracle | Both indexed graphs |
|---|---|---|
| Ordinary prepend and multi-argument include | `Top, Child, Left, Right, Parent, Object, Kernel, BasicObject` | Same ordered instance chain |
| `extend ClassMethods` | Module appears in Child's singleton ancestry | Present in indexed singleton ancestry |
| Private def, alias and attr_reader | `original`, `copied`, `token` private | Same declarations and visibility |
| Literal `define_method(:literal)` | Defines a private method | No method declaration |
| Rails `delegate :forwarded, to: :target` | Defines a method | No method declaration |
| Concern Host ancestry | `Host, Second, Left, First, …` | `Host, Second, First, Left, …` |
| Concern class-method owner | `First::ClassMethods` | Declaration incorrectly indexed as `First#from_concern()` |

This is a verified semantic mismatch, not merely an absent feature. The
`included` block executes against the includer, and Concern delays/redirects
its effects; a lexical walk is not equivalent. The fixture tests ordinary
mixins as a control. It does **not** establish all mixin/singleton behavior as
correct: [#937](https://github.com/Shopify/rubydex/pull/937) remains open for
singleton descendant propagation, with an upstream-reported +200 MB/+2 s
cost under review. Those are upstream workload numbers, not ours.

Contribution sequence: supply the fixture under #958/#1030 and settle how
block context, owner/visibility, effect order, dependencies and unload are
represented. Then choose a narrow compiler such as literal `define_method`
under [#583](https://github.com/Shopify/rubydex/issues/583), or the agreed
Concern effect. Require shadowed/overridden DSL receivers not to match,
literal vs computed names, private/public edges, aliases, dependency removal
and edit-vs-clean rebuild tests. Delegate prefixes/allow_nil, AR scopes/enums,
attribute defaults/casting and associations are not interchangeable method
shapes; unsupported arguments must stay explicit, not silently guessed.

Source syntax demonstrates relevance, not admission coverage:

| App | Files / def nodes | `included` / `class_methods` calls | `delegate` / `define_method` calls | `has_many` / `scope` / `enum` calls | `sig` calls |
|---|---:|---:|---:|---:|---:|
| Blog | 41 / 15 | 0 / 0 | 0 / 0 | 1 / 0 / 0 | 0 |
| Fizzy | 276 / 437 | 34 / 11 | 6 / 3 | 37 / 41 / 2 | 0 |
| CASA | 1,183 / 1,806 | 8 / 0 | 3 / 0 | 73 / 109 / 4 | 0 |
| Writebook | 141 / 252 | 16 / 8 | 2 / 3 | 7 / 20 / 5 | 0 |
| Wikino (`rails/`) | 336 / 470 | 7 / 0 | 7 / 0 | 26 / 19 / 5 | 582 |
| CodeTriage | 263 / 463 | 0 / 0 | 3 / 0 | 22 / 8 / 0 | 0 |
| PingCRM | 66 / 59 | 4 / 0 | 0 / 0 | 7 / 10 / 0 | 0 |
| Redprints | 149 / 195 | 2 / 1 | 4 / 0 | 10 / 4 / 4 | 0 |
| Starter | 55 / 50 | 0 / 0 | 1 / 0 | 1 / 0 / 0 | 0 |

The separate Prism 1.9 census includes tests/configuration; call spelling
does not prove Rails ownership, literal arguments, execution or unique
generated methods. No source parse errors were reported. Signature counts
are syntactic calls, not the inherited/recovered signatures or typed slots
in [docs/types.md](types.md); do not compare those denominators.

### 3 — Constants: core correctness before loader conventions

Reproduced [#1073](https://github.com/Shopify/rubydex/issues/1073): for
`class ApplicationRecord; end; module GSD; class ApplicationRecord <
ApplicationRecord; end; end`, Ruby selects `::ApplicationRecord`; both
inspected Rubydex builds select the namesake inner declaration incorrectly.
The existing open fix **#1074** owns that correction. **#1080** addresses
[#1063](https://github.com/Shopify/rubydex/issues/1063), multi-segment
on-demand `Graph#resolve_constant`; that bug is in the Ruby query API, not
the normal whole-graph resolution pass. Neither fix should be conflated with
Zeitwerk integration.

Independently exercised #997's directory scenario using Zeitwerk 2.8.3:
`Child < Parent`, an explicit `Parent::Tasks`, and workers under both
`parent/tasks/` and `child/tasks/`. Zeitwerk creates a distinct `Child::Tasks`
module; source-only resolution merges both workers into
`Parent::Tasks::Worker`. A Rust probe adding the explicit synthetic source
`module NamespaceChild::Tasks; end` restores two separate declarations.
This proves the value of namespace evidence for this case, **not** a complete
Zeitwerk adapter or proof of its incremental behavior.

The #997 maintainer response correctly notes that ordinary Ruby inherited
lookup is right without Zeitwerk, and rejects generally baking gem behavior
into the core. Propose an opt-in external namespace contribution using
declared loader roots/configuration, with provenance and removal on edits.
It must account for inflections, collapsed/ignored directories, explicit
namespaces and multiple loaders, or refuse unsupported configuration.
Lowrail must not invoke loaders/on_load hooks earlier to produce those seeds.
A generic runtime-faithful autoload/require-order model is not a reasonable
upstream PR promise.

### 4 — RBS, Sorbet and comments: preserve information, not inferred truth

RBS indexing already exists: classes/modules, mixins, members, aliases,
parameters and overload shapes. The important limitation is explicit in
[`model/definitions.rs`](https://github.com/Shopify/rubydex/blob/c69a742c9097a2a5c13f97726abda55b0507121b/rust/rubydex/src/model/definitions.rs):
`Signature = Box<[Parameter]>`, documented as supporting **parameter names
and kinds only**. The RBS indexer does not retain value/return type semantics.
A two-overload RBS probe preserves overload/parameter structure but cannot
export `String`, `Integer`, `Array[String]` contracts from that signature.
[#628](https://github.com/Shopify/rubydex/issues/628) is about type-name
references, not an already implemented type model.

Sorbet `sig` is recognized as a documentation decorator for comment grouping,
not ingested as a typed signature. Wikino's 582 source `sig` calls make this
a real secondary opportunity; Lowrail already has a bounded extractor, so
it ranks below immediate dependency and graph-identity correctness.

Propose retaining source-associated annotations/overload types or type spans
without evaluating sig blocks, introducing whole-program inference, or
asserting runtime truth. Discuss unknown/dynamic expressions, aliases,
wrapper source locations, generics and ownership before adding a broad type
API. Lowrail still labels declared types advisory, keeps provenance, and
requires separate method/value/context certificates. First ask maintainers
whether annotation retention belongs in core or an extension; no exact
open duplicate for that narrow proposal was identified in the inspected list.

Prism 2's `attach_comments` is a parse option and changes attachment rules;
it does not parse types or establish sig/def adjacency. Current Rubydex has
its own comment grouping/decorator association. Review semantic parity
(docstrings before sigs, inline comments, whitespace, nested nodes) before
replacing it. The Ruby/C release API must not be mistaken for a usable Rust
binding option without checking that binding. This is related to #1078,
not a reason to delay its dependency-only stable bump.

### 5 — Locations: useful refinements, not missing fundamentals

Rubydex already stores document source and **half-open byte offsets** and
converts to line/column locations. Its Prism 2 adaptation reads slice
start/end into existing offsets. Arena ownership does not require keeping
borrowed AST nodes alive in the graph. What matters for Lowrail is identifying
the right definition, full body/call/RHS span, original source bytes/hash and
generated-script/template provenance, not merely obtaining a line number.

Extend [#835](https://github.com/Shopify/rubydex/issues/835) (entity source),
[#844](https://github.com/Shopify/rubydex/issues/844) (constant RHS), and open
[#837](https://github.com/Shopify/rubydex/pull/837) (mixin expression spans).
The latter's review raises storage cost; avoid adding node-sized metadata to
every entity without measuring it. Cases should include UTF-8 before a
span, CRLF, multiline RHS/heredocs, same-line definitions and generated
source. These can reduce `SourceIndex`/MCP extraction duplication but cannot
replace Lowrail's certificate join.

Prism 2's `Prism.find` accepts a Method, UnboundMethod, Proc or backtrace
location and finds an AST node by source location. It is a **Ruby** convenience
API, not a Rust declaration query or a guarantee that a source file is fresh.
It may help a future boot-side association, but does not solve aliases,
captured eval identities, stale files or exact mid-request dispatch.

### 6 — Templates: help the extractor, retain the ActionView boundary

Open [#1064](https://github.com/Shopify/rubydex/pull/1064) uses Herb lexical
extraction, replacing non-Ruby ERB content with whitespace to preserve source
offsets; both Ruby backends then index it. It retains original document text.
The PR documents missing Rust Prism `partial_script` options and narrowly
filters context-invalid yield/break/next/redo errors in its current approach.
Review that boundary with the Prism upgrade rather than broadening diagnostic
suppression. No local benchmark of #1064 was performed.

This can provide helper/reference candidates and source association. It
does not know ActionView's compiled method owner, helper availability, locals,
partial lookup/variants, controller-to-view ivar dominance, escaping, or
runtime-generated ERB source. Those facts remain Lowrail/boot concerns.
Existing [types documentation](types.md) records raw-ERB inference diagnostics;
that historical run was not repeated here and must not be called fixed by an
unmerged extractor. The [candidate budget](candidates.md) also explicitly says
templates already have compiled ISeqs: indexing ERB is not a rendering-speed
claim or an optimization from “compiling templates again.”

### 7–8 — Incremental, cache and performance: defer until there is a consumer

Updating/removing documents and incremental resolution already exist.
[#960](https://github.com/Shopify/rubydex/issues/960) redesigns invalidation,
batching and unnecessary work; it is not a request to introduce incremental
indexing from scratch. Four fixture trailing-comment edits kept the compared
graph snapshots unchanged, but this is only a narrow control, not an edit
correctness or latency study. Stronger future tests should compare a fresh
rebuild after deleting/renaming a concern, changing superclass, removing an
alias or compiler effect, and modifying a source seed.

[#957](https://github.com/Shopify/rubydex/issues/957) discusses sharing;
[#869](https://github.com/Shopify/rubydex/pull/869) server mode and draft
[#979](https://github.com/Shopify/rubydex/pull/979) workspace watching are open.
Serialization prototype [#1009](https://github.com/Shopify/rubydex/pull/1009)
was closed **without merging**. Its large internal-workload cache numbers are
not evidence of a released serializable graph, or a suitable Lowrail design.
Any future cache must key content/configuration/roots, parser/index format,
compiler versions and synthetic inputs; detect removals; and fail open to
fresh indexing/no-op, never substitute stale data for boot certificates.

The measurements below do not identify indexing as a Lowrail bottleneck.
Whole bundles/core RBS and multi-client workloads may have very different
costs. Before proposing optimization, establish that larger workload and
measure stage time/RSS; [#826](https://github.com/Shopify/rubydex/issues/826)
and [#864](https://github.com/Shopify/rubydex/issues/864) already own metrics
and graph memory-accounting discussions. No Callgrind was used.

## 4. Measurements and compatibility evidence

### Inputs and protocol

- Eight real sources fetched with `script/corpus APP --source-only`, preserving
  the pins and dependency-only overlays in [compat.md](compat.md). Wikino's
  root is its `rails/` subdirectory. No bundle installation, DB preparation,
  app boot or own suite was required for these eight indexing inputs.
- Blog generated by the pinned Roundhouse `scripts/create-blog`, Rails 8.1.4,
  under `.corpus/rubydex-blog` (same `real-blog` source recipe). Rails was
  installed to run the generator. No source implementation was patched.
- Rust 1.99.1/Cargo 1.99.1, Linux x86-64 E2B orb, eight visible CPUs,
  approximately 15.6 GiB visible RAM. Release binaries, locked dependencies,
  default RubyIndexer backend and default exclusions; input scope includes
  app tests/configuration, **not dependency gem source/core RBS/ERB**.
- Compared Lowrail's pinned Rubydex/Prism 1.9 with exact #1078/Prism 2.0.0
  head, not a guessed future release. Other Rubydex changes between these
  revisions mean differences cannot be attributed solely to Prism.
- Three fresh processes per app per arm, **54 total**, alternating arm order
  in round two; no build/test job overlapped timings. OS page cache was not
  flushed, CPU placement/frequency was not controlled. This is a small
  exploratory workload, not a confidence interval or accepted speed claim.
- Command: `/usr/bin/time -f %M -o RSS_FILE RUBYDEX_CLI ABS_APP --stats`.
  Python monotonic wall surrounds the subprocess (includes startup, wrapper,
  resolution and default CLI query/output). Table reports median wall and
  **external peak RSS**, not retained graph bytes. Internal stage times and
  RSS are also retained in the appendix. CLI file counts are source counts
  below plus one built-in document.
- An initial trial inherited the Python parent's approximately 19 MiB RSS
  high-water mark when directly executing the binary. It was invalid for
  small-process RSS and is excluded. The final, fixed 54-run dataset uses
  GNU time's separate process; both external and internal readings are kept.
  This correction is measurement plumbing, not rerunning a rejected Lowrail
  speed cohort. No Lowrail request benchmark was run or implied.

### Wall and RSS results

Wall: median **[minimum–maximum] milliseconds**. RSS: median peak **MiB**.
All 54 processes exited zero with empty stderr. Do not infer no graph
diagnostics from an exit code of zero.

| App | Source files | Pinned wall ms | #1078 wall ms | Pinned RSS MiB | #1078 RSS MiB |
|---|---:|---:|---:|---:|---:|
| Blog | 41 | 8.8 [6.6–9.0] | 6.3 [5.8–8.1] | 5.04 | 5.05 |
| Fizzy | 276 | 16.7 [15.7–18.8] | 14.2 [14.1–15.1] | 7.78 | 7.36 |
| CASA | 1,183 | 89.0 [88.2–99.1] | 66.3 [66.1–68.0] | 27.95 | 26.11 |
| Writebook | 141 | 11.1 [11.0–13.6] | 10.2 [9.9–11.7] | 6.60 | 6.52 |
| Wikino | 336 | 38.2 [37.2–41.9] | 34.1 [31.6–38.8] | 12.56 | 11.88 |
| CodeTriage | 263 | 17.7 [17.0–18.4] | 17.5 [16.1–19.9] | 8.23 | 8.08 |
| PingCRM | 66 | 6.8 [6.7–7.0] | 6.7 [6.7–7.6] | 5.44 | 5.35 |
| Redprints | 149 | 11.8 [10.5–11.9] | 10.8 [9.9–11.9] | 6.69 | 6.71 |
| Starter | 55 | 7.2 [6.5–7.2] | 7.2 [6.4–8.9] | 5.20 | 5.20 |

Even the largest source-only median is under 0.1 s and 28 MiB. That argues
against making a cache/optimizer our first contribution **on these inputs**;
it says nothing categorical about dependency-expanded or Shopify-scale graphs.

### Compare semantic outputs, not just timing or counts

A Rust driver indexed the same roots, resolved them, and sorted rows for
declaration names/visibility/ordered ancestors, full definition debug data,
constant references, method references and diagnostic identities/locations.
All nine **non-diagnostic projections were byte-identical** between arms.
Seven full snapshots, including diagnostics, were identical. Fizzy loses two
and Writebook three instances of the same ambiguous-slash parser warning;
there are no added diagnostics or other row differences. This agrees with
Prism 2's documented removal of the `a /b/` ambiguity warning. The warning
rows/deltas and full-snapshot hashes are preserved, not normalized away.

| App | Diagnostics pinned → #1078 | Comparison |
|---|---:|---|
| Blog | 1 → 1 | Full projection identical |
| Fizzy | 6 → 4 | Only two slash warnings removed |
| CASA | 610 → 610 | Full projection identical |
| Writebook | 10 → 7 | Only three slash warnings removed |
| Wikino | 159 → 159 | Full projection identical |
| CodeTriage | 23 → 23 | Full projection identical |
| PingCRM | 0 → 0 | Full projection identical |
| Redprints | 8 → 8 | Full projection identical |
| Starter | 0 → 0 | Full projection identical |

This projection is stronger than equal totals but is **not a serialization of
every private graph field**, runtime equivalence, or proof of completeness.
Many diagnostics reflect missing framework/gem declarations in this deliberate
source-only scope. Existing Concern/namesake gaps remain in both builds.
No app was run through `lowrail verify`, so this report makes no new support,
fast-path-hit or speed claim.

### Reproduction from the appendix

The JSON includes the input recipes/source-manifest hashes, exact revisions,
per-run raw readings, snapshot hashes/deltas, selected call counts, the
inventory/measurement/graph-driver source, and small Ruby/RBS fixtures.
Paths in the historical drivers describe this orb; replace them for another
workspace rather than mistaking `/tmp` paths for durable dependencies.

To recreate: prepare the pinned sources with `script/corpus`, check out the
two upstream revisions into separate worktrees, build each with
`cargo build --release --locked --manifest-path WORKTREE/rust/Cargo.toml
--bin rubydex_cli`, and compile the saved graph driver against each library.
For example, after building:

```sh
deps="$WORKTREE/rust/target/release/deps"
rlib=$(find "$deps" -maxdepth 1 -name 'librubydex-*.rlib' -print -quit)
rustc --edition=2021 probe.rs -L "dependency=$deps" \
  --extern "rubydex=$rlib" -o probe
./probe --corpus "$ABS_APP" | LC_ALL=C sort > snapshot.txt
```

Use separate clean targets so `rlib` selects exactly the intended revision.
The driver already sorts its output; the final sort is redundant but harmless.
Run the saved measurement driver only after compilation ends. Repeatability
means same inputs/protocol and inspected differences, not identical wall/RSS
or path-dependent snapshot hashes on another machine.

## 5. Proposed authorization queue — nothing opened yet

| Order | Concrete proposed upstream action | Scope / stop condition |
|---|---|---|
| A | Review/test contribution to **existing #1078** | Share exact-head corpus evidence and five expected warning removals. No competing issue/PR or invented red check. Its merge remains a maintainer decision, not a prerequisite for Lowrail's newer-pin migration experiment |
| B | Add the Concern owner/order reproduction to **#958/#1030**; if maintainers want a separate bug, open “Concern included/class_methods effects are assigned to lexical owner” | Keep ordinary mixins as control. Ask which IR boundary should own delayed effects before coding. A literal define_method contribution under **#583** is a smaller follow-on if preferred |
| C | Review/test **#1074** and **#1080**, then contribute the namespace-seed experiment to **#997** | Do not duplicate either fix. Discuss opt-in synthetic namespace provenance/invalidation; no implicit autoloading or global path-name heuristics |
| D | Optional new design issue: “Retain source-associated declared RBS types/overloads without inference” | Explain existing shape-only signatures, relation to **#628**, and the Sorbet follow-on. Proceed only after maintainers accept the ownership/API boundary |
| E | Optional help for **#1064**, **#835/#844/#837** | Offer targeted template/source tests after higher priorities. Do not reopen a serialization prototype or start a broad performance PR without a measured workload |

Lowrail's separate integration decision should follow, not precede, usable
upstream APIs: begin with advisory graph/source candidates, compare them to
boot facts with explicit disagreement records, and retain exact-or-refuse
admission. Contributing useful static analysis is worthwhile; confusing its
answers with runtime certificates would reverse Lowrail's design.
