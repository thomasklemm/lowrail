# frozen_string_literal: true

# Untimed bet-J diagnosis, never a performance cohort. Raw ObjectSpace dumps
# stay in memory: export slot/type/site/counts, never object values/addresses.
require File.expand_path("config/boot", Dir.pwd) if ARGV.first == "--worker"
require "json"
require "objspace"
load File.expand_path("../../script/native-bench", __dir__)

module GcHeapSites
  module_function

  def census(generation: nil)
    was_disabled = GC.disable
    sites = Hash.new(0)
    ObjectSpace.each_object do |object|
      allocated = ObjectSpace.allocation_generation(object)
      next unless allocated && (!generation || allocated == generation)
      next if ObjectSpace.memsize_of(object) < 320
      record = JSON.parse(ObjectSpace.dump(object))
      next unless record["slot_size"] == 320
      file = ObjectSpace.allocation_sourcefile(object)&.sub(Rails.root.to_s + "/", "APP/")&.
        sub(%r{\A.*/gems/}, "GEM/")&.sub(NativeBench::ROOT + "/", "LOWRAIL/")
      sites[[file, ObjectSpace.allocation_sourceline(object),
        ObjectSpace.allocation_method_id(object)&.to_s, record["type"],
        record["embedded"], record["bytesize"], record["length"], record["memsize"]]] += 1
    end
    sites.sort_by { |key, count| [-count, key.to_s] }.map do |key, count|
      %w[file line method type embedded bytesize length memsize].zip(key).to_h.merge("count" => count)
    end
  ensure
    GC.enable unless was_disabled
  end

  def worker(config, arm, destination)
    ObjectSpace.trace_object_allocations_start
    require File.join(config.fetch("app"), "config/environment")
    require "rack/mock"
    raise "wrong runtime" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4" && RubyVM::YJIT.enabled?
    rack = Rack::MockRequest.new(Rails.application)
    headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_FORWARDED_PROTO" => "https",
      "HTTP_ACCEPT" => "text/html", "HTTP_ACCEPT_ENCODING" => "identity",
      "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0", "HTTP_X_REQUEST_ID" => "native-rps-fixture"}
    request = -> {
      response = rack.get(config.fetch("path"), headers)
      raise "HTTP #{response.status}" unless response.status == 200
      nil
    }
    500.times { request.call }
    ObjectSpace.trace_object_allocations_stop
    pre_gc = GC.stat_heap(3)
    ObjectSpace.trace_object_allocations_start
    3.times { GC.start }
    ObjectSpace.trace_object_allocations_stop
    post_gc = GC.stat_heap(3)
    boot_retained = census
    ObjectSpace.trace_object_allocations_clear

    raise "GC already disabled" if GC.disable
    before = GC.stat_heap(3)
    generation = GC.count
    ObjectSpace.trace_object_allocations_start
    20.times { request.call }
    ObjectSpace.trace_object_allocations_stop
    after = GC.stat_heap(3)
    allocated = census(generation: generation)
    # Keep FREEOBJ metadata current across collection, as allocations.rb does.
    ObjectSpace.trace_object_allocations_start
    GC.enable
    3.times { GC.start }
    ObjectSpace.trace_object_allocations_stop
    retained = census(generation: generation)
    ObjectSpace.trace_object_allocations_clear
    result = {"arm" => arm, "requests" => 20, "warmup" => 500,
      "ruby" => RUBY_DESCRIPTION, "rails" => Rails.version,
      "refusal" => Lowrail.refusal_reason,
      "stats_enabled" => !!(defined?(Lowrail::Stats) && Lowrail::Stats.enabled?),
      "admissions" => %w[FormScaffold TokenTag CollectionRender].to_h { |name|
        [name, Lowrail.const_get(name).admission] },
      "warm_pool_before_full_gc" => pre_gc, "warm_pool_after_full_gc" => post_gc,
      "boot_and_warm_retained_sites" => boot_retained,
      "request_pool_before" => before, "request_pool_after" => after,
      "request_allocated_sites" => allocated, "request_retained_sites" => retained}
    File.write(destination, JSON.pretty_generate(result), perm: 0o600)
  end
end

if ARGV.first == "--worker"
  _, config, arm, destination = ARGV
  GcHeapSites.worker(JSON.parse(File.read(config)), arm, destination)
else
  config_file, output = ARGV
  abort "usage: gc_heap_sites.rb CONFIG NEW_OUTPUT" unless config_file && output && ARGV.size == 2
  config = JSON.parse(File.read(config_file))
  output = File.expand_path(output)
  raise "new output required" if File.exist?(output)
  FileUtils.mkdir_p(output, mode: 0o700)
  %w[off_a on off_b].each do |arm|
    FileUtils.rm_rf(File.join(config.fetch("app"), "storage"))
    FileUtils.cp_r(config.fetch("seed"), File.join(config.fetch("app"), "storage"))
    FileUtils.rm_rf(File.join(config.fetch("app"), "tmp"))
    env = NativeBench.environment(config, config.fetch("seed")).merge(
      "LOWRAIL" => arm == "on" ? "1" : "0", "LOWRAIL_STATS" => nil)
    command = ["taskset", "-c", "0", RbConfig.ruby, "--yjit", "--disable-zjit",
      File.expand_path(__FILE__), "--worker", File.expand_path(config_file), arm, File.join(output, "#{arm}.json")]
    raise "worker failed: #{arm}" unless system(env, *command, chdir: config.fetch("app"),
      out: File.join(output, "#{arm}.log"), err: [:child, :out])
  end
end
