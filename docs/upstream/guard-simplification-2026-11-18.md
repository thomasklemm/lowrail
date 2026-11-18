# Guard simplification sweep (2026-11-18)

Thomas: "Guards vereinfachen wo wir können." Following AM1 (`return [] if @errors.empty?`, as fatkodima suggested) and
RK3 (`String === s`), every draft, ready, reviewed or built item in
[pr-queue/items](../../bench/upstream/pr-queue/items) except AM1, RK3 and ZRS1 was read on its fork head for type,
arity and nil checks, fast paths that test more than the repository's own code, and comments that justify them.
Rule recorded in [DECISIONS](../DECISIONS.md#submission-queue-2026-11-03).

Nothing upstream-visible changed: no PR branch was pushed and nothing was posted. Three simpler variants are on new
fork branches with the suffix `-simple`. Each is one commit like the original, with Thomas as author and committer, the
original author date, made with `/usr/bin/git commit-tree`, and no trailers (checked with `git cat-file commit`).
Probes: `.amp/in/orb-backup/guards/i18n_probe.rb` (19 call shapes) and `arel_probe.rb` (12 shapes), run against
main, the head and the simple branch on Ruby 4.0.7.

## Ranking

| Rank | Item | Simplification | Risk | Branch |
| --- | --- | --- | --- | --- |
| 1 | I18N764 | lib +16/−1 → +7/−1, tests 58 → 6 lines, two comments gone | to_ary-convertible non-Array defaults, outside the documented API | `thomasklemm/fallback-defaults-without-wrapper-simple` `a419bdecbd` |
| 2 | I18N765 | `instance_of?(Hash)` branch and its comment gone, lib +8/−1 → +3/−1, one 14-line test gone | Hash subclasses overriding `[]=`, which `I18n.t` never passes | `thomasklemm/fallback-options-without-merge-kwargs-simple` `21801f98f1` |
| 3 | PR59574 | keyword sentinel and "not both" raise gone, 2+/15− against the head | calls passing both forms, which neither 8.1's nor main's signature allows | `thomasklemm/arel-table-positional-name-simple` `cbe39c2a96` |
| 4 | TAP2748 | one of five clauses gone | none for Tapioca's own callers | not built |
| 5 | I18N766 | keep the guard; trim the four-line comment to one | none (comment only) | not built |
| 6 | SC1 | `frozen?` dup and write-back → the documented writer | Rails ≤ 8.1 code holding an earlier reference to the registry | not built; held anyway |

## I18N764 (ruby-i18n/i18n 764)

Current guard, `extract_non_symbol_default!` on head `6a57b94bc1`: `Array === default`, then
`Array.try_convert(default)` flattened as `[converted]`, else `!default.is_a?(Symbol)` and `options[:default] = [] if
default`. Two comments explain why each branch matches `[default].flatten` exactly. Seven tests cover `to_ary`
objects, Strings with `to_ary` or `method_missing`, an element's `to_ary` mutating the Array, an `is_a?` returning an
object with its own `!`, frozen options with nil/false, and an Array subclass with its own `flatten`.

Proposal, in i18n's own `is_a?(Array)` idiom (`lib/i18n/backend/fallbacks.rb:28`,
`lib/i18n/exceptions.rb:64`):

```ruby
default = options[:default]
unless default.is_a?(Array)
  return if default.is_a?(Symbol)
  options[:default] = []
  return default
end
defaults = [default].flatten
```

Differences (probe, head vs simple): a non-Array default with `to_ary` is returned as itself instead of being
flattened (this also differs from main). `I18n.t` documents defaults as a String, Symbol, or Array of them
(`lib/i18n.rb:182-193`), and the fallbacks doc adds Proc and Hash. Nothing in i18n or Rails passes a `to_ary`
object. Called directly, the private method with a nil or false default now sets `options[:default] = []`, but
`translate` only calls it `if options[:default]`. Array subclasses and elements whose `to_ary` mutates the Array
behave as on main, because Arrays still go through `[default].flatten`. Symbol, String, Proc, Hash, Integer, Array,
nested, empty and frozen Arrays are identical across main, head and simple.

