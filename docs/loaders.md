# Loader composition and compile options

Checked 2026-10-21 on MRI 4.0.7 and 4.1.0-preview1 (`2d08b5f42f`). Lowrail
preserves per-file compiler policy; it does **not** enable frozen string
literals for the app. Neither build capture nor runtime delivery defines a
`load_iseq` method. The existing method's owner, source location and method
chain stay unchanged; require-hooks keeps its original adapter selection.
Redprints additionally needs the targeted Bundlebun refusal below: its strict
load census passes, but it now has **zero fast-path hits**.

## Why the process-wide fingerprint was insufficient

MRI calls `RubyVM::InstructionSequence.load_iseq(path)` once. A returned
ISeq replaces normal file compilation; nil leaves compilation to MRI. Ruby
module lookup supplies the only hook chain. A prepended loader that never
calls `super` hides earlier loaders.

Freezolite registers require-hooks `around_load` callbacks that temporarily
set `compile_option[:frozen_string_literal]` for matching paths, with a
different policy for excluded/nested requires. require-hooks executes the
file **inside** that callback and returns an empty ISeq. Serving before
`super` bypassed the callback; checking process defaults after it returned
missed the actual per-file compilation context. Bootsnap's selected
compiler can also pass per-file options without changing process defaults.

Build now observes the actual app boot's compiler calls using a disposable
Bootsnap cache, then replays both process defaults and explicit arguments on
the lowered source. Replaying only an explicit merged options hash is not
enough: on MRI 4.0.7, with process `frozen_string_literal: false`, even
`compile_prism('"x".frozen?', ..., {frozen_string_literal: true})` returns
false. The fixture caught that difference. Source magic comments remain
authoritative.

Runtime leaves the original loader alone and substitutes only at these
boundaries, after checking the per-file recipe fingerprint **and** the
original ISeq fingerprint and disk digest:

- **Native MRI compilation:** MRI's `InstructionSequence.translate(iseq)`
  callback handles plain require/load when no loader returns bytecode. Only
  tracked top-level file ISeqs are eligible, never method/block/eval ISeqs.
  Build observes the complete native binary, including its different
  top-level label; same-root delivery checks that actual binary without
  recompilation or fingerprint normalization. Standalone builds can obtain
  an additional native fingerprint by stopping the native C load at `translate`, before
  evaluation or `script_compiled`. This is never attempted through existing
  load hooks, translators, warning callbacks or active TracePoints. Existing
  translators retain the runtime boundary in either order. Custom warning
  callbacks also decline native substitution: they can change compiler
  options during parsing, so final defaults cannot certify the recipe.
- **Bootsnap:** `storage_to_output` substitutes after native cache
  serialization, for both cache misses and hits. Compiler APIs always return
  originals, including when a compiler uses a display filename different
  from the absolute source path. The cache remains safe for subsequent
  `LOWRAIL=0` processes or changed builds.
- **Explicit execution:** `ISeq#eval` substitutes inside require-hooks'
  callbacks. Its empty-ISeq protocol, source transformations and callbacks
  remain owned by require-hooks, not reconstructed by Lowrail.

Unknown recipes, changed source/transforms, missing or broken binaries, and
active Coverage retain original code. A foreign `translate` callback declines
all three delivery sites, including explicit eval and cached output: an
unchanged original cannot prove its policy for newly introduced instructions.
Digest is still loaded lazily, but
its nested requires preserve the active compile defaults. Runtime native
compilation occurs exactly once: certification must not call compiler
wrappers or re-emit source warnings. The app file is **never evaluated twice**.
No compiler/delivery hooks are installed for manifests without source files.
Unobserved inner compiler wrappers cannot inherit an outer default-options
snapshot. Old artifacts without the observed native fingerprint safely miss
native delivery until rebuilt; API/cache delivery retains its own certificate.

Deploy-root builds retain the relocatable format's separate portable
certificate: only the known native/file/text root label is normalized in the
complete `ISeq#to_a` digest. The build must reproduce the observed original,
including its native entry line 0 rather than API line 1; different nested
frame labels still refuse. A deploy-root native certificate is derived only
after that complete replay matches, never by reusing the same-root binary hash.

