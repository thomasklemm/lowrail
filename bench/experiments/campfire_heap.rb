# frozen_string_literal: true

# Off-only calibration, then frozen-floor verification in both phase orders.
# Untimed tool=none only; no Callgrind extension, client requests or counters.
require_relative "campfire_scenario"

mode, n, app, seed, out, valgrind, calibration = ARGV
abort "usage: campfire_heap.rb baseline|verify N APP SEED NEW_OUT VALGRIND [BASELINE_JSON]" unless
  %w[baseline verify].include?(mode) && valgrind && (mode == "baseline" || calibration)
raise "dedicated disposable localhost Redis required" unless ENV["CAMPFIRE_DISPOSABLE_REDIS"] == "1"
n = Integer(n)
raise "positive window size required" unless n.positive?
app, seed, valgrind = [app, seed, valgrind].map { File.realpath(_1) }
out = File.expand_path(out)
raise "new output required" if File.exist?(out)
baseline = JSON.parse(File.read(calibration)) if calibration
floors = baseline ? baseline.fetch("proposed_init_slots") : [1_000_000, 250_000, 100_000, 20_000, 10_000]
raise "five positive floors required" unless floors.size == 5 && floors.all? { Integer === _1 && _1.positive? }
raise "baseline window changed" if baseline && baseline.fetch("requests_per_full_window") != n
prefix = File.expand_path("..", File.dirname(valgrind))
tool = JSON.parse(File.read(File.join(prefix, "share/lowrail/valgrind.json")))
raise "tool pin changed" unless Digest::SHA256.file(File.join(prefix, tool.fetch("tool"))).hexdigest == tool.fetch("tool_sha256")
tool["none_tool_sha256"] = Digest::SHA256.file(File.join(prefix, "libexec/valgrind/none-amd64-linux")).hexdigest
raise "baseline tool changed" if baseline && baseline.fetch("valgrind") != tool
manifest = File.join(app, ".lowrail/manifest.json")
artifact = Digest::SHA256.file(manifest).hexdigest
raise "baseline artifact changed" if baseline && baseline.fetch("artifact_sha256") != artifact
FileUtils.mkdir_p(out, mode: 0o700)
report = {"scope" => "untimed Valgrind tool=none; no timing, Ir or slot", "mode" => mode,
  "requests_per_full_window" => n, "init_slots" => floors, "valgrind" => tool,
  "artifact_sha256" => artifact, "launcher_sha256" => Digest::SHA256.file(__FILE__).hexdigest,
  "calibration_sha256" => calibration && Digest::SHA256.file(calibration).hexdigest, "workers" => {}}
File.write(File.join(out, "protocol.json"), JSON.pretty_generate(report))
require "redis"
arms = mode == "baseline" ? [["off", 0]] : %w[off on].product([0, 1])
arms.each do |arm, order|
  label = "#{arm}-#{order}"
  state = File.join(out, "#{label}-state")
  FileUtils.cp_r(seed, state)
  env = CampfireScenario.environment(app, state).merge("LOWRAIL" => arm == "on" ? "1" : "0",
    "LOWRAIL_SEALED" => "1", "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => File.join(app, ".lowrail"),
    "LOWRAIL_STATS" => File.join(out, "#{label}-stats"), "BENCH_HEAP_SLOTS" => floors.join(","),
    "BENCH_PHASE_ORDER" => order.to_s, "CAMPFIRE_HEAP_REQUESTS" => n.to_s,
    "RUBYOPT" => "-rbundler/setup -I#{CampfireScenario::ROOT}/gem/lib -rlowrail/setup")
  floors.each_with_index { |slots, pool| env["RUBY_GC_HEAP_#{pool}_INIT_SLOTS"] = slots.to_s }
  Redis.new(url: env.fetch("REDIS_URL")).flushdb
  log, vg, destination = %W[#{out}/#{label}.log #{out}/#{label}.valgrind.log #{out}/#{label}.json]
  File.open(log, "w") do |stream|
    ok = system(env, valgrind, "--tool=none", "--log-file=#{vg}", RbConfig.ruby,
      File.join(__dir__, "campfire_scenario.rb"), "heap", app, state, destination,
      chdir: app, out: stream, err: stream)
    raise "worker failed; retain #{log}" unless ok
  end
  raise "brk overflow" if File.read(vg).match?(/brk segment overflow|Cannot map memory to grow brk segment/)
  raise "artifact changed" unless Digest::SHA256.file(manifest).hexdigest == artifact
  worker = JSON.parse(File.read(destination))
  raise "baseline inputs changed" if baseline && worker.fetch("pins") != baseline.fetch("workers").fetch("off-0").fetch("pins")
  violations = worker.fetch("windows").flat_map.with_index do |window, index|
    %w[before after].flat_map do |boundary|
      worker.fetch("targets").filter_map do |pool, target|
        actual = window.fetch(boundary).fetch(pool).fetch("heap_eden_pages")
        {"window" => index, "boundary" => boundary, "pool" => pool, "target" => target, "actual" => actual} unless actual == target
      end
    end
  end
  additions = worker.fetch("windows").map do |window|
    window.fetch("after").to_h { |pool, stats| [pool, stats.fetch("total_allocated_pages") - window.fetch("before").fetch(pool).fetch("total_allocated_pages")] }
  end
  report.fetch("workers")[label] = worker.merge("page_violations" => violations, "new_pages" => additions,
    "log_sha256" => Digest::SHA256.file(log).hexdigest, "valgrind_log_sha256" => Digest::SHA256.file(vg).hexdigest)
  if mode == "baseline"
    budget = (0...5).map do |pool|
      worker.fetch("windows").select { _1.fetch("requests") == n }.map do |window|
        before, after = window.fetch("before").fetch(pool.to_s), window.fetch("after").fetch(pool.to_s)
        before.fetch("heap_live_slots") + after.fetch("total_allocated_objects") - before.fetch("total_allocated_objects")
      end.max
    end
    report["off_whole_window_slot_budget"] = budget
    report["calibration_rule"] = "max(original floor, 1.5 times off-only maximum(start live + all full-window allocations)), rounded up to 10000 slots; unchanged GC/window policy"
    report["proposed_init_slots"] = floors.zip(budget).map { |floor, slots| ([floor, (slots * 3 + 1) / 2].max + 9999) / 10000 * 10000 }
  end
  report["complete"] = report.fetch("workers").size == arms.size
  report["exact_pages_pass"] = report.fetch("complete") && report.fetch("workers").values.all? do |row|
    row.fetch("page_violations").empty? && row.fetch("new_pages").all? { _1.values.all?(&:zero?) }
  end
  File.write(File.join(out, "result.json"), JSON.pretty_generate(report))
end
puts JSON.generate(mode: mode, exact_pages_pass: report.fetch("exact_pages_pass"), init_slots: floors,
  proposed_init_slots: report["proposed_init_slots"], workers: report.fetch("workers").keys, counters_started: false)
exit 2 if mode == "verify" && !report.fetch("exact_pages_pass")
