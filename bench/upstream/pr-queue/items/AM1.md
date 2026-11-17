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
note: "2026-11-17 (Thomas: build and open; the invalid-UTF-8 attribute raise is a bug, not a contract, so the body doesn't mention it). Candidate AM of bench/upstream/form_helper_stack. Guard only for Symbol and plain String attributes with no type; String subclasses and other objects keep the existing path. Active Model suite 1,269 runs and Action View active_model_helper/form_helper 374 runs green. benchmark-ips four rounds with an A/A in form_helper_stack/am1_ips_aa.txt (A/A within 2% on best rounds, change +205% to +336%). Needs one detailed claude-code pass before ready (DECISIONS 2026-11-17); rails/rails is at 15/15 non-draft. 2026-11-17: fatkodima asked inline whether `return [] if @errors.empty?` is enough; replied (Thomas approved) that it changes errors[nil]/errors[1] (NoMethodError on main) and type procs to fail or run only once the model has errors, and offered to simplify: https://github.com/rails/rails/pull/59832#discussion_r4602066652"
passes:
  - {reviewer: claude-code, orb: "T-01a1e883-199e-75a1-a127-da2f4cc9a823", head: "8cef505ecc", date: 2026-11-17, verdict: nits, open: "No must-fix. Diff is the one guard line, no added comments, RuboCop clean, clean merge-tree on main 4f00fbc946 (unmoved, no drift in errors.rb); commit has author and committer Thomas Klemm, no trailers, lines within 72. Differential probe main vs branch (Ruby 4.0.7), 10,800 lines each: errors[], include?, key?, and messages_for/full_messages_for/where/added?/of_kind? with no type, nil, false, :blank, :invalid, a String message, a proc returning :blank and one returning nil, over 24 attributes (Symbol, String, frozen and -/+ literals, .b, UTF-16LE, empty, :base, comments.body as Symbol and String, String subclass, SafeBuffer, Integer, Float, nil, Object, to_sym ducks, plain Strings with a singleton to_sym) on 10 models (AM valid, invalid, error on another attribute only, cleared, deleted, base error, never validated; AR valid with nested comments, invalid nested comments.body, persisted reloaded): every value, class, frozen flag and raise identical; errors[] and messages_for return a fresh unfrozen Array on both (two calls not equal?, << and concat into it leave errors unchanged), full_messages_for stays frozen; proc types run once on both. Differences: invalid-UTF-8 String attribute returns [] instead of raising EncodingError (accepted by Thomas; messages_for with a type, where, full_messages_for, added? still raise, include? returns false on both); a plain String's singleton to_sym is no longer called on a model without errors (60 lines, values identical); and, not recorded before, overrides of Errors#where or #normalize_arguments (subclass or prepended module) are no longer reached through [] and messages_for while the error list is empty: a subclass whose where adds errors gets [] from errors[:title] instead of its messages (main 1 where and 1 normalize call, branch 0). GitHub code search: 38 ActiveModel::Errors.prepend and 157 'class Errors < ActiveModel::Errors' hits; the sampled openproject, canvas-lms, 3scale/porta, mushroom-observer, exclusive-error-message, active_interaction, activeresource and caprese override symbols_for, to_hash, to_xml, add, full_message, merge!, from_*, empty?, full_messages, but none where, messages_for or normalize_arguments. Body checked sentence by sentence: error_wrapping -> object_has_errors? -> error_message calls object.errors[@method_name] (a String) before field_error_proc; simple_form errors_on_attribute and the validations guide use errors[attr]; ObjectSpace.count_objects over 1,000 calls: errors[:title] 3 Arrays + 2 Hashes -> 1 Array (errors['title'] the same plus the caller's literal); am1_objs.rb text_field 28 -> 24. Body benchmark rerun, 4.0.7 YJIT, taskset -c 1, 3 rounds main/branch/main interleaved (appended to form_helper_stack/am1_ips_aa.txt): best errors[:title] 4.066M / 17.849M (4.35x, A/A 4.099M, 0.8%), errors['title'] 3.118M / 9.268M (2.96x, A/A 3.134M, 0.5%) against the body's 3.96x and 2.68x. Tests on branch and main alike: Active Model rake test 1,269 runs; Action View active_model_helper + form_helper 374 runs, form_with/form_options/form_collections/date_helper 627 runs; Active Record (sqlite3) validations, validations/*, autosave_association, nested_attributes 541 runs (branch); 0 failures. Optional: (1) record the where/normalize_arguments override boundary in form_helper_stack's AM boundaries; (2) the commit message says 'a Symbol or String attribute' and neither text says why only plain Strings (instance_of?) take the early return, which a maintainer may ask: String subclasses such as SafeBuffer can override to_sym; (3) the body's script gives YJIT numbers only with ruby --yjit, which only the version line shows."}
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
