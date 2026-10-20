# Compiled ERB: survey and refusal

2026-10-20. Candidate 2 in [candidates.md](../candidates.md). **No ERB pass
is installed or registered.** Literal-run fusion was rejected before corpus
verification or benchmarking: two eligible templates do not justify another
guard, delivery path and fallback. The scratch builder/runtime were removed.

## Existing implementations first

Rails already compiles each ERB template into a normal Ruby method. Its
Action View Erubi adapter groups static text into `safe_append=` calls,
freezes template literals when necessary, and returns the existing output
buffer. Dynamic `<%=` expressions still run helpers and append through
Rails' escaping rules. Compiling the same ERB again is not specialization.

Herb/ReActionView are not an exact guarded substitute for those helper calls:

- Rails' [Herb adapter](https://github.com/rails/rails/blob/main/actionview/lib/action_view/template/handlers/erb/herb.rb)
  uses Action View's buffer contract; HTML-aware parsing is not partial evaluation.
- Herb's experimental [OptimizeVisitor](https://github.com/marcoroth/herb/tree/main/lib/herb/engine)
  offers literal/static-branch folding, and its opt-in helper rewriting can
  turn a closed list of helpers into HTML nodes. This is not guarded on
  booted helper bodies with the original call as fallback. Custom Action View
  pre/postambles also exclude the standalone buffer-elimination path.
