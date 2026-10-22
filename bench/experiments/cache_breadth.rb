# frozen_string_literal: true

# Off-only allocation census. SETUP supplies CacheBreadthWorkload.routes, a
# Hash of route => zero-argument Rack request. It may prepare disposable data,
# but must not replace the app's cache/config/methods. Outputs contain hashes
# and counts, never cached values, response bodies or credentials.
require "bundler/setup"
require "json"
require "digest"
require "objspace"

app, setup, output = ARGV.map { File.expand_path(_1) }
abort "usage: cache_breadth.rb APP SETUP NEW_JSON" unless output && !File.exist?(output)
abort "off-only census" unless ENV["LOWRAIL"] == "0"
require setup
raise "production Rails 8.1.4 required" unless Rails.env.production? && Rails.version == "8.1.4"
Rails.logger.level = :error
ActiveRecord::Base.logger = nil

module CacheBreadthCensus
  class << self
    attr_accessor :active, :loads, :coders, :events, :thread
    attr_accessor :depth, :allocated, :operations

    def observing?
      active && Thread.current.equal?(thread)
    end

    # Same allocated-only reachability definition as bet M: do not traverse
    # preexisting classes/global framework graphs. GC stays disabled.
    def retained(root, allocated)
      seen = {}.compare_by_identity
      pending = [root]
      until pending.empty?
        object = pending.pop
        next unless (allocated.key?(object) || object.equal?(root)) && !seen.key?(object)
        seen[object] = true
        ObjectSpace.reachable_objects_from(object)&.each do |child|
          pending << child if allocated.key?(child)
        end
      end
      seen
    end
  end

  module MarshalLoad
    def load(source, ...)
      return super unless CacheBreadthCensus.observing?
      callers = caller_locations.map { "#{_1.path}:#{_1.lineno}:#{_1.label}" }
      ObjectSpace.trace_object_allocations_clear
      ObjectSpace.trace_object_allocations_start
      result = super
      ObjectSpace.trace_object_allocations_stop
      allocated = {}.compare_by_identity
      ObjectSpace.each_object do |object|
        file = ObjectSpace.allocation_sourcefile(object)
        next unless file
        allocated[object] = [file, ObjectSpace.allocation_sourceline(object), object.class.name]
      end
      retained = CacheBreadthCensus.retained(result, allocated)
      rows = Hash.new(0)
      allocated.each do |object, site|
        rows[[*site, retained.key?(object) ? "result_graph" : "intermediate"]] += 1
      end
      CacheBreadthCensus.loads << {
        cache_stack: callers.any? { _1.include?("/active_support/cache/") },
        callers: callers, result_class: result.class.name,
        payload_bytes: (source.bytesize if source.is_a?(String)),
        payload_sha256: (Digest::SHA256.hexdigest(source) if source.is_a?(String)),
        rows: rows.map { |(file, line, klass, role), count|
          {file: file, line: line, class: klass, role: role, objects: count}
        }.sort_by { [-_1[:objects], _1[:file], _1[:class]] }
      }
      CacheBreadthCensus.allocated&.merge!(allocated)
      result
    ensure
      if CacheBreadthCensus.observing?
        ObjectSpace.trace_object_allocations_stop
        ObjectSpace.trace_object_allocations_clear
      end
    end
  end

  module CacheResult
    %i[read read_multi fetch fetch_multi].each do |name|
      define_method(name) do |*args, **kwargs, &block|
        return super(*args, **kwargs, &block) unless CacheBreadthCensus.observing?
        outer = CacheBreadthCensus.depth.zero?
        CacheBreadthCensus.allocated = {}.compare_by_identity if outer
        CacheBreadthCensus.depth += 1
        result = super(*args, **kwargs, &block)
        if outer
          allocated = CacheBreadthCensus.allocated
          retained = CacheBreadthCensus.retained(result, allocated)
          marshal = allocated.select { |_, site| site.first == "<internal:marshal>" }
          CacheBreadthCensus.operations << {operation: name, marshal_objects: marshal.size,
            caller_graph_objects: marshal.keys.count { retained.key?(_1) },
            intermediates: marshal.keys.count { !retained.key?(_1) }}
        end
        result
      ensure
        if CacheBreadthCensus.observing?
          CacheBreadthCensus.depth -= 1
          CacheBreadthCensus.allocated = nil if outer
        end
      end
    end
  end

  module CoderLoad
    def load(payload)
      if CacheBreadthCensus.observing?
        kind = if payload.is_a?(String) && payload.start_with?("\x00\x11".b)
          {1 => "object", 2 => "UTF-8 String", 3 => "binary String", 4 => "US-ASCII String"}.
            fetch(payload.getbyte(2) & 0x7f, "unknown")
        else
          "legacy/other"
        end
        CacheBreadthCensus.coders[kind] += 1
      end
      super
    end
  end
