# Sealed links: prices and finite delivery results

Status: **stacking backlog, no promotion**. The post-TracePoint-fix series
accepts only interpreter show: **−0.185%**. Interpreter index and both YJIT
cohorts reject their controls; their deltas remain diagnostic. The earlier
pre-fix measurements below are historical diagnostics, not the current result.
The guarded tier and the source-arm quarantine are unchanged. The five-app
[seal census](../sealed-corpus.md) precedes these experiments; the blog is
seal-clean only in the documented, dynamic, test-observed sense.

## Finite experiments, including the rejected certificate

All three studies use Ruby 4.0.7 / Rails 8.1.4, interpreter execution,
seed 41231, six rounds, N=0/200 subtraction and the five fixed heap floors
from the c9d2397 protocol. Independent total/no-GC A/A, actual interpreter
state and heap checks pass. The tool is the pinned 512 MiB Valgrind build,
with the Rails-boot allocation preflight and no brk-overflow warnings.
[Machine-readable results and source/tool fingerprints](sealed-links.json)
retain all three studies, not just the best arm. Raw logs remain private.

| Study / unit | Original Ir | Candidate Ir | Objects | Disposition |
|---|---:|---:|---|---|
| v1, two links, reflective receiver checks | 90,378 | 56,143 | Combined link + route 28 → 48 | Incomplete: `singleton_methods` misses private overrides; not an admissible certificate. |
| v1, one route | 48,978 | 44,291 | Included in row above | −4,687 Ir is an incomplete price, not permission to activate route lowering. |
| v2, two literal-name links, exact method/visibility lookup | 90,587 | 64,392 | 16 → 18 | Private overrides refuse, but per-hit reflection still allocates. No constructor charged in this cached-builder shape. |
| v3, two literal-name links, fresh-builder provenance | 95,638 | 52,762 | 17 → 9 | Positive builder-cost price; startup/view/input/delivery certification and request gates still required. |

V1's allocation attribution was seven `singleton_methods` Arrays and 28
temporary objects from Kernel-owned `UnboundMethod#bind_call` (two/call).
Specific `Module#instance_method` lookup allocates one current UnboundMethod;
bound `Kernel#singleton_class` allocates two temporary objects and can create
an eigenclass. These are not allocation-free predicates. Creating an
eigenclass can also invalidate JIT no-singleton assumptions. V3 never acquires
the builder's singleton class. `Kernel#public_method` is not substituted for
the method-entry lookup: after removal/undef it can invoke application
`respond_to_missing?`, unlike the captured Module lookup.

V2 leaves URL selection, option conversion, escaping and
`PRE_CONTENT_STRINGS` consumption live. Its local fallback calls `content_tag`
with the already-computed arguments; it does not replay conversion. Boundary
probes cover private singleton overrides, singleton prepend, table entries
and default Proc, SafeBuffer, binary/UTF-16/invalid UTF-8 URLs and a String
with an observable once-only `to_s`.

## V3: constructor provenance without a constructor wrapper

`bench/experiments/sealed_provenance.rb` compiles a body edit to Rails'
original `TagHelper#tag_builder` through the existing Compiler/Manifest/Loader
ISeq seam. It does **not** edit `Class#new` or `TagBuilder#initialize` and does
not prepend, alias or attach a singleton class to the builder. The existing
`@tag_builder ||= TagBuilder.new(self)` expression records exactly its new
result in an `ObjectSpace::WeakKeyMap`, before returning it. Merely invoking
`initialize` on a foreign object never grants provenance. A foreign Ractor
takes the stock construction path before accessing the main-Ractor registry.

Paired off/delivered probes have identical constructor owner/source/parameters,
factory owner/source/parameters, constructor call traces, wrong-arity exception
frames, cached-builder identity and view-context identity. ObjectSpace confirms
no instance eigenclass. Four threads each construct/check 50 builders; the
foreign-Ractor construction succeeds unregistered; 100/100 WeakRefs to
discarded builders are collected. These are finite probes, not universal
Ractor/Box/refinement guarantees. Factory bytecode/trace differences remain
subject to SEAL009, not claimed observationally invisible.

