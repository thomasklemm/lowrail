# VM1: what the VM share under YJIT is made of

Bet VM1, 2026-11-15. P-MAP found 18–32% of request CPU in "VM dispatch and the interpreter" and 17–23% in
allocation, malloc and GC under YJIT, with no Rails method above 0.9% of a request
([p-map](p-map.md#native-cpu-perf-yjit)). This map splits both buckets on real request paths and names the Rails
or gem line behind each part.

**Result.** The VM bucket is not interpretation: interpreted instructions are 0.2–0.6% of retired instructions on
every app. It is the runtime's call machinery around compiled code: C methods calling back into Ruby (blocks
yielded from C, `send`/`public_send`, `Class#new` running a Ruby `initialize`, `!=` calling `==`), calls YJIT hands
to a generic send, and the `vm_call_*` helpers. Side exits (42–464 per request), invalidations (0 in steady state)
and compiles (under 2 blocks per request) are negligible. The generic sends come from a few mechanisms that repeat
across apps: class-level readers that are megamorphic because every model is its own receiver class, `super` in
anything whose receiver has a singleton class, yields after a `&:symbol` block, `...` forwarding, and Symbol or
Proc block arguments. Most of them are inherent to Rails' design or are YJIT limits (parked). Two sites in the tag helpers, which every
HTML page runs, had Rails-side fixes; both were built and reviewed, and one survives:

* **TE2** (`thomasklemm/tag-options-type-equality`): `tag_options` tests each attribute's type with `==` instead of
  `!=`. YJIT specializes `!=` only for two Integers or two Strings, so `nil != :aria` went through `rb_obj_not_equal`
  and `rb_funcall` twice per attribute: 0.10–0.57% of Puma samples on the CE2 pages. Callgrind: −1.55% and −1.73% of a whole Blog article and Lobsters settings request under YJIT, −7.2% / −16.9% on a tag micro under YJIT / ZJIT.
* **TE1** (`thomasklemm/tag-escape-without-super`, **held**): tag attribute values and `content_tag` content escaped
  without the alias plus `super` on `ERB::Util`'s singleton class that YJIT never compiles, as #59570 did for
  template appends. It is exact for Rails and erb and wins under YJIT, but it drops real prepends of the `:nodoc:`
  `unwrapped_html_escape` (makandra/angular_xss neutralising `{{`, Discourse repairing invalid UTF-8), and for
  escaping that boundary is not accepted. Under ZJIT it is flat.

Allocation has no new lever: the top sites per request by count and bytes are the ones censuses 3–9 and C10
already explain (SafeBuffers, association objects, attribute sets, path and option copies), plus app code.

## Setup

* P-MAP's three census copies (`censuspmap`: Blog, Fizzy, Mastodon) and CE2's heavier pages (`censusce2`: Blog,
  Fizzy, Lobsters), Rails main [50c54eed06](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b),
  production mode, Puma 8.0.2 in the measured process, P-MAP's workloads (6–12 per app, 20 measured requests each
  after 30 warmup requests for the counter runs).
* **YJIT counters:** Ruby 4.0.9 built with `--enable-yjit=stats` plus a per-ISEQ interpreted-instruction counter
  ([`bench/upstream/vm1/interp-insns.patch`](../../bench/upstream/vm1/interp-insns.patch)), `--yjit-stats=quiet`,
  counters diffed per measured window ([`jit_stats.rb`](../../bench/upstream/vm1/jit_stats.rb),
  [`summary.rb`](../../bench/upstream/vm1/summary.rb)). Call sites come from `--yjit-trace-exits=COUNTER
  --yjit-trace-exits-sample-rate=199` per counter ([`sites.rb`](../../bench/upstream/vm1/sites.rb)); without a
  sample rate the trace runs out of memory.
* **Native split:** Ruby 4.0.9 with frame pointers, `perf record -g` with `--yjit-perf`, each Puma sample
  classified by the native frames between its leaf and the nearest JIT frame
  ([`vm_split.rb`](../../bench/upstream/vm1/vm_split.rb)).
* **ZJIT:** pinned Ruby master 88ea6fd282, `--zjit-stats`, `--zjit-exec-mem-size=512 --zjit-mem-size=1024`
  (`compile_error_out_of_memory` is 0 in every run), and `--zjit-trace-fallbacks` traces summarized with
  [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb).
* **Allocations:** `ObjectSpace.trace_object_allocations` around the same windows, per site by count and bytes
  ([`allocs.rb`](../../bench/upstream/vm1/allocs.rb), [`alloc_report.rb`](../../bench/upstream/vm1/alloc_report.rb)).

