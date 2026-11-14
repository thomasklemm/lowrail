# frozen_string_literal: true

require_relative "test_helper"
load File.expand_path("../../script/pr-queue", __dir__)

class PrQueueTest < Minitest::Test
  def item(passes, risky: false)
    { "head" => "bbbbbbbbbb", "risky" => risky, "passes" => passes }
  end

  def pass(reviewer, head, verdict = "approve") = { "reviewer" => reviewer, "head" => head, "verdict" => verdict }

  def test_only_approving_passes_on_the_current_head_count
    old = [pass("claude-code", "aaaaaaaaaa"), pass("sol", "aaaaaaaaaa")]
    assert_equal %w[claude-code sol], PrQueue.missing(item(old), 40)

    current = [pass("claude-code", "bbbbbbbbbb4f1c"), pass("sol", "bbbbbbb", "nits")]
    assert_empty PrQueue.missing(item(old + current), 40)

    assert_equal %w[sol], PrQueue.missing(item(old + current + [pass("sol", "bbbbbbbbbb", "changes")]), 40)
    assert_equal %w[astra], PrQueue.missing(item(current + [pass("astra", "aaaaaaaaaa")], risky: true), 40)
  end

  def test_a_skeptic_pass_does_not_stand_in_for_the_claude_code_review
    assert_equal %w[claude-code], PrQueue.missing(item([pass("skeptic", "bbbbbbbbbb"), pass("sol", "bbbbbbbbbb")]), 40)
  end

  def test_thermos_is_required_above_200_lines_or_when_the_size_is_unknown
    passes = [pass("claude-code", "bbbbbbbbbb"), pass("sol", "bbbbbbbbbb")]
    assert_empty PrQueue.missing(item(passes), 200)
    assert_equal %w[thermos], PrQueue.missing(item(passes), 201)
    assert_equal %w[thermos], PrQueue.missing(item(passes), nil)
  end

  def test_a_thermos_waiver_counts_only_on_the_current_head_with_a_reason
    passes = [pass("claude-code", "bbbbbbbbbb"), pass("sol", "bbbbbbbbbb")]
    waiver = { "reviewer" => "thermos", "head" => "bbbbbbb", "by" => "coordinator", "reason" => "own commit is small" }
    assert_empty PrQueue.missing(item(passes).merge("waived" => [waiver]), 216)
    assert_equal %w[thermos], PrQueue.missing(item(passes).merge("waived" => [waiver.merge("head" => "aaaaaaaaaa")]), 216)
    assert_equal %w[thermos], PrQueue.missing(item(passes).merge("waived" => [waiver.merge("reason" => "")]), 216)
    assert_equal %w[sol], PrQueue.missing(item(passes.first(1)).merge("waived" => [waiver.merge("reviewer" => "sol")]), 40)
  end
end
