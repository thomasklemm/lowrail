# Guarded memo: certified expressions, not arbitrary methods

PLAN §9.2a, measured 2026-10-20. **Opt-in:** `lowrail build APP --memo`.
Ruby 4.0.7 +YJIT; Campfire and Rails pins are those in
[Campfire M0](../m0/campfire.md). real-blog uses Rails 8.1.4.

## What actually qualifies

Prism finds calls in Ruby files under `app/`. A booted Ruby oracle supplies
an **audited intrinsic certificate**, not a heuristic that a stable method
owner implies purity. Two expressions currently have certificates:

| Expression | Runtime keys | Boot facts / boundary |
|---|---|---|
| `URI.join(base, relative)` | Both complete strings **and their encodings** | URI 1.1.1/1.1.2 implementation, parser/scheme constants, full method closure; **no regexp timeout** |
| `Digest::SHA256.base64digest(string)` | Complete string and encoding | Digest 3.2.1, audited Ruby wrapper and native initialize/digest/reset/update/finish/pack dispatch |

**The important refusal:** Rails 8 sets `Regexp.timeout = 1`. A cached URI
could suppress a `Regexp::TimeoutError`, even if the mathematical URL is
unchanged. Therefore the default Campfire build **does not memoize URI.join**.
The setting is not changed to manufacture coverage or a speedup. A runtime
change from nil to a timeout also immediately uses the original call.

Campfire lowers **one SHA-256 expression** in `InlineScriptHashes#script_hashes`.
The two script values (resolved importmap and entry-point script) are actual
runtime keys, not guessed boot constants. This is a smaller opportunity than
M0's 34.8% inclusive `script_locations` budget. Importmap resolution,
`JSON.parse`, URL parsing, asset hosts/procs, config reads, and CSP construction
still execute every request. Dynamic resolvers therefore retain their effects;
different results cannot reuse a different string's digest. No app path,
controller name, or particular importmap is recognized by the pass.

## Delivery and guards

The existing `load_iseq` seam serves same-line, per-expression splices. The
original receiver and arguments evaluate exactly once, in their original
order; the fallback block retains lexical method dispatch. A load-time whole
method variant would need a certificate for the entire resolver/method and
would discard more observable work, so it is not justified here. Method
names, visibility, parameters and fallback bodies remain intact.

Each intrinsic/file gets a normal manifest unit, with method facts plus an
additive `memo` certificate containing `intrinsic`, `sources`, and `config`.
Sources carry **mtime (rational), size and SHA-256**. These are implementation
inputs, not an assertion that arbitrary data files are immutable. URI pins
approved source contents; Digest pins its Ruby wrapper, native extension
files, version and concrete dispatch owners. Runtime/fact helper files are
pinned too. The main facts schema and independent capture hooks are unchanged.

`Lowrail::Guard` invalidates on the usual method/module changes. A new guard
generation discards old entries, even if a stub later restores its owner and
source line. First preparation/revalidation checks source identities and the
certificate again. Calls also check constant identities and primitive inputs;
URI additionally checks the current native regexp-timeout getter. Unsupported
arguments, wrappers, stale files or config use the original expression. Original
exceptions are outside the guard rescue and are never cached.

Only ordinary Strings without singleton behavior qualify. Lookup, computation
and insertion use the **same private frozen String snapshots**, with encodings
read from the snapshots too. Concurrent changes to caller-owned inputs cannot
associate another value's result with a retained key. This deliberately selects
snapshot semantics for otherwise-racy input mutation; unsupported calls still
receive the original objects. At most **256 entries per unit** retain those
keys, never request/controller objects. Entries stop growing at that limit;
it is not an LRU. URI returns get
fresh objects and fresh component strings with the original encoding/frozen
bits. Digest returns get a fresh mutable US-ASCII String. Caller mutation of
either a key or a returned value cannot poison a subsequent call.

Tracing is deliberately conservative. `TracePoint.stat` misses targeted
TracePoints. Existing TracePoints, or subsequent Ruby TracePoint construction
or activation, permanently disable memo reuse, except for the exact preexisting
Lowrail RSpec attach hook: its `:end` events cannot observe these intrinsics.
That hook stays intact and its implementation file is pinned. Its active-hook
allowance disappears when it normally disables itself; it never hides another
hook. Legacy `set_trace_func` also
forces fallback while active. Hooks forward arguments, keywords, blocks,
exceptions and returns. A one-off ObjectSpace sentinel detects incomplete
enumeration after multi-ractor mode. Foreign-ractor calls use the original
expression. There is no heap walk on the hot path.

Every inspected refusal is in `ledger.json`: whole methods without a purity
certificate; JSON/resolver/file digest calls; unsupported arity, splats, blocks
or multiline calls; nested overlaps; refinements/reflective activation; unknown
implementations; and URI's timeout boundary. Runtime argument declines are not
written to disk per request. `LOWRAIL_UNITS`, environment guards, bisection,
denylisting and `LOWRAIL=0` retain their existing meanings. Without `--memo`
there are no memo units or memo-specific tracing hooks.

