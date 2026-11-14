# ZJIT leads 3 and 7: repros, existing coverage, drafts (2026-11-14)

Follow-up to the unowned buckets of [Ruby master round 2](ruby-master-round-2.md#zjit--yjit-buckets), where ZJIT runs
+3.39% more Ir than YJIT on railsbench. Lead 3 is class-polymorphic sends (`send_polymorphic_fallback`), lead 7 is
`&block` forwarding (`send_block_arg_not_nil`). Measured on ruby/ruby master
[`674c477295`](https://github.com/ruby/ruby/commit/674c477295) (2026-11-14 14:48 UTC), which has no `zjit/` change
since round 2's `b7e8fad022`, so round 2's app counters still describe it. Nothing was opened, posted or filed.
The megamorphic-send growth and lead 4 were not started.

**Short answer.**

* **Lead 3 is a real ZJIT-only gap and has no issue of its own.** A polymorphic send gets one arm per class seen
  in its profiled calls. Every other class goes to a generic send that never recompiles. YJIT grows its class
  chain at run time. Minimal repro: one call site, 4 classes, 2 of them seen before compile. ZJIT takes the generic
  path on half the calls, YJIT on none: 352.6 against 100.8 Ir per call (3.5×). On Rails main with 4 models, ZJIT
  runs +18% Ir per op against YJIT, +43% when 2 models ran before compile.
  [Shopify/ruby#776](https://github.com/Shopify/ruby/issues/776) is the generic tracker and is close to being closed
  as handled, so an [issue draft](#issue-draft-lead-3-shopifyruby-not-filed) follows.
* **Lead 7 is covered; stopped.** Forwarding a block param (`def m(&b) = n(&b)`) and forwarding sites that see both
  nil and a block fall back only in ZJIT (+266 / +271 Ir per call over YJIT). That is
  [Shopify/ruby#1014](https://github.com/Shopify/ruby/issues/1014) and [Shopify/ruby#1039](https://github.com/Shopify/ruby/issues/1039)
  row 7 (k0kubun, `93e4e7d69c`, assigned). No draft.
* **Correction to round 2: rails/rails#59141 does not forward `&block`.** Its `send_block_arg_not_nil` site is
  `cast_value(@ctx.name_at(index), index, &:value!)` in `LazyIndexedAttributeSet#fetch_value_at!`: a **Symbol**
  block argument, on every first read of an attribute. **YJIT falls back there too** (`send_iseq_block_arg_type`),
  so it is not a ZJIT−YJIT gap. A two-line Rails change (block literal instead of `&:value!`) removes the generic
  call in both JITs and is cheaper in all three modes: **−1.5% interpreter, −9.9% YJIT, −12.8% ZJIT** Ir per
  record-load op in an Active Record micro on Rails main. That is a Rails PR candidate, not a ZJIT one.

## Summary

| lead | repro (Ir per call: interp / YJIT / ZJIT) | ZJIT − YJIT | existing coverage | next step |
| --- | --- | ---: | --- | --- |
| 3: polymorphic send, class missing from the profile | 4 classes, 2 profiled: 632.0 / 100.8 / **352.6** (all 4 profiled: ZJIT 126.9) | **+251.8** (+250%) | [Shopify/ruby#776](https://github.com/Shopify/ruby/issues/776) (generic, open, unassigned; "might be handled now?"), [#1031](https://github.com/Shopify/ruby/issues/1031) (recompile triggers, design), #1039 rows 24/25/27 (megamorphic only, unassigned) | [Issue draft](#issue-draft-lead-3-shopifyruby-not-filed) for Thomas |
| 7a: forward a block param (`&b` → proxy) | 978.3 / 158.2 / **424.4** | **+266.2** | [Shopify/ruby#1014](https://github.com/Shopify/ruby/issues/1014) + #1039 row 7 (k0kubun) | stop (covered) |
| 7b: forwarding site sees nil and a block | 1,071.8 / 178.2 / **448.9** | **+270.7** | same (row 7's `split_nil_block_arg`) | stop (covered) |
| 7c: `&:sym` (rails/rails#59141's `fetch_value_at!`) | 796.3 / 538.2 / 537.4 | −0.8 (both JITs generic) | Shopify/ruby#1014 (dak2 lists `&:foo` as a later step); YJIT has no Symbol case either | [Rails-side change](#rails-side-option-a-block-literal-in-fetch_value_at) |

## Method and pins

* **Ruby** master `674c477295`, `--enable-yjit --enable-zjit --disable-install-doc`, GCC 14.2.0, rustc 1.100.0,
  release build, default JIT options (`--zjit` call threshold 30, 5 profiled calls; YJIT `SEND_MAX_DEPTH` 5).
* **Rails** main [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b)
  (round 2's pin) by path, sqlite3 2.10.2 in-memory. Rails main today still has both `&:value!` lines.
* **Valgrind:** the pinned 3.19.0 with the 512 MiB brk reservation, built on this orb with `script/bench-valgrind`
  (patch `ab95c4a3…`; tool SHA-256 `72464017…`, which differs from round 2's orb only by build host). None of the
  194 logs has `brk segment overflow`.
* **Windows:** [`bench/callgrind.c`](../../bench/callgrind.c) client dumps, `--instr-atstart=no
  --smc-check=all-non-file`; Ir per call = (Ir of an N-call window − Ir of an empty window) / N, from each dump's
  `totals:`. Micros: N = 100,000 calls in chunks of 100, so the JITs compile the loop itself. Active Record: N = 2,000 ops.
  GC counted; 0 GCs in every window with `RUBY_GC_HEAP_INIT_BYTES=33554432`.
* **JIT-flat gate:** warm windows until the compile counters are unchanged twice in a row (YJIT compiled ISEQs,
  blocks, invalidations; ZJIT compiled ISEQs, compiled side exits, `invalidation_time_ns`), and unchanged over the
  measured window. **Every reported JIT cell passes.**
* **A/A:** two runs per cell. Micros are identical to 0.1 Ir; Active Record cells agree within 0.02%.
* **Rejected cohort:** the first Active Record run loaded the Callgrind extension after warmup. That defined a
  constant, and ZJIT compiled 1 ISEQ and 55–61 side exits inside the window. All four ZJIT cells failed the gate
  (sym 164,460 / 164,440, literal 145,627 / 145,702 Ir per op). They are kept and not used. The extension now loads before warmup in all three
  scripts, and the whole Active Record cohort and the micros were rerun once. The micros, which had passed, gave the
  same numbers to 0.1 Ir.
* **Counters:** separate runs with `--zjit-stats-quiet` / `--yjit-stats=quiet`, same warmup, then N calls.
  Fallback sites: `--zjit-trace-fallbacks` summarized with [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb).
* **Scripts** in [fixtures/corpus/zjit-leads](../../fixtures/corpus/zjit-leads): `micro.rb` + `run.sh` (micros),
  `ar_read.rb` + `ar_run.sh` (lead 7 on Rails), `ar_poly.rb` + `ar_poly_run.sh` (lead 3 on Rails), `lead3_repro.rb`
  (the issue's script). Receipts (per-run JSON, logs, counters, summaries, rejected cohort; Callgrind dumps not kept):
  [`data/zjit-leads/receipts.tar.gz`](data/zjit-leads/receipts.tar.gz).

## Lead 3: classes missing from a polymorphic send's profile

**Mechanism** (`zjit/src/hir.rs`, `iseq_to_hir`, `opt_send_without_block` and `send`): when `polymorphic_summary`
finds a polymorphic or skewed profile, ZJIT emits one `CondBranchHasType` arm per profiled class. Each arm is
specialized from that class. The last `if_false` edge goes to a generic `Send` with reason `SendPolymorphicFallback`. That send has no
recompile, unlike a monomorphic `GuardType`'s exit. The profile comes from the ISEQ's last 5 calls before
compilation (`--zjit-num-profiles`). A class that runs only later stays generic for good. YJIT instead adds a class to its
guard chain the first time it shows up, up to 5 (`SEND_MAX_DEPTH`), and only then goes megamorphic.

**Minimal repro** ([`lead3_repro.rb`](../../fixtures/corpus/zjit-leads/lead3_repro.rb)): one call site
`models[i % n].types` on 4 subclasses, all resolving `Model.types`. `read` is compiled while it sees 2 of the 4
classes, then runs with all 4. Counters per call: **ZJIT `send_polymorphic_fallback` 0.5, YJIT dynamic 0.0**.
With all 4 classes before compile, ZJIT has 0.

**Ir per call** ([`micro.rb`](../../fixtures/corpus/zjit-leads/micro.rb) `poly_singleton` / `poly_inst K [P]`):

| case | interp | YJIT | ZJIT | ZJIT − YJIT | generic calls per call (ZJIT / YJIT) |
| --- | ---: | ---: | ---: | ---: | --- |
| class method, 1 class | 434.0 | 95.6 | 109.4 | +13.8 | 0 / 0 |
| class method, 4 classes, all profiled | 632.0 | 100.8 | 126.9 | +26.1 | 0 / 0 |
| **class method, 4 classes, 2 profiled** | 632.0 | 100.8 | **352.6** | **+251.8** | **0.5 / 0** |
| class method, 8 classes (round robin) | 632.0 | 268.3 | 305.4 | +37.1 | 0.36 / 0.35 (both generic) |
| #59141 shape, 1 class | 645.0 | 198.5 | 162.4 | −36.1 | 0 / 0 |
| #59141 shape, 4 classes, all profiled | 1,041.0 | 211.7 | 203.9 | −7.8 | 0 / 0 |
| **#59141 shape, 4 classes, 2 profiled** | 1,041.0 | 211.7 | **629.6** | **+417.9** | **1.0 / 0** |
| #59141 shape, 8 classes (round robin) | 1,041.0 | 466.2 | 546.4 | +80.2 | 0.72 / 0.62 |

The "#59141 shape" is a shared slot reader `read_3 = read_at!(3)` in a module included in every model, called on a
receiver whose class varies. It has two polymorphic sites, so 1.0 per call. With 8 classes and round-robin order,
both JITs run out of entries and the gap is only the price difference of a generic call. The gap needs classes
that the profile missed and YJIT's chain still has room for.

**On Rails main** ([`ar_poly.rb`](../../fixtures/corpus/zjit-leads/ar_poly.rb)): 4 models with the same 2
columns. One op loads 2 records per model from a cached result (`_load_from_sql`) and reads both attributes through
#59141's slot readers. P is how many models ran before the first window.

| | YJIT Ir/op | ZJIT Ir/op | ZJIT − YJIT | ZJIT `send_polymorphic_fallback` / op | YJIT `send_megamorphic` / op |
| --- | ---: | ---: | ---: | ---: | ---: |
| all 4 models before compile | 92,667.9 | 109,580.7 | **+16,912.8 (+18.3%)** | 50 | 0 |
| 2 models before compile | 93,239.5 | 133,282.1 | **+40,042.6 (+42.9%)** | 103 | 0 |

Both modes also make 16 generic calls per op for the `&:value!` reads (lead 7c), so those cancel. Even with every model
running before compile, the profiled calls of a site see only some models, because records of one model load
together. Traced fallback sites, largest first: `attributes_builder` (model_schema.rb:514), `primary_key`
(primary_key.rb:85), `instantiate_instance_of` (persistence.rb:298), `init_internals` (core.rb:922–933),
`strict_loading_mode`/`_by_default`, `_run_initialize_callbacks`, the shared `_read_attribute_N` readers
(attribute_methods.rb:300), `_load_from_sql` (querying.rb:118). The receivers are model classes or
instances of different models.

**Rails reach** (round 2, master `b7e8fad022`; extra ZJIT fallbacks at ISEQs where YJIT makes no generic call,
per iteration): railsbench 30k (≈8.5 M Ir, 5% of the +158.4 M gap), lobsters 171k (≈48.8 M), shipit 574k
(≈193.8 M; lobsters and shipit totals are diagnostic because YJIT failed the gate there). Top sites: `block in
_load_from_sql` (shipit: ZJIT 114k generic calls, YJIT 660), `Type::Value#hash`, `association`,
`current_shard`/`current_role`. On Rails main, #59141's `_read_attribute_N` adds +51 per Lobsters request. The
ruby-bench sites were not traced one by one this round. That they follow this mechanism is consistent with the
counts (YJIT generic at a small fraction of ZJIT's), but not verified site by site.

**Existing coverage** (searched 2026-11-14: Shopify/ruby issues and PRs, ruby/ruby PRs for ZJIT + polymorphic,
megamorphic, reprofile, recompile polymorphic, method entry, send fallback):

* [Shopify/ruby#776](https://github.com/Shopify/ruby/issues/776) "send_without_block_polymorphic happens too
  frequently" (k0kubun, 2025-09, open, unassigned). It asks for multi-class dispatch "like YJIT does", which has since
  landed as the arms above; tekknolagi on 2026-11-06: "I think this might be handled now?". It does not name the
  missing-class case, which this repro shows is not handled.
* [Shopify/ruby#1031](https://github.com/Shopify/ruby/issues/1031) "Adaptive Compilation" (k0kubun, assigned):
  a design issue that asks which events should trigger recompilation; no polymorphic-fallback item.
* Shopify/ruby#1039 rows 24, 25, 27 (megamorphic sites; unassigned) and our closed
  [Shopify/ruby#1099](https://github.com/Shopify/ruby/issues/1099) (data, closed by us as overlapping #995).
  No open ruby/ruby PR; by their descriptions, the open ones nearby (#19791 compresses profile buckets, #18616
  seeds polymorphic arms with shapes) do not change the fallback.
* Our candidate build `thomasklemm/zjit-method-entry-dispatch-v3` (`23273fd8ec`, not opened; see
  [zjit-iseq-leads](zjit-iseq-leads.md#lead-3-our-build-and-its-numbers-2026-11-03)) calls the shared method entry
  for unprofiled receivers. It covers sites whose classes share one entry (all sites in these repros), not
  sites that dispatch to different methods.

So the mechanism has no issue of its own. The draft below could also go to #776 as an answer to tekknolagi's
question; Thomas decides.

**Rails-side option: no.** The polymorphic sites are spread over Active Record (class-level readers on each model,
per-model instances), not one line. For #59141's reader, Rails could copy `@attributes.fetch_value_at!(N)` and its
two `rescue` clauses into every generated `_read_attribute_N`. That turns one class-polymorphic self call into a
monomorphic one, but it undoes the sharing #59141 is for and leaves the other sites alone. Not measured. The fix
belongs in ZJIT.

### Issue draft, lead 3 (Shopify/ruby, not filed)

> **ZJIT: receiver classes missing from a polymorphic send's profile stay on the generic send**
>
> A polymorphic send gets one arm per class seen in its profiled calls; every other class goes to a generic send
> (`send_polymorphic_fallback`) that doesn't recompile. So a class that first shows up after compilation is
> dispatched generically for good. YJIT adds it to its guard chain instead (up to `SEND_MAX_DEPTH`).
>
> ```ruby
> class Model
>   def self.types = 1
> end
> MODELS = Array.new(4) { Class.new(Model) }
>
> def read(models)
>   i = 0
>   while i < 100
>     models[i % models.size].types # every receiver resolves Model.types
>     i += 1
>   end
> end
>
> 100.times { read(MODELS.first(2)) } # compiled while the site has seen 2 of the 4 classes
> 100.times { read(MODELS) }
> RubyVM::ZJIT.reset_stats!
> 1000.times { read(MODELS) }
> p RubyVM::ZJIT.stats.slice(:send_fallback_send_polymorphic_fallback).transform_values { _1 / 100_000.0 }
> ```
>
> On master `674c477295`: `send_polymorphic_fallback` 0.5 per call with `--zjit --zjit-stats-quiet`, and 0 when
> the first loop uses all 4 classes. YJIT has 0 dynamic sends either way. Callgrind, Ir per call after warmup: ZJIT 352.6,
> YJIT 100.8, ZJIT with all 4 classes profiled 126.9.
>
> Active Record hits this because records of one model load together, so a site's 5 profiled calls see only some
> models. With 4 models on Rails main (load 2 records per model, read 2 attributes), ZJIT makes 50
> `send_polymorphic_fallback` per op and runs +18% Ir against YJIT, which goes megamorphic 0 times. Sites include
> `attributes_builder`, `primary_key`, `instantiate_instance_of`, `init_internals` and rails/rails#59141's shared
> `_read_attribute_N` readers. On ruby-bench, the fallbacks that YJIT doesn't match with a generic call at the same
> ISEQ are 30k / 171k / 574k per iteration on railsbench / lobsters / shipit.
>
> Related: #776 (this case isn't handled yet), #1031.

## Lead 7: block arguments other than nil or a Proc

**Mechanism** (`zjit/src/hir.rs`, `type_specialize`, `BlockHandler::BlockArg` to an ISEQ callee): ZJIT
specializes a block argument only when it is statically nil, profiled nil, or profiled as a Proc
(`BlockArgProc`, ruby/ruby#18180). Anything else gets `SendBlockArgNotNil`: the block param proxy that `&b` pushes
for a forwarded block parameter, a site that saw both nil and the proxy, and a Symbol. YJIT
(`exit_if_unsupported_block_arg_type`) handles nil, the proxy and a Proc, and falls back on a Symbol
(`send_iseq_block_arg_type`).

**Repros** ([`micro.rb`](../../fixtures/corpus/zjit-leads/micro.rb); the callee `cast_value(index)` yields only on a
rare path, like Rails'):

| case | interp | YJIT | ZJIT | ZJIT − YJIT | generic calls per call (ZJIT / YJIT) |
| --- | ---: | ---: | ---: | ---: | --- |
| control: `forward(i)` without a block (nil forwarded) | 934.3 | 152.2 | 138.4 | −13.8 | 0 / 0 |
| **7a** `def forward(i, &b) = cast_value(i, &b)`, called with a block | 978.3 | 158.2 | **424.4** | **+266.2** | **1 / 0** |
| **7b** the same, alternately with and without a block | 1,071.8 | 178.2 | **448.9** | **+270.7** | **1 / 0** |
| **7c** `cast_value(i, &:succ)` | 796.3 | 538.2 | 537.4 | −0.8 | 1 / 1 |
| `cast_value(i) { \|a\| a.succ }` (7c with a block literal) | 631.3 | 148.2 | 111.4 | −36.8 | 0 / 0 |

**Existing coverage: stop.** 7a and 7b are [Shopify/ruby#1014](https://github.com/Shopify/ruby/issues/1014)
"Specialize send with non-nil block arg" (k0kubun, open, unassigned) and
[Shopify/ruby#1039](https://github.com/Shopify/ruby/issues/1039) row 7, assigned to k0kubun: `93e4e7d69c` "Pass
a `&blk` argument through to a direct send" handles the proxy and branches nil against non-nil
(`split_nil_block_arg`). Under [DECISIONS](../DECISIONS.md) an assignee
in a tracker row counts as taken; round 2 listed lead 7 as free from #1014's empty assignee field. 7c is in #1014's scope:
its title covers every non-nil block argument, and dak2's comment lists "Symbol block args (`&:foo`)" as a later step.
Row 7 does not handle Symbols. No open ruby/ruby PR (searched ZJIT + block arg, block_arg, blockarg, block param,
getblockparamproxy, `&blk`, forward block, symbol block). No draft.

**Rails reach.** Round 2's top lead 7 sites on ruby-bench (Rails 8.1) are 7a/7b: `_read_attribute(name, &block)`,
`mon_synchronize(&b)`, Notifications `iterate_guarding_exceptions`, `ConnectionPool::Queue#synchronize`
(railsbench 108k, lobsters 88k, shipit 196k extra per iteration). On Rails main, #59141 added 7c (below).

### Correction: rails/rails#59141's site is `&:value!`, not `&block`

Round 2 attributed the new `fetch_value_at!` fallback to `fetch_value_at!(N, &block)` forwarding a nil block. Rails
main has no such call. `_read_attribute_at!(index)` calls `@attributes.fetch_value_at!(index)`, and the only send
with a block argument in `LazyIndexedAttributeSet#fetch_value_at!` (activemodel attribute_set.rb:412) is the cast
path of every first read of an attribute:

```ruby
cast_value(@ctx.name_at(index), index, &:value!)
```

`value_at!` (line 534, the name-keyed `fetch_value!` path) has the same call. Both came with #59141's commits
(`a1656e9f21`, `f547f565e4`); its parent `c48c154e3f` has no `&:value!` on the read path. The ZJIT fallback trace of
`ar_poly.rb` (unpatched Rails main) names attribute_set.rb:412 as the `block argument is not nil` site, and with `&:value!` each
first read is one generic call in **both** JITs:

| `ar_read.rb`, per op (10 records × 5 first reads) | ZJIT `send_block_arg_not_nil` | ZJIT dynamic sends | YJIT `send_iseq_block_arg_type` | YJIT dynamic sends |
| --- | ---: | ---: | ---: | ---: |
| `&:value!` (Rails main) | 50 | 71 | 50 | 60 |
| block literal | 0 | 21 | 0 | 10 |

So round 2's +208 per Lobsters request and +22.5k per railsbench iteration are lead 7c. They are generic in YJIT
too, which matches YJIT's +5.4% dynamic sends there. They add to both JITs' cost rather than to the ZJIT−YJIT gap.

### Rails-side option: a block literal in `fetch_value_at!`

```diff
-        cast_value(@ctx.name_at(index), index, &:value!)
+        cast_value(@ctx.name_at(index), index) { |attribute| attribute.value! }
```

and the same in `value_at!`. Same behavior: the block runs only on the default-attribute path and calls the public
`value!` on its argument, as `&:value!` does.

**Price on Rails main** ([`ar_read.rb`](../../fixtures/corpus/zjit-leads/ar_read.rb); both variants redefine the two
methods identically except for the block; Ir per op, mean of two runs, all gates pass, 0 GCs):

| mode | `&:value!` | block literal | change | per first read | A/A (`&:value!` / literal) |
| --- | ---: | ---: | ---: | ---: | --- |
| interpreter | 484,853.6 | 477,596.4 | **−7,257 (−1.50%)** | −145 Ir | 0.002% / 0.006% |
| YJIT | 164,123.5 | 147,861.9 | **−16,262 (−9.91%)** | −325 Ir | 0.02% / 0.001% |
| ZJIT | 149,904.4 | 130,711.1 | **−19,193 (−12.80%)** | −384 Ir | 0.003% / 0.0004% |

The micro agrees in direction (7c row against the block literal row: −165 / −390 / −426 Ir per call).
**It costs neither the interpreter nor YJIT; all three get cheaper.** Estimated reach, count × per-read saving,
not measured on ruby-bench: railsbench on Rails main about −8.6 M Ir per iteration under ZJIT (22.5k × 384, ≈0.3%),
about −7.3 M under YJIT (≈0.26%) and −3.3 M in the interpreter; Lobsters about −80k Ir per request under ZJIT
(208 × 384). The `value_at!` line was not measured separately.

**Judgment.** Of everything in leads 3 and 7, this is the only change that is small, exact and helps every
mode. Its Rails PR would be ours. The root fix (Symbol block args in ZJIT, and in YJIT, which is in maintenance
mode) belongs to #1014 and would not change the interpreter. No Rails PR was opened.

## Not done

* The megamorphic-send growth on shipit and lead 4 (protected calls).
* Pricing the Rails change on ruby-bench railsbench with Rails main (estimate above only).
* Tracing the ruby-bench lead 3 sites one by one against the repro mechanism.
