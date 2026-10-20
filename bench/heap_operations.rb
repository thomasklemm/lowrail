# frozen_string_literal: true

# Every layer boots the same active build and captures the same real workload.
# Only the replay arm differs; counters/capture never run in measured windows.
# Lock gems before capture requires JSON/Prism, but install before application
# requires targeted gem methods (notably RailsVite::Manifest).
require_relative "jit_stability"
require File.expand_path("config/boot", Dir.pwd)
require_relative "operation_capture"
OperationCapture.install
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false unless JitStability.mode == "yjit"
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require_relative "heap_windows"
require_relative "pass_probe"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil if defined?(ActiveRecord::Base)
JitStability.assert_mode!
PassProbe.active!(ENV.fetch("BENCH_UNITS").split(",").map { Integer(_1) })

verb, path = ARGV.fetch(0).split(":", 2)
last_env = nil
session = Rack::MockRequest.new(->(env) { last_env = env; Rails.application.call(env) })
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
request = -> {
  response = session.request(verb, path, headers)
  raise "request failed: #{response.status}" unless (200..299).cover?(response.status)
}
Integer(ENV.fetch("BENCH_WARMUP", "50")).times { request.call }
OperationCapture.capture { request.call }
records = OperationCapture.records
OperationCapture.restore_context

if (unit = Lowrail.manifest.units.find { _1["pass"] == "inertia/config_bind" })
  controller = last_env.fetch("action_controller.instance")
  config = controller.class._inertia_configuration
  on = config.method(:bind_controller)
  off = on.super_method
  raise "config-bind variant inactive" unless on.owner == Lowrail::Passes::InertiaConfig::Variant && off
  # Both arms use Method#call, never charging bind_call only to the original.
  records[unit.fetch("id")] = [{ original: -> { off.call(controller) }, expression: -> { on.call(controller) },
    counted: -> { on.call(controller) } }]
end
raise "no replayable operations on this request" if records.empty?

equivalent = ->(a, b) {
  a.class == b.class && if defined?(InertiaRails::Configuration) && a.instance_of?(InertiaRails::Configuration)
    a.instance_variable_get(:@options) == b.instance_variable_get(:@options) &&
      !a.instance_variable_get(:@options).equal?(b.instance_variable_get(:@options))
  else
    a == b && (!a.respond_to?(:encoding) || a.encoding == b.encoding) &&
      (!a.respond_to?(:html_safe?) || a.html_safe? == b.html_safe?)
  end
}
metadata = records.to_h do |id, pairs|
  OperationCapture.restore_context(id)
  pairs.each do |pair|
    original, optimized = pair.fetch(:original).call, pair.fetch(:expression).call
    raise "operation replay differs: unit #{id}" unless equivalent.call(original, optimized) &&
      (!pair.key?(:actual) || equivalent.call(pair.fetch(:actual), optimized))
  end
  [id, { invocations_per_iteration: pairs.size }]
end
# Runtime memo/bind counters can be enabled without installing counting guard
# wrappers. Restore the flag before timing; no Stats.enable! or TracePoint.
stats_was_loaded = defined?(Lowrail::Stats)
require "lowrail/stats"
Lowrail::Stats.instance_variable_set(:@enabled, true)
Lowrail::Stats.reset_counts!
request.call
request_hits = Lowrail::Stats.unit_hits
request_fallbacks = Lowrail::Stats.unit_fallbacks
Lowrail::Stats.reset_counts!
records.each do |id, pairs|
  OperationCapture.restore_context(id)
  pairs.each { _1.fetch(:counted).call }
end
metadata.each do |id, entry|
  pass = Lowrail.manifest.units.find { _1.fetch("id") == id }.fetch("pass")
  runtime = %w[memo/uri_join memo/sha256 digest/file_memo inertia/config_bind].include?(pass)
  entry[:invocations_per_request] = pass == "inertia/config_bind" ?
    request_hits.fetch(id.to_s, 0) + request_fallbacks.fetch(id.to_s, 0) : entry.fetch(:invocations_per_iteration)
  entry[:completed_hits_per_iteration] = runtime ? Lowrail::Stats.unit_hits.fetch(id.to_s, 0) : OperationCapture.completions[id]
  entry[:completed_hits_per_request] = runtime ? request_hits.fetch(id.to_s, 0) : OperationCapture.request_completions[id]
end
Lowrail::Stats.instance_variable_set(:@enabled, false)
Lowrail.send(:remove_const, :Stats) unless stats_was_loaded
arm = ENV.fetch("BENCH_OPERATION_ARM") == "on" ? :expression : :original
operations = records.transform_values { |pairs| pairs.map { _1.fetch(arm) } }
operations.each do |id, calls|
  OperationCapture.restore_context(id)
  100.times { calls.each(&:call) }
end
n = Integer(ENV.fetch("BENCH_REQUESTS", "50"))
windows = HeapWindows.windows(n, operations.keys)
if JitStability.enabled?
  jit_warmup = JitStability.warm do |count|
    operations.each do |id, calls|
      OperationCapture.restore_context(id)
      count.times { calls.each(&:call) }
    end
  end
  observe = JitStability.method(:snapshot)
end
anchors = HeapWindows.run(windows, prepare: OperationCapture.method(:restore_context), observe: observe) do |count, id|
  calls = operations.fetch(id)
  count.times { calls.each(&:call) }
end
puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION, windows: windows,
  operations: metadata, heap_anchors: anchors, ar_installed: 0, jit_warmup: jit_warmup)}"
