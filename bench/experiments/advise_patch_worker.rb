# frozen_string_literal: true

# Separate from the discovery process: never load Advise, StackProf, ObjectSpace
# tracing or TracePoint in an acceptance measurement.
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false if ENV.fetch("BENCH_JIT") == "0"
require File.expand_path("config/environment", Dir.pwd)
require "json"
require "digest"
require_relative "../jit_stability"
require_relative "advise_patch_study"

raise "pinned runtime required" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
raise "acceptance requires production, eager loading and caching" unless Rails.env.production? &&
  Rails.application.config.eager_load && Rails.application.config.action_controller.perform_caching &&
  !Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
JitStability.assert_mode!
Rails.logger.level = :error
workloads = eval(File.read(ENV.fetch("ADVISE_WORKLOAD")), TOPLEVEL_BINDING, ENV.fetch("ADVISE_WORKLOAD"))
raise "one workload required" unless workloads.one?
work = workloads.values.first
run = ->(n, _unit = nil) { n.times { work.call }; nil }
50.times { work.call }
n = Integer(ENV.fetch("BENCH_REQUESTS", "1000"))
entropy = ENV["ADVISE_ENTROPY"] ? JSON.parse(File.read(ENV.fetch("ADVISE_ENTROPY"))) : {}
exact = -> {
  queries = []
  connections = {}.compare_by_identity
  subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
    event = args.last
    # No normalization, ignored queries or masked binds in this source study.
    connection = connections[event.fetch(:connection)] ||= connections.size + 1
    queries << [event[:sql], event[:binds]&.map { [_1.name, _1.value_for_database] }, !!event[:cached],
      connection, event[:name], event[:row_count]]
  end
  begin
    response = work.call
    AdvisePatchStudy.response_fingerprint(response, entropy).merge(
      sql_n: queries.size, sql_sha256: Digest::SHA256.hexdigest(JSON.generate(queries)), sql: queries)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
}

if ENV["ADVISE_SCREEN"] == "1"
  result = { screen_only: true }
elsif ENV["ADVISE_COUNTER"] == "1"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  windows = HeapWindows.windows(n)
  warm = nil
  anchors = HeapWindows.run(windows, observe: JitStability.enabled? ? JitStability.method(:snapshot) : nil,
    settle: -> { run.call(1) }, warmup: -> {
      warm = JitStability.warm(rehearsal_requests: 20, &run) if JitStability.enabled?
      abort "YJIT did not quiesce: #{JSON.generate(warm)}" if warm && !warm[:stable]
    }, &run)
  result = { windows: windows, heap_anchors: anchors, heap_page_targets: HeapWindows.page_targets,
    jit_warmup: warm, **JitStability.state }
else
  # Rehearse the observer and timing APIs before the same bounded quiet warmup.
  200.times { JitStability.snapshot; GC.stat(:total_allocated_objects); Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) }
  warm = JitStability.warm(rehearsal_requests: 20, &run)
  abort "YJIT did not quiesce: #{JSON.generate(warm)}" unless warm[:stable]
  HeapWindows.collect
  window = { jit_before: JitStability.snapshot }
  alloc0 = GC.stat(:total_allocated_objects)
  cpu0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  wall0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  run.call(n, nil) # Same callback arity as the certified warmup.
  wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall0
  cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu0
  allocated = GC.stat(:total_allocated_objects) - alloc0
  window[:jit_after] = JitStability.snapshot
  result = { cpu_us: cpu * 1e6 / n, wall_us: wall * 1e6 / n, allocations: allocated.fdiv(n),
    windows: [window], jit_warmup: warm, **JitStability.state }
end
result.merge!(requests: n, ruby: RUBY_DESCRIPTION, rails: Rails.version, rails_env: Rails.env,
  exact: Array.new(3) { exact.call }, lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest)
puts "LOWRAIL_BENCH #{JSON.generate(result)}"