V3 measures one fresh builder context per iteration of two links, clearing
the view's cached holder symmetrically in every arm. Off workers use the
unchanged factory; only non-off arms deliver the registration body. A weak-map
lookup occurs at every candidate hit and an insertion at each construction.
Forced GC occurs symmetrically after both N=0 and N=200 windows: total Ir
therefore includes the weak-key cleanup slope; no-GC excludes collection work.
This is a cleanup-stress operation shape, not the production GC schedule.
No cleanup cost is silently moved to warmup. The newly constructed builder
accounts for the check arm's one Ruby object; registration/lookup allocate no
additional Ruby object in the native probe. Internal C storage and weak-map
GC work are priced in Ir, not mislabeled as Ruby allocations.

| V3 arm, two links + fresh holder | Total Ir | No-GC Ir | Objects |
|---|---:|---:|---:|
| Off A | 95,638 | 92,981 | 17 |
| Off B | 95,605 | 92,959 | 17 |
| Residual checks + construction/registration | 19,919 | 19,636 | 1 |
| Live option/URL prelude | 21,377 | 21,106 | 2 |
| Render residue | 20,440 | 19,638 | 6 |
| Whole candidate | 52,762 | 51,417 | 9 |

Total candidate delta is **−44.832% [−44.872, −44.784]** versus off A;
no-GC is −44.699% [−44.726, −44.675]. Separate arm medians are diagnostic,
not additive ablations. Boot/source certification, actual view admissibility,
request authorization, deployment opt-in and delivery refusal behavior are
not justified by a builder-membership check alone. Registered-instance
post-seal structural mutation remains a SEAL001 breach; this registry is
provenance, not mutation detection. The known quarantine counterexamples run
unoptimized under seal-check, rather than being falsely credited as safe
optimized in-flight deoptimization.

## Reproduction

```sh
PATH=/tmp/VALGRIND-brk512/bin:$PATH \
CPATH=/tmp/VALGRIND-brk512/include BENCH_JOBS=2 \
  mise exec -- ruby bench/experiments/sealed_links.rb \
    .corpus/real-blog-r4 /tmp/NEW-price --provenance
# From the prepared blog directory, compare the final JSON metadata:
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 mise exec -- ruby --disable-yjit \
  /path/to/lowrail/bench/experiments/sealed_provenance.rb off
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 mise exec -- ruby --disable-yjit \
  /path/to/lowrail/bench/experiments/sealed_provenance.rb provenance
```

The previous two prices use `sealed_helpers.rb APP NEW_OUTDIR` and
`sealed_links.rb APP NEW_OUTDIR` without `--provenance`. Their executed source
fingerprints are retained; the new optional branch does not retroactively
change those sources. No native YJIT/ZJIT or whole-request gain is claimed.

## Delivered pilot: pre-fix request diagnostics, not a promotion

