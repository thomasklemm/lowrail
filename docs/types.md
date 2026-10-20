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
TimeWithZone, Date and BigDecimal declarations for standalone `rbs validate`; omit it when
loading a full Rails RBS collection. This is generated member information,
not a complete Rails signature distribution. Existing files with these two
names in the chosen output directory are overwritten; other files are left
alone. Tests invoke `rbs validate` when the executable is available.

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
| `type_of` | `target`: `Article#title`, `Article.all` or `article_path` | RBS signature, return/parameter types and provenance, roles |
| `method_facts` | `target`: `Class#method` or `Class.method` | Resolved boot method, owner/source/parameters/ISeq kind and existing origin classifier result |
| `model` | `name`: model class | Raw columns, attributes, associations, callbacks; validations if recorded in the facts |
| `routes` | optional `name`, `path`, `controller` substrings (combined with AND) | Matching routes, in route-set order |
| `lowering_ledger` | none | Current `.lowrail/ledger.json`, or an explicit missing-ledger result |
| `diagnostics` | none | Explicit placeholder; source-read/parse diagnostics only |

For example, a tools/call request after initialization:

```json
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"type_of","arguments":{"target":"Article#title"}}}
```

Facts are compared by file contents on each data-tool request and the cached
model is rebuilt on changes, even if mtime/size are unchanged. A malformed or
missing replacement produces a tool error, never a stale successful answer;
later requests retry reading the file. The ledger is read for every ledger
request. Source-only edits require regenerated facts (or server restart).
Tool failures use MCP `isError`; protocol failures use JSON-RPC error codes.

The current fact dumper does not record validations or enum mappings. Missing
validations are reported as unavailable, not as an empty validated set.
Diagnostics are not a substitute for the lowering ledger or `lowrail verify`.
