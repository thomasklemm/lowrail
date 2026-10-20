# frozen_string_literal: true

# Five alternating, fresh-process pairs; only AR instantiate units enabled.
# ruby bench/ar_instantiate_runs.rb .corpus/APP /tmp/ar-APP [micro|requests|breakdown]
require "json"
require "fileutils"
require "rbconfig"

app, out = ARGV.take(2).map { File.expand_path(_1) }
kind = ARGV.fetch(2, "micro")
FileUtils.mkdir_p(out)
root = File.expand_path("..", __dir__)
model = { "real-blog" => "Article", "campfire" => "Message", "pingcrm" => "Organization",
  "redprints-cfp" => "Proposal", "react-starter-kit" => "User" }.fetch(File.basename(app))
manifest = JSON.parse(File.read(File.join(app, ".lowrail/manifest.json")))
ids = manifest.fetch("units").select { _1["pass"] == "active_record/instantiate" }.map { _1.fetch("id") }
abort "build --ar-instantiate first" if ids.empty?
paths = kind == "requests" && File.basename(app) != "real-blog" ? JSON.parse(File.read(File.join(app, "tmp/m0/paths.json"))) : {}
path = case File.basename(app)
when "real-blog" then "/articles"
when "campfire" then paths["room"]
else paths.values.first
end
header_path = File.join(app, "tmp/m0", File.basename(app) == "campfire" ? "headers.json" : "headers-html.json")
headers = File.file?(header_path) ? File.read(header_path) : "{}"
rounds = kind == "breakdown" ? 1 : Integer(ENV.fetch("BENCH_ROUNDS", "5"))
all = []
rounds.times do |round|
  (round.even? ? %w[0 1] : %w[1 0]).each do |mode|
    label = "#{kind}-#{round}-#{mode}"
    file = File.join(out, "#{label}.json")
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
      "LOWRAIL" => mode, "LOWRAIL_UNITS" => ids.join(","), "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil,
      "RUBYOPT" => "-I#{root}/gem/lib -rlowrail/setup", "BENCH_MODEL" => model,
      "BENCH_SECONDS" => ENV.fetch("BENCH_SECONDS", "1"), "BENCH_ROUNDS" => kind == "breakdown" ? "5" : "1",
      "BENCH_CASES" => kind == "micro" ? "load_1,load_20,load_200,load_and_read_1,load_and_read_20,load_and_read_200" : nil,
      "BENCH_JSON" => file, "BENCH_HEADERS" => headers, "BENCH_PROFILE" => nil,
      "CAMPFIRE_RESPONSE_CACHE_MB" => "0" }
    if kind == "breakdown" || (kind == "requests" && round.zero? && ENV["BENCH_PROFILES"] == "1")
      env["BENCH_PROFILE"] = File.join(out, "#{label}-profile.json")
    end
    script = File.join(__dir__, kind == "requests" ? "requests.rb" : "ar_instantiate.rb")
    args = kind == "requests" ? ["GET:#{path}"] : []
    ok = system(env, RbConfig.ruby, "--yjit", script, *args, chdir: app,
      out: File.join(out, "#{label}.log"), err: [:child, :out])
    abort "failed #{label}; inspect #{File.join(out, "#{label}.log")}" unless ok
    data = JSON.parse(File.read(file))
    rows = kind == "requests" ? data : data.fetch("samples").map { |s| { "route" => s["case"], "us_per_req" => s["us"], "allocs_per_req" => s["allocations"] } }
    rows.each { all << _1.merge("mode" => mode, "round" => round) }
    warn "finished #{File.basename(app)} #{label}"
  end
end
summary = all.group_by { [_1["route"], _1["mode"]] }.map do |(name, mode), rows|
  times = rows.map { _1.fetch("us_per_req") }.sort
  allocs = rows.map { _1.fetch("allocs_per_req") }.sort
  { case: name, mode: mode, n: rows.size, median_us: times[times.size / 2],
    min_us: times.first, max_us: times.last, allocations: allocs[allocs.size / 2] }
end
File.write(File.join(out, "#{kind}-summary.json"), JSON.pretty_generate(summary))
puts JSON.pretty_generate(summary)
