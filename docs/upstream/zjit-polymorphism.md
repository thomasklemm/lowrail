# ZJIT polymorphism on Rails: what the fallbacks are made of

Bet Z3: data for the ZJIT team, not a competing patch. This measures ZJIT's polymorphic/megamorphic sends,
getivar fallbacks and invokeblock misses on Rails, explains why each top site is polymorphic in Rails terms, and
estimates what an N-entry cache would catch. The issue draft is [at the end](#issue-draft-not-posted).

**Context ([zjit-gap-census](zjit-gap-census.md), J1, same master):** ZJIT runs 3.5% / 5.5% / 18% more Callgrind
instructions per iteration than YJIT on railsbench / lobsters / shipit (A/A ≤ 2.1%). Its largest send-fallback
reason is getivar (`no_profile_missing_ic` + `no_side_exits`) at 295k / 474k / 1.25M per iteration, followed by
`send_polymorphic_fallback` at 26.5k / 247k / 663k. The probe below reproduces those counters exactly, so its
per-site attribution covers the same fallbacks.

**Result.** The biggest bucket is mostly not polymorphism in the cache-size sense:

1. **Profile loss on monomorphic attr_reader sites.** 71–77% of `getivar_fallback_no_profile_missing_ic` sites
   see one (class, shape) in steady state; a 2-entry (class, shape) cache would catch 88% (9 apps) and 91–96%
   (ruby-bench). Mechanism, reproduced standalone: when a send's receiver profile holds several *shapes of one
   class*, `iseq_to_hir` builds a single class arm and the refined receiver loses its profile, so the inlined
   attr_reader becomes a generic `GetIvar` with no inline cache. Open #19443 (tekknolagi) seeds an arm's profile
   only when the arm has exactly one shape; it leaves this repro unchanged (checked on its head `1c29235c29`).
2. **Class-level methods on many model classes.** Half of `send_polymorphic_fallback` has a model *singleton
   class* as receiver (`_reflections`, `schema_context`, `attribute_types`, `current_shard`). Each site sees 7–36
   receiver classes, but 86% (9 apps) / 89–96% (lobsters, shipit) of fallbacks resolve to one method entry. More
   cache entries don't help; a guard on the resolved method would.
3. **Singleton objects.** Since [#19540](https://github.com/ruby/ruby/pull/19540) (k0kubun, merged 2026-10-28,
   a memory-leak fix for SFR that mirrors YJIT), the profiler records receivers whose class is the singleton class
   of a non-Module object as "other". That is right for short-lived objects, but Rails' logger is a long-lived
   `extend`ed `ActiveSupport::Logger`: 50% (9 apps) / 69% (ruby-bench) of `send_megamorphic` is singleton-object
   receivers, and railsbench's whole 190k/itr megamorphic count is `Logger#level`/`level_override`/`local_level` on
   that one object. The repro has 0 fallbacks on #19443's base (before #19540) and 1 per call on master.
4. **invokeblock in shared `<internal:array>` iterators.** `Array#each`'s yield sees 68–121 distinct blocks per app
   and `Array#map` 12–75. A larger cache catches only part (N=8: 70–87%); per-caller inlining of the iterator
   (Shopify/ruby#1093) is the structural fix.

More profile samples are not the lever: `--zjit-num-profiles=20` instead of 5 moves fallbacks between buckets and
leaves total dynamic sends at −2.5% / +19% / +1%.

## Prior work (checked 2026-11-03)

* ruby/ruby open: [#19443](https://github.com/ruby/ruby/pull/19443) polymorphic class + monomorphic shape
  (tekknolagi), [#18616](https://github.com/ruby/ruby/pull/18616) seed polymorphic branches with shape data
  (tekknolagi), [#19558](https://github.com/ruby/ruby/pull/19558) reprofile shape-polymorphic send
  misses (ours).
* ruby/ruby merged: polymorphic getivar #16476/#16533/#16526/#16637, polymorphic send #15949/#16335/#18057,
  polymorphic setivar #17801, polymorphic ISEQ invokeblock #18211, polymorphic sends with block literals #18567.
  Closed: #15972 (XrXr, shape-based getivar splitting), #17860.
* Shopify/ruby open: [#776](https://github.com/Shopify/ruby/issues/776) (`send_without_block_polymorphic` too
  frequent; tekknolagi: caches that are monomorphic in class need `is_monomorphic_class`),
  [#1039](https://github.com/Shopify/ruby/issues/1039) lobsters burndown, #1030, [#1031](https://github.com/Shopify/ruby/issues/1031)
  adaptive compilation (profiling budget, "function stubs compiling the callee immediately"), #1093 inline block
  ISEQ on yield, #803, #1041. Closed: #1013 (polymorphic invokeblock), #926/#927/#928, #984.
* Merged [#19540](https://github.com/ruby/ruby/pull/19540) stops profiling singleton classes of non-Module
  objects (memory leak). No issue or PR covers shape-polymorphic same-class attr_reader inlining, method-keyed dispatch for singleton
  class receivers, or profiling singleton-object receivers. No design note on a general polymorphic inline cache
  beyond `DISTRIBUTION_SIZE = 8` buckets and the dispatch arms in `iseq_to_hir`.

## Method

* **Ruby:** master `90dbced795`, release build `--enable-zjit`. Probe: fork branch
  [`wip/zjit-poly-probe`](https://github.com/thomasklemm/ruby/tree/wip/zjit-poly-probe) (`585aed7111`, one
  commit, measurement only, not for upstream).
* **Interpreter mode** (`ZJIT_POLYPROBE=interp:FILE`, `--zjit-call-threshold=4000000000`): every send, opt_*
  send, getivar and invokeblock execution records receiver class, shape, resolved method entry and block handler.
  This is the full steady-state distribution per site.
* **JIT mode** (`ZJIT_POLYPROBE=jit:FILE`): every polymorphism-related ZJIT fallback (send polymorphic /
  polymorphic fallback / megamorphic, invokeblock miss / not specialized, getivar by fallback counter) records
  its receiver. 96–100% of fallback receivers appear in the interpreter distribution of the same site.
* **Workloads:** the nine census-4 apps on Rails main `5810776eec` (`stats` command: warm 50×, reset, 20× per
  workload) and ruby-bench railsbench, lobsters, shipit (10 warmup, 10 measured iterations,
  [`zjit_poly_harness.rb`](../../bench/upstream/zjit_poly_harness.rb)).
* **Counterfactual:** for each site, an N-entry cache holds the N most frequent entries of the interpreter
  distribution: receiver class for sends, (class, shape) for getivar, block handler for invokeblock. "Caught" is
  the fallbacks whose receiver is among them. It is an upper bound on what a cache keyed that way could save in
  dynamic calls; it ignores guard cost, code size and recompiles. "One resolved method" counts fallbacks whose
  receiver resolves to the site's most common method entry.
* Tools: [`script/zjit-poly-probe`](../../script/zjit-poly-probe), [`zjit_poly_rank.rb`](../../bench/upstream/zjit_poly_rank.rb),
  [`zjit_poly_mechanism.rb`](../../bench/upstream/zjit_poly_mechanism.rb). Reports, repros and counter dumps:
  [`receipts.tar.gz`](data/zjit-polymorphism/receipts.tar.gz).
* No Callgrind prototype: the data says the largest buckets are profile loss (1, 3) and method identity (2), not
  cache size, so a 2–4 entry guard chain would mostly measure the wrong thing. Offered in the issue instead.

## Counterfactual

### Nine apps, fallbacks per operation (mean over apps)

| Reason | Fallbacks/op | N=1 | N=2 | N=4 | N=8 | one resolved method |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| getivar `no_profile_missing_ic` | 2,363 | 71% | 88% | 95% | 97% | – |
| `send_polymorphic_fallback` | 2,333 | 32% | 52% | 74% | 89% | 86% |
| getivar `no_side_exits` | 1,450 | 50% | 60% | 72% | 84% | – |
| `invokeblock_polymorphic_miss` | 1,035 | 23% | 35% | 57% | 72% | – |
| `send_megamorphic` | 964 | 37% | 52% | 69% | 85% | 95% |
| `invokeblock_not_specialized` | 480 | 52% | 65% | 78% | 87% | – |
| `send_polymorphic` | 258 | 67% | 84% | 87% | 89% | – |
| getivar `polymorphic` + `megamorphic` | 26 | | | | | |

### ruby-bench, fallbacks per iteration and N=4 / one-method catch

| Reason | railsbench | lobsters | shipit |
| --- | ---: | ---: | ---: |
| getivar `no_profile_missing_ic` | 221k (N=2 96%) | 320k (N=2 91%) | 837k (N=2 92%) |
| getivar `no_side_exits` | 74k (N=1 100%) | 154k (N=4 69%) | 411k (N=4 87%) |
| `send_polymorphic_fallback` | 26.5k (N=4 99%, method 37%) | 247k (N=4 70%, method 89%) | 663k (N=4 81%, method 96%) |
| `send_megamorphic` | 190k (method 100%) | 100k (method 95%) | 111k (method 72%) |
| `invokeblock_not_specialized` | 330k (N=4 51%) | 154k (N=4 55%) | 301k (N=4 78%) |
| `invokeblock_polymorphic_miss` | 11k | 13k | 98k |

`invokeblock_polymorphic_miss` on shipit varies by run (18.6k in the `num-profiles` baseline, 98k in the probe run).

### Mechanism shares (fallback-weighted)

| Reason | 9 apps | ruby-bench |
| --- | --- | --- |
| getivar `no_profile_missing_ic` | one class at site 58%, several classes 39% | 59%, 39% |
| `send_polymorphic_fallback` | model singleton classes 49%, several classes 51% | 50%, 50% |
| `send_megamorphic` | singleton objects 50%, several classes 30%, singleton classes 19% | 69%, 22%, 9% |
| getivar `no_side_exits` | several classes 31%, one class 30%, singleton classes 28%, singleton objects 10% | 26%, 32%, 29%, 14% |

### Sampling budget (`--zjit-num-profiles`, master, per iteration)

| Counter | railsbench 5 → 20 | lobsters 5 → 20 | shipit 5 → 20 |
| --- | --- | --- | --- |
| dynamic sends | 1,066k → 1,039k | 751k → 890k | 1,721k → 1,738k |
| `send_polymorphic_fallback` | 26.5k → 2.8k | 247k → 140k | 663k → 426k |
| `send_megamorphic` | 190k → 191k | 100k → 340k | 111k → 358k |
| `invokeblock_not_specialized` | 330k → 66k | 154k → 16k | 381k → 22k |
| `invokeblock_polymorphic_miss` | 11k → 275k | 13k → 151k | 19k → 382k |
| getivar `no_profile_missing_ic` | 221k → 222k | 320k → 275k | 837k → 825k |

## Top sites (nine apps, per operation)

Full tables per reason (top 12–15) are in the receipts (`apps-report.md`, `rb-*.md`).

| Reason | Site (apps) | Fallbacks/op | Receivers | Why it is polymorphic in Rails |
| --- | --- | ---: | --- | --- |
| getivar missing IC | `IsolatedExecutionState.[]` `@scope.current.active_support_execution_state` (9) | 138 | Thread, 1 class, 4 shapes, 100% one shape | Thread objects carry different ivar sets; shape-polymorphic attr_accessor on one class |
| getivar missing IC | Arel `Composite#<<` `left`/`right` (8) | 107 each | 1 class, 1 shape in steady state | likely shape-polymorphic at profile time (`retryable=`/`preparable` set later) |
| getivar missing IC | `WhereClause#empty?` `predicates` (9) | 76 | 1 class, 2 shapes 50/50 | `delegate` to an `attr_reader` on a class with two shapes in use |
| getivar missing IC | `Association#klass` `reflection` (9) | 66 | 5 association classes | BelongsTo/HasMany/HasManyThrough/HasOne share the reader |
| getivar no side exits | `schema_loaded?` / `schema_context` `@schema_context` (6) | 101 / 97 | 36 model singleton classes, **1 ivar index** | class-level ivar on every model class |
| getivar no side exits | `association_cache` / `_read_attribute` `@association_cache` / `@attributes` (6–7) | 98 / 78 | 22 model classes, 75–79 shapes, 3–4 ivar indexes | each model has its own shape tree; index is nearly constant |
| send polymorphic fallback | `BasicObject#!=` `==` (9) | 228 | 55 classes, 14 methods | one `!=` ISEQ for every class without its own `!=` |
| send polymorphic fallback | `schema_context` `schema_loaded?`, `_reflections`, `attribute_types`, `attribute_aliases` (5–9) | 79, 75, 48, 38 | 18–36 model singleton classes, **1 method** | class-level methods called on each model class |
| send polymorphic fallback | Arel `Visitor#visit` `class` (9) | 45 | 45 node classes, 1 method (`Kernel#class`) | visitor dispatch over Arel nodes |
| send megamorphic | `connection_specification_name` `superclass`/`==` (6) | 27 | 34 singleton classes, 1 method | walks model class hierarchy |
| send megamorphic | `Logger#level` / `level_override` (ruby-bench) | 26k/itr | one `ActiveSupport::Logger` object with a singleton class | `extend`ed logger; not profiled since #19540 |
| invokeblock miss | `Array#each` yield (9) | 839 | 121 blocks | shared `<internal:array>` iterator |
| invokeblock not specialized | `Array#map` yield (8) | 289 | 75 blocks, top `:hex` 45% | shared iterator; `map(&:sym)` |

`guard_type_failure` exits from J1 (`LazyAttributeSet#fetch_value!`, `Core#init_internals`) fit mechanism 1:
`LazyAttributeSet#fetch_value` reads `values`/`types`/`additional_types` through attr_readers on one class and
appears in the missing-IC and no-side-exits lists on lobsters and shipit.

## Repros

All on master `90dbced795`, `--zjit --zjit-stats-quiet`, per call after warmup.

| Repro | Shape | Result |
| --- | --- | --- |
| `shapes.rb` | attr_reader on one class with 2 shapes | 1.0 dynamic getivar (`no_profile_missing_ic`); HIR: `CondBranchHasType Box` then `GetIvar` (no IC). Same on #19443. |
| `classattr.rb` | class method on 12 subclasses' singleton classes, one method | 1.17 dynamic sends (`send_polymorphic_fallback`); `num-profiles=20`: 2.0 (megamorphic) |
| `singleton.rb` | ivar read in a method on an `extend`ed object | 1.0 dynamic getivar (`no_side_exits`); 0 on #19443's base `3d3d1b0329` (before #19540) |
| `blocks.rb` | `Array#each` with 3 blocks round-robin | 1.0 `invokeblock_polymorphic_miss`; `num-profiles=10`: 0 |
| `ies.rb`, `composite.rb`, `noprof.rb` | monomorphic controls | 0 (no fallback) |

## Issue draft (not posted)

**Title:** ZJIT: Polymorphic fallbacks on Rails are mostly lost profiles and per-class receivers (data from 9 apps + ruby-bench)

**Body:**

> On master 90dbced795, ZJIT runs 3.5% / 5.5% / 18% more instructions than YJIT on railsbench / lobsters / shipit
> (Callgrind, A/A ≤ 2.1%). Its largest fallback reason is getivar (`no_profile_missing_ic` + `no_side_exits`):
> 295k / 474k / 1.25M per iteration. `send_polymorphic_fallback` adds 26.5k / 247k / 663k.
>
> I recorded the receiver of every polymorphism-related fallback and the full receiver distribution at the same
> sites (interpreter, same workloads) across ruby-bench and nine Rails apps on Rails main. Probe:
> thomasklemm/ruby `wip/zjit-poly-probe` (measurement only). "N=k" is the share of fallbacks whose receiver is among
> the site's k most frequent entries, i.e. an upper bound for a k-entry cache keyed that way.
>
> | per iteration | railsbench | lobsters | shipit |
> |---|---|---|---|
> | getivar `no_profile_missing_ic` | 221k, N=2 96% | 320k, N=2 91% | 837k, N=2 92% |
> | getivar `no_side_exits` | 74k, N=1 100% | 154k, N=4 69% | 411k, N=4 87% |
> | `send_polymorphic_fallback` | 26.5k, N=4 99%, one method 37% | 247k, N=4 70%, one method 89% | 663k, N=4 81%, one method 96% |
> | `send_megamorphic` | 190k, one method 100% | 100k, one method 95% | 111k, one method 72% |
> | `invokeblock_not_specialized` | 330k, N=4 51% | 154k, N=4 55% | 301k, N=4 78% |
>
> Three patterns account for most of it:
>
> **1. Shape-polymorphic receiver of one class loses the profile.** ~59% of `no_profile_missing_ic` fallbacks are at
> sites with a single receiver class (`IsolatedExecutionState.[]` on `Thread`, `WhereClause#empty?`,
> `Composite#<<`). With several shapes of one class, the polymorphic arm is one `CondBranchHasType`, and the refined
> receiver has no profile, so the inlined attr_reader becomes a generic `GetIvar` without an IC:
>
> ```ruby
> class Box
>   attr_reader :v
>   def initialize(v, extra) = (@extra = 1 if extra; @v = v)
> end
> BOXES = [Box.new(1, false), Box.new(2, true)]
> def read(b) = b.v
> 200.times { |i| read(BOXES[i % 2]) }
> RubyVM::ZJIT.reset_stats!
> 10_000.times { read(BOXES[0]) }
> p RubyVM::ZJIT.stats[:getivar_fallback_no_profile_missing_ic] # => 10000
> ```
>
> ruby/ruby#19443 seeds an arm only when it has exactly one shape, so this case is unchanged on its head.
>
> **2. Class-level methods on model classes.** Half of `send_polymorphic_fallback` has a model's singleton class as
> receiver (`_reflections`, `schema_context`, `attribute_types`, `current_shard`, `attribute_aliases`): 7–36
> receiver classes per site, nearly always the same method entry. More samples make it worse
> (`--zjit-num-profiles=20` turns these into `send_megamorphic`):
>
> ```ruby
> class Base
>   def self.reflections = @reflections ||= {}
>   def self.lookup(name) = reflections[name]
> end
> MODELS = 12.times.map { Class.new(Base) }
> def find(k) = k.lookup(:x)
> 1200.times { |i| find(MODELS[i % 12]) }
> RubyVM::ZJIT.reset_stats!
> 12_000.times { |i| find(MODELS[i % 12]) }
> p RubyVM::ZJIT.stats[:send_fallback_send_polymorphic_fallback] # => 14000 (1.17/call)
> ```
>
> **3. Long-lived singleton objects since ruby/ruby#19540.** That change (a memory-leak fix) records receivers whose
> class is the singleton class of a non-Module object as "other", so such sites look megamorphic or unprofiled.
> Rails' logger is one long-lived `extend`ed `ActiveSupport::Logger`: on railsbench all 190k `send_megamorphic` per
> iteration are `Logger#level`/`level_override`/`local_level` on it, and across the apps singleton-object
> receivers are 50–69% of `send_megamorphic`. This repro gives 0 fallbacks before ruby/ruby#19540:
>
> ```ruby
> class Lg; def initialize = @level = 1; def lvl = @level; end
> L = Lg.new.extend(Module.new)
> def read = L.lvl
> 200.times { read }
> RubyVM::ZJIT.reset_stats!
> 10_000.times { read }
> p RubyVM::ZJIT.stats[:getivar_fallback_no_side_exits] # => 9970
> ```
>
> The rest is real block polymorphism in `<internal:array>` iterators (`Array#each` yield: 68–121 blocks per app),
> which a larger cache only partly catches (N=8: 70–87%). Raising `--zjit-num-profiles` from 5 to 20 only moves
> fallbacks between buckets (total dynamic sends −2.5% / +19% / +1%).
>
> Per-site tables with receiver counts, shapes, method entries and Rails call sites:
> thomasklemm/lowrail `docs/upstream/zjit-polymorphism.md`. If one of these directions is useful, I can prototype
> it and measure sends and Callgrind instructions on railsbench and lobsters.

## Limits

* Counters only; no timing claim. The Ir gap is J1's measurement; this record attributes fallbacks,
  not instructions.
* Counterfactuals are upper bounds; they don't model guard chains' code size (J1's `likely_a` experiment saved
  library work but lost it to JIT code size) or recompile behaviour.
* `Composite#<<` profile loss is inferred: in steady state it has one shape, so the shape set at profile time is
  not observed directly.
