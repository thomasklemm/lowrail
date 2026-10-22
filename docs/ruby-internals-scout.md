# CRuby internals scout — bet R

**Answer: no measured small Ruby C change emerges as a large Lowrail lever.**
The best Lowrail-specific opening is literal-derived tag/attribute work, but
its remaining CPU budget is small and overlaps the existing sealed tier.
Complex Active Record shapes are **zero on all three fixtures**, not a hidden
fallback cost. Allocation/GC is larger and is handed to bet J, not pursued here.
**Kill accepted; no optimization prototype, Ruby patch or upstream post.**

This is a diagnostic scout on Lowrail
[`a9a71db`](https://github.com/thomasklemm/lowrail/commit/a9a71dbf3d93b7b881d2833e7ebf6756ebf5d967),
not an accepted wall/RPS price. [Numeric evidence](ruby-internals-scout.json)
contains six profiles, allocation sites, model shapes, actual regexp callers,
replay samples and all short A/A windows. The
[worker](../bench/experiments/ruby_internals_scout.rb) is bench-only.

## Ranked readout

Rank is **Lowrail opportunity**, not descending total CPU. B/F/L mean blog,
Fizzy and Lobsters. Percentages are native YJIT **self CPU** unless marked
**replay**. Replay percentages estimate the complete operation's cost relative
to an untraced original request, not its contribution to `match_at` samples.
They are screening budgets, not rigorous speedup bounds. Rows overlap;
**never sum XML, blankness, regexp, String, allocator and GC as separate wins.**

“After sealed” means the blog's actively admitted form/token/collection tier.
No equivalent tier was activated on F/L. A residual pool is an optimistic
ceiling assuming every operation could disappear for free; it is **not** an
exactly removable pool. Unmeasured post-tier costs are explicitly unknown.

| Rank / mechanism | Measured share or objects/request | Ceiling after existing sealed tier | Exploit / rough cost / decision |
|---|---|---|---|
| **1. Literal-derived XML attribute names** | **1.30% replay**, 25.70 µs, 95 escapes, 55 Symbol→String objects on B; F 240 escapes, L 44 | B **62 escapes, 43 conversion objects**, replay **1.08%** / 20.74 µs. Already removes 33 escapes / 12 conversions. Includes its own blankness checks. | **Lowering**, no C needed. Site-level literal/schema/options and helper certificates; several days if folded into an existing template unit. A standalone generic helper replacement is not justified. **Kill standalone prototype.** |
| **2. Tag/String/SafeBuffer intermediates** | `html_safe`: **0.84% replay**, 16.67 µs, 54 calls; one-request census 54 SafeBuffers + 52 String shared roots = **106 objects** (4.4% of B). F/L total source-attributed SafeBuffers 131/32, not all this site | B site **48 + 46 = 94 objects**, replay **0.72%** / 13.86 µs. Some buffers escape and must remain; 94 is a pool, not a promise. Already removes 12 objects at these two sites. | **Lowering/fused output**, not a generic Ruby allocation API. Several days–weeks for exact helper/block/buffer continuations. Reusing a mutable SafeBuffer is wrong. A generic subclass-String C optimization would be Ruby-wide, not Lowrail-specific; no demonstrated large win. |
| **3. String blankness** | **0.99% replay**, 19.57 µs, **194 matches / 196 calls**, **0 objects**, B. F 487 matches, L 114 | B **121 matches/calls**, **0 objects**, replay **0.66%** / 12.73 µs. Most key checks overlap row 1. Only certified literal-derived callers are fold candidates; live content/paths/credentials remain live. | **Lowering at literal sites**, no C. Several days to certify a narrow template path; existing broad blank pass is ineligible with the observed **Regexp.timeout = 1.0**. No new broad replacement. |
| **4. HTML5 tag-name validation** | **0.16% replay**, 3.25 µs, 26 checks, **0 objects**, B; F 50, L 20 | B **16 checks**, replay **0.11%** / 2.06 µs; 10 already gone. | **Lowering**, no C. Small local fold inside an existing certified template, expensive as a new admission unit. No standalone prototype. |
| **5. Remaining regexp engine work** | `match_at` **2.87 / 2.81 / 1.80%**; broader named regexp symbols **4.99 / 4.89 / 3.25%** | Post-tier engine share **not measured**. These baseline bands include rows 1/3/4, URI, Rack, routing and other live input; cannot claim them again after folding tags. | C engine changes would be **generic Ruby work**, cost weeks and semantic/encoding/timeout testing. Lowering may fold only proven constant inputs, not a regexp just because its pattern is fixed. No new large candidate. |
| **6. Keyword/splat/block/Proc paths** | `vm_callee_setup_block_arg` **0.96 / 1.03 / 0.99%**; `setup_parameters_complex` **0.65 / 0.75 / 0.48%**; `vm_call_iseq_setup` **1.08 / 1.00 / 0.97%**. Source-attributed Procs **23 / 35 / 29** | Post-tier share unknown; free removal of each named baseline slice is only its displayed share. Not all setup is kwargs or avoidable; existing form fusion already bypasses some calls. | **Lowering** can eliminate whole helper layers; a small C bypass cannot discard conversion, binding, arity or block semantics. Weeks for a new exact unit; no isolated profitable callsite established. |
| **7. Hash/String operations** | Broad named Hash **7.23 / 6.19 / 6.80%**, String **4.08 / 3.90 / 2.93%**. One-request source-attributed Hashes **349 / 517 / 465**, Strings **931 / 1657 / 993** | Post-tier aggregate CPU unknown. B final attribute fragments **95→62 objects**; many encode live values and must still be produced. All Hash/String CPU is not a new optimization ceiling. | **Lowering** only after proving a particular intermediate cannot escape. Generic C optimization costs weeks; pools are spread across framework, DB and rendering, not one missing primitive. |
| **8. Ivar access / shapes** | Named shape/ivar CPU **1.42 / 1.45 / 1.21%**. **0 complex AR objects** out of **4 / 3 / 10**; **0 new shapes** in each warm profile, interpreter too | **0 observed TOO_COMPLEX rescue opportunity**. Ordinary ivar reads still cost CPU; they are not zero or all removable. | No demonstrated benefit from lowering ivar-order canonicalization or raising Ruby's shape limit. Would change observable ivar presence/order if done naively. **Kill on these fixtures.** |
| **9. Constant/method caches** | **0 constant invalidations**, **0 YJIT invalidations** in all six profiles. Warm constant misses ≈0 / 4 / 5 per request. Ordinary `callable_method_entry_or_negative` self **1.27 / 0.97 / 1.09%** | **0 observed invalidation-storm ceiling**. B's hot Lowrail method-witness share remains **0**, a different claim from ordinary VM lookup being free. F DirectSite's known 92 wrapper saving is not remeasured or reclaimed here. | Neither token C API nor new lowering established. Lookup tokens do not remove normal VM dispatch or certify mutable data. Existing token negative result stands. |
| **10. ISeq binary loading** | No `ibf_load*` / `rb_ibf_load_iseq_complete` samples in the warm request profiles | **0 observed warm loading share**, not a cold-start result | Boot-only/cold ownership belongs with bet H. Binary ISeqs still have runtime caches/JIT state; loading them is not precompiled YJIT. No warm-request C patch. |
| **J handoff: object allocator** | `rb_wb_protected_newobj_of` **6.19 / 5.15 / 5.03%**, against **2396 / 4127 / 3569 objects/request** | Post-tier allocator CPU unknown. B untimed census **2406→2037** objects already includes existing Lowrail savings/guards; not an incremental R saving | **Ruby C / GC policy** for per-object allocation cost; lowering only by removing proven objects. **Bet J**, no heap sizing or allocator changes here. 6.19% is Ruby new-object allocation, not just libc malloc. |
| **J handoff: sweep/marking** | `gc_sweep_step` **2.64 / 2.55 / 1.98%**; L additionally `rb_iseq_mark_and_move` **2.06%**, YJIT `mark_block` **1.50%**, `rb_gc_mark_and_move` **1.25%** | Post-tier share unknown. L GC.stat time is **13.88%** of measured process CPU vs B **7.26%**, F **6.28%**; not a prediction that all is removable | **Ruby C / GC policy**, not lowering alone; source/lifetime and JIT metadata matter. **Bet J**, including the Lobsters marking signal. No tuning experiment. |
| **J handoff: write barrier** | `rb_gc_writebarrier` **0.73 / 0.71 / 0.83%** self | Post-tier share unknown; free elimination of this named slice would still be <1%. Inlined barriers are outside that number | Correctness-critical **Ruby C**; lowering may remove writes only with their whole dead owners. Never skip barriers because a fixture happens to survive. No candidate patch. |

## What was actually profiled

Production Rails **8.1.4**, installed CRuby **4.0.7** revision
[`229531a6cf`](https://github.com/ruby/ruby/commit/229531a6cfbf07e3caef30dbac24a2a3f3fed482),
one sequential worker, actual interpreter (`--disable-yjit`) or native YJIT
(`--yjit-perf`), no Lowrail. Default GC; no heap-floor/allocator intervention.
Requests run through `Rack::MockRequest` and the real middleware/application/DB,
not HTTP/Puma; browser headers avoid Rails' modern-browser 406 response.
No fixed entropy is installed in timed requests.

* **Blog:** main's `script/corpus real-blog`, Roundhouse generated blog recipe,
  committed three-article/three-comment seed. `GET /articles/1` is article 1's
  two displayed comments plus the new-comment form, not three displayed comments.
* **Fizzy:** `script/corpus fizzy`, pinned
  [`6f1d200`](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9)
  with existing dependency-only `fixtures/corpus/fizzy.patch`; existing
  `bench/experiments/vm_epoch_fizzy_setup.rb` creates Bucket/User/Session and
  the signed cookie. **Minimal one-bucket fixture**, not bet F's older large
  fixture or six-route vector. Route `GET /buckets` returns 200.
* **Lobsters:** ruby-bench
  [`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
  shipped DB SHA256
  `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`,
  restored by SQLite backup into `:memory:` **per worker**. Route
  `GET /s/enr7ye`, not `/`. The Gemfile/lock copied unchanged from
  `origin/thomasklemm/guard-ceiling` pins Rails 8.1.4 and Rack 2.2.24.
  Bet H's `docs/boot-image.md` and the native-bench recipes were consulted;
  no new fixture or application source overlay was invented. Unused Puma and
  entropy recipe copies are not included in this branch.

| App | Mode | Warm / measured requests | Process CPU µs/request | Objects/request | New shapes / YJIT invalidations |
|---|---|---:|---:|---:|---:|
| Blog | interpreter | 2000 / 10000 | 3630.37 | 2386.32 | 0 / n/a |
| Blog | YJIT | 2000 / 10000 | 2041.60 | 2396.27 | 0 / 0 |
| Fizzy | interpreter | 2000 / 5000 | 6508.05 | 4103.54 | 0 / n/a |
| Fizzy | YJIT | 2000 / 5000 | 3826.13 | 4127.34 | 0 / 0 |
| Lobsters | interpreter | 2000 / 1500 | 7231.67 | 3544.19 | 0 / n/a |
| Lobsters | YJIT | 2000 / 1500 | 3838.83 | 3569.21 | 0 / 0 |

These are **profile-worker diagnostics, not mode speedup prices**. YJIT still
compiled 22 / 12 / 228 blocks in those measured windows; strict flat-JIT gates
would reject them for pricing. Later native off-A/off-B short controls (12
windows × 100 requests, 400 warmups per fresh process) drifted **+6.91%**
interpreter and **+22.33%** YJIT between arm medians. Retained, not retried or
filtered. They provide **no resolved wall benefit** and easily swamp the
remaining sub-percent operations. No optimized arm or exact-output gate is
claimed: no new optimization was prototyped.

### Instrumentation boundaries

`perf record -e cpu-clock -F 997 --call-graph dwarf,8192`, FIFO enable/ack only
after warmup/GC; no lost samples in any profile. Hardware cycles/instructions
are unavailable in this orb, but software CPU-clock works. Flat self costs are
usable; many Ruby/JIT caller stacks unwind to unknown addresses. A separate
three-request `TracePoint(:call, :c_call)` run therefore identifies actual
regexp primitives and Ruby callsites. Counts are **not** used to distribute
`match_at` time proportionally. No Regexp/String wrappers disturb backrefs.

Object census uses a separate worker: `ObjectSpace.trace_object_allocations`,
one retained request, GC disabled only for that census. It includes transient
objects but excludes objects without attributable source from the site/class
table. The residual between the table and total allocations is **not** called
IMEMOs: it also contains non-enumerated/no-source and excluded worker objects.

Replay retains receivers/arguments in a disposable traced worker, then uses a
**fresh untraced process**, seven original/empty-A/empty-B loop-control rounds,
2000 bundles/round, with 300 bundle warmups. XML replay includes its nested
blank?; html_safe includes SafeBuffer initialization. Mutable captured values
are retained through the request, not snapshotted byte-for-byte at call entry;
storage sharing, later mutation and loop reuse limit these estimates further.
Captures are private,
trusted local Marshal files, never shipped. Initially trying replay in the
same process as TracePoint deoptimized YJIT and inflated the denominator; those
timings were discarded, not mixed into the published fresh-process estimates.
Source-symbol sums use the explicit regexes in JSON; symbols below 0.05% or
with long JIT labels are omitted from the exported individual-symbol list,
not from group sums. Groups are partial named costs, not exhaustive attribution
of inlined work, and do not all form a disjoint partition.

## Regexp and literal-versus-live attribution

Blog's leading patterns are `String::BLANK_RE` (`\A[[:space:]]*\z`, **194**),
`ERB::Util::SAFE_XML_TAG_NAME_REGEXP` (**95**) and
`TagHelper.ensure_valid_html5_tag_name` (`\A[a-zA-Z][^\s/>]*\z`, **26**).
Thus the main tag signal is **Rails helper scaffolding**, not ERB's normal
HTML-escape primitive. URI's RFC3986 absolute and relative parser regexps each
run **5** times/request; Journey's article recognition regexp runs **1**.
Browser, Rack MIME/content-type, parameter filtering, inflection and AR matcher
patterns are recorded with their callers in JSON, not relabeled as templates.
F/L's blank/XML/tag counts are **487/240/50** and **114/44/20** respectively.
All three observe global `Regexp.timeout = 1.0`.

### 1. XML names and tag validation

`active_support/core_ext/erb/util.rb:143–145` calls `name.to_s`, `blank?`, then
`match?`. All **95** blog calls come from
`action_view/helpers/tag_helper.rb:296` (`tag_option`), including **4** through
`:317` (`prefix_tag_option`). Inputs: **55 Symbols**, **36 frozen Strings**,
**4 constructed mutable Strings** (`data-turbo-confirm` ×3 and
`data-disable-with` ×1). Keys include `name`, `content`, `class`, `href`,
`type`, `value`, `method`, `action`, `channel`, `signed-stream-name`, `for`,
`id`, `rows`, `accept-charset`, `rel` and `data-turbo-track`.

These keys are literal-derived framework/template names on the inspected
paths; their **values are often live** (URLs, CSRF, stream signature). A lowered
certified site can pre-escape a key or static prefix without folding the value.
Frozen-at-observation alone is not proof: `stringify_keys`/Hash key insertion
can freeze names supplied by arbitrary callers. The four `data-*` keys are
also fold candidates only after following their literal prefix/key sources.
Shared preescaped strings must not acquire newly observable mutation/identity.

The 26 tag checks are `a` ×2, `input` ×9, `button` ×3, `form` ×4, `label` ×2,
`textarea` ×1, `meta` ×2, `link` ×2 and `turbo-cable-stream-source` ×1.
The last is a mutable default option from Turbo, **not** universally fixed by
its observed bytes. `show.html.erb:24–26,42–51`, `_comment.html.erb:4` and the
layout's CSRF/assets/importmap paths lead to these helpers. Template-derived
literal names can be validated at lowering/admission; generic `tag(name)`
still validates live input and preserves exceptions.

Gross XML ceiling **55 objects**, **1.30% YJIT / 0.98% interpreter CPU**;
gross tag validation **0 objects**, **0.16% / 0.11%**. The active existing
sealed artifact removes XML **95→62** (conversions **55→43**) and validations
**26→16**. Incremental residual budgets are **1.08%** and **0.11%**, before
guards and without claiming every surviving input is certifiable.

### 2. String blankness by caller and provenance

196 calls include **2 empty translator defaults that skip matching**; 194
actually run BLANK_RE. Observed receivers: **102 mutable Strings**, **85 frozen
Strings**, **9 mutable SafeBuffers**. In particular, frozen request headers
and cipher names must not be confused with literal template keys.

CPU estimates below apportion the **0.99% inclusive replay** by call count
only for rough screening; they are **not perf callgraph attribution** or exact
per-caller timing. Empty calls and long content differ; every row's hard
observed allocation ceiling is **zero**. XML's 95 calls are already included
in the XML budget, not another 0.48% to add to it.

| Caller group (Rails 8.1.4) | Calls / approximate CPU | Literal, boot-frozen, or live? |
|---|---:|---|
| `ERB::Util.xml_name_escape:144` | 95 / ~0.48% | 36 frozen key Strings; 55 Symbol conversions and 4 constructed `data-*` keys are mutable but literal-derived on these paths. Certify names, not arbitrary mutable receivers. |
| `TagBuilder.tag_options:240,245` | 45 / ~0.23% | Frozen framework/template attribute keys, including the nested data key. Usually same literal provenance as XML; no extra objects. |
| `content_tag_string:229` | 13 / ~0.07% | 5 template-literal link/button texts, 2 locale-dependent label texts, 6 live SafeBuffers (forms/scripts/content). Only the first five are bare literal-fold candidates. |
| `field_name`, `field_id`, label name, translator, human attribute name | 14 / ~0.07% | Derived form/model names, locale/error-sensitive labels; includes 2 empty defaults. These paths are already bypassed by the sealed scaffold, not a fresh R saving. |
| CSRF `normalize_action_path:648`, Journey `generate:95,99` | 10 / ~0.05% | Live route/action/model-ID strings. Fixture repetition is not boot constancy. |
| `capture:55`, `content_for:183` | 3 / ~0.02% | Live SafeBuffers from blocks/slots; final output may be static in this fixture but arbitrary capture is effectful. |
| `asset_path:191`, `stylesheet_link_tag:219` | 4 / ~0.02% | Literal-derived logical paths and generated asset URLs; boot manifest/config and overrides need certification. |
| Cookie encryption/HMAC helpers | 4 / ~0.02% | 2 mutable secret strings, 2 frozen cipher/digest names read from configuration. No template fold; no secret values exported. |
| Request ID, tagged logger, browser checks | 4 / ~0.02% | 2 frozen **request inputs**, 2 mutable derived inputs. Remain live despite frozen status. |
| Strong params and SQL sanitization | 3 / ~0.02% | Live ID and SQL strings, not constants. |
| Turbo stream argument `present?` | 1 / ~0.005% | Model-ID-derived stream name; live. |

The 81 frozen key checks (36 XML + 45 tag_options) plus the other 4 frozen
receivers reconcile to 85, not “85 foldable literals.” The existing tier
removes **73 matches** and both empty calls: **196→121 calls, 194→121 matches**.
Remaining whole-blankness replay is **0.66%**, mostly overlapping XML keys.
A general replacement must still respect Unicode/invalid encoding, exceptions,
timeout policy and subclass dispatch; this scout does not reopen that pass.

### 3. SafeBuffer and tag/String sites

`String#html_safe` (`output_safety.rb:242`) constructs a SafeBuffer and
`SafeBuffer#initialize:71` calls String initialization. It is not two copies
of the final HTML bytes in every case. CRuby can make an extra **frozen shared
root String** for subclass sharing. One-request source census:

| Allocation site | Original B | Existing sealed B | Interpretation |
|---|---:|---:|---|
| `tag_helper.rb:309` | 95 Strings | 62 | Complete `key="escaped live value"` fragments. Preescaping a key alone does not eliminate the whole fragment. |
| `erb/util.rb:143` | 55 Strings | 43 | Symbol `to_s`; covered by XML ceiling above. |
| `output_safety.rb:242` | 54 SafeBuffers | 48 | Wrapper pool; escaping/rendering still needs final output and SafeBuffer semantics. |
| `output_safety.rb:71` | 52 Strings | 46 | Superclass initialization/shared-root pool, coupled to wrappers. |

Actual `html_safe` callsites include tags (26 validated tags plus Turbo meta,
seven importmap preloads and two script tags), 4 template buffer conversions,
2 captures, collection output, 2 stylesheet result conversions/one Propshaft
join, 3 safe_join calls, 2 importmap string conversions, the CSRF join and
2 layout slots. Final body/slot conversions can escape; do not count them all
as dead temporary pairs. A lowered tag that writes directly to the right
buffer can avoid an intermediate wrapper/root; a generic “make every
html_safe a constant” cannot.

Fresh replay gives **101** rather than census **106** objects because replay
reuses captured receivers and can reuse shared roots after warmup. The sealed
capture similarly replays **90** versus one-request **94**. Report both; do not
replace the larger one-request pool with an apparently exact per-request
replay saving. Gross full-operation replay: **0.84% YJIT / 0.62% interpreter**;
remaining after sealed **0.72%**. No proof that 94 more objects can be removed.

## Matching CRuby source: 4.0.7 and master

Inspected v4.0.7 above and canonical master
[`faefcb1105`](https://github.com/ruby/ruby/commit/faefcb11050ea61ee011e3b73c929ff406d30b68),
alongside the owner's `thomasklemm/ruby` fork. **Master is source inspection,
not a measured runtime/build; no master speed or compatibility claim.** The
fork's older master pointer is not substituted for current canonical master.
Method-token commits remain out of scope; the supplied
`thomasklemm/method-token-guards` draft was read, not rerun as a new lever.

| Mechanism | 4.0.7 source and what it establishes | Master comparison |
|---|---|---|
| Regexp | [`re.c:3884`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/re.c#L3884) `rb_reg_match_p` prepares/searches with NULL match regs; `:1700` handles temporary regex/timeout. [`regexec.c:2311`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/regexec.c#L2311) is `match_at`. Boolean `match?` is already not allocating MatchData for these calls. | `re.c:4150` retains prepare/search and timeout semantics (length types changed). No missing cheap boolean primitive discovered. |
| String/SafeBuffer | [`string.c:1453`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/string.c#L1453) `str_replace_shared_without_enc` may call `rb_str_new_frozen`; `:2065` String initialize reaches replace. The exact-class String constructor shortcut does not make arbitrary String subclasses free. | `rb_str_init:2140` retains subclass initialization/sharing responsibilities. A new Lowrail API would not erase a required output buffer. |
| Shapes/ivars | [`shape.c:805`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/shape.c#L805) respects per-class variation budget and falls back on failed transition; `vm_insnhelper.c:1684` delegates to cached `vm_getivar`. Variable storage and shape IDs are not Rails schema columns. | Still variation budget **8**, capacity and complex fallback; YJIT `gen_getinstancevariable` / `gen_setinstancevariable` already specialize shape-checked accesses. No measured failed transition to repair. |
| kwargs/blocks | [`vm_args.c:291`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/vm_args.c#L291) builds kwrest Hash; `:589` sets up complex parameters, `:1116` block args. Eliminating calls can avoid work, but bypassing setup is not semantics-preserving by default. | Same kwrest construction at `:293` (capacity API renamed), required/default/unknown-key handling persists. No generally removable Hash proven by these profiles. |
| Hash | [`hash.c:2952`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/hash.c#L2952) insertion chooses representation/update path and preserves mutable key/iteration semantics. | Existing representation specialization is not a license to replace live options with immutable constants. |
| GC/barrier | [`gc.c:3364`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/gc.c#L3364) delegates write barriers to GC; `gc/default/default.c` owns sweep/remember/mark. `RB_OBJ_WRITE` remains required for reference writes. | Collector ownership remains; metadata marking is real, especially in Lobsters' YJIT sample. J handoff, no patch. |
| ISeq/cache | [`compile.c:14834`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/compile.c#L14834) completes lazy binary ISeqs and initializes tracing; `vm_insnhelper.c:6580` checks constant caches. | `compile.c:15144` retains completion/trace initialization. No warm-load hotspot or invalidation storm observed. |

### Shape negative result in detail

Warm `next_shape_id` stays **2759 / 2951 / 2656** (B/F/L), with cache sizes
**6815 / 6857 / 6157**, in both modes. These IDs are worker-local, not a cross-app
count of model layouts. Retained allocation census finds:

* B: Article ×1, Comment ×3; Comment has two shapes/orders because the new
  form model has an additional `@errors`, not arbitrary initialization order.
* F: Bucket/User/Session ×1; stable AR order, Session adds validation context.
* L: Domain ×1, Tag ×1, Comment ×2, User ×3, Vote ×1, Story ×2; Story's extra
  validation context explains its second observed order.

All have `too_complex_shape` absent/false in ObjectSpace dumps; the CRuby dump
implementation explicitly emits that flag for a complex object. This is an
honest **0 observed complex objects / 0 warm shape creation** for these requests,
not proof that every Rails endpoint or every boot object avoids complex shapes.

## Reproduction and verification

Prepare corpus dependencies/DB/assets with the existing recipes first. Keep
Fizzy's signed-cookie JSON private. From the appropriate **application cwd**:

```sh
# BUNDLE_GEMFILE is the app Gemfile, or the absolute Lobsters wrapper path.
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 LOWRAIL=0 \
  BUNDLE_GEMFILE="$gemfile" SCOUT_WARMUP=2000 SCOUT_N=10000 \
  mise exec ruby@4.0.7 -- ruby --yjit-perf -rbundler/setup \
  "$lowrail/bench/experiments/ruby_internals_scout.rb" blog profile /tmp/profile.json
# Substitute --disable-yjit for interpreter; app fizzy/lobsters selects its route.
# Fizzy also needs SCOUT_HEADERS=/private/signed-cookie.json.
```

For perf, create control/ack FIFOs with `mkfifo`, set `SCOUT_PERF_CONTROL` and
`SCOUT_PERF_ACK`, then wrap the Ruby command with
`perf record -e cpu-clock -F 997 --call-graph dwarf,8192 --delay=-1
--control=fifo:CONTROL,ACK -o /tmp/perf.data --`.
Use `perf report --stdio --no-children --sort symbol --field-separator '|'`
for self costs. Run `census` and `regexp` in **separate untimed workers**.
For replay, run `capture` with private `SCOUT_INPUTS=/tmp/inputs.marshal`, then
`budget` with that same file in a **new** worker. `wall` retains all 12 windows.

Existing sealed overlap was checked with fresh YJIT build artifacts filtered
to only form/token/collection, compiled through `gem/exe/lowrail-compile`,
`LOWRAIL=1 LOWRAIL_SEALED=1 LOWRAIL_STATS=1` and
`RUBYOPT="-I$lowrail/gem/lib -rlowrail/setup"`. Form admission was active after
one natural witness; all three unit IDs had hits. No new exactness or throughput
claim is made from that diagnostic comparison.

Executed: six native perf runs (all 200, no lost samples), six censuses, regexp
attribution on all apps/modes, fresh replay on B interpreter/YJIT plus residual
sealed capture, and the noisy native A/A controls. Ruby worker syntax and JSON
consistency are checked. No application/gem production code changed. No broad
regression suite, C build, master runtime, new optimization output comparison,
or hosted CI is claimed. Private request inputs/cookies and perf dumps are not
committed; exported evidence contains numeric sites/patterns, not secret values.

## Verdict

Nothing measured supports a **large Lowrail-specific win from a small Ruby-side
change**. The strongest specific lead is modest literal tag/attribute folding,
which needs no C patch and already overlaps the sealed form/token/collection
tier; its remaining XML, blankness, SafeBuffer and validation pools are small,
overlapping and not all eliminable. Shapes and invalidation storms offer zero
observed rescue opportunity on all three requests. Broad Hash/String/call
setup work is real but distributed, not one absent VM primitive. A genuinely
better allocator/collector or less YJIT metadata marking could plausibly matter
(especially Lobsters), but that is generic Ruby/GC work for **bet J**, with no
demonstrated small exact patch here. **Do not prototype or open an upstream
case from this scout; retain the negative result and fold literal tag work only
as a cheap part of an already justified, exactly certified template unit.**
