# frozen_string_literal: true

# Separate diagnostic workers: ObjectSpace enumeration must not change the
# heaps of the primary instruction/time workers. See request_pairs.rb.
require "objspace"

module RequestMemory
  # Count only data containers, not their classes or arbitrary object edges
  # (which would reach nearly the entire Rails heap). Shared/cyclic containers
  # count once. Weak referents are deliberately not traversed.
  def self.containers(roots)
    seen = {}.compare_by_identity
    stack = roots.dup
    bytes = 0
    types = Hash.new(0)
    until stack.empty?
      obj = stack.pop
      next if seen.key?(obj)
      case obj
      when Hash
        obj.each_pair { |key, value| stack << key << value }
      when Array
        obj.each { stack << _1 }
      when String, ObjectSpace::WeakMap, ObjectSpace::WeakKeyMap
        # No strong Ruby container edges to follow here.
      else
        next
      end
      seen[obj] = true
      bytes += ObjectSpace.memsize_of(obj)
      types[obj.class.name] += 1
    end
    { bytes: bytes, objects: types }
  end

  def self.lowrail_data
    return {} unless defined?(Lowrail)
    result = {}
    if (manifest = Lowrail.manifest)
      result["manifest"] = containers(manifest.instance_variables.map { manifest.instance_variable_get(_1) })
      result["manifest"][:object_bytes] = ObjectSpace.memsize_of(manifest)
      result["facts"] = containers(manifest.units.map { _1["facts"] })
      result["template_entries"] = containers([manifest.templates])
    end
    result["receiver_caches"] = containers([Lowrail::V])
    %i[Guard Compilation ARInstantiate AR].each do |name|
      next unless Lowrail.const_defined?(name, false)
      mod = Lowrail.const_get(name, false)
      result[name.to_s] = mod.instance_variables.to_h do |ivar|
        value = mod.instance_variable_get(ivar)
        [ivar, { class: value.class.name, shallow_bytes: ObjectSpace.memsize_of(value),
          containers: containers([value]) }]
      end
    end
    result
  end

  def self.snapshot
    GC.start
    # First collect whole-heap sizes, before allocating attribution reports.
    sizes = ObjectSpace.count_objects_size
    total = ObjectSpace.memsize_of_all
    imemos = ObjectSpace.count_imemo_objects
    wrappers = ObjectSpace.each_object(RubyVM::InstructionSequence).count
    { memsize_of_all: total, count_objects_size: sizes, imemo_counts: imemos,
      iseq_wrappers: wrappers, gc: GC.stat, lowrail_data: lowrail_data }
  end
end

if $PROGRAM_NAME == __FILE__
  if ENV.fetch("BENCH_JIT", "0") != "1"
    require File.expand_path("config/application", Dir.pwd)
    Rails.application.config.yjit = false
  end
  require File.expand_path("config/environment", Dir.pwd)
  require "rack/mock"
  require "json" # after Bundler: corpus apps pin different default-gem versions
  Rails.application.eager_load!
  Rails.logger.level = :warn
  ActiveRecord::Base.logger = nil
  abort "usage: gc_requests.rb VERB:PATH" unless ARGV.size == 1
  verb, path = ARGV.first.split(":", 2)
  session = Rack::MockRequest.new(Rails.application)
  headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
  n = Integer(ENV.fetch("BENCH_REQUESTS", "200"))
  warmup = Integer(ENV.fetch("BENCH_WARMUP", "50"))
  raise "nonnegative requests/warmup required" if n.negative? || warmup.negative?

  def diagnostic_requests(n, session, verb, path, headers)
    n.times do
      response = session.request(verb, path, headers)
      raise "#{verb} #{path} -> #{response.status}" unless (200..299).cover?(response.status)
    end
  end

  def report_snapshot(stage)
    puts "LOWRAIL_MEMORY #{JSON.generate(stage: stage, snapshot: RequestMemory.snapshot)}"
  end

  mode = ENV.fetch("BENCH_GC_MODE")
  raise "expected memory or window mode" unless %w[memory window].include?(mode)
  report_snapshot("boot") if mode == "memory"
  diagnostic_requests(warmup, session, verb, path, headers)
  if mode == "memory"
    report_snapshot("warm")
    if (dump = ENV["BENCH_HEAP_DUMP"])
      GC.start
      File.open(dump, "w", 0o600) { ObjectSpace.dump_all(output: _1) }
    end
  else
    # Populate both hashes before GC so observing the endpoints doesn't
    # allocate a new Hash (or grow one) in the measured window.
    before, after = {}, {}
    GC.stat(before)
    GC.stat(after)
    GC.start
    GC.stat(before)
    diagnostic_requests(n, session, verb, path, headers)
    GC.stat(after)
    delta = after.to_h { |key, value| [key, value - before.fetch(key)] }
    puts "LOWRAIL_MEMORY #{JSON.generate(stage: "window", requests: n, before: before, after: after, delta: delta)}"
  end
  puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?, mode: mode)}"
end
