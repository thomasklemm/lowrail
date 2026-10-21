# frozen_string_literal: true

# Untimed heap calibration/verification only. Always tool=none: no Ir counter,
# cohort, comparison, retry-to-green or app change. Worker code is loaded from
# the explicitly pinned clean detached harness, not this launcher's checkout.
require "json"
require "digest"
require "fileutils"
require "rbconfig"

mode, n, app, seed, artifact, contexts, hits, harness, sha, out, calibration = ARGV
abort "usage: fizzy_link_heap.rb baseline|verify N APP SEED ARTIFACT CONTEXTS HITS HARNESS SHA NEW_OUT [BASELINE_JSON]" unless
  %w[baseline verify].include?(mode) && out && (mode == "baseline" || calibration)
n = Integer(n)
raise "positive window size required" unless n.positive?
phase = ENV.fetch("BENCH_PHASE_ORDER", "0")
raise "phase order must be 0 or 1" unless %w[0 1].include?(phase)
app, seed, artifact, contexts, hits, harness = [app, seed, artifact, contexts, hits, harness].map { File.realpath(_1) }
out = File.expand_path(out)
raise "new output required" if File.exist?(out)
require File.join(harness, "bench/request_pairs")
require File.join(harness, "bench/experiments/fizzy_link_vector")
FileUtils.mkdir_p(out, mode: 0o700)
expected = JSON.parse(File.read(hits))
raise "closed warm map required" unless expected.size == 23 && expected.values.sum == 24 && expected.values.count(&:zero?) == 4
baseline = JSON.parse(File.read(calibration)) if mode == "verify"
raise "baseline window changed" if baseline && baseline.fetch("vectors_per_full_window") != n
floors = baseline ? baseline.fetch("proposed_init_slots") : [1_000_000, 250_000, 100_000, 20_000, 10_000]
raise "five positive floors required" unless floors.size == 5 && floors.all? { _1.is_a?(Integer) && _1.positive? }
extension = RequestPairs.compile_counter_extension(out)
executable = ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { File.join(_1, "valgrind") }.find { File.executable?(_1) }
prefix = File.expand_path("..", File.dirname(File.realpath(executable)))
tool = JSON.parse(File.read(File.join(prefix, "share/lowrail/valgrind.json")))
raise "Callgrind tool pin changed" unless Digest::SHA256.file(File.join(prefix, tool.fetch("tool"))).hexdigest == tool.fetch("tool_sha256")
tool["none_tool_sha256"] = Digest::SHA256.file(File.join(prefix, "libexec/valgrind/none-amd64-linux")).hexdigest
raise "baseline tool changed" if baseline && baseline.fetch("valgrind") != tool
probe = {"scope" => "untimed Valgrind tool=none; no cohort or instruction counts", "mode" => mode,
  "launcher_sha256" => Digest::SHA256.file(__FILE__).hexdigest, "harness_sha" => sha,
  "valgrind" => tool, "init_slots" => floors, "vectors_per_full_window" => n, "phase_order" => phase.to_i,
  "calibration_sha256" => calibration && Digest::SHA256.file(calibration).hexdigest, "workers" => {}}
