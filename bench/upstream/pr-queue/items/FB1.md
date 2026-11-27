---
id: FB1
repo: rails/rails
kind: perf
area: Action View, form builder ids and names
reviewer: "Action View maintainers"
branch: thomasklemm/form-builder-field-names
head: "a2a13fc793"
base: main
built_on: "a5203b3d4d"
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/form_helper_stack/body/fb1/gated]
impact: "field_id, field_name and Tags::Base#sanitized_method_name copy only when there is something to replace: 6 fewer objects per builder field (f.text_field 28 -> 22, f.check_box 32 -> 26); Callgrind interp / YJIT, JIT-flat (form_helper_stack/body/fb1/gated): text_field -3.3% / -5.4% (persisted -2.9% / -4.4%), check_box -2.2% / -3.6% (persisted -2.2% / -4.0%)"
rank: 30
risky: false
state: merged
pr: 59824
note: "2026-11-18 (coordinator): live body PATCHed with the gated, rounded Callgrind sentence (Thomas approved); live body equal. 2026-11-18: body Callgrind sentence rounded to whole percent from the JIT-flat rerun form_helper_stack/body/fb1/gated (same trees, Ruby 4.0.7, every YJIT window flat, every cell outside its A/A; plain and persisted cases differ by up to 1.0 point under YJIT, so whole percent). The live body still has the 2026-11-17 sentence (3.1% / 5.3%, 2.2% / 4.0%); its YJIT figures came from pre-gate runs and are uncertified. Not PATCHed: waits for Thomas. 2026-11-17: body Callgrind sentence replaced verbatim with the claude-code confirm pass numbers (form_helper_stack/fb1_ir.*, main A/A at most 0.63%); head unchanged. 2026-11-17: a2a13fc793 has 870085d5a9's tree; only the commit message changed (date_select and friends don't call field_id, claude-code must-fix), force-pushed with a lease. Body: benchmark-ips replaced by objects per call and the Callgrind line, because wall time didn't reproduce (opus and claude-code must-fix; six rounds with an A/A in bench/upstream/form_helper_stack/fb1_ips_aa.txt). 2026-11-16 (Thomas: open as a separate draft overnight). Candidates B, C and D of bench/upstream/form_helper_stack. Action View suite green (2,967 + 251 + 177 runs). Only contrived inputs differ (a singleton gsub/delete_suffix on a plain String, to_s not returning a String); String subclasses behave the same, since String#to_s returns a plain copy. sanitized_method_name may now return @method_name itself; no in-tree caller mutates it. The 2026-11-16 body had benchmark-ips YJIT numbers; fb1_ips_aa.txt shows main against main up to +10.9% (checkbox, best of 6 rounds), so they were replaced. Review: one detailed claude-code pass is required now (DECISIONS 2026-11-17), and claude-code approved a2a13fc793 with the body as posted; only Thomas marks it ready."
passes:
  - {reviewer: skeptic, head: "870085d5a9", date: 2026-11-16, verdict: nits, open: "3,182 name pairs, 231,948 outputs and 390 regex inputs against main: identical apart from overridden String methods and non-String to_s; optional: a commit-message line on the no-op path, a comment that the match? class tracks the gsub class plus _"}
  - {reviewer: opus, orb: "T-01a1e86b-ce01-72c5-bb1c-f3f065ce2863", head: "870085d5a9", date: 2026-11-17, verdict: changes, open: "Code: no must-fix. match? class [^-a-zA-Z0-9:._] is exactly the gsub class plus _ (][ is two non-class chars); differential probe main vs branch, 5,974 lines over 199 inputs (Symbol, String, frozen literal, String subclass, SafeBuffer, binary, US-ASCII, UTF-16LE, invalid UTF-8, brackets, trailing _ and ?, index/namespace/multiple, collection_checkboxes/radio_buttons with nil value, form_with namespace, fields_for index and child arrays): every public output identical in value, class, encoding, frozen and html_safe, 1,835 raising inputs identical. Only private Tags::Base#sanitized_method_name differs: it is now @method_name itself, frozen for Symbol names (the usual case) and a SafeBuffer for SafeBuffer names; the only in-tree caller that keeps the String (collection_helpers sanitize_attribute_name) already dups it, and the html_safe label for stays escaped. No caller in simple_form 5.4.1, formtastic 6.0.0, bootstrap_form 5.6.1, govuk_design_system_formbuilder 6.6.0, client_side_validations 25.0.0, primer_view_components 0.53.5, activeadmin, administrate, avo, trestle, cocoon, nested_form, view_component or phlex-rails; GitHub code search finds only vendored Rails and gems defining their own sanitized_method_name. Objects per call (GC.stat, 1,000 calls, body's ActiveModel Post): text_field 28 -> 22, checkbox 32 -> 26, hidden_field 25 -> 19, select 43 -> 37, nested fields_for text_field 29 -> 26; field_id alone 11 -> 7 (a no-op gsub allocates 2). Branch form helper, form tag, collections, options and form_with tests: 907 runs, 0 failures; clean merge-tree on main 4f00fbc946, no base drift in these files. No added comments. MUST-FIX (body only, keeps head): the benchmark doesn't reproduce here. Body script, YJIT, pinned core, main/branch/main interleaved, best rounds: text_field 176.2k / 190.7k (+8%, A/A 174.0k), checkbox over 8 rounds 131.1k / 136.4k (+4%, A/A 125.9k, inside noise) against the body's +11% and +11%; the body's checkbox before row is +-8.0%, and Lowrail keeps neither its raw output nor an A/A. Rerun with more rounds and an A/A, record both under form_helper_stack, and post numbers that hold (or only text_field plus the object counts). Optional: the commit message's 'Every form builder field' isn't exact (an explicit id: skips field_id); the body's 'A form builder field' is fine."}
  - {reviewer: claude-code, orb: "T-01a1e86b-bad6-75b9-a538-65923711256c", head: "870085d5a9", date: 2026-11-17, verdict: changes, open: "Code: no must-fix, no added comments, RuboCop clean on both files. Differential probe main vs branch (Ruby 4.0.9), 45,973 lines: field_id over 47 object names x 26 method names x suffixes x index/namespace (Symbol, String, frozen, SafeBuffer, String subclasses, subclass overriding gsub/delete_suffix, binary, US-ASCII, UTF-16LE, invalid UTF-8, brackets, _attributes][, trailing _ and ?, model objects, Integer, Float, nil, to_s objects), field_name with extra names in four encodings, 13 builders x 7 methods x 21 fields incl. collection helpers with blank/nil values and form_with/fields_for: identical in value, class, encoding, frozen and html_safe, raises identical, inputs never mutated, counting to_s called once on both. Differences: objects whose to_s returns nil or a Symbol (624 lines), and singleton gsub/delete_suffix on a plain String (3 lines). Correction to the note and the skeptic: String subclasses do not differ, because String#to_s returns a plain copy for them, and SafeBuffer (to_s returns self) gives identical output. sanitized_method_name is now @method_name itself: frozen Symbol#name, the caller's own String, or a SafeBuffer; field_name interpolates it and sanitize_attribute_name dups it, and html_safe names with quotes in collection_check_boxes render identically; GitHub code search finds no outside caller of the private method. Action View rake test on branch and main: 2,967 + 251 + 177 runs, 0 failures. Body checked sentence by sentence: field_id/field_name via tag_id/tag_name, field_id 9 -> 5 and field_name 3 -> 2 objects, the _ sentence, ids and names unchanged; objects with the body's setup on 4.0.7 and 4.0.9: text_field 28 -> 22, checkbox 32 -> 26 (hidden_field 25 -> 19, select 44 -> 38, label 101 -> 95). MUST-FIX 1 (body, keeps head): body script on 4.0.7 YJIT, pinned core, 6 rounds interleaved: best main 109.8k / branch 123.1k text_field (+12%, matches the body), checkbox 76.0k / 81.9k (+8%, main runs 70.6k-76.0k, branch below main in 1 of 6) against the body's +11%. With opus's +4%, the checkbox row doesn't hold, and Lowrail keeps neither the raw output nor an A/A. Same fix as opus. MUST-FIX 2 (commit message, new head): 'Every form builder field computes its id with field_id' is false; date_select, time_select and datetime_select build ids in DateTimeSelector#input_id_from_type (field_id and field_name called 0 times, checked with a prepended counter), and an explicit id: skips it. Use the body's 'A form builder field'. Fix it before the remaining passes. Optional: 'still made' reads oddly in the commit message; no comment needed on the match? class."}
  - {reviewer: claude-code, orb: "T-01a1e86b-bad6-75b9-a538-65923711256c", head: "a2a13fc793", date: 2026-11-17, verdict: changes, open: "Confirm pass. Head: a2a13fc793 has 870085d5a9's tree (c527d1dbb3) and parent a5203b3d4d, so the earlier probe and suites stand; one commit, author and committer Thomas, no trailers, lines <= 72; merge-tree clean on upstream main 4f00fbc946, no base commits on the two files. Commit message: every sentence holds; text_field and checkbox each call field_id, field_name and sanitized_method_name once (prepended counters); the date_select must-fix is applied. Body (live = FB1.md, draft, head a2a13fc793): sentences unchanged from the reviewed version apart from 'such as text_field and checkbox' (checked as above). The script is byte-identical to form_helper_stack/fb1_alloc.rb and prints 28 -> 22 and 32 -> 26 on both trees under the 4.0.7 and 4.0.9 interpreters, as shown (YJIT: checkbox 33 -> 27, so the interpreter version line matters and is right). MUST-FIX (body only, keeps head): the Callgrind sentence has no record (no script or raw output in form_helper_stack, whose README says no Callgrind), and its YJIT checkbox number doesn't reproduce. fb1_ir.sh (added with fb1_ir.rb, fb1_ir.txt and a README table), Ruby 4.0.7, body's Post plain and persisted (no difference), GC off, main measured twice per cell: text_field -3.1% / -5.3%, checkbox -2.2% / -4.0% (interpreter / YJIT), main A/A 0.33 / 0.63 / 0.12 / 0.25%; the body says -2.8 / -5.7 and -2.3 / -4.8, so checkbox YJIT is 0.8 points off with an A/A of 0.25%. GC on doesn't recover it (one run each, cells move up to 3 points). Fix: 'a text_field call runs 3.1% fewer instructions in the interpreter and 5.3% fewer with YJIT, and a checkbox call 2.2% and 4.0% fewer', or record the measurement behind the current numbers with an A/A. Note to correct: persisted? doesn't change the field path; String subclasses don't differ (see my 870085d5a9 pass)."}
  - {reviewer: claude-code, orb: "T-01a1e86b-bad6-75b9-a538-65923711256c", head: "a2a13fc793", date: 2026-11-17, verdict: approve, open: "Confirm pass on the body (Lowrail 2ebecfc9). Head unchanged (git ls-remote a2a13fc793, PR head a2a13fc793, draft). Live body = FB1.md body (whitespace-normalized diff empty); against the body I reviewed, only the Callgrind sentence changed, and its numbers are fb1_ir.txt's means rounded (-3.05, -5.31, -2.18, -3.96 -> 3.1, 5.3, 2.2, 4.0), main A/A <= 0.63%. Note no longer claims String subclasses differ. Fixed myself: impact still carried the old -2.8/-5.7, -2.3/-4.8 and an unrecorded select -2.6/-2.9; now the recorded numbers. Optional (record only): the note's 2026-11-16 'benchmark-ips YJIT in the body, A/A within 1-4%' and 'Needs claude-code and opus/astra passes' are stale (fb1_ips_aa.txt shows main-vs-main up to +10.9%; one claude-code pass is now required). No must-fix."}
