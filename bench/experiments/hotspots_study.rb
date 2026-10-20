# frozen_string_literal: true

# Finite off/off + profiled-off/profiled-off cohorts; never retry a rejection.
require_relative "../request_pairs"

root = File.expand_path("../..", __dir__)
out = File.expand_path(ARGV.fetch(0))
raise "new output required" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
extension = File.join(out, "lowrail_hotspots.#{RbConfig::CONFIG.fetch("DLEXT")}")
raise "probe compilation failed" unless system(*RbConfig::CONFIG.fetch("LDSHARED").shellsplit, "-fPIC", "-O2", "-Wall",
  "-I#{RbConfig::CONFIG.fetch("rubyhdrdir")}", "-I#{RbConfig::CONFIG.fetch("rubyarchhdrdir")}",
  File.join(__dir__, "hotspots.c"), "-o", extension)
sources = %w[bench/callgrind.c bench/heap_windows.rb bench/request_pairs.rb
  bench/experiments/hotspots.c bench/experiments/hotspots.rb
  bench/experiments/hotspots_study.rb bench/experiments/hotspots-valgrind.patch].to_h do |path|
  [path, Digest::SHA256.file(File.join(root, path)).hexdigest]
end
File.write(File.join(out, "provenance.json"), JSON.pretty_generate(
  revision: `git -C #{root.shellescape} rev-parse HEAD`.strip, sources: sources,
  valgrind: `which valgrind`.strip,
  brk_reservation_mib: 512, data_limit: Process.getrlimit(Process::RLIMIT_DATA).map { _1 == Process::RLIM_INFINITY ? "unlimited" : _1 },
  valgrind_sha256: Digest::SHA256.file(ENV.fetch("HOTSPOT_VALGRIND_TOOL")).hexdigest))
apps = {
  "blog" => "real-blog-r4", "starter" => "react-starter-kit",
  "pingcrm" => "pingcrm", "redprints" => "redprints-hotspots-r4", "campfire" => "campfire"
}
apps.select! { |name, _| ARGV.drop(1).include?(name) } if ARGV.size > 1
verdicts = {}
apps.each do |name, directory|
  app = File.join(root, ".corpus", directory)
  paths = name == "blog" ? { "index" => "/articles", "show" => "/articles/1", "edit" => "/articles/1/edit" } :
    JSON.parse(File.read(File.join(app, "tmp/m0/paths.json")))
  shapes = if name == "campfire"
    [["room", "cached", nil], ["room", "uncached", "0"],
     ["sidebar", "uncached", "0"], ["json", "uncached", "0"]]
  elsif name == "blog"
    paths.keys.map { [_1, "html", nil] }
  else
    paths.keys.product(%w[html json]).map { |route, format| [route, format, nil] }
  end
  shapes.each do |route, format, cache|
    label = "#{name}-#{route}-#{format}"
    next if ENV["HOTSPOT_ONLY"] && !ENV["HOTSPOT_ONLY"].split(",").include?(label)
    headers = case name
    when "blog" then "{}"
    when "campfire" then route == "json" ? "{}" : File.read(File.join(app, "tmp/m0/headers.json"))
    else File.read(File.join(app, "tmp/m0/headers-#{format}.json"))
    end
    dir = File.join(out, label)
    FileUtils.mkdir_p(dir)
    env = { "RAILS_ENV" => "production", "RAILS_LOG_LEVEL" => "error", "SECRET_KEY_BASE_DUMMY" => "1",
      "LOWRAIL" => "0", "RUBYOPT" => nil, "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil,
      "LOWRAIL_DEBUG" => nil, "LOWRAIL_SHADOW" => nil, "BENCH_HEADERS" => headers, "BENCH_JIT" => "0",
      "HOTSPOT_EXTENSION" => extension, "CAMPFIRE_RESPONSE_CACHE_MB" => cache,
      "HOTSPOT_SSR" => name == "starter" && format == "html" ? "1" : nil }
    environments = %w[off_a off_b trace_a trace_b].to_h do |arm|
      [arm, env.merge("HOTSPOT_TRACE" => arm.start_with?("trace") ? "1" : "0")]
    end
    metadata = { seed: 41231, rounds: 6, app: directory, route_label: route, format: format,
      jobs: Integer(ENV.fetch("BENCH_JOBS", "4")), workers: {} }
    puts "#{label}: starting six finite rounds"
    $stdout.flush
    baseline_ok = RequestPairs.heap_instructions(environments, app, dir, "GET:#{paths.fetch(route)}", metadata,
      worker: File.join(__dir__, "hotspots.rb"))
    data = JSON.parse(File.read(File.join(dir, "samples.json")))
    corrected = data.fetch("samples").each_index.map do |round|
      %w[trace_a trace_b].zip(%w[off_a off_b]).to_h do |arm, key|
        worker = data.fetch("workers").fetch("#{round}-#{arm}")
        values = %w[total no_gc].to_h do |mode|
          indices = worker.fetch("windows").each_index.select { worker["windows"][_1]["mode"] == mode }
          empty, full = indices.sort_by { worker["windows"][_1]["requests"] }
          price = (worker["attribution"][full]["work_ir"] - worker["attribution"][empty]["work_ir"]).fdiv(data.fetch("requests"))
          ["instructions_#{mode}", price]
        end
        [key, values]
      end
    end
    sampler_aa = RequestPairs.summarize(corrected, seed: 41231, tolerance: 0.5,
      metrics: %w[instructions_total instructions_no_gc], controls: %w[instructions_total instructions_no_gc])
    fidelity = %w[total no_gc].to_h do |mode|
      values = corrected.each_index.map do |round|
        100 * (corrected[round]["off_a"]["instructions_#{mode}"] /
          data["samples"][round]["off_a"]["instructions_#{mode}"] - 1)
      end
      [mode, RequestPairs.estimate(values, seed: 41231)]
    end
    capture = data.fetch("workers").values.select { _1["trace"] }.flat_map { _1.fetch("attribution") }
    integrity = capture.all? do |window|
      window.values_at("empty", "truncated", "dropped") == [0, 0, 0] &&
        window["issued"] == window["signals"] && window["lag_max_ir"] <= 3277
    end
    fidelity_ok = fidelity.values.all? { _1[:ci95].all? { |value| value.abs <= 0.5 } }
    brk_overflow = Dir[File.join(dir, "*.valgrind.log")].any? { File.read(_1).include?("brk segment overflow") }
    verdicts[label] = baseline_ok && sampler_aa[:aa][:pass] && integrity && fidelity_ok && !brk_overflow
    File.write(File.join(dir, "sampler-controls.json"), JSON.pretty_generate(
      accepted: verdicts[label], sampler_aa: sampler_aa, fidelity_pct: fidelity,
      integrity: integrity, fidelity_pass: fidelity_ok, brk_overflow: brk_overflow, corrected_samples: corrected))
    puts "#{label}: #{verdicts[label] ? 'baseline controls accepted' : 'REJECTED; retained'}"
    $stdout.flush
    File.write(File.join(out, "verdicts.json"), JSON.pretty_generate(verdicts))
  end
end
raise "measurement source changed during study" unless sources.all? { |path, sha| Digest::SHA256.file(File.join(root, path)).hexdigest == sha }
exit(verdicts.values.all? ? 0 : 2)
