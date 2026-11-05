# frozen_string_literal: true

require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")
require_relative "../census8/cpu_harness"
require_relative "../../heap_windows"
require_relative "perf_window"

RubyVM::YJIT.singleton_class.undef_method(:enable) unless RubyVM::YJIT.enabled?

def run_benchmark(_hint, **, &block)
  RailsCensus.instance_variable_set(:@rails_dir, ENV.fetch("RAILS_PATH"))
  raise "wrong YJIT mode" unless RubyVM::YJIT.enabled? == (ENV.fetch("CENSUS_MODE") == "yjit")
  anchors = HeapWindows.prepare_heap
  pools = GC.stat_heap
  op = RailsCensus::Op.new(ENV.fetch("STACK_MAP_APP"), :benchmark, block)
  result = if ENV["STACK_MAP_COUNTER"] == "perf"
    StackMapPerf.measure(block)
  else
    require ENV.fetch("CENSUS_CPU_EXT")
    RailsCensus.cpu_measure(op, reset: false)
  end
  File.write(ENV.fetch("STACK_MAP_OUT"), JSON.generate(result.merge(ruby: RUBY_DESCRIPTION,
    yjit: RubyVM::YJIT.enabled?, pools: pools, anchors: anchors.size)) + "\n")
end
