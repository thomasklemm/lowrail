# frozen_string_literal: true

# Shared fixed-heap preparation/window seam for requests and operation replays.
module HeapWindows
  def self.floors
    defaults = GC.stat_heap.values.map do |stats|
      size = stats.fetch(:slot_size)
      size <= 40 ? 1_000_000 : size <= 80 ? 250_000 : size <= 160 ? 100_000 : size <= 320 ? 20_000 : 10_000
    end
    slots = ENV.fetch("BENCH_HEAP_SLOTS", defaults.join(",")).split(",").map { Integer(_1) }
    raise "one positive heap floor per VM pool required" unless slots.size == defaults.size && slots.all?(&:positive?)
    slots
  end

  def self.windows(n, keys = [nil])
    order = %w[total no_gc]
    order.reverse! if ENV["BENCH_PHASE_ORDER"] == "1"
    keys.product(order, [0, n]).map do |key, mode, count|
      { unit: key, mode: mode, requests: count, before: GC.stat, after: GC.stat,
        pools_before: GC.stat_heap.keys.to_h { [_1, GC.stat_heap(_1)] },
        pools_after: GC.stat_heap.keys.to_h { [_1, GC.stat_heap(_1)] } }
    end
  end

  def self.prepare_heap
    3.times { GC.start }
    raise "app disabled GC" if GC.disable
    # Preserve 4.0's published fillers; 4.1 has 12 differently sized pools.
    lengths = [0, 4, 9, 19, 39] if GC.stat_heap.size == 5
    anchors = []
    GC.stat_heap.each do |pool, stats|
      target = Integer(ENV.fetch("RUBY_GC_HEAP_#{pool}_INIT_SLOTS"))
      count = [target - GC.stat_heap(pool, :heap_live_slots), 0].max
      size = stats.fetch(:slot_size)
      length = lengths ? lengths.fetch(pool) : (size - GC::INTERNAL_CONSTANTS.fetch(:RBASIC_SIZE)) / [0].pack("J").bytesize
      fillers = Array.new(count) { size < 40 ? Object.new : Array.new(length) }
      stride = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / stats.fetch(:slot_size) / 2
      fillers.each_with_index { |object, index| anchors << object if (index % stride).zero? }
      anchors << fillers.last unless fillers.empty?
      fillers.clear
    end
    GC.enable
    anchors
  end

  def self.run(windows, prepare: nil, observe: nil, settle: nil)
    anchors = prepare_heap
    observe_pools = ->(pools) { pools.each { |pool, stats| GC.stat_heap(pool, stats) } }
    # Warm the exact observation signatures, not just the workload. Ruby's
    # two-argument stat_heap wrapper can otherwise compile inside the gate.
    if observe
      200.times do
        observe_pools.call(windows.first.fetch(:pools_before))
        GC.stat(windows.first.fetch(:before))
        observe.call
      end
    end
    windows.each do |window|
      prepare&.call(window[:unit])
      3.times { GC.start }
      settle&.call
      window[:jit_before] = observe.call if observe
      observe_pools.call(window[:pools_before])
      GC.stat(window[:before])
      LowrailCallgrindBench.start(window[:mode] == "no_gc")
      yield window.fetch(:requests), window[:unit]
      segments = LowrailCallgrindBench.finish
      GC.stat(window[:after])
      observe_pools.call(window[:pools_after])
      window[:jit_after] = observe.call if observe
      window[:gc_segments] = segments
    end
    anchors.size
  end
end
