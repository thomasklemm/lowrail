# frozen_string_literal: true

require "minitest/autorun"
require_relative "ar_profile_summary"
require_relative "ar_survey"

class ARDiagnosticsTest < Minitest::Test
  def test_nested_boundaries_are_not_added_or_counted_twice
    profile = {
      "frames" => {
        "1" => { "name" => "App#request", "file" => "app.rb" },
        "2" => { "name" => "ActiveRecord::QueryMethods#build_arel", "file" => "query_methods.rb" },
        "3" => { "name" => "Arel::Visitors::ToSql#visit", "file" => "to_sql.rb" },
        "4" => { "name" => "ActiveRecord::ConnectionAdapters::SQLite3Adapter#raw_execute", "file" => "database_statements.rb" },
        "5" => { "name" => "ActiveRecord::Persistence#instantiate", "file" => "persistence.rb" },
        "6" => { "name" => "ActiveRecord::Associations::Preloader#call", "file" => "/active_record/associations/preloader.rb" },
        "7" => { "name" => "(sweeping)", "file" => "" }
      },
      "raw" => [4, 1, 2, 3, 3, 2, 3, 1, 6, 4, 7, 3, 1, 6, 5, 11, 2, 1, 7, 5]
    }
    result = ARProfileSummary.summarize(profile)
    assert_equal 25, result.fetch(:samples)
    categories = result.fetch(:categories)
    assert_equal 25, categories.values.sum { _1.fetch(:deepest_samples) }
    assert_equal 2, categories.fetch("sql_building_arel").fetch(:inclusive_samples)
    assert_equal 18, categories.fetch("association_loading").fetch(:inclusive_samples)
    assert_equal 0, categories.fetch("association_loading").fetch(:deepest_samples)
    assert_equal 7, categories.fetch("execution").fetch(:deepest_samples)
    assert_equal 11, categories.fetch("types_instantiation").fetch(:deepest_samples)
    assert_equal 2, result.fetch(:boundaries).fetch("build_arel_and_visitors").fetch(:samples)
  end

  def test_survey_does_not_turn_fixed_keys_into_certified_queries
    source = <<~RUBY
      Model.find_by(id: key)
      owner.children.where(state: value).order(:id)
      where(id: [1, 4])
      Model.where("id > ?", key)
      Model.where(**filters)
      owner.children.where.not(id: key)
      records.select { it.enabled? }
    RUBY
    parsed = Prism.parse(source, version: "current")
    assert parsed.success?
    visitor = Lowrail::ARPlanSites.new("app/models/example.rb")
    visitor.visit(parsed.value)
    sites = visitor.ledger
    assert_equal 8, sites.size
    assert_equal 1, sites.count { _1.fetch(:outcome).start_with?("existing Rails StatementCache") }
    assert_equal 2, sites.count { _1.fetch(:outcome).start_with?("not certified:") }
    assert_equal 1, sites.count { _1.fetch(:shape) == "array/range/nested predicate" }
    assert_equal 1, sites.count { _1.fetch(:shape) == "nonconstant/nested keys or splat" }
    assert_equal 1, sites.count { _1.fetch(:shape).start_with?("WhereChain") }
    refute sites.any? { _1.fetch(:outcome) == "lowered" }
  end
end
