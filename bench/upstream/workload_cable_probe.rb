# frozen_string_literal: true

# Untimed call-path and existing cache-contract probes; no optimization patch.
require_relative "workload_census"

name, output = ARGV
raise "fresh output required" if File.exist?(output)
WorkloadCensus.boot(name)
operations = WorkloadCensus.workloads(name)
operation = operations.fetch(name == "fizzy" ? "Cable/JSON+broadcast+solid_cable" : "solid_cable/synchronous-persist")
10.times { operation.call }
paths = Hash.new(0)
counts = []
trace = TracePoint.new(:call) do |event|
  if event.method_id == :config_for
    counts.last["config_for"] += 1
    paths[caller_locations(2, 5).map(&:label).join(" <- ")] += 1
  elsif event.method_id == :parse && event.defined_class == ActiveSupport::ConfigurationFile
    counts.last["yaml_parse"] += 1
  end
end
50.times do
  counts << { "config_for" => 0, "yaml_parse" => 0 }
  trace.enable { operation.call }
end
accessors = {}
%i[polling_interval silence_polling? message_retention autotrim? trim_batch_size].each do |method|
  counts << { "config_for" => 0, "yaml_parse" => 0 }
  trace.enable { SolidCable.public_send(method) }
  accessors[method] = counts.pop
end

require "timeout"
pubsub = ActionCable.server.pubsub
listener_class = ActionCable::SubscriptionAdapter::SolidCable.const_get(:Listener)
interval_owner = SolidCable.method(:polling_interval).owner
pending_polls = {}
completed_polls = Queue.new
poll_trace = TracePoint.new(:call, :return) do |event|
  thread = Thread.current
  if event.event == :call && event.method_id == :with_polling_volume && event.defined_class == listener_class
    pending_polls[thread] = { "config_for" => 0, "yaml_parse" => 0 }
  elsif (sample = pending_polls[thread])
    if event.event == :call && event.method_id == :config_for
      sample["config_for"] += 1
    elsif event.event == :call && event.method_id == :parse && event.defined_class == ActiveSupport::ConfigurationFile
      sample["yaml_parse"] += 1
    elsif event.event == :return && event.method_id == :polling_interval && event.defined_class == interval_owner
      completed_polls << pending_polls.delete(thread)
    end
  end
end
callback = ->(*) {}
begin
  poll_trace.enable
  pubsub.subscribe("u3-config-poll-probe", callback, -> {})
  polls = Timeout.timeout(10) { Array.new(8) { completed_polls.pop } }
ensure
  poll_trace.disable
  pubsub.unsubscribe("u3-config-poll-probe", callback)
  pubsub.shutdown
end

contracts = nil
if SolidCable.respond_to?(:reset_configuration!)
  # Exercise the already-shipped 4.1 cache boundary, not a hypothetical new one.
  # A mutable config source models config_for returning newly parsed YAML.
  reads = 0
  options = { polling_interval: "0.25.seconds", connects_to: { database: { writing: "cable" } } }
  Rails.application.define_singleton_method(:config_for) { |*| reads += 1; options }
  begin
    SolidCable.reset_configuration!
    first = SolidCable.polling_interval
    options = { polling_interval: "0.5.seconds", connects_to: { database: { writing: "primary" } } }
    cached = SolidCable.polling_interval
    raise "cache unexpectedly reread configuration" unless first == cached && reads == 1
    SolidCable.reset_configuration!
    refreshed = SolidCable.polling_interval
    raise "reset did not reload" unless refreshed == 0.5.seconds && reads == 2
    raise "database override lost" unless SolidCable.connects_to == { database: { writing: :primary } }
    SolidCable.configure(polling_interval: "0.75.seconds", autotrim: false)
    raise "programmatic override lost" unless SolidCable.polling_interval == 0.75.seconds && !SolidCable.autotrim?
    values = 8.times.map { Thread.new { 100.times.map { SolidCable.polling_interval } } }.flat_map(&:value)
    raise "thread value mismatch" unless values.all? { _1 == 0.75.seconds }
    reader, writer = IO.pipe
    child = fork do
      reader.close
      inherited = SolidCable.polling_interval
      SolidCable.configure(polling_interval: "0.9.seconds")
      writer.write(JSON.generate(inherited: inherited.to_f, child: SolidCable.polling_interval.to_f))
      writer.close
      exit! 0
    end
    writer.close
    child_values = JSON.parse(reader.read)
    reader.close
    Process.wait(child)
    raise "fork probe failed" unless $?.success? && child_values == { "inherited" => 0.75, "child" => 0.9 }
    raise "child changed parent configuration" unless SolidCable.polling_interval == 0.75.seconds
    contracts = { cached_until_reset: true, reset_refreshes: true, database_override: true,
      programmatic_false: true, concurrent_read_values: values.size, fork: child_values, parent_after_fork: SolidCable.polling_interval.to_f }
  ensure
    Rails.application.singleton_class.remove_method(:config_for)
    SolidCable.reset_configuration!
  end
end

result = { app: name, ruby: RUBY_DESCRIPTION, solid_cable: Gem.loaded_specs.fetch("solid_cable").version.to_s,
  operation: name == "fizzy" ? "full synchronous Cable broadcast" : "direct synchronous persistence only; async writer excluded",
  calls_per_operation: counts.tally.map { |calls, frequency| calls.merge("operations" => frequency) },
  call_paths: paths, accessor_calls: accessors,
  real_listener_polls: polls.tally.map { |calls, frequency| calls.merge("iterations" => frequency) },
  existing_cache_contracts: contracts }
File.write(output, JSON.pretty_generate(result) + "\n")
puts JSON.pretty_generate(result)
