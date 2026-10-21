# frozen_string_literal: true

# Fixed-heap instruction worker. Keep separate from the native timing worker:
# even unused additional ISeqs can change its initial heap/GC phase.
require_relative "jit_stability"
if JitStability.mode != "yjit"
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
end
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"
require_relative "heap_windows"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")

Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil if defined?(ActiveRecord::Base)
JitStability.assert_mode!
abort "usage: heap_requests.rb VERB:PATH" unless ARGV.size == 1
verb, path = ARGV.first.split(":", 2)
session = Rack::MockRequest.new(Rails.application)
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
n = Integer(ENV.fetch("BENCH_REQUESTS", "50"))
raise "positive request count required" unless n.positive?

def counted_requests(n, session, verb, path, headers)
  n.times do
    response = session.request(verb, path, headers)
    raise "#{verb} #{path} -> #{response.status}" unless (200..299).cover?(response.status)
  end
end

# Prepopulate all observation hashes before warmup. No new reporting hashes
# or arrays are allocated between each window's GC.stat endpoints.
windows = HeapWindows.windows(n)
counted_requests(Integer(ENV.fetch("BENCH_WARMUP", "50")), session, verb, path, headers)
if ENV["BENCH_IDLE_CENSUS"] == "1"
  # A separate untimed process only. Never enable hooks in an Ir worker.
  census = { kind: "untimed_companion_not_measured_counts", idle_exercise: 0, counts: [] }
end
if census && defined?(ActiveRecord::Base)
  require "digest"
  owner = ActiveRecord::ConnectionAdapters::AbstractAdapter
  method = owner.instance_method(:with_raw_connection)
  source, line = method.source_location
  target_line = line + 16
  raise "uncertified AR idle census" unless ActiveRecord.version.to_s == "8.1.4" &&
    File.readlines(source).fetch(target_line - 1).strip == "elsif reconnectable"
  body = nil
  RubyVM::InstructionSequence.of(method).each_child { body = _1 if _1.label == "block in with_raw_connection" }
  raise "AR idle block unavailable" unless body
  verify_paths = 0
  trace = TracePoint.new(:line) { |event| verify_paths += 1 if event.path == source && event.lineno == target_line }
  census.merge!(source_sha256: Digest::SHA256.file(source).hexdigest, target_line: target_line)
end
jit_warmup = nil
if JitStability.enabled?
  observe = JitStability.method(:snapshot)
  idle_connections = -> {
    if defined?(ActiveRecord::Base)
      ActiveRecord::Base.connection_handler.connection_pool_list(:all).flat_map(&:connections).map do |connection|
        { verify_timeout: connection.verify_timeout, last_activity: connection.instance_variable_get(:@last_activity) }
      end
    else
      []
    end
  }
  warmup = -> {
    timeouts = idle_connections.call.map { _1.fetch(:verify_timeout) }
    idle = timeouts.empty? ? 0 : [timeouts.max, 0].max + 0.05
    sleep idle if idle.positive?
    if trace
      trace.enable(target: body) { counted_requests(1, session, verb, path, headers) }
      census[:idle_exercise] = verify_paths
    else
      counted_requests(1, session, verb, path, headers)
    end
    jit_warmup = JitStability.warm { |count| counted_requests(count, session, verb, path, headers) }
    jit_warmup[:stage] = "post_heap_observer_idle"
    jit_warmup[:idle_boundary] = { sleep_seconds: idle, verify_timeouts: timeouts }
  }
end

# Init slots are lazy growth floors, not preallocated pages. Fill each pool
# explicitly, then discard most fillers. On 64-bit MRI these Array lengths
# occupy 40/80/160/320/640-byte slots; actual capacities are checked by the
# driver. GC is disabled only during this untimed preparation, never during
# warmup or a measured request. Sparse anchors keep pages from moving to the
# tomb heap during full GC. Their small, artificial live set is reported.
# The GC pause can cross ActiveRecord's idle threshold. Settle only requests,
# symmetrically before N=0/N=50 endpoints; operation workers own captured context.
settle = -> { counted_requests(1, session, verb, path, headers) }
anchors = HeapWindows.run(windows, observe: observe, settle: settle, warmup: warmup,
  idle_connections: idle_connections) do |count|
  if trace
    verify_paths = 0
    trace.enable(target: body) { counted_requests(count, session, verb, path, headers) }
  else
    counted_requests(count, session, verb, path, headers)
  end
  census[:counts] << (trace ? verify_paths : 0) if census
end
ar_installed = 0
if defined?(Lowrail::ARInstantiate)
  ar_installed = Lowrail.manifest.units.count do |unit|
    unit["pass"] == "active_record/instantiate" &&
      Object.const_get(unit.fetch("ar_instantiate").fetch("model")).instance_variable_defined?(:@_lowrail_instantiate)
  end
end
puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION, windows: windows,
  lowrail_jit: defined?(Lowrail) && Lowrail.respond_to?(:jit_status) ? Lowrail.jit_status : nil,
  heap_anchors: anchors, ar_installed: ar_installed, jit_warmup: jit_warmup, request_settle: true,
  idle_census: census,
  compiled_iseqs: RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_iseq_count] : 0)}"
