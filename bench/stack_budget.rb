# frozen_string_literal: true

require_relative "request_pairs"

# Budgets are measurements, not fitted to the request result. Each array index
# is one independent replicate across ALL supplied operations/models; resample
# that vector together to retain shared-control covariance.
module StackBudget
  def self.count_fields(entry)
    case entry.fetch("count_kind", "hit")
    when "hit" then %w[hits_per_iteration completed_hits_per_request_samples]
    when "invocation" then %w[invocations_per_iteration invocations_per_request_samples]
    else raise "unknown budget count kind"
    end
  end

  def self.validate!(data, result, units)
    raise "unsupported budget schema" unless data.fetch("schema_version") == 1
    %w[manifest_sha256 runtime_fingerprint_sha256 request_context_sha256 route].each do |key|
      raise "budget #{key} mismatch" unless data.fetch(key) == result.fetch(key.to_sym)
    end
    if data["harness_fingerprint_sha256"]
      raise "budget harness mismatch" unless data.fetch("harness_fingerprint_sha256") == result.fetch(:harness_fingerprint_sha256)
    end
    raise "budget JIT mismatch" unless data.fetch("yjit") == result.fetch(:coverage).fetch("yjit")
    allowed = result.fetch(:counter) == "native" ? %w[wall_us cpu_us] : %w[instructions_total instructions_no_gc]
    metric = data.fetch("metric")
    raise "budget metric mismatch" unless allowed.include?(metric)
    entries = data.fetch("units")
    raise "budget needs distinct unit IDs" unless !entries.empty? && entries.map { _1.fetch("id") }.uniq.size == entries.size
    lengths = entries.map { _1.fetch("samples").size }.uniq
    raise "budget needs at least six aligned independent replicates" unless lengths.one? && lengths.first >= 6
    entries.each do |entry|
      unit = units.find { _1.fetch("id") == entry.fetch("id") }
      raise "budget unit/pass mismatch" unless unit && unit.fetch("pass") == entry.fetch("pass")
      if unit["ar_instantiate"]
        raise "budget model mismatch" unless entry.fetch("model") == unit.fetch("ar_instantiate").fetch("model")
      end
      raise "budget must include guard and provenance" unless entry.fetch("guard_included") == true && !entry.fetch("source").empty?
      denominator, frequency_key = count_fields(entry)
      hits = entry.fetch(denominator)
      raise "budget needs positive counted hits/iteration" unless hits.is_a?(Numeric) && hits.finite? && hits.positive?
      rows = entry.fetch("samples").map do |row|
        %w[off_a off_b on].to_h do |layer|
          value = row.fetch(layer)
          raise "budget costs must be finite and positive" unless value.is_a?(Numeric) && value.finite? && value.positive?
          [layer, { metric => value }]
        end
      end
      control = RequestPairs.summarize(rows, seed: 41231, tolerance: result.fetch(:counter) == "native" ? 2 : 0.5,
        metrics: [metric], controls: [metric])
      raise "budget unit #{unit.fetch('id')} A/A failed" unless control.fetch(:aa).fetch(:pass)
      frequency = entry[frequency_key]
      if frequency
        raise "budget completion frequencies must align and be nonnegative" unless frequency.size == lengths.first &&
          frequency.all? { _1.is_a?(Numeric) && _1.finite? && _1 >= 0 }
      elsif entry["count_kind"] == "invocation" || !%w[active_record/instantiate active_record/preload_plans active_record/ar_plans inertia/config_bind].include?(unit.fetch("pass"))
        raise "source budgets need completed_hits_per_request_samples; guard hits are not completions"
      end
      if entry["count_kind"] == "invocation"
        completions = entry.fetch("completed_hits_per_request_samples")
        raise "completion counts must align and not exceed invocations" unless completions.size == frequency.size &&
          completions.zip(frequency).all? { |completed, calls| completed.is_a?(Numeric) && completed.finite? && completed >= 0 && completed <= calls }
      end
    end
    data
  end

  def self.report(raw, result, budget, default_passes, seed:)
    cohorts = raw["cohorts"] ? raw.fetch("cohorts").map { _1.fetch("samples") } : raw.fetch("samples").map { [_1] }
    metrics = result.fetch(:counter) == "native" ? %w[cpu_us wall_us] : %w[instructions_total instructions_no_gc]
    units = budget ? budget.fetch("units") : []
    frequencies = result.fetch(:coverage).fetch("units").to_h { [_1.fetch("id"), _1.fetch("hits_per_request")] }
    contributions = units.to_h do |entry|
      denominator, frequency_key = count_fields(entry)
      [entry.fetch("id"), entry.fetch("samples").each_with_index.map do |row, i|
        saved = (row.fetch("off_a") - row.fetch("on")).fdiv(entry.fetch(denominator))
        frequency = entry[frequency_key]&.fetch(i) || frequencies.fetch(entry.fetch("id"))
        saved * frequency
      end]
    end
    modeled = units.map { _1.fetch("id") }
    output = { budget_status: budget ? "supplied" : "not_supplied",
      metric: budget && budget.fetch("metric"),
      removed_default_passes: default_passes - result.fetch(:passes, default_passes),
      unmodeled_unit_ids: frequencies.select { |id, n| n.positive? && !modeled.include?(id) }.keys,
      unmodeled_fallback_unit_ids: result.fetch(:coverage).fetch("units").select do |unit|
        unit.fetch("fallbacks_per_request", 0).positive? && !units.any? { _1.fetch("id") == unit.fetch("id") && _1["count_kind"] == "invocation" }
      end.map { _1.fetch("id") },
      units: units.map do |entry|
        denominator, frequency_key = count_fields(entry)
        invocation = entry["count_kind"] == "invocation"
        samples = entry.fetch("samples").map { (_1.fetch("off_a") - _1.fetch("on")).fdiv(entry.fetch(denominator)) }
        { id: entry.fetch("id"), pass: entry.fetch("pass"), model: entry["model"], source: entry.fetch("source"),
          guard_included: true, count_kind: invocation ? "invocation" : "hit",
          (invocation ? :saved_per_invocation : :saved_per_hit) => RequestPairs.estimate(samples, seed: seed),
          (invocation ? :invocations_per_request : :hits_per_request) => entry[frequency_key] || frequencies.fetch(entry.fetch("id")),
          completed_hits_per_request: entry["completed_hits_per_request_samples"],
          expected_saved_per_request: RequestPairs.estimate(contributions.fetch(entry.fetch("id")), seed: seed) }
      end }
    stacked = cohorts.first.first.key?("stacked")
    measured = stacked ? "stacked" : "default"
    references = stacked ? { "no_setup" => "off_a", "default" => "default" } : { "no_setup" => "off_a" }
    output[:comparisons] = references.to_h do |label, reference|
      relevant = units.reject { label == "default" && default_passes.include?(_1.fetch("pass")) }
      [label, metrics.to_h do |metric|
        saved = cohorts.map { |rows| RequestPairs.median(rows.map { _1.fetch(reference).fetch(metric) - _1.fetch(measured).fetch(metric) }) }
        pct = cohorts.map { |rows| RequestPairs.median(rows.map { 100 * (_1.fetch(measured).fetch(metric).fdiv(_1.fetch(reference).fetch(metric)) - 1) }) }
        comparison = { measured_saved_per_request: RequestPairs.estimate(saved, seed: seed), delta_pct: RequestPairs.estimate(pct, seed: seed) }
        if budget && budget.fetch("metric") == metric && (!relevant.empty? || output.fetch(:unmodeled_unit_ids).empty?)
          series = relevant.map { contributions.fetch(_1.fetch("id")) }
          expected = series.sum { RequestPairs.median(_1) }
          replicates = units.first.fetch("samples").size
          rng = Random.new(seed)
          expected_draws, residual_draws = Array.new(5000) do
            indices = Array.new(replicates) { rng.rand(replicates) }
            predicted = series.sum { |values| RequestPairs.median(indices.map { values.fetch(_1) }) }
            observed = RequestPairs.median(Array.new(saved.size) { saved.fetch(rng.rand(saved.size)) })
            [predicted, observed - predicted]
          end.transpose
          bounds = ->(values) { sorted = values.sort; [sorted[125], sorted[4875]] }
          comparison[:sum_individual_expected_saved_per_request] = { median: expected, ci95: bounds.call(expected_draws) }
          comparison[:measured_minus_expected] = { median: RequestPairs.median(saved) - expected, ci95: bounds.call(residual_draws) }
        end
        [metric, comparison]
      end]
    end
    output
  end
end