Raw summaries are in [data/vm-share](data/vm-share).

## The VM bucket, split

Share of Puma samples, frame-pointer perf on the CE2 pages under YJIT 4.0.9. "VM" is everything P-MAP put in
VM dispatch and the interpreter, split by what sits between the sample and the nearest compiled frame. The VM
totals here (15.5–20.8%) are below P-MAP's 18–32%; the pages (CE2's) and the classifier differ, and the gap is not
reconciled.

| | CE2 Blog | CE2 Fizzy | CE2 Lobsters |
|---|---:|---:|---:|
| JIT code | 13.7 | 12.1 | 16.2 |
| **VM total** | **15.5** | **17.3** | **20.8** |
| C calling back into Ruby | 8.6 | 5.9 | 11.7 |
| Generic sends from JIT code | 2.6 | 6.0 | 4.8 |
| `vm_call_*` and other helpers | 3.4 | 4.5 | 3.3 |
| Interpreter (`vm_exec_core`) | 1.0 | 1.0 | 1.1 |
| Object allocation | 4.9 | 5.6 | 6.5 |
| GC | 8.6 | 7.2 | 5.2 |
| Core C (String, Hash, Array, Regexp, …) | 40.7 | 39.5 | 37.8 |

* **C calling back into Ruby** is the largest part. Its entry points are `send_internal`/`rb_vm_send`
  (`ActionView::Base#_run`'s `public_send` of the compiled template, 2.4% of Lobsters, and helpers called through
  `send`), `rb_obj_not_equal` (0.33–1.14%, of which `tag_options` is 0.10–0.57%: TE2),
  `rb_class_new_instance_pass_kw` (0.56–1.61%: `String#html_safe` running `SafeBuffer#initialize`, `Type::String`
  casts, `Arel.sql`), blocks yielded from C (`Hash#each_pair` in `tag_options`, tzinfo's `bsearch`), and
  `rb_vm_invoke_proc`. Switching `_run` to `send` was measured equal (66 ns each) and dropped.
* **Generic sends**: `rb_vm_opt_send_without_block` (megamorphic and singleton-class sends), `rb_vm_invokesuper`
  (Lobsters 1.06%, half of it `ERBUtil#html_escape`: TE1), `rb_vm_sendforward` (0.38–0.70%), `rb_vm_invokeblock`.
* **Interpreter**: about half of what runs interpreted follows a side exit or an exception (Blog's `_article`
  partial, i18n `translate` on the 422 form, `run_callbacks`, `ScopeRegistry#value_for`); the rest is ISEQs that
  never got entry code: `Time#initialize` from `<internal:timev>` (41,519 calls in Blog), Active Model
  Serializers' `Association#initialize` (118 calls), and `Cache::Store#namespace_key` in CE2 Fizzy (30,122 calls,
  reason not traced). Interpreted instructions per request, from the counter build:

| | Blog | Fizzy | Mastodon | CE2 Blog | CE2 Fizzy | CE2 Lobsters |
|---|---:|---:|---:|---:|---:|---:|
| interpreted instructions per request | 2,768 | 3,551 | 8,272 | 6,167 | 23,884 | 24,745 |
| share of retired instructions | 0.5% | 0.2% | 0.4% | 0.6% | 0.6% | 0.5% |

## Calls that leave compiled code, YJIT 4.0.9

Per request, mean over each app's workloads ([data](data/vm-share/yjit-counters.tsv)).

| counter | Blog | Fizzy | Mastodon | CE2 Blog | CE2 Fizzy | CE2 Lobsters |
|---|---:|---:|---:|---:|---:|---:|
| `num_send_dynamic` | 1,432 | 23,269 | 27,877 | 2,976 | 56,196 | 24,425 |
| `send_megamorphic` | 105 | 13,242 | 10,635 | 186 | 33,464 | 7,623 |
| `invokeblock_symbol` | 258 | 4,312 | 1,610 | 453 | 11,728 | 2,559 |
| `send_singleton_class` | 49 | 482 | 9,059 | 43 | 745 | 1,312 |
| `send_forwarding` | 145 | 1,580 | 2,322 | 252 | 2,849 | 2,086 |
| `invokesuper_singleton_class` | 328 | 760 | 632 | 698 | 1,160 | 4,550 |
| `send_iseq_block_arg_type` | 186 | 520 | 542 | 527 | 1,662 | 2,177 |
| `send_cfunc_block_arg` | 48 | 401 | 496 | 92 | 700 | 803 |
| `side_exit_count` | 42 | 203 | 266 | 75 | 464 | 424 |
| `invalidation_count` | 0 | 0 | 0 | 0 | 0 | 0 |
| `compiled_block_count` | 0.5 | 0.7 | 0.1 | 0.6 | 1.7 | 0.3 |