- [ReActionView](https://github.com/marcoroth/reactionview) adds validation,
  instrumentation and reactive slots; those are not a boot-fact certificate.
- Roundhouse's [ERB compiler](https://github.com/rubys/roundhouse/blob/main/src/erb.rs)
  and [view lowering](https://github.com/rubys/roundhouse/tree/main/src/lower/view_to_library)
  merge literal fragments and specialize helper calls, but replace the view
  buffer/runtime. Borrow the refusal discipline, not its replacement ABI.
  Lowrail must retain capture, streaming, `content_for`, instrumentation,
  escaping, helper side effects and once-only argument evaluation.

This investigation read the installed Rails 8.1.4 Erubi and buffer methods,
the pinned Campfire Rails alpha, and those external implementations. It did
not enable Herb or change any app's engine, frozen-string or caching policy.

## Five-app literal-run survey

`script/corpus` pins, Ruby 4.0.7, test environment, actual booted handler
output. The report-only builder inspected statements in a synthetic method
(top-level Prism parsing incorrectly rejects legal template `yield`). It
considered only adjacent `@output_buffer.safe_append=` calls with literal
String arguments, optionally `.freeze`, whose expression values are discarded
by a following statement. No expression or helper was evaluated.

Counts are **template units**, not individual append calls. Each eligible
template has one run of three appends: two calls could disappear. Non-ERB
templates are explicitly refused rather than interpreted as ERB.

| App | Templates inspected | Eligible units | `no_literal_run` | `compiler_recipe_changed` |
|---|---:|---:|---:|---:|
| real-blog-r4 | 15 | 1 | 10 | 4 |
| Campfire | 90 | 0 | 81 | 9 |
| PingCRM | 3 | 0 | 3 | 0 |
| Redprints CFP | 10 | 0 | 10 | 0 |
| React Starter Kit | 7 | 1 | 5 | 1 |

The two targets are `app/views/layouts/application.html.erb` in blog and
starter. ERB comments between static PWA/icon markup split the generated
appends. `no_literal_run` means there is no eligible adjacent run, **not**
that a template is entirely dynamic. `compiler_recipe_changed` here means
a different handler (Jbuilder or another non-ERB format), not a changed app.

Decision: **`insufficient_opportunity` for both eligible units**. Streaming
observes chunk boundaries; custom buffers observe append calls; dynamic
helpers or `yield` can change state before the run. A correct extra guard
and original fallback have real cost. There is no measured per-hit saving,
no credited route saving, and no reason to promote this transformation.
The earlier 37.40 µs / 194-object synthetic form-envelope estimate is not a
measurement of this literal-run case or the real `_form`.

## Framework before gate

Executed `mise exec -- script/rails-suite --out .lowrail/erb-rails-before
--prepare`, then the same runner with `--suites actionview`. All three
upstream groups ran off/off-repeat and L1/L2/L3, serial seed 41231, pinned
Rails v8.1.4. Every subprocess exited zero; the comparison found no
reproducible outcome differences. Evidence is in that private output
directory's `summary.json`, lockfile, environment and per-process outcomes.
This is a before gate, **not coverage for a new ERB pass**.

| Action View group | Identical outcomes, each layer | L2 synthetic fallbacks | L3 existing-pass hits |
|---|---:|---:|---:|
| `actionview` | 2,747 | 17 | 0 |
| `actionview-actionpack` | 242 | 17 | 0 |
| `actionview-activerecord` | 173 | 17 | 118 |

L2's 17 fallbacks per group are deliberately nonmatching synthetic facts
checked by the suite runner, not attempted ERB specializations. L1 installs
setup only; L3 exercises existing passes. Zero new-pass hits are expected.

## Off-only compiled-template profile

Production, Lowrail **absent**, Ruby 4.0.7 +YJIT, StackProf 0.2.28 wall/raw,
100 µs interval, 400 warmups, then 3,000 blog edit / 1,000 Campfire room
requests. Every response was 200 with its complete body consumed and intended
form/messages present. Campfire used `CAMPFIRE_RESPONSE_CACHE_MB=0`; collection
and fragment caches were warm. This is **response-cache-disabled**, not a
cold-fragment-cache experiment. `RUBY_DEBUG_ENABLE=0` for the separate census
and route-coverage probes. No pass timing or on/off speed comparison here.

| Denominator | Blog edit | Campfire room |
|---|---:|---:|
| Rails | 8.1.4 | 8.2 alpha, corpus pin |
| Body bytes | 3,737 | 131,792 |
| Native unprofiled wall µs/request | 1,315.04 | 13,268.92 |
| Native objects/request | 1,716.34 | 22,675.65 |
| Raw-stack sample weight | 72,228 | 321,089 |
| Any compiled-template subtree, % request | 48.29 | 70.23 |
| Compiled-template frame itself is the leaf, % request | 0.77 | 0.48 |

The following is a **disjoint allocation of leaf self samples beneath the
innermost compiled template**, not a sum of overlapping inclusive helper
frames. Assign each stack once, with precedence escaping → buffer operations
→ URL generation → translations → tag options → first named helper in the
remaining tail → other. Thus `form_with` below excludes I18n, URL, escaping
and tag-option work, and a named helper's bucket includes its uncategorized
descendants. It is not that helper's intrinsic self time. The template frame
itself is included in “other”, not added again. Percentages use all request
raw-stack weights, including time outside compiled templates.

| Exclusive bucket, % request | Blog edit | Campfire room |
|---|---:|---:|
| Buffer appends/coercion | 1.28 | 0.79 |
| Escaping | 2.44 | 1.71 |
| URL helpers | 2.62 | 5.72 |
| I18n / label translator | 9.09 | 0.36 |
| Tag options | 4.46 | 2.90 |
| `form_with` remaining work | 10.15 | — |
| `label` remaining work | 2.46 | — |
| `submit` remaining work | 1.46 | — |
| `text_field` / `textarea` remaining work | 1.44 / 1.10 | — |
| `render` remaining work | — | 24.81 |
| `message_fragment_cache_key` remaining work | — | 14.08 |
| `stylesheet_link_tag` remaining work | 2.86 | 2.26 |
| `csrf_meta_tags` remaining work | 2.57 | — |
| `body_classes` remaining work | — | 2.09 |
| `rich_textarea` remaining work | — | 2.05 |
| `image_tag` remaining work | — | 1.66 |

Smaller named helpers and other work are omitted from this table, not from
the denominator. These are **cost shares, not removable budgets or measured
savings**. Campfire's collection-render bucket includes live cache/model work,
not just template dispatch. The message-key finding belongs to app code;
see [upstream.md](../upstream.md). No app change or upstream publication was made.

## Blog I18n census and exact-epoch refusal

Separate untimed TracePoint census: 20 warmups, 10 edit requests, Lowrail off.
All ten had the same sequence. Backend is mutable `I18n::Backend::Simple`
with Rails' `I18n::Backend::Fallbacks`, i18n 1.15.2, locale `en`, locale
fallback list `[:en]`. There are **no explicit app `t()` calls on this route**.
The two `form.label` calls and default `form.submit` produce all translations.
`text_field` and `textarea` do not add translation lookups on this successful,
persisted-Article edit. Error-rendering/new-record states were not profiled.

`MISSING` below is Active Model's `-(2**60)` sentinel; Rails humanizes the
attribute or model name when it receives that sentinel. Symbols in defaults
are lookup keys; Strings and the sentinel are literal defaults.

| Origin in `articles/_form.html.erb` | Initial key / scope | Full default chain | Actual result; Simple lookups/request |
|---|---|---|---|
| `form.label :title`, line 15, Tags::Translator | `article.title`, scope `helpers.label` | `[:"article.title", ""]` in the same scope; blank then calls `human_attribute_name` | Both attempts miss the **same** normalized key; 2 |
| `human_attribute_name(:title)` from that label | `activerecord.attributes.article.title`, `count: 1` | `[:"attributes.title", MISSING]` | Both keys miss; sentinel → `"Title"`; 2 |
| `form.label :body`, line 20, Tags::Translator | `article.body`, scope `helpers.label` | `[:"article.body", ""]` in the same scope; blank then calls `human_attribute_name` | Both attempts miss the **same** normalized key; 2 |
| `human_attribute_name(:body)` from that label | `activerecord.attributes.article.body`, `count: 1` | `[:"attributes.body", MISSING]` | Both keys miss; sentinel → `"Body"`; 2 |
| `form.submit`, line 25, `model_name.human` | `article`, scope `[:activerecord, :models]`, `count: 1` | `[MISSING]` (no additional ancestor model key here) | Miss; sentinel → `"Article"`; 1 |
| `submit_default_value`, same line, persisted record | `helpers.submit.article.update`, `model: "Article"` | `[:"helpers.submit.update", "Update Article"]` | First misses, fallback hits `"Update %{model}"`; interpolated → `"Update Article"`; 2 |

Per request: **6 outer I18n calls + 5 recursive symbol-default calls = 11**
public `I18n.translate` calls, **11 Simple lookups: 10 misses / 1 hit**, on
**9 distinct normalized keys**. The six outer default arrays contain five
symbol-default entries and six literal defaults. Two symbol defaults retry
the original label key; only three add distinct keys (`attributes.title`,
`attributes.body`, `helpers.submit.update`). There is no extra fallback
locale on this route. Fallbacks calls Base.translate **16** times: five are
`key: nil` literal-default evaluations, not extra tree lookups. All five
literal fallbacks used are the two empty labels and three sentinels; submit's
last literal is not used. Do not count 16 backend calls as 16 key lookups.

### Required triggers, and why an epoch is not closed

Locale and the **entire current option hash** must remain live inputs. Cache
neither an interpolated result nor the result of a runtime-dependent Proc,
count/plural choice, default or handler. A class-name check alone is not a
backend certificate: unknown classes, singleton overrides or unrecognized
backend extensions must refuse, including custom chains/caches/key-value
backends. Even known Simple + Fallbacks is not enough for an epoch today.

Existing i18n facilities do not supply that epoch:
[`Backend::Memoize`](https://github.com/ruby-i18n/i18n/blob/v1.15.2/lib/i18n/backend/memoize.rb)
caches lookup values and resets on `store_translations`/`reload!`, not writes
through aliases or fallback mutations.
[`Backend::Cache`](https://github.com/ruby-i18n/i18n/blob/v1.15.2/lib/i18n/backend/cache.rb)
keys backend results by namespace/locale/key/options and has no automatic
translation-store invalidation. Neither is enabled in the profiled blog;
enabling one would be an app caching-policy change, not an exact certificate
Lowrail may silently assume. No existing cache was enabled for this survey.

| Dependency / mutation path | Required treatment |
|---|---|
| `Simple#store_translations`, `reload!`, `eager_load!`; lazy `init_translations` / loads | Bump before mutation/initialization, including reload paths and partial failures; don't retain an uninitialized certificate |
| `I18n.backend=`, `I18n.config=` and config/fiber swaps | Bump/revalidate actual config/backend identities and implementation facts; also account for direct Config setters, not only delegated I18n setters |
| `load_path=`, `available_locales=`, `default_locale=`, `enforce_available_locales=` and clearing locale-validation caches | Bump for changes to loading, validation/errors and default locale; setter hooks alone miss public in-place containers |
| `exception_handler=`, missing-interpolation handler, `default_separator`, interpolation patterns/reserved-key policy | Bump/revalidate parsing/error/interpolation policy; a handler's unchanged identity does not certify its mutable state |
| Fallback object replacement, `map`, `defaults=`, cached locale arrays and their in-place mutations | Bump/revalidate full relevant fallback state, including existing returned arrays, not only `fallbacks=` |
| Public `Simple#translations` tree and Hash/Array subtrees returned by `I18n.t` | Writes through these aliases need invalidation too; they bypass backend setters and retain the same object identities |
| Translation/default Proc closures, stateful exception handlers, arbitrary option values | Refuse runtime-dependent results; no configuration epoch observes arbitrary captured state. Keep normal I18n evaluation live |
| Helper/model-name/humanization methods, backend mixins and method redefinitions | Ordinary method facts/invalidation remain necessary in addition to any data epoch |

Executed in a disposable blog process with **all nine requested hook names**
instrumented (`store_translations`, `reload!`, `eager_load!`, `backend=`,
`load_path=`, `available_locales=`, `default_locale=`, `config=`,
`exception_handler=`), plus direct Config setter interception. Positive control:
`store_translations` changes the title result **and** the counter. Five
negative controls each change a real I18n result without changing that counter:

1. Assign `backend.translations[:en][:helpers][:label][:article][:title]`.
2. Mutate a Hash subtree previously returned by `I18n.t(:labels)`.
3. Append `:fr` to `I18n.fallbacks[:en]` after loading a French-only key.
4. Change a translation Proc's captured variable with key/locale/options fixed.
5. Change an exception handler's captured variable without replacing it.

The first two show the hole even for plain, non-interpolated Strings in
Simple, not just exotic backends. The last two are **refusal controls**, not
eligible translation candidates. This does not prove all exact specialization
impossible: content revalidation or an upstream mutation/version contract
could support another design. It does prove the proposed cheap setter epoch
does not cover supported behavior. Lowrail must not freeze/wrap the app's
public data or globally intercept every Hash/Array mutation to manufacture
that contract.

**Decision: `mutable_i18n_without_epoch` for the label/name chains;
`runtime_interpolation` additionally for `helpers.submit.update`.** Its
`model` value is live even though this census observes `"Article"`. Unknown
backends/extensions are `uncertified_backend`; Proc/stateful-handler cases
are `runtime_dependent_result`. No I18n pass or result cache is implemented.
Credited eligible hits and expected route saving are zero, not the 9.09%
profile share. No guard-included per-hit saving has been measured.

## Campfire URL coverage: guards are not completed specializations

Fresh production default build on main, debugger disabled; source delivery
verified by the existing stats hook. Separate 20-warmup / 10-request probes
off and on produce the same **19 named-route invocations/request**, each
once, at the sites below. Eighteen occur under compiled templates; the CSP
worker-src call runs outside that subtree. Fragment caches remain warm.

There are **7 successful `route/path` guard checks/request, in 6 units, but
0 calls to `Lowrail::Routes.finish`** and no view/link_to hits. All seven
take their original-call arm after the live `optimize_routes_generation?`
predicate returns false. `Stats.unit_fallbacks` is zero because that counter
only sees failed **guards**, not a failed inner live predicate. Treating
seven guard hits as seven optimized URLs would falsely claim coverage.

Verified cause: `ActionView::RoutingUrlFor#optimize_routes_generation?`
delegates to the controller. The controller's
`SetCurrentRequest#default_url_options` returns live host/protocol (and
optional port), so `ActionDispatch::Routing::UrlFor` returns false from
`default_url_options.empty?`. Route-set defaults are empty. The view's own
empty default hash is **not** the controller predicate's input. Removing
the check would require modeling Rails' generic generator, not merely proving
the named route's path; the existing route contract correctly falls back.

All paths below are relative to `app/`. A → means a wrapper calls that named
route, not that the wrapper itself was lowered.

| Executed source / site | Existing coverage or refusal, one call/request |
|---|---|
| `views/rooms/involvements/_bell.html.erb:5` `room_involvement_path` | Lowered; live predicate false |
| `views/pwa/_browser_settings.html.erb:101` `root_url` | Lowered; live predicate false |
| `helpers/messages_helper.rb:19` `room_messages_url` | Lowered; live predicate false |
| `helpers/messages_helper.rb:29` `room_refresh_url` | Lowered; live predicate false |
| `views/rooms/show/_composer.html.erb:4` `searches_path` | Lowered; live predicate false |
| `helpers/rooms_helper.rb:51` `room_messages_path` | Lowered; live predicate false |
| `helpers/users/avatars_helper.rb:14` `user_path` | Lowered; live predicate false |
| `views/rooms/involvements/_bell.html.erb:3` `user_push_subscriptions_path` | Ledger `arity`: required `user_id` supplied by default `"me"`, not a positional argument |
| `views/rooms/show.html.erb:10` `user_sidebar_path` | Ledger `arity`: same default-backed part |
| `helpers/users/avatars_helper.rb:15` `fresh_user_avatar_path` → `user_avatar_url` | Ledger `block_helper`: direct route reads avatar token/timestamp and adds `v:` |
| `helpers/rooms_helper.rb:9` `link_to [:edit, @room]` → `edit_rooms_closed_path` | Polymorphic `link_to`/`url_for`, not a receiverless named-helper source call; generated call carries `only_path: true`. Existing narrow view pass does not lower Ruby helper bodies |
| `views/rooms/show/_composer.html.erb:20` → `rails_direct_uploads_url` | Action Text gem internals outside app-source lowering; explicit request URL options |
| Same rich-text call → `rails_service_blob_url` | Gem internals; generic non-optimized route (filename glob), explicit request URL options |
| `helpers/rich_text_helper.rb:9` `autocompletable_users_path(room_id:)` | Ledger `options_hash`; retains dynamic query encoding |
| `views/layouts/application.html.erb:19` `webmanifest_path(format:)` | **Absent from build ledger** (layout parse, below); independently outside current options-hash contract |
| Same layout, lines 20 and 21, `fresh_account_logo_path` → `account_logo_url` (two sites) | **Absent from ledger**; block-backed direct helper reads live logo cache key and adds `v:`/`size:` |
| Same layout, line 67, `user_push_subscriptions_path` | **Absent from ledger**; independently default-backed `user_id` arity boundary |
| `controllers/concerns/inline_script_hashes.rb:18` `service_worker_path(format:)` | Outside template profile; ledger `context` (included block, not an instance `def`), also options hash |

The four absent layout sites are a **diagnostic/coverage gap**, not recorded
ledger refusals. Both source passes parse handler output at top level; Prism
reports five `Invalid yield` errors for this layout and the passes silently
return no sites. Parsing the exact same body inside `def template; …; end`
has zero errors. Rails really does wrap that body in a method. The literal
survey used that wrapper, so it did not miss these templates. Fixing source
pass parsing/diagnostics is a separate existing-pass follow-up; even then
these four sites face the options/direct/default-backed boundaries above.
No runtime or parser change was made in this investigation.

**Ledger-only follow-up:** source passes now reparse otherwise rejected
handler bodies inside `def __lowrail_template__; …; end`, as Action View
does. A successful method-context parse records `template_context`; a
remaining syntax error records `template_parse` with the parser's explanation.
Both retain the original handler and refuse lowering, so this is not new
layout optimization. The regression (layout `yield` plus malformed-handler
control, both source passes) fails before the fix and passes after it.
`cargo test --locked`: 31 unit + 3 integration tests pass. Rebuilding Campfire
adds **14 refusal-only rows** (7 templates × 2 passes), including the layout;
the **entire manifest is identical**, all 60 units, templates and file entries,
so no new fast path or hit was introduced. Evidence comparison is retained
in `.lowrail/erb-ledger-before`.

**Decision:** no cheap new named-route eligibility on this measured room,
and no completed existing lowering to price. Guard facts alone do not permit
specializing away generic route generation. The 5.72% bucket is not credited
to a new pass; expected new saving is zero. This does not contradict route
hits in other requests/test environments, where controller defaults differ.

## Remaining families and delivery state

- **Candidate 4, tag attributes**, owns the 4.46% / 2.90% tag-option buckets
  together with `form_with` / label / text-field attribute construction.
  The blog census sees 23 `tag_options` calls/request, not 23 literal sites.
  Keep attribute insertion order, escaping/SafeBuffer rules, nested data/aria,
  class arrays, nil/boolean handling and value evaluation live. Builder type,
  options, object/persisted/error/index state and method overrides need facts
  or live checks. No whole-form or I18n constant-output claim transfers here.
- `stylesheet_link_tag`, `csrf_meta_tags`, `image_tag`: noted only. Asset
  hosts/paths and overrides remain dynamic; CSRF output is per request by
  design. No cache or pass is proposed for them.
- **Candidate 3, template lookup, is next** after these refusals, with its
  own mutable-resolver/path/details contract still to establish. This report
  does not implement it or presume its micro ceiling survives guards.

Private evidence: `.lowrail/erb-survey/*.json`,
`.lowrail/erb-profile/{blog,campfire}.{metadata,stackprof,split,inputs}.json`,
`blog.census.json`, `blog.epoch-probes.json`, `campfire.routes-{off,on}.json`
and the Action View before-gate directory. The census uses call/return
TracePoints on I18n translate/lookup/default and route UrlHelper#call, plus
completed `Lowrail::Routes.finish` returns; tracing is untimed. The epoch
probes mutate only their disposable process, not translation files or apps.
Raw profiles and authenticated headers are not published.

No pass registered, runtime changed, after-gate claimed, corpus on/off HTML
gate run for a new variant, or shared `lowrail bench` speed result produced:
there is no surviving variant to gate or benchmark. The existing three-group
Action View before result remains valid. No default promotion, per-hit
saving, or route-speed claim follows from this research. Documentation is
the deliverable; app-code changes and publication are explicitly out of scope.
