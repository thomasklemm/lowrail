# frozen_string_literal: true

# ruby bench/ar_plans_runs.rb .corpus/campfire OUTDIR
# Five fresh YJIT processes, reverse case order on alternate runs, no profiler.
# These are diagnostic implementations, not LOWRAIL on/off or support gates.
require "json"
require "fileutils"
require "rbconfig"

app, out = ARGV.take(2).map { File.expand_path(_1) }
FileUtils.mkdir_p(out)
rows = []
Integer(ENV.fetch("BENCH_ROUNDS", "5")).times do |round|
  file = File.join(out, "#{round}.json")
  env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0",
    "RAILS_LOG_LEVEL" => "error", "RUBYOPT" => nil, "BENCH_REVERSE" => (round.odd? ? "1" : "0"),
    "BENCH_JSON" => file }
  abort "failed round #{round}; see private log" unless system(env, RbConfig.ruby, "--yjit",
    File.join(__dir__, "ar_plans.rb"), chdir: app, out: File.join(out, "#{round}.log"), err: [:child, :out])
  rows.concat(JSON.parse(File.read(file)))
  warn "finished #{File.basename(app)} round #{round}"
end
summary = rows.group_by { _1.fetch("route") }.map do |name, samples|
  times = samples.map { _1.fetch("us_per_req") }.sort
  allocations = samples.map { _1.fetch("allocs_per_req") }.sort
  { name: name, n: times.size, median_us: times[times.size / 2], min_us: times.first, max_us: times.last,
    median_allocations: allocations[allocations.size / 2] }
end
File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
puts JSON.pretty_generate(summary)
