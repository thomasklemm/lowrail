# ZJIT gap census, round 3: wall time on Rails main (bet Z, 2026-11-27)

Bet Z: ZJIT will become Ruby's default JIT, so the most valuable Ruby-side work is wherever ZJIT still loses to
YJIT on Rails code. Round 2 ([zjit-gap-census-2.md](zjit-gap-census-2.md), 2026-11-25) answered that in
instructions on Rails 8.1. This round measures **wall time** on an a1.xxlarge orb, on Ruby master and Rails main of
2026-11-27, with k0kubun's newer `zjit-headline6` as the preview of what is still to land. It attributes the
remaining fallbacks to call sites and checks every residue against open work. Nothing was opened or posted.
The bet started on Fable ([handoff](../../bench/upstream/zjit_gap_bet/HANDOFF.md)) and was finished on Opus.

**Result.** On master `0d399335b7`, ZJIT is still slower than YJIT on four of five Rails-main workloads:
**shipit +22.3%, railsbench +11.2%, Writebook +9.3%, lobsters +2.7%**; Campfire +0.9% is inside its interval. On
k0kubun's `zjit-headline6`, ZJIT is **faster than YJIT on four and equal on shipit** (−0.7%, interval −3.3% to
+1.4%). Every master gap has the same cause, ZJIT falling back to generic sends and ivar reads 1.5–2.2× as often
as YJIT, and headline6 removes it; what headline6 leaves is small and owned.

**Ownership.** On headline6 ZJIT sends dynamically less than half as often as YJIT (171k / 125k / 327k against
389k / 334k / 659k per iteration on railsbench / lobsters / shipit), and every residue reason it still has is
either one where YJIT falls back too, or is covered by a commit on k0kubun's experiment branches. **No new,
unowned ZJIT−YJIT gap**, so no ZJIT issue or PR draft. Two leads change size on Rails main (below): `super`
passing the frame's block grew from 0.06k to 21k per shipit iteration with Rails main's new
`AssociationRoute::Cache#fetch_or_store`, and ZS1's Symbol block specialization is lost in final versions.

**Rails.** No Rails candidate. The one new Rails-side shape (`Relation#reset` adds 7 ivars that `initialize` does
not define) showed no interpreter, YJIT or ZJIT win in a micro, and the older ones are VB1 (closed upstream) and
OO1 (held). `scope_hm` (lead B), re-checked after rails/rails#59569 merged: ZJIT is faster than YJIT there.

## Pins and method