---

# Skip copying form field names that need no changes

Form builder fields such as `text_field` and `checkbox` compute their id with `field_id` and their name with `field_name`, and `Tags::Base#sanitized_method_name` strips a trailing `?` from the method name. For usual names such as `post` and `title`, none of them changes anything, but each made a copy: `field_id` copied the object name twice and the method name once, `field_name` joined an empty Array into a new String, and `sanitized_method_name` copied the method name.

This makes each copy only when there is something to replace. A `_` counts as nothing to replace, because `field_id`'s `gsub` turns it into itself. Ids and names are the same as before.

```ruby
require "active_support/all"
require "active_model"
require "action_view"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :published, :boolean
end

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello", published: true), view, {})

{ "text_field" => -> { form.text_field(:title) }, "checkbox" => -> { form.checkbox(:published) } }.each do |name, field|
  field.call
  before = GC.stat(:total_allocated_objects)
  1000.times { field.call }
  puts "#{name}: #{(GC.stat(:total_allocated_objects) - before) / 1000} objects"
end
```

```
ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]

before: text_field: 28 objects
before: checkbox: 32 objects
after:  text_field: 22 objects
after:  checkbox: 26 objects
```

Under Callgrind, a `text_field` call runs about 3% fewer instructions in the interpreter and 5% fewer with YJIT, and a `checkbox` call about 2% and 4% fewer.
