# frozen_string_literal: true

require "minitest/autorun"
require_relative "request_pairs"
require_relative "gc_requests"

class RequestPairsTest < Minitest::Test
  def test_memory_attribution_deduplicates_containers_without_following_weak_references
    text = "x" * 512
    array = [text, text]
    array << array
    key, value = Object.new, "y" * 8192
    weak = ObjectSpace::WeakMap.new
    weak[key] = value
    root = { "data" => array, :weak => weak }
    result = RequestMemory.containers([root, array])
    assert_equal({ "Hash" => 1, "Array" => 1, "String" => 2, "ObjectSpace::WeakMap" => 1 }, result[:objects])
    assert_equal [root, root.keys.first, array, text, weak].sum { ObjectSpace.memsize_of(_1) }, result[:bytes]
    assert_same value, weak[key]
  end

  def test_paired_bootstrap_removes_round_drift_but_not_a_real_effect
    rounds = 24.times.map do |i|
      value = 1000.0 + 50 * i
      { "off_a" => { "cpu_us" => value, "wall_us" => value, "allocations" => 100.0 },
        "off_b" => { "cpu_us" => value, "wall_us" => value, "allocations" => 100.0 },
        "slow" => { "cpu_us" => value * 1.125, "wall_us" => value * 1.125, "allocations" => 107.0 } }
    end
    result = RequestPairs.summarize(rounds, seed: 1, tolerance: 2)
    assert result[:aa][:pass]
    assert_equal [0.0, 0.0], result[:layers]["off_b"]["cpu_us"][:delta_pct][:ci95]
    result[:layers]["slow"]["cpu_us"][:delta_pct][:ci95].each { assert_in_delta 12.5, _1, 1e-9 }
    assert_in_delta 7.0, result[:layers]["slow"]["allocations"][:delta_pct][:median], 1e-9
    rounds.each { _1["off_b"]["wall_us"] *= 1.05 }
    refute RequestPairs.summarize(rounds, seed: 1, tolerance: 2)[:aa][:pass]
  end

  def test_wide_control_is_not_equivalence
    rounds = 24.times.map do |i|
      { "off_a" => RequestPairs::METRICS.to_h { [_1, 100.0] },
        "off_b" => RequestPairs::METRICS.to_h { [_1, i.even? ? 90.0 : 110.0] } }
    end
    refute RequestPairs.summarize(rounds, seed: 1, tolerance: 2)[:aa][:pass]
    assert_equal 2.5, RequestPairs.median([1, 2, 3, 8])
  end

  def test_instruction_control_ignores_emulation_time
    rounds = [-0.1, 0.0, 0.1].map do |noise|
      { "off_a" => { "instructions" => 1000.0, "wall_us" => 100.0 },
        "off_b" => { "instructions" => 1000.0 + noise, "wall_us" => 900.0 },
        "fast" => { "instructions" => 875.0, "wall_us" => 1100.0 } }
    end
    result = RequestPairs.summarize(rounds, seed: 1, tolerance: 0.5,
      metrics: ["instructions"], controls: ["instructions"])
    assert result[:aa][:pass]
    assert_in_delta(-12.5, result[:layers]["fast"]["instructions"][:delta_pct][:median], 1e-9)
    rounds.each { _1["off_b"]["instructions"] += 10.0 }
    refute RequestPairs.summarize(rounds, seed: 1, tolerance: 0.5,
      metrics: ["instructions"], controls: ["instructions"])[:aa][:pass]
  end

  def test_repeated_blocks_do_not_hide_process_specific_bias
    cohorts = [-3, -1, 0, 2, 4].map do |bias|
      Array.new(40) do
        { "off_a" => RequestPairs::METRICS.to_h { [_1, 100.0] },
          "off_b" => RequestPairs::METRICS.to_h { [_1, 100.0 + bias] } }
      end
    end
    result = RequestPairs.summarize(cohorts.flatten, cohorts: cohorts, seed: 1, tolerance: 2)
    refute result[:aa][:pass]
    low, high = result[:layers]["off_b"]["cpu_us"][:delta_pct][:ci95]
    assert_in_delta(-3, low, 1e-9)
    assert_in_delta 4, high, 1e-9
  end
end
