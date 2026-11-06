# frozen_string_literal: true

require "json"
require "objspace"
require_relative "../../heap_windows"
require_relative "../../jit_stability"
tree = ENV.fetch("BENCH_RAILS_PATH")
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { File.join(tree, _1, "lib") })
require "active_record"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
JitStability.assert_mode!

database = File.join(ENV.fetch("BENCH_OUTPUT"), "fixture-#{Process.pid}.sqlite3")
at_exit do
  ActiveRecord::Base.connection_handler.clear_all_connections!
  File.unlink(database) if File.exist?(database)
end
ActiveRecord.async_query_executor = :global_thread_pool
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: database, pool: 4)
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :n } }
class Post < ActiveRecord::Base; end
Post.create!(title: "first", n: 1)
Post.create!(title: "second", n: 2)
Post.create!(title: "third", n: 2)
connection = Post.lease_connection
ActiveRecord::Base.asynchronous_queries_tracker.start_session
proxy = ActiveRecord::ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")

cases = {
  "find" => -> { Post.find(1) },
  "where" => -> { Post.where(n: 2).to_a },
  "update_all" => -> { Post.where(id: 1).update_all(n: 1) },
  "async" => -> {
    relation = Post.where(n: 2).load_async
    future = relation.instance_variable_get(:@future_result)
    30_000.times do
      break unless future.pending?
      sleep(0.001)
    end
    raise "async completion timed out" if future.pending?
    relation.to_a
  },
  "proxy" => -> { proxy.exec_query("SELECT n FROM posts WHERE id = ?", "Proxy bench", [1], prepare: true) },
}
raise "find fixture" unless cases.fetch("find").call.title == "first"
raise "where fixture" unless cases.fetch("where").call.map(&:title) == ["second", "third"]
raise "update fixture" unless cases.fetch("update_all").call == 1
raise "async fixture" unless cases.fetch("async").call.map(&:title) == ["second", "third"]
raise "proxy fixture" unless cases.fetch("proxy").call.rows == [[1]]

n = Integer(ENV.fetch("BENCH_N", "500"))
warm = Integer(ENV.fetch("BENCH_WARMUP", "500"))
cases.each do |name, work|
  warn "warming #{name}"
  warm.times { work.call }
end
jit_warmup = JitStability.warm { |count, _| cases.each_value { |work| count.times { work.call } } } if JitStability.enabled?
anchors = HeapWindows.prepare_heap
heaps = GC.stat_heap.keys
snapshot = -> { GC.stat_heap.transform_values { _1.slice(:heap_eden_pages, :heap_eden_slots) } }
baseline_capacity = snapshot.call
records = []
cases.each do |name, work|
  [0, n].each do |count|
    warn "window #{name} #{count}"
    HeapWindows.collect
    GC.disable
    before_pools = snapshot.call
    before = heaps.to_h { [_1, GC.stat_heap(_1, :total_allocated_objects)] }
    jit_before = JitStability.snapshot if JitStability.enabled?
    LowrailCallgrindBench.start
    count.times { work.call }
    LowrailCallgrindBench.finish
    jit_after = JitStability.snapshot if JitStability.enabled?
    after = heaps.to_h { [_1, GC.stat_heap(_1, :total_allocated_objects)] }
    after_pools = snapshot.call
    GC.enable
    allocated = heaps.to_h { [_1, after.fetch(_1) - before.fetch(_1)] }
    records << { name: name, n: count, objects: allocated.values.sum,
      bytes: allocated.sum { |pool, objects| objects * GC.stat_heap(pool, :slot_size) },
      pools_before: before_pools, pools_after: after_pools,
      jit_before: jit_before, jit_after: jit_after,
      heap_ok: before_pools == baseline_capacity && after_pools == baseline_capacity }
  end
end

intents = []
capture = Module.new do
  define_method(:execute_intent) do |intent|
    intents << intent
    super(intent)
  end
end
ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(capture)
layouts = cases.to_h do |name, work|
  intents.clear
  work.call
  [name, intents.map { |intent|
    request = intent.respond_to?(:request) ? intent.request : nil
    { ivars: intent.instance_variables.size, bytes: ObjectSpace.memsize_of(intent),
      ran_async: intent.ran_async, request_ivars: request&.instance_variables&.size,
      request_bytes: request && ObjectSpace.memsize_of(request), request_frozen: request&.frozen? }
  }]
end
puts JSON.generate(ruby: RUBY_DESCRIPTION, rails: `git -C #{tree} rev-parse HEAD`.strip,
  gems: Gem.loaded_specs.transform_values { _1.version.to_s }, jit: JitStability.actual,
  **JitStability.state, jit_warmup: jit_warmup,
  zjit_oom: JitStability.actual == "zjit" ? RubyVM::ZJIT.stats[:compile_error_out_of_memory] : nil,
  n: n, warmup: warm, capacity: baseline_capacity, windows: records, layouts: layouts,
  anchors: anchors.size)
