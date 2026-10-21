# Method tokens: smaller patch, no upstream case yet

2026-10-21. Fork-only follow-up to [Ruby #22459](https://bugs.ruby-lang.org/issues/22459),
including all four notes. Nothing here has been posted upstream.

**Recommendation: keep the experiment in the fork.** A small implementation
exists, but correctness does not require a new Ruby API: public method-definition
equality plus visibility checks detects the named suppressed-hook case too.
The historical accepted blog instruction saving did **not** use tokens.

## What core would own

Ruby branch `thomasklemm/method-token-minimal`,
[patch commit](https://github.com/thomasklemm/ruby/commit/a21df07d7800aa4e0b3187378df84d179b6fd91b),
on refreshed ruby/ruby master
[base](https://github.com/ruby/ruby/commit/5771bd7a39100a1ceb003d78937b367ec2531f02).
This replaces the original prototype rather than carrying forward its epoch
or registry. The old published prototype remains untouched.

| File | Added lines | Maintenance obligation |
|---|---:|---|
| `vm_method.c` | 26 | Acquire a normal call cache; check its existing invalidation predicate; reject unsupported modes and invalid arguments |
| `include/ruby/vm.h` | 32 | Two exported C functions, self-contained includes and their lifetime/concurrency contract |
| `ext/-test-/method/token.c` | 47 | A real extension consumer that retains the opaque VM value safely |
| `test/ruby/test_method_token.rb` | 150 | Lookup mutations, suppressed hooks, GC/compaction, mode refusal and fork |
| **Total** | **255** | **4 files; 58 production/header lines; no removed lines** |

The token **is the existing normal call cache**. Leaf invalidation clears its
class; tree invalidation marks its callable method entry. The VM's existing
`vm_cc_invalidated_p` checks both. No mutation path, registry, global counter,
Ruby class, core TypedData, GC callback, Ractor latch or JIT code changes.
Acquisition uses a zero-flag callinfo, avoiding mandatory-only overloads.
It does not execute the target or `method_missing`; missing/refined entries
return nil. The test extension's wrapper is not a new Ruby core API.

The caller needs the GVL, must retain/mark the opaque value and must never
expose the raw IMEMO to Ruby. Movable marking requires relocation during
compaction; an ordinary `rb_gc_mark` pins it. It retains neither class nor
method entry. Existing weak-reference processing revokes it before those
objects are freed. A method-invalidated cache stays invalidated.

This minimal design refuses acquisition/checks with Ruby Box enabled or
outside single-main-Ractor mode. Unlike the old prototype, it has no permanent
process latch: after fork an unchanged cache can become usable again; a
method-invalidated cache cannot revive. The API does not certify receiver
identity, lexical refinements, callees/super or mutable values, and a check is
not a lock across Ruby reentry. These are explicit restrictions, not solved
concurrency or whole-specialization semantics.

The lasting core cost is **not merely 26 C lines**: future cache/GC changes
would have to preserve safe externally retained call caches and these API
semantics. Acquisition/memory pressure and subscribed mutation costs were not
benchmarked. A small diff alone does not answer alanwu's maintenance objection.

## Existing alternatives

* **Public reflection works for the named correctness need.** Save an
  `UnboundMethod`, look it up again and compare with `==`, not `equal?`.
  Separately compare public/protected visibility; equality ignores visibility.
  Capture the original reflection/equality methods so owner overrides cannot
  hide lookup changes. The experiment does this and takes the original path
  on missing/undefined methods. It allocates one wrapper per dependency/check.
  It is a current-definition comparison, not a permanent revocation event.
* `Method#==` also works for the same receiver; `equal?` compares newly
  allocated wrappers, and an owner-only comparison misses a same-owner
  redefinition. These are not equivalent validity predicates.
* **A public-header-only extension is viable without patching Ruby:**
  `rb_obj_method` plus `rb_equal` performs definition comparison (and allocates).
  It compiled on unpatched system Ruby and detected a suppressed-hook
  redefinition. The timed primitive omits visibility and uses current `==`
  dispatch, so is not the complete captured-reflection guard above.
* `rb_method_basic_definition_p` can help certify known core methods, not
  arbitrary Ruby definitions. Lowrail already has this narrower primitive.
* `RubyVM.stat` exposes no general method generation. Its class-variable
  state was priced as a cheap **incorrect** comparator, not an alternative.
  YJIT/ZJIT method-invalidation hooks are internal, not a public extension
  subscription API. Freezing forbids mutation rather than detecting it.

## Lowrail scope and measurement protocol

[Measured harness](https://github.com/thomasklemm/lowrail/commit/80456c9caa70e8e7e17665159d41b43f5b9ef46b),
branch `thomasklemm/method-token-experiment`.
Only an isolated harness changes guards for the **existing `memo/sha256`
unit**, with 19 dependencies. Token/public arms do not use the hook-validity
state; certification, tracing, constants, input and source guards remain.
Subscribe before certification and check again after it. No production pass
is promoted, no sealed restriction is removed, and default behavior is unchanged.

The request workload is an in-process production Rails 8.1.4 request through
middleware/controller to `GET /digest`, hashing a 22-byte asset key. This is
a small controlled app, **not the historical blog or a production app result**.
Every response is checked against the original operation. A separate
stats-enabled YJIT request worker recorded **14,599 fast-path hits**.

Both cohorts have eight randomized fresh-process rounds per mode, seed 41231,
500,000 micro checks and 2,000 measured requests per worker; GC stays enabled.
Native wall time includes request construction and response validation, but
not boot/warmup. Every worker records source/native hashes and Ruby revision.
The final cohort uses ordinary `--yjit`, not `--yjit-stats`, and also records
process CPU time. A/A requires the CPU and wall 95% intervals both to include
zero **and fit inside ±2%**; merely overlapping zero is insufficient.
YJIT warmup and measured compiled-ISeq/block/invalidation counters must be flat.
Micro prices include the loop and extension wrapper, not just a direct C call.
No Callgrind/Ir or fixed-heap speed claim is made.

The first cohort used YJIT stats instrumentation and an earlier raw-cache
build. Its request A/A wall intervals were −9.83%..+20.74% (interpreter) and
−12.98%..+29.62% (YJIT). It is retained as noisy diagnostic evidence, not a
price. The final pinned cohort is separate, not a retry-to-green procedure.

## Result: no accepted speedup

[Results and reduced samples](ruby-method-token-minimal-results.json) retain
both cohorts, all allocation observations, paired intervals and mutation probes.
**All four final A/A cohorts failed.** Request A/A wall intervals were
−8.92%..+18.15% (interpreter) and −26.40%..−0.31% (YJIT); CPU failed too.
YJIT `off_a`, round 6, also compiled one block during the request window
(14,552 → 14,553), despite a flat warmup. No failed sample is discarded.

These are **raw diagnostics, not accepted prices or speedups**:

| Mode | Off wall µs/request | Token wall µs/request | Paired token delta vs off, 95% CI | Allocations: off / tokens / public |
|---|---:|---:|---:|---:|
| Interpreter | 389.5 | 465.9 | +13.0%, [+0.7%, +35.2%] | 413 / 430 / 449 |
| Native YJIT | 148.2 | 147.6 | −1.3%, [−12.1%, +26.8%] | 415 / 432 / 451 |

Paired deltas are medians of within-round ratios, not ratios of absolute
medians. Relative to the old hook arm, raw token deltas were −2.4%
[−13.7%, +14.4%] interpreter and −14.4% [−27.1%, +33.3%] YJIT, likewise
inconclusive. The allocation difference versus reflection is 19 wrappers per
request, matching the 19 guarded dependencies. Tokens do not remove the memo
unit's other allocation overhead relative to the original operation.

| One check, wall ns including loop | Interpreter | YJIT | Allocations/check |
|---|---:|---:|---:|
| One token through the native aggregate checker | 38.5 | 10.3 | 0 |
| `Method#==` after lookup | 124.2 | 74.1 | 1 |
| `UnboundMethod#==` after lookup | 102.7 | 66.4 | 1 |
| Public C method-definition comparator | 142.1 | 106.7 | 1 |
| Captured reflection plus visibility | 401.1 | 273.7 | 1 |
| Owner-only lookup (incorrect substitute) | 107.7 | 58.4 | 1 |
| Class-variable stat (incorrect substitute) | 262.4 | 235.1 | 0 |
| Existing core-basic Hash predicate (narrower contract) | 58.8 | 29.2 | 0 |

The same failed A/A warning applies to this entire micro table. It suggests
the expected cost/allocation distinction, not a precise per-check guarantee.
There is **no measured application benefit on which to ask core to ship this**.

Correctness was also checked through complete Rails responses, separately
from timing, in both execution modes. After warmup, suppress
`Digest::SHA256.singleton_method_added`, replace `base64digest` with a sentinel,
and request the same route again:

| Guard | Interpreter hits before → after | YJIT hits before → after | Response |
|---|---:|---:|---|
| Hooks | 4,598 → 4,599 | 14,598 → 14,599 | stale digest; hook state still true |
| Public reflection | 4,599 → 4,599 | 14,599 → 14,599 | changed sentinel, status 200 |
| Tokens | 4,599 → 4,599 | 14,599 → 14,599 | changed sentinel, status 200 |

Thus public reflection is already sufficient for this named detection/fallback
case. Whether a larger, independently useful specialization makes its checking
cost unacceptable remains unestablished. That is the missing upstream argument.

## Verification and review boundaries

* Final-head affected Ruby `make test-all`: **566 tests, 17,232 assertions,
  no failures, errors or skips**.
* Broader YJIT `make test-all`, including GC and Ractor: **738 tests,
  19,785 assertions, no failures/errors, three skips**.
* Method/class/refinement bootstrap sets: **299 tests pass**.
* Lowrail memo/native/guard tests: **19 runs, 241 assertions, no failures or
  errors, three prerequisite skips** (RSpec, Vite/Inertia and rails_vite).
* Benchmark A/A/JIT control regressions: **7 runs, 87 assertions, no failures,
  errors or skips**. The full helper suite was not green: distro Valgrind
  hit the existing virtual-brk reservation limit in an operation-window test.
* An initial broad gem run failed for missing SQLite/bcrypt and an old Cargo.
  SQLite/bcrypt/libclang were installed and the relevant tests rerun with the
  rustup toolchain. This is not a full Lowrail suite pass.
* Independent implementation and two rounds of Thermos correctness and
  maintainability review led to deleting the redundant core TypedData wrapper,
  documenting fork semantics, and hardening the exported checker against
  non-callcache values. The suspected minor-GC UAF was withdrawn after tracing
  mark-bit/weak-reference ordering. Final type/docs/test hardening was directly
  reviewed and executed; static reviewers' last full range covered the previous
  version. The test-extension wrapper stays because raw IMEMOs must not reach Ruby.

Full Ruby `test-all`, other architectures, sanitizers, alternate collectors and
ZJIT were not run. No upstream PR, issue comment or workflow rerun was made.

Reproduction (use the built Ruby in `PATH`, and the rustup toolchain for builds):

```sh
# In the Ruby checkout:
make -C build -j4 test-all TESTS='ruby/test_method_token.rb ruby/test_method.rb ruby/test_module.rb ruby/test_class.rb ruby/test_refinement.rb'
make -C build -j4 test-all RUN_OPTS='--disable-gems --yjit' TESTS='ruby/test_method_token.rb ruby/test_method.rb ruby/test_module.rb ruby/test_class.rb ruby/test_refinement.rb ruby/test_gc.rb ruby/test_ractor.rb'
make -C build -j4 btest BTESTS='--sets=class,method,refinement'
# In Lowrail, after compiling the optional extension for that exact build:
rake -f gem/Rakefile compile
ruby bench/experiments/method_token_experiment.rb study NEW_DIRECTORY
```

## Draft upstream PR description — not submitted

```text
[Feature #22459] C-only method-lookup tokens
This exposes an existing normal call cache, not a second invalidation system.
Two C functions acquire/check it; no Ruby API, epoch, registry or hook is added.
The Lowrail fork uses it to abandon one shortcut after a suppressed method hook.
Public method reflection detects the same change, with per-check allocation.
Tests cover lookup changes, GC/compaction, Ractor refusal and fork.
Native Rails timing has not established a speedup; this remains experimental.
The small diff does not by itself establish a reason for Ruby to ship the API.
```