## Equivalence evidence

```sh
cargo test
ruby -Igem/lib -Igem/test -e 'Dir["gem/test/*_test.rb"].sort.each { require_relative _1 }'
target/debug/lowrail build .corpus/campfire --memo
PARALLEL_WORKERS=1 target/debug/lowrail verify .corpus/campfire -- bin/rails test --seed 35709
RUBY_DEBUG_ENABLE=0 PARALLEL_WORKERS=1 target/debug/lowrail verify .corpus/campfire -- bin/rails test --seed 35709
target/debug/lowrail build .corpus/real-blog --memo
PARALLEL_WORKERS=1 target/debug/lowrail verify .corpus/real-blog
```

| Gate | Observed result |
|---|---|
| Campfire, default debug gem active | **634 identical**, 632 pass + 2 identical libvips skips, 3,856 assertions each; memo correctly declines tracing |
| Campfire, debugger disabled **in both modes** | **634 identical**, same assertions/skips; **1,242 actual SHA-256 memo reuses**, 7,861 total hits across 53 units |
| real-blog | **21 identical**, 54 assertions each; 57 existing-pass hits, zero fallbacks, **no eligible memo expression** |
| Gem suite | **69 tests, 1,078 assertions**, 0 failures/errors/skips |
| Rust | **26 unit + 2 integration**, all pass |

The debug flag is the debug gem's documented opt-out, not a test suppression.
The default-debug run remains a negative control (6,619 other-pass hits).
Campfire's memo unit is 41 in these integrated builds; unit 60's 1,250 hits
are the existing avatar route helper, **not memo hits**. Unit IDs are
build-local: identify the `memo/sha256` unit in the manifest. The concurrent
RSpec/verifier change fixed double-counting of merged report files; earlier
2,484 memo counts were doubled. Counters advance on reuse, not on a passed
guard or a fill. Checks were repeated after integrating concurrent `_url`
lowering and per-file loader policy; their additional coverage is included.
Freezolite 0.7.0/require-hooks 0.4.0 were installed for the full gem suite,
rather than leaving its two optional ecosystem tests skipped.

Regression coverage includes distinct hosts/schemes/ports/relative URLs,
ASCII-compatible and UTF-16 encodings, invalid/conversion inputs, argument and
return mutation, source staleness, mutable/custom scheme tables, constant
replacement, method wrappers, core reflection overrides, late YJIT activation,
targeted/global tracing, repeat installation, ractors and timeout changes.
Queue-handshaked threads change inputs both before computation and after its
result is ready; both intrinsics then check stable calls under old/new keys,
including URI encoding-only changes. These regressions fail before snapshotting:
the after-computation cases returned a wrong result for the new stable key.
The targeted-tracing test failed before the tracing fix. The independent
SHA-256 expected value is the published `abc` test vector, not a value
computed by the memo under test.

## Public Inertia analogue and ARGOS

The fixture `tests/fixtures/memo/inertia_version.rb` uses inertia_rails 3.23.0's
lazy `config.version = -> { ViteRuby.digest }` with ViteRuby 3.11.1. Its real
gem test changes a same-length watched file and observes a changed version
after ViteRuby's existing one-second cache expires. Prism **refuses** this
call: the public builder reads time, globs and files, changes directory and
mutates builder state. It is not a pure single-file digest. Guarding its owner
alone would not justify skipping those effects.

