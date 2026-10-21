# Scoped method-assumption tokens: prototype evidence

2026-10-21. Experimental MRI API, not a production correctness or speed claim.
This document is self-contained and may be attached to a Ruby Feature ticket.

Posted by the owner as [Feature #22459](https://bugs.ruby-lang.org/issues/22459).
The posted description is historical; the review correction below has not
been posted by this thread. **Final-source read-cost remeasurement is pending.**

**Recommendation:** discuss scoped method-validity tokens, not a global
mutation counter. A production-mode request invalidated the global snapshot
20 times on every request, but invalidated none of the 12 held method tokens.
Constants need a separate design. The prototype has no cross-Ractor contract.

## Source and proposed surface

[Prototype branch](https://github.com/thomasklemm/ruby/tree/mutation-epoch-prototype),
on ruby/ruby master
[`cfa50b0`](https://github.com/ruby/ruby/commit/cfa50b00939fd07ae87ffceb730bd2cfbccd8553)
(re-fetched on 2026-10-21). It contains an
[epoch experiment](https://github.com/thomasklemm/ruby/commit/535cf1796028189e1ab5346101568b454ca58c35)
followed by the
[original token prototype](https://github.com/thomasklemm/ruby/commit/30c96264ab0fb6e7c6e14336679ff0ca4079ca56)
and the reviewed
[lifecycle fix](https://github.com/thomasklemm/ruby/commit/a30db2f20843940c089bd8247135a7c7cd475ca5).
[Combined patch](https://github.com/thomasklemm/ruby/compare/cfa50b00939fd07ae87ffceb730bd2cfbccd8553...mutation-epoch-prototype.patch).
The original linked commits are preserved; the global epoch remains a rejected
alternative. None changes Ruby's cache policy. No upstream PR has been opened.

Ruby surface:

```ruby
RubyVM.method_token(klass, name) # -> RubyVM::MethodToken or nil
token.valid?                   # -> true or false
```

C surface, declared in `include/ruby/vm.h`:

```c
VALUE rb_vm_method_token(VALUE klass, ID mid);
int rb_vm_method_token_valid_p(VALUE token);
```

- `klass` must be a Class, including an already-existing singleton Class;
  an ordinary Module raises `TypeError` while tokens are enabled. Ruby `name`
  uses `rb_to_id` conversion, which may execute Ruby coercion code.
  Acquisition returns `nil` for a missing or refined callable method entry
  (CME). It does not call the target or `method_missing`.
- Acquisition resolves/registers the lookup even without a Ruby callsite,
  allocates an opaque token, and retains its class and CME until token GC.
  Tokens sharing a CME share its invalidations; this is not exact event
  reporting or a promise never to invalidate conservatively.
- Four existing method-cache/CME invalidation paths that notify YJIT and ZJIT
  also permanently clear held tokens for that CME while enabled. Checks with
  a valid token argument allocate nothing and execute no Ruby callback.
  An invalid token never becomes valid again;
  consumers must revalidate their assumptions and acquire a fresh token.
- A native non-owning registry is keyed by CME; token GC unlinks live entries.
  Revocation walks the held tokens for the affected CME. Memory retention and
  revocation fan-out have not been benchmarked at large subscription counts.
- **Prototype restriction:** C callers require the GVL. The first transition
  to multi-Ractor mode permanently disables acquisition (`nil`) and checks
  (`false`) in every Ractor, even after termination or fork. A persistent
  latch is set before other Ractors can run; the resettable single-Ractor
  predicate alone is insufficient. Revocation is skipped after disabling;
  registered nodes still unlink at GC. No concurrent-Ractor API is claimed.
  These restrictions are not a proposed final concurrency design.
- The token concerns lookup on the specified class, not the identity of a
  later receiver. Adding a singleton to one instance leaves its ordinary
  class token valid. Consumers need an independent actual-receiver-class
  guard. Callees (including `super`), refinements, lexical/Box selection and
  mutable values are not certified. Ordinary Ruby wrappers are overridable;
  the C entry is distinct.
- A successful check is not a lock across subsequent Ruby calls or thread
  switches. Recheck after reentry before using an assumption, and do not
  replay already-executed application effects during fallback.

## Final-source review and regression evidence

Thermos correctness and maintainability reviews plus an independent oracle
review informed the fix. The final oracle found no blocker within the
documented single-Ractor, lookup-only, non-refinement/non-Box boundary. This
is source review, not exhaustive VM invalidation coverage or API acceptance.

- **Reproduced lifecycle crash:** collecting list heads with live sibling
  tokens across four CMEs aborted with `[BUG] Cannot malloc during GC`.
  `st_insert` can grow even when replacing an existing key. Both destruction
  and existing-list registration now use an existing-only `st_update`;
  its callback returns `ST_STOP` for an absent key. No allocation follows
  borrowing an unrooted list head. The retained regression failed before
  the fix and passes afterward.
- **Registration exception safety:** zero-initialized `valid` is published
  only after successful registration. A raised allocation failure cannot
  make an unpublished node unlink itself. Allocation failure injection was
  not performed; this ordering was source-reviewed and GC-stress tested.
- **Ractor/fork revalidation:** the resettable single-Ractor predicate could
  make a disabled token valid again in a forked child. The persistent latch
  fixes this. Regression tests cover termination and fork, with/without a
  subsequent definition change, and no intervening token API call.
- **Header/docs:** `<ruby/vm.h>` directly includes its boolean dependency;
  standalone C99 `-Werror` compilation passes. MRI-style RDoc documents the
  experimental API and lookup-only scope. NEWS is deferred pending core's
  acceptance rather than advertising a released facility.
- **Not established:** live class/CME references are pinned by `rb_gc_mark`,
  so the alleged compaction address hazard was not confirmed. Current master
  defers non-thread-safe `dfree` in parallel local sweeps; the alleged
  parallel-free registry race was not confirmed. Keep the registry: leaf
  invalidators notify JITs without setting `METHOD_ENTRY_INVALIDATED`.
- A final reviewer alleged included-module redefinition missed a child-class
  token. Both the focused test and an independent executed probe revoked
  the held token and observed the new result. The source complements the CME
  on the defining ICLASS; the allegation was not confirmed, so no speculative
  VM-cache change was made.

On the exact pushed fix, interpreter and YJIT each pass **13 tests, 97
assertions, zero failures/errors/skips**, including GC stress, lazy sweep,
compaction, suppressed callbacks, visibility/alias/remove/undef,
include/prepend, singleton replacement and fork refusal. A direct-C probe
returned ten successful checks before redefinition and zero afterward.
Installed Ruby SHA-256:
`60e66e78e0e887084232bbc3eebd3f19ddc331a8c126cf0a4b50572df7027a30`.
The final full `test-all` was not rerun; the historical non-green results
below remain limitations, not final-source certification.

## Final-source read-cost status: pending

The first post-fix interpreter/YJIT attempt is **INVALID: protocol drift**.
Ruby stayed pinned to the pushed fix, but a Lowrail pull during the cohort
mixed observer harnesses from `315d56f7dd8982c3eb974536c252b4aeb3709a81`
and `2ae8c72553b30493b71bdec22316099bf43b4475`. Among the first 20 completed
interpreter workers, 18 lacked placement observations and two had them.
No price from this attempt is claimed, irrespective of its numerical gates.
Raw evidence is retained under `/tmp/epoch-research/token-pushed-interpreter`
and `token-pushed-yjit`; results JSON records the rejected attempt separately.
A new, explicitly authorized finite cohort will use an immutable detached
harness worktree and record its exact SHA per worker. It is not yet evidence
for a revised price. All read-cost figures below are **historical**.

## Steady-state production-mode churn

Rails 8.1.4, Lowrail off, actual YJIT enabled, eager loading, 200 warmup
requests followed by 1,000 in-process Rack requests per endpoint. Every
measured request returned HTTP 200 with a nonempty body. This measures these
fixtures/endpoints, not general production traffic or optimized responses.

| Build/application/endpoint | Epoch bumps/request | Requests with a bump | Held-token invalidations/request |
|---|---:|---:|---:|
| Ruby 4.0.7, blog `/articles` | 0 | 0/1,000 | Not measured |
| Ruby 4.0.7, blog `/articles/1` | 0 | 0/1,000 | Not measured |
| Ruby 4.0.7, Fizzy `/first_run` | 0 | 0/1,000 | Not measured |
| Ruby 4.0.7, authenticated Fizzy `/buckets` | 0 | 0/1,000 | Not measured |
| Ruby 4.0.7, authenticated Fizzy `/bubbles` | **20** | **1,000/1,000** | Not measured |
| Master token build, authenticated Fizzy `/buckets` | 0 | 0/1,000 | **0** |
| Master token build, authenticated Fizzy `/bubbles` | **20** | **1,000/1,000** | **0** |

Fizzy source pin:
[`6f1d200`](https://github.com/basecamp/fizzy/commit/6f1d200316ec3bae91d32c557d88647300807ee9).
The existing corpus dependency overlay was used. The master bundle additionally
relaxed its Ruby-version constraint and used redcarpet 3.6.1 rather than 3.6.0
because master removed its old Data_* API. No application-source behavior
change was made. A disposable database used a normal signed Session fixture.
Some census runs logged failed Sentry envelope sends; use `SKIP_TELEMETRY=1`
when reproducing. These are not telemetry-free full deployment measurements.

The per-source census sampled a Ruby stack once per VM seam/holder kind.
Every `/bubbles` request produced 5 singleton creations, 10 include entry/exit
bumps and 5 method-cache clears. The stack was:

```text
Module#extend_object
Kernel#extend
ActiveRecord::Associations::CollectionProxy#initialize
  collection_proxy.rb:37: extend(*extending)
ActiveRecord::Delegation::ClassMethods#create
ActiveRecord::Associations::CollectionAssociation#reader
Account::GeneratedAssociationMethods#users
filters/_assignees.html.erb
```

Ignoring bumps whose immediate holder is a singleton still left **5/request**:
include also cleared an ordinary superclass cache. This rejects that simple
filter, not every possible root-operation filter; omitting singleton mutation
would in any event lose facts that some consumers need. A global counter does
not itself invalidate caches, but consumers comparing it would still lose
their snapshots on every one of these requests.

The 12 held dependencies were `Hash#each`, `Hash#each_with_object`
(Enumerable-owned), seven view methods (`convert_options_to_data_attributes`,
`link_to_remote_options?`, `url_target`, `url_for`, `content_tag`,
`ensure_valid_html5_tag_name`, `tag_builder`), and three TagBuilder methods
(`content_tag_string`, `tag_options`, `tag_option`). Tokens were checked after
each request and would be renewed on invalidation. Neither the per-instance
extend nor the superclass cache clearing invalidated these held tokens.
This is not a claim that every possible application token would survive.

## Historical read/check costs (original token revision)

Native CPU-time diagnostics preceded Callgrind. The direct C token-check loop
cost about **3.59 ns/iteration**, including an empty native-call loop of about
1.40 ns; the isolated uncontended CAS loop cost about 11.83 ns including the
same loop. These are machine-specific diagnostics, not stable latency claims.
The native Ruby-loop probe did not establish steady YJIT compilation, so its
Ruby/YJIT latencies are not used as evidence.

Original master token build (the linked token prototype, not the lifecycle
fix), x86-64 Linux, GCC 12.2, `-O3 -g`, Valgrind 3.19
(512 MiB brk reservation). One finite six-round cohort per interpreter/YJIT
mode, seed 41231, at most two workers. N=0/100,000 slopes subtract paired
same-round empty Ruby-loop or native-call-loop slopes. Fixed per-pool floors
on master's 12 pools were 1m/1m/250k/250k/100k/100k/100k/20k/10k/10k/10k/10k.

| Net executed instructions (Ir) per operation | Interpreter | YJIT |
|---|---:|---:|
| Epoch read | 194 | 75 |
| Epoch read + equality + successful guard | 265 | 91 |
| Ruby `token.valid?` read | **183** | **102** |
| Ruby `raise unless token.valid?`, successful path | **201** | **105** |
| Direct C `rb_vm_method_token_valid_p`, net of native empty call | **26** | **26** |
| Isolated uncontended epoch CAS, net of native empty call | **7** | **7** |

Both cohorts passed Ruby A/A, native A/A, fixed-heap and actual-JIT gates;
all YJIT measured windows passed the flat compilation/invalidation-counter
gate. A/A 95% intervals were [0, 0]%, within ±0.5%. No measured window
collected; positive windows allocated zero objects. Total and GC-excluded
net prices agree to floating-point precision. Nominal bootstrap 95% intervals
round to [value, value] because these synthetic paths are deterministic.
There were no retries-to-green. Both allocated Callgrind slots were released.

The historical Ruby 4.0.7 epoch result was **195/267 interpreter and 36/52
YJIT Ir** for read/check respectively. It is a different build/cohort; it must
not be substituted for the current-master numbers. No acquisition, failure,
revalidation or whole-request saving is priced by the read micro. A token is
not inherently cheaper than the epoch in YJIT; its advantage here is scope.

## Write-side costs

Six randomized paired native CPU-time rounds, including A/A, interpreter
only; includes natural GC. These are not fixed-heap instruction speed claims.
Both 4.0.7 builds had identical `-O3 -g` flags and differed only by the epoch
patch (not the census instrumentation).

| Ruby 4.0.7 workload | Epoch vs clean, median | Bootstrap 95% interval | A/A interval |
|---|---:|---:|---:|
| Production blog Rails boot (baseline about 1.12 s CPU) | +0.44% | −2.62% to +1.86% | −2.34% to +1.76% |
| 100,000 repeated `define_method` (baseline about 0.051 s) | +2.81% | +1.16% to +3.61% | −2.91% to +1.32% |

An additional master definitions cohort found epoch+token +1.24%
[−2.06%, +22.21%], epoch alone +1.57% [−2.52%, +13.63%], A/A
[−2.48%, +3.99%]. It is **too noisy for a precise token write-overhead claim**,
and it did not hold subscriptions to the repeatedly redefined method. A
master Rails-boot attempt stopped before measurement because json default
3.1 conflicted with bundle 2.9; there is no master-token boot-cost result.
The 7-Ir isolated CAS is not the cost of a complete definition or a contended
atomic. Subscription-heavy revocation, memory use and multicore writes remain
unmeasured.

## Standalone counterexample matrix and tests

The public branch's tests are in `test/ruby/test_method_token.rb` and
`test/ruby/test_mutation_epoch.rb`. The matrix intentionally distinguishes
method lookup from constants, receiver selection and heap facts.

| Counterexample/fact | Method-token result | Epoch result / boundary |
|---|---|---|
| Suppressed `method_added`; redefine watched method | Revoked, including sibling tokens | Changed |
| Unrelated method added | Watched token stayed valid | Conservative change |
| Visibility; alias replacement; remove; undef | Revoked | Changed |
| Include overriding inherited method; prepend | Revoked | Changed |
| Target replaced on an existing singleton class | Singleton token revoked | Changed |
| New singleton override on an instance | Ordinary-class token stays valid; receiver-class guard required | Changed, but does not establish receiver provenance |
| No prior Ruby callsite; GC/compaction | Acquisition registers dependency; held tokens survive GC, then revoke on edit | No subscription needed |
| Missing/refined lookup, ordinary Module | Missing/refined refused; Module TypeError | Epoch does not certify initial lookup or refinement scope |
| Suppressed `const_added`, uncached const_set/remove | Not covered | Changed without populated constant inline caches |
| Uncached autoload registration/materialization/removal; constant visibility | Not covered | Changed in standalone tests |
| Deprecated constant removal reenters `Warning.warn` after deletion | Not covered by method tokens | Changed **inside callback**; bump must precede warning, not just the later constant-cache invalidator |
| Hash contents/defaults, ivar receiver replacement, String state | Not covered | Not covered |

The Warning.warn regression specifically records `[constant_present: false,
epoch_changed: true]` during the callback. The first historical epoch draft
missed this ordering; the published epoch commit fixes it. A future constant
token cannot simply subscribe to the late cache invalidation seam and assume
this case is safe. A per-constant-name token is **not implemented** here.

Historical targeted interpreter and YJIT runs each passed **10 tests, 59 assertions,
0 failures/errors**. `make test-all` on the master token build ran **38,696
tests, 8,083,623 assertions, 1 failure, 2 errors, 221 skips**, using the
repository-default excludes (including `memory_leak`) and four test workers.
The three exact
failure/error identities also reproduced in a clean-master targeted control:

- `TestThread#test_handle_interrupt_masks_sigint`: missing `"outer"` stdout;
- `TestIO#test_seek`: ENOENT;
- `TestIO#test_seek_symwhence`: ENOENT.

The clean-master control restored the changed VM sources/header to the pinned
base and verified the epoch API absent; copied version metadata still named
the epoch commit. It was a **targeted control, not a clean full-suite run**.
The 4.0.7 patched full run had 32,800 tests, 1 failure, 2 errors, 318 skips;
its clean full control had 33,786 tests and the same three identities/skips.
Test counts/assertions differ, so these are not identical per-test outcomes.
No new failure identities were observed; **the full suite was not green**.

## Alternatives and upstream context

- [Feature #16614](https://bugs.ruby-lang.org/issues/16614) introduced
  per-class method caches and method-entry validity rather than coarse class
  serial invalidation. A scoped assumption API would build on that direction.
- [Feature #18589](https://bugs.ruby-lang.org/issues/18589) moved constant
  invalidation to name components; Shopify reported frequent global churn
  ([about one request in 30](https://blade.ruby-lang.org/ruby-core/107606)).
  [PR #5766](https://github.com/ruby/ruby/pull/5766) replaced the misleading
  `global_constant_state` stat with invalidation/miss metrics. Method-cache
  design is covered by #16614 above. The `/bubbles` census independently
  demonstrates why restoring one global assumption key is not the primary ask.
- [Feature #17660](https://bugs.ruby-lang.org/issues/17660), still open when
  checked, asks for basic-method redefinition introspection, not scoped
  subscriptions. Inspection/search of master's `RubyVM.stat`, public VM/debug
  headers and YJIT/ZJIT invalidators at the pin above found no supported API
  with this token contract. That is a scoped search finding, not proof that
  no related discussion exists.
- **Enforced sealing:** `Module#freeze` on holders and their full ancestor
  chains is a no-VM-change alternative where acceptable. It prevents writes
  rather than detects them; it does not alone freeze per-instance singletons,
  establish refinement selection or freeze mutable heap values. Tokens would
  serve unfrozen holders/apps that cannot freeze, and detection/fallback
  instead of enforcement. Real-app sealing feasibility is not established by
  this experiment.
- Per-constant-name assumptions could complement method tokens, but need a
  separate acquisition/lifetime/reentry design. TracePoint/user hooks and
  snapshots are not equivalent to a VM-owned revocation bit: hooks can be
  suppressed, and visibility/constant/reentry coverage differs.

## Reproduction and retained evidence

[Lowrail repository](https://github.com/thomasklemm/lowrail) contains the
[paired data/controls/census stacks](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream-drafts/ruby-method-token-results.json), the
[historical epoch investigation](https://github.com/thomasklemm/lowrail/blob/main/docs/passes/vm-epoch.md), and these drivers:

- `bench/experiments/vm_epoch_census.rb`, production-only Rack census;
- `bench/experiments/vm_epoch_fizzy_setup.rb`, disposable signed-session fixture;
- `bench/experiments/vm_epoch_writes.rb`, paired native boot/definition driver;
- `bench/experiments/vm_token_cost.rb` and `vm_token_native.c`, read/C/CAS micros.

Apply the original `ruby-4.0.7-mutation-epoch.patch`, then
`ruby-4.0.7-epoch-census.patch` for the diagnostic census build only. It retains
at most one 12-frame stack for each of 64 seam/holder-kind buckets; it is not a
timing build or cross-Ractor diagnostic. The public master branch omits this
instrumentation. In an isolated prepared corpus app, run:

```sh
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 SKIP_TELEMETRY=1 \
  /path/to/census-ruby --yjit /path/to/vm_epoch_census.rb /articles
# On the master token build, add CENSUS_TOKENS=1 and, for disposable Fizzy,
# CENSUS_SETUP=/path/to/vm_epoch_fizzy_setup.rb; use /buckets /bubbles.

BENCH_JOBS=2 BENCH_JIT=0 /path/to/token-ruby \
  bench/experiments/vm_token_cost.rb micro NEW_INTERPRETER_DIR
BENCH_JOBS=2 BENCH_JIT=1 /path/to/token-ruby \
  bench/experiments/vm_token_cost.rb micro NEW_YJIT_DIR
```

The micro uses the existing paired fixed-heap harness and requires its patched
Valgrind on PATH. Reserve Callgrind slots before running it. Read the retained
native A/A samples as well as the harness's Ruby A/A gate. JSON retains paired
slopes and aggregate controls, not all original per-window worker dumps.
All results are finite-cohort evidence; no endpoint specialization or public
API stability claim follows.
