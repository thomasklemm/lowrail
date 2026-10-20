# frozen_string_literal: true

require "minitest/autorun"
require_relative "request_pairs"

class RequestPairsTest < Minitest::Test
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