File.write(File.join(out, "protocol.json"), JSON.pretty_generate(probe) + "\n")
arms = mode == "baseline" ? ["off"] : %w[off on]
arms.each do |arm|
  state = File.join(out, "#{arm}-state")
  FileUtils.cp_r(seed, state)
  env = FizzyLinkFixture.environment(app, state).merge(
    "BENCH_HARNESS_SHA" => sha, "BENCH_BLOCK_LINK_COHORT_APPROVED" => sha,
    "BENCH_FIZZY_WARM_HITS" => hits, "BENCH_JIT" => "0", "BENCH_PHASE_ORDER" => phase,
    "BENCH_REQUESTS" => n.to_s, "BENCH_CALLGRIND_EXTENSION" => extension,
    "BENCH_HEAP_SLOTS" => floors.join(","), "BENCH_IDLE_CENSUS" => nil, "BENCH_YJIT_LOG_FILE" => nil)
  floors.each_with_index { |slots, pool| env["RUBY_GC_HEAP_#{pool}_INIT_SLOTS"] = slots.to_s }
  log = File.join(out, "#{arm}.log")
  vg = File.join(out, "#{arm}.valgrind.log")
  ok = system(env, "valgrind", "--tool=none", "--log-file=#{vg}",
    RbConfig.ruby, "--disable-yjit", "--disable-zjit", File.join(harness, "bench/experiments/fizzy_link_vector.rb"),
    "heap", app, state, artifact, contexts, arm, chdir: app, out: log, err: [:child, :out])
  raise "untimed worker failed; inspect #{log}" unless ok
  raise "brk overflow" if File.read(vg).match?(/brk segment overflow|Cannot map memory to grow brk segment/)
  line = File.readlines(log).find { _1.start_with?("LOWRAIL_BENCH ") }
  worker = JSON.parse(line.to_s.delete_prefix("LOWRAIL_BENCH "))
  raise "interpreter/pin mismatch" unless worker.fetch("pins").fetch("harness_sha") == sha &&
    worker.fetch("yjit") == false && worker.fetch("zjit") == false
  raise "baseline inputs changed" if baseline && worker.fetch("pins") != baseline.fetch("workers").fetch("off").fetch("pins")
  raise "closed mix changed" unless worker.fetch("vector_ledgers").size == 4 && worker.fetch("vector_ledgers").all? do |ledger|
    count = ledger.fetch("vectors")
    [0, n].include?(count) && ledger.fetch("completed_hits") == expected.transform_values { arm == "on" ? _1 * count : 0 }
  end
  violations = worker.fetch("windows").flat_map.with_index do |window, index|
    %w[pools_before pools_after].flat_map do |boundary|
      worker.fetch("heap_page_targets").filter_map do |pool, target|
        actual = window.fetch(boundary).fetch(pool).fetch("heap_eden_pages")
        {"window" => index, "mode" => window.fetch("mode"), "vectors" => window.fetch("requests"),
          "boundary" => boundary, "pool" => pool, "target" => target, "actual" => actual} unless actual == target
      end
    end
  end
  additions = worker.fetch("windows").map do |window|
    window.fetch("pools_after").to_h do |pool, stats|
      [pool, stats.fetch("total_allocated_pages") - window.fetch("pools_before").fetch(pool).fetch("total_allocated_pages")]
    end
  end
  probe.fetch("workers")[arm] = worker.merge("heap_page_violations" => violations,
    "new_eden_pages_per_window" => additions,
    "log_sha256" => Digest::SHA256.file(log).hexdigest, "valgrind_log_sha256" => Digest::SHA256.file(vg).hexdigest)
  if mode == "baseline"
    # Budget the entire finite window as if no object were collected, rather
    # than multiplying post-collection capacity. Add 50% explicit headroom.
    # Exact before/after page gates still reject growth; never learn per arm.
    budget = (0...5).map do |pool|
      worker.fetch("windows").select { _1.fetch("requests") == n }.map do |w|
        before, after = w.fetch("pools_before").fetch(pool.to_s), w.fetch("pools_after").fetch(pool.to_s)
        before.fetch("heap_live_slots") + after.fetch("total_allocated_objects") - before.fetch("total_allocated_objects")
      end.max
    end
    probe["calibration_rule"] = "max(original floor, 1.5 times off-only maximum(start live + all full-window allocations)), rounded up to 10000 slots; unchanged GC/window policy"
    probe["off_whole_window_slot_budget"] = budget
    probe["proposed_init_slots"] = floors.zip(budget).map { |floor, slots| ([floor, (slots * 3 + 1) / 2].max + 9999) / 10000 * 10000 }
  end
  probe["complete"] = probe.fetch("workers").keys == arms
  probe["exact_pages_pass"] = probe.fetch("complete") && probe.fetch("workers").values.all? do |worker|
    worker.fetch("heap_page_violations").empty? && worker.fetch("new_eden_pages_per_window").all? { _1.values.all?(&:zero?) }
  end
  File.write(File.join(out, "result.json"), JSON.pretty_generate(probe) + "\n")
end
puts JSON.generate(mode: mode, exact_pages_pass: probe.fetch("exact_pages_pass"), init_slots: floors,
  proposed_init_slots: probe["proposed_init_slots"], workers: probe.fetch("workers").keys, counters_started: false)
exit 2 if mode == "verify" && !probe.fetch("exact_pages_pass")
