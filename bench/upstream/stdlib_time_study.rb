# frozen_string_literal: true

require_relative "../request_pairs"

kind, out, base, candidate, ruby = ARGV
raise "usage: native|ir NEW_OUT BASE.rb CANDIDATE.rb [RUBY]" unless %w[native ir].include?(kind)
out = File.expand_path(out)
raise "new output required; no retries" if File.exist?(out)
FileUtils.mkdir_p(out)
sources = {"off_a" => File.realpath(base), "off_b" => File.realpath(base), "on" => File.realpath(candidate)}
worker = File.expand_path("stdlib_time.rb", __dir__)
pins = [*sources.values, worker, __FILE__].uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
protocol = {kind: kind, seed: 41231, rounds: kind == "native" ? 10 : 6,
  warmup: kind == "native" ? 30_000 : 100, measured_calls: kind == "native" ? 100_000 : 500,
  allocation_calls: 10_000, pins: pins, excluded: [], retry: false,
  scope: "parser calls only; no request-level speed claim",
  native_rule: "allocations primary; retain CPU regressions and failed controls; not a Lowrail JIT-flat speed certificate",
  ir_aa_rule: "total and no-GC paired 95% intervals wholly within ±0.1%"}
File.write(File.join(out, "protocol.json"), JSON.pretty_generate(protocol))

if kind == "ir"
  envs = sources.transform_values { {"TIME_SOURCE" => _1, "BENCH_JIT" => "0", "RUBYOPT" => nil} }
  ENV.update("BENCH_JIT" => "0", "BENCH_JOBS" => "1", "BENCH_REQUESTS" => "500")
  passed = RequestPairs.heap_instructions(envs, File.expand_path("../..", __dir__), out, "ir",
    {seed: 41231, rounds: 6, workers: {}}, worker: worker, requests: 500,
    aa_tolerance: 0.1, aa_zero_containment: false)
  puts "IR #{passed ? 'ACCEPTED' : 'REJECTED; retained'}"
else
  raise "Ruby executable required" unless ruby && File.executable?(ruby)
  rng = Random.new(41231)
  samples = {}
  %w[interpreter yjit zjit].each do |mode|
    flags = JitStability.flags(mode)
    flags << "--yjit-stats=quiet" if mode == "yjit"
    samples[mode] = 10.times.map do |round|
      sources.keys.shuffle(random: rng).to_h do |arm|
        stdout, stderr, status = Open3.capture3({"TIME_SOURCE" => sources.fetch(arm), "BENCH_JIT" => mode,
          "RUBYOPT" => nil, "RUBY_YJIT_ENABLE" => nil, "RUBY_ZJIT_ENABLE" => nil},
          "taskset", "-c", "2", ruby, *flags, worker, "native")
        label = "#{mode}-#{round}-#{arm}"
        File.write(File.join(out, "#{label}.json"), stdout)
        File.write(File.join(out, "#{label}.log"), stderr)
        raise "worker failed: #{label}" unless status.success?
        [arm, JSON.parse(stdout).fetch("cases")]
      end.tap { warn "#{mode} round #{round + 1}/10" }
    end
    File.write(File.join(out, "samples.json"), JSON.pretty_generate(samples))
  end
  summary = samples.transform_values do |rounds|
    rounds.first.fetch("off_a").keys.to_h do |name|
      rows = rounds.map { |r| r.transform_values { _1.fetch(name) } }
      [name, RequestPairs.summarize(rows, seed: 41231, tolerance: 5,
        metrics: %w[cpu_ns allocations], controls: %w[cpu_ns], zero_containment: false)]
    end
  end
  File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
  puts JSON.pretty_generate(summary)
end
raise "source changed" unless pins.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
