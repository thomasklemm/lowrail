# Feature: scoped method-assumption validity tokens

Posted by the owner as [Feature #22459](https://bugs.ruby-lang.org/issues/22459).
The original description below is preserved, not rewritten. Its costs and
main-Ractor wording describe the original prototype, not the reviewed fix.

## Correction comment draft — prepared before remeasurement

Prepared and delivered while pricing was pending. The cost follow-up below
updates that status; this thread has posted neither comment.

The prototype has a [review fix](https://github.com/thomasklemm/ruby/commit/a30db2f20843940c089bd8247135a7c7cd475ca5),
preserving the original commits and registry design. A new regression
reproduced `Cannot malloc during GC`: `st_insert` can allocate even when
replacing a registry head. Destruction and existing-list registration now
use non-inserting `st_update`, and `valid` is published only after registration
succeeds. Tokens now fail closed permanently at the first multi-Ractor
transition, including after Ractor termination and fork. The public header is
self-contained, and experimental lookup-only RDoc was added.

Interpreter and YJIT each pass **13 tests, 97 assertions**. Independent review
found no remaining blocker within that scope. Compaction and parallel-sweep
concerns were checked and not established: `rb_gc_mark` pins the retained
CMEs/classes, and non-thread-safe `dfree` is deferred. An alleged
included-module invalidation gap did not reproduce in the test or direct probe.

The previous Ir figures are **historical**, not measurements of this fix.
Remeasurement is pending: the first replacement cohort is **INVALID** because
it mixed observer-harness revisions, and no prices from it are claimed.
The non-green full-suite result, noisy write timing, limited endpoint census
and lookup-only/refinement/Box/constant exclusions remain unchanged; no final
full-suite equivalence or concurrent-Ractor guarantee is claimed.

## Cost follow-up comment draft — not posted

Remeasurement of the [reviewed fix](https://github.com/thomasklemm/ruby/commit/a30db2f20843940c089bd8247135a7c7cd475ca5)
is complete, using a clean detached Lowrail harness at
[`0f83cd0`](https://github.com/thomasklemm/lowrail/commit/0f83cd0eddab1997c9dda6e54c6e990edab7dbfd),
recorded in every worker. Net token read/successful-guard costs are **184/202
Ir in the interpreter, 103/106 Ir with YJIT**; direct C validity is **26 Ir**
in both. One finite six-round pair passed Ruby/native A/A (95% intervals
[0, 0]%), fixed-heap and actual-JIT/JIT-flat gates, with zero collections or
positive-window allocations. These supersede the historical token figures.
The mixed-harness attempt remains INVALID; it supplied no claimed price.
Costs exclude acquisition/revalidation and are instructions, not application
speedups. Non-green full-suite, noisy write timing and scope caveats remain;
[evidence and controls](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream-drafts/ruby-method-token-evidence.md).

## Original posted description — historical

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
unfrozen holders and apps that cannot freeze, with detection/fallback instead
of enforcement. They would not make arbitrary inlining or heap assumptions safe.

## Illustrative API and semantics

```ruby
token = RubyVM.method_token(klass, :method_name) # RubyVM::MethodToken or nil
token.valid?                                  # boolean
```

```c
VALUE rb_vm_method_token(VALUE klass, ID mid);
int rb_vm_method_token_valid_p(VALUE token);
```

The prototype accepts a Class (including an existing singleton Class), resolves
and registers the CME even without an existing callsite, and retains the class
and entry until token GC. Missing/refined entries return nil; ordinary Modules
raise TypeError. Relevant existing CME/cache invalidation paths permanently
clear the token. Checking allocates nothing and invokes no Ruby callback.
Invalidation may be conservative; renewal requires revalidating assumptions.

This is **a main-Ractor/GVL experiment**, not a final concurrency contract:
outside the main Ractor acquisition returns nil, checks return false and
revocation is ignored. Cross-Ractor mutation is not safe under this prototype.
A check is not a lock across later Ruby execution. Consumers still need actual
receiver-class guards (a new per-instance singleton does not change lookup on
the ordinary class), reentry checkpoints, and independent value/scope checks.
Constants/autoload, refinements and Box selection are not covered. Ruby
wrappers are ordinary overridable methods; the C interface is distinct.

## Why not a global epoch?

I initially prototyped a global mutation counter. It invalidates no caches
itself, but its consumers suffer the same coarse-grained churn that motivated
[Feature #18589](https://bugs.ruby-lang.org/issues/18589) and
[PR #5766](https://github.com/ruby/ruby/pull/5766).

In production-mode Fizzy with Rails 8.1.4, after 200 warmup requests, **every
one of 1,000 authenticated `/bubbles` requests bumped it 20 times**. The sampled
stack was `Module#extend_object -> Kernel#extend ->
ActiveRecord::Associations::CollectionProxy#initialize`, at
`collection_proxy.rb:37: extend(*extending)`, reached through association
reading from the assignees view. Five singleton creations, ten include
entry/exit bumps and five method-cache clears accounted for each request.
Ignoring singleton holders still left five ordinary superclass-cache bumps.

On the master token build, the same `/bubbles` and `/buckets` cohorts each had
**zero invalidations of 12 held tokens**: Hash#each, Enumerable-owned
Hash#each_with_object and ten view/builder methods. `/bubbles` still had 20
epoch bumps/request. The blog's two endpoints and Fizzy `/buckets` had zero
epoch churn. This is limited endpoint evidence, not a universal stability claim.

## Costs, tests and patch

One six-round fixed-heap Callgrind cohort per mode, paired A/A, N=0/100,000,
no retries-to-green. All heap, A/A and actual-JIT gates passed; every YJIT
window was compilation/invalidation-flat. Current-master net Ir per check:

| Operation | Interpreter | YJIT |
|---|---:|---:|
| Ruby token read / successful guarded branch | 183 / 201 | 102 / 105 |
| Direct C token validity check | 26 | 26 |
| Global epoch read / successful guarded branch | 194 / 265 | 75 / 91 |

These exclude acquisition/revalidation and are instructions, not latency or
application speedups. The historical 4.0.7 epoch read was 195/36 Ir; it is a
different build/cohort. The scoped token is not cheaper than the epoch in YJIT;
scope is the reason to prefer it.

The epoch's isolated uncontended CAS costs 7 net Ir. Paired native 4.0.7 CPU
time: Rails blog boot +0.44% (95% interval −2.62% to +1.86%); 100,000
define_method operations +2.81% (+1.16% to +3.61%). The master epoch+token
definition result, +1.24% (−2.06% to +22.21%), was too noisy for a precise
token overhead claim; subscription-heavy revocation remains unmeasured.

Standalone tests passed in interpreter and YJIT: **10 tests, 59 assertions**.
Master `make test-all`: **38,696 tests, one failure, two errors, 221 skips**.
The same exact identities reproduced on a clean-master targeted control:
`TestThread#test_handle_interrupt_masks_sigint` (missing stdout), and
`TestIO#test_seek` / `TestIO#test_seek_symwhence` (ENOENT). This is not a green
suite or a full clean-master equivalence run. Tests include deprecated
constant removal reentering Warning.warn: the epoch must change before that
callback; method tokens do not cover it. A constant-name token would need a
separate design rather than blindly using the late cache-invalidation seam.

- [Prototype branch on current master](https://github.com/thomasklemm/ruby/tree/mutation-epoch-prototype)
  ([patch](https://github.com/thomasklemm/ruby/compare/cfa50b00939fd07ae87ffceb730bd2cfbccd8553...mutation-epoch-prototype.patch)); the first commit is the rejected global experiment, the second adds scoped tokens.
- [Self-contained evidence, controls and limitations](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream-drafts/ruby-method-token-evidence.md).
- [Lowrail](https://github.com/thomasklemm/lowrail), the motivating experiment;
  [earlier epoch investigation](https://github.com/thomasklemm/lowrail/blob/main/docs/passes/vm-epoch.md).

The token direction follows [Feature #16614](https://bugs.ruby-lang.org/issues/16614).
I also found [Feature #17660](https://bugs.ruby-lang.org/issues/17660), but no
supported API with this scoped subscription contract in master at
[`cfa50b0`](https://github.com/ruby/ruby/commit/cfa50b00939fd07ae87ffceb730bd2cfbccd8553)
(2026-10-21).

Would exposing this kind of assumption be useful and maintainable? Which
ownership, lifetime, concurrency and reentry semantics would core prefer?
Would a C-only interface or an existing facility be a better starting point?
