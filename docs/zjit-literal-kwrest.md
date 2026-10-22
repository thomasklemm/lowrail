# Bet Z2: literal keyword rest in ZJIT direct sends

2026-10-22. **Fork-only prototype and PR draft prepared; no upstream post.**
The bounded follow-up to [#19478](https://github.com/ruby/ruby/pull/19478)
removes another **31 blog / 255 Fizzy kwrest fallback increments per request**.
Responses remain exact in the diagnostic Rack screen. The focused ZJIT micro
improves substantially, with its nonzero A/A drift retained. Fixed-seed
interpreter instruction counts agree exactly. **No whole-app speed claim.**

- Ruby implementation and draft: [46631773dd](https://github.com/thomasklemm/ruby/commit/46631773dd402e769190decb23ea44f64cd69dfc),
  branch `thomasklemm/zjit-literal-kwrest`.
- Control is the exact [#19478 head](https://github.com/thomasklemm/ruby/commit/1918cede86eb25a8311c0330aa4a647f5a32db38),
  not unpatched master. That branch/PR was not modified.
- [Evidence JSON](zjit-literal-kwrest.json) retains every timing round, both
  initial and fixed-seed Ir controls, selected runtime counters, exact-response
  digests, test receipts, the deliberately failing mutation control, binary
  hashes, and fixture recipes. Omitted counters are identified, not zeroed.

## Exact step and boundaries

For callers passing static literal keyword slots, remove the values consumed
by named required/optional parameters and build a fresh `NewHash` from the
remaining pairs in caller order. Named defaults keep the existing default
values/keyword-bits convention. Even when all literals match named parameters,
kwrest receives the fresh empty Hash the VM creates. Anonymous `**` with
literals likewise receives the VM's Hash rather than the no-keyword nil case.

Named keywords place a hidden keyword-bits local before kwrest. Compiled entry
already skips it, but the lazy callee stub previously spilled packed arguments
over it. Spill the final kwrest argument directly to `rest_start`; exclude
that already-placed argument from optional-positional gap shifting on stub
exit. No new VM helper, frame format, entry convention or general-inliner
support. The old trivial-return specialization remains unchanged.

Continue to refuse dynamic `**hash`, caller positional splats, literal-keyword
calls with literal or passed blocks (including `&nil`), anonymous positional
`*`, and no-keyword calls to mixed named-keyword/kwrest callees. Missing required
keywords, wrong positional arity and oversized keyword-bit tables retain VM
dispatch. The parent patch's admitted empty-kwrest cases are unchanged.

## Verification

`make zjit-check ZJIT_TEST_FEATURES=disasm ZJIT_TESTS='-j 4'`:
**1,891 passed, 15 skipped**, plus **27 CLI tests, 7,394 assertions**.

`make test-all RUN_OPTS='--zjit' TESTS='test/ruby/test_keyword.rb test/ruby/test_call.rb test/ruby/test_method.rb'`:
**280 tests, 4,541 assertions, zero failures/errors/skips**. Same result with
`RUN_OPTS='--zjit --zjit-inline-max-iterations=0'`.

New HIR/codegen coverage checks remaining-key order, independent mutable Hashes,
Hash defaults, named constant/nonconstant defaults, anonymous `**` forwarding,
and forced callee compilation failure with omitted positional parameters,
rest/post parameters and native-stack-passed arguments. Removing **only** the
stub fix makes the new forced-exit case fail with `Hash (expected set)`;
restoring it passes the full check. This reproduces the historical layout trap
rather than assuming the frame adjustment is needed.

A separate scratch matrix runs 14 asymmetric call/error/side-effect cases
100 times each, across base and patch in interpreter, ZJIT and no-inlining
modes, plus a compaction reference check. All six result files have identical
SHA256. Its source and outcomes are retained in the JSON, not as extra
permanent tests. AArch64, hosted CI, full ruby-spec and full Rails suites were
not run. This is not a `lowrail verify` support claim.

## Focused micro: all rounds retained

[Worker](../bench/experiments/jit_literal_kwrest.rb):
`literal_keywords(right: 3, a: 17, left: 29)` returns 43. Warm the **caller**
with 100 invocations of 2,000 calls, then measure two million calls. Ten serial,
CPU-2-pinned, rotated base/base/patch rounds per mode; stats off for timing.
The existing [paired-round estimator](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8)
resamples whole rounds 5,000 times.

| Mode | Base mean | Patch mean | Paired change [95%] | A/A change [95%] |
|---|---:|---:|---:|---:|
| ZJIT | 266.28 ms | 134.88 ms | −48.85% [−52.28%, −46.00%] | −5.18% [−10.49%, −0.84%] |
| Interpreter | 305.63 ms | 317.47 ms | +3.95% [+0.36%, +7.63%] | +0.53% [−2.93%, +4.30%] |

All 60 timing workers allocate **2,000,007 objects** and return 86,000,000.
Separate untimed stats workers, with inlining on and off, show exactly
2,000,000 kwrest fallbacks → zero and 2,000,000 direct sends in the patch.
The caller and callee execute compiled code, with **zero measured-window
compilation or side exits** in all four stats workers.

The ZJIT A/A interval excludes zero: it is a real control caveat, not silently
discarded or rerun until green. The owner explicitly accepts the much larger
resolved micro effect plus equal interpreter Ir for preparing this upstream
draft, as for #19478. This does **not** turn the cohort into a Lowrail
fixed-heap/JIT-flat accepted speed claim. Interpreter wall time is retained;
equal Ir establishes no added executed interpreter work in this micro, not
universal equal wall time or a verified explanation for its elapsed difference.

## Interpreter Callgrind: hash salt must match

All changed Ruby files, including the fork-only draft, are under `zjit/`.
Use unchanged [bench/callgrind.c](../bench/callgrind.c), with the same micro,
JITs disabled and GC disabled only after warmup in this instruction window.

The initial unseeded comparison was **not** identical: at N=5,000/10,000,
base Ir was 9,678,410 / 19,628,965 and patch Ir was 9,638,410 / 19,548,965.
Exclusive Callgrind function totals locate the entire −8 Ir/call difference
in unchanged `hash.c::any_hash` (560,000 → 480,000 Ir at N=10,000). Its positive
hash-sign normalization executes two additional instructions, four times per
call; Ruby's process-random startup hash salt changes that branch.

A separately declared fixed-seed control uses the tiny
[getrandom shim](../bench/experiments/jit_literal_kwrest_seed.c) to give both
binaries the same startup hash salt. `:left.hash` / `:right.hash` agree across
binaries. **This deliberately destroys randomness. It was used only in the
disposable interpreter Ir control, never in app, stats or elapsed runs. Never
preload it into an application or production process.** All original results
remain in the evidence; no timing cohort was rerun.

| Calls | Base Ir | A/A Ir | Patch Ir | Seam-subtracted Ir/call, all three |
|---:|---:|---:|---:|---:|
| 0 | 2,990 | 2,990 | 2,990 | — |
| 5,000 | 9,678,410 | 9,678,410 | 9,678,410 | 1,935.084 |
| 10,000 | 19,628,965 | 19,628,965 | 19,628,965 | 1,962.5975 |

Objects also agree per window (N + 12). Different window sizes need not have
the same per-call Ir; **at each size, the paired binaries and A/A are exact**.

## Real requests: next-step coverage, not whole-request pricing

Reuse [bet Z's fixtures, overlays and entropy policies](jit-internals.md),
with production Rack `GET /articles/1` and signed-session `GET /buckets`.
No Lowrail lowering is enabled. Each worker has its own copy of the closed
four-database seed. Both full-header/body digests match for seeds 0 and 1
across base/base/patch. Warm 1,200 requests; measure 300 for counters and
allocations. These windows still compile two ISeqs, so are not JIT-flat.

| Metric | Blog base A / base B / patch | Fizzy base A / base B / patch |
|---|---:|---:|
| Kwrest fallback increments/request | 62 / 62 / 31 | 343 / 343 / 88 |
| Direct-send fallback increments/request | 62 / 62 / 31 | 379 / 379 / 124 |
| Objects/request | 2306.23 / 2306.57 / 2306.45 | 3871.21 / 3871.18 / 3870.92 |
| Side exits/300 requests | 10,801 / 10,801 / 10,801 | 14,401 / 14,401 / 14,401 |

Fallback increments are emitted runtime counters, not unique physical calls;
fixed-point optimization may retain multiple counter instructions. No claim
that every historical literal candidate is now direct, no resolved allocation
saving, and no whole-request elapsed experiment in this follow-up.

## Reproduction

Build the #19478 head with the configure flags in the evidence and save the
base executable; apply the fork commit, rebuild/install and save the patch
executable against that same install. Both measured binaries retain the base
revision string from configuration: use their recorded SHA256, not that string,
to identify them. Ruby fork commits use Thomas as author and committer, without
trailers. `origin` is the Thomas fork; `upstream` is `ruby/ruby`.

Prepare source/assets with `script/corpus real-blog-r4` / `script/corpus fizzy`.
Extract `master_bundles` and `policies` from `docs/jit-internals.json` unchanged
into external temporary files; install the bundles with Ruby master and
Bundler 4.0.20. The exact seed-preparation source is in this evidence's
`reproduction.seed_preparation_source`; run it with all four disposable
database URLs, `RAILS_ENV=production`, `SKIP_TELEMETRY=1` and the external
Gemfile. No retained app source or lock changes are needed.

Create a detached worktree at the NativeBench commit above for `script/native-bench`.
Translate the absolute paths in the JSON configs. The micro config contains
the complete worker as `micro_code`; existing `jit_hooks.rb micro CONFIG OUTPUT`
handles rotation and estimation. `jit_hooks.rb run CONFIG NEW_OUTPUT` runs the
exact/stats corpus screens. Pin Bundler before setup to avoid losing JIT flags
to a Bundler autoswitch re-exec; the workers assert actual JIT enablement.

Compile `bench/callgrind.c` against that Ruby's installed headers and the seed
shim as a shared library. For the fixed-seed interpreter control only:

```sh
env LD_PRELOAD=PATH/TO/fixed_seed.so \
  LOWRAIL_CALLGRIND_EXT=PATH/TO/lowrail_callgrind \
  valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=NEW_OUT \
  RUBY --disable-yjit --disable-zjit \
  bench/experiments/jit_literal_kwrest.rb interpreter N
```

Use N=0/5000/10000 and compare the first client-request `.out.1` dump. Never
reuse the seed shim in another kind of experiment. The fork draft is eligible
under the owner's stated rule, but **waits for #19478 review and explicit
approval to post**; remove the draft Markdown from any future upstream diff.
