# Draft only: avoid re-extracting canonical Configuration options

Not submitted. Target: `inertiajs/inertia-rails`, `lib/inertia_rails/configuration.rb`.
Checked v3.21.2, v3.22.0, v3.23.0 and upstream master on 2026-10-20.
The constructor and `bind_controller` bodies are identical across those refs.
The earlier [class-level configuration optimization](https://github.com/inertiajs/inertia-rails/commit/2aacfed78174d852dc9014c756dc3f26fbfe0621)
already removed repeated inherited-config merging; this concerns binding.

## Proposed issue text

**Title: Avoid re-extracting the canonical option schema on each controller bind**

`Controller#inertia_configuration` binds a fresh configuration each time it is
read. In three unmodified public apps we count 5, 9 and 11 bindings per JSON
request (PingCRM, Redprints CFP, React Starter Kit). HTML counts are 5, 4 and
5. Each binding calls `Configuration.new(**@options, controller:)`, which
then extracts the same ordered `OPTION_NAMES` into another Hash.

Could `initialize` accept its already-owned keyword-rest Hash directly in
the common case where it has exactly the canonical ordered keys and ordinary
Hash policies? This would keep `.new` and `initialize` dispatch intact, unlike
an `allocate` shortcut. The latter risks bypassing application constructor
extensions and is not my proposed upstream API.

Possible shape (not a submitted or generally certified patch):

```diff
 def initialize(controller: nil, **attrs)
   @controller = controller
+  if attrs.instance_of?(Hash) && attrs.default.nil? && attrs.default_proc.nil? &&
+      !attrs.compare_by_identity? && OPTION_NAMES == attrs.keys
+    @options = attrs
+    return
+  end
   @options = attrs.extract!(*OPTION_NAMES)
```

The original extraction/error path remains for partial configs, reordered or
unknown keys and unusual Hash policies. A keyword-rest Hash is owned by this
call; it must **not** be replaced by the caller's `@options` directly.
Compare from the trusted Symbol schema: a custom key's asymmetric `==`
must not make an unknown option look canonical.
This removes repeated per-key extraction for ordinary canonical configs;
there is still a fresh bound object and a fresh options Hash for each bind.
It does not cache controller-bound objects, proc results or option values.

An isolated v3.23.0 probe matched ten original/changed constructor envelopes
(including key order, class, Hash policies and unknown-option errors), fresh
storage/controller checks and an `initialize` extension calling `super`.
The fallback must stay inline: forwarding its keyword Hash to a saved
constructor changed a Hash-subclass case in the first probe. This is a
correctness feasibility check, not a measurement of the proposed patch.

Lowrail's separate guarded allocation/copy experiment and its actual
measurements are in [the pass notes](../passes/inertia-config.md). They are
not measurements of this constructor proposal and must not be advertised
as an upstream request speedup. A maintainer-owned optimization can avoid
Lowrail entirely, without a manifest, guards or installation overhead.

## Proposed PR description / tests

**Title: Fast-path canonical keyword options in Configuration#initialize**

Keep the existing `bind_controller` and public constructor signatures. Reuse
the constructor's fresh keyword-rest Hash only when extraction would produce
the same entries in the same order, class and Hash policy. Otherwise retain
the original constructor body, including the unknown-option exception.

Tests should cover:

- Two bindings with different controllers are fresh, mutable objects with
  distinct option Hashes. Changing one bound option must not affect another
  binding or the source configuration.
- Option values retain their identities, including mutable Strings/Arrays;
  later changes to global/per-controller configuration remain visible.
- A callable version is not evaluated during binding, and subsequently
  evaluates in each bound controller's context. Controller `inertia_config`
  overrides and inherited config continue to work.
- Partial/reordered inputs, explicit nil, unknown keys, Hash subclasses,
  non-nil defaults, default procs and compare-by-identity inputs agree with
  the original constructor, including error class/message and ordered keys.
  Include a custom key claiming equality to a canonical Symbol, which must
  still follow the unknown-option error path.
- Constructor extensions using `super` are still called. Bound options stay
  mutable even when the source configuration was frozen.

Open maintainer decision: whether global core-Hash/extraction monkey patches
are supported extension points. The shortcut removes `extract!` dispatch and
adds a key/shape probe; Lowrail guards those methods, whereas an upstream
change needs its own supported API policy. Benchmark both Ruby 3.4 and 4.0,
including allocation counts, before adopting the suggested implementation.
