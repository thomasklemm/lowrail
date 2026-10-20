# frozen_string_literal: true

# A separate, finite method-attribution study. Original accepted cohorts stay
# unchanged: their exported groups cannot reconstruct discarded Ruby frames.
if ARGV.first&.start_with?("GET:")
  load File.expand_path("hotspots.rb", __dir__)
  puts "LOWRAIL_DETAIL #{JSON.generate(HotspotProbe.details)}"
  exit
end
require_relative "../request_pairs"

root = File.expand_path("../..", __dir__)
out = File.expand_path(ARGV.fetch(0))
raise "new output required" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
extension = File.join(out, "lowrail_hotspots_detail.#{RbConfig::CONFIG.fetch("DLEXT")}")
raise "probe compilation failed" unless system(*RbConfig::CONFIG.fetch("LDSHARED").shellsplit, "-fPIC", "-O2", "-Wall",
  "-I#{RbConfig::CONFIG.fetch("rubyhdrdir")}", "-I#{RbConfig::CONFIG.fetch("rubyarchhdrdir")}",
  File.join(__dir__, "hotspots_detail.c"), "-o", extension)
sources = %w[bench/callgrind.c bench/heap_windows.rb bench/request_pairs.rb
  bench/experiments/hotspots.c bench/experiments/hotspots.rb
  bench/experiments/hotspots_detail.c bench/experiments/hotspots_detail.rb
  bench/experiments/hotspots-valgrind.patch].to_h do |path|
  [path, Digest::SHA256.file(File.join(root, path)).hexdigest]
end
File.write(File.join(out, "provenance.json"), JSON.pretty_generate(
  revision: `git -C #{root.shellescape} rev-parse HEAD`.strip, sources: sources,
  brk_reservation_mib: 512,
  valgrind_sha256: Digest::SHA256.file(ENV.fetch("HOTSPOT_VALGRIND_TOOL")).hexdigest))
apps = { "blog" => ["real-blog-r4", "show", "/articles/1"],
  "starter" => ["react-starter-kit", "dashboard", "/dashboard"] }
apps.select! { |name, _| ARGV.drop(1).include?(name) } if ARGV.size > 1
verdicts = {}
apps.each do |name, (directory, route, path)|
  app = File.join(root, ".corpus", directory)
  format = name == "blog" ? "html" : "json"
  label = "#{name}-#{route}-#{format}"
  dir = File.join(out, label)
  FileUtils.mkdir_p(dir)
  headers = name == "blog" ? "{}" : File.read(File.join(app, "tmp/m0/headers-json.json"))
  env = { "RAILS_ENV" => "production", "RAILS_LOG_LEVEL" => "error", "SECRET_KEY_BASE_DUMMY" => "1",
    "LOWRAIL" => "0", "RUBYOPT" => nil, "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil,
    "LOWRAIL_DEBUG" => nil, "LOWRAIL_SHADOW" => nil, "BENCH_HEADERS" => headers, "BENCH_JIT" => "0",
    "HOTSPOT_EXTENSION" => extension }
  environments = %w[off_a off_b trace_a trace_b].to_h do |arm|
    [arm, env.merge("HOTSPOT_TRACE" => arm.start_with?("trace") ? "1" : "0")]
  end
  metadata = { seed: 41231, rounds: 6, app: directory, route_label: route, format: format, workers: {} }
  baseline_ok = RequestPairs.heap_instructions(environments, app, dir, "GET:#{path}", metadata,
    worker: File.expand_path(__FILE__))
  data = JSON.parse(File.read(File.join(dir, "samples.json")))
  corrected = data.fetch("samples").each_index.map do |round|
    %w[trace_a trace_b].zip(%w[off_a off_b]).to_h do |arm, key|
      worker = data.fetch("workers").fetch("#{round}-#{arm}")
      [key, %w[total no_gc].to_h do |mode|
        indices = worker.fetch("windows").each_index.select { worker["windows"][_1]["mode"] == mode }
        empty, full = indices.sort_by { worker["windows"][_1]["requests"] }
        price = (worker["attribution"][full]["work_ir"] - worker["attribution"][empty]["work_ir"]).fdiv(data.fetch("requests"))
        ["instructions_#{mode}", price]
      end]
    end
  end
  sampler_aa = RequestPairs.summarize(corrected, seed: 41231, tolerance: 0.5,
    metrics: %w[instructions_total instructions_no_gc], controls: %w[instructions_total instructions_no_gc])
  fidelity = %w[off_a off_b].to_h do |arm|
    [arm, %w[total no_gc].to_h do |mode|
      metric = "instructions_#{mode}"
      values = corrected.each_index.map { |i| 100 * (corrected[i][arm][metric] / data["samples"][i][arm][metric] - 1) }
      [mode, RequestPairs.estimate(values, seed: 41231)]
    end]
  end
  capture = data.fetch("workers").values.select { _1["trace"] }.flat_map { _1.fetch("attribution") }
  integrity = capture.all? do |window|
    window.values_at("empty", "truncated", "dropped") == [0, 0, 0] &&
      window["issued"] == window["signals"] && window["lag_max_ir"] <= 3277
  end
  fidelity_ok = fidelity.values.flat_map(&:values).all? { _1[:ci95].all? { |value| value.abs <= 0.5 } }
  brk_overflow = Dir[File.join(dir, "*.valgrind.log")].any? { File.read(_1).include?("brk segment overflow") }
  verdicts[label] = baseline_ok && sampler_aa[:aa][:pass] && integrity && fidelity_ok && !brk_overflow
  File.write(File.join(dir, "sampler-controls.json"), JSON.pretty_generate(
    accepted: verdicts[label], sampler_aa: sampler_aa, fidelity_pct: fidelity,
    integrity: integrity, fidelity_pass: fidelity_ok, brk_overflow: brk_overflow, corrected_samples: corrected))
  details = data.fetch("workers").select { |_, worker| worker["trace"] }.to_h do |key, _|
    line = File.foreach(File.join(dir, "#{key}.log")).find { _1.start_with?("LOWRAIL_DETAIL ") }
    [key, JSON.parse(line.to_s.delete_prefix("LOWRAIL_DETAIL "))]
  end
  File.write(File.join(dir, "details.json"), JSON.generate(details))
  puts "#{label}: #{verdicts[label] ? 'all detail controls accepted' : 'REJECTED; retained'}"
  $stdout.flush
  File.write(File.join(out, "verdicts.json"), JSON.pretty_generate(verdicts))
end
raise "measurement source changed during study" unless sources.all? { |path, sha| Digest::SHA256.file(File.join(root, path)).hexdigest == sha }
exit(verdicts.values.all? ? 0 : 2)
