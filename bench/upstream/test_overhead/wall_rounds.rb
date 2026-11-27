# frozen_string_literal: true

# Suite wall time per arm, interleaved by round (docs/upstream/test-overhead-2.md).
#   RDIFF_RAILS=SHA RDIFF_CORPUS=censuspt2 ruby wall_rounds.rb OUT_DIR RUBY_DIR MODE ROUNDS APP...
# Arms: a and a2 run the suite as configured (debug log level), info with PT2_LOG_LEVEL=info. Each round runs
# every app's three arms in a rotated order, serially, through run_suite.rb (fresh copy and database each),
# and appends one line per run to OUT_DIR/runs.jsonl: the test window's wall and CPU seconds, allocations,
# tests and exit status. Summarize with wall_summary.rb.
require "json"
require "fileutils"
require "rbconfig"

out, ruby, mode, rounds, *apps = ARGV
FileUtils.mkdir_p(out)
arms = { "a" => {}, "a2" => {}, "info" => { "PT2_LOG_LEVEL" => "info" } }
orders = arms.keys.permutation.to_a
runner = File.expand_path("run_suite.rb", __dir__)
Integer(rounds).times do |round|
  apps.each do |app|
    orders[(round + apps.index(app)) % orders.size].each do |arm|
      prefix = File.join(out, "raw", "#{app}-#{arm}-#{round}")
      FileUtils.mkdir_p(File.dirname(prefix))
      system(arms.fetch(arm), RbConfig.ruby, runner, app, ruby, mode, prefix, "none", out: File::NULL, err: File::NULL)
      meta = Dir["#{prefix}.[0-9]*.json"].map { JSON.parse(File.read(_1)) }.max_by { _1["tests"] }
      run = JSON.parse(File.read("#{prefix}.run.json"))
      line = { app:, arm:, round:, exit: run["exit"], process_wall: run["process_wall"], tests: meta&.dig("tests"),
        wall: meta&.dig("window", "wall"), cpu: meta&.dig("window", "cpu"), allocs: meta&.dig("window", "allocs"),
        ruby: meta&.dig("ruby"), yjit: meta&.dig("yjit"), zjit: meta&.dig("zjit") }
      File.open(File.join(out, "runs.jsonl"), "a") { _1.puts JSON.generate(line) }
      warn line.slice(:app, :arm, :round, :wall, :tests, :exit).inspect
    end
  end
end
