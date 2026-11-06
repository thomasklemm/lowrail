# frozen_string_literal: true

require "minitest"
require "json"
require_relative "../../heap_windows"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")

Minitest.singleton_class.prepend(Module.new do
  def run_all_suites(reporter, options)
    anchors = HeapWindows.prepare_heap
    before = GC.stat_heap.transform_values { _1.slice(:heap_eden_pages, :heap_eden_slots) }
    alloc0 = GC.stat(:total_allocated_objects)
    LowrailCallgrindBench.start
    result = super
    segments = LowrailCallgrindBench.finish
    allocations = GC.stat(:total_allocated_objects) - alloc0
    after = GC.stat_heap.transform_values { _1.slice(:heap_eden_pages, :heap_eden_slots) }
    warn "PTEST_SUITE #{JSON.generate(allocations: allocations, gc_segments: segments,
      heap_before: before, heap_after: after, anchors: anchors.size, yjit: RubyVM::YJIT.enabled?)}"
    result
  end
end)
