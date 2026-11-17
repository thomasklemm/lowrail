---
id: LBL1
repo: rails/rails
kind: perf
area: Action View, form builder labels
reviewer: "Action View maintainers (Tags::Translator is unchanged since 2018)"
branch: thomasklemm/label-translation-key-once
head: "67073f74f7"
base: main
built_on: "4500a94c34"
depends_on: []
stacked_on:
alternative_of:
impact: "f.label without text on a form whose object name is the model's i18n_key (form_with(model: @post), the usual case) looks its key up once instead of twice and builds one I18n::MissingTranslation fewer when the app has no helpers.label translation: 100 -> 85 objects per label (sweep setup, Ruby 4.0.9); Callgrind interp / YJIT -16.1% / -16.4% per f.label (form_helper_stack/fh2_ir.*, main A/A <= 0.45%). Every label without text on Rails main and Ruby master; a form page has one per field"
rank: 30
risky: false
state: built
pr:
note: "2026-11-17: built on main 4500a94c34 (Thomas, 2026-11-16: queue it). Candidate L of bench/upstream/form_helper_stack, guarded on a Symbol i18n_key: a String i18n_key (perpetuity returns one) keeps the default instead of raising NoMethodError for name. lbl1_probe.rb, 23,904 lines per backend: Fallbacks identical; Simple differs only where a translation Proc returns nil and I18n renders 'Translation missing' into the label, whose message no longer lists the key twice (form_helper_stack/lbl1_probe_diff.txt; Thomas decides). Lookups drop only where the object name is the i18n_key; the Proc runs as often as on main. TR (sweep) went to FH2: other method of translator.rb; merge-tree clean with FH2, FB1 a2a13fc793 and all three. Action View 2,967 + 251 + 177 runs green on the branch and on FH2 + LBL1 + FB1; RuboCop clean. ZJIT on master not measured. Needs one detailed claude-code pass; rails/rails urgent-only rule applies."
passes: []
---

# Look up a label's translation key once

`f.label(:title)` without text asks I18n for `helpers.label.post.title` and passes `post.title` (the model's `i18n_key` and the method) as the first default, for forms whose object name isn't the model's, such as nested attributes or `as: :article`. In the usual form, `form_with(model: @post)`, the object name is the `i18n_key`, so the default is the same key under the same scope. Most apps have no `helpers.label` translations, so each such label looks the key up twice and builds a second `I18n::MissingTranslation` before it falls back to `human_attribute_name`.

This leaves out the default when it would repeat the key. Translations, fallbacks and the humanized fallback are the same as before.

```ruby
require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title }
end

class Post < ActiveRecord::Base; end

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello"), view, {})

form.label(:title)
before = GC.stat(:total_allocated_objects)
1000.times { form.label(:title) }
puts "label: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]

before: label: 100 objects
after:  label: 85 objects
```

Under Callgrind, the call runs 16.1% fewer instructions in the interpreter and 16.4% fewer with YJIT.
