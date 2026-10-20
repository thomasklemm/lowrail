# frozen_string_literal: true

# Fresh processes are essential: disabling a global :return hook cannot undo
# its VM-wide instruction patching. No application or runtime changes here.
require_relative "../request_pairs"

if ENV["TRACE_SHAPE"]
  class TraceShape
    def boot
      @initialized = true
      self
    end

    def hot(value) = value * 3 + 7
    def run(n) = n.times { hot(19) }
  end
  object = TraceShape.new
  event = ENV.fetch("TRACE_SHAPE")
  if event != "original"
    kind = event == "targeted" ? :return : event.to_sym
    observer = TracePoint.new(kind) { observer.disable if event == "targeted" }
    if event == "targeted"
      observer.enable(target: TraceShape.instance_method(:boot))
      object.boot
    else
      observer.enable
      object.boot
      observer.disable
    end
    raise "observer still enabled" if observer.enabled?
  end
  raise "wrong result" unless object.hot(19) == 64
  object.run(2000)
  warm = JitStability.warm { |n| object.run(n) } if JitStability.enabled?
  metadata = {ruby: RUBY_DESCRIPTION, shape: event, **JitStability.state, jit_warmup: warm,
    tracepoints: TracePoint.stat.values, disasm: RubyVM::InstructionSequence.of(TraceShape.instance_method(:hot)).disasm}
  if ENV["TRACE_STATS"]
    before = RubyVM::YJIT.runtime_stats
    object.run(1000)
    after = RubyVM::YJIT.runtime_stats
    puts JSON.generate(metadata.merge(before: before, after: after,
      delta: after.select { |_, v| v.is_a?(Numeric) }.to_h { |k, v| [k, v - before.fetch(k, 0)] }))
  else
    JitStability.assert_mode!
    require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
    windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
    observer = JitStability.method(:snapshot) if JitStability.enabled?
    anchors = HeapWindows.run(windows, observe: observer) { |n, _| object.run(n) }
    puts "LOWRAIL_BENCH #{JSON.generate(metadata.merge(windows: windows, heap_anchors: anchors, ar_installed: 0))}"
  end
  exit
end

out = File.expand_path(ARGV.fetch(0))
raise "output must be new" if File.exist?(out)
raise "at most four workers" if Integer(ENV.fetch("BENCH_JOBS", "4")) > 4
FileUtils.mkdir_p(out, mode: 0o700)
arms = %w[off_a off_b return end script_compiled targeted]
environments = arms.to_h do |arm|
  [arm, {"RUBYOPT" => nil, "TRACE_SHAPE" => arm.start_with?("off_") ? "original" : arm}]
end
sources = [__FILE__, *%w[request_pairs heap_windows jit_stability].map { File.expand_path("../#{_1}.rb", __dir__) }]
  .to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources, diagnosis_only: true}
accepted = RequestPairs.heap_instructions(environments, Dir.pwd, out, "unused", metadata,
  worker: File.expand_path(__FILE__), requests: 10_000)
raise "source drift" unless sources.all? { |p, sha| Digest::SHA256.file(p).hexdigest == sha }
File.write(File.join(out, "verdict.json"), JSON.pretty_generate(accepted: accepted))
exit(accepted ? 0 : 2)
