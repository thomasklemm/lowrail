# frozen_string_literal: true

require_relative "../census/harness"
require_relative "../../heap_windows"
require_relative "perf_window"
require "socket"

app = ENV.fetch("STACK_MAP_APP")
RailsCensus.boot(app)
require "puma"
require "puma/server"
require ENV.fetch("CENSUS_CPU_EXT") if ENV["STACK_MAP_COUNTER"] == "callgrind"
anchors = HeapWindows.prepare_heap
pools = GC.stat_heap
path = "/articles"
headers = { "Host" => "localhost", "X-Forwarded-Proto" => "https", "Accept" => "text/html" }
if app == "writebook"
  user = User.find_by!(email_address: "david@example.com")
  login = user.sessions.start!(user_agent: RailsCensus::UA, ip_address: "127.0.0.1")
  headers["Cookie"] = RailsCensus.signed_cookie(:session_token, login.token).join("=")
  book = Book.find_by!(slug: "handbook")
  leaf = book.leaves.find_by!(title: "Welcome to The Handbook!")
  path = "/#{book.id}/#{book.slug}/#{leaf.id}/#{leaf.slug}"
end
headers["User-Agent"] = RailsCensus::UA
out = ENV.fetch("STACK_MAP_OUT")
control = UNIXServer.new("#{out}.control")
state = { arm: false, started: false }
if ENV["STACK_MAP_COUNTER"] == "callgrind"
  hook = Module.new do
    define_method(:process_client) do |*args|
      if state[:arm]
        state[:arm] = false
        CensusCpu.start(41231, 8192)
        state[:started] = true
      end
      super(*args)
    end
  end
  Puma::Server.prepend(hook)
end
server = Puma::Server.new(Rails.application, nil, min_threads: 1, max_threads: 1)
server.add_tcp_listener("127.0.0.1", Integer(ENV.fetch("PORT")))
server.run
File.write("#{out}.info", JSON.generate(port: ENV.fetch("PORT"), path: path, headers: headers, pid: Process.pid))
peer = control.accept
work = -> { peer.puts("go"); raise "client failed" unless peer.gets == "done\n" }
result = if ENV["STACK_MAP_COUNTER"] == "perf"
  StackMapPerf.measure(work)
else
  5.times { work.call }
  sample = -> {
    state[:arm] = true
    state[:started] = false
    work.call
    raise "Puma worker did not start sampler" unless state[:started]
    CensusCpu.finish
  }
  sample.call
  history = []
  if RubyVM::YJIT.enabled?
    flat = 0
    50.times do
      GC.start
      before = StackMapPerf.counters
      work.call
      after = StackMapPerf.counters
      history << after.to_h { |key, value| [key, value - before.fetch(key)] }
      flat = after == before ? flat + 1 : 0
      break if flat == 3
    end
  end
  3.times { GC.start }
  work.call
  before = StackMapPerf.counters
  objects, gc = GC.stat(:total_allocated_objects), GC.count
  window = sample.call
  after = StackMapPerf.counters
  objects, gc = GC.stat(:total_allocated_objects) - objects, GC.count - gc
  frames, stacks = CensusCpu.stacks
  File.write("#{out}.stacks", JSON.generate(frames: frames, stacks: stacks, window: window))
  { ops: 1, history: history, window: window, jit_before: before, jit_after: after,
    objects: objects, gc_runs: gc }
end
File.write(out, JSON.generate(result.merge(ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?,
  pools: pools, anchors: anchors.size, puma: Puma::Const::PUMA_VERSION)))
peer.puts("finished")
peer.close
server.stop(true)
control.close
File.unlink("#{out}.control")
