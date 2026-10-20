# Boot-first types and MCP

Target: Ruby 3.4+ (development pins 4.0.7), Rails 8.1+.

```sh
script/corpus real-blog
cargo run -- facts .corpus/real-blog
cargo run -- types .corpus/real-blog --rbs .corpus/real-blog/sig/lowrail
rbs -I .corpus/real-blog/sig/lowrail validate
```

`types` reads existing `.lowrail/facts.json`; it does not boot or modify the
app. Stdout is a JSON object with a `methods` map keyed by `Class#method` or
`Class.method`, and source-read/parse diagnostics. Every return/parameter type
has a `name` (RBS notation) and `provenance` entries with `source` and `detail`.
Sources are `boot_fact`, `schema`, `inference`, and `observed`. Existing
`.lowrail/observed.json` samples are merged **after** static inference, never
fed back into it. Types remain advisory unless explicitly proven within an
analyzed body; a lowering consumer must still certify its execution context.

## Observed types

```sh
lowrail verify APP --observe-types
lowrail verify APP --observe-overhead # also one enabled/no-recorder control
lowrail observe APP --samples 16 --overhead # full definition/script census
```

Verify records only its first **on** run, using targeted method TracePoints,
not a global call hook. The lightweight mode omits script capture and the
all-module definition census. The default cap is 16 returns per method per
process (`LOWRAIL_OBSERVE_SAMPLES`); args are sampled at entry and receiver
ivars at return. Missing ivars are not nil observations. Sampling never calls
the object's own reflection methods, enumerates a collection, or runs SQL.
Counts, calls, cap/saturation and raw class names survive in `observation`;
each typed slot also retains its class histogram in `samples`. Saturation
means **recording stopped**, not exhaustive coverage. Exceptions, recursion,
threads and uncalled methods can leave incomplete samples.

Observations fill `untyped`, or annotate a static type without narrowing it.
A contradicting sample creates a `conflicts` row with method, slot, static
type, class and count; the static name is preserved and body proof withdrawn.
`String?` plus String-only samples stays `String?`. Anonymous classes stay
`untyped`; model-specific Rails relation class names are rendered as advisory
`Relation[Model]`, not evidence about loaded elements. Regenerate facts and
observations after source changes; no source-freshness certificate is implied.

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
| `static` | Schema, boot catalog, or call-based inference. Needs method/schema/config certificates and, when applicable, live value checks. Storage nullability is not a Ruby-object invariant. |
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

- Columns seed reader types, including schema `null` (`String?`, `Integer`,
  `bool`, `BigDecimal`, `Date`). Time columns allow both `Time` and
  `ActiveSupport::TimeWithZone`, because the dump does not pin time-zone-aware
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
  `String?`; enum value-specific predicates/scopes are not yet enumerated.
  `where` and `unscoped` are not seeded: no-argument `where` returns a
  WhereChain, and block-form `unscoped` returns the block's result.
- Controller actions and method-based `before_action` callbacks have roles
  in the model. Their returns remain `untyped` unless a simple body is known;
  an action is not assumed to return the HTTP response.
- Each named route gets `Lowrail::RouteHelpers#name_path -> String`.
  Parameters are permissive because route facts do not describe the full
  polymorphic/positional/keyword calling convention.

Boot method parameters replace guessed parameter lists where available.
Prism matches boot source locations and original method names, then propagates
simple literals, attribute/association reads, no-argument calls and local/ivar
assignments through up to eight synchronous return-inference rounds. Custom
reader bodies take precedence over schema seeds. Unsupported control flow,
blocks, dynamic calls, arguments and recursive unknowns remain `untyped`.
This is not whole-program parameter inference, controller-to-view ivar flow,
or validation of source freshness. Regenerate facts after changing the app.

## RBS output

`--rbs OUT_DIR` creates `OUT_DIR/app.rbs` and `lowrail_support.rbs` (normally
choose an app `sig/` subdirectory). Output is deterministic. Provenance is
also emitted as comments. The support file supplies minimal Rails relation,
TimeWithZone, Date, BigDecimal and Tempfile declarations and name-only stubs for
namespaced external classes introduced by observations (e.g. strong parameters
and safe strings). Array, Hash, Set and Queue samples do not infer element
types. Namespace class/module kinds come from boot facts even when the namespace
has no modeled methods. Omit the support file when loading full Rails/stdlib
signatures. This is generated member information,
not a complete Rails signature distribution. Existing files with these two
names in the chosen output directory are overwritten; other files are left
alone. Tests invoke `rbs validate` when the executable is available.

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
| `method_facts` | `target`: `Class#method` or `Class.method` | Resolved boot method, owner/source/parameters/ISeq kind and existing origin classifier result |
| `model` | `name`: model class | Raw columns, attributes, associations, callbacks; validations if recorded in the facts |
| `routes` | optional `name`, `path`, `controller` substrings (combined with AND) | Matching routes, in route-set order |
| `lowering_ledger` | none | Current `.lowrail/ledger.json`, or an explicit missing-ledger result |
| `lowering_status` | `target`: `Class#method` or `Class.method` | Matched ledger sites and original reasons; `lowered`, `refused`, `mixed`, or `not_recorded` |
| `verify_stats` | none | Last completed verify's pass/unit hits and fallbacks, command, equivalence result, recorder overhead and `matches_current_manifest` |
| `diagnostics` | none | Source-read/parse diagnostics and static/observed type conflicts |

For example, a tools/call request after initialization:

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"type_of","arguments":{"target":"Article#title"}}}
```

Facts and observations are compared by file contents on each data-tool request and the cached
model is rebuilt on changes, even if mtime/size are unchanged. A malformed or
missing facts replacement produces a tool error, never a stale successful answer;
removing observations removes their types, and malformed observations error.
Later requests retry reading the file. The ledger is read for every ledger
request. Source-only edits require regenerated facts (or server restart).
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
