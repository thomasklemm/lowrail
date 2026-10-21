Would MRI consider an API for subscribing to a method-lookup assumption and
cheaply checking whether it remains valid? The intended shape is scoped to
`(class, method name)`, using existing callable-method-entry (CME) invalidation,
not a new global cache key. I would appreciate guidance on whether a C-only
API, an opaque Ruby token, or another shape would fit MRI better.

Memoization and dependency-injection libraries, sorbet-runtime-style checks,
specialization tools and diagnostics sometimes need to detect changed method
lookup without preventing ordinary Ruby mutation. Ruby callbacks can be
suppressed; freezing holders and their complete ancestor chains is useful
where acceptable, but enforces a different contract. Tokens would support
unfrozen holders and detection/fallback, not make arbitrary inlining or heap
assumptions safe.

## Illustrative API and semantics

```ruby
token = RubyVM.method_token(klass, :method_name) # RubyVM::MethodToken or nil
token.valid?                                  # boolean
```

```c
VALUE rb_vm_method_token(VALUE klass, ID mid);
int rb_vm_method_token_valid_p(VALUE token);
```

The [current prototype](https://github.com/thomasklemm/ruby/commit/a30db2f20843940c089bd8247135a7c7cd475ca5)
accepts a Class, including an existing singleton Class, resolves/registers the
CME even without an existing callsite, and retains and pins the class and
entry until token GC. Missing/refined entries return nil; ordinary Modules
raise TypeError while enabled. A non-owning registry associates CMEs with
tokens; four existing CME/cache invalidation paths also permanently revoke
their registered tokens. Revocation may be conservative; renewal requires
revalidating assumptions. The C check of a genuine token allocates nothing
and invokes no Ruby callback. Acquisition does not call the target or
`method_missing`; Ruby name coercion may execute Ruby or raise.

Review of the first prototype found a
reproducible `Cannot malloc during GC`: `st_insert` can grow even when replacing
an existing registry head. The follow-up retains the registry but uses
existing-only `st_update` for destruction and existing-list registration,
with no allocation after borrowing a collectible head. `valid` is published
only after registration succeeds, so failed registration cannot unlink an
unpublished node. Compaction/parallel-sweep concerns were checked and not
established: `rb_gc_mark` pins the retained references, and the current GC
defers non-thread-safe `dfree` during parallel local sweeps. The header is
self-contained; experimental lookup-only RDoc was added. This API has no compatibility
guarantee; NEWS is deferred pending acceptance.

This is **a single-Ractor/GVL experiment**, not a final concurrency contract.
C callers require the GVL. The first multi-Ractor transition sets a latch
before other Ractors can run, permanently disabling acquisition (nil) and
checks (false) in every Ractor, even after termination and fork.
Revocation is skipped after disabling,
but GC still unlinks registered nodes. The resettable single-Ractor predicate
alone would allow fork revalidation. No concurrent-Ractor assumption API is
claimed.

A check is not a lock across later Ruby execution or thread switches. Consumers
must validate the original definition and independently guard the actual
receiver class, lexical scope and mutable values, then recheck at reentry
boundaries. A new per-instance singleton does not change lookup on the ordinary
class. Callees, including `super`, constants/autoload, refinements and Box
selection are not certified. Ruby wrappers are ordinary overridable methods;
the C interface is distinct.

## Why not a global epoch?

I initially prototyped a global mutation counter. It invalidates no caches
itself, but consumers suffer the coarse-grained churn that motivated
[Feature #18589](https://bugs.ruby-lang.org/issues/18589) and
[PR #5766](https://github.com/ruby/ruby/pull/5766).

In the earlier production-mode Fizzy census with Rails 8.1.4, after 200 warmup
requests, **every one of 1,000 authenticated `/bubbles` requests bumped it
20 times**. The sampled stack was `Module#extend_object -> Kernel#extend ->
ActiveRecord::Associations::CollectionProxy#initialize`, at
`collection_proxy.rb:37: extend(*extending)`, reached through association
reading from the assignees view. Five singleton creations, ten include
entry/exit bumps and five method-cache clears accounted for each request.
Ignoring singleton holders still left five ordinary superclass-cache bumps.

On the original master token build, `/bubbles` and `/buckets` each had **zero
invalidations of 12 held tokens**: `Hash#each`, Enumerable-owned
`Hash#each_with_object` and ten view/builder methods. `/bubbles` still had
20 epoch bumps/request. The blog's two endpoints and Fizzy `/buckets` had
zero epoch churn. These were selected dependencies, partly acquired through
a separately constructed view context, not complete endpoint execution
certificates or a universal stability claim. The global epoch remains a
rejected alternative, not the proposed API.

## Costs, tests and patch

The new read cohort measures Ruby at
[`a30db2f`](https://github.com/thomasklemm/ruby/commit/a30db2f20843940c089bd8247135a7c7cd475ca5),
on master base
[`cfa50b0`](https://github.com/ruby/ruby/commit/cfa50b00939fd07ae87ffceb730bd2cfbccd8553),
with a clean detached Lowrail harness at
[`0f83cd0`](https://github.com/thomasklemm/lowrail/commit/0f83cd0eddab1997c9dda6e54c6e990edab7dbfd),
recorded in every worker. GCC 12.2, `-O3 -g`, x86-64 Linux, patched Valgrind
3.19; one finite six-round pair, seed 41231, N=0/100,000, at most two workers.
Both modes passed Ruby/native A/A (95% intervals [0, 0]%), fixed-heap and
actual-JIT gates; every YJIT window was compilation/invalidation-flat. No
window collected; positive windows allocated zero objects. Net Ir/check:

| Operation | Interpreter | YJIT |
|---|---:|---:|
| Ruby token read / successful guarded branch | 184 / 202 | 103 / 106 |
| Direct C token validity check | 26 | 26 |
| Global epoch read / successful guarded branch | 194 / 265 | 75 / 91 |

Earlier figures on the pre-fix prototype are superseded and retained in the
[pinned evidence](https://github.com/thomasklemm/lowrail/blob/acfef7152895dbdb70caafbbf6823bf25cfa1ffd/docs/upstream-drafts/ruby-method-token-evidence.md).
An intervening mixed-harness cohort is INVALID for protocol drift; none of
its prices is claimed. The separately authorized pinned cohort had no retry.
Costs exclude acquisition/revalidation and failure paths, and are instructions,
not latency or application speedups. The token is not cheaper than the epoch
in YJIT; scope is the reason to prefer it. The historical 4.0.7 epoch read
was 195/36 Ir, a different build/cohort.

Historical write-side CPU timing: 4.0.7 epoch Rails blog boot +0.44%
(95% interval −2.62% to +1.86%), 100,000 `define_method` operations +2.81%
(+1.16% to +3.61%). The pre-fix master epoch+token definition result,
+1.24% (−2.06% to +22.21%), was too noisy for a precise token write-overhead
claim and held no subscriptions to the redefined method. The isolated
uncontended epoch CAS costs 7 net Ir, not a full mutation or contended atomic.
There is no master-token boot-cost result; subscribed revocation, memory use
and multicore writes remain unmeasured. These are not write-cost measurements
of the lifecycle fix.

On the current fix, interpreter and YJIT each pass **13 tests, 97 assertions**,
including the formerly failing lifecycle regression, GC stress/compaction,
lookup invalidation and permanent disabling after multi-Ractor entry,
preserved across fork. Allocation-failure
publication ordering was source-reviewed, not fault-injected. Historical
master `make test-all`: **38,696 tests, one failure, two errors, 221 skips**.
The exact identities reproduced on a clean-master targeted control:
`TestThread#test_handle_interrupt_masks_sigint` (missing stdout), and
`TestIO#test_seek` / `TestIO#test_seek_symwhence` (ENOENT). This is not a green
suite or full clean-master equivalence; full `test-all` was not rerun on the
follow-up. Tests also cover deprecated constant removal reentering
`Warning.warn`: the epoch changes before the callback, but method tokens
do not cover constants. A constant-name token needs a separate design, not
blind subscription to the late constant-cache invalidator.

- [Prototype branch](https://github.com/thomasklemm/ruby/tree/mutation-epoch-prototype)
  ([patch](https://github.com/thomasklemm/ruby/compare/cfa50b00939fd07ae87ffceb730bd2cfbccd8553...mutation-epoch-prototype.patch)):
  rejected global experiment, original scoped tokens, then the lifecycle fix;
  original commit links are preserved. No upstream PR has been opened.
- [Evidence, controls and limitations](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream-drafts/ruby-method-token-evidence.md).
- [Lowrail](https://github.com/thomasklemm/lowrail), the motivating experiment;
  [earlier epoch investigation](https://github.com/thomasklemm/lowrail/blob/main/docs/passes/vm-epoch.md).

The token direction follows [Feature #16614](https://bugs.ruby-lang.org/issues/16614).
I also found [Feature #17660](https://bugs.ruby-lang.org/issues/17660), but no
supported API with this scoped subscription contract in master at the pinned
base (2026-10-21). This is a scoped search finding, not an exhaustive survey.

Would exposing this kind of assumption be useful and maintainable? Which
ownership, lifetime, concurrency and reentry semantics would core prefer?
Would a C-only interface or an existing facility be a better starting point?
