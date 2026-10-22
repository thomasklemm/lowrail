# Bet K: YJIT-aware lowered ISeqs — stopped at the screen

2026-10-22. **No new speed claim, RPS cohort, runtime promotion or F-branch
change.** One combined blog candidate removes five real constant-cache exits
per request, but does not clear the prospective wall screen. The final branch
retains the experiment and evidence, not its runtime change. Existing Ir/RPS
prices are neither rescored nor replaced.

## Inputs and finite protocol

- Ruby 4.0.7, Rails 8.1.4, production; unchanged disposable generated blog
  `GET /articles/1` and pinned Fizzy `GET /buckets`. No app/config patches.
- Old blog runtime matches main
  [a9a71db](https://github.com/thomasklemm/lowrail/commit/a9a71dbf3d93b7b881d2833e7ebf6756ebf5d967).
  Fizzy uses the **external**, bench-only DirectSite overlay at
  [936cc46](https://github.com/thomasklemm/lowrail/commit/936cc462ffa2586a45458f6efa69d9717f965fe8);
  this is not a production admission certificate.
- CLI and native extension built locally. Stock Ruby runs through
  `mise exec ruby@4.0.7 --`. Stats use official Ruby 4.0.7 source configured
  with `--enable-yjit=stats --disable-install-doc`, separately installed.
  Source archive SHA256:
  `911ace20f90d068ca0e4dda6d0e4f0f81e52e52f2dd4f4004c721e253412e82d`.
  Stats executable SHA256:
  `cf61ff3ca12fd3ef0374deaf4b49382507ce7944fff25dc86306b107b6c31776`.
- Stock Ruby's normal stats omit `ratio_in_yjit`. The stats build supplies
  instruction counters; **fresh certificates for each actual Ruby description**
  avoid bypassing build/mode compatibility. No metadata spoofing.
- [Driver](../bench/experiments/yjit_aware.rb): 2,000 warm requests followed by
  500 measured requests, serial workers pinned to CPU 2. Stats flags:
  `--yjit --disable-zjit --yjit-stats=quiet
  --yjit-trace-exits-sample-rate=101`. Separate stock-Ruby, stats-OFF wall
  screen: three rotated off-A/on/off-B rounds, same warm/sample counts.
- Each screen first checks two seeded response companions (status, body and
  **all** headers), positive hits and zero fallbacks in separate counting
  workers. Blog per ten requests: 10 form / 40 token / 10 collection hits.
  Fizzy: 20 bucket hits and 20 strict query shadows per ten requests.
- Only one combined candidate; old-on A / candidate-on / old-on B compares
  its *incremental* cost. Config keys `reference_lib`, `reference_artifact`,
  `reference_stats_artifact` select old-on for the two arms still named
  `off_a`/`off_b` in machine output. Neither is Lowrail-off in that screen.
- Prospective stop: no better allocation/counter screen, or wall improvement
  failing to exceed **3 × max absolute A/A 95% interval bound**, kills the
  candidate. Three-round intervals are only a noisy diagnostic. No retries,
  window exclusions, RPS or instruction pricing followed.

The [sanitized machine export](yjit-aware.json) retains every completed
worker's numeric counters, allocations, wall samples, response hashes,
coverage and input hashes, including all three A/A sequences. `jit_before`
and `jit_delta` reconstruct every numeric after-counter. Paths use root labels;
private exit/entropy/SQL logs are not published. Exit samples include boot and
warmup and are systematic every 101 exits, not random or window counts.

## Off/on YJIT census

Values below are off-A → on; off-B and every reason are in the export.
Compiled counts and `yjit_alloc_size` are cumulative **before** the window,
not the number of Lowrail bodies or per-request memory allocations.

| Metric | Blog off → on | Fizzy off → on |
|---|---:|---:|
| Compiled ISeqs | 3031 → 2872 | 3928 → 3926 |
| Compiled blocks | 44955 → 42889 | 62164 → 62323 |
| `yjit_alloc_size`, bytes | 16610778 → 10428605 | 23707609 → 23754751 |
| Window new ISeqs / blocks, each arm | +2 / +12 | +2 / +12 |
| Window `yjit_alloc_size`, bytes, each arm | +3280 | +1576144 |
| Window invalidations / code GC | 0 / 0 | 0 / 0 |
| Side exits / request | 11 → 16 | 42 → 38 |
| `opt_getconstant_path_ic_miss` / request | 0 → 5 | 0 → 0 |
| Window ratio-in-YJIT, % | 99.742555 → 99.658590 | 99.763679 → 99.795920 |
| Singleton-send fallbacks / request | 106 → 106 | **243 → 469** |
| Megamorphic-send fallbacks / request | 6 → 4 | 2150 → 1686 |
| Megamorphic ivar reads / request | 0 → 0 | 121 → 89 |
| Objects / request, stats build | 2260.756 → 1882.420 | 9085.236 → 8508.120 |

Ratio is 100 × (delta YJIT instructions − delta side exits) / (that retired
YJIT count + delta VM instructions), **not a delta of cumulative ratios**.
Every window still compiles two ISeqs/twelve blocks: these are diagnostic
counters, **not JIT-flat instruction-price evidence**. Named hot variant and
render-method compiled-instruction lists are retained; passive witness methods
need not compile. `total_exit_count` includes normal returns and is not the
side-exit measure above.

Blog opcode exits/request: `setblockparam` 1, `getblockparamproxy` 1,
`expandarray` 2, `invokesuper` 1, `once` 5, `opt_eq` 1, plus the new constant
lookup 5 when on. Fizzy: 1/13/3/1/5/1 for those same six opcodes, plus
`splatkw` 5→3 and `opt_neq` 13→11. Branch-stub counts are separate from this
opcode-side-exit sum; they are not added twice.

Send shapes generally improve with lowering: blog keyword-splat fallback
41→24, block-arg-type 17→9, rest-and-keyword-supplied 11→3; forwarding
114→115. Fizzy keyword-splat 52→46, forwarding 1074→1024, C-function block
args 157→124, missing-method-entry 113→115. Counters do not identify every
callsite: there is no demonstrated new `respond_to_missing?` callback or
method-missing defect here. Deleting reflective/implicit dispatch or changing
keyword separation, block identity or evaluation order is not an optimization
certificate. No app ivars are initialized merely to manufacture stable shapes.

### Fizzy: guard-created eigenclasses are a concrete JIT-hostile shape

The DirectSite overlay captures stock `Object#singleton_class` as `SINGLETON`.
Two hot guards **create** eigenclasses even after checking
`singleton_methods.empty?`:

1. `ARRequestSites.bucket_rows`: the `@user_methods` checks call
   `SINGLETON.bind_call(user)` before effective visibility/body lookup.
2. `ARRequestSites::Site#eligible?`: the `@readers` checks call
   `SINGLETON.bind_call(owner)` on each Bucket before the same lookup.

Ruby 4.0.7's `yjit/src/codegen.rs::gen_send_general` refuses specialized
sends through singleton classes of ordinary objects (to avoid retaining the
receiver), unlike class/module singleton setup. Its emitted fallback counter
explains why this shape matters. Runtime fallback counts are **not themselves
side exits** or invalidations. Creation during warmup can poison specialization
without any invalidations inside the later window.

The 243→469/request increase is a **likely contributor to F's weak YJIT RPS**,
not an isolated causal price; reduced megamorphism and query work coexist.
F stays parked and untouched. Removing these effective-visibility checks is
unsafe; bound `public_method` can invoke `respond_to_missing?` on missing
methods and is not an exact drop-in (see [shape guide](jit-shapes.md)).

## The single combined candidate

[Candidate source](https://github.com/thomasklemm/lowrail/commit/d3b2373790715367ced79f630431e039fdb1c2b0)
does two things together, not two measurement rounds:

- Retain actual private/implicit view dispatch inside captured stock
  `BasicObject#instance_exec`; move only the form's escape/string suffix
  outside, saving path/token/field locals in their original evaluation order.
- After the successful passive original witness, retain already-loaded
  `ActionView::Base` and `ERB::Util` identities under SEAL001 and use locals
  rather than their CREF-sensitive constant lookups in the view block.
  **No boot autoload, cached config value, token reuse or live getter removal.**

YJIT's `gen_opt_getconstant_path` checks CREF-sensitive caches via
`rb_vm_ic_hit_p` and exits on a miss. Lifetime stack samples locate the token
constant lookup and form view block; the combined experiment then verifies
**2500→0** window `opt_getconstant_path_ic_miss` and
`exit_opt_getconstant_path` counts across 500 requests. This is stronger than
guessing from disassembly or boot-only samples, but does not separately price
the split and constant capture.

Old-on A / candidate / old-on B results:

| Metric | Old A | Candidate | Old B |
|---|---:|---:|---:|
| Constant-cache exits / request | 5 | **0** | 5 |
| Total side exits / request | 16 | **11** | 16 |
| Window ratio-in-YJIT, % | 99.658590 | **99.703279** | 99.658590 |
| Objects / request, stats build | 1882.364 | **1877.736** | 1882.456 |
| Compiled ISeqs before window | 2872 | 2872 | 2872 |
| Compiled blocks before window | 42854 | 42901 | 42820 |
| `yjit_alloc_size` before, bytes | 10427531 | 10037269 | 10424427 |
| `yjit_alloc_size` delta, bytes | 244 | 3280 | 3280 |
| New ISeqs / blocks | 2 / 12 | 2 / 12 | 2 / 12 |

No send-fallback counter changes, steady invalidations or code GC. The
allocation difference on stock Ruby is about five objects/request too.
The asymmetric allocator deltas are retained, not flattened or called savings.

## Wall screen and exactness limits

| Diagnostic stock-YJIT wall comparison | Δ time [95% interval], % | A/A interval, % | Required improvement |
|---|---:|---:|---:|
| Blog entire existing stack vs off | −14.429 [−16.302,−13.176] | [−6.768,+5.128] | >20.303% |
| Fizzy existing F prototype vs off | −6.107 [−8.078,−2.290] | [−3.642,−1.308] | >10.925% |
| **Combined candidate vs old-on** | **+1.679 [−1.842,+3.819]** | **[−12.835,+4.127]** | **>38.505%** |

None clears the prospective screen rule. Fizzy A/A is directionally biased
as well. **Stop; no RPS cohort or retry.** These short Rack wall windows are
not real-Puma RPS prices and do not overturn the accepted earlier results.

Both seeds' response digests match in all three screens, with the hit maps
above and no runtime refusal. Public form regression passes its 192+192
pairs (plain and live render subscriber), renamed-app certificate and custom
builder refusal: **1 run, 74 assertions, zero failures/errors/skips**, on
the candidate and again after its removal. The broader production regression does **not** pass:
`seed-0-off1` raises `app source pin mismatch` on the freshly generated blog,
also reproduced with the unchanged reference entropy validator. That gate
was not weakened, and its later token/mid-call assertions are not credited.
An attempted parent-only policy override cannot reach exec'd child workers;
it fails identically and is not counted as coverage.

The first regression attempt also used a wrong cached CLI after sharing
Cargo's target directory with the reference source; rebuilding the main CLI
fixes form coverage, not the independent off-arm source-pin rejection.
Failed pre-screen setups (including stale relocation pointers and distinct
stats-Ruby descriptions) and all completed windows are retained privately.
Fizzy whole-login SQL digests differ even off/off; strict query shadows and
response equality are **not** whole-DB or cold exactness certificates.

ZJIT parity only: stable local receivers and avoiding eigenclass creation
agree with its method-specialization assumptions, but this study runs YJIT
only. No ZJIT counters, throughput or parity claim follows.

## Reproduction

Prepare unchanged corpus apps, bundles/assets, the BlogShowGetOnly seed and
FizzyLinkFixture seed. Build matching-mode sealed artifacts for stock and stats
Ruby separately; isolate the three blog passes **after** resolving manifest
paths, renumber IDs and regenerate `Paths.relative` pointer metadata. Pin
source/lock entropy metadata for these generated fixtures outside the apps;
retain existing provider/site checks and never normalize output.

The driver reuses `script/native-bench` from native-yjit-bench at
[6510cd2](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8)
and, for Fizzy, `bench/experiments/ar_request_sites.rb` at
[936cc46](https://github.com/thomasklemm/lowrail/commit/936cc462ffa2586a45458f6efa69d9717f965fe8).
These are read-only worktrees, not imported runtime changes. Portable config
and every actual input hash are in the JSON export. Resolve root labels to
local paths, supply the disposable BlogProduction::Entropy::SECRET for blog,
and use a fresh output directory:

```sh
export GEM_HOME="$(mise where ruby@4.0.7)/lib/ruby/gems/4.0.0"
export GEM_PATH="$GEM_HOME"
mise exec ruby@4.0.7 -- ruby bench/experiments/yjit_aware.rb run CONFIG NEW_OUTPUT
```

Old reference source and candidate source differ only by the declared two
runtime files; each gets its own stock/stats artifact. Do not time those
screens concurrently with builds, tests, another screen or a cohort.
