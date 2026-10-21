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

## Executed bench-only gates

The [pinned machine report](fizzy-link-gates.json) records **42 untimed
workers**, all run from the clean detached harness
[`da5fe91`](https://github.com/thomasklemm/lowrail/commit/da5fe91e2f04a27acef1f7245efa7f39a7332577).
This is not the eventual documentation commit or a floating local main.
Each worker records its harness SHA, source/native/artifact/context hashes,
Fizzy source/lock fingerprints, and (for companions) the entropy-policy hash.
App and dependency pins remain the unchanged corpus fixture above.

The previous 40-worker run used a **local, pre-rebase** frozen commit,
`6c3342fd77b90557b8da0133bbc296013aad42d4`, not a published GitHub revision.
Its report remains in the history at
[`87356dd`](https://github.com/thomasklemm/lowrail/commit/87356dd9b4f2aefb5c65ed69b85cf20a57c6bc95).
The exact local commit is preserved in
`.lowrail/private/fizzy-link-gates-executed.bundle`, SHA-256
`7bbe6db52290ae9bafb0e4c705176e2b61e9c9f4a6b881758f5f048efdae55ba`,
with prerequisite
[`ea44cf3`](https://github.com/thomasklemm/lowrail/commit/ea44cf3e3c03d37595294512edbc9da0ab498073).
The refreshed export retains that run's raw-worker hashes and rejections;
the later SQL agreement does not erase the earlier failure.

Discovery, in a separate original process, froze **24 contexts across23
sites** before gate workers. A successful original call is still required
in each process/context; no contexts or cached builders are manufactured.
Rails stores file-backed source in a `Sources::File` wrapper and registers
an ERB handler **instance**. The bench therefore observes the actual encoded
source at normal compilation through a sixth symmetric, source-pinned seam;
it never calls Template#source/compiled_source, a handler, or a compiler to
create witness evidence. Missing natural compilation/constructor evidence
refuses. Eval block ISeqs use their actual `path`, with child-tree and full
location association, not a source-line-only authorization.

### Cold off/off/on: still rejected, not normalized

Two independent seeded sequences use the existing thread-scoped
`BlogProduction::Entropy` controls with a separately pinned Fizzy policy.
Both seeds have identical full HTTP status/body/headers, selected render and
controller events, load/feature order, ancestry, initial DB state and entropy
trace in all arms. There are zero capture or undeclared-entropy errors.

The separately named `fizzy-solid-cable-3.0.5-synchronous-v1` completion
adapter passes for all six workers. Its own version/source pins cover
3.0.5's synchronous broadcast/TrimJob.perform_now path and1.1.2 queue
adapter. It reads existing Cable ivars and the isolated queue DB; it does
not call shutdown (which would create a listener), create a server/adapter,
load a model, run a job, or reuse the blog4.1.0 writer-drain certificate.
Existing listener/worker/event-loop/heartbeat, unfinished queue work,
unknown adapters or source/version mismatches refuse. **This is Cable/queue
completion only, not SolidCache completion.**

Exactly168 cached lazy-bind events per worker are retained with the named
`binds_unavailable/cached_lazy_proc_not_invoked` value. Their SQL text,
cache-hit flag, order and other captured fields are compared. The Proc is
never invoked, query attributes are not recast, and unavailable bind values
are explicitly uncovered rather than invented.

Both complete comparisons remain **`rejected_off_control`**:

- SQL order agrees for both seeds at the refreshed pin. In the retained
  earlier run, other-thread SolidCache1.0.6 size-estimation SQL interleaves
  with request SQL: seed0 rejects SQL order and seed1 agrees. Neither run
  establishes a completed/ordered cache boundary.
- Cache writes contain `STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')`; fixing Ruby's
  Time.now does not fix SQLite's clock. Cache row timestamps/state differ
  even off/off. At the refreshed pin, all four seed/comparison pairs differ
  only in `created_at` on the nine `solid_cache_entries` rows. No timestamps,
  queries or database rows are discarded.

Compared event fields are controller/action/method/path/format/status,
identifier/layout/count/cache_hits plus captured flash. Arbitrary subscriber
payloads, controller assigns and cached Proc bind values remain uncovered.
Asynchronous SolidCache completion is outside the completion adapter and
remains a separate explicit gap. No general equivalence claim follows.

### Separate boundary controls:18 paired cases pass

Each of36 fresh processes naturally signs in and visits /buckets, then
renders the pinned labelled bench template on that already-used view. Only
the external control harness temporarily holds the view; the admission
registry retains no view/request/model/Proc graph. The control has its own
frozen context, first-original witness, and an exercised normal fast call
before the mutation. It supplies no Fizzy authorization or coverage.

All18 off/on outcome comparisons and independently specified checks pass:
normal, nil, whitespace, unsafe/safe Strings, nested capture, next,
raise/throw/break/return, saved-builder replacement, a new singleton method
on the saved builder, output-buffer replacement, foreign builder, streaming,
native-predicate replacement, and a URL error before the block. Captured
bytes/encoding and tag safety, once-only effects and completed-hit deltas
are checked. Saved-builder and
buffer replacement remain correct fast cases; singleton/foreign/streaming
cases exercise the saved receiver's live fallback. The streaming constructor
setup error from the earlier draft is retained as rejected setup, not a pass.
Its corrected case actually runs the block once and takes the buffer-
provenance refusal after the positive fast prelude.

The native control reproduces a bench dependency defect, not a new native
authority: replacing `Native.exact_class?` with `{ |*| true }` previously
left `dependencies?` true. The specimen now retains the originally loaded
native Method, uses that Method for holder observations, and checks its
effective identity after block work. The unchanged block dispatches `<<`
on an opaque local whose control-only method replaces the primitive.
After the fast normal prelude, the mutated call executes its block once,
adds no hit, takes the saved receiver's original suffix once, and preserves
the exact result. No Proc/binding/constructor authority is added.

Warm vectors complete **24 suffix hits across19 identities**, identically
in both seeds and both warm repetitions. Cold has5 hits after24 successful
first originals. The report includes the complete per-site warm map,
including four explicit cache-elided zeros; counts are not source coverage
or production admission.

### Reproduction and the held shared-driver adapter

Run the tracked `block_link_delivery.rb` build against the frozen corpus
bundle and an isolated fixture prepared by `fizzy_link_fixture.rb`. The
builder observes actual original production boot recipes; it does not render
templates. Use a clean detached worktree with its matching native extension,
then freeze original `discover` output before any `cold`/control workers:

```sh
# Ruby invocation throughout: mise exec ruby@4.0.7 -- bundle exec ruby
# BUNDLE_GEMFILE points at the frozen corpus Gemfile; BUNDLE_FROZEN=true.
# Every STATE is a new copy of the same external four-DB fixture seed.
BENCH_HARNESS_SHA="$PIN" ruby "$HARNESS/bench/experiments/fizzy_link_vector.rb" \
  discover "$APP" "$DISCOVERY_STATE" "$ARTIFACT" "$EMPTY_CONTEXTS" off "$DISCOVERY_JSON"
BENCH_HARNESS_SHA="$PIN" BENCH_ENTROPY_SEED=0 BENCH_ENTROPY_POLICY="$POLICY" \
  ruby "$HARNESS/bench/experiments/fizzy_link_vector.rb" \
  cold "$APP" "$NEW_STATE" "$ARTIFACT" "$FROZEN_CONTEXTS" off "$OUTPUT"
# Repeat off/off/on, seed0 and seed1, with distinct NEW_STATE paths.
ruby "$HARNESS/bench/experiments/fizzy_link_check.rb" cold \
  "$REPORT" "$OFF_A_JSON" "$OFF_B_JSON" "$ON_JSON"
```

For controls, use `block_link_controls.rb discover|gate` with its separately
frozen manifest; compare with `fizzy_link_check.rb controls`. Raw logs,
discarded setup attempts and complete private responses remain under
`.lowrail/private/fizzy-link-*`; public reports contain no session cookies.

`RequestPairs.heap_instructions` can consume the same vector driver via the
single route argument `VECTOR:fizzy-links`. The tracked adapter creates a
new per-worker state copy, records all pins, charges guard/witness/count
work, records each window's completed site mix, and refuses any change from
the predeclared warm map. One iteration means **six GETs**, not one request.
There is no cohort launcher in this slice. An unapproved invocation refuses
before starting a counter or creating worker state; that refusal was checked.
The measured path has not run. **No cohort approval, measurement, production
registration, form change or app patch is included.**

## Cache/clock decision before a cohort request

The actual frozen bundle is **SolidCache 1.0.6 / concurrent-ruby 1.3.4 /
sqlite3 gem 2.5.0 / SQLite 3.47.2**. This is not a conclusion from another
sqlite3 or SolidCache release. Source hashes are in the machine report.

**Completion is possible, but does not make this workload deterministic.**
SolidCache's existing
[`@background`](https://github.com/rails/solid_cache/blob/v1.0.6/lib/solid_cache/store/execution.rb)
is a one-thread `FixedThreadPool` with queue capacity 100 and discard fallback.
Its own tests wait for completed/scheduled counter equality. A separately
source-pinned adapter could read that already-existing pool after request
submission stops, or terminally shut it down and wait. This can attest only
accepted tasks, not discarded posts, swallowed failures, or work arriving
after the boundary. It must not post a sentinel, create an executor, force
cache/model loading, or claim that every requested expiry ran. No such
adapter was added here; **SolidCache completion remains uncovered**.

That boundary cannot recover a single exact SQL ordering or final cache
state. Expiry reads current ids and sizes; its moving-average estimator
also upserts a cache entry. Sampling/deletes and request writes can therefore
observe different database states. Comparing SQL as a set/multiset would
hide relevant ordering, not prove equality. Waiting after every request
would instead define a new, explicitly serialized workload. Neither is a
silent repair of the existing six-request vector; no pool/scheduler/cache
policy is changed. The historical interleaving rejection is accepted as
a **named off/off rejection**, not an equality pass.

**No supported fixed DB-clock option exists in this pinned driver.**
[`Database#initialize`](https://github.com/sparklemotion/sqlite3-ruby/blob/v2.5.0/lib/sqlite3/database.rb)
can select an already-registered VFS by name; it exposes no Ruby VFS clock
setter. Stock SQL `now` reads the VFS clock, not Ruby `Time.now`. A real
in-memory probe fixed Ruby to `2026-01-02 00:00:00 UTC` while two SQL
`strftime` reads still returned changing `2026-10-21` timestamps. Minimal
probe, outside any app:

```ruby
require "sqlite3" # the frozen bundle's 2.5.0, loaded SQLite 3.47.2
db = SQLite3::Database.new(":memory:")
class << Time
  def now = at(1767312000)
end
sql = "SELECT strftime('%Y-%m-%d %H:%M:%f', 'now')"
p [Time.now.utc, db.get_first_value(sql)]
sleep 0.02
p [Time.now.utc, db.get_first_value(sql)]
```

Replacing SQL functions, building a custom VFS, or adding a process-clock
interposer would change the harness/input provider, not use a stock app/DB
setting. None is installed or proposed as an unreviewed workaround. Keep
the SQLite timestamp difference as the second named, accepted off/off
rejection under the coordinator's scoped-rejection instruction. **The cold
status stays red**, and arbitrary payload/assigns, cached lazy-bind values
and SolidCache completion stay explicitly uncovered.

A request for **one interpreter-Ir cohort**, not authorization to run it,
can name the published harness above, the app/lock/native/artifact/context
pins in the JSON, and the full 23-site warm map. One iteration is six GETs:
24 completed suffix hits over 19 identities, including three bucket-partial
sites with 2 hits each and the tray site with 3; fifteen sites have 1 and four
cache-elided sites have 0. N=50 therefore expects 1200 hits across 300 GETs in
each warm on window, not 1200 admitted source sites. Every per-hit context,
guard, observation, literal/dependency check and counter stays inside the
workload. First-original acquisition/setup precedes the warm windows and
is not a cold-start price. A/A, heap, mode and per-site mix gates remain
mandatory; no retries/exclusions, YJIT cohort, production promotion or
measurement approval follows from the accepted off/off rejection ledger.

## One authorized interpreter cohort (2026-10-21)

**Decision rule, before the result:** exact per-site mix, harness/input pins,
interpreter mode, fixed heap/pages and brk checks are mandatory. Any mix
deviation makes the cohort INVALID, not a different-priced workload. Both
total and GC-excluded A/A 95% intervals must include zero and lie wholly
within ±0.5%; either failure rejects the whole comparison. No retries,
exclusions, replacement cohort or YJIT run.

The coordinator authorized exactly one slot and one six-round cohort,
seed 41231, N=0/50, arms off_a/off_b/on, using the clean detached published
[`da5fe91`](https://github.com/thomasklemm/lowrail/commit/da5fe91e2f04a27acef1f7245efa7f39a7332577)
harness and unchanged Fizzy/Ruby/Rails pins above. Workers run
sequentially. Each N=50 on window must complete exactly 1200 suffix hits:
50 times the preregistered 23-site map (24 hits/19 identities per six GETs),
including the four explicit zeros. N=0 and both off arms must add zero hits.
The decision rule, full map, fixture and harness/tool/input hashes were
written before counters started. The source-pinned brk512 build and real
production allocation preflight pass.

**Completed INVALID: the mandatory fixed-heap gate fails in both arms.**
All 18 workers finished untouched. The [full diagnostic export](fizzy-link-ir-invalid.json)
retains every worker, source/tool/input pin, window, per-site ledger and raw
dump digest; 72 independent self-cost sums match dump totals and windows,
36 N0 subtractions reconcile, and a separate bootstrap reproduces every
reported estimate. No delta is a price or direction claim. Pool0 grows beyond
611 pages and pool2 beyond 246; there are 114 exact-page boundary violations.

| INVALID diagnostic only | On/A Δ% [95% interval] | Off-B/A Δ% [95% interval] |
|---|---:|---:|
| Total Ir | +0.415777 [+0.364704, +0.733074] | −0.006604 [−0.054151, +0.004149] |
| GC-excluded Ir | +0.413692 [+0.364724, +0.448149] | −0.006938 [−0.059915, +0.001993] |
| Allocations, diagnostic | +0.538933 [+0.536155, +0.540132] | +0.000221 [−0.001859, +0.001633] |

Both A/A controls, interpreter mode, all pins, brk and the exact 1200-hit
full-on-window map pass; none rescues the failed heap precondition. Units
are Ir per **six-GET vector**, not one GET. Total/no-GC are separate
executions, not a GC-saving decomposition. The original service and slot
are released. No exclusions or retry. Cold off/off/on remains RED. Accepted
off/off rejections remain the nine cache-row `created_at` values and the
historical order-sensitive SolidCache SQL interleaving. Payload/assigns,
lazy cached-bind values and SolidCache completion remain uncovered. No
completion adapter, serialization barrier, clock interposer or app patch
is introduced by the pricing run.

## Untimed heap preconditioning: prefer N=10 on the existing tool

**Untimed evidence; the subsequent N=10 approval is recorded below.** The tracked
[`fizzy_link_heap.rb`](../bench/experiments/fizzy_link_heap.rb) uses
**Valgrind tool=none**, never starts an Ir cohort, and exports every window's
pages and exact hit ledger. The [machine report](fizzy-link-heap.json) retains
failed experiments as well as the final two phase-order pairs.

The invalid precondition was treating init slots as a fixed capacity. Ruby
4.0.7's
[`heap_prepare`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/gc/default/default.c#L2061-L2088)
grows toward the init floor, but can then consume global growth credits;
sweep completion and lazy-sweep page claiming can add pages too. The shared
preparer fills to declared pages and retains sparse anchors, but cannot turn
the floor into a cap. Both off and on grow. A native trace of each added page
was not captured; the report distinguishes those source mechanisms from the
observed page/credit counters.

Three untimed alternatives failed and remain recorded: four times observed
capacity still grows in both arms; three extra minor collections still grow;
an N=50 whole-window budget needs 988 MB of slots and hits the existing tool's
`VG_N_SEGMENTS` host-map limit before a worker result. No larger-segment tool
was built or used. Do not change the tool or use a failed run's delta.

Instead budget the **entire N=10 window**, not its post-collection live heap.
For each pool, take the maximum over the original untimed off worker's full
windows of `start live slots + all allocations`, add 50% headroom, preserve
the original floor and round upward to 10000 slots. Freeze this one policy
before the revised on worker; never calibrate independently per arm. It is
a finite observed-workload envelope, **not a Ruby hard heap cap or a universal
allocation bound**; unchanged exact gates still refuse any later growth.

| Pool / slot bytes | Off uncollected N=10 budget | Frozen init slots | Exact pages |
|---|---:|---:|---:|
| 0 / 40 | 2,226,770 | 3,350,000 | 2047 |
| 1 / 80 | 196,392 | 300,000 | 367 |
| 2 / 160 | 305,686 | 460,000 | 1128 |
| 3 / 320 | 13,452 | 30,000 | 148 |
| 4 / 640 | 7,166 | 20,000 | 199 |

This reserves 254,000,000 slot bytes, about 242 MiB before metadata. A new
untimed off/on pair passes. Fresh final off/on pairs in **both** shared-driver
phase orders also pass every before/after page target, with **zero additions
to any pool's `total_allocated_pages` inside all 16 windows**. Each full on
window completes exactly 240 hits across 19 identities, including the same
four explicit zero sites; N=0/off adds zero. The tool remains the published
brk512 build: Callgrind binary SHA256
`025bec186951cffc94b2ccb000c0edb53e48d594a56d25f16dc641eec26c0d36`.

The worker harness remains the clean detached
[`da5fe91`](https://github.com/thomasklemm/lowrail/commit/da5fe91e2f04a27acef1f7245efa7f39a7332577).
Only N and the identical process heap-init environment change. App source,
config, fixture, guards/witness, natural sign-in, two-vector warmup, three full
collections per window, settle vector and counter/estimator seams stay the
same. No compaction, per-request collection, GC disabling or clock adapter.

Reproduce untimed, using the same frozen corpus bundle and native extension:

```sh
# BUNDLE_GEMFILE=$APP/Gemfile; BUNDLE_FROZEN=true; Ruby 4.0.7.
# PATH/CPATH select the existing pinned brk512 tool; every OUT must be new.
ruby bench/experiments/fizzy_link_heap.rb baseline 10 \
  "$APP" "$SEED" "$ARTIFACT" "$CONTEXTS" "$HITS" "$HARNESS" "$PIN" "$BASE"
for phase in 0 1; do
  BENCH_PHASE_ORDER=$phase ruby bench/experiments/fizzy_link_heap.rb verify 10 \
    "$APP" "$SEED" "$ARTIFACT" "$CONTEXTS" "$HITS" "$HARNESS" "$PIN" \
    "$OUT-$phase" "$BASE/result.json"
done
```

Validation: Ruby 4.0.7 syntax passes; an independent report audit checks all
four final workers / 16 windows, exact pages, zero additions, both window
modes and the complete per-site maps. `CPATH="$TOOL/include" ruby
bench/request_pairs_test.rb --verbose` passes 17 tests / 317 assertions,
with two counter-dependent skips because this test shell does not put
Valgrind on PATH. The actual heap probes above explicitly select the pinned
Valgrind tool=none. No extra instruction workers were started by the tests.

**Exactly one replacement authorized and completed below:** six rounds, seed 41231,
N=0/10, off_a/off_b/on, jobs=1, reusing the released original slot, the frozen
floors above and the same tool. The original untimed JSON retains its
request-only proposal as historical evidence; approval does not alter those
probe bytes. The replacement is not pooled with N=50.
The exact on-window gate scales to 240, not 1200; its 23-site map and four zeros
are unchanged. Both total/no-GC A/A 95% intervals must contain zero wholly
within ±0.5%, with all pin/mode/brk/heap/mix gates; no retry, exclusions,
YJIT or another N after a failed A/A. A failed A/A is reported REJECTED.
The accepted result below is only a scoped warm bench comparison of
these six GETs, not production admission or cold-start cost. Cold remains
RED with the named timestamp/interleaving rejections above; payload/assigns,
lazy cached-bind values and SolidCache completion remain uncovered.

## Replacement result: scoped warm bench price, not a win

**Decision rule before the numbers:** INVALID on any exact mix, pin, mode,
brk or exact-page deviation. Both total/no-GC A/A 95% intervals must contain
zero wholly within ±0.5%; otherwise REJECTED, not a reason to try another N.

**Accepted only as a scoped warm bench price for these six Fizzy GETs at
N=0/10 and init slots `[3350000,300000,460000,30000,20000]`.** This specimen
increases instructions; acceptance is of the controlled measurement, not a
win, runtime admission or product promotion. Cold off/off/on remains **RED**.
Accepted named off/off rejections remain nine SolidCache `created_at` values
and historical order-sensitive estimation-SQL interleaving. **Uncovered:**
payload/assigns, lazy cached-bind values and SolidCache completion. No
production admission, cold-start, latency, YJIT or whole-app claim.

| Metric / six-GET vector | Off-A median | On median | On/A Δ% [95% interval] | Off-B/A Δ% [95% interval] |
|---|---:|---:|---:|---:|
| Total interpreter Ir | 681,459,115.15 | 684,282,312.00 | **+0.403071 [+0.386235, +0.429585]** | −0.022014 [−0.046920, +0.026381] |
| GC-excluded Ir | 674,432,187.70 | 677,171,714.05 | **+0.402000 [+0.380081, +0.421142]** | −0.029792 [−0.042940, +0.026493] |
| Allocated objects, diagnostic | 208,158.60 | 209,276.80 | +0.536278 [+0.533744, +0.539356] | +0.002402 [−0.001057, +0.006077] |

Percentages are medians of six paired round ratios, not ratios of the
absolute medians. Bootstrap resamples whole rounds. Total/no-GC are separate
executions, not a GC-saving decomposition. Some windows record one
collection; fixed pages do not mean GC is disabled.

The original INVALID service/slot was released at **20:06:40 UTC**; this one
replacement started at **20:08:23**, never concurrently. It completes all 18
sequential workers, six rounds / seed 41231 / off_a/off_b/on / jobs=1, on the
same clean detached
[`da5fe91`](https://github.com/thomasklemm/lowrail/commit/da5fe91e2f04a27acef1f7245efa7f39a7332577)
harness, Fizzy
[`6f1d200`](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9),
Ruby 4.0.7 / Rails 8.1.4 overlay and unchanged brk512 binary above. All
per-worker source/native/lock/artifact/context pins pass. No retry,
exclusions, app/config/GC-policy change, higher-segment tool or pooling with
N=50. The replacement service and slot are released too.

Both A/A controls pass. Every one of the **72 measured windows** retains
exact pages `[2047,367,1128,148,199]`, with **zero additions** to any pool's
`total_allocated_pages`. Each full on window has exactly **240 hits over 19
identities**, all four explicit zero sites remain zero, and off/N0 adds zero.
Independent validation sums every dump's self costs (not inclusive call
costs), matching all **72 totals** and window values; all **36 N0
subtractions** and the separate bootstrap estimates reproduce exactly.
Input/fixture hashes remain unchanged afterward; the detached tree is clean.

The [complete numeric export](fizzy-link-ir-n10.json) retains the preregistered
rule, all inputs/tool/native pins, actual caller source, every worker/window/
site map, all raw dump/log digests and the independent reconciliation. The
earlier [N=50 export](fizzy-link-ir-invalid.json) remains **INVALID diagnostic
data only**, not a price/direction claim or a sample pooled into this result.

## Why this specimen loses: offline attribution, not another cohort

**Production widening is PARKED.** No further block-link cohort is running.
The following analyzes only the existing accepted N=10 dumps from the frozen
harness above. It does not change the result, cold RED status, named accepted
off/off rejections or uncovered payload/assign, lazy-bind and SolidCache
completion gaps. It is not a new screen or a new causal experiment.

### What the dumps can and cannot identify

The dumps have native C function symbols and `positions: line; events: Ir`,
not interpreted Ruby method, ISeq or ERB-site frames. `link_to`,
`content_tag_string` and `BlockLinkSpecimen` have no distinct function symbols.
Therefore **saved Ir and added Ir per site are unavailable**. Dividing net
request Ir by 24 would not recover either quantity, or separate guards from
rendering. Nor does a reduction in one native function establish which Ruby
call removed it. Do not assign a common average to asymmetric sites.

The [offline analyzer](../bench/experiments/block_link_attribution.rb) resolves
compressed function/object IDs separately in each dump, combines recursion
clones of the same native symbol, excludes inclusive `calls=` cost rows,
and checks every input digest, all 72 self-cost totals and window values.
It subtracts each worker's N=0 from N=10, then sums six rounds and divides
by 60 vectors. This **arithmetic-mean decomposition** is additive; it is not
the accepted result's median paired percentage. Both modes reconcile to the
original six per-round differences. Zero-delta functions in both comparisons
are omitted from the [complete changed-function export](fizzy-link-attribution.json).

Selected native **self-cost** differences, Ir per six-GET vector, rounded:

| Native function | Total on − off A | No-GC on − off A | Total off B − off A |
|---|---:|---:|---:|
| `vm_exec_core` | +632,361 | +632,815 | +618 |
| `vm_call_cfunc_with_frame_` | +356,469 | +356,627 | +218 |
| `invoke_block_from_c_bh` | +149,624 | +149,738 | +104 |
| `vm_callee_setup_block_arg` | +116,800 | +116,827 | +25 |
| `rb_data_typed_object_zalloc` | +109,061 | +109,084 | +23 |
| `mnew_internal` | +101,088 | +101,088 | 0 |
| `search_method_protect` | +98,252 | +98,256 | +4 |
| `method_eq` | +78,576 | +78,576 | 0 |
| `check_definition_visibility` | +49,680 | +49,680 | 0 |
| `match_at` | −40,742 | −39,317 | +951 |
| `str_buf_cat4.part.0` | −27,280 | −26,547 | +488 |
| `rb_str_buf_append` | −14,006 | −13,754 | +176 |
| **All native functions, including those not shown** | **+2,768,662** | **+2,705,026** | **−96,792** |

VM dispatch is the largest visible positive bucket. Reflection-specific
increases with almost no A/A change fit the source diagnosis below, but this
profile cannot causally assign all VM dispatch/allocation cost to the scan.
The separate total/no-GC executions are not a decomposition of GC savings.
The no-GC all-function A/A mean is −103,928 Ir/vector. Selected reflection
rows are not the whole A/A noise floor: for example, total `ar_update`
contributes −44,755 A/A Ir/vector. N10-minus-N0 function costs can be negative.

### Work per completed warm hit

| Component | Off versus on | Work and what remains live |
|---|---|---|
| Template/context | Common | Natural template seam reads source/compiler/locals/ISeq facts, audits six compiler methods, computes signatures/digests and disk SHA; frequency is template entry, not one per link. Never attribute all of this common work to the net on increase. |
| Link/site observation | Common per selected call | Original Proc ISeq/child association, descriptor merge, JSON/SHA key, entry eligibility snapshot, request-local call record and entries counter. |
| Capture/witness observations | Common | Saved builder, actual capture receiver, raw-buffer swap/restoration, completion seams. URL/options conversion, validation, builder selection, capture and the entire original block remain live once. |
| First-original admission | Outside warm windows | One bounded attempt, validation and publication after whole-link completion; not repeated on each warm hit. |
| Dependency scan | **On-only after capture** | **40** `instance_method` identity comparisons plus 40 visibility checks; native-holder bound Method and two escaping bound Method comparisons add three. Literal checking additionally inspects the `html_escape` native super-method chain: the informal “44-method scan” is **43 identity comparisons plus that chain observation**, not 44 instance-method entries. Six private methods make visibility use 46 public/protected queries. |
| Literal state | On-only | Frozen/exact TAG_TYPES and two Regexp checks, Hash defaults/class/href entries, two XML-name matches, native escape owner/location. This is one `literal_state?` per completed hit, not preescaped CSS. |
| Remaining guards | On-only | Ractor/epoch, saved owner holders and weak constructor token, actual saved builder/view relation, buffer receiver/restoration, converted Hash order/defaults/class, URL and content exact holders/UTF-8 validity. Saved receiver is revalidated **after** the live block. |
| Specialized suffix | On instead of stock suffix | Still escapes CSS and URL, tests quotes, conditionally escapes content, reads live PRE_CONTENT_STRINGS and allocates fresh safe output. It does **not** remove the block, capture, route generation or CSS escaping. |
| Stock work removed | Off-only | One `content_tag_string`, one `tag_options`, two `tag_option` calls; empty/options and per-key blank/type/value dispatch, two XML-name escapes, two generic per-attribute interpolations and output concatenations. Only outer tag/class/href shape is fixed. |
| Counters | Both, not identical | Entries and completion in both; off also constructs/increments its fallback-reason counter in `link_leave`. On's completed-hit counter is charged. This small off-only cost cannot explain an on slowdown. |

Thus the **hypothesis**, not a measured component price, is that the repeated
reflection/visibility/literal machinery dominates the small stock suffix it
replaces. The 24-hit vector does 960 instance-method comparisons, 960
visibility calls (960 public + 144 protected = 1104 method-defined queries), 72 further bound-Method
comparisons and 24 literal/native-chain checks, while removing only 96 stock
suffix calls. Native `mnew_internal`, `method_eq` and visibility increases
support that hypothesis; shared VM self costs cannot prove its percentage.
These are separately source-audited operation counts, not observations
recovered from native symbols; the dump analyzer does not own a second copy
of the dependency list or a per-operation cost model.

### Per-site ledger, not invented per-site prices

Paths below are under `app/views/`. `Scan` is instance-method identity
comparisons **and separately visibility checks**, per vector (40 each/hit).
`Removed` is stock suffix calls (four/hit). Each hit still pays the remaining
guards, literal check, three bound-Method comparisons and specialized suffix.
Both Ir columns are unavailable for every exercised site. Four cache-elided
sites have no on-only scan or removed suffix in these warm windows; their
zeros do not mean a zero-cost general specialization.

| Site | Hits/vector | Hits/N10 | Scan | Removed | Saved Ir | Added Ir |
|---|---:|---:|---:|---:|---|---|
| `buckets/index.html.erb:5` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `buckets/_bucket.html.erb:2` | 2 | 20 | 80 | 8 | unavailable | unavailable |
| `buckets/_bucket.html.erb:16` | 2 | 20 | 80 | 8 | unavailable | unavailable |
| `buckets/_bucket.html.erb:20` | 2 | 20 | 80 | 8 | unavailable | unavailable |
| `filters/_filter.html.erb:3` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `filters/_filter.html.erb:17` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `notifications/_tray.html.erb:6` | 3 | 30 | 120 | 12 | unavailable | unavailable |
| `bubbles/index.html.erb:9` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `filters/_buckets.html.erb:21` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `filters/_tags.html.erb:20` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `filters/_assignees.html.erb:22` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `filters/_creators.html.erb:23` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `filters/_stages.html.erb:21` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `filters/_settings.html.erb:20` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `bubbles/_bubble.html.erb:33` | 0 | 0 | 0 | 0 | 0 observed | 0 on-only |
| `bubbles/list/_bubble.html.erb:3` | 0 | 0 | 0 | 0 | 0 observed | 0 on-only |
| `bubbles/list/_bubble.html.erb:12` | 0 | 0 | 0 | 0 | 0 observed | 0 on-only |
| `accounts/users/index.html.erb:5` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `accounts/users/index.html.erb:18` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `workflows/index.html.erb:13` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `workflows/_workflow.html.erb:17` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `notifications/index.html.erb:14` | 1 | 10 | 40 | 4 | unavailable | unavailable |
| `comments/_body.html.erb:6` | 0 | 0 | 0 | 0 | 0 observed | 0 on-only |
| **Total / 19 exercised identities** | **24** | **240** | **960** | **96** | **unavailable** | **unavailable** |

### Is there a cheaper exact design?

- **Request-scoped scan:** at most six complete scans instead of 24 in this
  vector, but unsafe alone: URL conversion or the original block can change
  an effective dependency before the saved receiver's suffix runs. Keep the
  original suffix whenever a complete invalidation proof is unavailable.
  Per-hit object/encoding/options/buffer checks remain necessary even with
  a sound structural epoch. Common context/digest work does not disappear.
- **Cheap mutation epoch / bet D singleton freezing:** a plausible way to
  amortize structural checks, **not established by existing Guard hooks**.
  Visibility changes, saved ancestry primitives, suppressed object callbacks
  and refinements need detection or refusal. Freezing holder eigenclasses
  only prevents one way to replace callbacks; it does not close those holes.
  No permission follows to freeze app objects or change app semantics.
- **Drop low-value sites:** hit multiplicity is not net value. A one-hit site
  has the same scan but may have different stock content. These dumps cannot
  identify which site's saving exceeds its checks. Dropping the four warm
  zero sites changes no measured hits; dropping arbitrary exercised sites
  would not be evidence-driven and changes the preregistered mix.

Next is at most one **branch-only** improvement attempt and cheap screen,
not another price. First prove its invalidation/fallback boundary; a zero-hit
original-only comparison is not an improvement. New screen-first policy:
exact output, allocations and short native YJIT alternating wall samples;
one failed improvement means stop. No new Callgrind cohort without a clear
screen win and the coordinator's separate decision.

Reproduce the offline analysis (no Valgrind invocation):

```sh
mise exec ruby@4.0.7 -- ruby bench/experiments/block_link_attribution.rb \
  docs/fizzy-link-ir-n10.json "$EXISTING_N10_DUMP_DIR" "$NEW_JSON"
```

Validation: all 72 digest/self-total/window checks and both aggregate
on/off and A/A decompositions pass. A separate scratch asymmetric synthetic dump checks inclusive
cost exclusion, compressed cross-object IDs, recursion merging and refusal
of corrupt totals; that validation fixture was not added to the runtime or
kept test suite. A separate Prism read of the actual dependency array finds 40 entries;
no runtime witness, app or frozen harness is modified by this analysis.
