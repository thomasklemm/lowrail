# Loader composition and compile options

Checked 2026-10-20 on MRI 4.0.7 and 3.4.11. Lowrail preserves the app's
compiler policy; it does **not** enable frozen string literals for the app.

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

Runtime delegates to the original loader first. It observes compiler calls
and Bootsnap deserialization, checks the per-file recipe fingerprint **and**
the original ISeq fingerprint and disk digest, then substitutes the lowered
binary. For require-hooks the substitution also happens at `ISeq#eval`,
inside its callbacks. Unknown recipes, changed source/transforms, missing or
broken binaries, and active Coverage retain original code. Digest is still
loaded lazily, but its nested requires preserve the active compile defaults.
Lowrail never substitutes before Bootsnap serializes: its cache contains
originals, safe for subsequent `LOWRAIL=0` processes or changed builds.

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

Lowrail may load before, between, or after Bootsnap and require-hooks. Its
outer hook always delegates; the eval hook handles require-hooks' private
empty-ISeq protocol. Other modules and callbacks are not removed/reordered.

Bootsnap after require-hooks can hide require-hooks **without Lowrail too**.
Tests build with the app's own loader order and compare against that exact
baseline, including mutable literals when Freezolite is hidden. Lowrail must
not silently repair that order and change application behavior. To enable
Freezolite's policy, applications should follow its documented order:
Bootsnap first, Freezolite after. Lowrail's placement is independent of that.

require-hooks detects Bootsnap by the top `load_iseq.source_location`.
Lowrail in front can cause selection of its plain ISeq mode instead of the
Bootsnap adapter. Its around callbacks and per-file compilation still work,
and `super` can still reach Bootsnap. Cache/transform behavior remains
conservative; Lowrail does not falsify method introspection to influence the
gem's detection.

## Executed regression matrix

`gem/test/loader_test.rb` uses a tiny app with frozen literals, an excluded
nested require, and a `frozen_string_literal: false` file. Every active run
asserts that the lowered file was served exactly once and the fast path ran;
two active runs and an off run check cold/warm cache safety and baseline
literal behavior.

- MRI 4.0.7: Freezolite 0.7.0; require-hooks 0.4.0 and 0.5.1; no Bootsnap
  (both orders), and Bootsnap 1.18.6, 1.24.6, 1.26.0 (all six permutations).
- MRI 3.4.11: Freezolite 0.7.0, require-hooks 0.5.1, Bootsnap 1.26.0;
  both orders without Bootsnap and all six permutations with it.
- Selected Bootsnap frozen-literal compiler with Lowrail before/after it;
  removing the policy refuses the old artifact.
- Changed options after a successful load; options affecting only strings
  introduced by lowering; changed runtime source transforms; build-time
  rejection of transformed source; corrupt/missing/old artifacts; actual
  Coverage counters; no default-gem activation during setup.

The two new loader-policy regression cases fail on pre-fix main (two
failures); the full gem suite passes with the fix. Reproduce with the repo's
mise Ruby and installed app dependencies:

```sh
gem install freezolite require-hooks bootsnap --no-document
ruby -Igem/lib gem/test/loader_test.rb
ruby -Igem/lib -Igem/test -e 'Dir["gem/test/*_test.rb"].sort.each { require_relative _1 }'
```

Per-app verification results are recorded in [STATUS](STATUS.md); this
survey does not claim support for unexercised files or a performance gain.
