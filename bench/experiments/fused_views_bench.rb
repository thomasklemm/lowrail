# frozen_string_literal: true

# Direction finding only: native YJIT, alternating warm workers, in-cohort A/A.
# No Callgrind, fixed-heap claim, published price, or integration gate.
require "json"
require "open3"
require "rbconfig"
require "fileutils"
require "digest"
app, output, route = ARGV
abort "usage: fused_views_bench.rb RETAINED_BLOG NEW_OUTPUT_DIR /articles[/1]" unless app && output && %w[/articles /articles/1].include?(route)
app, output = [app, output].map { File.expand_path(_1) }
abort "new output directory required" if File.exist?(output)
FileUtils.mkdir_p(output, mode: 0o700)
root = File.expand_path("../..", __dir__)
rounds, n = Integer(ENV.fetch("FUSED_ROUNDS", "30")), Integer(ENV.fetch("FUSED_N", "100"))
raise "at least 20 alternating rounds" unless rounds >= 20 && n.positive?
workers, ready, samples = {}, {}, []
rng = Random.new(41231)
def receive(io)
  while (line = io.gets)
    return JSON.parse(line.delete_prefix("FUSED ")) if line.start_with?("FUSED ")
  end
  raise "worker exited; inspect private worker logs"
end
def command(worker, data)
  worker[0].puts(JSON.generate(data))
  worker[0].flush
  receive(worker[1])
end
begin
  %w[off_a off_b fused sealed stacked].shuffle(random: rng).each do |arm|
    sealed = %w[sealed stacked].include?(arm)
    env = {"RAILS_ENV" => "production", "RACK_ENV" => "production", "RAILS_LOG_LEVEL" => "fatal",
      "SECRET_KEY_BASE" => "lowrail-disposable-blog-companion-only-" * 4, "SECRET_KEY_BASE_DUMMY" => nil,
      "RUBY_YJIT_ENABLE" => "1", "RUBY_ZJIT_ENABLE" => "0", "LOWRAIL" => sealed ? "1" : "0",
      "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => sealed ? "1" : nil,
      "RUBYOPT" => sealed ? "-I#{root}/gem/lib -rlowrail/setup" : nil,
      "BUNDLE_GEMFILE" => File.join(app, "Gemfile"), "BUNDLE_FROZEN" => "true"}
    worker = Open3.popen3(env, RbConfig.ruby, "--yjit", File.join(__dir__, "fused_views_worker.rb"), arm, route, chdir: app)
    workers[arm] = worker
    # Drain stderr without retaining cookies, bodies or secret-bearing traces
    # in a public export. Full logs remain in the private output directory.
    worker << Thread.new { File.write(File.join(output, "#{arm}.stderr"), worker[2].read) }
    ready[arm] = receive(worker[1])
    warn "#{arm} warm"
  end
  rounds.times do |round|
    workers.keys.shuffle(random: rng).each do |arm|
      samples << {"round" => round, "arm" => arm, **command(workers.fetch(arm), op: "sample", n: n)}
    end
  end
  gates = workers.to_h { |arm, worker| [arm, command(worker, op: "gate")] }
  reference = gates.fetch("off_a").reject { |key, _| key == "coverage" }
  exact = gates.all? { |_, gate| gate.reject { |key, _| key == "coverage" } == reference }
  groups = samples.group_by { _1.fetch("arm") }
  deltas = %w[off_b fused sealed stacked].to_h do |arm|
    values = rounds.times.map { |i| 100 * (groups.fetch(arm)[i].fetch("wall_us") / groups.fetch("off_a")[i].fetch("wall_us") - 1) }
    bootstrap = Array.new(5000) { Array.new(rounds) { values[rng.rand(rounds)] }.sum.fdiv(rounds) }.sort
    [arm, {"mean_percent" => values.sum.fdiv(rounds), "ci95_percent" => [bootstrap[125], bootstrap[4874]],
      "allocations" => groups.fetch(arm).sum { _1.fetch("allocations") }.fdiv(rounds),
      "gc_us" => groups.fetch(arm).sum { _1.fetch("gc_us") }.fdiv(rounds)}]
  end
  aa = deltas.fetch("off_b").fetch("ci95_percent")
  report = {scope: "native YJIT exploration, not a published price or support claim", route: route,
    rounds: rounds, requests_per_window: n, seed: 41231, ready: ready, samples: samples, deltas: deltas,
    off_allocations: groups.fetch("off_a").sum { _1.fetch("allocations") }.fdiv(rounds),
    aa_pass: aa.first <= 0 && aa.last >= 0 && aa.first >= -2 && aa.last <= 2,
    exact_companion_gate: exact, gates: gates,
    sources: %w[fused_views.rb fused_views_worker.rb fused_views_bench.rb].to_h { [_1, Digest::SHA256.file(File.join(__dir__, _1)).hexdigest] }}
  File.write(File.join(output, "results.json"), JSON.pretty_generate(report))
  puts JSON.pretty_generate(report.reject { |key, _| %i[samples gates ready].include?(key) })
  raise "exact companion gate failed" unless exact
ensure
  workers.each_value do |worker|
    worker[0].close unless worker[0].closed?
    worker[1].read
    worker[3].value
    worker[4].join
  end
end