Tests: `rake test` 1608 runs, 2676 assertions, 0 failures (head 1615, main 1607). The head's own tests on the
simple code fail in exactly the three `to_ary` tests and error in the private nil/false call. The commit message's
second paragraph now says it in one sentence: "A non-Array default that defines to_ary is no longer flattened."

## I18N765 (ruby-i18n/i18n 765)

Current guard on head `0ff39e7cbf`: `if options.instance_of?(Hash)` copies with `merge` and stores the two keys,
with a comment; the else branch keeps `options.merge(:fallback_in_progress => true, ...)`, and a test covers a Hash
subclass with its own `[]=`.

Proposal, in i18n's `hash.dup` idiom (`lib/i18n/utils.rb:12`, `lib/i18n/backend/chain.rb:118`):

```ruby
fallback_options = options.dup
fallback_options[:fallback_in_progress] = true
fallback_options[:fallback_original_locale] = locale
```

Differences (probe): a Hash subclass overriding `[]=` sees the two writes (the probe's subclass stored
`"de-DE"` instead of `:"de-DE"`). Plain, frozen, empty and default-proc Hashes and three `I18n.t` calls give the
same results, options and key order. `I18n.t(key, **options)` always hands the backend a fresh plain Hash
(`lib/i18n.rb:241`, `translate_key` at 424). Tests: 1608 runs, 2680 assertions, 0 failures (head 1609). The commit
message says it in one sentence: "A Hash subclass that overrides `[]=` now sees the two writes; I18n.t always passes
a plain Hash."

## PR59574 (rails/rails 59574)

Current guard on head `a66e20ae68`: both `positional_name` and `name:` default to `NOT_GIVEN`; with both given it
raises "Pass the table name either positionally or as name:, not both.", including `name: nil`, plus a 9-line test.

Proposal: keep the `NOT_GIVEN` sentinel for the positional argument, Rails' own idiom
(`activesupport/lib/active_support/hash_with_indifferent_access.rb:404-407`,
`activesupport/lib/active_support/core_ext/time/calculations.rb:17-29`), and default `name:` to `nil` again:

```ruby
def initialize(positional_name = NOT_GIVEN, name: nil, as: nil, klass: nil, type_caster: klass&.type_caster)
  unless NOT_GIVEN.equal?(positional_name)
    ActiveRecord.deprecator.warn(...)
    name = positional_name
  end
```

Differences (probe): only the three both-given shapes, `(:users, name: :posts)`, `(:users, name: nil)` and
`(nil, name: nil, klass:)`, which now use the positional name with the deprecation instead of raising. Rails 8.1's
signature is `initialize(name, as: nil, ...)` with no `name:` keyword (8.1.4 `activerecord/lib/arel/table.rb:14`),
and main's accepts only `name:`, so no caller written for either passes both. The nine other shapes, deprecated or
not, are identical. Arel tests: 813 runs, 1390 assertions, 0 failures (head 814/1400; the removed test is the
difference). RuboCop not run. The commit message's "Passing both raises" sentence now reads: "A call passing both uses
the positional name; neither the Rails 8.1 signature nor main's allows both."

## TAP2748 (Shopify/tapioca 2748)

Current guard in `Reflection.constantize`: `(namespace == Object || symbol.start_with?("::")) && symbol.match?(...)
&& defined?(::ActiveSupport) && ::ActiveSupport.autoload?(:Configurable) && gem_version >= 8.1`.

Proposal: drop the first clause. Tapioca's only namespaced caller, `register_cname` in
`lib/tapioca/runtime/trackers/constant_definition.rb:73-76`, passes a bare constant name, which the regexp never
matches, and returns early for autoloads. The other four clauses protect real callers: non-Rails gems, apps that
loaded Configurable, and Rails < 8.1, where Configurable is not deprecated. Differences: only a caller passing
`namespace:` with a relative `"ActiveSupport::Configurable…"` string, which Tapioca doesn't do. Not built: it saves
one clause, and the spec builds whole projects with `bundle install`.

## I18N766 (ruby-i18n/i18n 766)