The public-app investigation separately found eager initializer assignments:
[PingCRM](https://github.com/ledermann/pingcrm/blob/22464f822dcf59c4425993dd623780ad44497fda/config/initializers/inertia_rails.rb)
and [Redprints CFP](https://github.com/evilmartians/redprints-cfp/blob/6080fc24fbf0015f7e5a5ae932e903731502c65a/config/initializers/inertia_rails.rb)
assign `ViteRuby.digest`; the
[React Starter Kit](https://github.com/inertia-rails/react-starter-kit/blob/f8081935e9bda68f8ef1ec53dc7eed19c819ee68/config/initializers/inertia_rails.rb)
assigns `RailsVite.digest`. These produce Strings at boot, not request-time
lambdas, so those pins are **negative controls**, not evidence of ARGOS's
12.8% request-time digest pattern. The separate
[public corpus investigation](../m0/inertia.md#version-digest-an-important-negative-control)
reports **400 authenticated requests per app**, zero version-digest calls,
and 2–3 expected trace events when explicitly invoking each digest as a positive
control. Stale-version controls return 409; unsigned controls return 302.
Those are that investigation's measurements, not a Lowrail speedup or an
additional local verify claim. `inertia_eager_version.rb` reproduces the public
assignment shape; the gem regression confirms that subsequent file changes
do not change the eager String, while the lazy fixture does observe them.

`Configuration#bind_controller` is a different candidate (the corpus thread
measured 0.7–2.0% self / 2.1–6.9% inclusive on Inertia JSON). The installed
3.23.0 implementation creates a fresh configuration with a **request-specific
controller** and fresh mutable options. A direct probe returned different
controller-dependent versions and independently mutable results. It is not a
boot-fixed memo result; encountered calls are refused in the ledger. A guarded
allocation/options-construction plan could be a separate optimization, not
permission to cache controller-bound objects. No speedup is claimed for it.

ARGOS is unavailable and was not built or verified. A future certificate for
its actual manifest reader must establish file inputs/content identity,
reader/digest method owners, configuration and fresh-return semantics. An
arbitrary Inertia version proc cannot qualify from its name or observed result.
This pass does **not** yet replace file digest calls or specialize that private
method; implementation-file fingerprints are not data-file memo support.

## Request measurements

Production fixtures/authentication/assets follow [Campfire M0](../m0/campfire.md).
`bench/memo_check.rb` requests room, messages, sidebar and search three times
each, checks HTTP 200 and fixture content, and exports only CSP header values.
Off/on exports compare **byte-identical** in both default-cache and
`CAMPFIRE_RESPONSE_CACHE_MB=0` modes. Each on probe records **20 memo reuses**;
off records zero. There are no policy relaxations or nonce substitutions.

```sh
RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 \
  target/debug/lowrail build .corpus/campfire --env production --memo
BENCH_ROUNDS=5 BENCH_SECONDS=3 ruby bench/memo_runs.rb \
  .corpus/campfire /tmp/memo-results
```

The harness uses `bench/requests.rb`: YJIT, 200 warmups per route, three seconds
per case, five fresh-process on/off pairs, alternating pair order, all four HTML
routes, sequential and without profilers or concurrent tests. Only memo units
are enabled; stats are off. Off is ordinary Rails, on includes Lowrail's
guard/load-time plumbing, not just the isolated intrinsic. Default response/
record caches and disabled response/record caches are measured separately;
fragment caches remain warm. Raw logs/authentication stay private in `/tmp`.

Each run reports mean request time; the table reports the median and
min–max of five process means, not a confidence interval or latency percentile.
Times are **µs/request**; positive change means slower. These are the final
cohort after input snapshotting, tracing/reporter and concurrent route/loader
integration, not pooled with earlier iterations.

| Cache / HTML route | Off median [min–max] | On median [min–max] | Time change | Median allocations off → on |
|---|---:|---:|---:|---:|
| Default / room | 2962.0 [2803.2–3372.0] | 2780.8 [2723.3–3008.0] | −6.1% | 6169.3 → 6205.8 |
| Default / messages | 2914.9 [2841.3–3318.7] | 2780.6 [2737.9–3070.9] | −4.6% | 6105.2 → 6141.6 |
| Default / sidebar | 2883.3 [2692.4–3086.8] | 2774.3 [2657.5–2966.8] | −3.8% | 6039.0 → 6075.4 |
| Default / search | 2939.4 [2800.5–2981.6] | 2860.8 [2717.0–3027.0] | −2.7% | 5999.9 → 6036.4 |
| Disabled / room | 15909.9 [15680.7–16579.1] | 18155.6 [16604.3–18870.1] | +14.1% | 22674.0 → 22718.7 |
| Disabled / messages | 10502.6 [10434.3–11153.5] | 10907.1 [10853.1–11780.3] | +3.9% | 15749.9 → 15790.6 |
| Disabled / sidebar | 10238.6 [9833.5–11169.1] | 11692.3 [10979.8–13581.0] | +14.2% | 14420.7 → 14460.3 |
| Disabled / search | 11900.1 [11715.5–12441.5] | 13731.5 [11402.5–15619.1] | +15.4% | 16191.4 → 16232.6 |

**Not a general net win.** Cached medians improve 2.7–6.1%, with overlapping
off/on ranges and mixed paired directions except messages (all five lower).
The cache-disabled medians instead **regress 3.9–15.4%**. Room, messages and
sidebar are slower in all five pairs; room's observed ranges do not overlap.
Do not dismiss those regressions as noise. These are net on/off results,
including Lowrail plumbing, not an attribution of all cost to hashing or input
copies. Allocations increase by approximately **36–45 objects/request**.
The pass remains opt-in; these numbers do not justify enabling it by default
or claiming the 34.8% importmap budget was removed.

## Open boundaries

- The major importmap/URI opportunity remains **refused under Rails defaults**.
  Relaxing the timeout or bypassing resolver/instrumentation semantics is not
  an optimization Lowrail is entitled to make.
- Narrow source/version certificates need review on upgrades. Native code
  replacement and definition hooks that bypass `super`, refinements outside
  the compiled source, ISeq inspection, and saved/native tracing entry points
  that bypass Ruby hooks retain the documented guard-system limitations.
  Concurrent method/config mutation between a guard and a return is not made
  transactional; mutable runtime input bytes/encodings are snapshotted.
- Conservative tracing can disable memo even for a boot-only or unrelated
  debugger; preload's boot TracePoint can likewise disable a combined build.
  This loses coverage rather than losing instrumentation events.
- General purity inference, file-content memoization and whole-method resolver
  certificates are not implemented. No general application-speed claim follows
  from successful reuse. Keep the pass opt-in until it is a measured net win.
