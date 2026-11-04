# frozen_string_literal: true

# Active Support request-path micros, for a Rails checkout given in RAILS:
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N ir    N calls inside [0].cycle(1), GC off (Callgrind,
#                                                        --toggle-collect=rb_ary_cycle; ir.sh)
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N obj   objects per call
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N ns    wall ns per call, GC off (ns_pinned.sh)
# Loads Rails from the checkout's lib directories, so Ruby master runs it without a bundle.
RAILS = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord actionview actionpack].each { |c| $LOAD_PATH.unshift File.join(RAILS, c, "lib") }
require "active_support"
require "active_support/notifications"
require "active_support/core_ext/hash/slice"
require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
class Post < ActiveRecord::Base; end
Post.create!(title: "t")

[ActiveSupport::Notifications::Fanout.instance_method(:build_handle), Hash.instance_method(:extract!),
  ActionView::Helpers::AssetTagHelper.instance_method(:stylesheet_link_tag)].each do |m|
  raise "#{m.name} not loaded from #{RAILS}" unless m.source_location.first.start_with?(File.expand_path(RAILS) + "/")
end

# A notifier like a production app's for these events: one monotonic callable (as
# ActiveRecord::RuntimeRegistry), plus, for "two", one event-object subscriber.
class Runtime; def self.call(name, start, finish, id, payload) = nil; end
FANOUT = ActiveSupport::Notifications::Fanout.new
FANOUT.subscribe("bench.one", Runtime, monotonic: true)
FANOUT.subscribe("bench.two", Runtime, monotonic: true)
FANOUT.subscribe("bench.two") { |event| }
INSTRUMENTER = ActiveSupport::Notifications::Instrumenter.new(FANOUT)
PAYLOAD = { sql: "SELECT 1" }
VIEW = ActionView::Base.empty

CASES = {
  "instrument_one" => -> { INSTRUMENTER.instrument("bench.one", PAYLOAD) { } },
  "instrument_two" => -> { INSTRUMENTER.instrument("bench.two", PAYLOAD) { } },
  "build_handle_one" => -> { FANOUT.build_handle("bench.one", "id", PAYLOAD) },
  "find" => -> { Post.find(1) },
  "extract" => -> { { "media" => "all" }.extract!("protocol", "extname", "host", "skip_pipeline") },
  "extract_hit" => -> { { "media" => "all", "host" => "x" }.extract!("protocol", "extname", "host", "skip_pipeline") },
  "stylesheet_link_tag" => -> { VIEW.stylesheet_link_tag("application") },
  "javascript_include_tag" => -> { VIEW.javascript_include_tag("application") },
}

name, n, mode = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
fn = CASES.fetch(name)
(ENV["WARMUP"] || 3000).to_i.times { fn.() }
GC.start
GC.disable
case mode
when "ir"
  [0].cycle(1) { n.times { fn.() } }
when "obj"
  b = GC.stat(:total_allocated_objects)
  n.times { fn.() }
  puts (GC.stat(:total_allocated_objects) - b).fdiv(n)
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  n.times { fn.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(n).round(1)
end
