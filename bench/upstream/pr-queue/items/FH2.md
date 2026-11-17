---
id: FH2
repo: rails/rails
kind: perf
area: Action View, form builder tags
reviewer: "Action View maintainers"
branch: thomasklemm/form-builder-tag-copies
head: "d6ff7e8c4c"
base: main
built_on: "4500a94c34"
depends_on: []
stacked_on:
alternative_of:
impact: "Form builder fields make 1-5 fewer objects each (sweep setup, Ruby 4.0.9: text_field 28 -> 26, text_area 28 -> 25, radio_button 31 -> 29, select 41 -> 40, label 100 -> 95; form_with with 5 fields 279 -> 270); Callgrind interp / YJIT (form_helper_stack/fh2_ir.*, main A/A <= 0.45%): text_field -1.2% / -0.8%, text_area -2.3% / -1.1%, label -0.9% / -2.5%, form_with -0.4% / -0.2% (the YJIT one inside cross-tree noise). Every form page on Rails main and Ruby master; a small share of a request"
rank: 30
risky: false
state: built
pr:
note: "2026-11-17: built on main 4500a94c34 (sweep PR 2: PH, AMT, V, SV, TR). CB dropped: with HashWithIndifferentAccess options its []= converts a caller's Array unchecked value in place (merge! dupped it). OS dropped: map! is C while Array#map runs as Ruby under YJIT, f.select +469 instructions with it. TR uses match? on the pattern (a constant) instead of the sweep's include?, which rendered invalid-UTF-8 names main raised for; left: Tags::Translator (nodoc) called directly with a Symbol object name works where main raised NoMethodError. AMT: wrong-arity messages say 2..4. Probe fh2_probe.rb 32,272 lines and sweep_fuzz 86,726 lines against main: only those (form_helper_stack/fh2_probe_diff.txt). TR stays here, not in LBL1: different methods; merge-tree clean with LBL1, FB1 a2a13fc793 and all three. Action View 2,967 + 251 + 177 runs green on the branch and on FH2 + LBL1 + FB1; RuboCop clean. ZJIT on master not measured. Needs one detailed claude-code pass; under the rails/rails urgent-only rule it stays queued."
passes: []
---

# Avoid throwaway copies in form builder tags

Each form builder field builds a `Tags` object, and some of its steps make an object that the usual call throws away. `Placeholderable#initialize` and `ActiveModelInstanceTag#content_tag` collect their arguments into an Array only to pass them to `super`. `value_before_type_cast` builds the `title_before_type_cast` method name before asking whether the value came from the user, which for a record loaded from the database it didn't. `sanitized_value` copies a radio button's or label's value three times, and `Tags::Translator` copies the object name even when there is no nested attributes index to rewrite.

This passes the arguments on with `(...)` and with `content_tag`'s own parameters, builds the method name only when it is used, edits the first copy in place, and copies the object name only when it changes. Ids, names, values and translations are the same as before, and the record sees the same calls in the same order.

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
  "select" => -> { form.select(:category, %w[news blog]) },
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

before: text_field: 28 objects
before: text_area: 28 objects
before: radio_button: 32 objects
before: select: 43 objects
before: label: 100 objects
after:  text_field: 26 objects
after:  text_area: 25 objects
after:  radio_button: 30 objects
after:  select: 42 objects
after:  label: 95 objects
```

Under Callgrind, a `text_field` call runs 1.2% fewer instructions in the interpreter and 0.8% fewer with YJIT, a `text_area` call 2.3% and 1.1% fewer, and a `label` call 0.9% and 2.5% fewer.
