# ZJIT leads from per-ISEQ stats (bet Z10)

Bet Z10 ([DECISIONS](../DECISIONS.md), 2026-11-03): build the per-ISEQ stats sketched in
[zjit-stats.md](zjit-stats.md) §2 for Shopify/ruby#746, run it on the apps, and name the biggest concrete ZJIT
leads. Nothing is posted or opened; the #746 claim still waits for a reply.

## The tool: `--zjit-stats-iseq`

thomasklemm/ruby `thomasklemm/zjit-stats-iseq` @ `508f80e462dc8b6bb9aab6caa623da265663ef48`, one commit on ruby/ruby
master `9aa0898240`, 8 files, +126/−42. Not a PR.

* `--zjit-stats-iseq` implies `--zjit-stats-quiet`. With it off, the generated code is unchanged.
* Every counted HIR event (`Function::count`, `count_send`), send fallback (`gen_incr_send_fallback_counter`) and
  side exit also increments a cell for **the ISEQ of the instruction's FrameState**. Inlined code therefore counts
  for the callee. Cells live in `ZJITState` like `iseq_calls_count`, keyed by counter and ISEQ location, and are
  reset by `reset_stats!`.
* `RubyVM::ZJIT.stats` reports them as `:"iseq:<counter>:<label>@<path>:<line>"`. The stats print gains top-20
  sections for send fallbacks and side exits by ISEQ.
* Per-ISEQ HIR counters of a send are tracked in `send_counters`, like the global ones, so a retried send doesn't
  accumulate them (the #995/#19485 property).

**Checks**

* `test_stats_iseq` in `test/ruby/test_zjit_cli.rb`: three methods, one of them inlined into a caller. It asserts
  exact per-ISEQ counts (10 and 5, 0 for the inlining caller) and that every per-ISEQ counter sums to its global
  counter. On master the flag is rejected (`invalid ZJIT option 'stats-iseq'`), so the test fails there.
* `test_zjit_cli.rb`: 29 tests pass.
* btest at `--zjit-call-threshold=1`: 2141/2141 pass, both with and without `--zjit-stats-iseq`.
* `make zjit-test` (nextest, `ZJIT_TEST_FEATURES=disasm`): 1939 tests. The only failure is
  `test_profile_frames_during_direct_jit_to_jit_entry` ("rb_profile_frames was not called from SIGPROF handler"),
  which is load-sensitive on master too. Under the same 8-way CPU load it passed 6/15 on base `9aa0898240` and
  5/15 on the head, and it passes alone on an idle orb. Clean full runs happen on both.
* On real data the sum property holds: across 13 runs (10 census apps, 3 ruby-bench) **0 per-ISEQ counter sums
  differ from the global counter**. The globals also reproduce the #1099 numbers exactly (railsbench
  `getivar_fallback_no_profile_missing_ic` 221,098/itr; lobsters 320,308; shipit 836,857).

