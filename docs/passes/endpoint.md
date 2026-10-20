# Endpoint/action: conservative generated slice

Opt-in only: `--passes default,+endpoint/action` (alias `endpoint`). Target:
`RealBlogR4::Application`, Rails **8.1.4**, `ArticlesController#index/show`.
Other applications/versions refuse at build time with a ledger reason. This
is the first reviewable slice of layer D, **not** the whole-route handwritten
ceiling, and it is not promoted to default.

## Next pilot design: show-first section continuations

**Design/cost gate only; not implemented or activated.** First target is
`GET /articles/1`, against default ≈ off, using the `c9d2397` heap-observer
warmup and symmetric post-GC request settling protocol. Index waits. Neither
quarantined pass, the parked composition nor the old handwritten ceiling is
a building block. The first candidate only expands the two show-page links;
forms, tags outside those links, AR, renderers and events remain live Rails.

The unit of certification is an **already-entered method body**, not an epoch
covering subsequent calls. Generate from the actual compiled handler in its
original compilation container (retain `Comment`'s CREF), not a copied `_run`
wrapper. Invoke the real handler and compare its source once at compilation;
a new resolver Template compiles afresh. Keep Rails' `_run`/normal method
dispatch, so later compiled-method redefinitions win normally. No per-request
file hashes or compiled-ISeq hashing. A section may use a cached build proof
of its own body; every *removed nested dispatch* still needs effective-method
identity/visibility on the actual receiver **after its arguments**. Suppressed
hooks make a K/epoch-only shortcut insufficient. Do not reuse authorization
across a live call, subscriber, conversion or block yield.

Post-entry evaluation inventory, in execution order (each listed live call
includes its complete dynamic subtree; no closure claim about that subtree):

| Point | Section / exact continuation |
|---|---|
| Controller events, before/around filters, `set_article`/`Article.find`, action, view assigns and render-event starts | All live, once. Permission before them cannot authorize any later removed dispatch. A subscriber can change both state and methods. |
| Show prologue: `content_for(:title)`, head capture block, `turbo_exempts_page_from_preview`, `@article.id`, notice/presence, title/body reads and output-buffer appends | Live, including coercion/escaping. Check the next expanded call only after these return; no template restart or replay of head capture. |
| Each link's name, URL/record argument and keyword/hash construction; nested `edit_article_path(@article)` and zero-argument `articles_path` | Evaluate original receiver/arguments once, left-to-right, into locals. On failed `link_to` certificate, invoke the live helper with those locals and the original arity/keyword shape. Index later adds `article.title`, record URLs and `new_article_path`; it cannot inherit show's authorization. |
| Inside `link_to`: option conversion/stringification, remote/method options, `url_target`/`url_for`, name/model predicates and href hash access | A live call ends the section. A failed next-callee certificate invokes that live callee with the saved arguments and resumes the caller's suffix. Never re-enter `link_to` after option conversion or URL work. Redefining an already-entered method does not replace its running body. |
| Inside a named/polymorphic route: defaults/URL options, predicate, argument `to_param`, captured route's `format`, escaping and script/URL finishing | First candidate leaves the whole route live. A later route expansion must continue at `captured_route.format(converted_parts)` after conversion, not call `*_path(original_arg)` again, nor refetch a different route object. Preserve Rails' own error-path conversions; add none. |
| Anchor construction: `content_tag`, name validation, `tag_builder`, actual builder's `content_tag_string`, `tag_options`/`tag_option`, escaping, coercions and SafeBuffer construction | Recheck each removed dispatch at its use on the actual builder/string/hash receiver, not the TagBuilder class alone. If name validation or builder acquisition runs live, recheck afterwards. Continue with the already computed content/options; do not regenerate the link or repeat a conversion. Unknown/custom coercions stay live. |
| Remaining show body: destroy `button_to`; Turbo stream signing; `@article.comments`, collection iteration, each comment's `dom_id`, attributes, `comment.article`, delete button and nested route; `Comment.new`; `form_with`, builder `label`/`text_field`/`text_area`/`submit` and capture block | All live, including callbacks, SQL, CSRF/session work and empty collections. These are mutation boundaries before any later expansion, not permission to batch checks over the form or collection. Index's article partial also keeps `dom_id`, count/pluralize, truncate, three links and destroy button under their own future boundaries. |
| Layout: title/head/body yields, CSRF/CSP tags, stylesheet/importmap helpers; render/controller finishes and response finalization | All live. Keep real controller/view objects, assignment order, payloads, event nesting, buffers and exception behavior. No layout/filter/envelope lowering in this step. |

**Invariant budget per section:** incremental cost is exact residuals +
branch/locals/continuation dispatch − removed interpreter/dispatch/allocation
work; all live callees cancel against off. Charge entry and template delivery
once, not as free work. A K check is about 425 interpreter Ir; the synthetic
four-fact 4,470-Ir check is not a real-view certificate. The measured actual
view receiver/visibility pair alone was about 10.8k Ir/call, so price the
actual show receivers before generating a pass. Measure an optimistic
check-only full-anchor certificate against the *entire* live anchor cost,
plus the one-certificate/thin-body alternative; omit no remaining checks from
any claimed complete cost. If even these optimistic budgets lose, stop this
caller-side design before implementing it. Body-installed specializations
that retain normal dispatch are a different, as-yet-unpriced design.

**Mutation gate before any request benchmark:** separate controlled off/on
processes, literal status/body/all-header equality and ordered SQL/event traces;
never replay an authoritative request. Keep all existing 144 specimen pairs.
Add once-only probes at name evaluation, each positional/keyword expression,
option conversion, model/URL predicates, `url_for`, `to_param`, name validation,
builder acquisition, builder formatting, attribute/value coercion and escaping.
Include singleton/prepend/own-visibility changes, suppressed/conditional hooks,
template/cache clears and compilation-container constant replacement. Existing
subscriber redefinition, callbacks-once and assigns-visible probes remain.
Failing a certificate must exercise the local live suffix, not restart a
helper, renderer, action or filter. Only a green semantic matrix permits an
opt-in show request comparison; both total/no-GC A/A, heaps and JIT-state
controls must pass and show must be ≤ off before considering index.

### Show section-cost gate: stop before runtime implementation

**Stop this caller-side reflection design.** Its optimistic check-only arm
already costs more than executing both original show links. This rejects the
measured implementation, not all possible body-installed specializations that
retain Ruby's normal dispatch; those remain unpriced. No new runtime pass,
continuation generator, mutation matrix or whole-request show comparison was
built/run. Index remains untouched, and neither source pass is reactivated.

`bench/experiments/endpoint_sections.rb` captures the two actual show-page
`link_to` calls using an **untimed** TracePoint, then measures operations on
that real view and its actual tag builder. All workers have Lowrail off;
no controller/template/helper method is replaced. The original arm executes
both links. The thin arm checks effective `link_to` identity and visibility,
then expands only its stock no-block body with every nested helper live.
The check-only arm unrolls ten effective-method/visibility pairs per link:

- View: `link_to`, `convert_options_to_data_attributes`, `url_target`,
  `url_for`, `content_tag`, `ensure_valid_html5_tag_name`, `tag_builder`.
- Actual builder: `content_tag_string`, `tag_options`, `tag_option`.

These use captured core `Module#instance_method`, visibility predicates and
`UnboundMethod#==`, not overridable reflection on the application receiver.
The cheaper combined variants use `Module#public_instance_method` to combine
identity and public visibility in one lookup; private methods still use the
separate predicate. This avoids charging an unnecessary lookup on public calls.
Holders and expected methods are captured **outside** the measured windows.
This is an optimistic subset, **not a complete certificate**: remote-option
helpers, String/Hash/escaping/value checks, repeated checks after live calls,
holder acquisition, entry/template delivery and continuation work are absent.
It does not authorize executing an accelerated arm.

The initial four-arm cohort and subsequent six-arm comparison including the
combined lookups each use six randomized fresh-process rounds, Ruby **4.0.7**,
Rails **8.1.4**, seed **41231**, interpreter Callgrind, five standard heap floors,
N=0/200 operation windows and the shared `c9d2397` `HeapWindows` protocol.
Operation windows retain the captured context; they do not execute a request
as a settling step. Both cohorts pass total/no-GC A/A, heap and actual
interpreter-state controls; no collections occur inside measured windows.
Source hashes match at finish. Both thin arms' stock results match bytes,
encoding and HTML-safety flag in every worker; this is not the unexecuted
mutation/response equivalence gate.

The table is the **six-arm** comparison. Its total/no-GC A/A deltas are
−0.009% [−0.099, +0.068] / −0.015% [−0.107, +0.069].

| Operation, for both links together | Total interpreter Ir, median [95% CI] | GC-excluded Ir, median [95% CI] |
|---|---:|---:|
| Entire original links | 90,042 [89,957, 90,213] | 90,048 [90,037, 90,138] |
| Separate-lookup checks alone | 112,135 [112,131, 112,140] | 112,135 [112,131, 112,140] |
| Combined-lookup checks alone | 93,649 [93,645, 93,654] | 93,649 [93,645, 93,654] |
| Combined checks minus entire original links | **+3,607 [+3,441, +3,688]** | **+3,601 [+3,507, +3,616]** |
| Thin expansion, separate lookup, minus original | **+14,450 [+14,257, +14,555]** | **+14,452 [+14,256, +14,549]** |
| Thin expansion, combined lookup, minus original | **+8,905 [+8,780, +9,006]** | **+8,905 [+8,780, +9,004]** |

These are **operation costs, not request percentages or native speed claims**.
Even replacing all the original anchor work with nothing cannot pay for this
set of checks, even with the cheaper lookup. The less ambitious thin expansion
also loses. All four measured candidate arms allocate 20 objects/two-link
operation versus the original's 14. The initial accepted cohort's separate
checks cost 112,471 versus 90,070 Ir for the original, a +22,401 deficit;
the portable export retains that cohort too, not just the improved variant.

`Kernel#method`/`public_method` are not safe drop-in shortcuts: when a target
is missing they can invoke application `respond_to_missing?`. An executed
Ruby probe observed one call from each getter, versus none from the captured
`Module#instance_method` and `Module#public_instance_method` missing-method
lookups. A guard must not introduce those effects before its live fallback.
This is a semantics constraint, not a claim to have exhausted alternative
lookup implementations.

Reproduce after preparing the corpus production database/assets, including
article 1 (the driver's initial request must return 200):

```sh
BENCH_JOBS=2 mise exec -- ruby bench/experiments/endpoint_sections.rb \
  .corpus/real-blog-r4 /tmp/NEW-endpoint-section-budget
```

Portable numeric evidence: [endpoint-sections.json](endpoint-sections.json).
Raw worker logs and counters stay private in
`/tmp/endpoint-show-section-budget-v{2,3}/`. An earlier invocation failed
before measurement on a relative worker path; it was fixed, not retried after
a failed A/A control. The historical slice and its gates below are unchanged.

## Body-installed alternative: design and measurement only

Deliver an ordinary `def` in its **original file and lexical container** through
the existing Compiler/Loader seam, before that file is first required. Do not
prepend a wrapper, alias the old implementation, use `define_method`, change
parameters, or reinstall an already exposed method. VM dispatch then owns the
outer method's receiver, visibility, alias/super resolution and redefinition;
an already-entered body continues while the next ordinary call sees a new def.
This does **not** authorize removing any dispatch inside that body.

First check the observable delivery contract in fresh off/original-ISeq/edited-
ISeq processes: owner, name/original_name, source location, parameters/arity,
super/alias/bound and unbound handles, backtraces and late/mid-call redefinition.
Compare repeated-handle equality within each process, not unrelated object IDs
across processes. Also expose top-level frame labels, line/C-call traces and
ISeq differences rather than silently treating them as equal. Every observed
difference is a refusal boundary; an unchanged-text reload is the control for
the separate question of preserving an **already existing** UnboundMethod.

Internal-fact inventory for a possible full-anchor expansion:

| Work | Facts if removed; cheapest exact strategy |
|---|---|
| Outer `link_to` dispatch | None inside an already-entered body. Keep block handling/argument shape and the unchanged fallback body. |
| Option conversion and remote/method handling | Effective `convert_options_to_data_attributes` and `link_to_remote_options?`; fresh Hash/stringification/deletion/iteration and key/value conversions in original order. Preserve live calls or check actual receivers at use; a boot hook epoch alone is insufficient. |
| `url_target` / `url_for` | Effective helpers and actual model predicates/conversions after their arguments. Leave named routes, polymorphic routing and `to_param` live in this first target: then no route-set/default-URL certificate is needed in `link_to`. Inlining them would add route/config/mount/current-request facts, captured formatter identity and post-conversion continuations. |
| `content_tag`, name validation, builder acquisition | Effective helpers at each use. Normal dispatch to a body-installed callee is free of an identity residual; copying that callee into its caller is not. A live call or block ends the region. |
| Builder formatting and attributes | Actual builder's `content_tag_string`, `tag_options`, `tag_option`; live `TAG_TYPES`/`PRE_CONTENT_STRINGS` contents, escaping/encoding/safety/coercion and primitive method facts for operations removed. Constant identity alone does not detect Hash mutation. |
| Locale/config/subscribers | No new certificate when these operations remain live; keep real render/controller events. Do not charge or claim a global epoch for state this body does not specialize. |

Price captured `Module#public_instance_method` for public facts and captured
`instance_method` plus visibility predicate for private facts. Acquire holders
and expected methods outside timing to give this design an optimistic budget.
For the full-anchor budget, dropping the outer `link_to` check still leaves
the remote-option helper and the other nine internal facts. Primitive/table/
value checks and repeated post-call checks are additional, not free.

One finite six-round `c9d2397` interpreter micro will compare the two actual
show links with Lowrail off, an unchanged original-file ISeq delivery control,
and a body-installed **guard-cost specimen**. That specimen inserts only the
optimistic internal checks and then runs the unchanged original body: it never
authorizes a shortcut, caches HTML, or replays a request. Subtract the original-
delivery arm to price guards; compare that guard cost with the *entire* off
operation as a deliberately generous budget for a future full-anchor body.
If guards alone lose, stop without constructing an accelerated implementation.
If they fit, this is only headroom, not a positive net-saving certificate:
actual residual work, local continuations and all mutation/observable gates
would still have to fit. No quarantine or default changes are permitted here.

### Body-delivery contract and finite cost result

**Decision: guarded endpoint: stopped; requires a sealed contract or a VM
epoch.** Installing the outer body avoids its caller-side identity check, but
the measured internal checks alone still exceed the entire original two-link
operation. Ruby-level fact-guard endpoint work ends here: no accelerated
runtime, generator or whole-request result follows. This is not an impossibility
proof for every body transformation, nor does it change the independent sealed
contract. Neither sealing nor an epoch alone covers every omitted fact below.

`bench/experiments/endpoint_bodies.rb` delivers an ordinary `def` through the
actual Compiler/Manifest/Loader before the original file's first require.
The Rails arm observes the real app compiler in a separate boot; it does not
substitute a guessed original-ISeq fingerprint. Untimed probes verify actual
delivery and the installed method body. No quarantined pass name or artifact
is used. The guard-cost arm executes its checks and then the **unchanged**
original body regardless of their result; a false check cannot authorize
anything. This is not a shortcut or a completed equivalence implementation.

Fresh off/unchanged-delivery/edited-delivery fixture processes establish:

| Observable | Executed result / refusal boundary |
|---|---|
| Owner, name/original name, source path and def line | Identical with original lexical container and line-preserving insertion. |
| Parameters, arity, public/private status | Identical, including positional/rest/keyword-rest/block arguments. |
| `super`, aliases, repeated bound/unbound lookup, bind/unbind equality | Same relational results within each process; no cross-process object-ID comparison. |
| Redefinition during a call | Active frame, alias and saved bound/unbound handles finish the old body; next ordinary send sees the new body, identically in all three arms. |
| Already exposed UnboundMethod versus reloaded method | Not equal after even an unchanged-source reload; saved handle still works. **Refuse late installation**, not merely late alias creation. Cold delivery does not preserve a pre-existing method entry. |
| Exception frame from the unchanged method body | Same file, line, method label and base label. Not a claim that expanding callees preserves their exception/caller frames. |
| Top-level frame | Off is `<top (required)>`; both delivered arms are `<compiled>`. **Refuse top-level label/backtrace introspection**; ordinary method-frame equality does not fix this. |
| TracePoint line/C-call stream, method ISeq | Delivery changes the trace; edited body adds its own line/C-call events and has a different ISeq. The unchanged method's ISeq matches off. **Refuse instruction/AST/trace-sensitive consumers** rather than normalize the difference. |

The fixture's require-caller stack itself is identical; the top-level label
above is captured inside the loaded file. These are finite positive/negative
probes, not a general detector proving an app never inspects a stack or ISeq.
Consequently transparent delivery for every Ruby observer is **not** established.

The one finite cost cohort has four arms (independent off A/B, original ISeq,
guard-cost ISeq), six randomized fresh-process rounds, seed **41231**, Ruby
**4.0.7**, Rails **8.1.4**, interpreter Callgrind, five standard heap floors,
N=0/200 operation windows and the shared **c9d2397** observer-warmup protocol.
Operation workers retain the real captured view/builder; they do not issue a
settling request that replaces that context. Both links' bytes, encoding and
HTML safety agree in every worker. All original/guard workers confirm one
actual file delivery; off confirms none. The original and off `link_to` method
ISeq hashes agree; the guard arm differs.

| Two actual show links; Ir/operation, paired nominal 95% CI | Total | GC-excluded |
|---|---:|---:|
| Off original links | 89,729 [89,700, 89,768] | 89,731 [89,673, 89,792] |
| Unchanged-ISeq delivery minus off | +2,537 [+2,506, +2,563] | +2,536 [+2,506, +2,563] |
| Internal guard-cost increment over unchanged delivery | 94,466 [94,430, 94,530] | 94,465 [94,429, 94,532] |
| Guard cost minus **all** off link work | **+4,720 [+4,695, +4,814]** | **+4,777 [+4,649, +4,805]** |

Actual complete arm costs are **89,729 off / 92,279 unchanged delivery /
186,757 checks + original body**. Allocations are **14 / 14 / 34** objects per
two links. The +2,537-Ir unchanged-delivery increment is retained and
**unattributed**, not called the cost of the loader or edited bytecode: the
method ISeq is identical and no loader runs during these operation windows.
It is subtracted before pricing guards, making the rejection generous.

Total and GC-excluded A/A pass: **+0.057% [−0.006, +0.144]** and
**+0.059% [−0.005, +0.141]**; actual five-pool capacities and all 24 workers'
interpreter-state gates pass. This is an accepted instruction-cost comparison,
**not a native YJIT speed or request-saving claim**. The cheapest measured
public identity/visibility lookup is captured `Module#public_instance_method`
with captured `UnboundMethod#==`; private facts add the captured private
predicate. This is not proof of a globally cheapest possible guard. Ten
internal facts still omit holder acquisition, primitive/value/mutable-table
facts and rechecks after live boundaries. Nor may this entry check list be
used as authorization across any of those boundaries. No remaining cost is
treated as free in an accelerated implementation, since none was built.

Reproduce (new directory, production blog with article 1/assets prepared):

```sh
BENCH_JOBS=2 mise exec -- ruby bench/experiments/endpoint_bodies.rb \
  .corpus/real-blog-r4 /tmp/NEW-endpoint-body-budget
# Optional third argument: contract-only (no instruction cohort).
```

Portable evidence: [endpoint-bodies.json](endpoint-bodies.json); private raw
windows/counters/contract logs: `/tmp/endpoint-body-budget-v1/`. Two early
contract/worker setup failures were diagnosed before this cohort (Ruby keyword
Hash syntax; guessed compiler fingerprint), not failed A/A controls retried.
Targeted checks: benchmark contract **10/70**, compiler **3/38**, loader
**7/548** runs/assertions, all zero failures/errors/skips. Quarantine/default
and endpoint runtime/generator files remain unchanged.

### Final fact classification: sealed contract, VM epoch, residuals

Analysis only, coordinated with the
[sealed owner](https://ampcode.com/threads/T-01a15abc-a586-71fa-a60f-965ab3fc387e)
and [VM-epoch owner](https://ampcode.com/threads/T-01a15ac4-d389-72f9-81f9-f1fcb7018e97).
Their reported boundaries below are **not completed endpoint certificates**.
`SEAL001` is a no-post-seal method/constant/visibility/ancestor-mutation
contract, including singleton/refinement/native equivalents; its TracePoint
detector is incomplete. Zero observations is not proof. `SEAL005` covers
runtime config/route/resolver mutation in concept, but its current watcher
does not cover arbitrary tables or ivars. The other relevant IDs are
`SEAL002` request-dependent URL defaults, `SEAL003` custom `to_param` needing
a purity certificate, `SEAL004` subscriber-set mutation, `SEAL006` unresolved
dynamic dispatch, and `SEAL007` undeclared template locals. The sealed
follow-up adds `SEAL008` for framework heap tables (API observation plus
per-test/end snapshots, not complete write detection), and `SEAL009` for
accepted delivery-introspection exclusions. None is a general
value/purity/receiver certificate.

The proposed Ruby 4.0.7 VM patch uses an atomic saturated global generation,
bumped at method-table/cache/entry changes, visibility, include/prepend,
singleton creation and constant set/clear/autoload, read by a direct C
`RubyVM.mutation_epoch`. It covers structural changes to a **previously
certified actual holder**, not future-receiver provenance or heap writes.
The [final six-round study](vm-epoch.md) accepts read/compare/compare+branch
costs of **195/249/267 interpreter Ir**, **36/49/52 YJIT Ir**, zero allocations.
All ten actual-holder replacement/own-visibility probes, 48 structural and
15 constant/autoload/Zeitwerk cases per mode, and both mid-call repros detect
changes. The warning-reentry repair bumps before `Warning.warn` on removal.
Only patched Ruby provides this API; 4.1-preview1/master do not. An ordinary
getter can lie: trusted/intrinsic read **and comparison** remain necessary.
Active lexical refinements need a separate certificate; no universal
refinement/Box/Ractor or complete VM-reentry certificate is proven.

In the table **M** means method identity/visibility on a certified holder:
sealed contract `SEAL001`, or a boot baseline plus an unchanged structural VM
epoch at **each** post-application-code boundary. Neither admits an entry-only
snapshot. Without either mechanism, the measured ten-fact Ruby check list is
94,466 Ir/two links, about **4,723 Ir/fact-use on average** (20 uses); that is
an accounting estimate, not ten independently measured or equal prices.
**R** means actual-receiver/provenance certification still required. Under a
satisfied seal there is no per-call **structural** guard; under the VM design
one shared epoch check may replace several structural lookups in an uninterrupted
section. Two interpreter checkpoints estimate **534 Ir** against 94,466
historical check Ir (about 177× cheaper), **not** a net endpoint saving or
proof that two checkpoints suffice. Holder/input/config/table residuals and
post-call local continuations remain mandatory.

| Fact | (a) Sealed contract / current gap | (b) Structural VM epoch | (c) Residual and interpreter Ir estimate |
|---|---|---|---|
| View `convert_options_to_data_attributes` (private) | `SEAL001`, baseline implementation required | M, on actual view holder | M + R; Ruby reflection average ≈4,723/use if not covered. Hash/conversion effects below remain. |
| View `link_to_remote_options?` (private) | `SEAL001` | M | M + R; ≈4,723/use average, not certification of its Hash input. |
| View `url_target` (private) | `SEAL001` | M | M + R; ≈4,723/use average; model predicates/coercions stay live. |
| View `url_for` (public) | `SEAL001`; URL-default behavior is also `SEAL002`, not proven by method sealing | M, not request/default values | M + R; ≈4,723/use average; retain live routing/config reads unless separately certified. |
| View `content_tag` (public) | `SEAL001` | M | M + R; ≈4,723/use average; block capture remains an effect boundary. |
| View `ensure_valid_html5_tag_name` (private) | `SEAL001` | M | M + R; ≈4,723/use average; actual name/Regexp semantics still need proof or live call. |
| View `tag_builder` (private) | `SEAL001` protects method, **not `@tag_builder`** | M, not ivar contents | M + R; ≈4,723/use average; retain actual returned builder, never substitute a remembered one. |
| Builder `content_tag_string` (public) | `SEAL001` on certified actual builder | M, not that this is the certified builder | M + R; ≈4,723/use average; table/value facts below remain. |
| Builder `tag_options` (public) | `SEAL001` on certified actual builder | M | M + R; ≈4,723/use average; input iteration and conversions remain live. |
| Builder `tag_option` (private) | `SEAL001` on certified actual builder | M | M + R; ≈4,723/use average; escaping/array/hash/value dispatch remains live. |
| View/builder holder, singleton class and ancestor chain | `SEAL001` forbids structural changes; **future receiver / ivar replacement GAP**, no rule certifies it | Structural change yes; replacement `@tag_builder`/future receiver no | R at every acquisition after live code. One cached-class K comparison costs ≈425 Ir as a **proxy only**; effective singleton-holder acquisition/complete provenance is unpriced. |
| Core/helper primitives: Hash `stringify_keys`, `delete`, `[]`, `[]=`, `each_pair`; String/Regexp/safety/encoding and ERB escaping methods | `SEAL001` only on certified method/instance targets; no primitive semantic/purity certificate | Method mutation yes, assuming actual holder/lexical baseline; per-value state no | Keep live dispatch (0 **extra specialization-check** Ir, original work retained), or add M + R for each removed call; ≈4.7k/fact-use is only a reflection proxy, not a primitive measurement. |
| Constant bindings, including tag tables and helper/model modules | `SEAL001`; direct constant/uncached-autoload detector gaps remain | Final 15-case set/clear/autoload/Zeitwerk matrix detects changes; no heap-write coverage | Boot identities still required. Simple direct constant-identity check ≈311 Ir/binding from speculation micro if retained; no claim it detects in-place mutation. |
| Stock Rails 8.1.4 `TAG_TYPES` contents | Source constructs and **freezes** the Hash; certify that actual object/immutable keys and Symbol values at boot, plus `SEAL001` for binding/Hash methods | Binding/method changes only, sufficient for that frozen-content fact once proven | No repeated content snapshot for the certified stock frozen object. A replacement mutable Hash is a new heap-fact gap, not permission from a matching epoch. |
| `PRE_CONTENT_STRINGS` contents and default Proc; replacement mutable tag/config tables | `SEAL008` now watches the two named tag tables and snapshots String bytes/encoding/defaults per test/end; undone-between-checkpoints and other-table GAP remains | **No**, in-place Hash/default/value writes do not bump structural epoch | Read live at original point and preserve default Proc invocation/once-only effects (0 extra check, original work retained), or exact independent contents/default/value certificate. Full cost unpriced; ≈2,081 Ir for a simple two-key config snapshot is only a prior micro proxy, not this table's certificate. |
| Input class/shape/key order/value, HTML safety, encoding and frozen state | **GAP**; no SEAL rule asserts these request facts | **No**, heap/value facts | Per-use value certificate or live operation. ≈425 Ir for one class K comparison is a lower-scope proxy only; complete check unpriced and cannot be replaced by `Class === value` alone. |
| `to_param`, model predicates, blocks and arbitrary coercion callbacks | `SEAL003` is only a custom-`to_param` purity requirement/hint; `SEAL006` flags unresolved sends, neither proves general purity | Detects structural mutation caused by callback, not callback effects/heap writes | Keep live once; checkpoint after callback and continue with computed arguments. 0 extra guard for a call left live; measured epoch compare+branch 267 interpreter Ir excludes local-continuation/residual cost. Never replay action/helper/conversion. |
| Request-dependent config/default URLs, route/resolver state | `SEAL002`/`SEAL005`; legitimate request-dependent values are not fixed by sealing | Definition/binding changes only, not nested config state | Remain live in this link-only design; 0 extra specialization check, unchanged original cost. Any removal needs a separate value plan/snapshot, unpriced. |
| Subscribers, template locals, lexical refinements | `SEAL004`/`SEAL007` address first two only; `SEAL001` refinement contract is not a proven detector | Not subscriber/locals/heap state; active refinements require lexical baseline | Keep events/real locals/call boundaries; refuse unsupported lexical scope rather than price an invented universal check. |
| `<compiled>` frame, trace events, edited ISeq identity and reload-handle inequality | `SEAL009`: explicit production exclusion or refusal; cold-only delivery before handles escape | **No**, mutation generation cannot restore these observations | Refusal without accepted exclusion, not a per-request guard or an Ir saving. Late reload remains refused. No zero-cost equivalence claim. |

The 425/311/2,081-Ir proxies are the published interpreter micros in
[speculation.md](speculation.md#fixed-heap-guard-micro-costs); they are deliberately
not added into a fabricated endpoint budget. Unknown residuals remain
**unpriced**, and any future sealed/VM pilot still needs its own complete
mutation/value/observable matrix and ≤ off measurement. Ownership of this
document passes to the sealed thread after this result is published; this
thread will not continue guarded endpoint implementation.

## What is generated, and what stays live

The runtime builder runs in an off, booted application. It obtains Rails'
compiled template Ruby, including the partial-locals prologue, for the two
pages, article/comment collection partials and application layout. It emits
one method scope per template, and a controller `process` wrapper, into the
endpoint manifest payload. The compiler produces a fingerprinted ISeq factory.
There is no handwritten application HTML in the runtime gem.

The generated template body executes on the **real view context**, with the
same output buffer, virtual path, current template and block. Only the audited
stock, non-block, two/three-argument `link_to` body is expanded. Arguments run
once, in order, before its effective-method check. All its nested calls
(`convert_options_to_data_attributes`, `url_target`, `content_tag`) stay live.
Unsupported/custom helper implementations stay live, rather than refusing
the endpoint. Strict/unknown locals and lexical-scope-dependent template bodies
remain with Rails. In particular, the show template's unqualified `Comment`
must retain Rails' compiled-method constant scope: moving it to a generated
module would ignore a constant installed on the original compilation container
by a subscriber. Constant/class-variable reads, nested definitions, source
pseudo-variables and scope introspection therefore refuse per template. The
other four bodies are eligible; show still hits through its layout/partials.
Collection and single-partial locals are distinct shapes; this slice only
inlines the certified collection shape.

**Everything outside those bodies stays Rails:** Rack, routing, session,
cookies, flash, CSRF, logging, exception handling, callbacks, action methods,
assignments, AR queries/objects, `Comment.new`, resolver, collection/layout
renderers, assets, forms, tags and translations. Instrumentation is not
re-created: the original Rails instrument calls execute in their original
nesting and order with their original payloads and live controller/view state.
There is no subscriber-absence certificate.

For eligible templates the delivery seam invokes the actual handler once
and checks its exact generated code before accepting the original body. This
supersedes overlapping default template splices so that a second lowerer
cannot silently change the body being certified. The stacked benchmark must
account for this lost default-pass opportunity, not just the new helper sites.

## Entry and local continuation

The process wrapper grants permission once before callbacks/action execution:

| Entry fact | Current exact check |
|---|---|
| Request | GET, resolved HTML, no variant, exactly controller/action keys (+ id for show) |
| Controller | captured core class lookup; named constant resolves to that exact class |
| Callback chain | same chain object as activation; callbacks themselves remain live |
| Helper | effective view-class `link_to` definition identity |
| Locale | same locale as build; I18n operations/backend reads remain live |
| Sources | runtime/process/helper fingerprints at activation; eligible template SHA-256s at entry |
| Permission cache | existing K slot, with counting mode using normal validation |

No Accept/User-Agent/cookie absence is required. In particular the app's
integration-test Accept header and absent UA/cookie enter the generated path.
Extra params and explicit format keys conservatively use the original path.

This is **not** a claimed cheap unified epoch. Four file hashes and residual
lookups still execute per request. RubyVM constant-cache invalidation statistics
are not used. The 4,470-Ir synthetic residual micro is not this guard's cost.

At each template/partial boundary, compare the effective compiled method's
ISeq against the boot body, its locals, public visibility and the underlying
`_run` definition. Only parser-location metadata and process-local template
labels are excluded from that fingerprint. Subsequent uses still compare the
effective UnboundMethod, including hidden singleton/prepend replacements.
The resolver is never cached or bypassed: `clear_cache`/`DetailsKey.clear`
therefore cannot select a stale generated template. A changed/unrecognized
compiled body uses Rails' original `_run` before that body starts.

Before **each expanded helper**, after argument evaluation, recheck the
effective receiver method and visibility using captured core reflection.
Suppressed `method_added`/singleton hooks, conditional-super hooks and own
visibility changes cannot authorize a stale expansion. If it differs, call
the **live helper with the original arity/keyword shape** at that point.
Already-running template code continues, just as Rails' already-running method
would. Nothing restarts process, callbacks, action, SQL or previous output.
No filter/action deopt boundary is removed in this slice: those sections run
unchanged and every later inlined use checks its own facts.

Permission/accounting lives in a weak-key map, not controller ivars that would
leak into `view_assigns`. A hit means a certified generated template body was
entered, counted at most once per endpoint request. A helper deopt is counted
at most once per request too; such a request can have both a hit and fallback.
Entry rejection is one fallback. An admitted request raising before rendering
is neither a generated-body hit nor a helper deopt. Counts are not helper-call
counts or a claim that all rendering machinery was removed.

## Strict shadow means isolation, never replay

`LOWRAIL_SHADOW=strict` does **not** execute an authoritative endpoint twice.
The endpoint gate consists of the existing two-process `lowrail verify` plus
`bench/experiments/blog_endpoint_check.rb`'s two fresh worker processes.

The latter uses the same database snapshot, rolls fixture changes back, seeds
SecureRandom/OpenSSL entropy identically, fixes clock readings during each
request, fixes request ID and uses the same disposable session/CSRF secret.
It compares status, body and **all headers literally**: no stripping ETag,
Set-Cookie or X-Runtime. Ordered SQL includes binds and cache markers. The
event trace retains names, nesting, payload keys/scalars and assign-presence
observations; non-scalar framework objects have stable class/request/response
summaries, not cross-process object identities. It is not a certificate for
arbitrary object/ISeq/stack introspection.

The 144 cases are four routes (index and three asymmetric comment counts),
six Accept/UA/query shapes, absent/existing session and stock/escaped/empty
data. Empty data includes real 404 responses. An authoritative request always
runs once. The harness never loads into a deployed application.

## First-slice gates

- real-blog app suite: **21 identical outcomes, 125 ordered queries**;
  **index 1 hit / 0 fallbacks; show 1 / 0** from its own controller tests.
- Baseline **144 isolated pairs** identical. Including warmups, endpoint
  request H/F is **31/14 index, 60/42 show**. Negative format/query shapes
  deliberately fall back.
- Nine mutation cohorts, **144 pairs each**, identical: changed template plus
  both cache clears; helper redefine; added before_action; new render subscriber;
  locale switch; process-action-start helper mutation; fully suppressed hook;
  conditional-super hook; own-private visibility. A new subscriber keeps the
  baseline hits. Template/helper/filter/locale changes yield zero generated
  hits; the mid-request mutation first hits then continues with live helpers.
- Permanent regression: **90 assertions**, including ten mutated link markers,
  narrowed two-argument fallback, hidden singleton replacement, private helper,
  changed template, callbacks exactly once, assigns visible to subscribers and
  a compilation-container constant changed mid-request.
- Gem suite: **92 tests / 1,654 assertions**, zero failures/errors, six optional
  skips. Rust: **31 unit + three integration** tests pass. Benchmark driver:
  **13 tests / 110 assertions** pass after integrating main's new budget seam.
- Other corpus apps, pass selected but **no endpoint units**:

| App / actual Rails | Identical outcomes | Ordered queries | Endpoint refusal |
|---|---:|---:|---|
| PingCRM / 8.1.4 | 26 | 809 | application |
| Redprints / 8.1.3 | 50 + 12 system | 692 + 260 | rails_version |
| Starter Kit / 8.1.4 | 36 | 264 | application |
| Campfire / 8.2 alpha, supplementary | 634 (2 matching skips) | 15,108 | rails_version |

PingCRM retains **nine advisory other-thread SQL differences** (the same names
as the speculation study); do not mistake these for an ordered SQL gate.
Campfire's separate 30 browser tests were not rerun for this refusal gate.

Rails 8.1.4, unchanged source pin, L1/L2/L3: Action Pack **4,095** and Action
View **2,747 + 242 + 173** identical in every layer, no shadow mismatches and
all exits zero. AV/AR L3 has 123 existing-pass hits / 2 fallbacks; this is
compatibility evidence, **not endpoint coverage in the framework suite**.
Private evidence: `.lowrail/endpoint-framework-publish/`, `/tmp/endpoint-publish-*`,
`/tmp/endpoint-*-verify.log`. Raw responses/cookies are deliberately untracked.

## Reproduction and next measurements

```sh
RAILS_ENV=test mise exec -- target/debug/lowrail build .corpus/real-blog-r4 \
  --env test --passes default,+endpoint/action
RAILS_ENV=test PARALLEL_WORKERS=1 LOWRAIL_SEED=41231 LOWRAIL_SQL_TRACE=full \
  mise exec -- target/debug/lowrail verify .corpus/real-blog-r4 -- \
  bin/rails test --seed 41231
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 mise exec -- target/debug/lowrail \
  build .corpus/real-blog-r4 --env production --passes default,+endpoint/action
mise exec -- ruby bench/experiments/blog_endpoint_check.rb \
  .corpus/real-blog-r4 /tmp/NEW-endpoint-pairs
# Optional third argument: template/helper/filter/render_subscriber/locale/
# subscriber/suppressed/invokesuper/private. Always use a NEW output directory.
```

Fixed-heap benchmark of this exact slice against a separately built default
reference follows publication. No saving is claimed yet. The old eventful
−26/−37% specimen is an **upper bound with missing observable assigns**, not
a supported semantic target. Widen in separate measured, paired-gated steps:
helpers, partial/collection dispatch, layout, then filter dispatch. Each needs
its own new facts/local continuation; none is implied by this slice.

## Exact-slice measurement and rejected composition

The published conservative slice's index benchmark passed the fixed-heap and
A/A gates, but **regressed** against a separate default build: 8.574259 →
10.170184 M Ir/request, paired **+1,593,364 Ir, +18.565% [18.534, 18.646]**.
Allocations were 2,235.14 → 2,689.86. This is not the handwritten ceiling.

An inclusive-caller diagnostic explains the budget below. Inclusive deltas
are not independent causal ablations; notably `Endpoint.current` overlaps
its callers. No double counting is intended.

| Cost | Net Ir/request | Interpretation |
|---|---:|---|
| Entry | 415,186 | Includes 370,696 for four request-time SHA computations |
| Template checks | 165,064 | 14 calls |
| Helper checks | 106,806 | 10 calls |
| Lost default view/route source splices | 549,861 | Raw handler bodies superseded the default lowerings |
| Remainder | 356,447 | Includes 139,331 from 24 `Endpoint.current` lookups; not another additive row |

Unpublished composition work removes request-time file hashing, pins selected
runtime Template identities, passes the execution as a local, and starts from
post-source-pass bodies. Its descriptive index result was 9.052005 versus
8.574968 M Ir (**+5.56%**), with ten route completions and one endpoint hit.
**Rejected:** off/off A/A excludes zero ([+0.004, +0.069]%), and the warmed
suppressed-hook specimen renders stale output. It is neither a published
performance result nor a semantically certified implementation.

Pricing only effective `link_to` receiver identity plus public visibility
costs about **10,830–10,836 Ir/hit**, leaving diagnostic per-hit savings
34,075 and 26,062 on two view units (nine and one invocations per request).
Those two units pass their controls, but the experiment as a whole fails
route-unit A/A. More importantly this is **not the complete source-arm
certificate**. Neither these numbers nor the composition result licenses
shipping a residual or reactivating a pass.

## Source-arm quarantine

The owner chose quarantine before a continuation/body-certificate rewrite.
Both `view/link_to` and `route/path` are unavailable in default, explicit
`+name`/aliases and `all-opt-in`. Every new build records a pass-level
`quarantined` refusal. Runtime rejects an old artifact containing either
pass **as a whole**, including otherwise safe units and template entries,
before installing delivery hooks. The reason is retained as
`Lowrail.refusal_reason` and emitted in a boot warning. Direct guard validation
and binary lookup also refuse it; installing such a guard withdraws G/V/K
authorizations. No repaired accelerated-arm support is claimed.

Three independently executed Rails 8.1.4 fixtures establish the boundary:

| Mutation | Original Rails | Previous default source arm |
|---|---|---|
| Warm guard; process-action subscriber suppresses `method_added`, redefines `link_to` | Ten live-helper markers | Zero markers |
| `link_to` name expression changes actual `tag_builder.content_tag_string` | `<!-- changed builder -->` | Old anchor |
| Route argument's `to_param` installs singleton `route.format` returning `/changed` | `/changed`, one conversion | `/widgets/7`, one conversion |

The last two mutations occur **after** entry authorization. Even checking the
actual receiver and its visibility at entry is insufficient; the route's
class method fact also cannot describe a singleton override on the captured
route object. A whole-helper fallback after conversion would repeat effects.
The permanent regressions keep the observable outputs and once-only name /
conversion assertions; quarantine makes them green by refusal, not by
silently removing mutation coverage.

The rewrite is a separate opt-in pilot. It must certify actual method bodies
and receiver provenance, preserve argument evaluation once and in order, and
continue locally after every application-code boundary (name, arguments,
`to_param`, builder). Each such point needs a mutation probe, paired isolated
response/header/SQL/event gates, and fixed-heap cost ≤ the new default.
The pending endpoint composition is not published or reactivated on unsafe
source arms. The old eventful −26/−37% handwritten results remain upper bounds
missing observable assigns and mutation behavior.

### Quarantine cost and gates

This deliberately **loses** the previous source-pass instruction saving.
Six fresh fixed-heap interpreter Callgrind rounds per route, 50 requests per
worker, no YJIT, use the shared `bench/request_pairs.rb` protocol. The
`before` layer uses archived pre-quarantine runtime sources from
[fecd033](https://github.com/thomasklemm/lowrail/commit/fecd033) and its
production default artifact. The current `default` layer refuses that same
artifact at boot; it is an original-Rails path, **not successful activation**.
The independent `empty` layer agrees within noise. No production bypass was
added, and the blog was restored to a fresh test/default build afterwards.
The harness is also pinned to that pre-quarantine revision: these cohorts
precede the later heap-observer warmup/post-GC settling refinement in
[c9d2397](https://github.com/thomasklemm/lowrail/commit/c9d2397). They are not
a measurement under that newer protocol.

| GET | Off M Ir/request | Former unsafe default M Ir (Δ vs off, 95% CI) | Quarantined M Ir (Δ vs off, 95% CI) | Loss vs former default, paired 95% CI |
|---|---:|---:|---:|---:|
| `/articles` | 9.122639 | 8.575382 (−5.995% [−6.012, −5.966]) | 9.120766 (−0.006% [−0.037, +0.013]) | +6.367% [+6.333, +6.386] |
| `/articles/1` | 8.771261 | 8.684129 (−0.987% [−1.040, −0.977]) | 8.769938 (−0.004% [−0.033, +0.046]) | +0.998% [+0.960, +1.086] |

Both total/GC-excluded A/A controls include zero and pass the fixed 0.5%
tolerance. Total-Ir A/A is +0.003% [−0.012, +0.014] index and +0.001%
[−0.028, +0.039] show; heap capacities match and all warmup/window JIT checks
pass. These are instruction losses, **not native YJIT throughput claims**.
Private evidence: `/tmp/lowrail-quarantine-{index,show}-cost/{samples,summary}.json`.

Runtime/build gates after quarantine:

- Gem: **97 runs / 1,733 assertions**, zero failures/errors, six optional
  dependency skips. Includes the previously red warmed-subscriber test and
  the name-expression/builder and conversion/formatter regressions.
- `cargo test`: **34 unit + 3 integration tests** pass. Benchmark contract:
  **16 runs / 157 assertions**, zero failures/errors/skips. Explicit build
  and bench selectors reject both names and aliases; old/mixed artifacts
  reject rather than silently producing inactive performance results.
  After integrating the newer harness, all benchmark tests pass:
  **30 runs / 262 assertions**, zero failures/errors/skips.
- AP L3: **4,095** identical. AV L3: **2,747 + 242 + 173** identical;
  zero differences/shadow mismatches. AV/AR retains **123 hits / 2 fallbacks**
  from other runtime passes, not source-arm coverage.
- Five-app default verify has identical outcomes and own-thread SQL digests:
  blog **21**; Campfire **634** (two matching skips); PingCRM **26**;
  Redprints **50** plus **12** browser-system examples; Starter **36**.
  Every app's unit-hit and unit-fallback maps are **`{}`**, with **zero
  emitted route units and no executable source completion arms**. This is
  quarantine compatibility evidence, not accelerated coverage. Other-thread
  SQL differences remain advisory: one Campfire and nine PingCRM cases.

Campfire's query totals are 15,109 off / 15,108 on because the concurrent
repair test records 41 / 40 including other threads; its own-thread digest
is identical. PingCRM totals are 812 / 812. No advisory was suppressed and
neither these totals nor green outcomes certify the disabled source arms.
Earlier browser runs without Chrome had matching failures; those were not
counted as passing. The completed Redprints browser gate uses `BROWSER_PATH`
pointing to the installed Chrome. PingCRM uses the existing private PostgreSQL
socket. Final evidence is in `/tmp/lowrail-quarantine-corpus-final/` and
`/tmp/lowrail-quarantine-framework-final/`; request secrets stay private.
