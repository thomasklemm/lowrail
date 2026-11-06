# frozen_string_literal: true

require "json"
require "socket"
require "digest"
require_relative "../../heap_windows"
require_relative "../stack_map/perf_window"

out, source, app, counter = %w[PUMA_OUT PUMA_SOURCE PUMA_APP PUMA_COUNTER].map { ENV.fetch(_1) }
require "bundler/setup" if app == "blog"
$LOAD_PATH.unshift File.join(source, "lib")
require "puma"
require "puma/server"
if app == "blog"
  require_relative "../census/harness"
  RailsCensus.boot("blog")
  application = Rails.application
else
  require "rack/headers"
  body = ("aB7!" * (app == "large" ? 12_800 : 16)).freeze
  headers = { "content-type" => "text/plain", "content-length" => body.bytesize.to_s }
  response = [200, headers, [body]]
  application = ->(_env) { response }
end
loaded_puma = $LOADED_FEATURES.grep(%r{/puma(?:/.*)?\.(?:rb|so)\z})
raise "mixed Puma sources: #{loaded_puma}" unless loaded_puma.all? { _1.start_with?(source + "/") }
require ENV.fetch("PUMA_COUNTER_EXT") if counter == "callgrind"
require ENV.fetch("PUMA_SAMPLER_EXT") if counter == "stacks"

threads = Integer(ENV.fetch("PUMA_THREADS"))
sampling = { armed: false }
if counter == "stacks"
  raise "stack attribution needs one worker" unless threads == 1
  Puma::Server.prepend(Module.new do
    define_method(:process_client) do |*args|
      if sampling[:armed]
        sampling[:armed] = false
        CensusCpu.start(41231, 8192)
      end
      super(*args)
    end
  end)
end
anchors = HeapWindows.prepare_heap
server = Puma::Server.new(application, nil, min_threads: threads, max_threads: threads)
server.add_tcp_listener("127.0.0.1", Integer(ENV.fetch("PORT")))
server.run
control_path = "/tmp/lowrail-puma-#{Process.pid}.control"
control = UNIXServer.new(control_path)
File.write("#{out}.info", JSON.generate(port: ENV.fetch("PORT"), pid: Process.pid, control: control_path,
  path: app == "blog" ? "/articles" : "/"))
peer = control.accept
run = ->(count, measured = false) do
  peer.puts("go #{count} #{measured}")
  raise "client failed" unless peer.gets == "done\n"
end
snapshot = -> { StackMapPerf.counters }
count = Integer(ENV.fetch("PUMA_COUNT"))
200.times { GC.stat_heap.each_key { GC.stat_heap(_1, {}) }; snapshot.call }
run.call(2000)
history = []
if RubyVM::YJIT.enabled?
  flat = 0
  20.times do
    before = snapshot.call
    run.call(200)
    delta = snapshot.call.to_h { |key, value| [key, value - before.fetch(key)] }
    history << delta
    flat = delta.values.all?(&:zero?) ? flat + 1 : 0
    break if flat == 3
  end
end
3.times { GC.start }
run.call(1)
stats_before, stats_after = GC.stat, GC.stat
pools_before, pools_after = GC.stat_heap, GC.stat_heap
clock = -> { Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) }
times = []
200.times { times[0] = clock.call }
perf = nil
if counter == "perf"
  ctl, ack = "#{out}.ctl", "#{out}.ack"
  [ctl, ack].each { File.mkfifo(_1) }
  perf = Process.spawn("sudo", "perf", "record", "-e", "cpu-clock", "-F", "997", "--call-graph", "dwarf,16384",
    "--delay=-1", "--control=fifo:#{ctl},#{ack}", "-p", Process.pid.to_s, "-o", "#{out}.perf",
    out: "#{out}.perf.log", err: [:child, :out])
  perf_control, perf_ack = File.open(ctl, "w"), File.open(ack, "r+")
  perf_command = ->(command) do
    perf_control.puts(command)
    perf_control.flush
    raise "perf ack failed" unless perf_ack.read(5) == "ack\n\0"
  end
  perf_command.call("disable")
end
if counter == "strace"
  tracer = Process.spawn("sudo", "strace", "-f", "-c", "-o", "#{out}.strace", "-p", Process.pid.to_s,
    out: "#{out}.strace.log", err: [:child, :out])
  sleep 0.25
end
jit_before = snapshot.call
pools_before.each { |pool, values| GC.stat_heap(pool, values) }
GC.stat(stats_before)
usage_before = Process.times
times[0] = clock.call
LowrailCallgrindBench.start if counter == "callgrind"
sampling[:armed] = true if counter == "stacks"
perf_command&.call("enable")
run.call(count, true)
perf_command&.call("disable")
raise "worker sampler did not start" if sampling[:armed]
window = CensusCpu.finish if counter == "stacks"
LowrailCallgrindBench.finish if counter == "callgrind"
times[1] = clock.call
usage_after = Process.times
GC.stat(stats_after)
pools_after.each { |pool, values| GC.stat_heap(pool, values) }
jit_after = snapshot.call
if perf
  perf_command.call("stop")
  Process.wait(perf)
  raise "perf failed" unless $?.success?
  perf_control.close
  perf_ack.close
  File.unlink(ctl, ack)
end
if tracer
  peer.puts("detach #{tracer}")
  raise "strace detach failed" unless peer.gets == "detached\n"
  Process.wait(tracer)
end
if counter == "stacks"
  frames, stacks = CensusCpu.stacks
  File.write("#{out}.stacks", JSON.generate(frames: frames, stacks: stacks, window: window))
end
File.write(out, JSON.pretty_generate(ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?,
  puma: Puma::Const::PUMA_VERSION, source: IO.popen(["git", "-C", source, "rev-parse", "HEAD"], &:read).strip,
  loaded_puma: loaded_puma, app: app, threads: threads, counter: counter, count: count, anchors: anchors.size,
  jit_before: jit_before, jit_after: jit_after, history: history,
  stats_before: stats_before, stats_after: stats_after, pools_before: pools_before, pools_after: pools_after,
  cpu_s: times[1] - times[0], user_s: usage_after.utime - usage_before.utime,
  system_s: usage_after.stime - usage_before.stime, window: window))
peer.puts("finished")
peer.close
control.close
server.stop(true)
File.unlink(control_path)
