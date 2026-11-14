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
  as handled, so an [issue draft](#issue-draft-lead-3-shopifyruby-not-filed) follows. **Update (evening): the PR
  attempt stopped at a design question** ([section](#lead-3-pr-attempt-2026-11-14-evening-stopped-at-a-design-question)).
  Recompiling on the miss fixes the repro and the Rails case but barely moves ruby-bench, and the ZJIT team leans
  towards a cheaper fallback instead; a short answer on #776 with one question replaces the issue draft.
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
| 3: polymorphic send, class missing from the profile | 4 classes, 2 profiled: 632.0 / 100.8 / **352.6** (all 4 profiled: ZJIT 126.9) | **+251.8** (+250%) | [Shopify/ruby#776](https://github.com/Shopify/ruby/issues/776) (generic, open, unassigned; "might be handled now?"), [#1031](https://github.com/Shopify/ruby/issues/1031) (recompile triggers, design), #1039 rows 24/25/27 (megamorphic only, unassigned) | PR attempt stopped; [answer on #776](#draft-answer-on-shopifyruby776-not-posted) for Thomas |
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

## Lead 3: PR attempt (2026-11-14 evening): stopped at a design question

Thomas asked for a ruby/ruby PR instead of the issue (DECISIONS exception, 2026-11-14), if a small fix fits the
ZJIT team's design. **No PR.** The fix that fits ZJIT's recompile machinery fixes the repro and the 4-model Rails
case. On ruby-bench, limited to an ISEQ's first version, it gains 1.0% on shipit and 0.16% on railsbench but 0.06% on
lobsters, and it makes sites with more than 8 receiver classes slower; without the limit it makes lobsters and
shipit worse in other ways. The team has also chosen the other direction for this kind of site:
in merged code for polymorphic `yield`, and on k0kubun's lobsters branch for exactly this fallback. Which way lead 3
goes is their decision, so this ends in [one question for #776](#draft-answer-on-shopifyruby776-not-posted), for
Thomas. Prototype, pushed, not opened: thomasklemm/ruby
[`thomasklemm/zjit-poly-miss-recompile`](https://github.com/thomasklemm/ruby/tree/thomasklemm/zjit-poly-miss-recompile)
@ `fc8d729709`, one commit on master [`88ea6fd282`](https://github.com/ruby/ruby/commit/88ea6fd282) (2026-11-14 18:00 UTC).

### How ZJIT handles misses today (master `88ea6fd282`)

* **Recompile exits.** A guard or `SideExit` with `recompile: Some(Recompile)` calls `exit_recompile`. After
  `--zjit-num-exits-until-invalidate` (5) such exits, `invalidate_iseq_version` drops the version and resets the
  ISEQ's call counter, so it profiles again in the interpreter and compiles the next version. Each compile of a
  non-final version re-enables the profiling instructions (`reset_profiles_remaining`), so the exits themselves
  profile. Profiles accumulate across versions in an 8-bucket `Distribution`; a ninth class (or a singleton class
  of a non-module object) makes the site megamorphic, which compiles to a generic send with no arms.
* **Version budget.** `--zjit-max-versions` is 4 per ISEQ. Once a version was invalidated, the last one compiles
  with `no_side_exits` (`CompilePolicy`): getivar/setivar call `rb_ivar_get`/`rb_ivar_set`, caller splats and other
  speculation are skipped. `convert_no_profile_sends` already keeps sends generic in the final version.
* **Who uses recompile exits.** No-profile sends (ruby/ruby#16525, k0kubun, the pattern this prototype copies),
  shape guards (#16589, #16881), Float operands (#17776), `getblockparamproxy` (#17326), `coerce_to` (#19603),
  caller-splat lengths (#18267, `76d4288406`).
* **Who chose not to.** Polymorphic `invokeblock` (#18211, k0kubun, `9c2c8caf28`): "Unlike the monomorphic path
  above, a miss must not side-exit: the site is known to see multiple blocks, so a guard would keep failing and
  recompiling." On `k0kubun/zjit-lobsters7` ([Shopify/ruby#1039](https://github.com/Shopify/ruby/issues/1039)), the
  fallthrough of a class guard chain stays a send and gets cheaper instead: row 24 `46061d1cc6` builds the chain for
  megamorphic sites "with the dynamic send as the fallthrough arm rather than a side exit", row 25 `9ce1c0bff0`
  calls a shared method behind one ancestor guard, row 27 `4e25f5dbac` looks targets up in a per-call-shape class
  table and explicitly accepts `SendPolymorphicFallback`, row 35 `b7dd4346e3` calls such targets JIT-to-JIT. Rows
  24, 25 and 27 have no assignee. [Shopify/ruby#1031](https://github.com/Shopify/ruby/issues/1031) (k0kubun,
  assigned) asks which events should trigger recompilation; on ruby/ruby#19617 tekknolagi wrote "we are in great
  need of a more general solution" for recompile tuning.

### What was tried

* **V1, every version:** `convert_no_profile_sends` also turns a `Send` with reason `SendPolymorphicFallback` into
  `SideExit PolymorphicSendMiss recompile` (new counter `exit_polymorphic_send_miss`), except in the final version.
  Nine added lines plus test updates.
* **V2, first version only** (the prototype): the same, but only while the ISEQ has no earlier version, so these
  misses spend at most one of its versions. Ten added lines. `make zjit-test` 1992 of 1993; the one failure is
  `test_profile_frames_during_direct_jit_to_jit_entry` (no SIGPROF sample in 1M iterations), which also failed alone
  3 times while four Valgrind runs held all cores, then passed 3 of 3 alone on a quieter orb and failed again in the
  next full parallel run. It calls no polymorphic site; the 11-03 lead 3 build saw the same. Not run: test-all and
  btest, because no PR follows.
* **Not retried:** our method-entry build `23273fd8ec` (11-03, on master `9b30fd207f`: railsbench +0.15%, lobsters
  −0.30%, shipit −1.20%; a new HIR instruction and about 350 lines, so it needs the tracker first under DECISIONS).
  It is the polymorphic counterpart of row 25.

### Numbers

Same method as above (pinned Valgrind 3.19.0 with the 512 MiB brk reservation, tool SHA-256 `6ad7588e…` built on
this orb, fixed heap, JIT-flat gate, A/A; every reported Callgrind cell passes the gate, no log has `brk segment
overflow`). YJIT and ZJIT columns are master `88ea6fd282`. Scripts in
[fixtures/corpus/zjit-leads/zl3](../../fixtures/corpus/zjit-leads/zl3) (the stats runs use the gap harness, which
now also records compiles, `zjit_alloc_bytes` and peak RSS); receipts (logs, per-run JSON, the V1 patch; no Callgrind
dumps) in [`data/zjit-leads/zl3-receipts.tar.gz`](data/zjit-leads/zl3-receipts.tar.gz).

**Micro, Ir per call** (`micro.rb`; K classes, P of them before compile; A/A identical to 0.1 Ir):

| case | YJIT | ZJIT master | V1 | V2 | compiled ISEQs master → V1 / V2 |
| --- | ---: | ---: | ---: | ---: | --- |
| class method, 4 classes, 2 profiled | 100.8 | 352.6 | 134.0 | 137.3 | 2 → 3 / 3 |
| class method, 4 classes, all profiled | | 126.9 | 126.6 | 126.6 | 2 → 2 / 2 |
| #59141 shape, 4 classes, 2 profiled | 211.7 | 629.6 | 211.0 | 214.3 | 3 → 5 / 5 |
| class method, 8 classes | 268.3 | 305.4 | 152.7 | 152.8 | 2 → 3 / 3 |
| #59141 shape, 8 classes | 466.2 | 546.4 | 268.7 | 269.0 | 3 → 5 / 5 |
| **class method, 12 classes** | 354.9 | 402.0 | **577.8** | **577.8** | 2 → 3 / 3 |
| **#59141 shape, 12 classes** | 588.1 | 725.3 | **1,036.8** | **1,036.8** | 3 → 5 / 5 |
| class method, 12 classes, 2 profiled | 354.9 | 502.9 | 576.8 | 347.1 | 2 → 4 / 3 |
| #59141 shape, 12 classes, 2 profiled | | 907.9 | 1,035.8 | 591.6 | 3 → 7 / 5 |
| 1 class (control) | | 109.4 / 162.4 | same | same | unchanged |

With 12 classes the recompiled profile overflows its 8 buckets, the site turns megamorphic and loses the arms the
first version had: +44% in both variants.

**Rails main, 4 models** (`ar_poly.rb`, Ir per op, mean of a/b; A/A ≤ 0.04%):

| | YJIT | ZJIT master | V1 | V2 |
| --- | ---: | ---: | ---: | ---: |
| all 4 models before compile | 92,594.8 | 109,467.7 (+18.2%) | 97,139.5 (+4.9%) | 98,731.2 (+6.6%) |
| 2 models before compile | 93,088.6 | 133,218.5 (+43.1%) | 97,123.3 (+4.3%) | 99,193.8 (+6.6%) |
| compiled ISEQs at the end | 851 | 715 / 714 | 751 / 755 | 739 / 742 |

Percentages are against YJIT. `send_polymorphic_fallback` per op: 50 / 103 on master, 0 / 0 with either variant.

**ruby-bench main `0e67be03ef`, ZJIT counters per iteration** (one stats run per cell: 40 warmup, then 10
iterations; compiles and memory are whole-process at the end of warmup; `--zjit-exec-mem-size=512
--zjit-mem-size=1024`, no `compile_error_out_of_memory` anywhere):

| | railsbench master → V1 → V2 | lobsters master → V1 → V2 | shipit master → V1 → V2 |
| --- | --- | --- | --- |
| `send_fallback_send_polymorphic_fallback` | 30,483 → 0 → 9,057 | 259,460 → 34,697 → 194,867 | 788,029 → 109,141 → 589,383 |
| `send_fallback_send_megamorphic` | 189,766 → 189,766 → 189,766 | 118,320 → **373,919** → 143,690 | 120,896 → **685,995** → 207,609 |
| `getivar_fallback_no_side_exits` | 0 → 0 → 0 | 144,770 → **231,121** → 149,147 | 335,358 → **895,635** → 340,749 |
| `dynamic_send_count` | 1,083,889 → 1,053,406 → 1,062,463 | 783,747 → **841,654** → 746,529 | 1,877,795 → 1,773,924 → 1,771,904 |
| compiled ISEQs | 2,605 → 2,688 → 2,655 | 6,367 → 7,014 → 6,641 | 5,943 → 6,614 → 6,219 |
| code region (MB) | 10.30 → 10.66 → 10.53 | 31.25 → 34.59 → 32.56 | 25.92 → 29.33 → 27.16 |
| `zjit_alloc_bytes` (MB) | 7.48 → 7.57 → 7.55 | 18.57 → 19.38 → 18.92 | 16.19 → 17.00 → 16.51 |

V1 sends ISEQs into their no-side-exit final version (getivar falls back to `rb_ivar_get` 86k and 560k more times
per iteration) and turns sites with many classes megamorphic; lobsters ends with more dynamic sends than master.
V2 avoids most of the final-version cost but keeps part of the megamorphic shift. Railsbench's
`inline_iseq_optimized_send_count` drops by 18,041 in both variants (`iseq_optimized_send_count` +32,037): some
recompiled callers stop inlining a callee. Not traced.

**ruby-bench Callgrind, V2 only** (Ir per iteration, 3-iteration window after 40 warmup iterations and the flat
windows; GC counted, fixed heap):

| | master a / b | V2 a / b | V2 − master | compiled ISEQs at the window's end |
| --- | --- | --- | ---: | --- |
| railsbench | 4,904.1 / 4,902.4 M (A/A 0.03%) | 4,895.9 / 4,895.1 M | **−0.16%** | 2,562 → 2,610 |
| lobsters | 2,498.9 / 2,498.6 M (A/A 0.01%) | 2,497.3 M / rejected | −0.06% | 6,339 → 6,615 |
| shipit | 3,761.0 / 3,762.0 M (A/A 0.03%) | 3,727.7 / 3,721.6 M | **−0.98%** | 5,902 → 6,170 |

Rejected: lobsters V2 run b compiled one ISEQ and 8 side exits inside the measured window (gate fail, 2,496.6 M);
kept in the receipts, not used, not rerun.

### Why this stops here

* **The design choice is open and the team leans the other way.** Recompiling on a polymorphic miss is what
  k0kubun ruled out for polymorphic `yield`, and his lobsters branch makes this same fallback cheaper instead
  (rows 24/27). A PR that recompiles would answer #1031's open question by itself.
* **Its value depends on megamorphic handling.** Sites with more than 8 classes lose their arms after the
  recompile (+44% in the micro, +25k / +87k megamorphic sends per iteration on lobsters / shipit with V2). Row 24
  would turn exactly those sites back into guard chains, so the two would have to be weighed together.
* **The app effect is uneven.** Shipit gains 1.0% and railsbench 0.16%, both outside the A/A, but lobsters, where
  round 2 counted the most lead 3 fallbacks against YJIT (171k per iteration), moves 0.06%: V2 removes only 64k of
  its 259k polymorphic fallbacks and adds 25k megamorphic sends. No `run_benchmarks.rb` timing was taken, which
  DECISIONS asks of a ZJIT performance PR.

### Draft answer on Shopify/ruby#776 (not posted)

> Not for receiver classes that first show up after compilation, I think. The arms cover the classes from the
> profiled calls, and any other class takes the `send_polymorphic_fallback` send for good:
>
> ```ruby
> class Model; def self.types = 1; end
> MODELS = Array.new(4) { Class.new(Model) }
> def read(m) = m.types
> 100.times { read(MODELS[0]); read(MODELS[1]) } # compiled with arms for 2 classes
> 100.times { MODELS.each { read(_1) } }         # 200 of these 400 calls take the fallback
> ```
>
> I tried turning that fallback into a recompile exit in an ISEQ's first version, as for `NoProfileSend`
> ([branch](https://github.com/thomasklemm/ruby/commit/fc8d729709)). That removes the fallbacks above and cuts a
> 4-model Active Record loop by 10–26%. On ruby-bench (Callgrind) it is −1.0% on shipit, −0.16% on railsbench and
> −0.06% on lobsters. Sites with more than 8 classes turn megamorphic after the recompile and lose their arms (+44%
> in a 12-class micro), and without the first-version limit lobsters and shipit reach their no-side-exit final
> versions much more often.
>
> Should a miss here recompile, or should the fallback get cheaper instead, like the guard chain and class table
> on zjit-lobsters7?

### For Thomas (German)

ZJIT übersetzt einen Aufruf wie `model.types` mit je einem schnellen Zweig für die Klassen, die es in den fünf
Aufrufen vor dem Kompilieren gesehen hat; jede später auftauchende Klasse nimmt für immer den langsamen generischen
Aufruf, während YJIT sie einfach an seine Kette anhängt. Die Änderung springt bei fremden Empfängern zurück in den
Interpreter, der sie profiliert, und kompiliert die Methode einmal neu; das ist sicher, weil der Interpreter den Aufruf genau
wie bisher ausführt und danach nur Zweige dazukommen, und der Minimalfall braucht so 2,6-mal weniger Instruktionen
pro Aufruf, shipit 1 % weniger. Einen PR öffnen wir trotzdem nicht, weil railsbench und lobsters kaum gewinnen, Aufrufstellen mit mehr als
acht Klassen dabei ihre Zweige verlieren und k0kubun für denselben Fall bei `yield` bewusst gegen das Zurückspringen
entschieden hat; welche Richtung gilt, soll das ZJIT-Team in #776 sagen.

```ruby
class Model; def self.types = 1; end
MODELS = Array.new(4) { Class.new(Model) }
def read(m) = m.types
100.times { read(MODELS[0]); read(MODELS[1]) } # ZJIT kompiliert read mit Zweigen für die ersten zwei Klassen
10_000.times { MODELS.each { read(_1) } }      # die anderen zwei: 20.000 von 40.000 Aufrufen generisch
```

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

**Built as VB1** (2026-11-14, [record](../../bench/upstream/vb1/README.md), queue item
[VB1](../../bench/upstream/pr-queue/items/VB1.md), not opened): both `&:value!` lines plus `map(&:deep_dup)` in
`LazyIndexedAttributeSet#deep_dup`, the third Symbol block on that class, which every record `dup` runs. At 30
columns, 10 records each read once: interpreter −2.5%, YJIT −7.5%, ZJIT −20.6%; `dup` −1.9% / −5.7% / −12.3%;
railsbench-like request mix under ZJIT −0.58%. The `value_at!` line is in the measured reads (`id`).

## Not done

* The megamorphic-send growth on shipit and lead 4 (protected calls).
* Pricing the Rails change on ruby-bench railsbench with Rails main (estimate above only; VB1 measured a
  railsbench-like request mix instead).
* Tracing the ruby-bench lead 3 sites one by one against the repro mechanism.
* Lead 3 prototype: test-all and btest at `--zjit-call-threshold=1`/`2`, `run_benchmarks.rb` timings, and why
  railsbench recompiles inline 18k fewer sends per iteration. Only if the ZJIT team wants the recompile.