`leave_interp_return` (24k–58k per request) is the count of returns from compiled code to a C caller, the other
side of "C calling back into Ruby" above; it is not an exit.

## Ranked sites

Share × reach: the per-request count or sample share across the six page sets, and how many apps run the site.
Lines are in Rails 50c54eed06 unless named otherwise.

| # | Site | Mechanism | Per request (Blog / Fizzy / Mastodon / Lobsters) | Reach | Outcome |
|---|---|---|---|---|---|
| 1 | `tag_options` `type != :aria && type != :class` ([tag_helper.rb:1554](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/actionview/lib/action_view/helpers/tag_helper.rb#L1554)) | YJIT: `BasicObject#!=` specialized only for Integer/String, so `rb_obj_not_equal` → `rb_funcall(==)`; ZJIT: polymorphic fallback (nil and Symbol receivers) | 0.57% / 0.10% / – / 0.50% of Puma samples (CE2 perf); 2 calls per attribute | every attribute of every tag helper, all apps | **TE2 built** |
| 2 | `ERB::Util.unwrapped_html_escape` from `TagBuilder#append_tag_option` (1645–1654) and `#content_tag_string` (1536), → `super` ([util.rb:16](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/activesupport/lib/active_support/core_ext/erb/util.rb#L16)) | YJIT: `invokesuper_singleton_class` (YJIT doesn't compile `super` on a receiver with a singleton class, `codegen.rs` "to avoid retaining the receiver") | 309 / 538 / 258 / 2,880 calls through this `super`, of which the two TagBuilder callers make 276 / 467 / 143 / 2,598; 0.57% / 0.08% / – / 0.50% of samples | every escaped tag attribute and content, all apps | **TE1 built, held** (drops real prepends) for the TagBuilder callers; `safe_join` (output_safety_helper.rb:39–41, Lobsters 273), `token_list` (1835, Fizzy 65) and `h` (Mastodon 103) are the rest |
| 3 | class_attribute readers on models: `_reflections` ([reflection.rb:13](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/activerecord/lib/active_record/reflection.rb#L13), via `_reflect_on_association`:154, preloader `branch.rb:84`, `association`), `current_role`/`current_shard`/`default_shard`/`connection_handler` (core.rb:106–205 via `connection_pool`, connection_handling.rb:396), `attribute_aliases`, `__callbacks`, `schema_attributes`, `primary_key` | megamorphic: `class_attribute` defines one reader (`owner_method.reader_method`, core_ext/class/attribute.rb:116) whose receiver is each model class | 0 / 3,850 / 1,176 / 3,730 (`_reflections` 0 / 1,773 / 338 / 3,115) | every app with more than a handful of models | not built: the polymorphism is the design (one method shared by every model class); ZJIT side in [zjit-polymorphism](zjit-polymorphism.md) |
| 4 | yields in `Array#each`/`#map` (`<internal:array>`) under C Enumerables: preloader `group_by` (branch.rb:128), `owners_by_key` `each_with_object` (association.rb:176), `RowLayout` `each_with_index` (result.rb:275), `Bind#add_binds` `map(&proc)` (bind.rb:22) | YJIT: `invokeblock_symbol`. The non-inlined version of `Array#each` is compiled for the block handler it first sees; once anything calls `each(&:sym)`, that version's yield is a generic call for every later caller from C, whatever the block (micro: 0 → 80,000 for 2,000 `each_with_index` + `group_by` over 20 elements after 60 `each(&:to_s)`) | 258 / 4,312 / 1,610 / 2,559 | every app | YJIT lead, parked (below); no Rails line causes it |
| 5 | `ActiveModel::Type::Value#hash` ([value.rb:131](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/activemodel/lib/active_model/type/value.rb#L131)) from `Attribute#hash` (attribute.rb:149) | megamorphic `precision`/`scale`/`limit` | 0 / 593 / 743 / – | apps hashing attributes (query cache keys with binds) | rejected: reading the ivars would break `==`/`hash` agreement for PostgreSQL `OID::Money`, which overrides `scale` |
| 6 | `String#html_safe` → `SafeBuffer.new` → Ruby `SafeBuffer#initialize(_str = "")` → `super` (output_safety.rb:72, 245) | C `Class#new` calling a Ruby `initialize` (0.56–1.61% of samples with the allocation) | 131 / 242 / 235 / 1,024 `html_safe` | every HTML page | rejected: removing `initialize` changes `SafeBuffer.new` without arguments from UTF-8 to BINARY (`content_for` buffers, `form_helper.rb:3064`); C10 already priced the String-subclass `new` at 0.1–0.3% of a page and left it to the VM ([actionview-render-c10](actionview-render-c10.md)) |
| 7 | `...` delegates: `WhereClause#empty?` (where_clause.rb:8), `ThroughReflection#options`/`#scope`/`#name`, `TimeWithZone#method_missing` (time_with_zone.rb:620), CSRF helper delegates, AMS | YJIT `send_forwarding`, ZJIT `sendforward_not_specialized` | 145 / 1,580 / 2,322 / 2,086 | every app | YJIT lead J2 ([yjit-sendforward](yjit-sendforward.md)), ZJIT ruby/ruby#18326 (open, not ours) |
| 8 | singleton-class receivers: AMS `read_attribute_for_serialization` (serializer.rb:398), BroadcastLogger `Logger#level`, Lobsters' view (`AssetUrlHelper#asset_path`:212, `compute_asset_host`:282–284 → `ControllerHelper#respond_to?` `super`) | `send_singleton_class`, `invokesuper_singleton_class` | 49 / 482 / 9,059 / 1,312 | Mastodon (AMS, no upstream per DECISIONS), Lobsters | not built |
| 9 | `Time.===` → `super` ([time/calculations.rb:23](https://github.com/rails/rails/blob/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b/activesupport/lib/active_support/core_ext/time/calculations.rb#L23)), from tzinfo's `case value when Time` (timestamp.rb:131); `resolve_attribute_name` (attribute_methods.rb:426) | `super` in a class method (singleton receiver) | 2 / 16 / 2 / 882 | apps rendering local times | not built: no exact replacement for `Module#===` through `super`; our ruby/ruby#19487 (approved, open) compiles `super` on Class/Module receivers on master |
| 10 | Symbol and Proc block arguments: `LazyIndexedAttributeSet#fetch_value_at!`/`#value_at!` (attribute_set.rb:412, 528), preloader `reject(&:persisted?)` (association.rb:264), `all?(&:run?)`, `flat_map(&:…)` (branch.rb:28–77), `can_use_fast_cache_version?` (integration.rb:208) | `send_iseq_block_arg_type`, `send_cfunc_block_arg` | 234 / 921 / 1,038 / 2,980 | every app | `value_at!` sites: VB1 (rails/rails#59803, draft); integration.rb:208: rails/rails#59047 (open, not ours); the 35 preloader Symbol blocks are 100–300 calls per request together, below a PR |
| 11 | Fizzy's `Uuid#serialize` `map(&:…)` (lib/rails_ext/active_record_uuid_type.rb:26) | `invokeblock_symbol` | Fizzy 1,901 | Fizzy | app code |

## ZJIT on master 88ea6fd282

Per request, mean over each app's workloads.

| counter | Blog | Fizzy | Mastodon | CE2 Blog | CE2 Fizzy | CE2 Lobsters |
|---|---:|---:|---:|---:|---:|---:|
| `dynamic_send_count` | 4,970 | 41,399 | 52,795 | 12,021 | 101,929 | 61,738 |
| `send_polymorphic_fallback` | 957 | 15,710 | 13,745 | 3,334 | 57,738 | 28,624 |
| `send_megamorphic` | 58 | 9,315 | 13,332 | 50 | 6,841 | 2,287 |
| `getivar_fallback_no_profile_missing_ic` | 3,218 | 11,016 | 13,357 | 5,274 | 25,814 | 17,549 |
| `getivar_fallback_no_side_exits` | 983 | 8,831 | 10,369 | 1,146 | 9,602 | 13,590 |
| `invokeblock_polymorphic_miss` | 1,243 | 3,865 | 6,377 | 2,304 | 8,649 | 8,399 |
| `invokeblock_not_specialized` | 629 | 4,256 | 1,256 | 1,362 | 11,533 | 4,139 |
| `singleton_class_seen` | 0 | 359 | 10,521 | 624 | 1,051 | 0 |
| `sendforward_not_specialized` | 145 | 1,582 | 2,251 | 252 | 2,855 | 2,087 |
| `send_block_arg_not_nil` | 525 | 2,104 | 973 | 1,081 | 5,563 | 2,642 |
| `side_exit_count` | 41 | 343 | 16,976 | 48 | 1,218 | 933 |

The fallback trace (all four apps) ranks the same families: getivar fallbacks (`association_cache`,
`index_for_name`, `Arel::Collectors::Composite#<<`), polymorphic sends (`BasicObject#!=` from `tag_options`, the
second site overall in all four apps; `Value#hash`; `_reflections`), the `Array#each` yield under C callers
(`Inflector#apply_inflections` first), and `...` delegates. All of these are already in the
[ZJIT lead queue](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03) (leads 1, 2 and 6, the getivar
profile lead, and F1-f for Mastodon's 15,917 `patchpoint_no_singleton_class` exits). The `ERBUtil#html_escape`
`super` is not a ZJIT fallback: ZJIT compiles it.

## Allocation

Objects per request (YJIT 4.0.9): Blog 4,632 (664 KB), Fizzy 21,912 (3.1 MB), Mastodon 27,734 (2.3 MB), CE2 Blog
9,227, CE2 Fizzy 52,067 (9.7 MB), CE2 Lobsters 42,872 (4.4 MB). Allocation leaves are 4.9–6.5% and GC 5.2–8.6% of
Puma samples.

| Site | Share | What | Explained by |
|---|---:|---|---|
| `output_safety.rb:73` (`SafeBuffer#initialize` → `String#initialize`) | 19% of bytes, 0.8% of objects | the copy of each string marked `html_safe`, largest for rendered partials (`OutputBuffer#to_s`) | census 4 rank 5, C10 |
| `output_safety.rb:245` `html_safe` | 1.8% of objects | the SafeBuffer itself | census 8 rank 30, C10 |
| `tag_helper.rb:1540`, `:1545` | 4.8% and 1.7% of bytes | the tag string and `tag_options`' output buffer | inherent |
| `associations.rb:62`, `:85`; `persistence.rb:299`; `attribute_set/builder.rb:134`; `attribute_set.rb:308` | 0.8–1.4% of objects each | association objects and their cache, records and their attribute sets | inherent per record; census 4–7 and 9 list them |
| `type/string.rb:40` | 0.9% | `String.new(value)` on cast | census 3–7 |
| `hash/keys.rb:13` | 0.9% | `stringify_keys` of asset tag options | census 4–6 (mutated afterwards) |
| `journey/visitors.rb:28`, `http/url.rb:169`, `route_set.rb:233`, `:318` | 0.6–0.7% each | path buffer, its copy, URL option merges, positional params Hash | framework census rows 55–56 and 64–66 (R2, R2-3 held) |
| `preloader/association.rb:179`, `:220` | 0.7–0.9% | owner groups and per-owner record lists | inherent (census 6 lists 179) |
| Fizzy `active_record_uuid_type.rb:15–26`, `<internal:marshal>`, `cache/coder.rb:119`; sqlite3 `statement.rb:125/143` | up to 4.7% | app code, cache entries, driver rows | app / P-DRV |

No Rails site outside these is above 0.6% of objects or bytes per request in any app.

## Prototypes

Both on [thomasklemm/rails](https://github.com/thomasklemm/rails), one commit each on 50c54eed06. Scripts in
[`bench/upstream/vm1/tag`](../../bench/upstream/vm1/tag), raw cells in [data](data/vm-share/prototypes.txt).

**Callgrind micro** (`tag/ir_micro.rb`: `tag.a` with three attributes plus `content_tag` with one, Ir per iteration,
GC off; Ruby 4.0.9, ZJIT on master 88ea6fd282):

| | main | A/A | TE1 | TE2 |
|---|---:|---:|---:|---:|
| interpreter | 67,565 | −0.01% | −4.25% | −1.72% |
| YJIT | 37,316 | +0.20% | −5.29% | −7.22% |
| ZJIT | 38,907 | −0.24% | +0.11% | −16.89% |

**Whole requests** (P-MAP's `request_ir.sh` through the full Rack stack, Ir per request, GC off, N = 30 after 100
(interpreter) or 200 (YJIT, Lobsters 150) warmup requests; a YJIT cell counts only with 0 blocks compiled in the
window):

| | main | A/A | TE1 | TE2 |
|---|---:|---:|---:|---:|
| Blog article, interpreter | 8,901,438 | −0.06% | −0.60% | −0.03% |
| Blog article, YJIT | 5,160,763 | −0.15% | −0.58% | −1.55% |
| Fizzy card, interpreter | 78,517,395 | −0.06% | −1.11% | −0.64% |
| Fizzy card, YJIT | 47,626,652 | failed twice | not flat (27 blocks) | −2.27% |
| Lobsters settings form, interpreter | 25,651,701 | −0.04% | −0.80% | −0.19% |
| Lobsters settings form, YJIT | 14,863,431 | not flat (2 blocks) | −0.55% | −1.73% |

The Fizzy YJIT A/A cell ended without output twice (no OOM kill; cause not traced) and Lobsters' compiled 2
blocks, so only Blog has a YJIT A/A; the TE2 YJIT cells move 10× more than it. Lobsters' 50-story index page was
too slow for these windows under Callgrind and was dropped.

**benchmark-ips** (TE2's body script, [`tag/ips.rb`](../../bench/upstream/vm1/tag/ips.rb), core 3, interleaved,
every other job and service stopped): 10 rounds of main, a second main checkout and TE2 give, best of 10, `tag.a`
196.5k / 196.7k / 214.0k i/s (A/A +0.1%, TE2 +8.9%) and `content_tag` 319.1k / 327.8k / 345.7k (A/A +2.7%, TE2
+8.3%). Medians agree for `tag.a` (+9.3% against A/A +1.5%; TE2 beat every main run in 9 of 10 rounds) and are
smaller for `content_tag` (+3.0% against −1.6%). An earlier idle cohort of 5 rounds gave +7.1% and +4.7% against
A/A −0.6% and +0.7%, near Callgrind's −7.2%. Single runs still carry ±2–21% errors: a fresh a1.small orb that ran
only this measurement found the vCPU switching between two speeds (a pure-Ruby loop swung about 2× per 100 ms with
no steal or throttling) and failed its A/A (+12.3%). Earlier cohorts ran beside Callgrind jobs and failed their
A/A ([all cohorts](data/vm-share/prototypes-ips.txt)). TE2's body uses the 10-round cohort's best runs.

**Reviews.** Two independent passes per branch (claude-code and Opus standing in for Sol), recorded in
[TE1](../../bench/upstream/pr-queue/items/TE1.md) and [TE2](../../bench/upstream/pr-queue/items/TE2.md):

* **TE2: no must-fix from either.** Probes of 1,815 and 1,026 lines are byte-identical between main and branch on
  the 4.0.9 interpreter and YJIT and on master's interpreter and ZJIT; only a global redefinition of `!=` on
  NilClass or Symbol sees a difference (accepted). L1. Commit-message nits applied in `d018a5b457`.
* **TE1: held.** Both passes found the code exact for Rails and erb (0 differences without overrides) but flagged
  the commit message; Opus found two real callers that prepend `unwrapped_html_escape` on `ERB::Util`'s singleton
  class: makandra/angular_xss 1.0.0 (archived, 82,884 downloads) escapes `{{` there, so the branch emits raw
  `{{…}}` in `tag.input value:`, `content_tag` and `link_to` text, and Discourse's
  `lib/freedom_patches/erb_util.rb` repairs invalid UTF-8 there. The exactness checklist accepts overrides of
  `:nodoc:` methods except for escaping, so TE1 stays held like C2. Rated L2, and flat under ZJIT.
* **Side finding on #59570** (merged, unreleased): angular_xss also prepends `OutputBuffer#<<`, so its `<%= %>`
  coverage survives, but Discourse patches no `OutputBuffer` method, so on Rails main its UTF-8 repair no longer
  runs for template appends. Not acted on; for Thomas.

## Leads recorded, not built

* **YJIT `invokeblock_symbol` poisoning** (new, [yjit-leads](yjit-leads.md#leads-not-built)): `Array#each`'s
  non-inlined version keeps the block-handler type it was first compiled for; after one `each(&:sym)`, every
  yield from it falls back for every caller (all C Enumerables), whatever block they pass. 258–11,728 per request.
* **YJIT `BasicObject#!=`** (new): `jit_rb_obj_not_equal` handles only Integer and String pairs; for receivers
  whose `==` is `BasicObject#==` (nil, Symbols, most objects) it could compare identities as
  `jit_rb_obj_equal` does. TE2 removes the hottest Rails caller; preloader `branch.rb:95`,
  `abstract_adapter.rb:417`, `template.rb:508` and `association.rb:102` are the next ones (0.03–0.19% each).
* Both are YJIT changes, so they stay leads (DECISIONS: YJIT is in maintenance mode).
