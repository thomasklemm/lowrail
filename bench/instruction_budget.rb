# frozen_string_literal: true

require_relative "request_pairs"

module InstructionBudget
  def self.run(app, out, env, route, result, units)
    raise "automatic budgets require interpreter Callgrind" unless result.fetch(:counter) == "callgrind" && env.fetch("BENCH_JIT") == "0"
    FileUtils.mkdir_p(out, mode: 0o700)
    rounds = Integer(ENV.fetch("BENCH_MICRO_ROUNDS", "6"))
    raise "budgets need at least six independent rounds" if rounds < 6
    environments = %w[off_a off_b on].to_h do |arm|
      [arm, env.merge("LOWRAIL_STATS" => nil, "BENCH_OPERATION_ARM" => arm)]
    end
    metadata = { seed: Integer(ENV.fetch("BENCH_SEED", "41231")), rounds: rounds, workers: {} }
    accepted = RequestPairs.heap_instructions(environments, app, out, route, metadata, worker: "heap_operations.rb",
      requests: Integer(ENV.fetch("BENCH_MICRO_ITERATIONS", "200")))
    raw = JSON.parse(File.read(File.join(out, "samples.json")))
    data = { "schema_version" => 1, "metric" => "instructions_total", "yjit" => false,
      "units" => [], "unmodeled" => [] }
    %w[manifest_sha256 runtime_fingerprint_sha256 request_context_sha256 harness_fingerprint_sha256 route].each { data[_1] = result.fetch(_1.to_sym) }
    ids = raw.fetch("workers").values.first.fetch("operations").keys
    raise "operation coverage changed between workers" unless raw.fetch("workers").values.all? { _1.fetch("operations").keys.sort == ids.sort }
    ids.map { Integer(_1) }.sort.each do |id|
      unit = units.find { _1.fetch("id") == id }
      counted = rounds.times.map { raw.fetch("workers").fetch("#{_1}-on").fetch("operations").fetch(id.to_s) }
      counts = raw.fetch("workers").values.map { _1.fetch("operations").fetch(id.to_s).fetch("invocations_per_iteration") }.uniq
      raise "operation shape changed between workers: #{id}" unless counts.one?
      if counted.any? do |entry|
          entry.fetch("completed_hits_per_iteration") * entry.fetch("invocations_per_request") !=
            entry.fetch("completed_hits_per_request") * entry.fetch("invocations_per_iteration")
        end
        data.fetch("unmodeled") << { "id" => id, "pass" => unit.fetch("pass"),
          "reason" => "replay completion mix differs from warmed request; cannot price changing cache inputs exactly" }
        next
      end
      controls = RequestPairs.summarize(raw.fetch("samples").map do |row|
        row.to_h { |arm, values| [arm, values.fetch("operations").fetch(id.to_s)] }
      end, seed: metadata.fetch(:seed), tolerance: 0.5,
        metrics: %w[instructions_total instructions_no_gc], controls: %w[instructions_total instructions_no_gc])
      accepted &&= controls.fetch(:aa).fetch(:pass)
      entry = { "id" => id, "pass" => unit.fetch("pass"), "guard_included" => true,
        "aa" => controls.fetch(:aa),
        "source" => File.join(out, "samples.json"), "count_kind" => "invocation",
        "invocations_per_iteration" => counts.first,
        "invocations_per_request_samples" => counted.map { _1.fetch("invocations_per_request") },
        "completed_hits_per_request_samples" => counted.map { _1.fetch("completed_hits_per_request") },
        "samples" => raw.fetch("samples").map do |row|
          %w[off_a off_b on].to_h { |arm| [arm, row.fetch(arm).fetch("operations").fetch(id.to_s).fetch("instructions_total")] }
        end }
      if counted.all? { _1.fetch("completed_hits_per_iteration") == counts.first && _1.fetch("completed_hits_per_request") == _1.fetch("invocations_per_request") }
        entry["count_kind"] = "hit"
        entry["hits_per_iteration"] = entry.delete("invocations_per_iteration")
        entry.delete("invocations_per_request_samples")
      end
      data.fetch("units") << entry
    end
    units.each do |unit|
      next if ids.include?(unit.fetch("id").to_s)
      coverage = result.fetch(:coverage).fetch("units").find { _1.fetch("id") == unit.fetch("id") }
      next unless coverage.fetch("hits_per_request").positive? || coverage.fetch("fallbacks_per_request").positive?
      data.fetch("unmodeled") << { "id" => unit.fetch("id"), "pass" => unit.fetch("pass"),
        "reason" => "no exact operation capture on this request; runtime/model adapters remain per-pass" }
    end
    File.write(File.join(out, "budget.json"), JSON.pretty_generate(data) + "\n")
    raise "instruction budget A/A or heap gates failed; inspect #{out}" unless accepted
    data
  end
end
