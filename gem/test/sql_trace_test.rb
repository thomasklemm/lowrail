# frozen_string_literal: true

require_relative "test_helper"

# Per-test SQL traces (LOWRAIL_OUTCOMES): equal outcomes with different
# queries must show up as a trace difference, while run-to-run noise (bind
# values, schema setup, connection PRAGMAs) must not.
class SqlTraceTest < Minitest::Test
  include LowrailTest

  SUITE = <<~'RUBY'
    gem "activerecord", "~> 8.1.4"
    require "active_record"
    require "minitest/autorun"
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define { create_table(:items) { |t| t.string :name; t.integer :rank } }
    class Item < ActiveRecord::Base; end

    class ItemTest < Minitest::Test
      def test_lookup
        Item.create!(name: "t-#{rand(1_000_000)}", rank: 1) # bind value differs per run
        # Same result either way, different query: what a wrong lowering looks like.
        found = ENV["VARIANT"] == "b" ? Item.where(rank: 1).to_a : Item.where("rank = 1").to_a
        assert_equal 1, found.size
      ensure
        Item.delete_all
      end

      def test_cached
        Item.cache { 2.times { Item.where(rank: 2).to_a } }
        assert true
      end

      def test_no_sql = assert(true)
    end
  RUBY

  def run_suite(dir, env = {})
    File.write(File.join(dir, "item_test.rb"), SUITE)
    path = File.join(dir, "outcomes.json")
    FileUtils.rm_f(Dir[File.join(dir, "outcomes.json*")])
    _out, err, status = ruby("item_test.rb", chdir: dir, env: { "LOWRAIL_OUTCOMES" => path }.merge(env))
    skip "install activerecord 8.1.4 and sqlite3 to run SQL trace tests" if err.include?("Could not find 'activerecord'")
    assert status.success?, err
    JSON.parse(File.read(path)).fetch("sql")
  end

  def test_trace_detects_changed_queries_not_bind_values
    realpath_tmpdir do |dir|
      a1 = run_suite(dir)
      a2 = run_suite(dir)
      b = run_suite(dir, "VARIANT" => "b")
      assert_equal a1["ItemTest#test_lookup"]["digest"], a2["ItemTest#test_lookup"]["digest"], "bind values must not matter"
      refute_equal a1["ItemTest#test_lookup"]["digest"], b["ItemTest#test_lookup"]["digest"]
      assert_equal a1["ItemTest#test_cached"].slice("digest", "n"), b["ItemTest#test_cached"].slice("digest", "n")
      assert_equal 0, a1["ItemTest#test_no_sql"]["n"]
    end
  end

  def test_full_trace_lines
    realpath_tmpdir do |dir|
      lines = run_suite(dir, "LOWRAIL_SQL_TRACE" => "full", "VARIANT" => "b")["ItemTest#test_cached"]["lines"]
      loads = lines.grep(/\AItem Load\t/)
      assert_equal 2, loads.size, lines.join("\n")
      assert_equal ["", "cached"], loads.map { _1.split("\t")[3] }
      assert_includes loads.first, "rank:Integer"
    end
  end

  def test_disabled
    realpath_tmpdir do |dir|
      assert_equal({}, run_suite(dir, "LOWRAIL_SQL_TRACE" => "0"))
    end
  end
end
