# Per-call micro under Callgrind (--toggle-collect=rb_ary_cycle): boots a ruby-bench app
# (APP=railsbench|lobsters|shipit|erubi-rails, BUNDLE_GEMFILE set by the driver) or nothing (APP=none,
# RAILS_PATH libs on the load path), loads CASES (a Ruby file defining MICRO = { name => -> { setup; -> { work } } }),
# warms up, then runs ITERS calls of the case with GC disabled inside [nil].cycle(1).
#   ruby irm.rb CASES CASE ITERS
cases_file, name, iters = ARGV[0], ARGV[1], Integer(ARGV[2])
app = ENV.fetch("APP", "none")
if app != "none"
  Dir.chdir(File.join(ENV.fetch("RUBY_BENCH_DIR", File.expand_path("~/src/ruby-bench")), "benchmarks", app))
  ENV["RAILS_ENV"] ||= "production"
  ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] = "1"
  ENV["SHIPIT_DISABLE_AUTH"] = "1"
  ENV["SECRET_KEY_BASE"] ||= "0" * 128
  require File.expand_path("config/environment", Dir.pwd)
  if app == "shipit"
    mem_db = ActiveRecord::Base.connection.raw_connection
    file_db = SQLite3::Database.new("db/production.committed.sqlite3")
    b = SQLite3::Backup.new(mem_db, "main", file_db, "main")
    b.step(-1)
    b.finish
  end
end
load cases_file
work = MICRO.fetch(name).call
require ENV.fetch("BENCH_CALLGRIND_EXTENSION") if ENV["PERFCALL_CLIENT"] == "1"
calls = ->(count) { count.times { work.call } }
calls.call(ENV.fetch("WARMUP", "2000").to_i)
jit_proof = nil
if ENV["PERFCALL_STATE"] == "1"
  require_relative "../../jit_stability"
  require "json"
  JitStability.assert_mode!
  heap_anchors = HeapWindows.prepare_heap
  200.times do
    GC.stat_heap.transform_values { _1.slice(:heap_eden_pages, :heap_eden_slots) }
    JitStability.snapshot if JitStability.enabled?
  end
  if JitStability.enabled?
    jit_proof = JitStability.observe_batches(200, 100, 0, 10) { |count| calls.call(count) }
  end
end
GC.start
GC.disable
if ENV["PERFCALL_STATE"] == "1"
  heap_before = GC.stat_heap.transform_values { _1.slice(:heap_eden_pages, :heap_eden_slots) }
  jit_before = JitStability.snapshot if JitStability.enabled?
end
alloc0 = GC.stat(:total_allocated_objects)
LowrailCallgrindBench.start if ENV["PERFCALL_CLIENT"] == "1"
[nil].cycle(1) { calls.call(iters) }
alloc = GC.stat(:total_allocated_objects) - alloc0
LowrailCallgrindBench.finish if ENV["PERFCALL_CLIENT"] == "1"
if ENV["PERFCALL_STATE"] == "1"
  jit_after = JitStability.snapshot if JitStability.enabled?
  heap_after = GC.stat_heap.transform_values { _1.slice(:heap_eden_pages, :heap_eden_slots) }
  jit_flat = !JitStability.enabled? || (jit_proof[:consecutive_flat_windows] >= 10 &&
    jit_before.values.all? { _1.is_a?(Integer) } && jit_before == jit_after)
  warn "PERFCALL_STATE #{JSON.generate(jit: JitStability.state, warmup: jit_proof, jit_before: jit_before,
    jit_after: jit_after, jit_flat: jit_flat, heap_before: heap_before, heap_after: heap_after)}"
  raise "measurement state changed" unless jit_flat && heap_before == heap_after
end
GC.enable
$stderr.puts "OBJECTS_PER_CALL #{alloc / iters.to_f}"
