# frozen_string_literal: true

require_relative "worker_placement"

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
        pools_after: GC.stat_heap.keys.to_h { [_1, GC.stat_heap(_1)] },
        placement: {"counter_envelope_ns" => [0, 0]} }
    end
  end

  def self.collect
    3.times { GC.start }
  end

  def self.page_targets
    GC.stat_heap.to_h do |pool, stats|
      # Allow one slot for the page header/alignment, conservatively. Equal
      # page counts can still differ slightly in slots; the old gate remains.
      slots = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / stats.fetch(:slot_size) - 1
      floor = Integer(ENV.fetch("RUBY_GC_HEAP_#{pool}_INIT_SLOTS"))
      [pool, (floor + slots - 1) / slots]
    end
  end

  def self.prepare_heap
    collect
    raise "app disabled GC" if GC.disable
    # Preserve 4.0's published fillers; 4.1 has 12 differently sized pools.
    lengths = [0, 4, 9, 19, 39] if GC.stat_heap.size == 5
    anchors = []
    targets = page_targets
    # Prepare pool 0 last: bookkeeping for the other pools uses small slots.
    GC.stat_heap.to_a.reverse_each do |pool, stats|
      target = targets.fetch(pool)
      raise "heap pool #{pool} already exceeds page target #{target}" if stats.fetch(:heap_eden_pages) > target
      size = stats.fetch(:slot_size)
      length = lengths ? lengths.fetch(pool) : (size - GC::INTERNAL_CONSTANTS.fetch(:RBASIC_SIZE)) / [0].pack("J").bytesize
      stride = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / stats.fetch(:slot_size) / 2
      index, object = 0, nil
      until GC.stat_heap(pool, :heap_eden_pages) == target
        # With GC disabled the unanchored fillers remain occupied too.
        object = size < 40 ? Object.new : Array.new(length)
        anchors << object if (index % stride).zero?
        index += 1
        raise "filler does not grow heap pool #{pool}" if index > target * GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / size
      end
      anchors << object if object
    end
    GC.enable
    # Discard fillers BEFORE observers. Otherwise their nearly full heap can
    # grow by an arm-dependent page before automatic collection catches up.
    collect
    targets.each do |pool, target|
      raise "heap pool #{pool} did not retain page target #{target}" unless GC.stat_heap(pool, :heap_eden_pages) == target
    end
    anchors
  ensure
    GC.enable
  end

  def self.run(windows, prepare: nil, observe: nil, settle: nil, warmup: nil, idle_connections: nil)
    anchors = prepare_heap
    observe_pools = ->(pools) { pools.each { |pool, stats| GC.stat_heap(pool, stats) } }
    clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) } if idle_connections
    realtime = -> { Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond) } if ENV["BENCH_YJIT_LOG_FILE"]
    placement_clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) }
    200.times do
      # Consume the result too: YJIT's unused-return specialization otherwise
      # leaves the actual snapshot-producing path cold at the first window.
      windows.first[:placement]["before"] = WorkerPlacement.snapshot
      windows.first[:placement]["after"] = WorkerPlacement.snapshot
      windows.first[:placement]["counter_envelope_ns"][0] = placement_clock.call
      windows.first[:placement]["counter_envelope_ns"][1] = placement_clock.call
    end
    # Warm the exact observation signatures, not just the workload. Ruby's
    # two-argument stat_heap wrapper can otherwise compile inside the gate.
    if observe
      200.times do
        observe_pools.call(windows.first.fetch(:pools_before))
        GC.stat(windows.first.fetch(:before))
        observe.call
        clock&.call
        realtime&.call
        idle_connections&.call
      end
    end
    # Certify the workload in the prepared heap, after observer compilation.
    # Captured-operation workers supply their own context-preserving callback.
    warmup&.call
    windows.each do |window|
      prepare&.call(window[:unit])
      collect
      window[:last_request_start_ns] = clock.call if clock
      settle&.call
      if clock
        window[:last_request_end_ns] = clock.call
        window[:idle_connections] = idle_connections.call
        window[:wall_start_ns] = clock.call
      end
      window[:jit_log_start_realtime_ns] = realtime.call if realtime
      window[:jit_before] = observe.call if observe
      observe_pools.call(window[:pools_before])
      window[:placement]["before"] = WorkerPlacement.snapshot
      window[:placement]["counter_envelope_ns"][0] = placement_clock.call
      GC.stat(window[:before])
      LowrailCallgrindBench.start(window[:mode] == "no_gc")
      yield window.fetch(:requests), window[:unit]
      segments = LowrailCallgrindBench.finish
      GC.stat(window[:after])
      window[:placement]["counter_envelope_ns"][1] = placement_clock.call
      observe_pools.call(window[:pools_after])
      window[:wall_end_ns] = clock.call if clock
      window[:jit_after] = observe.call if observe
      window[:jit_log_end_realtime_ns] = realtime.call if realtime
      window[:gc_segments] = segments
      window[:placement]["after"] = WorkerPlacement.snapshot
    end
    anchors.size
  end
end
