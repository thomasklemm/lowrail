# Literal-class block links: design before pricing

2026-10-21. **Bench-only design, not production admission or cohort approval.**
No runtime widening or measurement. The selected shape is a bare block `link_to`
with a sole literal String `class:` option. The [source census](helper-discovery.md)
finds74 HTML-ERB sites: Fizzy23/CASA20 are the43 current boot/delivery
opportunities; Writebook27 and Wikino4 remain excluded. These are not admitted
units or runtime hits. Shapes1/3 and all forms remain refusals.

**Recommendation:** price a source-preserving variant inside the original
`UrlHelper#link_to` invocation, keeping the template's original block and
method frame. Do not move the literal block to a new `capture` callsite or
wrap it in a new Proc. This is a proposal, not an existing delivery feature.
If the specimen cannot preserve that control-flow/provenance boundary, stop
before pricing rather than approximate it.

## Live calls and legal continuation

Rails8.1.4 sources:
[link_to](https://github.com/rails/rails/blob/v8.1.4/actionview/lib/action_view/helpers/url_helper.rb#L198-L208),
[content_tag](https://github.com/rails/rails/blob/v8.1.4/actionview/lib/action_view/helpers/tag_helper.rb#L516-L524),
[capture](https://github.com/rails/rails/blob/v8.1.4/actionview/lib/action_view/helpers/capture_helper.rb#L47-L65),
[OutputBuffer](https://github.com/rails/rails/blob/v8.1.4/actionview/lib/action_view/buffers.rb#L42-L78).

Keep this order, with the actual original block:

1. Evaluate template arguments, then link_to's block-form argument
   reassignment/options defaulting. Keep options conversion live once.
2. Keep `url_target`, routing/defaults/to_model/to_param as applicable and
   `html_options["href"] ||= url` live, in order. URL errors must occur before
   any block work. No route/model/config/I18n folding.
3. Keep content_tag's name validation and block-form argument selection.
   Critically, **evaluate and save the tag_builder receiver before capture**:
   Ruby evaluates the receiver of
   `tag_builder.content_tag_string(name, capture(&block), options, escape)`
   before its arguments. A standalone event probe produced
   `builder, capture, block`; overwriting `@tag_builder` inside the block did
   not change which builder rendered the original tag.
4. Keep `capture(&original_block)` live once. Its OutputBuffer raw-buffer
   swap/restoration, nonblank-buffer versus block-return selection, escaping
   and return-type handling stay stock. Do not assume a block returns HTML
   or returns the same buffer it writes. Preserve its original lexical
   self/locals/ivars and break/return target, not just its source text.
5. Only after normal capture completion, consider folding the literal outer
   tag/class formatting. Keep the captured builder, dynamic URL escaping,
   PRE_CONTENT_STRINGS lookup and remaining live content work in stock order.
   Return a fresh correctly encoded SafeBuffer. Nil capture emits an empty
   tag; it does not suppress the tag.

No block code is inlined/folded. SQL, image/local-time helpers, notifications,
content_for, locale/config reads, nested render and arbitrary block effects
stay live once. A captured SafeBuffer with unsafe state is not assumed safe.
No value gets stringified/escaped early merely to test eligibility.

| Point of refusal | Continuation |
|---|---|
| Before original helper work | Entire original link_to, with already evaluated arguments and the original block. |
| After options conversion/URL, before content_tag work | Original content_tag with converted options and the original block; never link_to again. |
| After validation/builder selection/capture | The **saved receiver's** content_tag_string("a", captured_content, converted_options, true). No second validation, builder lookup, capture or URL conversion. |
| Raise/throw/break/return during capture | Propagate the original unwind. Stock ensure restores raw buffer; do not rescue and replay a helper or build a tag afterward. |

Only insert guards where the refused continuation is still exact. If tag
option/content normalization has begun, retain an exact suffix with its
saved intermediate values or refuse earlier. StreamingBuffer/custom capture,
unmodeled control flow or template introspection boundaries remain original.
Retargeting `break` to a new capture call would incorrectly allow subsequent
tag assembly; retaining the original helper invocation avoids that rewrite.

## Owner-scoped passive provenance, not inferred purity

Build a finite certificate per concrete view/template/compilation/locals/site
context, not a global ArticlesController substitute. A shared partial may
have several contexts. The first **natural wholly original invocation in
each context** must complete before that context can be admitted. A witness
for one navigation link does not admit all23 sites or another controller.

The sealed owner owns admission and witness design. A proposed witness must
observe, without replay or forced materialization:

- Actual controller/view holders, current compiled template/container,
  handler/resolver/locals, unchanged source and delivered ISeq provenance;
  actual original Proc and its already-compiled block ISeq/site identity.
- Stock effective link/content_tag/capture/TagBuilder method bodies,
  visibility, literal/regex bindings, String/Hash primitives, escaping and
  native constructors, independently pinned to audited8.1.4 source.
- The actual naturally used OutputBuffer, raw-buffer restoration, and the
  **pre-capture builder receiver** plus its natural constructor/view relation.
  Do not substitute the post-block `@tag_builder` value. Per-hit holder,
  encoding/safety/options, request/Ractor and seal guards remain necessary
  after live boundaries too; an epoch alone is not object provenance.

No binding materialization, ObjectSpace fallback, forced load/lookup/SQL,
runtime build inventory, active probe or on-only prepend/ancestry. Use the
owner's bounded passive observer discipline; one attempt per context,
terminal refusal on failed certification, no retained block/view graphs.
An interrupted original call supplies no successful witness.

Existing Native.exact_class? establishes only an actual class, **not** a
Proc's ISeq/binding. Form's existing block signature is not general link
authority. Do not assume a new native primitive, free ISeq attestation or a
source_location-only proof. The specimen must make its concrete observer,
source/compiled-context attestation and hot guards explicit and charge their
entire cost. If the context cannot be established passively, refuse it.

Observing a block once proves neither purity nor future inputs. Here the
block is kept live, not specialized; do not assume its lexical self equals
the helper view or inspect its Binding to make that assumption. The seal
must still cover structural changes to folded dependencies, including those
attempted by URL conversion or the block. Existing no-introspection and
unsupported-boundary rules stay explicit. This is not a small table-only
extension to the current no-block link certificate.

## Fizzy's23 sites require a route vector, not23 repeated micro calls

Use unchanged public pin
[`6f1d200`](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9),
its frozen corpus8.1.4 overlay and isolated external data. Routes below come
from config/routes.rb and actual render calls. They are **proposed
reachability**, not executed coverage. Cold production HTTP must establish
the exact file:line hit/fallback ledger before choosing any counted windows.

| Existing GET | Candidate sites expected from source |
|---|---|
| /buckets (also root) | buckets/index:5; buckets/_bucket:2,16,20; filters/_filter:3,17; notifications/_tray:6. |
| /bubbles with permitted filter params | bubbles/index:9; bubbles/_bubble:33; bubbles/list/_bubble:3,12; filters/_assignees:22, _buckets:21, _creators:23, _settings:20, _stages:21, _tags:20; notifications/_tray:6. Up to11 identities, not all23. |
| /account/users | accounts/users/index:5,18. |
| /workflows | workflows/index:13; workflows/_workflow:17. |
| /notifications | notifications/index:14. |
| /buckets/:bucket/bubbles/:bubble | comments/_body:6, if a comment is rendered. |

The union is23 identities (tray shared), not a prediction of invocation
counts. Use a natural authenticated session through the app's sign-in,
HTTPS/host and ordinary Rack entrypoint. External disposable data should
include two accessible buckets, a matching published bubble, comments,
saved filter, workflow/stage and allowed creator. The primary /bubbles
request uses permitted bucket_ids/creator_ids/stage_ids with an actual
nonempty result, exposing conditional clear-filter links. Derive IDs/URLs
from the disposable fixture; never hard-code assumed production IDs. No
controller/model shim, app patch, fake Current, jobs or production credentials.

Preserve real fragment/collection caching. Cold correctness may visit all23;
warmed requests may execute fewer sites. Record both, per site, with actual
invocations/completed hits/fallbacks. **Do not disable caching, reset it to
manufacture hits, add a loop to a template or replay captured closures** to
turn source sites into priced runtime work. Cache-elided or unreachable
sites remain unpriced; zero warm hits stops that unit's pricing claim.

## One finite pricing-only cohort, after untimed gates

No existing production artifact may be widened just to price the specimen.
Keep the specimen private/external to admission/registry, source-pinned and
non-deployable. A shared-driver adapter for the fixed six-request vector,
if absent, is an explicit pre-cohort task; do not silently replace it with
six cohorts or unrepresentative isolated helper calls.

Proposed pre-registration: one vector containing the six GETs above, same
fixed order/multiplicity in every arm, six independent fresh-process rounds,
seed41231 and the published fixed-heap/window/tool protocol in [bench.md](bench.md).
This is a coverage-oriented workload, not production traffic weighting.
No workload selection after seeing a price. If untimed reachability cannot
establish it, revise the proposal before any cohort, not after a rejection.

Arms: original_a, independent original_b (A/A), and the guarded specimen.
All boot the same pinned gem/native binary/source universe with symmetric
passive setup and delivery; other passes are off. Original arms run original
helpers/blocks, specimen includes all witness/selection/guards/fallbacks and
live operations above. No unpriced “always authorized” shortcut. Ruby4.0.7,
**interpreter certified in every worker**, including disabling production's
config.yjit before initialization; actual YJIT/ZJIT state, not env alone.

Required before the one counted cohort:

- Cold real production off/off/on: full status/body/all headers, render/event
  nesting/payload/assigns, ordered SQL, DB state, session/cookie behavior and
  post-exit work equal; feature load order, ancestry, method metadata and
  native/source delivery provenance pass. Raw entropy failures remain red
  unless a separately declared symmetric companion is accepted first.
- Boundary cases: empty/whitespace/String/SafeBuffer/nil capture, nested
  capture/content_for, multibyte/escaping, observable exactly-once effects,
  URL error before block, block raise/throw/break/return/next, buffer/builder
  replacement, custom helpers/eigenclasses/foreign owners, unsupported
  streaming, stale template/locals, seal mutation and concurrent first calls.
  Fallback preserves observations; no helper/block/conversion replay.
- Separate untimed cold and warmed count ledgers; first original remains
  original, admitted contexts have nonzero completed hits, and every claimed
  priced site is actually exercised. No counting guard attempts as hits.

Only then, after separate authorization, run **one interpreter cohort** with
both total and GC-excluded independent A/A gates, identical five actual heap
capacities, tool/brk/provenance/window checks, correct interpreter state and
completion/count-mix gates. Include whole-vector work and complete guard
cost. Preserve all raw/rejected workers; no retries, replacements, weakened
thresholds, cached-result borrowing, cherry-picking or additive extrapolation.
Cold witness/setup costs are reported separately, not assumed free. Failure,
unresolved provenance, no real warm hits or no supported saving means stop;
neither a green correctness gate nor a numeric ceiling admits production.

## Executed HTTP reachability (untimed)

The [machine ledger](fizzy-link-reachability.json) records all18 successful
production HTTP GETs following natural password/CSRF sign-in, Ruby4.0.7,
Rails8.1.4, interpreter. Stock fragment/collection caching stays enabled.
These are block-entry diagnostics, **not completed hits or admission**.

| Route, in fixed vector order | Cold entries | Warm | Warm repeat |
|---|---:|---:|---:|
| /buckets |10|10|10|
| /bubbles with fixture-derived filter params |11|8|8|
| /account/users |2|2|2|
| /workflows |2|2|2|
| /notifications |1|1|1|
| /buckets/:bucket/bubbles/:bubble |3|1|1|
| **Whole vector** |**29 /23 identities**|**24 /19 identities**|**24 /19 identities**|

Warm cache elision: `bubbles/_bubble.html.erb:33`,
`bubbles/list/_bubble.html.erb:3,12` (one cold entry each),
`comments/_body.html.erb:6` (two cold entries). The report carries actual
cache/collection-hit events and per-route/per-site counts. The19 remaining
identities are opportunities only; a first natural invocation may still
refuse provenance, and the same partial may require multiple owner contexts.
The earlier suggested route reachability is now observed, not assumed.

Reproduce with the frozen corpus bundle and an isolated copy of Fizzy:

```sh
BUNDLE_GEMFILE=.corpus/fizzy-link/Gemfile BUNDLE_FROZEN=true \
  mise exec ruby@4.0.7 -- bundle exec ruby \
  bench/experiments/fizzy_link_fixture.rb .corpus/fizzy-link NEW_PRIVATE_STATE
# Run `fizzy_link_http.rb serve APP STATE PORT` as a supervised orb service;
# then `fizzy_link_http.rb probe APP STATE PORT`, and `report APP STATE`.
```

## Observation map required by sealed-owner review

All seams below must be delivered **symmetrically, before natural loading**,
from independently pinned stock sources with replacement ISeq evidence.
An unavailable seam means refusal, not an extra helper call or inferred fact.
Path/line TracePoint diagnostics above cannot supply any of this authority.

| Fact | Exact natural seam/read | Acquisition time | Retained evidence |
|---|---|---|---|
| Entry view/controller and template | `_run`'s actual `self`, `method`, `template`, `locals`, `buffer`, `has_strict_locals`; already-populated template fields, effective compiled method | Before `public_send`, saved/restored as a stack across nested renders | Finite context key, actual holder identities, source/encoding/handler/compiler/body digests, locals/strict-locals scalars; no view/request |
| Original block/site | Original `link_to` frame's `block`; `RubyVM::InstructionSequence.of(block)` associated with the already-compiled entry method's child ISeq tree | Entry, before any URL or block effects | Block ISeq digest and bytecode/code-location discriminator, not just file:line; no Proc or Binding |
| Stock constructor actually used | The stock `tag_builder` factory's own `TagBuilder.new(self)` result, with effective native Class#new and initialize checked at that operation | Immediately after its natural return, before capture | Weak builder identity token plus verified constructor/body/holder evidence; class plus `@view_context` is insufficient |
| Saved builder used for outer tag | Receiver evaluation in stock block `content_tag`, before the capture argument | Before block | Invocation-local saved receiver; weak provenance token only after completion |
| Buffer actually used and raw-buffer restoration | Stock CaptureHelper's actual buffer receiver; OutputBuffer#capture's `old_buffer`, `new_buffer`, and assignment in ensure | Before yield; ensure on normal/unwind paths | Invocation-local identities, restoration boolean, class/encoding scalars; never reconstruct from final view ivars |
| Post-capture dependencies | The **saved receiver** and its effective methods/visibility, actual converted Hash order/defaults, URL/content String/SafeBuffer state, current primitive/literal bindings | After normal capture, before any folded work | Predicate result for this invocation, unchanged epoch; a pre-block signature is not enough |
| Successful whole-original witness | Normal completion of the outer original link including final tag assembly | Last operation before returning normally | One bounded context's terminal state; publication last after validation/epoch check |

The finite manifest is closed before workers run. Unknown template,
controller/view, handler/compiler, locals/strict-locals or block-ISeq contexts
stay original; they cannot grow the inventory. Same-line calls and alternate
locals/compiler contexts must not alias. Nested renders cannot rewrite the
saved entry context. No constructor probes, resolver lookup, handler call,
`Template#compiled_source`, view-context construction or compiler/cache
warming may manufacture evidence. No retained Proc/view/request graph.

Each context gets a try-lock and a terminal attempt budget. The entry
decision is immutable: a call that chose original cannot become fast because
a nested/concurrent invocation publishes. Only successful **whole original
link completion**, validation and unchanged epoch publish admission. A
capture success followed by tag-assembly failure is not a witness; neither
are raise/throw/break/return. All first calls stay original.

After URL conversion, refusal continues through live `content_tag`; after
capture it calls the saved receiver's **live** `content_tag_string`, including
any singleton override the block just installed. Never invoke an old captured
UnboundMethod as fallback. Validate order/defaults of the actual converted
Hash and encoding/safety without coercion/app dispatch. Preserve tag-options,
content presence/escaping, live PRE_CONTENT_STRINGS lookup, interpolation
order. Once normalization begins, only a saved-intermediate stock suffix is
legal; restarting `content_tag_string` would repeat live work.

Required asymmetric controls, in addition to ordinary capture/control flow:

1. Replacing `@tag_builder` in the block does not replace the saved receiver.
2. Adding `content_tag_string` to that saved receiver in the block invokes
   the **new** method after capture, not its pre-block body.
3. Replacing `output_buffer` and returning it produces an empty anchor;
   old raw buffer is restored to `"old"`, replacement remains `"new+block"`.

The existing native `exact_class?` is only holder evidence: no Proc/binding
or constructor authority follows. The bench specimen must charge all seams,
manifest selection, witness, post-live guards and fallback costs. This review
accepts a direction, not a production certificate or measured cohort.
