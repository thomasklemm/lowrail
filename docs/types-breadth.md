# Types/MCP breadth — six frozen Rails workloads

2026-10-22. Advisory tooling only; no runtime, lowering, application source,
benchmark, Callgrind or measurement-cohort changes. Baseline is Lowrail
[`f257ddd`](https://github.com/thomasklemm/lowrail/commit/f257ddd1d35284b1da4daad201852ab8cc2ee32e).
Ruby 4.0.7, Rails 8.1.4, RBS 4.2.0. Facts were collected in the test environment;
the before/after comparison uses the **same facts, source and observations**.
Only the retained blog has observations. Boot YJIT flags are historical facts,
not a JIT experiment or a performance claim.

## Coverage, with the denominator held fixed

Each modeled return/argument is one slot; ivars, support declarations and
unmodeled methods are excluded. There are no new app signatures or removed
placeholder parameters in this comparison. Every recovered slot is **static**,
never proven. Unknown stays `untyped`.

| App | Proven/static/observed/unknown before | After | Unknown → static |
|---|---|---|---:|
| Blog (`real-blog-r4`) | 2/99/7/188 | **2/99/7/188** | 0 |
| Fizzy | 14/936/0/1,677 | **14/953/0/1,660** | 17 |
| Campfire | 30/622/0/6,071 | **30/752/0/5,941** | 130 |
| CASA | 40/2,424/0/7,410 | **40/2,548/0/7,286** | 124 |
| Writebook | 19/462/0/1,062 | **19/499/0/1,025** | 37 |
| Lobsters workload | 36/858/0/2,227 | **34/881/0/2,206** | 21 |
| **Total** | **141/5,401/7/18,635** | **139/5,732/7/18,306** | **329** |

Lobsters' `CategoriesController#new` and `TagsController#new` keep their String
type but lose an old body-proof label: a call before the literal tail is not
certified. No known type is withdrawn. Excluding Lobsters, recovery is **308**
and remaining unknown is **16,100**. This is a small improvement, not a claim
that real Rails applications are now fully typed.

Known outer containers can still have unknown members (`Array[untyped]`, for
example). These remain visible, not guessed: the new known slots with nested
`untyped` are blog 0, Fizzy 0, Campfire 6, CASA 9, Writebook 1, Lobsters 2.
These 18 partially known slots are included in the 329, not complete element
type recovery.

These are effective receiver slots, **not 329 independent method bodies**.
Counting their final recorded body source locations yields Fizzy 17, Campfire
22, CASA 107, Writebook 11 and Lobsters 20. Concern methods inherited into many
controllers explain much of Campfire/Writebook's gain. Keeping those public
receiver signatures useful is real coverage, but does not imply many distinct
analyses or a whole-program typing capability.

The [machine-readable ledger](types-coverage.json) contains both snapshots'
coverage, ranked causes, representative unknown slots, argument shapes/families,
effective owners, **all 329 recovered slot identities**, evidence sources,
the two proof demotions, diagnostics and input/output SHA256s. The coarse cause
classifier is [script/types-coverage](../script/types-coverage); it is based on
provenance, not an assertion that every unsupported AST has been diagnosed.
Classification priority makes the rows disjoint. Bodies whose returned value
depends on an unmodeled call are in the body row, not counted twice as missing
framework contracts. Changes in that row alone need not equal recovery.

## Remaining unknown causes, ranked across the six apps

Each column sums to its app's remaining unknown total. Per-app ordering can
differ from this aggregate rank; the JSON lists each app in descending order.

| Rank / cause | Blog | Fizzy | Campfire | CASA | Writebook | Lobsters | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1. Argument value contract unavailable | 97 | 947 | 3,791 | 3,223 | 529 | 1,050 | **9,637** |
| 2. Source body unresolved | 0 | 393 | 570 | 2,352 | 289 | 893 | **4,497** |
| 3. Effective owner return contract unavailable | 80 | 138 | 1,453 | 948 | 111 | 56 | **2,786** |
| 4. Casting writer input returned, input unknown | 11 | 175 | 124 | 725 | 92 | 206 | **1,333** |
| 5. Association target unavailable/polymorphic | 0 | 5 | 3 | 27 | 4 | 0 | **39** |
| 6. Schema type unmodeled/custom | 0 | 2 | 0 | 11 | 0 | 1 | **14** |
| **Total** | **188** | **1,660** | **5,941** | **7,286** | **1,025** | **2,206** | **18,306** |

### Next-bet estimates for the top three

These are **planning estimates, not measured recoveries or commitments**. A
coarse bucket is a ceiling, not evidence that one generic change can solve it.
No estimate justifies adding an unguarded/proven type. A next pass must measure
slot identities again, including inherited copies and partial containers.

1. **Argument contracts (9,637): expect zero from body/DSL inference alone.**
   The input census includes 1,489 named writer slots, 1,450 route slots and
   1,360 constructor/query slots; these are intentionally permissive, not
   simply missing model-valued arguments. Another 5,338 are other arguments.
   Casting inputs cannot be typed from their reader schema, and observed
   callers cannot exhaust the public call boundary. A useful generic fix needs
   version/owner-matched declared signatures, or opt-in runtime observations
   labeled observed, not propagation of the current tests' arguments as static
   truth. There is **no measured nonzero lower bound** for an import/observation
   pass yet; its yield depends on actual upstream signatures or executed
   methods. Shape correction/removing forwarding placeholders is not recovery.

2. **Unresolved bodies (4,497): budget roughly 100–300 further static return
   slots for a bounded control-flow/dataflow pass**, not thousands. This rough
   estimate assumes only a few percent have fully typed normal-exit values
   after adding explicit `return`/`case`/rescue joins and better local flow.
   It is not an AST-measured forecast. Existing unresolved final call contracts
   illustrate the limits: CASA has 160 `untyped#[]=` dependencies and Campfire
   72; these are candidates for assignment-value semantics, **not 232 promised
   recoveries** (the RHS can itself be unknown). CASA also has 28 and Campfire
   9 `untyped#permit` dependencies: `require` can return a scalar, so calling
   it Parameters from the name would be wrong. Correct CFG exit/exception
   joins, once-only evaluation, mutation invalidation, receiver-sensitive
   APIs and source-backed asymmetric regressions are prerequisites. Blocks,
   callback self and controller-to-view state need separate analysis.

3. **Missing effective-owner returns (2,786): a scoped Rails/View/Turbo signature
   import/catalog pass is the best next bet; budget roughly 300–700 static
   slots**, conditional on finding usable contracts. This is also a planning
   range, not a checked import result. Campfire alone contains 693 Turbo
   broadcast-return slots, 198 TagHelper, 165 CaptureHelper and 99
   OutputSafetyHelper slots. These are repeated effective slots, not that many
   distinct APIs. Some broadcast helpers have variable publisher/job return
   types and may remain unknown even with good parameter signatures. CASA's
   largest owner groups are ApplicationController 320, Draper 108, Devise
   helpers 79; one import cannot solve all three, and app-owned wrapper results
   cannot be taken from a framework name. The work is a pinned, read-only RBS
   importer or small tested catalog, boot owner/source/version matching,
   generic receiver substitution, and preserving `untyped` in unsupported
   unions. Do not import Roundhouse replacement-runtime contracts as if they
   described real Rails. **2,786 is an upper bound, not the estimate.**

In particular, `delegated_type`/polymorphic association or JSON/store support
alone cannot remove thousands here: those direct return buckets total only
53 slots, although their effects on callers could be larger and are unmeasured.
The ranking argues for real framework/gem contracts before another small DSL
enumeration, while retaining the intentionally unknown argument boundaries.

## What this change fixes generically

- **Unknown values no longer mean unknown control flow.** A normal-completing
  call/read with unknown result does not hide a known sequence tail. Early
  returns, arbitrary blocks, splats, forwarding and other unsupported control
  flow still refuse. Predecessor advisory effects demote a literal tail to
  static. This corrects the two old proof labels above.
- **Containers and bounded branches.** Arrays/hashes retain outer shape and
  independently known member types, keeping unknown members untyped. Both
  conditional arms are joined; missing arms include nil, and only locals
  available on both paths survive. Interpolation has a String result on normal
  completion. All these new compound facts are static. Hash key conversions,
  interpolation conversions and constant autoload boundaries invalidate local
  knowledge; they cannot leave a stale literal proof behind.
- **Missing real-Rails call contracts.** Owner/source/version-matched `where`,
  `exists?` and Parameters `permit` are advisory. No-argument `where` is a
  WhereChain, not a Relation; a whole-method signature retains their union.
  An unknown `require` result remains unknown, even before `permit`.
- **Usable exports beyond the blog.** CASA subclasses Struct. RBS already
  defines `Struct[E]`; emit its subclasses as `Struct[untyped]`, not an invalid
  non-generic redeclaration. All six exports now validate.

These fix subcases of unresolved source bodies and framework contracts, **not
the entirety of the top three buckets**. No new proof engine or whole-program
parameter inference is claimed. Facts retain every slot's evidence/source.

## A real Fizzy MCP session

Run `script/types-mcp-smoke .corpus/fizzy --lowrail target/debug/lowrail`.
It launches the actual stdio server, initializes it and lists tools, then checks:

| Query | Checked answer |
|---|---|
| `type_at_position`, `app/controllers/comments_controller.rb`, **31:15** | `Comment.new`, return `Comment`, evidence **static**, `proven_type: null` |
| `type_of`, `CommentsController#new_comment` | `() -> Comment`, matching the constructor call in its body |
| `find_definition`, `CommentsController#new_comment` | Same file, **line 30**, source-backed `def` |
| `find_definition`, `Comment.new` | Actual `ActiveRecord::Inheritance::ClassMethods` source and line containing `def new(attributes = nil, &block)` |
| `type_at_position`, dynamic `@comment.update!` call | Explicitly unavailable; receiver type not guessed |

The script independently checks Fizzy's source lines, reads the effective Rails
constructor source and verifies the app source was not changed. Fizzy file
SHA256: `79d12b6e001b4a35dd3ed302a681f6034a4442321f49e7b37197e33a90dd5075`.
The two source tools are bounded queries, not an LSP: positions are **one-based
UTF-8 byte columns at a method-name token**; dynamic receivers, ambiguous boot
contexts and implicit calls inside blocks do not get guessed. Calls cannot
inherit body-proof status. Definitions report the real boot source/generator
location, not a fabricated declaration for generated methods. Source contents
now invalidate the MCP type cache as facts/observations already did; this is
not live execution certification, and changed lookup still needs fresh facts.

## Inputs, validation and limitations

Pinned sources: [Fizzy](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9),
[Campfire](https://github.com/basecamp/once-campfire/commit/02023b0f0cafc4d66e06e43be072cf4d6ca328fa),
[CASA](https://github.com/rubyforgood/casa/commit/b584d2e6e6ebffe382f34c2ec202d20384d035ca),
[Writebook](https://github.com/basecamp/writebook/commit/be1f8fcf1b0fc8064011c2d29d75133885b182e2).
Blog is the retained `real-blog-r4` fixture recorded in the JSON source pin.
Lobsters is the unchanged ruby-bench `351a39b77e6c06f4f4fa03148639b10a6bb0c716`
workload plus Lowrail's already-committed dependency overlay, not an upstream
checkout to edit or contribute to. No upstream activity occurred.

Boots completed, but the materialization census still records unavailable
optional engine tables: blog **21**, Fizzy **16**, Campfire **1**, CASA **1**,
Writebook **3**, Lobsters **0** errors. Sites/counts remain in the JSON; they
are not erased to call the census complete. Writebook's known production
SQLite-warning refusal is unchanged; this row is its test-environment boot.
CASA uses a disposable local PostgreSQL database; no production credentials.

Lobsters policy correction: its initial Lowrail facts/generated captures were
written inside `.lowrail`, then **moved outside the workload**. RBS outputs
were external throughout. The old types after relocation are byte-identical;
the workload now has no `.lowrail`. The new `types APP --facts EXTERNAL_JSON
--rbs EXTERNAL_DIR` option allows this directly, with no app writes. Only the
unchanged app's ordinary tmp/log/database runtime outputs remain inside the
disposable copy. Nothing is offered to or published to Lobsters; the owner may
still exclude that row.

Validation on the changed Lowrail tree:

- `cargo test --locked`: **41 unit + 2 types/MCP integration + 8 verify tests**,
  zero failures/ignored tests. `cargo build --locked` succeeds.
- `LOWRAIL_STRICT_GATES=1 ruby -Igem/lib -Igem/test -e 'ARGV.replace(%w[--seed
  1379]); %w[facts materialize observe].each { |n| require_relative
  "gem/test/#{n}_test" }'`: **22 runs / 255 assertions / 0 failures / 0 errors**,
  one named optional skip: `MaterializeCorpusTest#test_campfire` expects
  `.corpus/campfire`, while this workload is `.corpus/campfire-r81`. Its separate
  types/RBS row ran. An earlier invocation omitted `-Igem/lib` and failed before
  tests with LoadError; that log is retained, not reported as a test result.
- `rbs -I OUT validate`: **6/6 pass**; before was 5/6 (CASA
  `RBS::GenericParameterMismatchError: Struct`). The negative regression for
  stale interpolation-local knowledge failed first, then passes with invalidation.
- Fizzy's scripted MCP checks above pass. Rust transport regressions also check
  changed-source refresh, invalid coordinates/paths and unsupported receivers.
- Blog's output is unchanged. Its earlier **Steep 51 → 2** remains a separate,
  non-gating result, **not rerun in this batch** and not a clean app type check.

Reproduce exports outside every app, preserving baseline snapshots first:

```sh
lowrail types APP --rbs /tmp/NAME-after-rbs > /tmp/NAME-after.json
# For an external facts workload, add: --facts /tmp/NAME-facts/facts.json
rbs -I /tmp/NAME-after-rbs validate
# Record validate exit status in NAME-after-validate.status (likewise before).
script/types-coverage --before BEFORE_DIR --after AFTER_DIR \
  NAME=FACTS_JSON > /tmp/coverage.json
script/types-mcp-smoke .corpus/fizzy > /tmp/fizzy-mcp-session.json
```

The companion review evidence contains full before/after type JSON and RBS,
validation statuses/logs, the complete MCP transcript and test logs. Raw boot
facts/application configuration are **not** published in that bundle.

## Pre-integration Thermos follow-up

The independent correctness/security review found no introduced blocker.
The maintainability review raised three structural concerns. The confirmed
output issue, redundant nested unions such as `((String | nil) | String)`, is
normalized to `(String | nil)`, including nullable arms. Nested generic
arguments remain intact, and unknown arms still dominate. New public-model
regressions cover nested conditionals and unions of differently typed arrays.
The six exports/ledger were regenerated; coverage counts are unchanged.

The other two proposed redesigns are not adopted: `Option<Type>` deliberately
distinguishes a normal-completing **unknown value** from unsupported control
flow, and conservatively demotes rather than invents proof. Likewise the
catalog's optional argument-presence fact describes only fixed arity: Rails
`where()` is a WhereChain, but `where(nil)` is a Relation. Value inference is
not required for this split; blocks/splats/forwarding are refused upstream.
Those contracts are explicit, and the catalog retains a whole-method union.
A complete new type AST/effect system would be broader than this change and
the existing name-based type model. The `permit` shape-only fallback remains
necessary when its typed catalog refuses unsupported sources/versions.
