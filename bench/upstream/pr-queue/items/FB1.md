---
id: FB1
repo: rails/rails
kind: perf
area: Action View, form builder ids and names
reviewer: "Action View maintainers"
branch: thomasklemm/form-builder-field-names
head: "870085d5a9"
base: main
built_on: "a5203b3d4d"
depends_on: []
stacked_on:
alternative_of:
impact: "field_id, field_name and Tags::Base#sanitized_method_name copy only when there is something to replace: 6 fewer objects per builder field (f.text_field 28 -> 22, f.check_box 32 -> 26); Callgrind interp / YJIT: text_field -2.8% / -5.7%, check_box -2.3% / -4.8%, select -2.6% / -2.9%"
rank: 30
risky: false
state: draft
pr: 59824
note: "2026-11-16 (Thomas: open as a separate draft overnight). Candidates B, C and D of bench/upstream/form_helper_stack. Action View suite green (2,967 + 251 + 177 runs). benchmark-ips YJIT in the body, best rounds, A/A within 1-4%. Only contrived inputs differ (String subclasses overriding gsub/delete_suffix, to_s not returning a String). sanitized_method_name may now return @method_name itself; no in-tree caller mutates it. Needs claude-code and opus/astra passes before ready; rails/rails is at 15/15 non-draft."
passes:
  - {reviewer: skeptic, head: "870085d5a9", date: 2026-11-16, verdict: nits, open: "3,182 name pairs, 231,948 outputs and 390 regex inputs against main: identical apart from overridden String methods and non-String to_s; optional: a commit-message line on the no-op path, a comment that the match? class tracks the gsub class plus _"}
---

# Skip copying form field names that need no changes

A form builder field computes its id with `field_id` and its name with `field_name`, and `Tags::Base#sanitized_method_name` strips a trailing `?` from the method name. For the usual names, such as `post` and `title`, none of them changes anything, but each made a copy: `field_id` copied the object name twice and the method name once, `field_name` joined an empty Array into a new String, and `sanitized_method_name` copied the method name.

This makes each copy only when there is something to replace. A `_` counts as nothing to replace, because `field_id`'s `gsub` turns it into itself. Ids and names are the same as before.

```ruby
require "active_support/all"
require "active_model"
require "action_view"
require "benchmark/ips"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :published, :boolean
end

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello", published: true), view, {})

Benchmark.ips do |x|
  x.report("text_field") { form.text_field(:title) }
  x.report("checkbox") { form.checkbox(:published) }
end
```

```
ruby 4.0.7 (2026-09-15 revision 229531a6cf) +YJIT +PRISM [x86_64-linux]

before:           text_field    109.453k (± 2.3%) i/s    (9.14 μs/i) -    558.500k in   5.102639s
before:             checkbox     74.598k (± 8.0%) i/s   (13.41 μs/i) -    378.800k in   5.077869s
after:            text_field    121.593k (± 2.1%) i/s    (8.22 μs/i) -    608.884k in   5.007572s
after:              checkbox     82.564k (± 2.8%) i/s   (12.11 μs/i) -    418.808k in   5.072535s
```

Each field also allocates 6 fewer objects: `text_field` 28 → 22, `checkbox` 32 → 26.
