# frozen_string_literal: true

# Fresh-process, alternating on/off HTML requests. Only memo units enabled.
# Build production first; prepare fixture authentication with campfire_setup.rb.
# ruby bench/memo_runs.rb .corpus/campfire /tmp/memo-results
require "json"
require "fileutils"
require "rbconfig"

app, out = ARGV.take(2).map { File.expand_path(_1) }
FileUtils.mkdir_p(out)
root = File.expand_path("..", __dir__)
units = JSON.parse(File.read(File.join(app, ".lowrail/manifest.json"))).fetch("units")
ids = units.select { _1["pass"].start_with?("memo/") }.map { _1.fetch("id") }
abort "build with --memo --env production first" if ids.empty?
paths = JSON.parse(File.read(File.join(app, "tmp/m0/paths.json")))
headers = File.read(File.join(app, "tmp/m0/headers.json"))
routes = %w[room messages sidebar search].map { "GET:#{paths.fetch(_1)}" }
all = []
%w[cached no_page_cache].each do |cache|
  Integer(ENV.fetch("BENCH_ROUNDS", "5")).times do |round|
    (round.even? ? %w[0 1] : %w[1 0]).each do |mode|
      name = "#{cache}-#{round}-#{mode}"
      file = File.join(out, "#{name}.json")
      env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
        "LOWRAIL" => mode, "LOWRAIL_UNITS" => ids.join(","), "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil,
        "RUBYOPT" => "-I#{root}/gem/lib -rlowrail/setup", "BENCH_HEADERS" => headers,
        "CAMPFIRE_RESPONSE_CACHE_MB" => cache == "no_page_cache" ? "0" : nil,
        "BENCH_SECONDS" => ENV.fetch("BENCH_SECONDS", "3"), "BENCH_JSON" => file, "BENCH_PROFILE" => nil }
      ok = system(env, RbConfig.ruby, "--yjit", File.join(__dir__, "requests.rb"), *routes,
        chdir: app, out: File.join(out, "#{name}.log"), err: [:child, :out])
      abort "failed #{name}; see private log" unless ok
      JSON.parse(File.read(file)).each { all << _1.merge("cache" => cache, "mode" => mode, "round" => round) }
      warn "finished #{name}"
    end
  end
end
summary = all.group_by { [_1["cache"], _1["route"], _1["mode"]] }.map do |(cache, route, mode), rows|
  times = rows.map { _1.fetch("us_per_req") }.sort
  allocs = rows.map { _1.fetch("allocs_per_req") }.sort
  { cache: cache, route: route, mode: mode, n: rows.size, median_us: times[times.size / 2],
    min_us: times.first, max_us: times.last, median_allocs: allocs[allocs.size / 2] }
end
File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
puts JSON.pretty_generate(summary)
