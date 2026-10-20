# Sealed links: pre-implementation prices

Status: operation prices, **not a deployed pass or request speed claim**.
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
