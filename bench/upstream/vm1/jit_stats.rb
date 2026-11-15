# frozen_string_literal: true

# VM1: JIT counters per request on P-MAP's Puma setup (server and client in
# one process, production). Warms every workload, then measures each one alone
# and stores the counter deltas per request:
#   hx CORPUS APP bundle exec ruby --yjit --yjit-stats=quiet [--yjit-trace-exits[=COUNTER]] THIS APP OUT_JSON
#   hx CORPUS APP bundle exec ruby --zjit --zjit-stats=quiet ... THIS APP OUT_JSON
# With --yjit-trace-exits, the sites (innermost frame and line, plus two
# callers) of the window's exits or of COUNTER's increments are stored too. On
# the VM1 measurement build (interp-insns.patch), interpreted instructions per
# ISEQ go to OUT_JSON's directory as APP.WINDOW.iseq.tsv.
# Env: VM1_WARMUP (150), VM1_REQUESTS (50), PMAP_ONLY (workload names), CENSUS_SET.
require_relative "../p_map/profile"

module VM1
  WARMUP = Integer(ENV.fetch("VM1_WARMUP", "150"))
  REQUESTS = Integer(ENV.fetch("VM1_REQUESTS", "50"))

  module_function

  def jit
    if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? then :zjit
    elsif RubyVM::YJIT.enabled? then :yjit
    end
  end

  def counters
    stats = case jit
    when :yjit then RubyVM::YJIT.runtime_stats
    when :zjit then RubyVM::ZJIT.stats
    else {}
    end
    stats.select { |_, v| v.is_a?(Integer) }
  end

  # Innermost Ruby frame of each traced exit, with two callers.
  def exit_sites
    return {} unless jit == :yjit && RubyVM::YJIT.trace_exit_locations_enabled?
    r = RubyVM::YJIT.exit_locations
    raw, lines, frames = r[:raw], r[:lines], r[:frames]
    sites = Hash.new(0)
    i = 0
    while i < raw.size
      len = raw[i]
      i += 1
      stack = raw[i, len].zip(lines[i, len])
      count = raw[i + len]
      insn = frames[stack.last[0]][:name]
      ruby = stack[0..-2].last(3).reverse.map { |f, l| "#{frames[f][:name]}@#{frames[f][:file]}:#{l}" }
      sites[[insn, *ruby].join(" <- ")] += count
      i += len + 1
    end
    sites
  end

  def run(name, output)
    RailsCensus.const_set(:Client, PMap::Client)
    server = PMap.start_puma
    ops = RailsCensus.workloads(name)
    ops += PMap.extra_ops(name, RailsCensus, ops)
    ops = ops.select { PMap::REQUEST_KINDS.include?(_1.kind) }
    only = ENV["PMAP_ONLY"]&.split(",")
    ops = ops.select { only.include?(_1.name) } if only
    reset = -> { RailsCensus.reset_side_effects }
    ops.each { |op| WARMUP.times { op.call.call; reset.call } }
    iseq = RubyVM::InstructionSequence.respond_to?(:vm1_reset)
    windows = ops.each_with_index.map do |op, index|
      GC.start
      before, sites_before = counters, exit_sites
      gc = GC.stat.slice(:count, :total_allocated_objects, :malloc_increase_bytes)
      RubyVM::InstructionSequence.vm1_reset if iseq
      started = PMap.mono_ns
      REQUESTS.times { op.call.call; reset.call }
      ns = PMap.mono_ns - started
      RubyVM::InstructionSequence.vm1_dump(File.join(File.dirname(output), "#{name}.#{index}.iseq.tsv")) if iseq
      after, sites_after = counters, exit_sites
      delta = after.filter_map { |k, v| d = v - before.fetch(k, 0); [k, d.fdiv(REQUESTS)] if d != 0 }.to_h
      sites = sites_after.filter_map { |k, v| d = v - sites_before.fetch(k, 0); [k, d.fdiv(REQUESTS)] if d > 0 }
        .sort_by { -_2 }.to_h
      { name: op.name, kind: op.kind, index: index, requests: REQUESTS, ms_per_request: ns / 1e6 / REQUESTS,
        objects_per_request: (GC.stat(:total_allocated_objects) - gc[:total_allocated_objects]).fdiv(REQUESTS),
        gc_count: GC.count - gc[:count], stats: delta, exit_sites: sites }
    end
    server.stop(true)
    File.write(output, JSON.generate(app: name, ruby: RUBY_DESCRIPTION, jit: jit, rails: RailsCensus.rails_sha,
      set: ENV["CENSUS_SET"], warmup: WARMUP, argv: ENV["VM1_FLAGS"], windows: windows))
    puts JSON.generate(app: name, jit: jit, workloads: windows.size)
  end
end

if $PROGRAM_NAME == __FILE__
  name, output = ARGV
  RailsCensus.boot(name)
  VM1.run(name, output)
end
