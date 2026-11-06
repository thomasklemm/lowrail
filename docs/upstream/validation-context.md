# The `validation_context=` writer (rails/rails#59660, OP3)

Research for seanpdoyle's request on [#59660](https://github.com/rails/rails/pull/59660#issuecomment-6690830524)
to rework the restore into a documented public method. Done 2026-11-06 on Rails main
[`8e8a9bb38b`](https://github.com/rails/rails/commit/8e8a9bb38bf1a64d93aae2261f37623f46933500), Ruby 4.0.7.

**Decision (recommended, Thomas decides): close #59660; build no new public API.** Neither caller the PR names
needs to set the context. Both work on Rails main once they delete their writer calls. A bare public writer would
change Active Record behaviour beyond validations. The open proposal for a public writer is
[#55911](https://github.com/rails/rails/pull/55911), not ours. Nothing was posted, no fork branch was built, #59660 is
unchanged.

## What the callers actually need

### ancestry 5.1.0

[`sane_ancestor_ids?`](https://github.com/stefankroes/ancestry/blob/c03bc1a9b0339236f4e817ebd9730cc62d46c453/lib/ancestry/instance_methods.rb#L145-L159)
saves the context, sets it to nil, clears the errors, calls `validate_each` on the ancestry column's validators and
`ancestry_exclude_self`, then restores the context. Callers: the `after_update`
[`update_descendants_with_new_ancestry`](https://github.com/stefankroes/ancestry/blob/c03bc1a9b0339236f4e817ebd9730cc62d46c453/lib/ancestry/instance_methods.rb#L37-L49),
`check_ancestry_integrity!`, `restore_ancestry_integrity!` and the SQL update strategy (`class_methods.rb`). Still the same on
master [`e8c09d2`](https://github.com/stefankroes/ancestry/blob/e8c09d27929a292452901c8b5f34b1b0a1b882b4/lib/ancestry/instance_methods_builder.rb#L102-L116).

History: [`a1e3e6b`](https://github.com/stefankroes/ancestry/commit/a1e3e6b89a3e2fca00acd53cf528573c668f4056) (2020)
was `valid? || errors[ancestry_column].blank?`. [`ef78cbe`](https://github.com/stefankroes/ancestry/commit/ef78cbed5c22aa9f7a0d16178227758c64d4c38e)
(2021, kbrock, "only run validation on ancestry column") replaced it with the direct validator calls and wrote the
nil-context preamble new, modelled on Active Model's `valid?`.

kbrock's reasoning ([#770](https://github.com/stefankroes/ancestry/pull/770#issuecomment-5752596602)): "we are using
this to detect if we introduced an error or if there was an error from the model (some people save records to the
database with errors in them …) So this concept is necessary in general". The concept is right: run only ancestry's
validators so old invalid data in other columns doesn't count. But `errors.clear` plus direct `validate_each` calls
already do that. The context plays no part: direct `validate_each` never consults `on:`/`if:`, and the context is
already nil on every ancestry path (Active Model's `valid?` restores it in `ensure` before the save callbacks run;
the integrity checks load fresh records). He said as much on
[#766](https://github.com/stefankroes/ancestry/issues/766#issuecomment-5234621632): "probably not necessary anymore … I'll
work through dropping it and see if we can avoid the context all together." [#769](https://github.com/stefankroes/ancestry/pull/769)
and [#770](https://github.com/stefankroes/ancestry/pull/770) (both open) delete the lines; that is correct.

Probe [ancestry_probe.rb](../../bench/upstream/app_suites/validation_context/ancestry_probe.rb) (original vs. the
lines deleted; a spy validator on the ancestry column records the context it sees):

| Scenario | 8.1 original | 8.1 lines deleted | main original | main lines deleted |
|---|---|---|---|---|
| `update!(parent:)` with descendants | moved, entry context nil | same | NoMethodError | moved, nil |
| `save!(context: :import)` reparent | saved, nil | same | NoMethodError | saved, nil |
| reparent record with an invalid other column | saved, nil | same | NoMethodError | saved, nil |
| `check_ancestry_integrity!` (good / bad ancestry) | nil / raises integrity error | same | NoMethodError | same as 8.1 |
| `restore_ancestry_integrity!` | restored, nil | same | NoMethodError | restored, nil |
| user calls it inside their own `valid?(:strict)` | spy sees nil, sane | spy sees `:strict`, insane | NoMethodError | spy sees `:strict` |

Only the last row differs, and only for a custom ancestry-column validator that reads `record.validation_context`
while the user calls `sane_ancestor_ids?` from inside a validation run (which also wipes their errors, so it is not a
real use). The review subagent's [anc_autosave.rb](../../bench/upstream/app_suites/validation_context/anc_autosave.rb)
also got nil at entry for autosaved `has_many`/`belongs_to` reparents in a custom context, nested attributes,
`cache_depth`, `counter_cache`, `touch` and the adopt orphan strategy (not run: `update_strategy: :sql`, Postgres only, same
hook). ancestry's suite at v5.1.0 on Rails 8.1 with the lines deleted: 133 runs, 0 failures (same as unchanged).

### OpenProject

[`ModelContract#contract_valid?`](https://github.com/opf/openproject/blob/9ae6b5cc50ba3b675661f751d2ca9f361cb1f0b3/app/contracts/model_contract.rb#L85-L109)
is "mostly copied from `ActiveModel::Validations#valid?`" without `errors.clear`: a contract shares the model's errors
(`BaseContract#errors` returns `model.errors`), so `model.valid?(context)` runs first and the contract adds to it. The
contract sets its own context around `run_validations!`. Three contracts default that context:
`Projects::BaseContract#valid?(context = :saving_custom_fields)` (L57), `WorkPackages::BaseContract` (L253, same),
`WorkPackages::UpdateParentContract#valid?(context = :update)` (L34). But no contract declares `on:`/`except_on:` or reads
`validation_context`; the readers are in models and validators, which get the context through `model.valid?(context)`.

So deleting the three lines changes nothing at this commit and works on main; its real dependency is the private
`run_validations!`, which main still has. It should also drop the then unused `context` parameter, so a future
contract-level `on:` rule is not silently ignored. Probes:
[openproject_probe.rb](../../bench/upstream/app_suites/validation_context/openproject_probe.rb) and the review's
[op_check.rb](../../bench/upstream/app_suites/validation_context/op_check.rb) (contract with the `:saving_custom_fields`
default plus one `on:` rule):

| Mode | 8.1 | main |
|---|---|---|
| original | false; model error, "contract", "on-context contract rule"; contract sees `:saving_custom_fields` | NoMethodError |
| lines deleted | false; model error, "contract"; contract sees nil | same as 8.1 |
| public API (`prior = errors.dup`, Active Model `valid?(context)`, `errors.merge!(prior)`) | false; all three errors, reordered | same |

The public-API variant works but is clumsy: OpenProject overrides `valid?`, so it needs
`ActiveModel::Validations.instance_method(:valid?).bind_call(self, context)`, and `merge!` re-wraps the errors.

## Other users (broad search, 2026-11-06)

Sources: GitHub REST code search (4,638 files in 939 repos, every hit re-checked at its SHA), Sourcegraph, and the
latest release of 7,333 gems from rubygems.org (reverse dependencies of activemodel/activerecord ≥ 20k downloads, all
other activemodel dependents, rails/railties dependents ≥ 50k). grep.app was blocked (HTTP 429). Forks, vendored copies
and Rails itself filtered out. Patterns: `self.validation_context =`, `send(:validation_context=`, other receivers,
`instance_variable_set/get(:@validation_context`, `context_for_validation`, `def validation_context`.

Released gems that write the context or depend on the internals (downloads from rubygems.org, 2026-11-06):

| Gem | Downloads | Latest affected? | Code | Use | On main |
|---|---|---|---|---|---|
| activerecord-import | 172,154,910 | no: 3.0.x uses plain `valid?(ctx)` ([#919](https://github.com/zdennis/activerecord-import/pull/919)) | [2.2.0 L82](https://github.com/zdennis/activerecord-import/blob/6aec1e78060f15a8d39f31592225848e9e35f2b7/lib/activerecord-import/import.rb#L82), [2.3.0 L131-L136](https://github.com/zdennis/activerecord-import/blob/8ac907c9bbc548be8c9d12408ac3f703571314f1/lib/activerecord-import/import.rb#L131-L136) | sets `:create`/`:update` and runs the validate chain by hand to skip uniqueness | ≤ 2.2.0 breaks; 2.3.0 uses private `context_for_validation`; 3.x safe |
| ancestry | 40,597,862 | yes, 5.1.0 | [L146](https://github.com/stefankroes/ancestry/blob/c03bc1a9b0339236f4e817ebd9730cc62d46c453/lib/ancestry/instance_methods.rb#L146) | dead nil-context preamble (above) | breaks; fix is deleting the lines |
| simple_params | 182,745 | yes, 2.0.4 (2020) | [validations.rb#L8](https://github.com/brycesenz/simple_params/blob/c1fec0bb5e877b662743eb9a439e3e5a41524c11/lib/simple_params/concerns/validations.rb#L8) | copy of old `valid?` for nested params | breaks |
| foreman_puppet | 119,133 | yes, 11.3.0 | [L7](https://github.com/theforeman/foreman_puppet/blob/47a38d34a7ea96017310cded2ad8e390f80858d5/app/models/foreman_puppet/puppetclass_lookup_key.rb#L7) | reads `@validation_context` | silently wrong since 8.0; main adds nothing |
| multi_model_wizard, mondido, schema_dot_org, einvoice, docker-swarm | 98k–5k | — | e.g. [multi_model_wizard](https://github.com/ProctorU/multi_model_wizard/blob/c3160c13de82f19944530b12385ea8552d03ad71/lib/form_object/base.rb#L87) | ivar names in serialization exclusion lists | unchanged by main |
| light_form | 18,869 | yes, 0.0.7 (2015) | [L95](https://github.com/pniemczyk/light_form/blob/d8dddedc8f3056c5ea3f8c8f486ee06b309120d5/lib/light_form/property_methods.rb#L95) | validate in a context without clearing errors | breaks |
| upgrow (Shopify) | 14,069 | yes, 0.0.5 (2021, repo gone) | gem `lib/upgrow/input.rb:45` | `undef_method :validation_context=` | NameError at require |
| object_json_mapper | 13,438 | yes, 0.1.4 (2017) | [errors.rb#L29](https://github.com/InspireNL/object_json_mapper/blob/815b4a02d34a42a22d40bd065c19f5b46389320a/lib/object_json_mapper/errors.rb#L29) | `valid?` without clearing remote API errors | breaks |
| activevalidation | 6,152 | yes, 1.0.0 (2019) | [L14](https://github.com/kvokka/activevalidation/blob/3c2ef1948e964ccda4f74f89f8393999f5b5fbc9/lib/active_validation/ext/add_active_validation_context_check.rb#L14) | second validation pass in another context, keeps errors | breaks |
| action_blocks | 3,260 | yes, 0.1.0 (2018) | [L209](https://github.com/CTEH/action_blocks/blob/b7b904a2bc44c934ed93b14352ddd90119f13250/lib/action_blocks/builders/base_builder.rb#L209) | cached `valid?` copy | breaks |

Only the public reader (safe): shoulda-callback-matchers (10.8M), store_model (6.8M), html5_validators, sequent,
activeinteractor. Same name only: sequel, couch_potato, active_record_compose, GitLab's services, and others.

Apps: [OpenProject](https://github.com/opf/openproject/blob/a39e1dc70f5d16476c1d19c8bdfe51768e91de37/app/contracts/model_contract.rb#L100)
(17k stars; also specs at `spec/models/project_spec.rb` L659/L670 call `send(:validation_context=)`, and a safe reader override in
`app/models/projects/identifier.rb#L147`) is the only notable app that writes it; canvas-lms, conjur, DFE apply and others
only list the ivar names in `as_json` exclusions; Cloud Foundry's stored YAML jobs embed `ActiveModel::ValidationContext`.
Long tail: `self.validation_context =` in 34 repos (16 of them OpenProject copies, 6 Rails-source copies),
`send(:validation_context=` in 13 (9 OpenProject copies).

Reach, honestly: among widely used code only ancestry (5.1.0) and OpenProject still call the removed writer, and both
can delete the call. activerecord-import's current release is clean. The rest are small, mostly unmaintained gems.
The recurring need behind them is not a writer but "validate (in a context) without `errors.clear`" (OpenProject,
light_form, object_json_mapper, activevalidation), which [rafaelfranca declined in 2015](https://github.com/rails/rails/issues/20623#issuecomment-113270488)
("`valid?` always cleaned the errors before running the validations").

## Rails history

* 2010, [`8248506`](https://github.com/rails/rails/commit/82485068f8b64a49cbb6529d17dd5de27c28e951): `attr_accessor :validation_context`, `valid?(context)` saves and restores it.
* Rails 3.0–4.2: reader and writer both public (undocumented). 5.0, [`4642d68`](https://github.com/rails/rails/commit/4642d68d80)
  (tenderlove, "Eliminate instance level writers for class accessors"): `private :validation_context=`. So Rails already
  had a public writer once and took it back; the reader stayed public.
* 7.1, [#46397](https://github.com/rails/rails/pull/46397) ([`8be20b0`](https://github.com/rails/rails/commit/8be20b0debb9f12ad9f3aa8d07a0bd7eaeb68af2)), closing [#46391](https://github.com/rails/rails/issues/46391):
  the reader documented "to make it clear that the API is public", for `if: -> { validation_context != :custom }`.
  [#53866](https://github.com/rails/rails/pull/53866) later dropped that example once `except_on` existed.
* 8.0, [#47969](https://github.com/rails/rails/pull/47969) ([`afecc8f`](https://github.com/rails/rails/commit/afecc8fd6c3bf972acd277d95e7a3b7d446a5417), "Permit frozen models to be validated"):
  the ivar became the private `context_for_validation` returning a `:nodoc:` `ValidationContext`; `valid?` sets it
  directly; a private writer remained. (In v8.0.0, not v7.2.)
* Main, [#58220](https://github.com/rails/rails/pull/58220) ([`0f9d127`](https://github.com/rails/rails/commit/0f9d1270834a6407a59637650bf910d8ae826169), merged by byroot, no discussion): writer removed as "unused since afecc8fd6c". Unreleased.
* Requests for a public writer: [#55911](https://github.com/rails/rails/pull/55911) (open since 2025-10; rafaelfranca: "Makes sense to me, but … needs more work").
  It makes the writer public, makes Active Model `valid?` and Active Record `valid?`/`save` honour a preset context, and
  suggests `Object#with` for scoping (after discussing a `with_validation_context` block). Earlier: [#30710](https://github.com/rails/rails/pull/30710)
  (`except`, declined then, later done as `except_on`), [#24135](https://github.com/rails/rails/pull/24135)/[#46238](https://github.com/rails/rails/pull/46238) (passing the context to associations).
  No issue or PR asked for "validate in a context without clearing errors" except [#20623](https://github.com/rails/rails/issues/20623) (declined).

## Existing public API

* `valid?(context)` / `validate(context)` / `invalid?` / `validate!`: always `errors.clear` first.
* `validates_with` (instance): runs only the validator classes you pass, in no context.
* `EachValidator#validate` / `validate_each`: public; what ancestry already uses, no context needed.
* `errors.dup` + `errors.merge!`: keeps earlier errors around a `valid?` call (OpenProject's own
  `validate_and_merge_errors` already does this between contracts).
* `with_options on: ...`: declaration-time only.
* `custom_validation_context?` (Active Record): public but `:nodoc:`, internal.
* `run_validations!`: private.

## Design options considered (for the record)

Conventions checked: `guides/source/api_documentation_guidelines.md` (Method Visibility: private methods and
`:nodoc:` are not user-facing API), Markdown RDoc with fenced examples as default on main (files opt out with
`# :markup: rdoc`), CHANGELOG entries as `*   Sentence.` + paragraph + `*Author*`, and the validations guide's
custom
contexts section (it would need a line for any new public way to set a context).

1. **Public `validation_context=` (#55911's shape), scoped with `Object#with`.** Smallest surface, and `Object#with`
   ([`1884323`](https://github.com/rails/rails/commit/1884323574), byroot) exists exactly for this begin/ensure
   pattern, so a separate block method would duplicate it. But alone it has no effect through public validation
   (`valid?` overwrites the context), and on Active Record it leaks into the save: the review's
   [writer_effect.rb](../../bench/upstream/app_suites/validation_context/writer_effect.rb), identical on 8.1.4.1 and main:
   a preset `:import` makes `violates_strict_loading?` skip (`association.rb:245`, `owner.validation_context.nil?`)
   and autosaves every loaded unchanged child (`autosave_association.rb:327`, `custom_validation_context?`).
2. **`with_validation_context(ctx) { ... }`.** Same semantics as 1 plus a new name that duplicates `Object#with`;
   precedents like `with_lock` or `I18n.with_locale` wrap behaviour that public calls inside the block observe, which
   is not the case here.
3. **Validate without clearing errors** (e.g. a `clear:` keyword on `valid?`). The one need several callers share, but
   it contradicts a maintainer's stated design and has one app and a few dormant gems behind it. Not ours to open
   without a clearer case.
4. **Close #59660** and let the callers delete the lines. Chosen.

## Drafts (nothing posted)

Closing comment on #59660, which also answers seanpdoyle:

> Thanks @seanpdoyle, that's fair. I looked at what the two callers actually need, and neither needs to set the
> context: ancestry calls its validators directly and the context is already nil on every path, and no OpenProject
> contract reads its own. Both work on main once they drop those lines, so there's no case here for a new public API.
> Closing.

Optional, only if Thomas wants it: one comment on stefankroes/ancestry#770 with the probe result (the context is nil
on every ancestry path; the suite passes with the lines deleted). The etiquette rule allows it because it is a verified
fact the thread is waiting on.

Queue item: [OP3](../../bench/upstream/pr-queue/items/OP3.md). Probe Gemfiles:
[Gemfile.rails81](../../bench/upstream/app_suites/validation_context/Gemfile.rails81) and
[Gemfile.main](../../bench/upstream/app_suites/validation_context/Gemfile.main) (points at a local Rails main checkout).
