# frozen_string_literal: true

# Native cross-check for profile.rb: the same Puma workloads with Vernier off,
# while `perf record` (started by native.sh) samples the process. The measured
# windows are bracketed with perf's control FIFO, so boot and warmup stay out.
#   hx CORPUS APP bundle exec ruby --yjit --yjit-perf native.rb APP OUT_JSON CTL_FIFO ACK_FIFO
require_relative "profile"

module PMapNative
  module_function

  def perf(ctl, ack, command)
    File.write(ctl, "#{command}\n")
    File.read(ack, 5)
  end

  def run(name, output, ctl, ack)
    RailsCensus.const_set(:Client, PMap::Client)
    server = PMap.start_puma
    ops = RailsCensus.workloads(name)
    ops += PMap.extra_ops(name, RailsCensus, ops)
    ops = ops.select { PMap::REQUEST_KINDS.include?(_1.kind) }
    reset = -> { RailsCensus.reset_side_effects }
    ops.each { |op| PMap::WARMUP.times { op.call.call; reset.call } }
    GC.start
    windows = []
    jit_before = PMap.yjit_counters
    gc_before = GC.total_time
    perf(ctl, ack, "enable")
    ops.each do |op|
      start = PMap.mono_ns
      PMap::REQUESTS.times { op.call.call; reset.call }
      windows << { name: op.name, requests: PMap::REQUESTS, ns: PMap.mono_ns - start }
    end
    perf(ctl, ack, "disable")
    server.stop(true)
    File.write(output, JSON.generate(app: name, ruby: RUBY_DESCRIPTION, windows: windows, gc_ns: GC.total_time - gc_before,
      jit: PMap.yjit_counters.to_h { |k, v| [k, v - jit_before.fetch(k, 0)] }, pid: Process.pid))
  end
end

if $PROGRAM_NAME == __FILE__
  name, output, ctl, ack = ARGV
  RailsCensus.boot(name)
  PMapNative.run(name, output, ctl, ack)
end
