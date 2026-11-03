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

Rule (DECISIONS, after k0kubun on [Shopify/ruby#1100](https://github.com/Shopify/ruby/issues/1100)): an idea is
taken only when its own issue has an assignee or an open PR exists; burndown rows such as Shopify/ruby#1039's
count as free. I checked assignees and all 67 open ruby/ruby PRs with "ZJIT" in the title on 2026-11-03. Numbers
below come from runs with 0 `compile_error_out_of_memory` (the three apps that hit the 64 MiB code region were
rerun with `--zjit-exec-mem-size=512 --zjit-mem-size=1024`). "Per op" is the mean over the apps reached;
ruby-bench is per iteration (railsbench / lobsters / shipit).

**Taken**

| lead | taken by |
|---|---|
| 4 protected calls | ours, ruby/ruby#19483 (open) |
| 5 `Kernel#send` | tekknolagi, ruby/ruby#19583 "Support .send(:symbol)" (open) |
| 6 `def m(...)` forwarding | nozomemein, ruby/ruby#18326 "Specialize monomorphic sendforward calls" (open) |
| 8 `super` with a block | cleared by k0kubun on Shopify/ruby#1100; U3 builds the fix |
| 9 invalidated constant patch points | k0kubun, ruby/ruby#19617 "Recompile final versions invalidated by PatchPoint" (open) |

**Free, ranked**

| rank | lead | apps | per op | ruby-bench | why this rank |
|---|---|---|---|---|---|
| 1 | 7 `&block` forwarding (`mon_synchronize(&b)`, Notifications fanout, `ConnectionPool::Queue#synchronize`, `with_connection`) | 10 | 345 | 120k / 95k / 201k | Largest concrete volume in both data sets. It has its own issue, [Shopify/ruby#1014](https://github.com/Shopify/ruby/issues/1014), with no assignee and no open PR. The patch shape is known from Shopify/ruby#1039 rows 41/44/49 (unassigned). Medium size. |
| 2 | 10 `singleton_class_seen` for module receivers (`IndexedRow::Mutable#fetch` → `UNSET.equal?`) | 6 | 431 | 0 / 1.2k / 0.2k | Small: guard the receiver's class instead of a dynamic send. A standalone repro exists. It's free because ruby/ruby#19669 was closed by its author (linyiru, no comment). It builds on linyiru's open ruby/ruby#19658, so it should wait for or sit on top of that PR. Matters mostly on Rails main. |
| 3 | 3 class-level methods on many model classes (`_reflections`, `attribute_aliases`, `schema_context`) | 10 | 325 | 0 / 10.5k / 16.2k | Shopify/ruby#1099 item 2: 7–36 receiver classes, but one method entry. Needs a method-entry-keyed guard (cf. Shopify/ruby#1039 rows 24/25/27, unassigned). Design-heavy. |
| 4 | 1 polymorphic yield in `Array#each`/`map`/`find` | 10 | 1,397 | 242k / 136k / 361k | Biggest volume overall, but the largest change. Block inlining is k0kubun's (Shopify/ruby#1093, assigned). Run-time block-ISEQ dispatch (Shopify/ruby#1039 row 55) is free but sits right next to that work, so collision risk is high. |
| 5 | 2 `BasicObject#!=` (polymorphic inner `==`) | 10 | 277 | 0 / 3.8k / 0 | A polymorphic dispatch inside a builtin. Little ruby-bench effect, and it would ride on any general polymorphic-send work rather than stand alone. |

Not built yet; the ruby/ruby PR cap (15) applies before any of these can open.

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