Current: `FIBER_STORAGE || Fiber.respond_to?(:[])` three times, with a four-line comment and a test for storage that
appears after load. Leave the guard: i18n supports Ruby >= 3.1, and on 3.1 the fiber-storage gem defines `Fiber[]`
later, pulled in by fiber-local (reverse dependencies: fiber-local, console-adapter-rails), which console and async
load. Main checks on every call, so dropping the fallback would change behaviour for those apps. Proposal: one-line
comment, e.g. "Fiber[] can still be defined later, e.g. by the fiber-storage gem on Ruby 3.1." Not built.

## SC1 (pond/scimitar 172)

Current: `parsers.frozen? ? parsers.dup : parsers`, then write back `if parsers.frozen?`. The simpler form is the
earlier `e81365a6e0`: `ActionDispatch::Request.parameter_parsers = ActionDispatch::Request.parameter_parsers.merge(...)`,
the writer Rails documents in the comment above `parameter_parsers=` (8.1.4 `actionpack/lib/action_dispatch/http/parameters.rb:40-46`).
Difference: on Rails ≤ 8.1, whose writer doesn't freeze, code holding an earlier reference to the registry Hash no
longer sees Scimitar's parser, and its later writes don't reach `ActionDispatch::Request`. Sol and Astra both marked
that must-fix (P2) on `e81365a6e0`. The item is held on Thomas's decision (fix at the source), so this is his call
and nothing was built.

## Left alone

- **OP8** (rails 59662): `!type.respond_to?(:freezable_default?) || ...` is Rails' idiom for optional type
  methods (`activerecord/lib/active_record/model_schema.rb:733`, `attribute_methods/serialization.rb:242`). The
  attributes API accepts type objects that only respond to Value's methods, so they are real callers.
- **CF350** (once-campfire 350): `messages.respond_to?(:preload_associations)` mirrors Rails' CollectionRenderer
  (`actionview/lib/action_view/renderer/collection_renderer.rb:115`). Search results reach `message_runs` too.
- **WAL150** (with_advisory_lock 150): `respond_to?(:internal_exec_query, true)` is the check the repository
  already uses on master (`lib/with_advisory_lock/postgresql_advisory.rb:155`).
- **CELLS75**: `if defined?(ActionView::Helpers::NavigationHelper)` keeps Rails < 8.2 working.
- **DRV2** (sqlite3-ruby 770): `#ifndef TRUFFLERUBY` is Astra's TruffleRuby finding. `length > 1` keeps
  `RARRAY_ASET` inside the pre-sized length, which is correctness inside the contract.
- **MB1** (rails 59810): the `where_clause`/`having_clause`/`null_relation?` conditions keep merge's
  deduplication and `none`, which its test shows. That is correctness inside the contract.
- **IMP336** (importmap-rails 336): `nonce.nil?` keeps a `false` nonce rendered, and `request&.` serves mailers.
- **RB569, RB-PV** (ruby-bench): feature detection for Ruby < 4.1 and modular GCs, and nil checks for runs without
  warmup or per-run counts. These handle data the runner writes.
- **OP1** (rails 59661): `&.freeze` covers Request subclasses whose class ivar is nil, as tested.
- **I18N763, RACK2550, TZ1, FB1, K6, A1, INR436, FLK1b**: identity or empty fast paths, or the repository's own
  `Array ===`, `is_a?(BaseProp)` or `Process.respond_to?(:fork)`. These are already minimal.
- **ruby/ruby** (RUBY19487, RUBY19492, RUBY19659, RUBY19681, ZS1, ZSV1, ZWB1, TN1, TN2): VM and JIT
  invariants (`RB_TYPE_P` for T_CLASS/T_MODULE mirrors the VM, like ZRS1), or no added guard.

No added guards: BD562, CF320, CF345, CF346, CF347, CF352, CF374, CF417, CW2, DRV1, DS1, E2, E2b, FLK1, INR437,
INR442 (both merged during the sweep), K1, L3, L6, LAGO91, NOKO3759, PSH289, RB570, RB571, RBCG1, RBW1, RCP550,
RCP551, RCP552, RCR1670, RMP670, PR59617, TZ2, UG82, UG82H, UG82K, UG82P, UG82S.
