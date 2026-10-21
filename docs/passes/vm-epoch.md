# VM mutation epoch: cheap structural detection, not a section certificate

Experiment only, 2026-10-20. **No runtime-gem, default, quarantine or upstream
publication changes.** The [local Ruby patch](../upstream-drafts/ruby-4.0.7-mutation-epoch.patch)
is not a supported Ruby API or a production Lowrail implementation.

**Upstream follow-up (2026-10-21):** the owner posted
[Feature #22459](https://bugs.ruby-lang.org/issues/22459), proposing scoped
method tokens instead. Production Fizzy `/bubbles` bumped the global epoch
20 times/request via `CollectionProxy#extend(*extending)`, while none of 12
selected held tokens invalidated. The registry lifecycle/Ractor
[review fix](https://github.com/thomasklemm/ruby/commit/a30db2f20843940c089bd8247135a7c7cd475ca5)
passes 13 tests/97 assertions in interpreter and YJIT. Final-source cost
remeasurement is pending; its first cohort is INVALID for harness drift.
See the [current evidence](../upstream-drafts/ruby-method-token-evidence.md)
and [unposted correction draft](../upstream-drafts/ruby-method-token-feature.md).
The numbers and prototype below describe the historical 4.0.7 experiment,
not the reviewed token implementation. The global epoch is a rejected
alternative, not the proposed API.

**Answer:** an allocation-free C getter can read a broad VM generation for
**195 interpreter / 36 YJIT Ir**; read + integer comparison + successful branch
costs **267 / 52 Ir**. It detects the tested method/visibility/constant
counterexamples without suppressible Ruby callbacks or populated constant
inline caches. It does **not** detect mutable heap contents, receiver selection
or input facts, or make an entry check protect later code after arbitrary Ruby
runs. The ordinary getter itself is overridable. Cheap structural detection
is feasible; replacing complete section certificates with it is not established.

## Existing Ruby facilities

The parallel [Ruby 4.1 investigation](https://ampcode.com/threads/T-01a15ab5-4c4d-77e7-a574-29cb734df5b8)
checked preview1
[`2d08b5f`](https://github.com/ruby/ruby/commit/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1)
and master
[`c71329d`](https://github.com/ruby/ruby/commit/c71329d4298a4ce03dabea45328933c6464cf362).
This experiment independently inspected master's `vm.c`, `vm_method.c`,
`include/ruby/vm.h`, `yjit.h` and `zjit.h` at the latter pin. No supported broad
method/visibility/constant epoch or dependency-subscription API was found.
This is a pinned-source finding, not a prediction about later master.

- [`RubyVM.stat`](https://github.com/ruby/ruby/blob/c71329d4298a4ce03dabea45328933c6464cf362/vm.c#L846-L907)
  still exposes constant-cache invalidations/misses, global cvar state, next
  shape ID and shape-cache size. None is a general mutation generation.
- [`vm_method.c`](https://github.com/ruby/ruby/blob/c71329d4298a4ce03dabea45328933c6464cf362/vm_method.c#L314-L345)
  calls both JITs' CME and constant invalidators. `yjit.h`/`zjit.h` also have
  no-singleton-class, tracing and other assumption-specific invalidators.
  These internal callbacks are useful implementation seams, not an extension
  contract, and do not mean every possible assumption changed.
- Cvar state concerns class variables; shapes describe object layouts, not
  changes to existing ivar values, Hash entries/defaults or String encoding.
  ZJIT's `invalidation_time_ns` measures work, not semantic generations.
- In 4.0.7 `rb_clear_method_cache` is called independently of whether a cached
  CME exists. In contrast, `ruby_vm_constant_cache_invalidations` adds the
  number of registered constant ICs, potentially zero. The
  [rejected stat experiment](speculation.md#constant-cache-counter-measured-and-rejected)
  remains rejected; this patch adds a different counter, not a reinterpretation
  of that stat.

## Prototype and read path

Ruby **4.0.7**, revision
[`229531a`](https://github.com/ruby/ruby/commit/229531a6cfbf07e3caef30dbac24a2a3f3fed482),
official source archive SHA-256
`911ace20f90d068ca0e4dda6d0e4f0f81e52e52f2dd4f4004c721e253412e82d`.
Final patch SHA-256
`4704966df17d7c5de16e664099fa350bb409549f091e6b085273d45073aec88e`.
It adds 47 lines across five VM files:

| Seam | Prototype action |
|---|---|
| Method table insertion/removal, `rb_clear_method_cache`, CME invalidation paths, refinement cache clearing | Bump independent of user hooks or JIT activation |
| Include/prepend (extend uses include), singleton/metaclass creation | Conservative bumps; unrelated/no-op structural operations may revoke too |
| Constant cache clearing, table set/materialization, successful autoload registration, removal | Bump even with zero registered constant ICs; bump before application notifications |
| Method visibility | Existing `rb_export_method` changes reach method-cache clearing; no lexical `Module#private` wrapper |

The global is an unsigned LP64 word. GCC/Clang relaxed atomic CAS increments
avoid lost updates; reads are relaxed atomic loads. It saturates at Fixnum max
and returns `nil` thereafter, rather than wrapping or allocating Bignums.
A validator must never publish a nil generation. The micro assumes an already
certified integer snapshot; it does not price initial validation or saturation
handling. There is no Hash/stat/symbol lookup in the C getter.

On this GCC 12.2 x86-64 build, `vm_mutation_epoch` is seven native instructions
including `ret`: load, saturation test, Fixnum tagging and conditional selection.
The bump uses a `lock cmpxchg` loop; it is **not a free ordinary increment**.
No mutation-heavy application overhead or cross-core contention was measured.
One semantic mutation can bump several times; only equality matters.

The Ruby entry is a zero-argument C method, `RubyVM.mutation_epoch`, rather
than a new opcode or JIT-specific optimization. This is a minimal practical
read path, **not proof of the lowest possible intrinsic cost**. Ordinary method
dispatch and constant lookup are included below. A VM-intrinsic comparison
could avoid some of this cost, but has not been implemented or measured.

### Reentrancy is part of the patch, not just an API detail

The initial 45-line draft passed the named mutation probes, but a further
probe found `remove_const` deletes a deprecated constant **before** calling
overridable `Warning.warn`, and clears its cache **after** the warning. The
warning saw the constant absent while the first draft's epoch still matched.
The final patch bumps immediately after deletion, before warning reentry.
The retained regression observes `present: false, epoch_changed: true` inside
the warning. Both first-draft read cohorts passed their performance controls;
they are retained as superseded semantic evidence, not silently discarded.
Fresh cohorts measure the final patch. No failed performance control was
rerun until green.

This example is also why hooking only the JIT invalidators is not enough:
observation must precede every application-code reentry after a structural
write. The patch is a finite experiment, **not an exhaustive audit of every
VM mutation/reentry path**.

## Fixed-heap read cost

`bench/experiments/vm_epoch.rb micro OUT` reuses `RequestPairs`, `HeapWindows`
and `JitStability`: the
[`c9d2397`](https://github.com/thomasklemm/lowrail/commit/c9d2397f1748579b04f6bddff48bc3bfc53d79b0)
operation protocol, no request settling or application context replacement.
Six randomized fresh-process rounds per mode, seed 41231, N=0/100,000,
total/GC-excluded windows, five floors 1,000,000/250,000/100,000/20,000/10,000.
Subtract each arm's **paired same-round empty-loop slope**, not an estimated
bytecode cost. Independent `off_a`/`off_b` use identical empty bodies.

YJIT uses the production call threshold, three consecutive flat warm windows
and exact-signature heap/GC observer warmup. Every measured before/after
compiled-ISeq/block/invalidation counter must match. Both final cohorts pass
both A/A controls, all heap checks and actual-JIT-state/window gates. A/A
intervals are [0, 0]%; all N=100,000 operation windows allocate zero objects.
The first N=0 window has five fixed seam allocations in every arm; subsequent
N=0 windows allocate none. No window collects. Valgrind 3.19 counts executed
instructions, **not nanoseconds**.

| Operation, net Ir/check | Interpreter, total and GC-excluded | YJIT, total and GC-excluded |
|---|---:|---:|
| `RubyVM.mutation_epoch` | 195.002 | 36 |
| `RubyVM.mutation_epoch == saved` | 249.002 | 49 |
| `raise unless RubyVM.mutation_epoch == saved` (successful path) | 267.002 | 52 |

Each cell's nominal bootstrap 95% interval rounds to [value, value]; the
synthetic instruction paths are deterministic across the six processes.
The failure branch/revalidation is not priced. The old `RubyVM.stat` read's
7,081/6,970 Ir is not paid by this direct getter. No native latency,
whole-request saving or patched-VM support claim follows from the micro.

## Executed completeness matrix

`vm_epoch.rb probe`: Rails **8.1.4**, Zeitwerk **2.8.3**, interpreter and YJIT.
It checks 48 cases plus the existing `constant_epoch.rb`'s **15** original
constant/autoload/Zeitwerk cases. A captured C `Method` observes the actual
generation during probes, so replacing the ordinary getter cannot hide the
mutation from the experiment. Existing `speculation_holes.rb` also runs
unchanged: its cached Ruby-hook guards remain stale; the experiment does not
silently fix Lowrail's runtime. Deltas are conservative counts, not event IDs.

| Counterexample / fact | Final prototype | Remaining requirement |
|---|---|---|
| Suppressed `method_added`; conditional hook containing but not reaching `super` | **Detected**, deltas 2 / 3 | Validate effective definition originally; epoch is not the definition |
| Suppressed singleton callback (hook installed before snapshot) | **Detected**, delta 2 | Bind facts to the actual receiver/holder, not `object.class` alone |
| Own visibility change; restore public | **Detected**, deltas 3 / 1 | Preserve implicit vs public dispatch semantics |
| Alias/remove/undef; include/prepend/extend; singleton class creation | **Detected** | Global invalidation is conservative, not receiver provenance |
| Constant replacement with prebuilt target and suppressed `const_added`; removal | **Detected**, deltas 4 / 2 | Presence/identity must have been certified at snapshot |
| Uncached `const_get` replacement/removal | **Detected**, deltas 4 / 2; stock constant-cache invalidations 0 / 0 | No dependence on warmed literal caches |
| Uncached autoload registration/materialization/removal; unmaterialized removal | **Detected in all cases** | Autoload may execute arbitrary code; recheck after it |
| Zeitwerk uncached reload/rematerialization | **Detected**, deltas 7 / 7; stock invalidations 0 / 0 | Revalidate the replacement, do not merely accept the new epoch |
| Warmed literal constants/autoload/Zeitwerk cases | **Detected**, all 15 original matrix operations bump | Cached and uncached paths are both exercised |
| Deprecated removal calls `Warning.warn` after deletion | **Detected before callback**, final delta 2 | First draft missed this; more reentry paths need auditing |
| `process_action` start subscriber suppresses hooks and redefines `link_to` | **Detected**; actual later call emits live-helper marker | Check **after subscriber**, not only at request entry |
| Name expression changes actual builder's `content_tag_string` | **Detected**; changed HTML, name evaluated once | Check after name evaluation; continue locally without replay |
| `to_param` installs singleton `route.format` | **Detected**; `/changed`, conversion once | Check after conversion; whole-helper restart repeats effects |
| Direct config and nested config changes | **Not covered**, delta 0 | Independent value snapshot/live predicate or refusal; keep AR/schema epochs |
| Replacing `view.@tag_builder` with a prebuilt builder | **Not covered**, delta 0 | Actual receiver identity/provenance at use |
| Mutable table entries/defaults and primitive input state | **Not covered**, delta 0 | See exact fact inventory below |
| Redefining the ordinary `RubyVM.mutation_epoch` getter | VM mutation **detected by captured reader**, but ordinary getter can return stale saved value | Trusted intrinsic/captured core access and trusted comparison needed; the measured direct-call expression is not a self-protecting certificate |

The subscriber specimen executes the real Notifications start/finish protocol
and live Action View helper; the route specimen executes the real optimized
Rails route helper. These are **mutation probes**, not a full Rack response /
header / SQL / instrumentation equivalence gate for a new lowerer. No lowered
continuation is installed, so the once-only outputs demonstrate the original
behavior that a future continuation must preserve, not an implemented deopt.

### Exact endpoint fact inventory

| Fact in the final [endpoint inventory](endpoint.md#final-fact-classification-sealed-contract-vm-epoch-residuals) | What this prototype actually establishes |
|---|---|
| View `convert_options_to_data_attributes`, `link_to_remote_options?`, `url_target`, `url_for`, `content_tag`, `ensure_valid_html5_tag_name`, `tag_builder` | **All seven executed**: singleton definition replacement and own public→private change detected for each |
| Builder `content_tag_string`, `tag_options`, `tag_option` | **All three executed**, same definition/visibility cases |
| Singleton/ancestor changes on already certified holders | Generic singleton/include/prepend/extend probes detect structural mutation; all possible ancestor/refinement combinations are not exhaustively tested |
| Already-active refinement / lexical constant scope, Box selection | **Not certified** by comparing a global generation; different scopes can resolve differently without intervening mutation |
| Actual view/builder replacement | **Not covered**; preexisting different holders can be selected without any code mutation |
| Hash/String/escaping primitive methods and per-instance overrides | Structural definition/visibility edits go through the same VM hooks, but this experiment does **not** certify all primitive contracts/receivers; no exhaustive primitive-mutation matrix |
| Stock `TAG_TYPES` | Stock table is **frozen**; constant rebinding bumps (executed), Hash method changes are structural. Certify exact stock identity/frozen state; do not manufacture an in-place-write hole for that frozen object |
| Mutable replacement `TAG_TYPES` | Rebinding bumps, but later entry edits do **not** (executed with a prebuilt mutable copy) |
| `PRE_CONTENT_STRINGS` | Mutable Hash, default Proc. Entry changes and replacing the default Proc with a scalar default both leave epoch unchanged (**executed**); constant rebinding is structural, not a contents guard |
| Input class/shape, HTML safety, encoding, coercion effects | **Not covered**; String encoding mutation is an executed zero-delta example. Method definitions used for coercion are structural; their data/results/effects are not |
| Arbitrary calls mutating facts inside a section | Later structural mutations bump, but **entry permission is not revoked from already-running code**. Every relevant post-call use needs a checkpoint/local continuation; heap mutations still need residuals |

Further limits: relaxed atomics are not a seqlock or a lock around a section;
another thread/Ractor can mutate after a comparison. Safe acquisition must
validate facts between compatible snapshots, account for validation's own
Ruby/reentry, and refuse/retry on change. Scope/refinement/Box and concurrent
execution semantics, TracePoint/ISeq introspection, unsupported C extensions
writing VM internals, saturation behavior and universal hook coverage are not
certified by these probes. An unchanged epoch only protects previously proven
facts within a proven execution boundary. It is never proof that arbitrary
boot assumptions or data-dependent predicates are true.

## Endpoint cost estimate, not a measured endpoint

At **one successful read/compare/branch per each of two sections**, the
interpreter estimate is **534 Ir**, versus the original caller-side
**93,649 Ir** checks: about **175× cheaper, 99.43% less check work**. The latest
body-installed inventory's **94,466 Ir** guard baseline gives **177× / 99.43%**.
Its entire two-link work is **89,729 Ir** (earlier caller-side cohort 90,042).
These are different experiments, not interchangeable paired samples.

Sensitivity, using 267.002 interpreter Ir/check: two/six/twenty checkpoints
cost about **534 / 1,602 / 5,340 Ir**, before residuals. Against 94,466 that
removes about 99.43% / 98.30% / 94.35% of that historical check budget. Two
YJIT checkpoints estimate **104 YJIT Ir**; do not subtract that from an
interpreter endpoint baseline. The number of sufficient checkpoints is
**not established**. Caller state, holder/input/config checks, trusted read
delivery, cold certification, global false-positive invalidations and fallback
costs remain unpriced. No endpoint micro or request was run with the epoch.

**Recommendation:** retain a local upstream API draft/research result. The
read cost is small enough that a VM-owned structural generation is worth
discussing if a future design needs it, but it does not reopen guarded endpoint
lowering or replace the sealed-tier decision. Do not ship a patched-Ruby
dependency, reactivate source passes, erase live value/receiver checks or call
one comparison per section complete. A real intrinsic must protect its own
read/comparison, specify lexical/concurrent boundaries, audit every mutation
reentry and demonstrate a net win including the residual facts.

## Reproduction and evidence

```sh
# Extract the official ruby-4.0.7.tar.gz into a disposable directory; verify SHA.
patch -p1 < /path/to/lowrail/docs/upstream-drafts/ruby-4.0.7-mutation-epoch.patch
./configure --prefix=/tmp/lowrail-epoch-ruby --enable-yjit --disable-install-doc \
  --with-opt-dir=/usr CFLAGS='-O3 -g'
make -j4 && make install
make test

# From the Lowrail checkout, using the PATCHED Ruby explicitly:
R=/tmp/lowrail-epoch-ruby/bin/ruby
# Install actionpack/actionview 8.1.4 and zeitwerk 2.8.3 for this Ruby, or set
# GEM_PATH to an ABI-compatible 4.0.7 gem directory. Micros need only stdlib.
$R bench/experiments/vm_epoch.rb probe
$R --yjit bench/experiments/vm_epoch.rb probe
BENCH_JOBS=2 BENCH_JIT=0 $R bench/experiments/vm_epoch.rb micro /tmp/NEW-epoch-interpreter
BENCH_JOBS=2 BENCH_JIT=1 $R bench/experiments/vm_epoch.rb micro /tmp/NEW-epoch-yjit
$R bench/speculation_holes.rb
```

[vm-epoch.json](vm-epoch.json) retains sanitized per-round slopes, window
instructions/allocations/GC/capacities/JIT observations, controls, source and
binary hashes, both mutation matrices, and superseded first-draft results.
Raw Callgrind/build logs stay in `/tmp/lowrail-vm-epoch/`, not Git. Ruby's
`make test` reports **PASS all 2,044 tests** and the basic checks report
**test succeeded**. No full Rails suite or `lowrail verify` support gate was
run for this uninstalled experimental facility.
