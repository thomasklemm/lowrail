# frozen_string_literal: true

# Shared fixed-heap preparation/window seam for requests and operation replays.
module HeapWindows
  def self.windows(n, keys = [nil])
    order = %w[total no_gc]
    order.reverse! if ENV["BENCH_PHASE_ORDER"] == "1"
    keys.product(order, [0, n]).map do |key, mode, count|
      { unit: key, mode: mode, requests: count, before: GC.stat, after: GC.stat,
        pools_before: GC.stat_heap.keys.to_h { [_1, GC.stat_heap(_1)] },
        pools_after: GC.stat_heap.keys.to_h { [_1, GC.stat_heap(_1)] } }
    end
  end

  def self.run(windows, prepare: nil)
    3.times { GC.start }
    raise "app disabled GC" if GC.disable
    lengths = [0, 4, 9, 19, 39]
    anchors = []
    GC.stat_heap.each do |pool, stats|
      target = Integer(ENV.fetch("RUBY_GC_HEAP_#{pool}_INIT_SLOTS"))
      count = [target - GC.stat_heap(pool, :heap_live_slots), 0].max
      fillers = Array.new(count) { Array.new(lengths.fetch(pool)) }
      stride = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / stats.fetch(:slot_size) / 2
      fillers.each_with_index { |object, index| anchors << object if (index % stride).zero? }
      anchors << fillers.last unless fillers.empty?
      fillers.clear
    end
    GC.enable
    windows.each do |window|
      prepare&.call(window[:unit])
      3.times { GC.start }
      window[:pools_before].each { |pool, stats| GC.stat_heap(pool, stats) }
      GC.stat(window[:before])
      LowrailCallgrindBench.start(window[:mode] == "no_gc")
      yield window.fetch(:requests), window[:unit]
      segments = LowrailCallgrindBench.finish
      GC.stat(window[:after])
      window[:pools_after].each { |pool, stats| GC.stat_heap(pool, stats) }
      window[:gc_segments] = segments
    end
    anchors.size
  end
end