* **Ruby master** [`0d399335b7`](https://github.com/ruby/ruby/commit/0d399335b7) (2026-11-27 16:40 UTC), release
  build `--enable-yjit --enable-zjit optflags=-O3`; YJIT and ZJIT on this one binary.
* **Headline:** k0kubun/ruby `zjit-headline6` [`5c4239a16d`](https://github.com/k0kubun/ruby/commit/5c4239a16d),
  97 commits on master `c10bc4c5aa` (2026-11-26), same configure. Compared with master's YJIT: `yjit/` differs by two
  commits between the two bases.
* **Rails main** [`2e299253f9`](https://github.com/rails/rails/commit/2e299253f9) (contains rails/rails#59569).
  ruby-bench [`43d41e2`](https://github.com/ruby/ruby-bench/commit/43d41e2): railsbench, lobsters and shipit on
  that Rails by path, prism added, `reaping_frequency: 0`, the Rails 8.2 default config lines, shipit-engine 0.45.0
  vendored with the `ReviewStack` patch. Census copies of Campfire and Writebook (corpus `censusz3`), master
  overlays, database snapshot restored before every process.
* **ZJIT flags** `--zjit-exec-mem-size=512 --zjit-mem-size=1024`; `compile_error_out_of_memory` 0 in every stats
  run. Fixed heap `RUBY_GC_HEAP_INIT_BYTES=32 MiB`; GC stays on.
* **Timing:** a1.xxlarge orb (16 vCPUs, SMT pairs 0-1 … 14-15), five lanes pinned to CPUs 2, 4, 6, 8 and 10
  with their siblings idle, one target per lane, run in parallel. Each round is five fresh processes: master YJIT
  and ZJIT twice each (the twins are the A/A) and headline6 ZJIT once, in order Y Z H Z Y or Z Y H Y Z. ruby-bench:
  150 warmup and 20 timed iterations per process, 6 rounds; census apps: `script/census run --wall`, 80 warmup
  cycles and 20 windows of 5 cycles, 10 rounds (Writebook without "POST page", which grows the book). **JIT-flat
  gate per timed iteration:** an iteration or window in which the JIT compiled or invalidated anything is rejected
  and counted, and only flat ones are averaged. Ratio per round = mean of the two ZJIT processes over the mean of
  the two YJIT processes; across rounds the geometric mean with a 95% bootstrap interval
  ([`wall_table.rb`](../../bench/upstream/zjit_gap_bet/wall_table.rb)). Raw JSONs and logs:
  [`data/wall-raw.tar.gz`](../../bench/upstream/zjit_gap_bet/data/wall-raw.tar.gz); steal time over the run was about 0.03% per lane
  ([`wall-machine.txt`](../../bench/upstream/zjit_gap_bet/data/wall-machine.txt)).
* **Counters and traces:** on an a1.large orb, counts only
  ([handoff](../../bench/upstream/zjit_gap_bet/HANDOFF.md#what-was-measured), raw data in
  [`data/`](../../bench/upstream/zjit_gap_bet/data/)).

## Wall time

[wall-table.md](../../bench/upstream/zjit_gap_bet/data/wall-table.md), wall time per iteration (ruby-bench) or
per operation (census apps), master YJIT against master ZJIT and headline6 ZJIT:

| workload | rounds | YJIT ms | ZJIT ms | **ZJIT/YJIT** [95%] | A/A YJIT | A/A ZJIT | **headline6 ZJIT/YJIT** [95%] | rejected iterations (Y, Z, H) |
| --- | ---: | ---: | ---: | --- | --- | --- | --- | --- |
| shipit | 6 | 880.0 | 1,076.1 | **+22.3%** [+19.7, +25.1] | −0.2% | −0.6% | **−0.7%** [−3.3, +1.4] | 87/240, 0/240, 3/120 |
| railsbench | 6 | 806.4 | 896.8 | **+11.2%** [+10.0, +12.7] | +1.1% | −1.6% | **−4.6%** [−6.0, −3.1] | 0/240, 0/240, 0/120 |
| Writebook | 10 | 7.73 | 8.44 | **+9.3%** [+7.6, +10.6] | +1.2% | −0.4% | **−3.7%** [−6.2, −1.1] | 187/400, 0/400, 21/200 |
| lobsters | 6 | 684.1 | 702.6 | **+2.7%** [+0.5, +4.6] | −1.1% | +2.1% | **−11.4%** [−14.6, −8.4] | 18/240, 6/240, 12/120 |
| Campfire | 10 | 13.48 | 13.60 | +0.9% [−2.6, +4.1] | −1.5% | +1.2% | **−10.1%** [−12.6, −7.7] | 283/400, 26/400, 37/200 |

Every A/A interval contains 0. With rejected iterations included the ratios barely move (+22.0, +11.2, +8.7,
+3.0, +0.8%). **Caveat:** YJIT keeps compiling late in the census apps (283 of 400 Campfire windows and 187 of 400
Writebook windows rejected), so their YJIT means rest on fewer windows; railsbench is clean in all three modes. The
headline column compares two builds whose `yjit/` differs by two commits (above).

Ranked by the master gap: shipit, railsbench, Writebook, lobsters; Campfire has none. These rank with the counters:
shipit has the most fallbacks over YJIT (dynamic sends 1,427k against 659k per iteration; polymorphic fallback
705k, ivar reads without a profile 658k), railsbench next (575k against 389k; `&block` arguments 115k, megamorphic
78k, protected 47k), lobsters the fewest over YJIT relative to its size (622k against 334k).

## Where ZJIT still falls back, and who owns it

Per iteration, railsbench / lobsters / shipit, from `--zjit-stats` and `--yjit-stats` (100 warmup + 10 counted
iterations, [stats-table.md](../../bench/upstream/zjit_gap_bet/data/stats-table.md)) and sampled traces
([sites.tar.gz](../../bench/upstream/zjit_gap_bet/data/sites.tar.gz)).

| | master ZJIT | headline6 ZJIT | master YJIT |
| --- | ---: | ---: | ---: |
| dynamic sends | 575k / 622k / 1,427k | 171k / 125k / 327k | 389k / 334k / 659k |
| side exits | 4.0k / 8.1k / 7.0k | 13 / 1.2k / 3 | 9.0k / 3.1k / 7.0k |
| generic ivar reads | 201k / 423k / 1,019k | 244k / 275k / 579k | <0.5k / 76k / 173k (`num_getivar_megamorphic`) |

Campfire and Writebook, per operation: dynamic sends 6,168 / 19,182 on master ZJIT, 1,651 / 3,726 on headline6,
2,899 / 9,288 under YJIT.

**On master**, ZJIT sends dynamically 1.5–2.2× as often as YJIT. The reasons are the known ones, each fixed or much
smaller on headline6, which is landing commit by commit (merged ruby/ruby#20113 and #20137; open #20192, #20193,
#20197): ivar reads without a shape profile 170k / 233k / 658k, polymorphic fallbacks 24k / 263k / 705k,
megamorphic sends, `&block` arguments 115k / 51k / 147k, `(...)` forwarding 46k / 27k / 103k, protected sends
47k / 16k / 36k, `Kernel#send` 40k / 26k / 68k.

**What headline6 leaves**, ranked by the count ZJIT has above YJIT at the same kind of site:

| # | residue on headline6 | ZJIT h6 | YJIT at the same sites | sites (Rails main) | owner |
| --- | --- | --- | --- | --- | --- |
| 1 | generic ivar reads after a shape-chain or shape miss | 244k / 275k / 579k | <0.5k / 76k / 173k (`num_getivar_megamorphic`) | class-level ivars on model classes (`table_name`, `loaded_mapped_table`, `schema_context`, `_reflections`, `attribute_aliases`, `connection_specification_name`), `ActiveModel::Type::Value#hash`, `Rack::Request::Env#get_header` (`@env`, 30k on railsbench), `RoutingUrlFor#url_options`, `ConnectionPool#with_connection` | k0kubun: `61327ecd80` "Read class instance variables through the (shape, name) cache" (`zjit-headline-exp/rails`, `rails2`), `d061c0dc` "Read attr_reader ivars through an inline cache on a shape chain miss" (`ivar`). Round 2 measured the shape-chain fallback at 325–339 Ir per call against YJIT's 647–731 at 6+ shapes, so a count above YJIT is not a cost above YJIT |
| 2 | generic ivar writes after a shape-chain miss | 2.2k / 16k / 61k | – | `Relation#reset` (22k + 6.3k + 3.2k on shipit), `Association#reset_scope`, `Relation#initialize_copy` | k0kubun: `a50ed7e5` "Take cached shape transitions in the setivar inline cache check" (`ivar`) |
| 3 | `super` passing the frame's block | 4.0k / 1.3k / 21k | YJIT specializes it; ZJIT pays +374 Ir per call (micro) | `AssociationRoute::Cache#fetch_or_store` (`super(key.nil? ? NIL_KEY : key)` into `WeakKeyMap#fetch_or_store`, which yields), new on Rails main; ~19k of shipit's 21k | k0kubun: `554bd43e` "Pass the frame's block on through super to an ISEQ method" (`zjit-headline-exp/super13`, 2026-11-22). Duplicates our lead 8b prototype; see below |
| 4 | `&:value!` in `LazyIndexedAttributeSet#fetch_value_at!` | 0 / 0 / 18k | YJIT falls back too (`send_iseq_block_arg_type`) | attribute_set.rb:425 | ours, follow-up to ZS1 (ruby/ruby#19912, open); see below |
| 5 | `yield` not specialized | 45k / 22k / 46k | YJIT: 53k / 48k / 152k (`invokeblock_symbol`, `_iseq_not_inlined`, `_proc`) | `Fanout#iterate_guarding_exceptions` → `collection.each(&block)` (18k railsbench) | not a gap against YJIT; k0kubun: "Dispatch yield directly to Procs that wrap ISEQ blocks" (`invokeblock-on-tip`), Shopify/ruby#1093 |
| 6 | `super` with complex args, from blocks, `super(...)` | 47k / 9k / 42k (super family, row 3 included) | 59k / 35k / 30k (`invokesuper_*`) | `process_action`/`initialize` chains in Action Pack | YJIT falls back as often or more except shipit; k0kubun's `super13` branch (`super(...)` on the profiled callinfo, splat/keywords, literal block) |
| 7 | `Kernel#send` with a forwarded `&block` | 29k / 2.9k / 2.2k (`unsupported method type Optimized`) | 26k / 2.2k / 2.2k (`send_optimized_block_arg`) | `ActiveSupport::Callbacks::CallTemplate::{MethodCall,ObjectCall}#make_lambda` (callbacks.rb:399, :422) | not a gap against YJIT |
| 8 | `(...)` forwarding with several callinfos | 4k / 10k / 52k | YJIT: `send_forwarding` 46k / 27k / 103k | `WhereClause#empty?` delegation on shipit | not a gap against YJIT; k0kubun: "Guard only the argument shape of forwarded callinfos" (`super13`) |
| 9 | C methods called with a frame | `Hash#fetch` 94k / 83k / 303k, `Hash#key?`, `Array#fetch`, `Array#any?` | YJIT calls these with a frame too | – | `Hash#fetch`: nithya4005, Shopify/ruby#1086 / ruby/ruby#19949; frame cost: k0kubun, Shopify/ruby#1030 |

Rows 1, 3 and the shipit part of 2 are the only ones where ZJIT on headline6 does something YJIT does more
cheaply; each is covered by a k0kubun commit that is not in headline6 and has no PR yet. By the queue rule
([zjit-iseq-leads](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03)) a branch commit doesn't make an idea
taken, but building any of them would duplicate his work, so none is built here.

## Two leads that change on Rails main

### 8b: `super` passing the frame's block, now 21k per shipit iteration

Rails main added `ActiveRecord::AssociationRoute::Cache < ActiveSupport::WeakKeyMap` with

```ruby
def fetch_or_store(key)
  super(key.nil? ? NIL_KEY : key)
end
```

called from `Cache.for` and `AssociationReflection#association_route` for every association lookup. The `super`
passes the frame's block on to `WeakKeyMap#fetch_or_store`, an ISEQ method that `yield`s. ZJIT (master and
headline6) sends it dynamically (`send_fallback_super_call_with_block`, 21k per shipit iteration, ~19k of them at
association_route.rb:189); on Rails 8.1 lead 8b's prototype turned only 0.06k such sends per shipit iteration into direct ones. Our lead 8b prototype
([`zjit-super-block-pass`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-super-block-pass), 2026-11-03)
and k0kubun's `554bd43e` on `zjit-headline-exp/super13` (2026-11-22) both pass the frame's block handler to the
ISEQ super method. **Status: covered by k0kubun's branch, not built.** Price, Callgrind Ir per call on the same shape
([`price_micro.rb`](../../bench/upstream/zjit_gap_bet/price_micro.rb) `super_block`, A/A identical,
[table](../../bench/upstream/zjit_gap_bet/data/opus/price/table.md)): YJIT 663, master ZJIT 1,026, headline6 ZJIT
1,037, and the same call without a block 610 / 585 / 596. YJIT specializes it (no `invokesuper` fallback counter);
ZJIT takes `send_fallback_super_call_with_block` → `rb_vm_invokesuper` on every call. So about +374 Ir per call
over YJIT, ≈ 8 M Ir per shipit iteration (21k calls), about 0.2%: below `run_benchmarks.rb` resolution. The
Rails code is ordinary and stays.

### ZS1 in final versions: `&:value!` still falls back 18k times per shipit iteration on headline6

headline6 contains our ZS1 commit (`8de2da0`, "Send Symbol block arguments directly", ruby/ruby#19912 open), and on
railsbench and lobsters the `&:value!` send in `fetch_value_at!` is a direct send. On shipit it is not:

* `--zjit-log-compiled-iseqs` ([`probe_versions.sh`](../../bench/upstream/zjit_gap_bet/probe_versions.sh),
  [data](../../bench/upstream/zjit_gap_bet/data/opus/fetch_value_at-versions.txt)): `fetch_value_at!` is compiled
  **4 times** under shipit, once under railsbench.
* `--zjit-trace-exits` over the whole run
  ([data](../../bench/upstream/zjit_gap_bet/data/opus/fetch_value_at-exits.tsv)): its only exits are
  `NoProfileSend` at attribute_set.rb:422 (`attrs[index]`) and :423 (`cache_value_at(index, attr.value!)`). That
  branch runs only for records whose `@attributes` was already materialized, which shipit reaches after the
  method was profiled. Each such exit recompiles, and the last version is compiled with `no_side_exits`.
* ZS1's specialization is skipped under `no_side_exits`, because it guards the caller's cref for refinements with a
  side exit. So the final version keeps the dynamic send.

**Lead (ours, free, small):** in a `no_side_exits` version, branch on the cref's refinements instead of exiting:
the nil arm sends directly with the Symbol as block handler, the other arm sends dynamically, the same
branch-and-fallback shape k0kubun uses for attr_reader dispatch in final versions. It waits for ruby/ruby#19912
to merge, and YJIT has no Symbol case either (`send_iseq_block_arg_type`), so it is a ZJIT-beyond-YJIT item, not a
gap. Price ([`price_micro.rb`](../../bench/upstream/zjit_gap_bet/price_micro.rb) `sym_first`/`sym_final`,
`--zjit-max-versions=2` so one invalidation reaches the final version; Ir per call, A/A identical): headline6 ZJIT
1,495 while the method is in its first version, 1,878 in its final version (120,000 of 120,000 calls take
`send_fallback_send_block_arg_not_nil`), YJIT 1,941 / 1,941. So the final version gives back ZJIT's 383 Ir lead
per call and lands at YJIT's level: ≈ 7 M Ir per shipit iteration (18k calls), about 0.2%. The recompile churn itself (unprofiled branches
reached after profiling) is k0kubun's adaptive-compilation area (Shopify/ruby#1031, assigned; his `2ffe78ec`
"Compile the final version next for ISEQs with many unprofiled exits" needs 50+ such exits and doesn't touch this
ISEQ).

## Rails side

* **`Relation#reset` shapes, dropped.** `reset` (relation.rb:1257) sets `@should_eager_load`, `@arel`, `@to_sql`,
  `@take`, `@offsets`, `@cache_keys` and `@cache_versions`, which `initialize` doesn't define, so `Model.all` has a
  10-ivar shape and every spawned relation a 17-ivar one, and the `reset` writes see both. Defining the seven in
  `initialize` makes them one shape. A screening micro (`Post.where.where.order.limit`, master, 3 rounds on a1.large,
  [`rel_shape.rb`](../../bench/upstream/zjit_gap_bet/rel_shape.rb),
  [data](../../bench/upstream/zjit_gap_bet/data/opus/relshape-chain.txt)): interpreter 44.7 → 45.0 µs, YJIT
  14.07 → 14.19 µs, ZJIT 12.78 → 12.70 µs, all within noise. No win of its own, so not a Rails candidate.
* **`&:value!` in `fetch_value_at!`** (VB1, closed upstream: "fix this in the JITs") and **protected `_get` in
  `InheritableOptions`** (OO1, held) are unchanged JIT-side items.
* **The shared-helper rule** (DECISIONS, Pull requests, 2026-11-27) changes nothing here: there is no Rails
  candidate, and both ZJIT items sit in shared compiler paths (super dispatch, the Symbol block-argument
  specialization), not in one Rails method.
* **`scope_hm` (lead B)** after rails/rails#59569: on Rails main `2e299253f9`, a1.xxlarge, CPU 2, 10 interleaved rounds of
  200,000 calls ([`scope_hm_run.sh`](../../bench/upstream/zjit_gap_bet/scope_hm_run.sh),
  [data](../../bench/upstream/zjit_gap_bet/data/scope_hm-xxl/)): YJIT 12,681 / 12,634 ns per call (A/A), master ZJIT
  11,177 / 11,086, headline6 ZJIT 9,081. **ZJIT/YJIT 0.879** (per round 0.863–0.909), headline6/YJIT 0.717
  (0.691–0.794). ZJIT is ahead here, so lead B is dropped. Its remaining master fallbacks per call (`(...)`
  forwarding, ivar reads without a profile, protected sends) are the general ones above, which headline6 halves.

## Looked at and dropped

* Fizzy and the census Lobsters: not set up (round 2 found both failing on Rails main before any JIT).
* The per-ISEQ stats branch: not rebased; sampled traces and `--zjit-log-compiled-iseqs` gave the sites.
* Census traces on headline6: not run; the master traces and headline counters gave the same reasons.
* Upstream survey, 2026-11-27 ([upstream-survey.tar.gz](../../bench/upstream/zjit_gap_bet/data/upstream-survey.tar.gz)):
  132 open Shopify/ruby issues, 68 open and 18 recently merged ruby/ruby ZJIT PRs, headline6's commit list and 202
  commit titles on k0kubun's experiment branches; for rows 1–3 and the ZS1 lead the commits were read, not only the
  titles. Open items nearest to the residue: Shopify/ruby#1127 / ruby/ruby#19901 (`Proc#call` with keywords),
  ruby/ruby#20217 (super to an attr_writer), ruby/ruby#19659 (surplus yield args), ruby/ruby#19617 (recompile
  final versions invalidated by a PatchPoint).

## Reproduce

```sh
bench/upstream/zjit_gap_bet/setup.sh                    # both Rubies, ruby-bench on Rails main, census copies
bench/upstream/zjit_gap_bet/wall_queue.sh OUT CPU TARGET 1 N   # one lane per target, CPUs 2 4 6 8 10
ruby bench/upstream/zjit_gap_bet/wall_table.rb OUT
bench/upstream/zjit_gap_bet/stats_queue.sh OUT master-0d399335b7:zjit:shipit ...
bench/upstream/zjit_gap_bet/probe_versions.sh h6-5c4239a16d shipit OUT
CPU=2 bench/upstream/zjit_gap_bet/scope_hm_run.sh OUT 10 scope_hm
```
