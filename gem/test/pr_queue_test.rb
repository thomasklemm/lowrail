# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
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

  def test_opus_or_fable_from_another_orb_stands_in_for_sol_and_astra
    claude = pass("claude-code", "bbbbbbbbbb").merge("orb" => "T-a")
    opus = ->(orb, verdict = "approve", head = "bbbbbbbbbb") { pass("opus", head, verdict).merge("orb" => orb) }
    fable = pass("fable", "bbbbbbbbbb").merge("orb" => "T-c")

    assert_empty PrQueue.missing(item([claude, opus.("T-b")]), 40)
    assert_equal %w[sol], PrQueue.missing(item([claude, opus.("T-a")]), 40)
    assert_equal %w[sol], PrQueue.missing(item([claude, opus.(nil)]), 40)
    assert_equal %w[sol], PrQueue.missing(item([claude.except("orb"), opus.("T-b")]), 40)
    assert_equal %w[sol], PrQueue.missing(item([claude, opus.("T-b", "approve", "aaaaaaaaaa")]), 40)
    assert_equal %w[sol], PrQueue.missing(item([claude, opus.("T-b"), opus.("T-b", "changes")]), 40)
    assert_empty PrQueue.missing(item([claude, opus.("T-b", "changes"), opus.("T-b", "nits")]), 40)
    assert_equal %w[thermos], PrQueue.missing(item([claude, opus.("T-b"), fable]), 201)

    assert_equal %w[astra], PrQueue.missing(item([claude, opus.("T-b")], risky: true), 40)
    assert_equal %w[astra], PrQueue.missing(item([claude, opus.("T-b"), fable.merge("orb" => "T-b")], risky: true), 40)
    assert_empty PrQueue.missing(item([claude, opus.("T-b"), fable], risky: true), 40)
    assert_empty PrQueue.missing(item([claude, pass("sol", "bbbbbbbbbb"), fable.merge("orb" => "T-b")], risky: true), 40)
    assert_empty PrQueue.missing(item([claude.except("orb"), pass("sol", "bbbbbbbbbb"), pass("astra", "bbbbbbbbbb")], risky: true), 40)
  end

  def test_a_thermos_waiver_counts_only_on_the_current_head_with_a_reason
    passes = [pass("claude-code", "bbbbbbbbbb"), pass("sol", "bbbbbbbbbb")]
    waiver = { "reviewer" => "thermos", "head" => "bbbbbbb", "by" => "coordinator", "reason" => "own commit is small" }
    assert_empty PrQueue.missing(item(passes).merge("waived" => [waiver]), 216)
    assert_equal %w[thermos], PrQueue.missing(item(passes).merge("waived" => [waiver.merge("head" => "aaaaaaaaaa")]), 216)
    assert_equal %w[thermos], PrQueue.missing(item(passes).merge("waived" => [waiver.merge("reason" => "")]), 216)
    assert_equal %w[sol], PrQueue.missing(item(passes.first(1)).merge("waived" => [waiver.merge("reviewer" => "sol")]), 40)
  end

  def test_diff_facts_name_the_conflicting_files_and_the_base_commits_on_the_pr_files
    Dir.mktmpdir do |dir|
      git = ->(*args) { PrQueue.run("git", "-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", *args) }
      commit = lambda do |files|
        files.each { |path, text| File.write(File.join(dir, path), text) }
        git.("add", "-A")
        git.("commit", "-q", "-m", "c")
        git.("rev-parse", "HEAD").first.strip
      end
      git.("init", "-q", "-b", "main")
      built_on = commit.({ "CHANGELOG.md" => "old\n", "lib.rb" => "a\n", "other.rb" => "x\n", "test.rb" => "t\n" })
      git.("checkout", "-q", "-b", "pr")
      commit.({ "CHANGELOG.md" => "ours\nold\n", "lib.rb" => "b\n" })
      git.("checkout", "-q", "main")
      commit.({ "other.rb" => "y\n" })
      commit.({ "test.rb" => "u\n" })

      fact = PrQueue.diff_facts(git, "main", "pr", built_on)
      assert_equal [true, [], 0, []], fact.values_at(:clean, :conflicts, :base_commits, :base_files)
      assert_equal "clean", PrQueue.merge_label(fact, "CONFLICTING")

      commit.({ "CHANGELOG.md" => "theirs\nold\n" })
      fact = PrQueue.diff_facts(git, "main", "pr", built_on)
      assert_equal [["CHANGELOG.md"], 1, ["CHANGELOG.md"]], fact.values_at(:conflicts, :base_commits, :base_files)
      assert_equal "CHANGELOG-only", PrQueue.merge_label(fact, nil)

      commit.({ "lib.rb" => "c\n" })
      fact = PrQueue.diff_facts(git, "main", "pr", built_on)
      assert_equal [%w[CHANGELOG.md lib.rb], 2], fact.values_at(:conflicts, :base_commits)
      assert_equal "CONFLICT", PrQueue.merge_label(fact, nil)
      assert_equal 2, PrQueue.diff_facts(git, "main", "pr", "").fetch(:base_commits)
      assert_nil PrQueue.diff_facts(git, "main", "pr", "0000000000").fetch(:base_commits)
    end
  end

  def test_without_a_fetched_branch_the_merge_state_comes_from_github
    assert_equal "CONFLICT(gh)", PrQueue.merge_label({ error: "fetch: denied" }, "CONFLICTING")
    assert_equal "clean(gh)", PrQueue.merge_label(nil, "MERGEABLE")
    assert_equal "", PrQueue.merge_label(nil, "UNKNOWN")
  end
end
