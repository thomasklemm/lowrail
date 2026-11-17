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
passes:
  - {reviewer: claude-code, orb: "T-01a1ebad-a1af-7339-a56f-de5d9eb37309", head: "67073f74f7", date: 2026-11-17, verdict: changes, open: "MUST-FIX (commit message, new head; body clause too): an undisclosed boundary. i18n-active_record 1.4.1's documented Missing extension (Chain(ActiveRecord, Simple)) stores a stub when a translate call ends in MissingTranslation; on main the repeated Symbol default is that call, so main stores helpers.label.post.title and helpers.placeholder.post.title for form_with(model: post), the head stores neither for any form whose object name is the i18n_key (nested and scope:/as: forms still store). Rendering is unaffected. Fix: replace the commit message's last three sentences with 'Labels and placeholders render as before, except for the 'Translation missing' text shown when a translation Proc returns nil, which no longer lists the key twice. A backend that acts on missing translations no longer sees the second miss: i18n-active_record's Missing extension stops storing a stub for helpers.label.post.title.' and add to the body after its second paragraph's last sentence: 'Only a backend that stores missing keys, such as i18n-active_record's `Missing`, no longer stores `helpers.label.post.title`, which reached it only through the repeated default.' Thomas decides whether the boundary is acceptable at all (GitHub code search: one app initializer uses Missing besides vendored copies; lit 1.1.6 likely differs too, by source, not run). Confirmed: the builder's Proc-returning-nil boundary, also for placeholders and for the MissingTranslationData message under Rails' raising exception_handler; nothing else renders differently. Evidence: lbl1_backends_probe.rb, about 60,000 cases per backend, main vs head: Fallbacks and KeyValue identical, Simple/Chain/Memoize/Missing chain 284 Proc-nil lines, Cache 10 more Proc call counts (shared cache key); lookups never rise, drop only where the object name is the Symbol i18n_key; Proc and to_s calls identical; on_fallback once fewer through a Symbol link with value:. Commit message and body checked sentence by sentence (default [:post.title, ''] logged, 2 -> 1 MissingTranslation, 4 -> 3 lookups; 7 of 9 sampled apps have no helpers.label in English). Body script 100 -> 85 on 4.0.9. Callgrind with A/A (lbl1_form_ir.txt): f.label -16.07% interp (A/A 0.05%), -16.23% YJIT (A/A 0.16%; body says 16.4%, inside cross-tree noise); form_with with 5 fields and 5 f.label -8.6% interp, -9.1% YJIT; with label text 0. A whole request not measured. Action View 2,967 + 251 + 177 runs green on the head and on FH2 + LBL1 + FB1; RuboCop clean; merge-tree clean with main 4500a94c34 (current), FH2 d6ff7e8c4c, FB1 a2a13fc793 and all three; no added comments; author and committer Thomas, no trailers. Optional: (1) if key == object_name.to_sym is a shorter guard with identical probe output and objects; (2) the body could say about 16% for both. Value: rails/rails stopped merging per-call wins after 11-06; this one moves a label-heavy form by about 9%, labels with text not at all."}
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