**Cost.** About +3.5% over `--zjit-stats-quiet` on railsbench (see [Cost](#cost)). Cells in a run: 50,930 over the 10 apps, 10,429 over ruby-bench.

## Data

* **Census apps:** the 10 census-4 configurations on Rails `5810776eec` (blog, campfire, writebook, fizzy,
  fizzy-mysql, codetriage, pingcrm, redprints-cfp, react-starter-kit, lobsters), via
  `script/jit-parity-census stats-one APP zjit OUT --zjit-stats-iseq`. Each run warms up, resets, then runs every
  workload 20 times. "Per op" means per request, job or mailer.
* **ruby-bench:** railsbench, lobsters, shipit (Rails 8.1.x gems) with
  [`bench/upstream/zjit_iseq_harness.rb`](../../bench/upstream/zjit_iseq_harness.rb), 10 warmup and 10 measured
  iterations. "Per itr" means per benchmark iteration.
* **F1's 21 master configurations** (Rails main `c042aee23a`, 18 apps) are queued in the F1 orb with this build,
  behind F1's own passes. They aren't in this record yet; they will be added when they arrive.
* Ranking: [`bench/upstream/zjit_iseq_rank.rb`](../../bench/upstream/zjit_iseq_rank.rb) (ISEQ × counter, by apps
  reached, then per-op cost) and [`bench/upstream/zjit_iseq_leads.rb`](../../bench/upstream/zjit_iseq_leads.rb)
  (lead totals). Raw JSONs and both rankings:
  [`data/zjit-iseq-leads/receipts.tar.gz`](data/zjit-iseq-leads/receipts.tar.gz).

**Code region caveat (found 2026-11-03 via F1).** With `--zjit-stats` the default 64 MiB
`--zjit-exec-mem-size` filled in fizzy, fizzy-mysql and lobsters (`compile_error_out_of_memory` 195k / 168k / 74k;
`--zjit-mem-size` alone doesn't lift it). Rerun of those three plus writebook with
`--zjit-exec-mem-size=512 --zjit-mem-size=1024`: code region 89 / 88 / 70 MiB, no out-of-memory, writebook
unchanged. The 10-app means above and in the (since deleted) #1039 comment move by at most 4% (send 186 → 192, sendforward
331 → 344, protected 188 → 191, constant exits 230 → 228, #1100 22.5 → 23.2); the named top sites are unchanged
(Visitor#visit 101.5, WhereClause#empty? 91.5, OrderedOptions 113.9, fetch_or_store 20.9). Only
`singleton_class_seen` moves more: 391 → 431 per op (fizzy 145 → 266). Raw runs: `apps-mem1g/` in the private
data; the tables here keep the original runs.

Reasons by apps reached (all 10 apps; mean per op over all 10):

| reason | per op | ruby-bench per itr (railsbench / lobsters / shipit) |
|---|---|---|
| `send_fallback_send_polymorphic_fallback` | 2,589 | 26.5k / 247k / 663k |
| `getivar_fallback_no_profile_missing_ic` | 2,493 | 221k / 320k / 837k |
| `getivar_fallback_no_side_exits` | 1,662 | 74k / 154k / 411k |
| `send_fallback_send_megamorphic` | 1,184 | 190k / 100k / 111k |
| `send_fallback_invokeblock_polymorphic_miss` | 1,139 | – |
| `send_fallback_invokeblock_not_specialized` | 530 | – |
| `send_fallback_one_or_more_complex_arg_pass` | 421 | 105k / 41k / 83k |
| `send_fallback_send_block_arg_not_nil` | 334 | 120k / 95k / 201k |
| `send_fallback_sendforward_not_specialized` | 331 | 75k / 32k / 101k |
| `send_fallback_send_not_optimized_need_permission` | 188 | 55k / 16k / 30k |
| `send_fallback_send_not_optimized_method_type_optimized` | 186 | 42k / 26k / 70k |
| `setivar_fallback_no_side_exits` | 182 | 0 / 6k / 0.2k |
| `exit_guard_type_failure` (side exits) | 77 | 0 / 2.8k / 1.3k |

The top four are #1099's polymorphism data. The rest are more concrete: each has one or a few ISEQs, a single
mechanism, and in most cases a patch already exists on k0kubun's lobsters branch.

## The 10 biggest concrete leads

"Apps" counts the census apps (of 10) where the (counter, ISEQ) pair is non-zero. "Per op" is the mean over the
apps reached. Side exits (#8, #9) cost far more per event than fallbacks.

| # | method (file:line) | counter | apps | per op | ruby-bench per itr (rb / lob / ship) | owner / tracker |
|---|---|---|---|---|---|---|
| 1 | `Array#each` yield (`<internal:array>:266`); also `map` :284, `find` :335 | `invokeblock_polymorphic_miss` / `not_specialized` | 10 | 924 (+342 map, +131 find) | 201k / 87k / 259k | #1099 item 4; Shopify/ruby#1093 (inlining); #1039 rows 26, 28, 55 |
| 2 | `BasicObject#!=` (`<internal:basic_object>:14`): the inner `==` is polymorphic | `send_polymorphic_fallback` | 10 | 282 | 0 / 3.8k / 0 | #1099 (polymorphism); #19162 already inlines `!=` |
| 3 | `ActiveRecord::Reflection._reflections` (reflection.rb:13); also `attribute_aliases`, `schema_context` | `send_polymorphic_fallback` | 10 | 120 (`attribute_aliases` 51; `schema_context` 142 in 5 apps) | 0 / 4.6k / 3.9k (`attribute_aliases` shipit 12.4k) | #1099 item 2 (many model classes, one method entry) |
| 4 | **protected calls:** `@parent._get(k)` in `OrderedOptions#initialize` block (ordered_options.rb:109), `other.extract_attributes` in `WhereClause#merge` (where_clause.rb:30) | `send_not_optimized_need_permission` | 10 | 114 (all protected: 188) | 55k / 16k / 30k | #1039 row 47 `bd5d9ed755` "Compile protected calls behind a check on the caller's self": unassigned, not on master |
| 5 | **`Kernel#send`:** `send(dispatch_method, object, collector)` in Arel `Visitor#visit` (visitors/visitor.rb:35) | `send_not_optimized_method_type_optimized` | 10 | 102 (all `send`: 186) | 0.1k / 14k / 28k (all: 42k / 26k / 70k) | #1039 row 11 `315cb1edd6` "Compile send/__send__ with a profiled method name": unassigned, not on master |
| 6 | **`delegate … to:` (`def m(...)`):** `WhereClause#empty?` (where_clause.rb:8) → `predicates.empty?(...)` | `sendforward_not_specialized` (+ same-ISEQ `getivar_fallback_no_profile_missing_ic`) | 10 | 92 (all sendforward: 331) | 75k / 32k / 101k (all) | #1039 rows 20 and 22 (`e86591975e`, `8faf844778`): unassigned, not on master. Master has only the callee side (#18606) |
| 7 | **`&block` forwarding:** `mon_synchronize(&b)` (monitor.rb:147), `iterate_guarding_exceptions` (fanout.rb:23), `ConnectionPool::Queue#synchronize` (queue.rb:99), `with_connection` (connection_handling.rb:361) | `send_block_arg_not_nil` | 10 | 63 for monitor (all `&block`: 334) | 120k / 95k / 201k (all) | Shopify/ruby#1014 (open, unassigned); #1039 rows 41, 42, 44, 49. On ruby-bench's Rails 8.1, `_read_attribute(name, &block)` alone is 36k / 58k / 68k; Rails main removed that block |
| 8 | **`super` from a method that received a block side-exits every call:** `AssociationRoute` cache `fetch_or_store` (association_route.rb:189), `cleanup_view_runtime` (controller_runtime.rb:43) | `exit_unhandled_block_arg` | 10 | 21 (all: 22.5) | 2.1k / 0.3k / 0.06k | Repro: 10,000 exits in 10,000 calls, for explicit `super(x)` and zsuper. The guard has `recompile: None`. On k0kubun's branch the same guard has `recompile: Some(Recompile)` (super rows 45/46, unassigned). No issue covers it |
| 9 | **invalidated constant patch points that keep exiting:** `WhereClause.empty` → `EMPTY` (where_clause.rb:99), `FromClause.empty` (from_clause.rb:22), `connection_specification_name` (connection_handling.rb:320) | `exit_patchpoint_stable_constant_names` | 5 | 230 (fizzy 252) | 0 / 0 / 38.5k | #1039 row 19 `69b586ee80` "Let invalidated ISEQs recompile instead of exiting forever" (version budget spent): unassigned, not on master. Why these constant names get redefined per request is open; hand to J1's Z12 (invalidation churn) |
| 10 | **`singleton_class_seen` in `ActiveModel::IndexedRow#fetch`** (indexed_row.rb:172, Rails main only): `UNSET.equal?(value)`, where `UNSET = Module.new.freeze` | `send_fallback_singleton_class_seen` | 6 | 330 (lobsters 1,220) | 0 / 1.2k / 0.2k (htmlentities) | linyiru's ruby/ruby#19658 (open) / #19669 (closed 2026-11-03). Receiver class is plain `Module`; see [lead 10 below](#lead-10-the-receiver-class) |

Not in the 10, for the record:

* `setivar_fallback_no_side_exits` in `Relation#reset` (relation.rb:1256): 6 apps. Shape-polymorphic, a #1099
  relative.
* `complex_arg_pass` (421/op): spread over unrelated sites. The largest are `resolve_attribute_name`
  (`fetch(super, &:itself)`), `Core#relation` and Rack `fetch_header`.
* App-specific `exit_guard_type_failure`: lobsters `build_default_scope` 1,433/op, `content_tag_string` 538/op.

**What this means for us.** Leads 4–7 and 9 are patches on k0kubun's `zjit-lobsters7` branch that #1039 lists
without an assignee. The shortlist rule is not to take #1039 rows, so the useful move is to give him the
per-request breadth on Rails main (10/10 apps for 4–7) as upstreaming priority data, not a competing patch.
Lead 8 is the only one without an issue. It's small: give the block-handler guard a recompile, or specialize the
implicit block pass through `super`. It's also in the area of k0kubun's super rows, so it needs an ownership
question first. Leads 1–3 are #1099. Lead 10 is the general #19658/#19669 problem with `Module` as the class, so it belongs with linyiru's PRs.

## Queue: which leads are free (2026-11-03)

Rule (DECISIONS 2fa718c, after k0kubun on [Shopify/ruby#1100](https://github.com/Shopify/ruby/issues/1100)): an idea is
taken when its own issue has an assignee, an open PR exists, or a tracker table names an assignee for it (such as
the Assignee column of Shopify/ruby#1039); an unassigned tracker row is free. On 2026-11-03 I checked issue
assignees, all open ruby/ruby PRs with "ZJIT" in the title, and all 83 rows of Shopify/ruby#1039 (body as of
16:56Z), the only open Shopify/ruby tracker with an assignee column. Numbers below come from runs with 0
`compile_error_out_of_memory` (the three apps that hit the 64 MiB code region were rerun with `--zjit-exec-mem-size=512 --zjit-mem-size=1024`). "Per op" is the mean over the apps reached;
ruby-bench is per iteration (railsbench / lobsters / shipit).

**Taken**

| lead | taken by |
|---|---|
| 1 polymorphic yield in `Array#each`/`map`/`find` | block inlining is k0kubun's (Shopify/ruby#1093, assigned); marked taken 2026-11-03 together with run-time block-ISEQ dispatch (Shopify/ruby#1039 row 55), which sits in the same area. Gap: 70.4 / 27.2 / 60.9 M Ir per iteration ([zjit-yjit-gap](zjit-yjit-gap.md)) |
| 4 protected calls | ours, ruby/ruby#19483 (open). Gap: 14.9 / 4.4 / 10.6 M Ir |
| 5 `Kernel#send` | tekknolagi, ruby/ruby#19583 "Support .send(:symbol)" (open). Gap: 11.3 / 4.7 / 14.3 M Ir |
| 6 `def m(...)` forwarding | nozomemein, ruby/ruby#18326 "Specialize monomorphic sendforward calls" (open). Gap: 1.4 / 1.4 / 4.2 M Ir; YJIT falls back at most of these sites too |
| 8 `super` with a block | cleared by k0kubun on Shopify/ruby#1100; fix on [thomasklemm/ruby `zjit-super-block-recompile`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-super-block-recompile), PR queued (not opened) |
| 9 invalidated constant patch points | k0kubun, ruby/ruby#19617 "Recompile final versions invalidated by PatchPoint" (open). shipit: 38.5k exits and 381k interpreted instructions per iteration |
| 7 `&block` forwarding | k0kubun: Shopify/ruby#1039 row 7 (`93e4e7d69c` "Pass a `&blk` argument through to a direct send") lists him as assignee. Found 2026-11-03 after our build; our branch [`thomasklemm/zjit-forward-block-param`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-forward-block-param) @ `ab21c5458b` stays unopened. |
| 17 `throw` from blocks and exception handlers unwind by longjmp and materialize frames | Shopify/ruby#1093 (k0kubun, TAG_RETURN/TAG_BREAK), ruby/ruby#18244 (luke-gruber, draft, `throw`), ruby/ruby#18759 (rafaelfranca, exception handlers). Gap: 15.6 / 5.3 / 13.2 M Ir in `zjit_materialize_frames` alone |
| 19 `PushInlineFrame` costs ~21 Ir per inlined call | nirvdrum, Shopify/ruby#1023 "Virtual Inline Frames" (assigned); Shopify/ruby#1008. Not a gap against YJIT (a YJIT call is ~19 Ir plus `leave`); 92 / 33 / 76 M Ir of ZJIT code |
| 11 attr_reader/getivar on shape-polymorphic receivers without a shape profile | tekknolagi: ruby/ruby#18616 (open draft, "Seed polymorphic type branches with shape data too") branches on every profiled shape of an arm's class, which is what remains after his ruby/ruby#19443 (open, approved; one shape per class). Shopify/ruby#1039 rows 77/78 (unassigned) port the same fix on k0kubun's branch. Found 2026-11-03 in the [lead 11 follow-up](zjit-yjit-gap.md#lead-11-why-there-is-no-profile). Gap: 12.4 / 30.8 / 83.9 M Ir; about 11 / 24 / 59 M remain after #19443 |
| 12 cfunc calls with a frame (40 Ir per call against YJIT's 30) | k0kubun: Shopify/ruby#1030 (assigned) links a "send_cfunc_block" patch series. It contains `5a370e8571` "Don't spill consumed receiver and args on C calls with a frame", `9e4bb54cb6` "Don't move SP/CFP registers around C calls with a frame", and fixes for result moves, local respills and the `cfp->sp` lea. Found 2026-11-03 during the lead 14 check; this replaces the parked "waits for ruby/ruby#18960" and "free, owner must confirm" statuses. Gap: 22.7 / 10.3 / 14.4 M Ir |
| 14a/14b `&block` param passed to a C method (`fetch_header`, `each_value(&block)`, `bsearch_index(&block)`) and `(*args, &block)` passed to an ISEQ (`render` → `_normalize_render` → `_normalize_args`) | Waits for #1039 row 7 (k0kubun): both need its block-param-proxy reduction. Row 42 (`fd713176a1`, unassigned) is the C-call follow-up. Gap: 5.3 / 0.7 / 0.1 M Ir |
| 15c a stale shape list in a final version (`@ivar` reads on shapes not seen when the method was first profiled) | Version policy is k0kubun's Shopify/ruby#1031 "Adaptive Compilation" (assigned). The per-name shape table behind shape-chain misses is Shopify/ruby#1039 row 6 (tekknolagi). Rows 9, 10 and 52 (no assignee) re-learn shapes in final versions. ruby/ruby#19617 (k0kubun, open) leaves it unchanged (measured). Gap: ~0 / ~2.8 / ~4.2 M Ir |

**Free, ranked**

Ranked since 2026-11-03 by the measured ZJIT − YJIT instruction gap on ruby-bench ([zjit-yjit-gap](zjit-yjit-gap.md),
master `a8b095a07e`, Callgrind, three runs per mode), not by fallback counts; the count-based ranking is in git
history. "Gap" is M Ir per iteration, railsbench / lobsters / shipit, and in brackets the share of that benchmark's
gap (+184 / +179 / +619 M). Fallback-driven sizes are extra generic calls against YJIT at the same ISEQ times an
average price per call, so they are estimates.

| rank | lead | gap (M Ir) | apps (census, per op) | why this rank |
|---|---|---|---|---|
| 1 | 3 class-polymorphic sends to one method entry: class-level methods on model classes (`attribute_types` in `_load_from_sql`, `current_shard`/`current_role`, `_reflections`) and instance-level `self` attr_readers shared by many subclasses (`Type::Value#hash`/`#cast`, `association`) | 7.2 / 42.1 / 180.1 (4% / 24% / 29%) | 10, 325 | Largest free item on lobsters and shipit. Shopify/ruby#1099 item 2, no assignee. Includes lead 2's 6.6 M on shipit. **Built, candidate only, not to be opened** (no new ruby/ruby PRs for now): two commits at `23273fd8ec`, see [Lead 3](#lead-3-our-build-and-its-numbers-2026-11-03). |
| 2 | 13 `rb_zjit_root_mark` marks every JITFrame's ISEQ on every GC | 25.4 / 6.7 / 37.1 (14% / 4% / 6%) | unmeasured | No issue or PR. Small, self-contained. Scales with GC count and JITFrames (38k / 150k / 119k). |
| 3 | 15a an `attr_reader` call in a final version (`no_side_exits`) gives up and calls `rb_ivar_get`, even on a known shape (`block in fetch_value` → `values`/`types`, `stale_state` → `reflection`, `type_for_attribute` → `type_caster`/`klass`) | measured: 0.8 / 4.5 / 22.0 in `rb_ivar_get` (estimate was 0.9 / 3.1 / 17.9) | – | **Candidate built, not opened** (no new ruby/ruby PRs, DECISIONS 10cef95): see [Lead 15a: our candidate build](#lead-15a-our-candidate-build-and-its-numbers-2026-11-03). Exact and small: give it the shape branch that an `@ivar` read already gets in a final version (`dispatch_getivar`), with `rb_ivar_get` as the miss path. Part of Shopify/ruby#1039 row 78 (no assignee); take only that piece, because the rest of row 78 is lead 11 (taken). See [zjit-yjit-gap, Lead 15](zjit-yjit-gap.md#lead-15-ivar-reads-in-final-versions-and-on-singleton-objects). |
| 4 | 14c ISEQ callees with `**rest`, including `def m(a, ...)` (`Relation.create(self)` → `def create(model, ...)`, `AssociationRelation#initialize(klass, association, **)`) | 0.7 / 1.0 / 5.1 | –, 21.5k `complex_arg_pass_param_kwrest` per shipit iteration | Measured +314 to +405 Ir per call against YJIT. Shopify/ruby#1039 rows 36 (`2ac995c680`) and 43 (`29903d645e`) have no assignee, and there is no PR or issue. Medium: keyword planning plus the callee's hidden `kw_bits` argument. See [Lead 14](zjit-yjit-gap.md#lead-14-what-one_or_more_complex_arg_pass-really-costs). |
| 5 | 15b an `@ivar` read on a singleton object (Rails' `extend`ed logger: `Logger#level`/`level_override`, TaggedLogging `tag_stack`). The profiler records such objects as "other" (ruby/ruby#19540), so these methods use up their versions and read generically | 4.6 / 0.4 / 0.7 | – | Record the shape, without the class, for ivar instructions. Medium, and it changes the profiling policy of k0kubun's #19540, so it needs his agreement. Under the issue rule we don't ask in an issue, so it is parked. Shopify/ruby#1099 pattern 3, no assignee. |
| 6 | 2 `BasicObject#!=` (polymorphic inner `==`) | 0 / ~1 / 6.6 (in lead 3's total) | 10, 277 | Rides on lead 3 or general polymorphic-send work. |
| 7 | 14d a `nil` `&blk` passed to a C method (HWIA `update_with_single_argument` → `regular_update(other_hash, &block)`) | 0.8 / 0.04 / 0.03 | – | Exact: guard and strip, as the ISEQ path already does. A few lines; part of #1039 row 42 (unassigned). Saves about 210 Ir per call. |
| 8 | 10 `singleton_class_seen` for module receivers (`IndexedRow::Mutable#fetch` → `UNSET.equal?`) | 0 / 0.2 / 0.1 | 6, 431 | Matters on Rails main (lobsters census 1,220 per op), not on ruby-bench's Rails 8.1. Builds on linyiru's open ruby/ruby#19658. Small. |
| 9 | 16 PatchPoint nop padding executed inline | 31.7 / 14.0 / 27.9 Ir of nops | unmeasured | Ir overstates it: nops are cheap in cycles. Measure cycles before acting. |
| 10 | 18 `with_vm_lock` → `rb_gc_disable()` → `gc_rest()` on every invalidation, e.g. each `extend` (297 per shipit iteration) | Ir-neutral (moves 114 M of shipit GC into the call) | unmeasured | Wall-time and pause effect only, unmeasured. The comment in zjit/src/cruby.rs explains why GC must be off under the lock, so a change needs care. |
| new | 20 literal `super { … }`: every `super` with its own block stays a dynamic send (`send_fallback_super_call_with_block`); hir.rs has the TODO "pass Option<blockiseq> to build_send_direct_args when we start specializing `super { ... }`" | unmeasured | unmeasured | 4.0k / 0.4k / 1.9k | Found while building lead 8 (counts from master a8b095a07e, `--zjit-stats` with 512/1024 MiB, 0 OOM, 10 warmup + 10 measured iterations). Sites not identified yet. No issue and no open ruby/ruby PR; not checked against Shopify/ruby#1039's rows. Free. |
| new | 8b pass the frame's block to the super callee instead of the dynamic super that the lead 8 fix uses for these sites | unmeasured | unmeasured | 2.1k / 0.3k / 0.06k sites become direct sends | A measurement prototype ([thomasklemm/ruby `zjit-super-block-pass`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-super-block-pass)) adds a `BlockHandler::FrameBlock` variant and doesn't inline such sends. On the Shopify/ruby#1100 repro, Ir per call is 1,090 on master, 942 with the lead 8 fix and 555 with the prototype; ruby-bench Ir per iteration stays within the A/A (railsbench ±0.07%, lobsters ±0.11%, shipit −0.21%/+0.07%; callgrind, 10 warmup + 5 measured iterations, two runs each). A cfunc super target with a block stays dynamic (about 40 per lobsters iteration). Free, follows lead 8. |

Lead 12 left the free list (k0kubun, Shopify/ruby#1030; see Taken). Lead 14 is split into 14a–14d: 14c and 14d are free and ranked, 14a/14b wait for row 7, and splat or keyword arguments to C methods are not a gap (ZJIT is already cheaper than YJIT there).
Lead 15 is split into 15a–15c (2026-11-03): 15a and 15b are ranked, and 15c is taken.
Lead 11 left the free list too: the draft ruby/ruby#18616 is an open PR for it (see Taken).
Lead 7 left the free list: it is Shopify/ruby#1039 row 7, assigned to k0kubun (see Taken). Its measured gap stays
29.4 / 25.1 / 66.0 M Ir. U3's literal-`super { }` lead is numbered 20 here, because Z13 numbered its leads 11–19.

Shopify/ruby#1039 rows per lead (2026-11-03): 10 and 2 have no row; 3 is near rows 24/25/27 and 1 near row 55,
all unassigned; 7b is row 7's `split_nil_block_arg` (k0kubun, taken); 7c has no row (rows 19 and 45 are other
mechanisms, unassigned); 7d is row 44 (unassigned).

Not built yet; the ruby/ruby PR cap (15) applies before any of these can open.

## New leads from the ZJIT-YJIT gap (2026-11-03)

From [zjit-yjit-gap.md](zjit-yjit-gap.md): Callgrind on ruby/ruby master `a8b095a07e`, railsbench / lobsters /
shipit, ZJIT (`--zjit-exec-mem-size=512 --zjit-mem-size=1024`, 0 `compile_error_out_of_memory`) against YJIT on the
same build. Sizes are M Ir per iteration and the share of each benchmark's gap (+184 / +179 / +619 M). Status was
checked on 2026-11-03 against assignees, the 67 open ruby/ruby PRs with "ZJIT" in the title, and searches of
Shopify/ruby issues and ruby/ruby PRs (`CCallWithFrame`, `cfunc frame`, `root_mark`, `JITFrame`, `materialize`,
`PatchPointPad`, `entry trampoline`, `rb_ivar_get`, `attr_reader shape`). Nothing is posted.

### 11. Shape-polymorphic attr_reader/getivar without a shape profile

* **Fallback:** `getivar_fallback_no_profile_missing_ic`. An `attr_reader` send (or an inlined one) whose receiver
  has no shape profile becomes `GetIvar` without an IC → `rb_ivar_get` → shape-tree lookup (`rb_ivar_lookup`,
  `rb_shape_get_iv_index`), about 120–131 Ir per call. At the same ISEQs YJIT guards up to 5 shapes and reads the
  slot, or calls `rb_ivar_get_at_no_ractor_check` with the index (about 53 Ir).
* **Sites:** implicit-self readers in methods that many subclasses or shapes share:
  * `Arel::Collectors::Composite#<<` (`left << str`): 105k per iteration on shipit, 29k on lobsters;
  * `Association#klass` (`reflection.klass`): 64k on shipit;
  * `ActiveModel::Attribute#hash`/`#==` (`name`, `type`): 48k/39k;
  * `Type::Value#hash`/`#==` (`precision`, `scale`, `limit`);
  * `WhereClause#empty?`;
  * `block in fetch_value`;
  * Action Pack `url_options` and `cookies#request` (railsbench).
* **Size:** 218k / 303k / 706k extra reads per iteration, about **12.4 / 30.8 / 83.9 M Ir (7% / 17% / 14%)**.
* **Repro:** Shopify/ruby#1099, pattern 1 (`Box#v` with two shapes of one class).
* **Status:** taken (2026-11-03 follow-up). ruby/ruby#19443 (tekknolagi, open, approved) handles the
  class-polymorphic case with exactly one shape per class; tekknolagi's draft ruby/ruby#18616 handles several
  shapes per class, and Shopify/ruby#1039 rows 77/78 port the same fix. Shopify/ruby#1099 has no assignee. Our
  ruby/ruby#19558 covers sends, not getivar.
* **Cause, fix and #19443's measured effect:** [zjit-yjit-gap, Lead 11](zjit-yjit-gap.md#lead-11-why-there-is-no-profile).

### 12. cfunc calls with a frame

* **JIT code per call** (perf map `--zjit-perf=hir` against `--yjit-perf=codegen`; counts from stats):
  * ZJIT: `CCallWithFrame` + `CCallVariadic` cost 40.7 / 40.7 / 39.0 Ir per call;
  * YJIT: `gen_send_cfunc` + its `gen_push_frame` cost 17.7 / 17.8 / 17.9 Ir.

  There are 2.1 / 1.0 / 1.7 M such calls per iteration.
* **Size (first estimate, superseded below):** about 48 / 22 / 35 M Ir (26% / 12% / 6%). YJIT charges some send setup to the per-instruction range
  (`opt_send_without_block`, `jit_guard_known_klass`), and ZJIT charges the matching work to `GuardType` and
  `PatchPoint`, so this is an upper bound.
* **Correction (2026-11-03 follow-up):** YJIT's 17.7 Ir left out its call tail, which YJIT charges to
  `opt_send_without_block`. Over the whole sequence YJIT costs 29.9 / 30.1 / 30.3 Ir, so the difference is
  +10.8 / +10.6 / +8.7 Ir per call and the size is **22.7 / 10.3 / 14.4 M Ir** per iteration.
* **Mechanism** (disassembly plus per-instruction Callgrind counts on every executed site):
  * caller-saved push/pop: +4.8–6.0 Ir per call;
  * spills: +2.8–3.7 Ir, of which 2.2–2.3 are dead receiver/argument stores;
  * the SP/CFP register switch: 4.0 Ir;
  * `argv` copied to the C stack: +1 Ir;
  * the caller's `cfp->sp` store: +1.3 Ir;
  * offset by YJIT's interrupt check: −3.2 Ir.
* **Status (corrected 2026-11-03): taken.** k0kubun's Shopify/ruby#1030 "send_cfunc_block" series has both fixes
  (`5a370e8571`, `9e4bb54cb6`) and more. The bullets below are the first check.
* **Status at first check:**
  * Free: the dead-store fix (4.9 / 2.2 / 3.7 M) and the register switch (6.3 / 2.9 / 5.0 M). Neither has an issue,
    PR or #1039 row. The dead-store fix sits on lines that ruby/ruby#18960 (XrXr) rewrites.
  * Taken: locals spill, by #18960.
  * Tracked as unassigned #1039 rows: callee-saved registers (row 58) and the `cfp->sp` store (row 69).
  * Details: [zjit-yjit-gap, Lead 12](zjit-yjit-gap.md#lead-12-what-a-cfunc-call-with-a-frame-costs).

### 13. JITFrame root marking on every GC

* **Mechanism:** `rb_zjit_root_mark` (zjit/src/gc.rs) calls `rb_gc_mark_movable` on the ISEQ of every JITFrame on
  every GC, minor ones too. The process has 38,119 / 150,144 / 119,011 JITFrames, one per call site and frame
  state, so most ISEQ pointers repeat.
* **Cost:** 28.5 / 7.0 / 39.3 M Ir per iteration inclusive, against YJIT's root marking at 3.1 / 0.3 / 2.2.
* **Size:** **25.4 / 6.7 / 37.1 M Ir (14% / 4% / 6%)**.
* **Shape of a fix:** mark each distinct ISEQ once, for example from a set filled in `JITFrame::alloc`, while
  keeping `update_references`.
* **Status:** free, no issue or PR.

### 14. `&block` passed to a C method, and other complex argument passing

* **Fallback:** `send_fallback_one_or_more_complex_arg_pass`.
* **Size:** first estimated at 19.5 / 6.1 / 13.1 M Ir, using the average generic-send price. Measured per shape on
  2026-11-03, it is **6.8 / 1.8 / 5.3 M Ir**.
* **Parts:**
  * **14a:** the `&block` param passed to a C method, +66 Ir per call. `fetch_header`, `each_pool_config`,
    tzinfo `bsearch_index`. Waits for row 7.
  * **14b:** `(*args, &block)` passed to an ISEQ, +285 Ir per call. `render`, `_normalize_render`, `process`, HWIA
    `merge`. Waits for row 7.
  * **14c:** ISEQ callees with `**rest` or `(a, ...)`, +314 to +405 Ir per call. Free: #1039 rows 36 and 43.
  * **14d:** a `nil` `&blk` passed to a C method, +129 Ir per call. Free, exact, tiny.
  * Splat or keyword arguments to C methods: ZJIT is cheaper than YJIT there (−328 and −73 Ir per call).
* **Details:** [zjit-yjit-gap, Lead 14](zjit-yjit-gap.md#lead-14-what-one_or_more_complex_arg_pass-really-costs).

### 15. getivar on final versions and long-lived singleton objects

* **Fallback:** `getivar_fallback_no_side_exits`.
* **Split:** the stats split it exactly into two kinds of read, per iteration (railsbench / lobsters / shipit):
  * `attr_reader` calls in final versions that call `rb_ivar_get`: 8.0k / 28.6k / 163.0k;
  * `@ivar` reads in final versions that call `rb_vm_getinstancevariable`: 65.9k / 125.0k / 247.7k.
* **Size against YJIT:** ~5.5 / ~6.3 / ~22.8 M Ir. The first estimate was 3.9 / 7.8 / 24.0.
* **Parts:**
  * **15a**, an attr_reader in a final version: 0.9 / 3.1 / 17.9. Free, small, exact.
  * **15b**, singleton objects: 4.6 / 0.4 / 0.7. Needs k0kubun's agreement; parked.
  * **15c**, stale shapes in final versions: ~0 / ~2.8 / ~4.2. Taken.
* **ruby/ruby#19617:** measured on top of master, it does not reduce the counter (shipit 410.8k → 423.5k).
* **Details:** [zjit-yjit-gap, Lead 15](zjit-yjit-gap.md#lead-15-ivar-reads-in-final-versions-and-on-singleton-objects).

### 16. PatchPoint nop padding

* **Cost:** `patch_point_pad` puts multi-byte nops on the hot path when patch points sit close together. They are
  31.7 / 14.0 / 27.9 M executed instructions per iteration, 0.6–0.7% of ZJIT's Ir.
* **Caveat:** nops are cheap in cycles, so Callgrind overstates them. Measure cycles before acting.
* **Status:** free.

### 17. `throw` unwinding and frame materialization: taken

`break`/`next`/`return` from blocks run `rb_zjit_throw` → longjmp. The tag jumps total 56k / 20k / 22k per
iteration, against YJIT's 1.3k / 1.0k / 5.9k. Each one walks and materializes ZJIT frames: 15.6 / 5.3 / 13.2 M Ir.

* **Sites:**
  * Journey `#evaluate` block (visitors.rb:42);
  * `PathSet#find_all` block;
  * `Router#serve` block;
  * `SQLite3::Statement#each` block;
  * `Formatter#generate` blocks;
  * TZInfo `periods_for_local`.
* **Taken:** Shopify/ruby#1093 (k0kubun), ruby/ruby#18244 (luke-gruber, draft) and, for exception-handler exits,
  ruby/ruby#18759 (rafaelfranca).

### 18. `with_vm_lock` finishes the incremental GC

* **Mechanism:** `with_vm_lock` calls `rb_gc_disable()`, which runs `gc_rest()`. Every invalidation pays this,
  including `rb_zjit_invalidate_no_singleton_class` on each `extend` (297 per shipit iteration).
* **Effect:** 114 M Ir of shipit's GC work per iteration runs inside those calls. The Ir is the same; the work moves
  from incremental steps into a pause. Wall time is unmeasured.
* **Status:** free. The comment explains why GC must be off while ZJIT holds the lock, so a change needs care.

### 19. `PushInlineFrame` cost: taken

An inlined ISEQ call costs 21–22 Ir in `PushInlineFrame` + `PopInlineFrame`: 92 / 33 / 76 M Ir per iteration. That
is not a gap against YJIT, where a full call costs about 19 Ir plus `leave`. Taken: Shopify/ruby#1023 (nirvdrum,
Virtual Inline Frames); see also Shopify/ruby#1008 and #1070.

### 20. Over-broad method-entry invalidation: parked

Found in the `Kernel#dup` work ([zjit-cfunc-paths](zjit-cfunc-paths.md#why-an-unrelated-include-invalidates-hashs-patch-point)).

* **Mechanism:** an `include`, `extend` or `def` clears the method cache for each method name at the changed class's
  superclass. If that lookup reaches a method inherited from a module, such as `Kernel#initialize_dup` or
  `Kernel#respond_to?`, CRuby invalidates the one method entry that every inheriting class shares. ZJIT keys its
  `MethodRedefined` patch points by that entry, so it patches all of them, even on receiver classes whose lookup
  did not change. Once a site has used its 4 versions, the final version exits on every call.
* **Size:** 95–97% of the invalidated patch points guard a class that could not see the change (railsbench 397 of
  411, lobsters 575 of 593, shipit 698 of 734). On master this costs lobsters 382 exits per iteration and no
  measurable Ir. With a Ruby-level `dup` it costs 3.6k–3.8k exits per iteration, and an unsound oracle that keeps
  the unaffected patch points saves 0.31% (lobsters) and 1.35% (shipit) Ir.
* **Exact fix:** CRuby would tell the JITs which class changed, or call a hook once the change is complete. ZJIT and
  YJIT would then re-resolve each kept patch point's method, keep it only if the definition and defined class are
  unchanged, and re-key it to the new entry. That is a cross-cutting change to CRuby's method cache.
* **Status:** parked (Thomas, 2026-11-03): no new ruby/ruby PRs, and this is a CRuby method-cache change we can't
  stand behind yet. Unowned. The closest work treats the symptom: ruby/ruby#19617 (k0kubun, open) lets invalidated
  final versions recompile, and row 19 of Shopify/ruby#1039 ("Let invalidated ISEQs recompile instead of exiting
  forever") has no assignee.

## New leads from Rails PR work (2026-11-03)

Found while measuring open Rails PRs ([rails-open-evidence.md](rails-open-evidence.md)), Ruby master `9aa0898240`
`--zjit`, Callgrind Ir per call with an A/A. Not from `--zjit-stats-iseq`; nothing posted.

| lead | fallback / exit | repro or site | counts | status |
|---|---|---|---|---|
| A `Hash.new(capacity:)` | `opt_new` is not specialized for `Hash` under ZJIT, so ruby/ruby#19537's capacity fast path is skipped and the call allocates 2 transient Hashes | `Hash.new(capacity: 6)`: 3 objects per call under `--zjit`, 1 in the interpreter. Site: rails/rails#59557 `Array#index_with` | `index_with`, 3 Strings: +45.8% Ir against `to_h` (A/A 0.07%); `serializable_hash` with 4 attributes +11.3%; 8 Strings +16.1% | Taken: ruby/ruby#19662 (ours, open). Remeasure #59557 once it lands |
| B direct association scope build | unknown: not measured with stats | `post.association(:comments).scope` after `reset_scope` ([`cpu_open.rb`](../../bench/upstream/rails-open/cpu_open.rb) `scope_hm`). rails/rails#59569 skips building the `AliasTracker` there | saves 8.3% Ir in the 4.0.7 interpreter and 6.1% under YJIT, +0.1% under ZJIT (that mode's A/A is 1.31%); ZJIT wall time −10% | Free, **unmeasured**: the ZJIT Ir may simply be noisy here, or the tracker path is already cheap or not compiled. Next step: `--zjit-stats-iseq` on `scope_hm` |

Checked and not a ZJIT lead: a 2-local partial render allocates 35 objects on master in both the interpreter and
ZJIT, against 33 on 4.0.7, so the extra 2 come from master, not ZJIT.

## New leads from the lead 7 build (2026-11-03)

Found while building lead 7 (thomasklemm/ruby `thomasklemm/zjit-forward-block-param` @ `ab21c5458b`, on master
`a8b095a07e`). ruby-bench per iteration, 15 warmup + 10 measured, 0 `compile_error_out_of_memory`. Nothing posted.

| lead | fallback / exit | repro or site | counts | status |
|---|---|---|---|---|
| 7b `&block` forwarding at sites that see both nil and the proxy | `send_fallback_send_block_arg_not_nil` | `_read_attribute(name, &block)` (activerecord 8.1.1 read.rb:39), called with and without a block; `def ra(n, &b) = inner(n, &b)` called both ways | after lead 7: lobsters 72.6k, shipit 95.0k per itr left (railsbench 50.9k, sites not traced). Rails main removed this block, so app counts are smaller | Patch shape: branch on nil vs. proxy instead of a guard (`split_nil_block_arg` in k0kubun's `93e4e7d69c`, Shopify/ruby#1039 row 7, **assigned to k0kubun**). Taken (row 7 assignee counts as a claim, DECISIONS 2fa718c) |
| 7c recompiling guards on skewed profiles keep exiting | side exits of a `recompile` guard after the version budget is spent | First draft of lead 7 guarded the proxy also on `SkewedPolymorphic` profiles: lobsters 8,902 and shipit 7,859 `exit_block_arg_not_block_param_proxy` per itr, all in `_read_attribute` (traced) | the shipped version guards only monomorphic profiles: 0 / 77 per itr | Free, **unmeasured** in general: whether other skewed `GuardType`/`GuardBitEquals ... recompile` sites behave the same on the apps. Related to ruby/ruby#19617 (k0kubun, PatchPoint only) |
| 7d inline callees that receive the forwarded block handler | none (missed inlining, not a fallback) | `SendDirect ..., &vN` with `BlockParamProxy` is not inlined; `mon_synchronize(&b)` → `Monitor#synchronize` | **unmeasured** | Free: Shopify/ruby#1039 row 44 (`e89844f878`, unassigned) |

## Lead 7: our unopened build and its numbers (2026-11-03)

Taken (Shopify/ruby#1039 row 7, k0kubun); kept for reference, no PR and no comment. thomasklemm/ruby
[`thomasklemm/zjit-forward-block-param`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-forward-block-param)
@ `ab21c5458b`, one commit on master `a8b095a07e`, +124/−16 in 6 files (production code about +35 lines).

**What it does.** When a `foo(&b)` block argument profiles **monomorphically** as `rb_block_param_proxy`, it adds
`GuardBitEquals proxy` (recompile; new exit `block_arg_not_block_param_proxy`), loads the LEP's specval and passes it
as a new `BlockHandler::BlockParamProxy` to `SendDirect`. This is what `vm_caller_setup_arg_block` does for the proxy.
The inliner skips such sends. Smaller than k0kubun's `93e4e7d69c`: no nil/proxy branch split, no inlining.

**Skewed-profile finding (lead 7c).** A first draft also guarded `SkewedPolymorphic` profiles. In
`_read_attribute(name, &block)` (activerecord 8.1.1 read.rb:39), which sees both nil and the proxy, the guard exited
after the recompile budget was spent: `exit_block_arg_not_block_param_proxy` 8,902 (lobsters) and 7,859 (shipit) per
iteration, all at that site (traced with `--zjit-trace-exits`). Restricting it to monomorphic profiles brought this
to 0 and 77. Side exits are otherwise unchanged.

**Fallbacks**, ruby-bench `73918b2`, per iteration, 15 warmup + 10 measured, `--zjit-stats-quiet`, 0
`compile_error_out_of_memory`:

| | `send_block_arg_not_nil` | `dynamic_send_count` |
|---|---:|---:|
| railsbench | 120,000 → 50,850 | 1,065,952 → 996,802 |
| lobsters | 95,135 → 72,593 | 750,337 → 728,762 |
| shipit | 201,312 → 95,008 | 1,709,368 → 1,604,077 |

What remains on lobsters is mostly `_read_attribute` (lead 7b). Census apps were not rerun.

**Callgrind**, Ir per iteration with GC (15 warmup, 3 measured, `ruby_bench_callgrind.rb`):

| | master | branch |
|---|---:|---:|
| railsbench | 4,936.7 / 4,938.3 M | 4,901.6 / 4,908.0 M (−0.67%) |
| lobsters | 3,271.6 / 3,298.0 M | 3,262.1 / 3,260.5 M (−0.3% to −1.1%; master A/A 0.8%) |
| shipit | 3,954–4,040 M (4 runs) | 3,896–3,985 M (4 runs): within noise, both builds bimodal |

Lobsters runs must not share a checkout concurrently: two parallel runs raced on `tmp/cache` (`Errno::ENOENT` in
`rename`) and were rerun in sequence.

**Per call** (Callgrind, `--zjit`, 100k calls, A/A identical): `def fwd(&b) = callee(&b)` with `def callee = yield`
1,003 → 748 Ir; `def mon(&b) = M.synchronize(&b)` with a Monitor 1,947 → 1,418 Ir.

**Checks:**
- `make zjit-test`: 1943/1943 pass.
- btest at `--zjit-call-threshold=1`: 2141/2141 pass.
- test-all at threshold 1 (proc, method, yield, iterator, refinement, settracefunc, call, lambda, enumerator, syntax,
  monitor, thread_queue, zjit_cli): 1036 tests, 0 failures.
- A differential script (block identity, `lambda?`, Method objects, Symbol and nil blocks, reassigned block params,
  nested blocks, Monitor/Mutex, break/return/raise, Enumerable, refinements, TracePoint) matches the interpreter at
  thresholds 1, 2 and 5.

`test/ruby/test_zjit.rb` no longer exists on master (ported to `zjit/src/codegen_tests.rs`; the rest is
`test_zjit_cli.rb`). Only the three updated HIR snapshots fail without the change.

## Lead 15a: our candidate build and its numbers (2026-11-03)

A finished candidate, recorded here and not opened (DECISIONS 10cef95: no new ruby/ruby PRs for now). thomasklemm/ruby
[`thomasklemm/zjit-final-attr-reader-shape`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-final-attr-reader-shape)
@ [`a0dd4a08af`](https://github.com/thomasklemm/ruby/commit/a0dd4a08af762c43ae6affe0f947175439d9cf3a), one commit on
master `9b30fd207f`, 3 files, +116/−5 (production code +19/−5 in `zjit/src/hir.rs`).

**What it does.** In `type_specialize`, an attr_reader send whose receiver has a profiled shape used to emit a
generic `GetIvar` in a final version, because `try_emit_optimized_getivar` refuses to guard there. It now calls
`dispatch_getivar` with that one shape, the same helper `getinstancevariable` uses in a final version: compare the
shape, load the field on a match, and call `rb_ivar_get` otherwise. The block continues in the join block. The class
guard and the `MethodRedefined` patch point are unchanged. This is only the final-version piece of Shopify/ruby#1039
row 78 (`4857dd0ef5`, unassigned); nothing from lead 11 (polymorphic arms) and nothing for setivar.

**Ownership, rechecked 2026-11-03 20:50Z.** Row 78 has no assignee. Open ruby/ruby ZJIT PRs about ivars or shapes:
#19443 and #18616 (tekknolagi, polymorphic arms), #18249 (tekknolagi, draft since 2026-08-07, merges identical shape
arms inside the ivar dispatch), #17865 (RData setivar), #19617 (k0kubun, recompiling final versions) and our #19558
(polymorphic send misses in non-final versions). None of them touches the attr_reader branch for final versions.
#18249 and #19558 no longer apply cleanly to master, with or without this commit.

**Counters**, ruby-bench `73918b2`, per iteration, 15 warmup and 10 measured, `--zjit --zjit-stats-quiet
--zjit-exec-mem-size=512 --zjit-mem-size=1024`. `compile_error_out_of_memory` and `failed_iseq_count` were 0 before
the reset and at the end in all six runs.

| per iteration | master `9b30fd207f` | branch |
|---|---:|---:|
| `getivar_fallback_no_side_exits` railsbench / lobsters / shipit | 73,922 / 153,653 / 410,795 | 65,922 / 125,456 / 247,748 |
| `ccall_rb_ivar_get` | 229,098 / 351,131 / 1,001,336 | 221,098 / 323,683 / 838,289 |
| `side_exit_count` | 23,709 / 12,649 / 49,584 | 23,709 / 12,649 / 49,557 |

The drops (8,000 / 28,197 / 163,047) match lead 15's count of attr_reader reads in final versions (8.0k / 28.6k /
163.0k on `a8b095a07e`).

**Callgrind**, M Ir per iteration, GC and write barriers excluded, 10 warmup and 3 measured iterations, two runs per
build (a with `--zjit-perf=iseq`, c without), same flags without stats:

| | master a / c | branch a / c | Δ of the means | `rb_ivar_get` inclusive, both runs |
|---|---|---|---:|---:|
| railsbench | 4,724.75 / 4,726.29 (A/A 0.03%) | 4,721.78 / 4,728.45 (A/A 0.14%) | −0.40 (−0.01%) | 31.53 → 30.70 (−0.83) |
| lobsters | 3,239.60 / 3,237.33 (A/A 0.07%) | 3,237.43 / 3,236.05 (A/A 0.04%) | −1.73 (−0.05%) | 48.71 → 44.25 (−4.46) |
| shipit | 3,675.96 / 3,676.29 (A/A 0.01%) | 3,650.74 / 3,657.56 (A/A 0.19%) | −21.97 (−0.60%) | 131.48 → 109.43 (−22.05) |

Shipit is above its A/A; railsbench and lobsters are within it, but their `rb_ivar_get` drop is the same in both runs.
Calls to `rb_ivar_get` per iteration drop by 8.0k / 28.4k / 159.3k, at 104 / 157 / 138 Ir per removed call. The
estimate (0.9 / 3.1 / 17.9) priced a call at 105–130 Ir, so it was low on lobsters and shipit. With GC included, the
branch's shipit run c had 65 M Ir more GC marking than its run a (one more major mark in the window); the other five
runs agree within 1.6 M of GC, so I compare without GC.

**Per call** (Callgrind, `--zjit --zjit-max-versions=2 --zjit-inline-threshold=0`, 20,000 iterations of
`run(o) = o.v + C` after a constant reassignment makes `run`'s next version final; release builds, A/A identical):
one-shape receiver 211 → 107 Ir per iteration; a receiver of the same class with another shape 211 → 219 Ir, the
cost of the added shape compare.

**Checks:**
- `make zjit-test`: 1941/1941 pass. The new HIR snapshot `test_inline_attr_reader_on_final_version` fails without the
  change. The new `test_attr_reader_on_final_version` (profiled shape, other shape, object without the ivar,
  redefined reader) passes with and without it, as a correctness guard.
- btest at `--zjit-call-threshold=1`: 2141/2141 pass. `test_zjit_cli.rb`: 28 tests, 0 failures.
- The test's Ruby script under `--zjit-stats`: the branch counts 2 generic reads (other shape, no ivar), master 4.

**Draft PR body (not opened):**

> When ZJIT compiles the last allowed version of an ISEQ, it may not side-exit, so a send to an `attr_reader` there
> always becomes a generic `GetIvar`, a call to `rb_ivar_get`, even when the receiver was profiled with one shape. A
> `getinstancevariable` in the same version already branches on the profiled shape and calls `rb_ivar_get` only for
> other shapes. This change gives the `attr_reader` send the same branch by calling `dispatch_getivar` with the
> profiled shape. The class guard, the method redefinition patch point and the fallback are unchanged.
>
> On ruby-bench, comparing master `9b30fd207f` with this branch (`--zjit --zjit-exec-mem-size=512
> --zjit-mem-size=1024`, 15 warmup and 10 measured iterations, no out-of-memory compile errors), generic ivar reads in
> final versions (`getivar_fallback_no_side_exits`) drop per iteration from 73,922 to 65,922 on railsbench, from
> 153,653 to 125,456 on lobsters, and from 410,795 to 247,748 on shipit. Side exits are unchanged.
>
> Under Callgrind (10 warmup and 3 measured iterations, two runs per build, GC excluded), shipit executes 22.0M fewer
> instructions per iteration than master (−0.60%), while the two runs of each build differ by at most 0.19%. On
> railsbench (−0.01%) and lobsters (−0.05%) the total change is within run-to-run noise, but the instructions spent
> in `rb_ivar_get` drop by 0.8M and 4.5M per iteration in both runs.
>
> In a microbenchmark where an `attr_reader` call in a final version sees one shape, a loop iteration executes 107
> instructions instead of 211 on master. With a receiver of another shape it executes 219 instead of 211, the cost of
> the added shape check.
>
> The attr_reader part of k0kubun's lobsters patch list (Shopify/ruby#1039, row 78) goes further, into polymorphic
> arms; this PR takes only the final-version piece.

**Short explanation for Thomas** (DECISIONS a5f8c4a):

ZJIT may compile a method only a limited number of times. When it compiles a method for the last time, that code
must not jump back to the interpreter when something unexpected happens, because nothing could recompile it
afterwards. In that last compile, a call to an `attr_reader` such as `point.x` gave up its fast path and called the
slow C lookup `rb_ivar_get` every time, even when every object it had seen had the same layout. A plain `@x` read in
the same situation already does better: it checks the object's layout, reads the slot directly when the layout
matches and otherwise calls the slow lookup. The change gives `point.x` exactly that check, so an object with another
layout still takes the old slow lookup, and redefining `x` still discards the compiled code as before.

```ruby
# ruby --zjit --zjit-call-threshold=2 --zjit-max-versions=2 example.rb
class Point
  attr_reader :x
  def initialize(x) = @x = x
end

OFFSET = 10
def shifted(point) = point.x + OFFSET

point = Point.new(1)
shifted(point); shifted(point)       # ZJIT compiles shifted
Object.send(:remove_const, :OFFSET)
OFFSET = 20                          # ...and throws that code away
shifted(point); shifted(point)       # last allowed compile of shifted
i = 0; while i < 1000; shifted(point); i += 1; end  # each point.x: rb_ivar_get before, a direct read after
```

With `--zjit-stats`, the loop's 1,000 `point.x` calls take the slow lookup 1,000 times on master `9b30fd207f` and 0
times on the branch.

## Lead 3: our build and its numbers (2026-11-03)

**Candidate only, not to be opened** (DECISIONS 10cef95: no new ruby/ruby PRs for now). thomasklemm/ruby
[`thomasklemm/zjit-method-entry-dispatch-v3`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-method-entry-dispatch-v3)
@ `23273fd8ec`, two commits on master `9b30fd207f`:

1. `59b5ddc22a` ZJIT: Recompile a super call that has no profile yet (lead 3e below). Stands alone.
2. `23273fd8ec` ZJIT: Call the shared method directly for receivers outside a polymorphic profile (lead 3).

The first review head `2c26d6e653` (one commit) stays on `thomasklemm/zjit-method-entry-dispatch`. Lead 3b is no longer
in the PR: it did not change railsbench (the same +23,922 dynamic supers with and without it), and Shopify/ruby#1039
row 46 covers the same profile shape. It is kept locally as `thomasklemm/zjit-super-profile-copy` (`24c306b98e`).

**What it does.** When every profiled receiver class of a polymorphic send resolves the same ISEQ method entry, a new
branch before the generic send checks `rb_callable_method_entry(CLASS_OF(recv), mid) == cme` and calls the entry
directly. Since the review, the branch is dropped again when its direct call can't be specialized (a `**kw` splat, for
example), and the resolved method entry is carried with the branch instead of being looked up again.

**Generic calls per iteration**, ruby-bench, master → branch, 0 `compile_error_out_of_memory`:

| | railsbench | lobsters | shipit |
|---|---:|---:|---:|
| `send_fallback_send_polymorphic_fallback` | 26,500 → 26,500 | 246,906 → 128,767 | 681,999 → 263,907 |
| `send_fallback_super_polymorphic` | 4,013 → 0 | 2,738 → 2,338 | 1,682 → 1,439 |
| `dynamic_send_count` | 1,065,952 → 1,061,939 | 750,522 → 631,545 | 1,709,365 → 1,269,447 |
| `exit_unhandled_block_arg` | 2,052 → 6,052 | 341 → 591 | 57 → 171 |

**Callgrind** (Ir per iteration in millions, GC excluded, 15 warmup + 3 measured, 4 runs each, master `9b30fd207f`):

| | master `9b30fd207f` | branch `23273fd8ec` | Δ |
|---|---|---|---:|
| railsbench | 4691.4 / 4690.6 / 4693.7 / 4686.0 (A/A range 0.16%) | 4697.3 / 4700.6 / 4697.4 / 4695.4 | **+0.15%** |
| lobsters | 3205.6 / 3206.3 / 3204.7 / 3204.0 (A/A range 0.07%) | 3195.1 / 3195.5 / 3194.2 / 3197.2 | −0.30% |
| shipit | 3668.5 / 3667.7 / 3670.5 / 3668.1 (A/A range 0.08%) | 3623.9 / 3627.3 / 3624.8 / 3622.9 | −1.20% |

Railsbench misses the bar (at or below master, or inside the A/A): the lowest branch run is 1.7M above the highest
master run.

**Railsbench.** The cost is one site: `self[name]` in `ActiveSupport::OrderedOptions#method_missing`
(ordered_options.rb:50). On master its receiver profile holds the hot `InheritableOptions` class and `#[]` is inlined.
On the branch the profile taken after a recompile holds two other option classes, so 23,922 calls per iteration take
the new check (about 117 Ir) and a direct call that is not inlined (`inline_iseq_optimized_send_count` −21,108,
`iseq_optimized_send_count` +21,120). A same-binary toggle (arm off/on in one build, 4 runs each) gives +9.8M (+0.21%)
in total; +6.8M of that is heap page initialization (`heap_page_allocate_and_initialize` and its `memset`), which
varies with GC timing under Valgrind (outside Valgrind both modes allocate about two pages per iteration for the same
1.73M objects). Without heap page initialization the toggle difference is +2.6M (+0.06%), inside the A/A range.

**Per call** (Ir): 36 subclasses 565.6 → 290.9; class method calling a class method 987.4 → 474.2; monomorphic
132.0 unchanged; `super` that first runs after profiling 614.0 → 173.0; `**kw` splat (no branch) 1,303.4 → 1,303.4;
worst case (profile shares one method, run-time receivers override it) 632.0 → 774.0.

**Checks:** `make zjit-test` 1945/1946 (the miss is `test_profile_frames_during_direct_jit_to_jit_entry`, which fails
only under load and passes 3/3 alone); btest at threshold 1 2141/2141; test-all at threshold 1 (method, module,
class, refinement, super, alias, object, call, eval, zjit_cli, settracefunc, keyword, iterator, gc_compact) 1104
tests, 0 failures; the 14-scenario differential and a `super` differential (redefined target, prepend, implicit block,
module includer) match the interpreter at four threshold/profile settings; railsbench responses are identical.
New tests fail without the change where a wrong variant is observable: the `**kw` HIR snapshot, the shared-entry
snapshot and counter tests, and the late `super` test (polymorphic super fallbacks 20 → 21). Two wrong variants could
not be made to fail: dropping the branch's `MethodRedefined` patch point (a visibility change keeps the method entry
but the method cache clear copies it, so the run-time check already fails), and embedding the method entry untracked
by GC (compaction did not move it in the test).

## New leads from the lead 3 build (2026-11-03)

| lead | fallback / exit | repro or site | counts | status |
|---|---|---|---|---|
| 3b `super` after a method-entry copy | `send_fallback_super_polymorphic` | Profile `super` in `OO#[]`, then `Sub.class_eval { def [](k) = super }` with `SubSub < Sub` copies `OO#[]`'s entry; the super profile then holds two entries for one method and never specializes (0 → 10,000 per 10,000 calls on master) | not the railsbench cause after all (3e is); app counts **unmeasured** | Overlaps Shopify/ruby#1039 row 46 (`6f1119a5f1`, unassigned; dispatches polymorphic `super` on the frame's method entry). Our fix kept locally as `thomasklemm/zjit-super-profile-copy` (`24c306b98e`), not in the lead 3 candidate |
| 3e `super` without a profile | `send_fallback_super_polymorphic` (mislabeled; the profile is empty) | A `super` that does not run while its method is profiled, or sits in a method inlined before it was profiled: `def get(k, flag) = flag ? super(k) : k`, profile with `flag = false`, then call with `true` (10,000 of 10,000 calls dynamic on master). Sites: `OrderedOptions#[]` (ordered_options.rb:42) inlined into `method_missing`, actionview `PreloadCollectionIterator#each_with_info` (collection_renderer.rb:92) | railsbench 4,013 → 0, lobsters 2,738 → 2,338, shipit 1,682 → 1,439 per itr; 614 → 173 Ir per call | Ours: first commit of the lead 3 candidate. Not on k0kubun's `zjit-lobsters7` branch; no #1039 row |
| 3f `super` that forwards a block | `exit_unhandled_block_arg` (side exit on every call, no recompile) | A specialized `super` guards that the caller passed no block; a method always called with a block exits on every call. Site: actionview `PreloadCollectionIterator#each_with_info` `super` (collection_renderer.rb:92), which 3e now specializes | railsbench 2,052 per itr on master, 6,052 with 3e; Ir **unmeasured** | Overlaps Shopify/ruby#1039 row 45 (`7b373cdb14`, unassigned; recompiles on this guard and then dispatches dynamically) |
| 3g profile timing at a shared-entry site | none (direct call instead of an inlined profiled branch) | `self[name]` in `OrderedOptions#method_missing` (ordered_options.rb:50): the profile taken after a recompile misses the hot `InheritableOptions`, so lead 3's check plus a non-inlined direct call replaces master's inlined branch | 23,922 calls per railsbench itr, about +0.06% to +0.16% Ir | Ours, part of lead 3; a fix would inline the shared-entry call or re-profile the site |
| 3c failed method-entry check | none (extra C call before a fallback) | lead 3 when run-time receivers resolve another entry than the profile's shared one | +142 Ir per call in the worst-case micro; **unmeasured** on apps | Ours, part of lead 3 |
| 3d megamorphic sites with one method entry | `send_fallback_send_megamorphic` | lead 3 only covers polymorphic summaries; `connection_specification_name` (`superclass`/`==`, 34 singleton classes, 1 method) | 27 per op in 6 apps (zjit-polymorphism.md) | Free: Shopify/ruby#1039 rows 24/25/27 (unassigned) |

## Lead 10: the receiver class

The fallback is the `UNSET.equal?(value)` send. The lobsters HIR dump shows
`Send v70, :equal?, v331 # SendFallbackReason: Singleton class previously created for receiver class`, where
`v70` is the `UNSET` constant (behind `StableConstantNames(UNSET)`).

* **`UNSET` itself has no singleton class.** Checked in the lobsters census process with an `at_exit` hook:
  no singleton class attached to it, and no singleton methods.
* **The receiver class is plain `Module`.** By the end of the run, 686 plain `Module` instances in that process
  have a singleton class. `make_singleton_class` (class.c) invalidates `NoSingletonClass(Module)` whenever any of
  them gets one.
* **Once an ISEQ was invalidated for that and `Module` has a singleton-class record**
  (`assume_no_singleton_classes`, hir.rs:3662), every recompile sends to *any* module receiver dynamically.
* **Standalone repro on `9aa0898240`:** 10,000 `singleton_class_seen` fallbacks in 10,000 calls.

```ruby
U = Module.new.freeze
def f(v) = U.equal?(v)
def mk = (m = Module.new; def m.helper = 1)
5.times { 1000.times { f(1) }; mk }          # modules get singleton classes after f is compiled
def run(n) = (i = 0; while i < n; f(i); i += 1; end)
run(100)
RubyVM::ZJIT.reset_stats!; run(10_000)
p RubyVM::ZJIT.stats[:send_fallback_singleton_class_seen]   # => 10000
```

**Variants.** A single creation after compile doesn't trigger it: ZJIT recompiles with the patch point again.
Creations before the first compile don't trigger it either.

**Mechanism vs. linyiru's PRs.** This is the mechanism of ruby/ruby#19658/#19669 (Mastodon's per-request
`def env.http_accept_language` on `Hash`), with `Module` as the class. Rails apps keep giving `Module` instances
singleton classes after boot. Which Rails code does it during requests isn't traced. #19669's approach (guard the
receiver's class instead of a dynamic send) would cover a constant receiver like `UNSET` trivially, since its
class is known.

## Draft: Shopify/ruby issue for lead 8 (not posted)

**Title:** ZJIT: `super` in a method that received a block side-exits on every call

> `super` (explicit or zsuper) inside a method that was called with a block side-exits on every call and never
> recompiles. The specialized `invokesuper` guards that the frame's block handler is `VM_BLOCK_HANDLER_NONE`
> (`SideExitReason::UnhandledBlockArg`, zjit/src/hir.rs:5652 on master 9aa0898240), and that guard has
> `recompile: None`.
>
> ```ruby
> class C; def fetch_or_store(k) = (yield k); end
> class D < C; def fetch_or_store(k) = super(k.nil? ? 0 : k); end   # zsuper behaves the same
> O = D.new
> def run(n) = n.times { |i| O.fetch_or_store(i) { _1 } }
> run(1000); RubyVM::ZJIT.reset_stats!; run(10_000)
> p RubyVM::ZJIT.stats[:exit_unhandled_block_arg]   # => 10000
> ```
>
> In Rails this hits `ActiveRecord::AssociationRoute::Cache#fetch_or_store` (association_route.rb:189,
> `super(key.nil? ? NIL_KEY : key)` under `fetch_or_store(key) { new }`) and
> `ActiveRecord::Railties::ControllerRuntime#cleanup_view_runtime` (controller_runtime.rb:43).
>
> * **Rails main:** 10 of 10 census apps, 21 exits per request on average (campfire 67, writebook 63, fizzy 31).
> * **ruby-bench:** railsbench 2,052 per iteration (2,000 in `cleanup_view_runtime`), lobsters 341, shipit 57.
>
> Measured with per-ISEQ counters (`--zjit-stats-iseq`, see #746).
>
> On k0kubun's `zjit-lobsters7` branch the same guard has `recompile: Some(Recompile)`, next to the super rows 45/46
> of #1039. Is this covered by that work, or is it free to take? The small version is giving the guard a recompile;
> passing the frame's block handler through to the super callee would specialize it fully.

## Draft: comment on Shopify/ruby#1039 (not posted)

> Rails-main breadth for a few unassigned rows, in case it helps order the upstreaming. I measured with per-ISEQ
> ZJIT counters (`--zjit-stats-iseq`, #746) on master 9aa0898240 over 10 Rails-main apps (Rails 5810776eec;
> blog, campfire, writebook, fizzy, fizzy-mysql, codetriage, pingcrm, redprints-cfp, react-starter-kit,
> lobsters). "Per request" is the mean over the apps reached. ruby-bench is per iteration, railsbench / lobsters /
> shipit.
>
> | row | fallback / exit | top Rails site | apps | per request | ruby-bench per itr |
> |---|---|---|---|---|---|
> | 11 `send`/`__send__` | `send_not_optimized_method_type_optimized` | Arel `Visitor#visit` (visitor.rb:35), 102/request | 10/10 | 186 | 42k / 26k / 70k |
> | 19 invalidated ISEQs | `exit_patchpoint_stable_constant_names` | `WhereClause.empty` (where_clause.rb:99), `FromClause.empty` | 5/10 | 230 | 0 / 0 / 38.5k (shipit `connection_specification_name`) |
> | 20/22 `def foo(...)` | `sendforward_not_specialized` | `WhereClause#empty?` via `delegate` (where_clause.rb:8), 92/request | 10/10 | 331 | 75k / 32k / 101k |
> | 47 protected | `send_not_optimized_need_permission` | `OrderedOptions` `@parent._get(k)` (ordered_options.rb:109), 114/request; `WhereClause#merge` | 10/10 | 188 | 55k / 16k / 30k |
>
> Each per-ISEQ counter sums exactly to its global counter on every app.

## Data for the #746 comment

* Getting this table took one run per app with one flag. With `--zjit-trace-fallbacks` the railsbench run alone
  didn't finish in 457 s ([zjit-stats.md](zjit-stats.md)).
* The per-ISEQ split names mechanisms that the global counters blur. For example, `exit_unhandled_block_arg` is
  only 22 per request, but per ISEQ it is two Rails methods that exit on every call, and the cause is a
  `recompile: None` guard.
* Breadth by ISEQ: the 10 apps have 5,026 distinct (fallback/exit counter, ISEQ) pairs. 169 of them appear in all
  10 apps and 1,042 in at least 5. A global counter can't show that.

## Cost

`--zjit-stats-iseq` against `--zjit-stats-quiet` on the same build, railsbench, 10 warmup + 10 measured iterations,
two runs each on an orb, so the numbers are rough:

| mode | measured itr avg |
|---|---|
| `--zjit` | 1,580 ms |
| `--zjit-stats-quiet` | 2,353 / 2,330 ms (mean 2,342) |
| `--zjit-stats-iseq` | 2,476 / 2,371 ms (mean 2,424, +3.5%) |

For comparison, `--zjit-trace-fallbacks-sample-rate=100` took 3,272 ms per iteration and `--zjit-trace-fallbacks`
didn't finish ([zjit-stats.md](zjit-stats.md)).
