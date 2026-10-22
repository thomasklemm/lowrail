# Y2: YJIT exits and final send fallbacks on Rails requests

2026-10-22. **One narrow Class/Module `super` exemption qualifies for handoff.**
Fork only; no upstream PR, issue or comment was opened. No Lowrail runtime
change, whole-request speed claim or Campfire support claim.

Ruby master was pinned and re-fetched at
[`8ff4ae1`](https://github.com/ruby/ruby/commit/8ff4ae135d438314090f0dc23916601ef9c444d5).
Clean fork commit
[`df0fa8f`](https://github.com/thomasklemm/ruby/commit/df0fa8fc9de28e5e39220e58798d549e4ac54e32),
`thomasklemm/ruby:thomasklemm/yjit-exits`, is based directly on that master.
Author and committer: Thomas Klemm <github@tklemm.eu>; no trailers.
Only seven source lines and two YJIT regression tests change. Diagnostic
instrumentation is **not** in that commit.

[Machine-readable evidence](yjit-exits.json) preserves all twelve request
screens, seeds 0/1, response digests, nonzero refusal/exit/final-fallback
sites, every native global counter, all 90 timing observations, instruction
counts, test receipts, counterexamples, bundle locks, policies and diagnostic
patches. [The consolidator](../bench/experiments/yjit_exits_report.rb) checks
cross-cohort exactness and accounting, rather than merely formatting totals.

## Request result and residuals

Counts below are the original **unseeded**, untimed 300-request windows
after 1,200 warmup requests, except the separately labelled final attempt
census. Each entry is base → patch.

| Signal | Blog GET `/articles/1` | Fizzy GET `/buckets` |
|---|---:|---:|
| Singleton-super refusals / request | **141 → 13** | **300 → 16** |
| ERBUtil `html_escape` super / request | **115 → 0** | **249 → 0** |
| Stock `num_send_dynamic` (normal returns) / request | **611 → 483** | **1,333 → 1,049** |
| Actual dispatch attempts, final census / request | **616 → 488** | **1,304 → 1,020** |
| Side exits / request | 6 → 6 | 15 → 15 |
| Newly compiled blocks / window | 12 → 12 | 12 → 12 |
| Newly compiled block IDs / window | 7 → 7 | 7 → 7 |
| Invalidations / code GC / window | 0 / 0 → 0 / 0 | 0 / 0 → 0 / 0 |

The remaining **13 / 16 singleton-super refusals are all one PC**:
`ActiveSupport::LoggerThreadSafeLevel#level`,
`active_support/logger_thread_safe_level.rb:36`, bytecode offset 8.
Its body is `local_level || super`. A separate TracePoint/ObjectSpace probe
in both real requests observed `self.class == ActiveSupport::Logger`,
`self.is_a?(Module) == false`, with an existing singleton class. TaggedLogging
clones and extends the logger instance. **This is an ordinary singleton
object, not a missing Class/Module subcase; retain the refusal.** The probe
does not create singleton classes to identify them and is not a timing run.

All other singleton-super sites become zero:

| Site, source line / bytecode offset | Blog base → patch | Fizzy base → patch |
|---|---:|---:|
| ERBUtil `html_escape`, erb/util.rb:15 / 18 | 115 → 0 | 249 → 0 |
| AR `respond_to_missing?`, dynamic_matchers.rb:10 / 21 | 4 → 0 | 4 → 0 |
| AR `scope_attributes?`, scoping/default.rb:56 / 1 | 3 → 0 | 2 → 0 |
| UserAgent Version `new`, user_agent/version.rb:10 / 56 | 3 → 0 | 3 → 0 |
| AM `resolve_attribute_name`, attribute_methods.rb:397 / 6 | 2 → 0 | 20 → 0 |
| AR `new`, inheritance.rb:76 / 116 | 1 → 0 | 0 → 0 |
| GlobalID `build`, uri/gid.rb:98 / 109 | 0 → 0 | 1 → 0 |
| Time `===`, time/calculations.rb:20 / 3 | 0 → 0 | 3 → 0 |
| Serializer `detect_format`, serializer_with_fallback.rb:103 / 3 | 0 → 0 | 1 → 0 |
| AR `block in find_by`, core.rb:320 / 180 | 0 → 0 | 1 → 0 |

The entropy harness adds its own `clock_time` super calls in seeded windows;
these are separately retained, not included in the unseeded table.
Seeded bodies, complete headers and both full 300-response sequences match
across base/A/A/diagnostic/patch in every screen. This is not a full Rails
suite or `lowrail verify` result.

## Count-ranked final fallback reasons

Ranked by the sum of the two app rates, not by estimated time saved. Rates
are final dynamic dispatch attempts, attributed to the latest refusal when
generating `gen_send_dynamic`, **not sums of all stock `send_*` counters**.
The finalized site census uses the same master, fixtures and two-seed
harness as the first screen. The complete per-app rankings and every site
are in the JSON.

| Rank / reason | Blog | Fizzy | Leading sites / upstream check / decision |
|---|---:|---:|---|
| 1. `invokesuper_singleton_class` | 141 | 300 | ERBUtil `html_escape` 115/249. **Qualified: 13/16 remain, all ordinary logger objects.** No matching open YJIT exemption found. |
| 2. `send_forwarding` | 114 | 200 | Controller `session` 10 on blog; WhereClause `empty?` 8/31, `current_scope` 8/19. Master still refuses. [#18326](https://github.com/ruby/ruby/pull/18326) is **ZJIT**, not YJIT coverage. Forwarded callinfo/arguments need a larger implementation; defer. |
| 3. `send_megamorphic` | 12 | 216–245 | Fizzy Arel `visit` at visitor.rb:28 / 8 contributes 25–35; `_reflections` 23. No matching small YJIT fix found. More versions/inlining trades code size for receiver coverage; do not simply raise limits. |
| 4. `send_singleton_class` | 94 | 112 | Logger `level`/`local_level`, 13/16 at several PCs. [Bug #20209](https://bugs.ruby-lang.org/issues/20209), [#9693](https://github.com/ruby/ruby/pull/9693): deliberate retention boundary. **Do not remove it.** |
| 5. `send_cme_not_found` | 10 | 79 | Asset `compute_asset_host` and `asset_path` contribute 2/34 each. Preserve `method_missing`; no bounded exact admission established. |
| 6. `send_iseq_kw_splat_non_nil` | 41 | 35 | Importmap preload tags 7 and I18n `resolve` 4 on blog; verifier `generate` and `create_message` 3 each on Fizzy. Exact keyword conversion/copy semantics matter; do not remove the check. |
| 7. `send_iseq_has_no_kw` | 27 | 48 | `token_tag` 4 on blog; asset `resolve_asset_source`, DB `select` and `log` 5 each on Fizzy. Master retains argument-setup refusal; VM PRs below are not direct YJIT coverage. Defer. |
| 8. `invokeblock_symbol` | 19 | 51 | Array `each` 11/45; `map` 3/4. Master retains Symbol-handler fallback. No matching focused open YJIT implementation found; larger block dispatch work, defer. |
| 9. `send_iseq_missing_optional_kw` | 31 | 31 | `messages_for` 4 on blog; `exec_main_query` 4 on Fizzy; HashWithIndifferentAccess construction in both. Requires correct missing-keyword frame/default setup; defer. |
| 10. `send_cfunc_block_arg` | 13 | 48 | `resolve_attribute_name` 2/20; Fizzy `compact_blank` 7. C-call block-handler semantics, not this receiver exemption; defer. |

Remaining ranked reasons (blog/Fizzy): ISEQ block not inlined 18/26,
ISEQ block-argument type 17/21, optimized-method block argument 14/19,
forwarded super 12/19, rest plus supplied keywords 11/18, Proc block handler
3/23, super keyword splat 6/15, arity mismatch 11/9, defined-class mismatch
6/5, trailing positional arguments 3/6, super keyword arguments 2/6,
GC-unsafe ISEQ block argument 0/7, positional splat with keywords 5/2,
captured rest arguments 2/4, non-ISEQ/non-C super target 2/2 and dynamic-send
null method ID 2/2. Equal-count ties have no significance. The JSON supplies
the exact sorted per-app lists; none was prototyped here.

### Accounting and process-profile caveat

The stock prefixes are not an additive fallback census: Fizzy's
`send_bpp_dispatch` counts **9 successful block-parameter-proxy dispatches**,
not fallback sends. Also, native **`num_send_dynamic` increments after the
VM call**, so calls leaving nonlocally do not increment it. For example,
blog I18n `resolve` has four final keyword-splat dispatches/request and zero
normal returns at that PC. The finalized census measures attempts **before**
the VM call and normal returns **after**, retaining both.

All **30 instrumented windows** reconcile each retained reason/site sum to
its native global counter and each opcode exit sum to `side_exit_count`.
The **24 v2/v3 windows** additionally reconcile normal-return counts per
site and globally to `num_send_dynamic`. The **12 finalized v3 windows**
reconcile pre-call attempts to an independent global and each corresponding
native refusal reason. There are zero unclassified or unregistered sites.
Successful/general `num_*` site maps and zero site deltas are omitted to
keep the file bounded; native globals are retained. The earlier hypothesis
that blog's four extra keyword-splat refusals were overlapping counts was
wrong: they are real dispatches absent from the post-call count.

Unchanged Fizzy A/A processes produced two dispatch profiles: **1,333 or
1,302 dynamic sends/request**, megamorphic **245 or 216**, plus two other
sends. This also happens in the clean base binary, so it is **not attributed
to the patch or diagnostic instrumentation**. The final diagnostic base/
patch pair is 1,302 → 1,018; the earlier uninstrumented pair is
1,333 → 1,049. **Both remove exactly 284**, exclusively singleton super.
These are normal-return counts; final pre-call attempts are 1,304 → 1,020.
Blog attempts are 616 → 488 versus normal returns 611 → 483. Both metrics
show the same optimization delta. No screen is discarded or rerun to hide
this variation. The counter-placement finding is a separate stats candidate,
not part of the super fix.

All 763 open ruby/ruby PR titles/bodies were searched. Focused all-state
searches for YJIT/super/singleton and `invokesuper_singleton_class` found no
matching Class/Module exemption. ZJIT [#19351](https://github.com/ruby/ruby/pull/19351),
[#19484](https://github.com/ruby/ruby/pull/19484) and #18326 do not cover these
YJIT refusals. [#6920](https://github.com/ruby/ruby/pull/6920) and
[#17629](https://github.com/ruby/ruby/pull/17629) overlap VM keyword/splat/
dispatch mechanics, not this YJIT guard; [#6674](https://github.com/ruby/ruby/pull/6674)
is Module#===. Bug-tracker searches also found closed keyword-correctness
issues [#20195](https://bugs.ruby-lang.org/issues/20195) / [#20012](https://bugs.ruby-lang.org/issues/20012),
module/refinement-super [#22309](https://bugs.ruby-lang.org/issues/22309) and
closed define_method/super crash [#22116](https://bugs.ruby-lang.org/issues/22116).
These are semantic context, not evidence of an already-implemented
exemption. The collected PR list and its full-response hash are retained.

## Side exits and invalidations

| Reason / site | Blog / request | Fizzy / request |
|---|---:|---:|
| Modified block parameter; BroadcastLogger dispatch + Fizzy `link_to` | 1 | 8 (7 at `link_to`) |
| `expandarray_splat`; callback `run_callbacks` | 2 | 3 |
| Splat-array length guard; rendering helper `_layout_for` | 1 | 1 |
| Non-fixnum comparison; `rack_status_code` | 1 | 1 |
| Unimplemented `setblockparam`; BroadcastLogger `dispatch` | 1 | 1 |
| Non-nil `splatkw`; relation delegation `create` | 0 | 1 |

These stay unchanged with the patch. No invalidation or code GC occurs in
the unseeded 300-request windows. Seed 0 instead records **7 / 9 constant-IC
fill invalidations per entire window**, not per request; seed 1 records
zero. The final diagnostic attributes seven to entropy `bytes`/
`random_bytes` PCs; Fizzy adds two at ActiveSupport `at_with_coercion`.
Thus the first seeded window is not JIT-flat, and neither is the unseeded
window with its 12 compiled blocks. No throughput comparison is claimed.

## Why the exemption preserves the boundary

Before: singleton `self` → refuse specialized super, including Class/Module.
After: Class/Module `self` → existing specialized super; ordinary singleton
objects → the same refusal as before.

The ancestor is still taken from the **running method's defining class**,
not assumed equal to the runtime receiver's singleton class. The existing
kind-of check, running-CME guard and dependencies on **both** the current
method entry and super target remain unchanged. Therefore an inherited
class method running with a subclass as `self` does not look up super from
the wrong singleton class. CME means callable method entry.

[#20209](https://bugs.ruby-lang.org/issues/20209) / #9693 refused ordinary
singleton objects because YJIT can bake the receiver into a guard, or keep
it alive indirectly through a baked CME → singleton class → attached
receiver. That can retain a request-local object. The exception is the
**same Class/Module policy already used by ordinary YJIT sends**. In these
Rails sites the receivers are named classes/modules already reachable from
constants, not request-local logger instances, so compiling their super
does not newly keep those receivers alive. **Do not generalize this to a
universal leak-free or collectability guarantee for anonymous classes or
modules.** The patch deliberately uses the existing comment's qualified
“tend to be retained” wording.

### Semantic and test gates

* `make yjit-check`: **374 Rust tests**, **2,134 bootstrap tests** and
  **151 Ruby YJIT tests / 714 assertions**, zero failures/errors, one skip.
* `make test-all TESTS='ruby/test_keyword.rb ruby/test_call.rb ruby/test_method.rb ruby/test_module.rb ruby/test_refinement.rb'`
  with interpreter, YJIT and ZJIT `RUN_OPTS`: **673 tests / 10,002 assertions
  in each mode**, zero failures/errors/skips.
* The two added tests check compiled super for differing subclass self and
  module_function copies with extended and singleton-prepended modules.
  Running them against the saved clean master fails with **2 / 4 dynamic
  fallbacks**; the patch passes with zero.
* [22 warmed counterexamples](../bench/experiments/yjit_super_checks.rb)
  have identical base/patch outputs in each mode: inherited class-method
  self; module_function copies; extend/prepend into receiver singleton and
  its ancestors; target redefinition/removal/undefinition/restoration;
  define_singleton_method; refinements; and GC compaction. Each checkpoint
  runs 1,000 times, before/after mutations, not just before compilation.
* **Separate observation, not this PR:** the ordinary-object WeakRef probe
  is collectible with interpreter/YJIT in both arms; ZJIT retains it in
  **both** arms. Recorded in the semantic outputs, not suppressed, changed
  or presented as fixed by this YJIT patch.

No AArch64, full ruby-spec/Ruby suite or full Rails suite was run locally.
Campfire was not cheap: it needs a third master bundle, assets and closed
deterministic state; skipped rather than implying coverage.

## Micro gain and unchanged-VM controls

The [micro](../bench/experiments/yjit_super_micro.rb) models the ERBUtil
singleton-prepended escaping chain around a C escaping method using
`CGI.escapeHTML`. Input `<a&b>` must yield `&lt;a&amp;b&gt;`, 15 bytes/call.
One retained cohort: 100 × 2,000 warmup iterations, 2,000,000 measured calls,
ten rotated base/base/patch rounds for all three VMs, CPU 2, NativeBench's
paired estimator with 5,000 bootstrap resamples. Stats are off for timing.
**No timing rerun for green.**

| Mode | Patch elapsed change, 95% interval | Unchanged A/A, 95% interval |
|---|---|---|
| YJIT | **−23.12% [−29.82%, −17.35%]** | −0.84% [−7.86%, +4.95%] |
| Interpreter | −12.57% [−17.17%, −7.85%] | −5.38% [−11.69%, +0.22%] |
| ZJIT | −9.52% [−16.40%, −2.36%] | −3.68% [−9.26%, +0.78%] |

The interpreter and ZJIT wall gains are informational, **not causal speed
claims** for an unrelated YJIT change. The separate untimed 2,000-call
YJIT window has singleton-super/final-send fallbacks **2,000 → 0**, zero side
exits, and one harness/seam ISEQ (21 blocks) compiled in each arm;
allocations match.

To separate real work from timing/code-layout noise, use the unchanged Z3
fixed-getrandom seed shim, GC disabled after warmup for the counted micro,
and the unchanged Callgrind client extension. The seed shim is never used
for timings or requests. Read the **client-request `.1` dump**, not the
process-termination summary. Raw Ir:

| Mode / binary | N=0 | N=5,000 | N=10,000 |
|---|---:|---:|---:|
| Interpreter base / A/A / patch | **3,092** | **7,940,768** | **15,881,233** |
| YJIT base / A/A | 902,847 | 6,666,882 | 12,132,447 |
| YJIT patch | **901,396** | **4,905,999** | **8,611,564** |
| ZJIT base / A/A / patch | **2,969** | **3,705,645** | **7,411,220** |

Interpreter and ZJIT raw counts are **exactly identical at all three N**.
YJIT's N=10,000 minus N=5,000 window removes **1,760,000 instructions**:
**352 Ir/call**, or **32.20%** of marginal work, with identical A/A counts.
The N=0 seam contains one-time JIT work, so do not pretend all three points
are a single line through zero. This is an escaping micro, not a request
RPS result or a headline ruby-bench result.

## Reproduction and handoff

Use the Z3 source at
[`85d877e`](https://github.com/thomasklemm/lowrail/commit/85d877edaaf9713768099b6de77e4d6beb8bb0a8)
for `bench/experiments/jit_hooks.rb`, the entropy fixture/policies and
`bench/experiments/jit_literal_kwrest_seed.c`; use NativeBench at
[`6510cd2`](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8).
The JSON includes actual configurations, bundle Gemfiles/locks and seed
preparation source. Set `BUNDLER_VERSION=4.0.20` **before** setup: Bundler's
autoswitch otherwise re-execs without the Ruby JIT CLI flags. Clone the four
closed SQLite files for each worker, precompile assets and use the retained
entropy allowlists. No app/framework source specialization is installed.

```sh
# Build master and patch separately, saving each executable before rebuilding.
./configure --prefix=/tmp/y2-ruby --enable-yjit=stats --enable-zjit=stats --disable-install-doc
make -j4 && make install

# Use a fresh output directory. Configs are retained under cohorts.*.config.
ruby /tmp/y2-z3/bench/experiments/jit_hooks.rb run CONFIG NEW_OUTPUT
ruby /tmp/y2-z3/bench/experiments/jit_hooks.rb micro MICRO_CONFIG MICRO_OUTPUT

cc -shared -fPIC -O2 /tmp/y2-z3/bench/experiments/jit_literal_kwrest_seed.c -o /tmp/y2/fixed_seed.so
cc -shared -fPIC -O2 -I"$(ruby -rrbconfig -e 'puts RbConfig::CONFIG["rubyhdrdir"]')" \
  -I"$(ruby -rrbconfig -e 'puts RbConfig::CONFIG["rubyarchhdrdir"]')" \
  bench/callgrind.c -o /tmp/y2/lowrail_callgrind.so
env -u RUBYOPT -u RUBY_YJIT_ENABLE -u RUBY_ZJIT_ENABLE \
  LD_PRELOAD=/tmp/y2/fixed_seed.so LOWRAIL_CALLGRIND_EXT=/tmp/y2/lowrail_callgrind.so \
  taskset -c 2 valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=OUTPUT \
  BINARY --disable-zjit --yjit bench/experiments/yjit_super_micro.rb yjit N
# Interpreter: --disable-yjit --disable-zjit, mode interpreter.
# ZJIT: --disable-yjit --zjit, mode zjit. N=0,5000,10000; base/base/patch.
```

Only the clean Ruby commit above is intended for the dedicated PR thread's
Thermos and semantic review. The census patches stay in Lowrail evidence;
they are not upstream implementation. Nothing was written to either main.
