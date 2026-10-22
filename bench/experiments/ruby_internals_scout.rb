# frozen_string_literal: true

# VM scout. No source rewrite, cache clearing, GC sizing or policy change.
# TracePoint is confined to disposable attribution/capture workers, never
# the profile, budget replay or wall workers. Lowrail is optional via RUBYOPT.
# Run from a prepared corpus app with its matching BUNDLE_GEMFILE.
require "json"
require "digest"
require "objspace"

app, mode, output = ARGV
abort "usage: ruby_internals_scout.rb blog|fizzy|lobsters profile|census|cgi|regexp|capture|budget|wall OUTPUT" unless
  %w[blog fizzy lobsters].include?(app) && %w[profile census cgi regexp capture budget wall].include?(mode) && output

require File.expand_path("config/application")
Rails.application.config.yjit = false unless RubyVM::YJIT.enabled?
require File.expand_path("config/environment")
raise "Rails 8.1.4 required" unless Rails.version == "8.1.4"
Rails.logger.level = :error
ActiveRecord::Base.logger = nil

if app == "lobsters"
  require "sqlite3"
  file = SQLite3::Database.new("db/production.sqlite3")
  backup = SQLite3::Backup.new(ActiveRecord::Base.connection.raw_connection, "main", file, "main")
  backup.step(-1)
  backup.finish
  file.close
end

require "rack/mock"
route = {"blog" => "/articles/1", "fizzy" => "/buckets", "lobsters" => "/s/enr7ye"}.fetch(app)
headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "ruby-internals-scout",
  "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0"}
headers.merge!(JSON.parse(File.read(ENV.fetch("SCOUT_HEADERS")))) if app == "fizzy"
session = Rack::MockRequest.new(Rails.application)
request = -> do
  response = session.get(route, headers)
  raise "#{route}: HTTP #{response.status}" unless response.status == 200
  response
end
warmup = Integer(ENV.fetch("SCOUT_WARMUP", "2000"))
warmup.times { request.call }
GC.start

jit = -> { RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count,
  :compiled_block_count, :invalidation_count, :code_gc_count) : {} }
result = {app: app, route: route, ruby: RUBY_DESCRIPTION, rails: Rails.version,
  yjit: RubyVM::YJIT.enabled?, warmup: warmup, mode: mode, vm_before: RubyVM.stat,
  jit_before: jit.call, gc_before: GC.stat}

case mode
when "profile"
  n = Integer(ENV.fetch("SCOUT_N", "5000"))
  control = ENV["SCOUT_PERF_CONTROL"] && File.open(ENV.fetch("SCOUT_PERF_CONTROL"), "w")
  ack = control && File.open(ENV.fetch("SCOUT_PERF_ACK"), "r")
  control&.puts("enable"); control&.flush; ack&.gets
  allocations = GC.stat(:total_allocated_objects)
  cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  n.times { request.call }
  result[:wall_us] = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall) * 1e6 / n
  result[:cpu_us] = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu) * 1e6 / n
  result[:objects] = (GC.stat(:total_allocated_objects) - allocations).fdiv(n)
  control&.puts("disable"); control&.flush; ack&.gets
  control&.close; ack&.close
  result[:requests] = n
when "census"
  # A distinct untimed process: trace allocation metadata and retain the
  # transient request objects too. This is not the CPU/timing configuration.
  ObjectSpace.trace_object_allocations_start
  GC.start
  generation = GC.count
  GC.disable
  allocations = GC.stat(:total_allocated_objects)
  response = request.call
  result[:objects] = GC.stat(:total_allocated_objects) - allocations
  ObjectSpace.trace_object_allocations_stop
  sites = Hash.new(0)
  models = Hash.new { |h, k| h[k] = {objects: 0, complex: 0, shapes: Hash.new(0), orders: Hash.new(0)} }
  ObjectSpace.each_object do |object|
    next unless ObjectSpace.allocation_generation(object) == generation
    source = ObjectSpace.allocation_sourcefile(object)
    next unless source && source != __FILE__
    line = ObjectSpace.allocation_sourceline(object)
    sites[[object.class.name, source, line]] += 1
    next unless ActiveRecord::Base === object
    dump = JSON.parse(ObjectSpace.dump(object))
    model = models[object.class.name]
    model[:objects] += 1
    model[:complex] += 1 if dump["too_complex_shape"]
    model[:shapes][dump.fetch("shape_id")] += 1
    model[:orders][object.instance_variables.join(",")] += 1
  end
  result[:sites] = sites.sort_by { |_, count| -count }.map { |(klass, path, line), count|
    {class: klass, path: path.sub(Dir.pwd + "/", "APP/"), line: line, objects: count} }
  result[:models] = models
  result[:response] = {status: response.status, bytes: response.body.bytesize,
    body_sha256: Digest::SHA256.hexdigest(response.body)}
  GC.enable
  ObjectSpace.trace_object_allocations_clear
