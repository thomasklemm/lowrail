# frozen_string_literal: true

# Sequential, alternating fresh on/off processes; only this pass is enabled.
# ruby bench/preload_runs.rb .corpus/campfire OUTDIR [requests|micro]
require "json"
require "fileutils"
require "rbconfig"

app, out = ARGV.take(2).map { File.expand_path(_1) }
kind = ARGV.fetch(2, "requests")
FileUtils.mkdir_p(out)
root = File.expand_path("..", __dir__)
manifest = JSON.parse(File.read(File.join(app, ".lowrail/manifest.json")))
unit = manifest.fetch("units").find { _1["pass"] == "active_record/preload_plans" }.fetch("id")
paths = JSON.parse(File.read(File.join(app, "tmp/m0/paths.json")))
headers = File.read(File.join(app, "tmp/m0/headers.json"))
rounds = Integer(ENV.fetch("BENCH_ROUNDS", "5"))
all = []
(kind == "micro" ? ["micro"] : %w[cached no_page_cache]).each do |cache|
  rounds.times do |round|
    (round.even? ? %w[0 1] : %w[1 0]).each do |mode|
      formats = kind == "micro" ? ["micro"] : %w[html stream json]
      formats.each do |format|
        name = "#{cache}-#{round}-#{mode}-#{format}"
        file = File.join(out, "#{name}.json")
        env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
          "LOWRAIL" => mode, "LOWRAIL_UNITS" => unit.to_s,
          "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil,
          "RUBYOPT" => "-I#{root}/gem/lib -rlowrail/setup",
          "BENCH_HEADERS" => format == "json" ? nil : headers,
          "CAMPFIRE_RESPONSE_CACHE_MB" => cache == "no_page_cache" ? "0" : nil,
          "BENCH_SECONDS" => ENV.fetch("BENCH_SECONDS", "3"), "BENCH_JSON" => file, "BENCH_PROFILE" => nil }
        script = File.join(__dir__, format == "micro" ? "preload_paths.rb" : "requests.rb")
        keys = format == "html" ? %w[room messages sidebar search] : [format]
        args = format == "micro" ? [] : keys.map { "GET:#{paths.fetch(_1)}" }
        ok = system(env, RbConfig.ruby, "--yjit", script, *args, chdir: app,
          out: File.join(out, "#{name}.log"), err: [:child, :out])
        abort "failed #{name}; see private log" unless ok
        JSON.parse(File.read(file)).each { all << _1.merge("cache" => cache, "mode" => mode, "round" => round) }
        warn "finished #{name}"
      end
    end
  end
end
summary = all.group_by { [_1["cache"], _1["route"], _1["mode"]] }.map do |(cache, route, mode), rows|
  times = rows.map { _1.fetch("us_per_req") }.sort
  allocs = rows.map { _1.fetch("allocs_per_req") }.sort
  { cache: cache, route: route, mode: mode, n: rows.size,
    median_us: times[times.size / 2], min_us: times.first, max_us: times.last,
    median_allocs: allocs[allocs.size / 2] }
end
File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
puts JSON.pretty_generate(summary)
