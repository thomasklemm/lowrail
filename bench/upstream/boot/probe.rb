# frozen_string_literal: true

# Boot-to-first-request probe, run by bench/upstream/boot/run.rb inside a
# disposable census copy (production, eager_load as the app configures it):
#   ruby probe.rb KIND APP OUT_JSON
# KIND: plain (no profiler; for Callgrind and timing), cpu (stackprof CPU
# samples, raw, classified by boot phase), objects (stackprof, every
# allocation, by site and phase). The boot is RailsCensus.boot (the census
# harness: config/application, then config/environment), then one GET.
started_cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
started_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
kind, app, out = ARGV
abort "usage: probe.rb plain|cpu|objects APP OUT_JSON" unless %w[plain cpu objects].include?(kind) && out
raise "fresh output required" if File.exist?(out)

# stackprof without activating a gem, so the app's bundle is unaffected.
if kind != "plain"
  $LOAD_PATH.unshift(Dir[File.join(Gem.default_dir, "gems/stackprof-0.2.28/lib")].first ||
    abort("stackprof 0.2.28 not installed"))
  require "stackprof"
  if kind == "cpu"
    StackProf.start(mode: ENV.fetch("BOOT_STACKPROF_MODE", "wall").to_sym, interval: Integer(ENV.fetch("BOOT_INTERVAL_US", "250")), raw: true)
  else
    StackProf.start(mode: :object, interval: 1, raw: true)
  end
end

# As bundle exec (and config/boot.rb) would, before the harness loads json.
require "bundler/setup"

require_relative "probe_paths"

# BOOT_CONFIG_ZJIT=1 (with --zjit-disable): enable ZJIT the way config.zjit
# does, in Rails' enable_zjit finisher initializer, instead of from the start.
if ENV["BOOT_CONFIG_ZJIT"] == "1"
  require "active_support/lazy_load_hooks"
  ActiveSupport.on_load(:before_initialize) { config.zjit = true }
end

module BootProbe
  PATHS = BootPaths::PATHS

  def self.boot(app) = RailsCensus.boot(app)

  def self.first_request(app)
    path, headers = PATHS.fetch(app)
    RailsCensus::Client.new.get(path, headers: headers || {}, expect: [200])
  end
end

require_relative "../census/harness"
BootProbe.boot(ARGV[1])
booted_cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
booted_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
booted_objects = GC.stat(:total_allocated_objects)
# ZJIT counters (with --zjit-stats-quiet) at boot, after the first request and after BOOT_REQUESTS.
zjit = defined?(RubyVM::ZJIT) && RubyVM::ZJIT.stats_enabled?
zjit_keys = %i[compile_time_ns compiled_iseq_count failed_iseq_count profile_time_ns gc_time_ns invalidation_time_ns
  code_region_bytes zjit_insn_count vm_insn_count side_exit_count]
zjit_snap = -> { RubyVM::ZJIT.stats.slice(*zjit_keys) }
zjit_stats = { boot: zjit_snap.call } if zjit
response = BootProbe.first_request(app)
done_cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
done_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
done_objects = GC.stat(:total_allocated_objects)
zjit_stats[:first_request] = zjit_snap.call if zjit
profile = StackProf.stop && StackProf.results if kind != "plain"
more = Integer(ENV.fetch("BOOT_REQUESTS", "1")) - 1
more_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
more.times { BootProbe.first_request(app) }
more_wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - more_wall
zjit_stats[:"after_#{more + 1}_requests"] = zjit_snap.call if zjit && more > 0

result = {
  app: app, kind: kind, ruby: RUBY_DESCRIPTION, rails: ENV["CENSUS_RAILS_SHA"],
  eager_load: Rails.application.config.eager_load, status: response.status,
  # CPU since process start includes the VM's own boot (before this file ran).
  cpu_ms: { boot: ((booted_cpu) * 1000).round(1), request: ((done_cpu - booted_cpu) * 1000).round(1),
            probe_start: (started_cpu * 1000).round(1) },
  wall_ms: { boot: ((booted_wall - started_wall) * 1000).round(1), request: ((done_wall - booted_wall) * 1000).round(1),
             later_requests_mean: (more > 0 ? (more_wall * 1000 / more).round(2) : nil) },
  zjit: zjit_stats,
  objects: { boot: booted_objects, request: done_objects - booted_objects },
  gc: GC.stat.slice(:count, :minor_gc_count, :major_gc_count, :time),
  loaded_features: $LOADED_FEATURES.size,
  gems: Gem.loaded_specs.transform_values { _1.full_gem_path },
}
if profile
  # Frames as [name, file, line]; raw stacks as frame-id arrays, root first.
  frames = profile[:frames].transform_values { [_1[:name], _1[:file], _1[:line]] }
  stacks = []
  raw = profile[:raw]
  i = 0
  while i < raw.size
    len = raw[i]
    stack = raw[i + 1, len]
    count = raw[i + 1 + len]
    stacks << [stack, count]
    i += len + 2
  end
  result[:profile] = { mode: profile[:mode], interval: profile[:interval], samples: profile[:samples],
    frames: frames, stacks: stacks }
end
File.write(out, JSON.generate(result) + "\n")
puts JSON.generate(result.except(:profile, :gems))
