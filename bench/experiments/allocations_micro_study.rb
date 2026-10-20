# frozen_string_literal: true

# Reuse the public lowrail bench instruction/budget seam, not another counter.
require_relative "../request_pairs"

root = File.expand_path("../..", __dir__)
out = File.expand_path(ARGV.fetch(0))
raise "new output required" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
all_passed = true
groups = { "blog" => "real-blog-r4", "props" => "react-starter-kit", "frozen" => "redprints-alloc-r4" }
groups.select! { |name, _| ARGV.drop(1).include?(name) } if ARGV.size > 1
groups.each do |group, directory|
  dir = File.join(out, group)
  FileUtils.mkdir_p(dir, mode: 0o700)
  app = File.join(ENV.fetch("BENCH_CORPUS_ROOT", File.join(root, ".corpus")), directory)
  base = { "LOWRAIL" => "0", "RUBYOPT" => nil, "RAILS_ENV" => "production",
    "RAILS_LOG_LEVEL" => "error", "SECRET_KEY_BASE_DUMMY" => "1", "ALLOC_MICRO_APP" => group }
  environments = %w[off_a off_b on].to_h do |arm|
    [arm, base.merge("ALLOC_MICRO_ARM" => arm == "on" ? "on" : "off")]
  end
  metadata = { seed: 41231, rounds: 6, workers: {},
    lockfile_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest }
  passed = RequestPairs.heap_instructions(environments, app, dir, "GET:/unused", metadata,
    worker: File.join(__dir__, "allocations_micro.rb"), requests: 1000)
  samples = JSON.parse(File.read(File.join(dir, "samples.json"))).fetch("samples")
  units = samples.first.fetch("off_a").fetch("operations").keys
  budgets = units.to_h do |unit|
    per_unit = samples.map do |round|
      round.to_h do |arm, row|
        windows = row.fetch("windows").select { _1.fetch("unit") == unit && _1.fetch("mode") == "total" }
        empty, full = windows.sort_by { _1.fetch("requests") }
        allocation_delta = [empty, full].map { _1.fetch("after").fetch("total_allocated_objects") - _1.fetch("before").fetch("total_allocated_objects") }
        [arm, row.fetch("operations").fetch(unit).merge("allocations" => (allocation_delta[1] - allocation_delta[0]) / 1000.0)]
      end
    end
    summary = RequestPairs.summarize(per_unit, seed: 41231, tolerance: 0.5,
      metrics: %w[instructions_total instructions_no_gc allocations], controls: %w[instructions_total instructions_no_gc])
    summary[:saving_per_call] = %w[instructions_total instructions_no_gc allocations].to_h do |metric|
      [metric, RequestPairs.estimate(per_unit.map { _1.fetch("off_a").fetch(metric) - _1.fetch("on").fetch(metric) }, seed: 41231)]
    end
    passed &&= summary.fetch(:aa).fetch(:pass)
    [unit, summary]
  end
  File.write(File.join(dir, "budgets.json"), JSON.pretty_generate(accepted: passed, units: budgets))
  all_passed &&= passed
end
exit(all_passed ? 0 : 2)
