# frozen_string_literal: true
# byroot's heap-report harness (byroot/ruby-bench heap-harness bf1afb2) plus a
# machine-readable summary: totals, all spills, and every object allocated in
# active_support/core_ext/enumerable.rb, by line, type, embedded/spilled.
require_relative "../harness-heap-report/harness"
# json is required lazily by heap_report, after Bundler.setup

module HeapHarness
  alias_method :byroot_heap_report, :heap_report

  def heap_report(file)
    byroot_heap_report(file)
    file.rewind
    ideal = 9.times.to_h { |size| [size, ObjectSpace.memsize_of(size.times.to_h { |i| [i, i] }.dup)] }
    s = Hash.new(0)
    enum = Hash.new(0)
    file.each_line do |line|
      next if line.include?('"type":"shape"')
      obj = JSON.parse(line)
      slot = obj["slot_size"] or next
      mem = obj["memsize"]
      s[:objects] += 1
      s[:heap_bytes] += slot
      s[:malloc_bytes] += mem - slot
      if obj["type"] == "HASH"
        s[:hashes] += 1
        if obj["size"] <= 8 && mem > slot
          s[:early_evictions] += 1
          s[:early_eviction_bytes] += mem - ideal[obj["size"]]
        end
      end
      if obj["file"]&.end_with?("active_support/core_ext/enumerable.rb")
        k = "#{obj["line"]} #{obj["type"]}#{obj["type"] == "HASH" ? " size#{obj["size"] <= 8 ? "<=8" : ">8"} #{mem > slot ? "spilled" : "embedded"}" : ""}"
        enum[k] += 1
        enum["#{k} bytes"] += mem
      end
    end
    out = ENV.fetch("IW_OUT", "/tmp/iw-summary.json")
    File.write(out, JSON.pretty_generate(ruby: RUBY_DESCRIPTION, yjit: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?, totals: s, enumerable_rb: enum.sort.to_h))
    puts "summary -> #{out}"
  end
end
