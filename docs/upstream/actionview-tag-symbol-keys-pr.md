### Motivation / Background

Nested `data:` / `aria:` / other Hash attribute keys still call `Symbol#to_s`
before `dasherize` builds another String. Avoid the first allocation by using
`Symbol#name`, as the flat and boolean attribute appenders already do.

### Detail

This is a small follow-up to #59117, not another attribute-buffer rewrite
(also proposed in #57999). It uses the same Symbol conversion idiom as #59224.
Non-Symbol keys still use `to_s`. Live `String#dasherize` / Inflector dispatch,
JSON serialization, escaping and output assembly are unchanged. For Symbol
keys, `dasherize` now receives the shared frozen name rather than a freshly
allocated mutable String; receiver identity and mutability are not preserved.
Stock `dasherize` is non-mutating and already accepts frozen Strings;
TagBuilder's custom-tag path already calls `Symbol#name.dasherize`.

### Additional information

Ruby 4.0.7, x86_64 Linux, benchmark-ips 2.15.1, stock Rails without Lowrail.
Baseline: Rails 8.2.0.alpha at
[`a5545972e7`](https://github.com/rails/rails/commit/a5545972e7fc2a17062b46b31e1fba99eea85a49).
Each arm ran in a separate process, serially: 1 second warmup, 3 seconds
measurement per case; allocations counted over 20,000 warmed operations with
GC enabled. The table is the complete final cohort, not selected reruns.

| Operation | Objects/op before → after, both modes | Interpreter k i/s before → after | YJIT k i/s before → after |
| --- | ---: | ---: | ---: |
| Scalar tag | 7 → 7 | 227.755 ±6.0% → 231.145 ±4.5% | 317.331 ±2.8% → 313.634 ±6.8% |
| Three Symbol data keys | 17 → 14 | 114.447 ±7.7% → 115.129 ±4.6% | 155.123 ±14.0% → 177.874 ±6.3% |
| Three String data keys | 14 → 14 | 120.388 ±1.4% → 117.055 ±4.7% | 176.761 ±8.0% → 171.200 ±10.3% |
| Two Symbol aria keys | 18 → 16 | 114.173 ±1.9% → 115.149 ±2.7% | 168.643 ±16.8% → 187.148 ±4.9% |
| Link with three data keys | 19 → 16 | 86.462 ±4.3% → 82.594 ±4.5% | 138.562 ±10.6% → 147.735 ±4.5% |
| GET button with three data keys | 27 → 24 | 40.661 ±6.1% → 39.148 ±10.9% | 83.692 ±7.5% → 78.391 ±4.8% |
| Record URL control | 9 → 9 | 139.010 ±5.3% → 141.385 ±0.6% | 309.185 ±9.6% → 305.511 ±7.2% |
| String URL control | 0 → 0 | 10,568 ±2.5% → 11,788 ±5.0% | 26,905 ±11.9% → 28,517 ±8.5% |

The allocation saving is one object per processed nested Symbol key. Timings
are noisy exploratory helper micros, not a stable throughput or request-speed
claim. In particular, the link and button interpreter point estimates and
the button YJIT point estimate are lower after the change. The ± values are
within-run standard deviations, not confidence intervals or proof of equality.

Tests on both main and this change:

```sh
# From actionview/, with the repository Gemfile and Ruby 4.0.7:
BUNDLE_ONLY=default:test:rubocop:cable:db PARALLEL_WORKERS=1 SEED=41231 bundle exec rake test
# 2901 runs, 6865 assertions; 249 runs, 338 assertions; 173 runs, 334 assertions
# All three groups: 0 failures, 0 errors, 0 skips.

# From the Rails root:
BUNDLE_ONLY=default:test:rubocop:cable:db bundle exec rubocop actionview/lib/action_view/helpers/tag_helper.rb
# 1 file inspected, no offenses detected
```

Additional standalone controls compare 3,049 byte/encoding/safety/frozen-flag
or exception snapshots, including nil/false/true, Symbols, non-String values,
String subclasses, SafeBuffer, nested data/aria/custom prefixes, invalid
encodings, escape on/off, a TagBuilder subclass, and live non-mutating String /
Inflector overrides. All match. Existing rendering tests are unchanged; no
permanent VM-allocation assertion is added.

<details>
<summary>Standalone benchmark script</summary>

Install `benchmark-ips` 2.15.1 and the Rails checkout's dependencies first.
Run against clean and changed checkouts with a fresh shared output prefix per
mode (saved comparisons are supported by benchmark-ips 2.15.1):

```sh
ruby actionview_helpers.rb /path/to/main before /tmp/av-interpreter
ruby actionview_helpers.rb /path/to/change after /tmp/av-interpreter
ruby --yjit actionview_helpers.rb /path/to/main before /tmp/av-yjit
ruby --yjit actionview_helpers.rb /path/to/change after /tmp/av-yjit
```

```ruby
# frozen_string_literal: true

# ruby [--yjit] actionview_helpers.rb RAILS_CHECKOUT LABEL OUTPUT_PREFIX
# Run before and after in separate processes with a fresh shared output prefix.
# The candidate only replaces nested Symbol keys' to_s with name.
# These are short helper micros, not application/request-speed measurements.
rails, label, output = ARGV
abort "usage: #{$0} RAILS_CHECKOUT LABEL OUTPUT_PREFIX" unless output
%w[activesupport activemodel actionpack actionview].each do |component|
  $LOAD_PATH.unshift File.join(rails, component, "lib")
end
require "action_controller"
require "action_view"
require "active_model"
require "active_support/json"
require "benchmark/ips"

class Post
  include ActiveModel::Model
  attr_accessor :id

  def persisted?
    true
  end
end

routes = ActionDispatch::Routing::RouteSet.new
routes.draw { resources :posts }
view_class = Class.new(ActionView::Base) do
  include routes.url_helpers
end
view = view_class.empty
post = Post.new(id: 37)
text = "Search <posts> & comments"
safe = '<strong>Search</strong>'.html_safe
symbols = { data: { controller: "search", action: "click->search#open", item_id: 37 } }
strings = { "data" => { "controller" => "search", "action" => "click->search#open", "item_id" => 37 } }
aria = { aria: { label: text, described_by: ["help", "errors"] } }

scenarios = {
  scalar_tag: -> { view.content_tag(:div, text, class: "card", title: text) },
  data_symbols: -> { view.content_tag(:div, text, symbols) },
  data_strings: -> { view.content_tag(:div, text, strings) },
  aria_symbols: -> { view.content_tag(:div, safe, aria) },
  nested_link: -> { view.link_to(text, "/posts/37?a=1&b=2", symbols) },
  get_button: -> { view.button_to(text, "/posts/37", method: :get, **symbols) },
  record_url: -> { view.url_for(post) },
  string_url: -> { view.url_for("/posts/37") }
}

# Validate every fixture before any timing starts.
scenarios.each_value(&:call)
abort "unexpected URL" unless scenarios[:record_url].call == "/posts/37"

puts RUBY_DESCRIPTION
puts "Rails #{ActionView::VERSION::STRING}; benchmark-ips #{Benchmark::IPS::VERSION}"
puts "checkout: #{rails}; label: #{label}"
scenarios.each do |name, operation|
  2_000.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  20_000.times { operation.call }
  allocated = GC.stat(:total_allocated_objects) - before
  puts "#{name}: #{format('%.3f', allocated.fdiv(20_000))} objects/op"

  Benchmark.ips do |x|
    x.config(warmup: 1, time: 3)
    x.report(label, &operation)
    x.compare!(order: :baseline)
    x.save!("#{output}-#{name}.json")
  end
end
```

</details>

### Checklist

* [x] This Pull Request is related to one change. Unrelated changes should be opened in separate PRs.
* [x] Commit message has a detailed description of what changed and why. No related bug report is being fixed.
* [x] Tests are added or updated if you fix a bug or add a feature. This allocation-only refactor retains existing tests; the full Action View suite passes.
* [x] CHANGELOG files are updated for the changed libraries if there is a behavior change or additional feature. Not applicable: no feature, deprecation or behavior change.
