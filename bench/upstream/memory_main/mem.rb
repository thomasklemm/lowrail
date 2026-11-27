# frozen_string_literal: true

# Retained memory of one census app process, run by run.rb inside a census copy:
#   bundle exec ruby [--zjit] mem.rb APP OUT.jsonl [DUMP_DIR]
# Boots in production through the census harness (eager loading as the app
# configures it), then snapshots after full GCs: at boot, after MEM_FIRST
# (1,000) requests and after MEM_LAST (5,000). Requests cycle through the app's
# census request workloads (jobs and mailers left out), minus the ones MEM_SKIP
# names ("|"-separated). Each snapshot is written as one JSON line at once, so
# the measurement keeps nothing alive between snapshots.
#
# Plain runs (no DUMP_DIR) take RSS and the cheap whole-heap counts only.
# Detail runs (DUMP_DIR) start allocation tracing before boot, add live bytes by
# class and duplicated Strings, and write ObjectSpace.dump_all per snapshot for
# dump.rb; tracing and the walks make the process bigger, so their RSS is not used.
require "json"
require "objspace"

app, output, dump_dir = ARGV
raise "fresh output required" if File.exist?(output)
ObjectSpace.trace_object_allocations_start if dump_dir
require_relative "../census/harness"

module MemoryRun
  KERNEL_CLASS = Kernel.instance_method(:class)
  MODULE_NAME = Module.instance_method(:name)
  module_function

  def proc_kb
    fields = {}
    File.read("/proc/self/status").scan(/^(VmRSS|RssAnon|RssFile|VmHWM):\s+(\d+) kB/) { fields[$1] = $2.to_i }
    File.read("/proc/self/smaps_rollup").scan(/^(Pss_Anon|Private_Dirty):\s+(\d+) kB/) { fields[$1] = $2.to_i }
    fields
  end

  def full_gc = 3.times { GC.start(full_mark: true, immediate_sweep: true) }

  def jit_stats
    return nil unless defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    RubyVM::ZJIT.stats.select { |_, v| v.is_a?(Numeric) }
  rescue StandardError => e
    { error: e.message }
  end

  def class_name(klass) = (klass && MODULE_NAME.bind_call(klass)) || "(anonymous)"

  # Live heap by class (non-internal objects: imemo and nodes are only in
  # count_objects_size), and Strings with identical contents.
  def by_class
    counts = Hash.new(0)
    bytes = Hash.new(0)
    strings = {}
    ObjectSpace.each_object do |object|
      klass = KERNEL_CLASS.bind_call(object)
      size = ObjectSpace.memsize_of(object)
      name = class_name(klass)
      counts[name] += 1
      bytes[name] += size
      next unless klass == String
      entry = (strings[[object.hash, object.bytesize]] ||= [object, 0, 0, 0])
      entry[1] += 1
      entry[2] += size
      entry[3] += 1 if object.frozen?
    end
    dups = strings.values.select { _1[1] > 1 }
    top = dups.sort_by { |_, n, size, _| -(size - size / n) }.first(60).map do |sample, n, size, frozen|
      { sample: sample.byteslice(0, 80).inspect, bytesize: sample.bytesize, copies: n, frozen: frozen, bytes: size,
        wasted: size - size / n }
    end
    { classes: bytes.sort_by { -_2 }.first(400).to_h { |name, b| [name, [counts[name], b]] },
      strings: { count: strings.values.sum { _1[1] }, distinct: strings.size, duplicated_groups: dups.size,
        wasted_bytes: dups.sum { |_, n, size, _| size - size / n }, top: top } }
  end

  def snapshot(label, requests, dump_dir)
    rss_before_gc = proc_kb
    full_gc
    snap = { label: label, requests: requests, rss_before_gc_kb: rss_before_gc, rss_kb: proc_kb,
      gc: GC.stat, gc_heap: GC.stat_heap, count_objects: ObjectSpace.count_objects,
      count_objects_size: ObjectSpace.count_objects_size, memsize_of_all: ObjectSpace.memsize_of_all,
      imemo: ObjectSpace.count_imemo_objects, symbols: ObjectSpace.count_symbols, jit: jit_stats,
      loaded_features: $LOADED_FEATURES.size }
    if dump_dir
      snap.merge!(by_class)
      snap[:tdata] = ObjectSpace.count_tdata_objects.each_with_object(Hash.new(0)) { |(k, v), h| h[k.is_a?(Module) ? class_name(k) : k.to_s] += v }
      path = File.join(dump_dir, "#{label}.json")
      full_gc
      File.open(path, "w") { ObjectSpace.dump_all(output: _1) }
      snap[:dump] = { path: File.basename(path), gc_count: GC.count }
    end
    snap
  end
end

log = File.open(output, "w")
write = ->(row) { log.puts(JSON.generate(row)); log.flush }
RailsCensus.boot(app)
raise "eager_load is off" unless Rails.application.config.eager_load
first = Integer(ENV.fetch("MEM_FIRST", "1000"))
last = Integer(ENV.fetch("MEM_LAST", "5000"))
sample_every = Integer(ENV.fetch("MEM_SAMPLE", "250"))
write.call(snapshot: MemoryRun.snapshot("boot", 0, dump_dir))
skip = ENV.fetch("MEM_SKIP", "").split("|")
ops = RailsCensus.workloads(app).reject { %i[job mailer].include?(_1.kind) || skip.include?(_1.name) }
raise "no request workloads" if ops.empty?
write.call(meta: { app: app, ruby: RUBY_DESCRIPTION, mode: RailsCensus.mode, rails: RailsCensus.rails_sha,
  rails_version: Rails.version, traced: !dump_dir.nil?, pid: Process.pid, workloads: ops.map(&:name), skipped: skip })
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
(1..last).each do |i|
  ops[(i - 1) % ops.size].call.call
  RailsCensus.reset_side_effects
  write.call(sample: [i, MemoryRun.proc_kb["VmRSS"], GC.stat(:heap_live_slots), GC.count]) if (i % sample_every).zero?
  write.call(snapshot: MemoryRun.snapshot("r#{i}", i, dump_dir)) if i == first || i == last
end
write.call(done: { requests_seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1) })
