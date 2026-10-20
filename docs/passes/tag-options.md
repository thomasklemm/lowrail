# Tag/form attributes: surveyed, parked as upstream-solved

2026-10-20. Candidate 4, considered as a **component**, not another ERB
call-site pass. No Lowrail runtime, builder, registry entry or unit was added.
The owner chose not to build a guarded old-version backport for this budget.
The following are census observations and estimates, not a request speed claim.

## Rails already implements the useful component transformation

Rails main's [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b)
replaces intermediate `key="value"` Strings with writes into the existing
attribute buffer. It covers ordinary, prefixed and boolean attributes, keeps
`tag_option`/`prefix_tag_option`/`boolean_tag_option` as returning wrappers,
and uses `Symbol#name` instead of allocating a key String. Its commit reports
8 → 7 objects for a class-only div, 10 → 7 for a three-attribute input,
20 → 17 for data/aria, and roughly 8–10% helper micro time saved. Those are
**upstream's measurements**, not guarded Lowrail or corpus measurements.

Checked GitHub's actual source, not commit ancestry alone: the appenders are
**absent from `8-1-stable`** at
[ac21f438](https://github.com/rails/rails/commit/ac21f438bdda4a3ecdd289a3de360e1940665372)
and from every published stable 8.1 release at inspection: v8.1.0, v8.1.1,
v8.1.2, v8.1.2.1, v8.1.3, v8.1.3.1 and v8.1.4 (latest). They are also
absent from both installed corpus implementations. This is an upstream-main
solution, not a claim that updating within 8.1 already supplies it.

Do not copy current main wholesale into 8.1: main also expands generic nested
Hash prefixes, while 8.1 expands only data/aria. That separate behavior change
is [b3dcad2f](https://github.com/rails/rails/commit/b3dcad2f5060f504b7ba7cf3a8436cec01683619).
The Campfire alpha already has that generic-prefix behavior. Both versions
still construct form attributes dynamically before calling TagBuilder.
Roundhouse's tag/form lowerings replace the view runtime and FormBuilder;
they do not preserve Rails' arbitrary `builder:`, helper and tag overrides.

## Five-app census

The [per-site appendix](tag-options-sites.md) records all 108 direct
tag/form calls, their source line, each literal/live option key, nested hashes
and splats. **Every site is refused as `upstream_solved`.** This is a survey
ledger, not additions to a build manifest. No parse omission: compiled handlers
were parsed inside a method, including layouts with `yield`. Scope: booted
compiled templates and Ruby helpers/controllers/models under `app/`.
`link_to` and `image_tag` are excluded from this source count; their actual
TagBuilder calls are included in the runtime census below.

| App | Direct sites | Fully literal option expressions | Mixed live | Unknown splat | No option hash |
|---|---:|---:|---:|---:|---:|
| real-blog-r4 | 12 | 6 | 4 | 0 | 2 |
| Campfire | 94 | 40 | 48 | 3 | 3 |
| PingCRM | 2 | 0 | 2 | 0 | 0 |
| Redprints | 0 | 0 | 0 | 0 | 0 |
| React Starter Kit | 0 | 0 | 0 | 0 | 0 |

“Fully literal” describes the **written options**, not the complete resulting
HTML attribute hash. A literal `form.submit class: ...` still adds a live
translated value and `data-disable-with`. A literal field still reads the
model, errors, object name/index, defaults and builder configuration.

Production off-only TracePoint census, 20 warmups + 10 requests/route:

| Workload | `tag_options` calls/request | `tag_option` calls/request | Distinct caller/shape rows |
|---|---:|---:|---:|
| Blog index | 30 | 69 | 16 |
| Blog edit | 23 | 57 | 16 |
| Campfire room, response cache off | 175 | 475 | 56 |
| PingCRM organizations, HTML | 11 | 25 | 10 |
| Redprints proposals, HTML | 7 | 20 | 7 |
| Starter dashboard, SSR HTML | 8 | 16 | 4 |

After eager loading, all five apps resolve all four TagBuilder methods to
the original class: zero subclass/singleton overrides observed. All use the
default Rails FormBuilder; `safe_join` is the standard OutputSafetyHelper in
all 3/34/15/25/13 controller view classes respectively. This is a boot census,
**not** an installed invalidation certificate or proof about later mutations.

### Per-site semantics and refusal boundaries

| Site/family | Static portion | Must remain live; reason against folding the whole call |
|---|---|---|
| Blog `_form:1` / comment `show:42`, `form_with` | CSS class | model persistence, scope, route/action, method, CSRF, builder and config (`live_form_state`) |
| Blog `_form:15,20`, `label` | no written attribute hash | generated `for`, index/name and I18n label defaults (`live_form_state`) |
| Blog `_form:16`, `text_field` | CSS strings inside class array | error predicates/hash token filtering, model value, generated name/id (`live_class_tokens`) |
| Blog `_form:21`, `textarea` | rows=4, CSS strings | error predicates, model body, name/id; content escapes separately (`live_form_state`) |
| Blog `_form:25`, `submit` | class | translated value, disable-with, submit config (`live_form_state`) |
| Blog comment `show:44,45,48,49,51` | classes; rows=3 | same label/field/submit machinery; literal caller options do not close it |
| Campfire layout meta/link and PingCRM layout meta | literal name/rel/type plus live content/href | leaf scalars are serialized/escaped live; their producers (request title, assets, URLs, CSRF) are not boot constants (`live_value`) |
| Campfire `messages_helper:11,24,36`, clipboard, message actions | class/id/controller strings | data values, timestamps/IDs/URLs, JSON and escaping; aria token/Hash behavior (`nested_options`) |
| Campfire bot/account/user fields | many literal class/input options | model state plus boolean autofocus/required/checked, nested Stimulus data (`live_form_state`, `boolean_options`) |
| Campfire `forms_helper:6`, `time_helper:3`, `users/profiles_helper:3` | some explicit keys | splatted keys/order/values not statically closed (`dynamic_splat`) |
| All source rows without an option hash | no attribute expression to fold | generated attributes or content-only tag (`no_option_hash`) |

Dynamic scalar **serialization** can remain live without certifying the
value's producer; that is why a component replacement is preferable to a
large family of per-site certificates. But arrays/classes, nested data/aria,
booleans, key order, `escape: false`, SafeBuffer safety and exceptional
encodings cannot be replaced with a generic HTML-escape-and-join shortcut.
Keep the live Rails conversions and once-only evaluation. CSRF output remains
per request; stylesheet/image helpers receive no additional pass proposal.

## Removable ceiling, not the inclusive form share

The earlier profile's **disjoint non-escaping TagBuilder envelopes** are
4.46% of blog edit and 2.90% of Campfire room. The 10.15% `form_with` bucket
is separate remaining form/capture/model work, not attribute-assembly savings.
Re-reading raw stacks gives these per-template upper envelopes:

| Template in measured route | Non-escaping serialization envelope, % request | Ruby TagBuilder method self, % request |
|---|---:|---:|
| Blog `articles/_form` | 2.600 | 1.339 |
| Blog `articles/edit` links | 0.242 | 0.158 |
| Blog application layout | 1.617 | 1.045 |
| Campfire application layout | 1.510 | 0.887 |
| Campfire composer | 0.510 | 0.281 |
| Campfire room outer template | 0.339 | 0.181 |
| Campfire involvement bell | 0.145 | 0.084 |
| Campfire message template | 0.078 | 0.044 |
| Campfire nav | 0.083 | 0.045 |
| Campfire lightbox + three PWA partials | 0.238 | 0.145 |

Even Ruby self samples include required branches/appends, so **neither column
is a removable budget**. No individual call-site saved-time estimate is
credited without a guarded operation measurement. Applying upstream's 8–10%
helper improvement to the whole envelope gives only about **0.3–0.45% blog
edit** and **0.2–0.3% Campfire room**, before Lowrail guards. That is the
owner's decision estimate, not a measured request effect. The other three
apps have no measured removable route budget.

## Scratch controls and delivery state

A measurement-only prototype fused ordinary scalar attribute appends while
keeping live XML/HTML escaping; arrays, hashes, regexps, nested and boolean
paths retained the original helpers. It was never installed on TagBuilder.
Each pin ran **504 asymmetric cases, zero differences** in output bytes,
class, encoding, frozen/safe flags or exception class/message: Rails 8.1.4
and Campfire 8.2 alpha. Cases included escape on/off, Unicode/binary/invalid
encodings, SafeBuffer, empty/nil, booleans, nested values, arrays and regexps.
These controls are not a full equivalence certificate. The scratch prototype
was deleted rather than creating a permanent unsupported backport.

The three Action View **before** groups remain valid: 2,747 + 242 + 173
identical outcomes in every existing layer. No new implementation means no
after/L4/corpus-on gate or `lowrail bench` win is claimed. If a component-pass
pilot is later needed, **this is the cheapest candidate**: upstream code and
`tag_helper` tests already exist, making the L4 scaffold almost free. A real
backport still needs version/source pins, boot refusal for overrides,
fact-change fallback, live escape/config semantics, all four helper test files,
five-app ordered-SQL/HTML gates and guard-included shared benchmark budgets.