end

Marshal.singleton_class.prepend(CacheBreadthCensus::MarshalLoad)
ActiveSupport::Cache::Coder.prepend(CacheBreadthCensus::CoderLoad)
ActiveSupport::Cache::Store.prepend(CacheBreadthCensus::CacheResult)
CacheBreadthCensus.thread = Thread.current
subscription = ActiveSupport::Notifications.subscribe(/\Acache_.*\.active_support\z/) do |name, *, payload|
  next unless CacheBreadthCensus.observing?
  # Retain key identity without publishing application data.
  CacheBreadthCensus.events << {name: name, key_sha256: Digest::SHA256.hexdigest(payload[:key].to_s),
    hit: payload[:hit], hits: payload[:hits]&.size, super_operation: payload[:super_operation]}
end

source_files = Dir[File.join(app, "{app,config,lib}/**/*")].select { File.file?(_1) }.sort
source_pin = -> { Digest::SHA256.hexdigest(source_files.map { |path|
  [path.delete_prefix(app + "/"), Digest::SHA256.file(path).hexdigest].join("\0")
}.join("\n")) }
before_pin = source_pin.call
report = {kind: "off-only discovery, not support or speed evidence", ruby: RUBY_DESCRIPTION,
  rails: Rails.version, yjit: RubyVM::YJIT.enabled?, store: Rails.cache.class.name,
  coder: Rails.cache.instance_variable_get(:@coder).class.name,
  cache_format: ActiveSupport::Cache.format_version,
  lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
  source_sha256: before_pin, setup_sha256: Digest::SHA256.file(setup).hexdigest,
  census_sha256: Digest::SHA256.file(__FILE__).hexdigest, routes: {}}
CacheBreadthWorkload.routes.each do |route, request|
  25.times do
    response = request.call
    raise "#{route}: HTTP #{response.status}, location=#{response.headers['location']}, title=#{response.body[/<title>(.*?)<\/title>/m, 1]}" unless response.status == 200
  end
  GC.start
  GC.disable
  begin
    samples = 3.times.map do
      CacheBreadthCensus.loads = []
      CacheBreadthCensus.coders = Hash.new(0)
      CacheBreadthCensus.events = []
      CacheBreadthCensus.operations = []
      CacheBreadthCensus.depth = 0
      CacheBreadthCensus.active = true
      response = request.call
      CacheBreadthCensus.active = false
      raise "#{route}: HTTP #{response.status}" unless response.status == 200
      cache_loads = CacheBreadthCensus.loads.select { _1[:cache_stack] }
      marshal_rows = cache_loads.flat_map { _1[:rows] }.select { _1[:file] == "<internal:marshal>" }
      {status: response.status, body_bytes: response.body.bytesize,
        body_sha256: Digest::SHA256.hexdigest(response.body),
        cache_marshal_calls: cache_loads.size,
        cache_marshal_objects: marshal_rows.sum { _1[:objects] },
        cache_marshal_intermediates: marshal_rows.select { _1[:role] == "intermediate" }.sum { _1[:objects] },
        cache_operations: CacheBreadthCensus.operations,
        coders: CacheBreadthCensus.coders, events: CacheBreadthCensus.events, loads: CacheBreadthCensus.loads}
    end
    report[:routes][route] = samples
  ensure
    CacheBreadthCensus.active = false
    GC.enable
  end
end
raise "app source changed" unless before_pin == source_pin.call
ActiveSupport::Notifications.unsubscribe(subscription)
File.write(output, JSON.pretty_generate(report), perm: 0o600)
puts JSON.generate(report.except(:routes).merge(routes: report[:routes].transform_values {
  _1.map { |sample| sample.slice(:cache_marshal_calls, :cache_marshal_objects, :cache_marshal_intermediates, :coders) }
}))
