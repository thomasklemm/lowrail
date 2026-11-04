# frozen_string_literal: true

# Per-call cost of JSONGemCoderEncoder#escape! on small documents (rails#59584 review).
#   ruby [--yjit] -I RAILS/activesupport/lib escape_small.rb
# Prints ns/call (best of 3 batches) for each case. JS_OFF=1 sets
# escape_js_separators_in_json = false (load_defaults 8.1); HTML_OFF=1 sets
# escape_html_entities_in_json = false (JS separators only). With IR=N the
# script instead runs CASE (env) N times with GC off, for Callgrind deltas.
require "active_support"
require "active_support/json"

ActiveSupport.escape_js_separators_in_json = false if ENV["JS_OFF"] == "1"
ActiveSupport.escape_html_entities_in_json = false if ENV["HTML_OFF"] == "1"

DOCS = {
  "small" => { "id" => 1, "name" => "x" },
  "record11" => {
    "id" => 1, "author_id" => 7, "title" => "Post 1 about Ruby and Rails",
    "body" => "Body text 1, with quotes and e. " * 2, "published" => true,
    "comments_count" => 3, "score" => "1.25", "published_at" => "2026-01-01T01:00:00.000Z",
    "slug" => "post-1", "created_at" => "2026-11-03T10:00:00.000Z", "updated_at" => "2026-11-03T10:00:00.000Z",
  },
  # Contains every escaped character.
  "chars" => { "id" => 1, "title" => "Ruby & Rails", "body" => "<b>bold</b> line\u2028next\u2029end" },
}.freeze

encoder = ActiveSupport::JSON::Encoding.json_encoder.new
raise "not the coder encoder: #{encoder.class}" unless encoder.class.name.end_with?("JSONGemCoderEncoder")

cases = DOCS.flat_map do |name, doc|
  dumped = JSON.generate(doc).freeze
  [["#{name} encode", -> { ActiveSupport::JSON.encode(doc) }],
   ["#{name} escape!", -> { encoder.send(:escape!, +dumped) }]]
end.to_h

if (n = ENV["IR"])
  c = cases.fetch(ENV.fetch("CASE"))
  50.times { c.() }
  GC.disable
  Integer(n).times { c.() }
  exit!(0)
end

def ns(n = 200_000)
  3.times.map do
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { yield }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e9 / n
  end.min
end

cases.each_value { |c| 20_000.times { c.() } }
cases.each { |name, c| puts format("%-18s %8.1f", name, ns { c.() }) }
