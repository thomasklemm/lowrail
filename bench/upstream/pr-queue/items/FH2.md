---
id: FH2
repo: rails/rails
kind: perf
area: Action View, form builder tags
reviewer: "Action View maintainers"
branch: thomasklemm/form-builder-tag-copies
head: "7401f9dac7"
base: main
built_on: "088fc0cf61"
depends_on: []
stacked_on:
alternative_of:
impact: "Parked 2026-11-27: the exact remainder (PH + SV) saves 1-2 objects and 0.1-0.5% of instructions per field, 0.1-0.2% of a 5-field form (interpreter), within cross-tree noise"
rank: 30
risky: false
state: held
pr:
note: "2026-11-27 (later): parked again, not opened. Astra on 7401f9dac7 showed two exactness breaks with ordinary mutable Strings and public model callbacks (V builds the before_type_cast name after value_came_from_user? runs; TR keeps an unfrozen caller name instead of a copy), so V and TR must go. What is left, PH + SV (local tree fh2-reduced, not pushed), saves 1-2 objects per field (text_field 17 -> 16, text_area 18 -> 17, radio_button 21 -> 19, label 90 -> 88) and in the interpreter f.text_field -0.54%, f.text_area -0.53%, f.radio_button -0.31%, f.label -0.14%, 5-field form_with -0.09% to -0.16% (main/main2 A/A <= 0.07%, cross-tree noise about 0.3%; results/fh2_reduced_interp.txt). That is below the bar of a real measured benefit; after two exactness rounds DECISIONS says to drop. The fork branch keeps 7401f9dac7. 2026-11-27: revived after rails/rails merged per-call wins again on 2026-11-26 (K1, K6, #59824, #59983). Rebuilt on main 088fc0cf61 as 7401f9dac7: AMT dropped (claude-code must-fix 1), Placeholderable keeps its bare super (the nit), the commit message says String#gsub, and the body and table drop ActiveModelInstanceTag and select (must-fix 2). Pushed to the fork with a lease on d6ff7e8c4c. Equivalence, tests and Callgrind (interp, YJIT, ZJIT, three main runs) in bench/upstream/revive-2026-11-27. Honest size: 2 objects and 1-2% per field call, 0.4% of a 5-field form, about 0 under ZJIT at the form level; no ZJIT loss. 2026-11-18 (coordinator): parked as an idea, not to open. The claude-code pass on d6ff7e8c4c found an AMT crash with a TagHelper#content_tag prepend (must-fix: drop AMT) and rates the rest not worth it: form_with with 5 fields saves 0.24-0.39% of its own instructions, and the 2026-11-17 PR retrospective shows rails/rails stopped merging per-call wins after 11-06. If ever revived: drop AMT, keep PH bare super, rerun Callgrind with three main runs. 2026-11-17: built on main 4500a94c34 (sweep PR 2: PH, AMT, V, SV, TR). CB dropped: with HashWithIndifferentAccess options its []= converts a caller's Array unchecked value in place (merge! dupped it). OS dropped: map! is C while Array#map runs as Ruby under YJIT, f.select +469 instructions with it. TR uses match? on the pattern (a constant) instead of the sweep's include?, which rendered invalid-UTF-8 names main raised for; left: Tags::Translator (nodoc) called directly with a Symbol object name works where main raised NoMethodError. AMT: wrong-arity messages say 2..4. Probe fh2_probe.rb 32,272 lines and sweep_fuzz 86,726 lines against main: only those (form_helper_stack/fh2_probe_diff.txt). TR stays here, not in LBL1: different methods; merge-tree clean with LBL1, FB1 a2a13fc793 and all three. Action View 2,967 + 251 + 177 runs green on the branch and on FH2 + LBL1 + FB1; RuboCop clean. ZJIT on master not measured. Needs one detailed claude-code pass; under the rails/rails urgent-only rule it stays queued."
ownership: {date: 2026-11-27, checked: ["open PRs naming value_before_type_cast, sanitized_value, initialize that change actionview/lib/action_view/helpers/tags/base.rb, actionview/lib/action_view/helpers/tags/placeholderable.rb, actionview/lib/action_view/helpers/tags/translator.rb"], hits: []}
evidence: ['bench/upstream/revive-2026-11-27/README.md', 'bench/upstream/revive-2026-11-27/results/']
passes:
  - {reviewer: claude-code, orb: "T-01a1ebad-963b-72bb-8400-64d63a1e80ea", head: "d6ff7e8c4c", date: 2026-11-17, verdict: changes, open: "MUST-FIX 1 (code, new head): drop AMT and restore def content_tag(type, options, *). With named parameters the bare super passes all four, so an override of the public TagHelper#content_tag below ActiveModelInstanceTag (prepend on TagHelper) gets escape=true as its last argument; the common def content_tag(name, *args, &block) with args.extract_options! then calls super with five arguments and f.text_area, f.label and f.select raise ArgumentError (given 5, expected 1..4) where main renders (form_helper_stack/fh2_amt_override.rb). The DECISIONS acceptance covers private overrides only; content_tag is public. No exact allocation-free form: (type, ...) also allocates 1 object for 3 arguments (interpreter and YJIT) and accepts 1-argument calls. GitHub code search found no current gem or app with such an override (haml 4/5 pass *args through; inputs_with_class and ui18n use the full signature), but the failure is a crash. Cost of the fix (sweep setup): text_area 28 -> 26 instead of 25, label 100 -> 96 instead of 95, select no saving (41 / body script 43), form_with 279 -> 273 instead of 270; Action View 2,967 + 251 + 177 runs green without AMT. MUST-FIX 2 (text, with 1): the commit message's first bullet, the body's first two paragraphs and its table (drop the select row; text_area 26, label 96), impact and note; and the Callgrind sentence: fresh fh2_ir.sh runs (main, head, main; fh2_ir_review.txt) reproduce the interpreter cells (text_field -1.24%, text_area -2.37%, label -0.67% against the body's 0.9%, A/A <= 0.06%) but not YJIT: label -1.32% (body 2.5%), text_field -0.42% against a 0.35% A/A (body 0.8%), YJIT A/A up to 1.23% (radio_button). Without AMT: interpreter text_field -1.20%, text_area -1.71%, label -0.45%, form_with -0.24%; YJIT within its A/A except text_area -0.59% and label -0.95%. Rerun with at least three main runs and keep only cells outside the spread. NITS: PH can keep the bare super (def initialize(...) with super forwards and allocates the same as super(...), measured), a one-line diff. Commit message: 'The first gsub always returns a new String' holds for String#gsub; say String#gsub. CHECKED: own differential probe fh2_review_probe.rb, 202,330 lines main against head (17 object names incl. Symbol, String, SafeBuffer, frozen, a String subclass with its own +/gsub/match?, nested _attributes][ names, post[], admin/post, empty, non-ASCII, binary, invalid UTF-8, UTF-16LE, a to_s object, nil, Integer; 11 objects incl. persisted, from user, changed, invalid, namespaced subclass, Active Model, logging ducks with and without came_from_user?, a before_type_cast-only object, a plain object, nil; 5 method names; 13 option shapes incl. HashWithIndifferentAccess, a Hash subclass, frozen, index, index nil, namespace, id nil, placeholder true/Symbol/String, value; 23 builder calls incl. label plain/text/block/value, check_box, radio_button, select, collection radio/check boxes/select; labels and placeholders with and without translations; fields_for nested, child_index and index; form_with namespace and index; form_for; sanitized_value over 21 values; Translator directly; Placeholderable with keywords, blocks, subclasses, wrong arity; content_tag by arity, keywords and blocks; a TagHelper prepend). Differences: the AMT override and arity messages, TR's Symbol (raise -> works) and nil/Integer/to_s-object messages (gsub -> match?), and contrived String subclasses: an SV value whose to_s returns a subclass with its own gsub (one returning a frozen String now raises FrozenError, one returning self changes the value attribute's case), a V method name whose to_s returns a subclass with its own + (not called for values not from the user), a TR object name with its own match? (one more call). The record sees the same calls in the same order (ducks identical). Invalid UTF-8 and UTF-16LE object names raise the same in Translator. fh2_probe.rb reproduces fh2_probe_diff.txt exactly; sweep_fuzz.rb 86,726 lines byte-identical. Builder boundaries: both confirmed; view_component-form and phlex-form pass a builder's raw object_name (a Symbol for form_for :post), so they move from NoMethodError to working; HealthDataInsight converts Symbols; mdn and form_components pass .to_s. Objects: fh2_alloc.rb is the body's script verbatim and gives 28/28/32/43/100 -> 26/25/30/42/95, sweep_count.rb the impact's counts. merge-tree clean with main 4500a94c34 (current main, no drift), FB1 a2a13fc793, LBL1 67073f74f7 and all three; Action View on the head and on FH2 + LBL1 + FB1: 2,967 + 251 + 177 runs, 0 failures; RuboCop clean on the 4 files; no added comments; commit author and committer Thomas, no trailers. Shorter forms: none for V, SV, TR that keep the gain and stay exact. WORTH: no. form_with with 5 fields saves 0.24-0.39% of its own instructions, a small part of one request, and rails/rails stopped merging such per-call wins; under the urgent-only rule it stays queued and should be held as a parked idea rather than opened."}
  - {reviewer: astra, orb: "T-01a21cf0-89bb-715a-91c6-3bbbc60df307", head: "7401f9dac7495aef0e0588f0e1ff5f06f3203a22", date: 2026-11-27, verdict: changes, open: "MUST-FIX 1: value_before_type_cast now builds its method name after user code: with name = +\"title\", a public title_came_from_user? that does name.replace(\"body\") makes main render value=\"original title\" and the head value=\"other body\"; drop the V hunk. MUST-FIX 2: Translator aliases an unfrozen caller name where main took a snapshot: an ActiveModel::Model whose public to_model mutates the name renders \"Original label\" on main and \"Other label\" on the head; drop the TR hunk (Translator.new on matched 32/256-byte names is also 17-33% slower, a 1 MiB captured nested name +44.76%, A/A 2.60%; constructor only, not label or request time). Text: the README's YJIT form-level 0.4% used an nf cell; the body's form sentence must say interpreter only. Checked: fh2_review_probe 202,330 lines reproduces the stored diff, A/A empty; own 313-line probe (103 encodings, frozen String/SafeBuffer, content_tag prepend) differs only in the two mutation lines; Action View 2,982 + 252 + 177 green on both; objects 17->15, 18->16, 21->19, 90->86 reproduce; fresh interp Callgrind text_field -1.38%, text_area -1.76%, label -0.35%, five-field form -0.36% (A/A <= 0.10%); stored tables regenerate byte-identically. Commit metadata clean. Worth opening: not as submitted; re-evaluate PH + SV only after new measurements. Archive: bench/upstream/revive-2026-11-27/astra-fh2/FH2-astra-7401f9d-review.tar.xz (SHA256 5441352bdeec60b3)."}
