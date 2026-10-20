# frozen_string_literal: true

# Five fresh-process, interleaved pairs, only active_record/ar_plans enabled.
# ruby bench/ar_cached_runs.rb .corpus/{campfire,pingcrm} OUTDIR [requests|micro]
# Private request headers stay in the app's tmp/m0; never copy them into results.
require "json"
require "fileutils"
require "rbconfig"
app, out = ARGV.take(2).map { File.expand_path(_1) }
micro = ARGV.fetch(2, "requests") == "micro"
root = File.expand_path("..", __dir__)
manifest = JSON.parse(File.read(File.join(app, ".lowrail/manifest.json")))
ids = manifest.fetch("units").select { _1["pass"] == "active_record/ar_plans" }.map { _1.fetch("id") }
paths = JSON.parse(File.read(File.join(app, "tmp/m0/paths.json")))
campfire = File.basename(app) == "campfire"
headers = File.read(File.join(app, "tmp/m0", campfire ? "headers.json" : "headers-json.json"))
keys = campfire ? %w[room messages sidebar search] : %w[organizations contacts]
unless micro
  accepted = keys.map do |key|
    system({ "BENCH_HEADERS" => headers, "CAMPFIRE_RESPONSE_CACHE_MB" => "0" }, RbConfig.ruby,
      File.join(__dir__, "pass.rb"), app, "--out", File.join(out, key), "--pass", "active_record/ar_plans", "--path", paths.fetch(key))
  end
  exit(accepted.all? ? 0 : 2)
end
FileUtils.mkdir_p(out)
all = []
Integer(ENV.fetch("BENCH_ROUNDS", "5")).times do |round|
  (round.even? ? %w[0 1] : %w[1 0]).each do |mode|
    name = "#{round}-#{mode}"
    file = File.join(out, "#{name}.json")
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
      "LOWRAIL" => mode, "LOWRAIL_UNITS" => ids.join(","), "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil,
      "RUBYOPT" => "-I#{root}/gem/lib -rlowrail/setup", "BENCH_HEADERS" => headers,
      "CAMPFIRE_RESPONSE_CACHE_MB" => "0", "BENCH_SECONDS" => ENV.fetch("BENCH_SECONDS", "3"),
      "BENCH_JSON" => file, "BENCH_PROFILE" => nil }
    script = File.join(__dir__, "ar_cached_reader.rb")
    abort "failed #{name}; see private log" unless system(env, RbConfig.ruby, "--yjit", script,
      chdir: app, out: File.join(out, "#{name}.log"), err: [:child, :out])
    JSON.parse(File.read(file)).each { all << _1.merge("round" => round, "mode" => mode) }
    warn "finished #{File.basename(app)} #{name}"
  end
end
summary = all.group_by { [_1.fetch("route"), _1.fetch("mode")] }.map do |(route, mode), rows|
  times = rows.map { _1.fetch("us_per_req") }.sort
  allocations = rows.map { _1.fetch("allocs_per_req") }.sort
  { route: route, mode: mode, n: rows.size, median_us: times[times.size / 2],
    min_us: times.first, max_us: times.last, median_allocs: allocations[allocations.size / 2] }
end
File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
puts JSON.pretty_generate(summary)