A require-hooks bytecode hijack can use options unrelated to Bootsnap's
selected compiler. Its warm cached binary does not prove that recipe, even
when its bytes match the original (options may affect only strings introduced
by lowering). Lowrail therefore never borrows Bootsnap's options for a path
with a registered hijack. Observable direct compiler calls remain guarded;
opaque cached hijacks retain their original bytecode.

This favors correctness over boot speed: the original ISeq must still be
compiled or read from the app's cache and fingerprinted. No boot-time or
application-speed improvement is claimed here.

## Ecosystem survey

These are source-level findings, not a claim that every listed integration
was executed. The regression matrix below names what was actually tested.

| Component | Seam and behavior | Lowrail consequence |
|---|---|---|
| [Bootsnap](https://github.com/rails/bootsnap/blob/main/lib/bootsnap/compile_cache/iseq.rb) | Prepends `InstructionSequenceMixin#load_iseq`, without `super`. Old versions compile with process defaults. 1.24+ selects `Compiler` objects per path; `FROZEN_STRING_LITERAL` supplies explicit options. `compile_option=` invalidates caches/updates compiler options. | Observe real calls on misses and `storage_to_output` on hits. Preserve selected options and keep the native cache unmodified. Opaque custom compilers without an observed recipe are declined. |
| [require-hooks](https://github.com/ruby-next/require-hooks/blob/master/lib/require-hooks/setup.rb) | Chooses ISeq, Bootsnap, or Kernel-patch mode. ISeq mode wraps compilation **and eval** in around callbacks; source transforms precede first-non-nil bytecode hijacks. | Delegation and the eval seam preserve callbacks. Actual compiler calls supply the recipe; the original ISeq detects changed transforms/hijacks. |
| [require-hooks + Bootsnap](https://github.com/ruby-next/require-hooks/blob/master/lib/require-hooks/mode/bootsnap.rb) | 0.4 wraps cache compilation and isolates cache directories. 0.5.1 wraps 1.24+ selected compilers in a namespaced `VersionedCompiler` and delegates to the original compiler. Around callbacks run on cache hits too. | Both paths remain intact. Namespaces and callback execution remain the gem's responsibility, not Lowrail's. |
| [Freezolite](https://github.com/ruby-next/freezolite/blob/master/lib/freezolite.rb) | A require-hooks user, not its own ISeq loader. Temporarily changes frozen-literal defaults; auto mode selects app Ruby files, excluding vendor. Experimental constant freezing is a source transform adding a pragma. | Replay and guard the observed per-file context. No implicit freezing; excluded files and explicit false magic comments retain their behavior. Experimental source transforms need analysis of transformed text and are currently declined at build. |
| [Bootsnap frozen literals](https://github.com/rails/bootsnap/blob/main/lib/bootsnap.rb) | `enable_frozen_string_literal(app_only: true)` uses the per-file compiler selector; global mode changes process defaults. | Both are compiler-policy inputs, not Lowrail configuration. Coverage support has Ruby/Bootsnap version restrictions imposed by Bootsnap. |
| [Ruby Next](https://github.com/ruby-next/ruby-next/blob/master/lib/ruby-next/language/runtime.rb) | Registers require-hooks source transforms for syntax transpilation. | Current passes analyze disk Ruby, not transpiled Ruby: transformed files are skipped with a build warning. Runtime never bypasses a newly installed transform. |
| [Tapioca RBS rewriting](https://github.com/Shopify/tapioca/blob/master/lib/tapioca/rbs/rewriter.rb) | Uses require-hooks transforms and explicitly handles later Bootsnap installation hiding those hooks. | Same transformed-source boundary; no assumption that RBS rewriting is an option-only change. |
| [Vernacular](https://github.com/kddnewton/vernacular/blob/master/lib/vernacular.rb) | Prepends an ISeq loader or adapts Bootsnap compilation; applies source modifiers. | Changed compiler input is not silently overwritten. Transformed files need lowering of the transformed source first. Not execution-tested here. |
| [Yomikomu](https://github.com/ko1/yomikomu/blob/master/lib/yomikomu.rb), MRI's sample ISeq cache | Defines `load_iseq` directly and reads/writes binaries. | Observable source compiler calls can be recorded; opaque warm binary caches have no proven recipe and safely miss. Not execution-tested here. |
| [Zeitwerk](https://github.com/fxn/zeitwerk/blob/main/lib/zeitwerk/core_ext/kernel.rb) | Wraps `Kernel#require` for autoload bookkeeping; does not select compile options or replace `load_iseq`. | Its original require/autoload notifications keep running. Exercised through all three Rails corpus apps. |
| [debug](https://github.com/ruby/debug/blob/master/lib/debug/session.rb), Coverage/SimpleCov | debug inspects ISeqs/traces rather than replacing the file compiler. Coverage needs source instrumentation; loaded binaries do not carry its counters. | No debug-specific delivery hook. Lowrail serves no binaries during Coverage; the regression checks actual executed-line counters, not just results. |

### Installation order

Lowrail may load before, between, or after Bootsnap and require-hooks. It
does not add an outer `load_iseq` hook at all, during build or runtime.
Other load methods and callbacks are not removed/reordered. A later Bootsnap
installation attaches the cache-output observer through the existing prepend
notification, without rewrapping the load method.

Bootsnap after require-hooks can hide require-hooks **without Lowrail too**.
Tests build with the app's own loader order and compare against that exact
baseline, including mutable literals when Freezolite is hidden. Lowrail must
not silently repair that order and change application behavior. To enable
Freezolite's policy, applications should follow its documented order:
Bootsnap first, Freezolite after. Lowrail preserves that order's literal
results **and** its loader selection; it does not force an adapter.

### Resolved: require-hooks adapter selection

In both [0.4.0](https://github.com/ruby-next/require-hooks/blob/v0.4.0/lib/require-hooks/setup.rb)
and [0.5.1](https://github.com/ruby-next/require-hooks/blob/v0.5.1/lib/require-hooks/setup.rb),
`REQUIRE_HOOKS_MODE` explicitly selects an adapter when set. Otherwise MRI's
automatic check is exactly:

```ruby
RubyVM::InstructionSequence.respond_to?(:load_iseq) &&
  (load_iseq = RubyVM::InstructionSequence.method(:load_iseq)) &&
  load_iseq.source_location[0].include?("/bootsnap/")
```

True selects `require-hooks/mode/bootsnap`; false selects `mode/load_iseq`.
Without MRI it uses the Kernel patch. Neither `defined?(Bootsnap)` nor the
method owner decides this. The former Lowrail wrapper changed the answer;
removing both wrapper definitions fixes the detector rather than falsifying
introspection or setting `REQUIRE_HOOKS_MODE`.

A fresh-process probe on Ruby 4.0.7, Bootsnap 1.26.0 and **each** require-hooks
version confirms the following. B = Bootsnap, H = require-hooks, L = Lowrail;
the off run keeps B/H order and disables L.

| Installation order | Off adapter | On adapter |
|---|---|---|
| L, B, H or B, L, H | Bootsnap | Bootsnap |
| B, H, L | Bootsnap | Bootsnap |
| L, H, B; H, L, B; H, B, L | plain ISeq | plain ISeq |
| L, H or H, L, without Bootsnap | plain ISeq | plain ISeq |

The earlier 32-process probe found adapter changes in 2/6 permutations while
still delivering the fixture correctly. The new regression compares the full
method chain (owners, source locations, parameters), adapter and census
during build and off/cold-on/warm-on/off runs, not only return values.

Late installation alone was rejected: it misses early file delivery and
does not establish that a detector never checks again. A registry would
require changing the app's loader; substituting at compiler return would
poison Bootsnap's cache. The three downstream boundaries above cover the
tested native/cold/warm/eval cases without either compromise.

### Refused: Bundlebun integration enumeration

In the historical pre-quarantine build, hook-free delivery removes
require-hooks' adapter difference in Redprints, but leaves **12 stable
load-event differences** (formerly 26), with the same 50 outcomes, 692 queries
and 277 hits across seven units. Bundlebun 0.5.0.1.3.14 enumerates
`Integrations.constants` unsorted and autoloads each entry. Additional
runtime identifier interning changes MRI's constant enumeration order.
An 18-process control separates this from adapter selection: all six off
and six setup-only boots use CSS/ExecJS/JS/Vite; all six active boots use
ExecJS/Vite/CSS/JS. The adapter is correct in every case.
An independent off-only probe changes integration order merely by compiling
(not evaluating) one additional symbol literal before app boot. Runtime
activation need not execute at all to expose this identifier sensitivity.

No exact general solution to that enumeration sensitivity is established.
Rather than sort someone else's constants or force their integration order,
setup refuses **all delivery and runtime activation before loading runtime
installers** if Bundlebun is already defined or the app's `Gemfile.lock`
lists it. This deliberately covers locked Bundlebun versions conservatively;
it does not load the gem to inspect it. Build records `bundlebun_load_order`
in the delivery ledger and manifest; stats expose `refusal_reason`. A saved
refusal also requires rebuilding after a lockfile change. Old artifacts
refuse through runtime detection too. This is not a certificate for arbitrary
dependencies introduced dynamically or through an unexamined alternate lock.

Redprints now passes strict verify: **50 pass, 692 identical queries, zero
stable load differences**, 32 unstable advisory entries, **0 hits / 0
fallbacks**. The **277-hit target is obsolete**: it is a pre-quarantine
aggregate, not today's eligible guarded build. The current gate is to retain
the eligible **14 `inertia/props` hits**, identical outcomes/SQL, unchanged
hook detection and zero stable load differences. That gate is **not
satisfied**. No sealed-only pass is re-enabled to recover the old total.
This is a targeted no-op, not full active support. See
[compatibility results](compat.md) and [DECISIONS](DECISIONS.md).

#### Bounded follow-up: delivery timing cannot certify this bundle

The pinned gem's Ruby source is
[Bundlebun 0.5.0, commit b18ac047](https://github.com/yaroslav/bundlebun/blob/b18ac047ca4f958e09de9003ef9daea1be2bf458/lib/bundlebun.rb#L90-L130).
It installs **no `load_iseq` hook**. At the bottom of `bundlebun.rb` it sets up
its Zeitwerk loader, prepends Bun's directory to PATH, loads tasks if Rake is
already defined, and calls `load_integrations` synchronously. That calls
[`Integrations.bun!`](https://github.com/yaroslav/bundlebun/blob/b18ac047ca4f958e09de9003ef9daea1be2bf458/lib/bundlebun/integrations.rb#L22-L28):

```ruby
integration_modules = constants.map { |const| const_get(const) }
  .select { |const| const.is_a?(Module) }
integration_modules.select { |mod| mod.respond_to?(:bun!) && mod.bun! }
```

`const_get` resolves the registered autoloads in this unspecified enumeration
order. CSS/JS integrations prepend task commands when their host is loaded;
ExecJS replaces its Bun runtime and assigns `ExecJS.runtime`; Vite prepends
runner extensions. None is a Lowrail delivery registry or a post-integrations
callback. Manual `load_integrations` repeats the walk, not a readiness signal.

Fresh Ruby 4.0.7 probes on Lowrail `01cfc45` observed natural entry/return of
`load_integrations`, without requiring Bundlebun early. A disposable artifact
contained only the eligible props unit; both refusal layers were bypassed
**only in the probe**, never in production. Before Bundlebun even enters the
walk, `inertia_rails/props_resolver.rb` is already in `$LOADED_FEATURES`.

| Probe | Actual integration file order | Props hits | Result |
|---|---|---:|---|
| Direct off, twice | ExecJS / Vite / CSS / JS | 0 | 50 passing examples |
| Direct early setup, twice | CSS / ExecJS / JS / Vite | 14 | 50 passing examples, **different actual load order** |
| Setup at natural integration return, twice | same as direct off | 0 | 50 passing examples, delivery already missed |
| Early setup with strict census | CSS / ExecJS / JS / Vite on both sides | 14 | 50 outcomes / 692 queries identical, 0 stable differences; **coincidental, non-certifying** |
| Setup at integration return with strict census | same as its off control | 0 | 50 outcomes / 692 queries identical, 0 stable differences |

The direct and census runs use the same activation probe; only the latter
boots the verification reporters. Observer/startup identifier allocation can
mask the divergence. A green census cohort is not proof that an unobserved
startup has the same order.

**The eight-difference compile-only control is an actual load-order change,
not a synthetic census difference.** It compiles one new symbol literal,
never evaluates it and never activates Lowrail. Two off and two on controls
agree within their sides. `$LOADED_FEATURES`, independently of the census,
records CSS / ExecJS / JS / Vite versus CSS / JS / ExecJS / Vite. Two swapped
entries, on/off, at first-test/after-suite account for all eight stable
entries. Owners, source locations, parameters and order of the complete
`load_iseq` chain remain equal; require-hooks still selects Bootsnap.

A separate **four-process census-free control** reproduces that same swap
with the single compilation: no Lowrail preload, reporters, TracePoint,
compiler override or census. It only reads `$LOADED_FEATURES` at exit, after
the loads. Thus the verifier can perturb which order appears, but it is
correctly reporting real Bundlebun integration loads here. A bare
`require "bundlebun"` without the Redprints startup prefix did not reproduce
the swap; the reproduction needs the app's identifier history.

Waiting until integration completion (or Rails initialization) cannot deliver
the already evaluated props file. Re-loading it would repeat app code, not
exact delivery. Early setup still allocates identifiers that influence
Bundlebun's unordered walk. Padding IDs, sorting its constants, forcing its
autoloads, or making the off arm allocate the active runtime is not an exact
fix. No public Ruby API reserves/restores this process-wide identifier state.
This is a bounded unsupported boundary for the locked version and present
delivery contract, **not a proof that every possible integration is
impossible**. Refusal remains unchanged. A deterministic upstream integration
policy needs a new app baseline and certification; a completion hook alone
does not recover files loaded before it. The
[local-only upstream draft](upstream/bundlebun-integration-order.md) records
both options and the census-free reproduction. Nothing was posted upstream,
no foreign repository was changed, and no measured cohort was run.

## Executed regression matrix

The Freezolite matrix in `gem/test/loader_test.rb` uses a tiny app with frozen
literals, an excluded nested require, and a `frozen_string_literal: false`
file. Every active run asserts that the lowered file was served exactly once
and the fast path ran; two active runs and an off run check cold/warm cache
safety and baseline literal behavior.

- MRI 4.0.7: Freezolite 0.7.0; require-hooks 0.4.0 and 0.5.1; no Bootsnap
  (both orders), and Bootsnap 1.18.6, 1.24.6, 1.26.0 (all six permutations).
- MRI 4.1.0-preview1: Freezolite 0.7.0, require-hooks 0.4.0 and 0.5.1,
  Bootsnap 1.26.0; both orders without Bootsnap and all six permutations with it.
- Both Ruby targets: explicit load-state/census matrix, Bootsnap absent or
  1.26.0, require-hooks absent/0.4.0/0.5.1, every Lowrail placement (19 orders
  per Ruby). SHA2 is loaded symmetrically by the fixture, like the Rails
  corpus: this isolates loader composition, not bare-app stdlib dependencies.
  Lazy digest loading itself can add stdlib constants in a bare app.
- Selected Bootsnap frozen-literal compiler with Lowrail before/after it;
  removing the policy refuses the old artifact.
- Changed options after a successful load; options affecting only strings
  introduced by lowering; changed runtime source transforms; build-time
  rejection of transformed source; corrupt/missing/old artifacts; actual
  Coverage counters; no default-gem activation during setup.
- Cached require-hooks hijacks with their own temporary compiler options:
  cold, warm and off runs preserve the original result for every installed
  require-hooks/Bootsnap pair above, including when original ISeq bytes alone
  cannot detect the recipe mismatch.
- Explicit compiler serialization, transformed input with a separate display
  filename, existing translators/compiler/warning overrides in both orders,
  and runtime/build/saved Bundlebun refusal. Native delivery introduces zero
  compiler calls, emits source warnings once, and its standalone build
  certificate never evaluates the file. The rejected canonical-runtime
  recompile introduced one compiler call and doubled source warnings. The
  inner-compiler regression fails without its recipe guard: original `1`
  becomes `false` from an incorrectly compiled introduced string.

Loader suite: **13 tests, 2,047 assertions** on 4.0.7; **13 tests, 1,460
assertions** on 4.1-preview; no failures/errors/skips.

The load-state regression fails against pre-change main
([cb83265](https://github.com/thomasklemm/lowrail/commit/cb832658d52e0a9f440d51ccac7dd985ceb09f2a))
because build capture adds its own `load_iseq` method. Earlier loader-policy
and cached-hijack regressions remain in the suite. Reproduce with installed
app dependencies:

```sh
gem install freezolite require-hooks bootsnap --no-document
mise exec -- ruby -Igem/lib gem/test/loader_test.rb
mise exec ruby@4.1.0-preview1 -- ruby -Igem/lib gem/test/loader_test.rb
mise exec -- ruby -Igem/lib -Igem/test -e 'Dir["gem/test/*_test.rb"].sort.each { require_relative _1 }'
```

Per-app verification results are recorded in [STATUS](STATUS.md); this
survey does not claim support for unexercised files or a performance gain.

## Deploy paths

Build and runtime directories need not be identical. Format-2 manifests and
facts store typed app-owned paths/template keys relative to the app root.
Setup resolves them against an initialized `Rails.root`, or the actual boot
directory/explicit `LOWRAIL_ROOT` before Rails exists. It never consults the
recorded `build_root` for lookups. Opaque config/code/reflection values are not
rewritten: a retained build-root dependency becomes a `delivery/relocation`
ledger warning and a refusal if the artifact moves. Endpoint compiled-method
certificates are explicitly path-bound. External gem installations retain
their own absolute paths and certificates; this is not gem-path rebasing.

**File ISeqs still embed filenames. Build them for the deploy directory:**

```sh
lowrail build /ci/build/app --target-root /app --env production
# Copy the app, including .lowrail/src and .lowrail/iseq, to /app.
# Boot there, or set LOWRAIL_ROOT=/app before lowrail/setup runs.
```

The target directory must be absolute but need not exist at build time.
Omitting the option targets the current build root. A file artifact delivered
at any other root refuses before installation, with `Lowrail.refusal_reason`
and a `LOWRAIL_DEBUG` boot warning naming the required rebuild command.
Template/runtime-only artifacts need no file-binary retargeting when all
their certificates are portable. Missing/changed original or lowered sources,
changed binary bytes, unknown recipes, or changed live-loader originals also
record refusals and run original code. Rebuild format-1 artifacts; their
untyped absolute metadata cannot safely be interpreted as portable.

The build replays the observed original compiler recipe first at the build
path and then at the target path, and compiles the lowered source at the
target path with that same recipe. Original and lowered content digests
remain independent of the directory. For retargeted files the original
certificate is the full serialized `ISeq#to_a`, normalizing only the root
`<main>`/`<compiled>` label already distinguished by file/text compilation.
Nested frames, instructions, paths and literal values are not normalized.
If replay cannot reproduce the observed original (for example, a top-level
block retains `block in <main>` instead of `block in <compiled>`), build
refuses that file and records why; it does not weaken the comparison.

### Why not compile lowered source at runtime?

The source is present, but invoking a public text compiler is another
observable loader event. A fresh-process probe on **both 4.0.7 and the pinned
4.1 preview** prepends a compiler hook that records calls and rewrites the
literal `lowered` to `hooked`. Loading the prebuilt binary returns `lowered`
with zero hook calls; compiling that identical lowered text at boot returns
`hooked` with one call. Recipe options and source digests alone do not prove
that this newly invoked hook preserves the program. Temporarily removing
the hook or bypassing it would change the loader policy too. No TracePoint
event claim is needed for this counterexample.

Therefore the exact, authorized alternative is AOT `--target-root`, not a
transparent runtime recompile fallback. It adds **zero runtime compilations**
but still pays live-original validation. The boot-component prices and
copied-blog verification are reported in [ruby-4.1.md](ruby-4.1.md#relocation-follow-up).
This changes delivery, not pass eligibility: `tier: sealed-v1`, registry
`sealed_only`, explicit production opt-in and old/mixed-artifact refusals
remain exactly the separate sealed contract.
