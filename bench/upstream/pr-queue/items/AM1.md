---
id: AM1
repo: rails/rails
kind: perf
area: Active Model, Errors#messages_for
reviewer: "Active Model maintainers"
branch: thomasklemm/errors-messages-for-no-errors
head: "8cef505ecc"
base: main
built_on: "4f00fbc946"
depends_on: []
stacked_on:
alternative_of:
impact: "errors[attr] on a model without errors returns [] without normalizing and filtering: 5 -> 1 objects per call, about 4x i/s under YJIT; form builder text_field 28 -> 24 objects"
rank: 30
risky: false
state: draft
pr: 59832
note: "2026-11-17 (Thomas: build and open; the invalid-UTF-8 attribute raise is a bug, not a contract, so the body doesn't mention it). Candidate AM of bench/upstream/form_helper_stack. Guard only for Symbol and plain String attributes with no type; String subclasses and other objects keep the existing path. Active Model suite 1,269 runs and Action View active_model_helper/form_helper 374 runs green. benchmark-ips four rounds with an A/A in form_helper_stack/am1_ips_aa.txt (A/A within 2% on best rounds, change +205% to +336%). Needs one detailed claude-code pass before ready (DECISIONS 2026-11-17); rails/rails is at 15/15 non-draft."
passes: []
---

# Return no messages for an attribute when a model has no errors

Form builder fields call `errors[method]` to decide whether to wrap the field in `field_error_proc`, and views often ask `errors[attr]` the same way. On a model without errors, `messages_for` still normalized the attribute and type, filtered the empty error list and mapped the result: three Arrays and two Hashes for an empty result.

It now returns an empty Array right away when there are no errors and no type, for a Symbol or String attribute. Other attributes and types take the existing path.

```ruby
require "active_support/all"
require "active_model"
require "benchmark/ips"

class Post
  include ActiveModel::Model
  attr_accessor :title
  validates :title, presence: true
end

post = Post.new(title: "Hello")
post.valid?

Benchmark.ips do |x|
  x.report("errors[:title]") { post.errors[:title] }
  x.report("errors[\"title\"]") { post.errors["title"] }
end
```

```
ruby 4.0.7 (2026-09-15 revision 229531a6cf) +YJIT +PRISM [x86_64-linux]

before:      errors[:title]      4.776M (± 1.2%) i/s  (209.37 ns/i) -     24.214M in   5.069759s
before:     errors["title"]      3.639M (± 4.8%) i/s  (274.80 ns/i) -     18.541M in   5.095148s
after:       errors[:title]     18.933M (±10.0%) i/s   (52.82 ns/i) -     95.088M in   5.022489s
after:      errors["title"]      9.753M (± 9.1%) i/s  (102.53 ns/i) -     49.532M in   5.078464s
```

A form builder `text_field` on a valid model allocates 4 fewer objects (28 → 24).