---

# Avoid throwaway copies in form builder tags

Each form builder field builds a `Tags` object, and some of its steps make an object that the usual call throws away. `Placeholderable#initialize` collects its arguments into an Array only to pass them to `super`. `value_before_type_cast` builds the `title_before_type_cast` method name before asking whether the value came from the user, which for a record loaded from the database it didn't. `sanitized_value` copies a radio button's or label's value three times, and `Tags::Translator` copies the object name even when there is no nested attributes index to rewrite.

This takes the arguments as `(...)`, builds the method name only when it is used, edits the first copy in place, and copies the object name only when it changes. Ids, names, values and translations are the same as before, and the record sees the same calls in the same order.

```ruby
require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.string :category }
end

class Post < ActiveRecord::Base; end
Post.create!(title: "Hello", body: "Text", category: "news")

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.first, view, {})

{
  "text_field" => -> { form.text_field(:title) },
  "text_area" => -> { form.text_area(:body) },
  "radio_button" => -> { form.radio_button(:category, "news") },
  "label" => -> { form.label(:title) },
}.each do |name, field|
  field.call
  before = GC.stat(:total_allocated_objects)
  1000.times { field.call }
  puts "#{name}: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]

before: text_field: 17 objects
before: text_area: 18 objects
before: radio_button: 21 objects
before: label: 90 objects
after:  text_field: 15 objects
after:  text_area: 16 objects
after:  radio_button: 19 objects
after:  label: 86 objects
```

Under Callgrind, a `text_field` call runs 1.4% fewer instructions in the interpreter and 0.9% fewer with YJIT, a `text_area` call 2.0% fewer in the interpreter, and a `label` call 0.5% and 1.1% fewer. A `form_with` with five fields runs 0.4% fewer.
