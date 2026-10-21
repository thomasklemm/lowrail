# Local draft: deterministic Bundlebun integration discovery

**Not submitted.** No upstream issue, PR, gem patch or Ruby patch accompanies
this draft. Lowrail continues to refuse delivery/activation for known or
locked Bundlebun. This describes the locked **0.5.0.1.3.14** release on
**Ruby 4.0.7**, not every Bundlebun version or Ruby implementation.

## Problem and authoritative source

Bundlebun's Ruby source at
[b18ac047](https://github.com/yaroslav/bundlebun/commit/b18ac047ca4f958e09de9003ef9daea1be2bf458)
sets up Zeitwerk autoloads, then synchronously calls `load_integrations` at
the end of `lib/bundlebun.rb`. `Integrations.bun!` in
[`lib/bundlebun/integrations.rb:22–28`](https://github.com/yaroslav/bundlebun/blob/b18ac047ca4f958e09de9003ef9daea1be2bf458/lib/bundlebun/integrations.rb#L22-L28)
does `constants.map { |const| const_get(const) }`, filters Modules and invokes
their `bun!` methods. The constant walk both loads the integrations and
determines their patch order. Ruby does not guarantee `Module#constants`
enumeration order. Changing identifier allocation before this walk changes
the actual file-load order, even without executing the compiled code.

There is no Bundlebun `load_iseq` override here. Lowrail's separate
require-hooks/Bootsnap detector problem is already resolved. In the probes
their complete hook chains (owners, source locations, parameters and order)
are identical, and require-hooks still selects Bootsnap.

## Census-free reproduction

Use the Redprints CFP corpus pin and dependency overlay in `script/corpus`
([compatibility setup](../compat.md)), then run from that app directory.
The verified lock digest was
`74d2f70ab268cb2de8158152d51fbbb56255fab1370e38e7199731d260275b82`.
The reproduction uses the app's ordinary identifier history; bare
`require "bundlebun"` alone did not reproduce this swap.

Save this as a temporary `unobserved.rb`, outside the app source:

```ruby
# No Lowrail, census, compiler wrapper, or TracePoint in this process.
RubyVM::InstructionSequence.compile(":lowrail_bundlebun_probe_intern_000") if ENV["EXTRA_IDENTIFIER"] == "1"
at_exit do
  File.write(ENV.fetch("LOAD_ORDER_RESULT"), $LOADED_FEATURES.grep(%r{/bundlebun/integrations/}).join("\n") + "\n")
end
```

Run each side twice, with Ruby 4.0.7 / the app's bundle on PATH:

```sh
for control in 1 2; do
  for extra in 0 1; do
    env -u RUBYOPT -u LOWRAIL_OUTCOMES -u LOWRAIL_STATS \
      -u LOWRAIL_VERIFY_LOADS LOWRAIL=0 RAILS_ENV=test MT_CPU=1 \
      PARALLEL_WORKERS=1 EXTRA_IDENTIFIER="$extra" \
      LOAD_ORDER_RESULT="/tmp/bundlebun-order-$extra-$control.txt" \
      bundle exec ruby -r/absolute/path/to/unobserved.rb \
        -S rspec --seed 41231
  done
done
```

Both no-compilation processes load **CSS / ExecJS / JS / Vite**; both with
the single compilation load **CSS / JS / ExecJS / Vite**. Each process passes
all 50 examples. There is no Lowrail preload, census, compiler override or
TracePoint, and the observer only reads `$LOADED_FEATURES` after the loads.
No result of `compile` is evaluated. This demonstrates actual file loading,
not a reporter interpreting a compiler event as a load.

A separate strict-census control also has the swap and eight stable event
differences: the two moved entries, on both sides, at first-test/after-suite.
All 50 outcomes and all 692 SQL queries remain identical. Instrumentation can
change which particular order appears by allocating identifiers, but that
does not make these load differences imaginary.

## Option A: deterministic discovery (preferred direction)

Establish an explicit integration ordering policy upstream. One small
candidate, **not applied or certified**, is:

```diff
- integration_modules = constants.map { |const| const_get(const) }
+ integration_modules = constants.sort.map { |const| const_get(const) }
```

This retains discovery of additional constants and the current filtering;
an explicit ordered registry is another option if extension registration is
made part of the API. Maintainers must choose inherited-constant/extension
semantics and the relative precedence of integration effects. A fixed list
must not silently remove third-party integrations the old walk accepted.

Sorting changes the previous incidental order. **Lowrail cannot apply it as
an invisible workaround**: an app would intentionally adopt a new dependency
version/policy, establish its new plain baseline, then certify delivery
against that baseline. Regression coverage should assert actual integration
file order and integration effects, with/without a compiled-but-unevaluated
symbol and with the host integration gems present/absent. A newer release is
not assumed fixed without those checks.

## Option B: post-integrations lifecycle hook (limited)

A documented callback after the natural synchronous walk could let other
libraries initialize without requiring Bundlebun early. It must not force
integration/host autoloads at registration, must specify late subscription,
and must define repeated `load_integrations` and failed-walk semantics.

**It does not solve Lowrail's current Redprints props target.** Direct
observation at entry and successful return shows `PropsResolver` is already
loaded before the walk starts. A probe that initializes Lowrail at that
natural return preserves integration order but delivers no files and counts
zero hits. Re-evaluating the file would repeat app code; there is no public
MRI API for replacing an already-installed method ISeq in place while
preserving its original load/evaluation history. This hook would only help
targets still unloaded at that point; it is not a promise of 14 recovered
props hits or a solution to every later unordered constant walk.

## Lowrail decision

Keep the `bundlebun_load_order` refusal. The present eligible target is
**14 `inertia/props` hits** with identical 50 outcomes / 692 queries and
unchanged detection/load behavior. The old 277-hit/seven-unit aggregate is
obsolete after the sealed-only quarantine. A census-instrumented early-setup
probe happens to pass with 14 hits, but direct controls change actual order:
it is **non-certifying**, not grounds to remove refusal. No claim is made
that every conceivable integration is impossible. No measured cohorts were
run. [Full bounded investigation](../loaders.md#bounded-follow-up-delivery-timing-cannot-certify-this-bundle).