[The generic eligibility boundary](https://github.com/thomasklemm/lowrail/commit/ca814ae9168946d90e9895e9feb4d85ed68c4c2b)
adds registry `sealed_only`, `build --sealed --env production`, the
`sealed-v1` manifest and explicit production opt-in. Old/mixed artifacts
refuse whole; tests run original-only, without a certificate bypass. This
includes `inertia/config_bind` eligibility, not its promotion. The guarded
`view/link_to` and `route/path` arms remain quarantined. The pilot is the
separate `sealed/link_to` pass; routes stay live and unlowered.

Before request measurement, the existing isolated checker matched **144
pairs** of status, byte body, all headers, ordered SQL, controller/render
events and assigns: **350 hits, zero fallbacks**. The five-app default verify
matched **779 outcomes**, including two unchanged Campfire skips and the
separately selected Redprints browser suite. PingCRM retained nine advisory
cross-thread SQL-order differences; own-thread SQL was identical. AP/AV L3
matched 4,095 / 2,747 outcomes with zero units/hits; AV-AP matched 242. AV-AR
matched 173 with the existing AR units' 122 hits / three fallbacks. These are
not sealed fast-path coverage claims for test processes.

One finite c9d2397 interpreter cohort per route, Ruby 4.0.7, seed 41231,
six rounds, N=0/50, five matched fixed heaps and the pinned 512 MiB Valgrind:

| Route | Off Ir/request | Sealed Ir/request | Paired total delta, 95% CI | Objects off → sealed | Hits/request |
|---|---:|---:|---|---|---:|
| Index | 9,105,767 | 9,286,270 | **+1.974% [1.916, 2.000]** | 2,358.19 → 2,351.14 | 7 |
| Show | 8,750,648 | 9,013,273 | **+2.993% [2.978, 3.037]** | 2,244.25 → 2,242.13 | 2 |

Total/no-GC A/A, actual interpreter/JIT-state and heap controls pass. These
are accepted **pre-fix diagnostic measurements**, not a verdict on link
specialization: activation leaves a global tracing tax after its TracePoint
is disabled. Native `vm_trace` **self**, with N=0/50 no-GC subtraction, is
exactly **0 versus 279,708 Ir/request in all six index rounds**. Inclusive
callee costs are not added to that figure, nor is this tax subtracted to
manufacture a hypothetical post-fix endpoint saving.

### Finite A/B/C decomposition

A second, single finite index interpreter diagnostic uses the same protocol:

| Arm | Meaning | Total Ir/request | Delta versus off, 95% CI | Objects/request |
|---|---|---:|---|---:|
| Off | No setup | 9,099,920 | control | 2,358.57 |
| A | Public sealed setup with zero units | 9,097,992 | −0.030% [−0.080, +0.016] | 2,358.33 |
| B | A + factory body delivery/registration; no dispatch or link sites | 9,422,507 | **+3.538% [3.480, 3.578]** | 2,358.41 |
| C | Full pilot | 9,286,353 | +2.037% [1.983, 2.790] | 2,351.55 |

A returns before installing Guard/Loader/pass activation and has no
activation TracePoint. B executes the actual full activation machinery and
already reproduces the tax **without changing dispatch**: `vm_trace` self is
283,074 Ir/request in every round; A is zero. C is 279,708 in four rounds,
279,876 / 283,173 in the other two. The factory-only arm is therefore enough
to locate the flat tax outside link sites and dispatch; no new dispatch-only
or TracePoint-disabled request cohort was started. The requested targeted
dispatch-inclusive A/C profile was also collected, but its own target
TracePoint perturbs tracing: 7,386,034 → 8,024,321 inclusive Ir is not dispatch
self cost or an accepted request benchmark.

### Whole-file delivery is not the compiler-options explanation

At the real Loader seam, compare each original ISeq with its delivered
binary. `tag_helper.rb` has 22 methods, only `tag_builder` changed;
`metal.rb` has 25, only `dispatch` changed. All **45 unchanged method
subtrees** match after removing only parser IDs, source hashes and source
coordinates. Original/delivered compilation recipe hashes are identical;
`specialized_instruction` is true and `frozen_string_literal` is nil with
source magic comments retained. Address-normalized disassembly diffs of
unchanged `tag_options` and `performed?` are empty.

That refutes differing compilation options for untouched methods, **not**
VM-level trace patching: Ruby disassembly presents trace opcodes as ordinary
instructions, and a disabled global TracePoint can leave sticky tracing
state. The central production activation fix is owned separately; this
pilot does not change it.

### Rejected YJIT and the next gate

The finite pre-fix YJIT index cohort is **rejected**: no-GC A/A and JIT
flatness both fail. Its +32.973% diagnostic delta is retained only in the
[numeric export](sealed-link-pilot.json), never as an accepted result. The
final boot-visibility refusal fix also changed a pinned builder source while
that diagnostic was running, precluding stable-source interpretation. YJIT
show refuses before measurement because the artifact is stale. No retry to
green and no inferred YJIT saving.

Boot visibility now has an independent stock check: a body ISeq fingerprint
alone does not certify visibility. A private `content_tag_string` is refused
at build, with a permanent public-build regression. After the central fix,
rebuild the source-pinned artifact, repeat the correctness gates and run
fresh, finite interpreter **and** YJIT index/show cohorts. Promotion remains
pending; the micro price cannot replace the request gate.

## Post-fix: four finite cohorts, one small accepted result

Measured and published harness head:
[`cb83265`](https://github.com/thomasklemm/lowrail/commit/cb832658d52e0a9f440d51ccac7dd985ceb09f2a),
including the central production TracePoint fix. All four cohorts use that
exact head and one freshly rebuilt, source-pinned format-2 `sealed-v1`
artifact. No loader redesign landed during these measurements. The
[numeric export](sealed-link-postfix.json) records the manifest SHA
`fbd041bcf7eb64f8d789cec50038249d1701baab3b1caf08fb86c2580f0abf0a`,
35 source certificates, five template pins, both delivered ISeq contracts,
runtime/harness hashes, per-round numbers and changed JIT windows.
Corpus source is Roundhouse's real-blog fixture at
[`bb90df2`](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9);
the lockfile SHA is
`570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.

### Admission and correctness before measurement

Format-2 path-bound ISeqs correctly refused the old harness's fake snapshot
app root. `LOWRAIL_DIR` now forwards the existing separate artifact directory
through normal boot; `LOWRAIL_ROOT` remains the **real app root**. Both
`request_pairs.rb` and `pass.rb` keep snapshot isolation and check relocation
against that real root. Empty controls remove pointers to removed units/files.
No certificate or guard is bypassed. The public external-directory regression
fails before this fix and passes afterwards, including wrong-root refusal.
Untimed real-app boots admit the empty snapshot without units and activate
only the full snapshot; missing/disabled/off arms remain original.

On the pushed head, the isolated checker passes **144 identical pairs** of
status, byte body, all headers, ordered SQL, controller/render events and
assigns: **350 link hits, zero fallbacks**. Untimed native probes record
**7 index / 2 show hits per request**, including a repeated YJIT probe before
each YJIT cohort. No JIT-mode fact mismatch or zero-hit measurement is hidden.
Native off/sealed YJIT both have **zero lifetime and delta
`exit_trace_leave`**, with no live TracePoints. Full gem checks pass
132 tests / 4,598 assertions (six skips), harness suites 16/157 and 13/151,
and Cargo 35 + 1 + 3. The default tier/quarantine is unchanged.

### Request results

Ruby 4.0.7 / Rails 8.1.4, six fresh rounds per cohort, seed 41231,
N=0/50, the five unchanged fixed heaps, at most four Callgrind workers.
The 512-MiB pinned tool SHA is
`5edddeee9ee49e9d4ff2188c7d01ea03e389a5acf091af4c465d04e52fda9588`.
There is **one cohort per route/mode, no retries and no clean-arm salvage**.

| Mode / route | Off Ir/request | Sealed Ir/request | Paired total Δ%, 95% CI | Disposition |
|---|---:|---:|---|---|
| Interpreter index | 9,101,417 | 8,981,144 | −1.300 [−1.358, −1.273] | **Rejected A/A; diagnostic only** |
| Interpreter show | 8,743,657 | 8,728,980 | **−0.185 [−0.221, −0.159]** | **Accepted** |
| YJIT index | 5,682,337 | 5,579,236 | −1.841 [−1.911, −1.764] | **Rejected JIT-flatness; diagnostic only** |
| YJIT show | 5,416,204 | 5,375,833 | −0.715 [−0.756, −0.690] | **Rejected JIT-flatness; diagnostic only** |

Interpreter index total A/A excludes zero: **[−0.037, −0.002]%**; its
no-GC A/A passes. Interpreter show passes both, with accepted no-GC delta
**−0.187% [−0.238, −0.139]**. All four cohorts pass heap matching, actual
execution-mode and overflow gates; both YJIT A/A controls pass.

All 36 warmups in each YJIT cohort reach three flat windows. Nevertheless,
index has **6/36** workers compile inside a measured N=50 window:
`0-off_b` (+1 ISeq/+28 blocks), `1-empty` (+17 blocks), `1-missing` (+32),
`2-default` (+9), `4-missing` (+1), `5-missing` (+12). Show has **1/36**:
`2-disabled` (+30 blocks). No invalidation delta occurs. These failures include
off/empty/disabled controls; their compilation sites remain unattributed.
Neither a clean sealed arm nor an attractive raw delta repairs the cohort.

An initial driver invocation omitted parent `RAILS_ENV=production` and
refused admission before launching any worker or measured window. That
failure is retained separately, not counted as a measured cohort or replaced
control. Reproduction requires explicit production/sealed acceptance:

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 LOWRAIL_SEALED=1 \
BENCH_JIT=0 BENCH_JOBS=4 BENCH_ROUNDS=6 BENCH_REQUESTS=50 \
PATH=/tmp/VALGRIND-brk512/bin:$PATH CPATH=/tmp/VALGRIND-brk512/include \
  mise exec -- ruby bench/pass.rb .corpus/real-blog-r4 \
    --pass sealed/link_to --path /articles/1 --out /tmp/NEW-output
```

**Decision: stacking backlog, no default promotion and no accepted YJIT win.**
The accepted show gain is small; do not subtract a hypothetical setup tax or
credit the rejected index result. Next is interpreter-first pricing of the
show form scaffold, using the behavior-matched sealed-renderer specimen.
Further YJIT cohorts wait for the separately owned warmup-method investigation.