when "cgi"
  # Untimed attribution, including aliases and instance/module uses. Never
  # export input bytes: length/encoding/safe-byte status suffice for this screen.
  require "cgi/escape"
  sites = Hash.new(0)
  wrapper = Module.new
  %i[escapeHTML escape_html h].each do |name|
    wrapper.define_method(name) do |value|
      caller = caller_locations(1, 1).first
      descriptor = String === value ? [value.bytesize, value.encoding.name,
        !value.b.match?(/[<&'">]/)] : [value.class.name]
      sites[[name, caller.path, caller.lineno, descriptor]] += 1
      super(value)
    end
  end
  CGI::EscapeExt.prepend(wrapper)
  count = 0
  trace = TracePoint.new(:c_call) do |event|
    count += 1 if event.defined_class == CGI::EscapeExt && event.method_id == :escapeHTML
  end
  trace.enable { 10.times { request.call } }
  result[:requests] = 10
  result[:rack] = Rack.release
  result[:cgi_c_calls] = count
  result[:cgi_sites] = sites.to_a
  count = 0
  trace.enable { CGI.escapeHTML("a" * 200); CGI.escapeHTML("a" * 199 + "<") }
  result[:positive_control_c_calls] = count
  raise "missed CGI controls" unless count == 2
when "regexp"
  # Untimed, disposable diagnostic worker only. c_call observes the actual
  # primitive and its Ruby callsite without wrapping backreference-sensitive
  # Regexp#match/=~ or String#gsub methods.
  counts = Hash.new(0)
  inputs = Hash.new { |h, k| h[k] = Hash.new(0) }
  trace = TracePoint.new(:call, :c_call) do |event|
    if event.event == :call && ((%i[blank? html_safe].include?(event.method_id) && String === event.self) ||
        %i[xml_name_escape tag_option ensure_valid_html5_tag_name].include?(event.method_id))
      binding = event.binding
      value = %i[blank? html_safe].include?(event.method_id) ? event.self :
        binding.local_variable_get(event.method_id == :tag_option ? :key : :name)
      # Digests, not request values; the caller site and fixed source determine
      # foldability. Repeating a digest on one fixture is not a constant proof.
      descriptor = [value.class.name, value.frozen?, value.is_a?(String) ? value.bytesize : nil,
        (String === value || Symbol === value) ? Digest::SHA256.hexdigest(value.to_s) : nil]
      caller = caller_locations(1, 6).map { [_1.path, _1.lineno, _1.base_label] }
      inputs[[event.method_id, caller]][descriptor] += 1
    elsif event.event == :c_call && Regexp === event.self && %i[match? match =~ ===].include?(event.method_id)
      counts[[event.path, event.lineno, event.method_id, event.self.source, event.self.options]] += 1
    elsif event.event == :c_call && String === event.self && %i[match? match =~ gsub gsub! sub sub! scan split].include?(event.method_id)
      counts[[event.path, event.lineno, "String##{event.method_id}", nil, nil]] += 1
    end
  end
  3.times { trace.enable { request.call } }
  result[:regexp_calls] = counts.sort_by { |_, count| -count }.map { |(path, line, method, pattern, options), count|
    {path: path.sub(Dir.pwd + "/", "APP/"), line: line, method: method,
      pattern: pattern, options: options, calls: count, per_request: count.fdiv(3)} }
  result[:input_calls] = inputs.map { |(method, callers), values|
    {method: method, callers: callers, inputs: values.map { |descriptor, count| {descriptor: descriptor, calls: count} }} }
  result[:global_regexp_timeout] = Regexp.timeout
when "capture"
  # Never time this worker: TracePoint changes YJIT state even after disable.
  # This private Marshal is replayed only by this experiment in a fresh worker.
  bundles = Hash.new { |h, k| h[k] = [] }
  trace = TracePoint.new(:call) do |event|
    receiver = event.self
    case event.method_id
    when :blank?
      bundles[:blank] << [receiver, receiver.frozen?] if String === receiver
    when :xml_name_escape
      name = event.binding.local_variable_get(:name)
      bundles[:xml] << [name, name.frozen?]
    when :ensure_valid_html5_tag_name
      name = event.binding.local_variable_get(:name)
      bundles[:tag_name] << [name, name.frozen?]
    when :html_safe
      bundles[:html_safe] << [receiver, receiver.frozen?] if String === receiver
    end
  end
  trace.enable { request.call }
  bundles.default_proc = nil
  File.binwrite(ENV.fetch("SCOUT_INPUTS"), Marshal.dump(bundles))
  result[:calls_per_request] = bundles.transform_values(&:size)
when "budget"
  # Inclusive operation replay estimates, not removal prices. XML includes
  # its blank? call; html_safe includes SafeBuffer#initialize. Never add them.
  # Only load trusted local captures written by the capture mode above.
  bundles = Marshal.load(File.binread(ENV.fetch("SCOUT_INPUTS"))).transform_values do |values|
    values.map { |value, frozen| frozen ? value.freeze : value }
  end
  measure = ->(n, call) do
    GC.start
    a = GC.stat(:total_allocated_objects)
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { call.call }
    {cpu_us: (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu) * 1e6 / n,
      wall_us: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall) * 1e6 / n,
      objects: (GC.stat(:total_allocated_objects) - a).fdiv(n)}
  end
  result[:request_controls] = 3.times.map { measure.call(300, request) }
  result[:bundles] = bundles.to_h do |name, values|
    calls = values.map do |value|
      case name
      when :blank then -> { value.blank? }
      when :xml then -> { ERB::Util.xml_name_escape(value) }
      when :tag_name then -> { ActionView::Helpers::TagHelper.ensure_valid_html5_tag_name(value) }
      when :html_safe then -> { value.html_safe }
      end
    end
    empty = Array.new(calls.size) { -> {} }
    original = -> { calls.each(&:call) }
    overhead = -> { empty.each(&:call) }
    300.times { original.call; overhead.call }
    samples = 7.times.map do |round|
      order = round.even? ? [[:empty_a, overhead], [:original, original], [:empty_b, overhead]] :
        [[:empty_b, overhead], [:original, original], [:empty_a, overhead]]
      order.to_h { |label, call| [label, measure.call(2000, call)] }
    end
    [name, {calls_per_request: calls.size, samples: samples}]
  end
  result[:global_regexp_timeout] = Regexp.timeout
when "wall"
  # Fresh-process A/A controls, not a precision benchmark. Keep all windows.
  result[:windows] = Array.new(12) do
    n = Integer(ENV.fetch("SCOUT_N", "300"))
    a = GC.stat(:total_allocated_objects)
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { request.call }
    {wall_us: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e6 / n,
      objects: (GC.stat(:total_allocated_objects) - a).fdiv(n)}
  end
end
result.merge!(vm_after: RubyVM.stat, jit_after: jit.call, gc_after: GC.stat)
if defined?(Lowrail::FormScaffold)
  result[:form_admission] = Lowrail::FormScaffold.admission
  result[:form_refusal] = Lowrail::FormScaffold.refusal
  result[:form_input_refusal] = Lowrail::FormScaffold.input_refusal
end
result[:hits] = Lowrail::Stats.unit_hits if defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
File.write(output, JSON.pretty_generate(result))
puts JSON.generate(result.except(:sites, :models, :windows, :regexp_calls, :input_calls))
