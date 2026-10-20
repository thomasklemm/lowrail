# frozen_string_literal: true

require_relative "test_helper"

class AREquivalenceTest < Minitest::Test
  include LowrailTest

  PRELUDE = <<~RUBY
    require #{File.expand_path('../../bench/ar_equivalence', __dir__).inspect}
    require "lowrail/ar_shadow"
    AREquivalence.schema
  RUBY

  def test_all_passes_compose_and_shadow_preserves_queries_cache_records_and_callbacks
    scenario = PRELUDE + <<~'RUBY'
      $callbacks = 0
      EqPost.after_find { $callbacks += 1 }
      built = Lowrail::AREquivalenceRuntime.build
      all_events = []
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        # Include SCHEMA too: shadow must not emit even diagnostic events.
        all_events << [payload[:name], payload[:sql],
          payload[:binds].map { Lowrail::ARShadow.bind(_1) }, !!payload[:cached]]
      end
      results = [
        { "base" => "EqWriter.find(1).preferred_posts", "ops" => [], "end" => "to_a", "cache" => true },
        { "base" => "EqWriter.all", "ops" => ["preload(posts: :notes)"], "end" => "to_a", "cache" => true }
      ].map { AREquivalence.execute(_1, "boot").first }
      ActiveSupport::Notifications.unsubscribe(subscription)
      puts JSON.generate({ "results" => results, "all_events" => all_events, "callbacks" => $callbacks,
        "hits" => Lowrail::Stats.unit_hits.group_by { |id, _| built[:manifest].units[id.to_i]["pass"] }.transform_values { _1.sum(&:last) },
        "checks" => Lowrail::ARShadow.counts })
    RUBY
    outputs = [["0", "strict"], ["1", "0"], ["1", "strict"]].map do |mode, shadow|
      ruby_json(scenario, setup: false, env: { "RUBYLIB" => GEM_LIB, "LOWRAIL" => mode, "LOWRAIL_SHADOW" => shadow })
    end
    off, on, shadow = outputs
    %w[active_record/ar_plans active_record/preload_plans active_record/instantiate].each do |pass|
      assert_operator on.fetch("hits").fetch(pass, 0), :>, 0, pass
    end
    %w[active_record/ar_plans active_record/preload_plans active_record/instantiate].each do |pass|
      assert_operator shadow.fetch("checks").fetch(pass, 0), :>, 0, pass
    end
    outputs.each { _1.delete("hits"); _1.delete("checks") }
    assert_equal off, on
    assert_equal off, shadow
    assert_operator off.fetch("callbacks"), :>, 0
    assert off.fetch("results").any? { _1.fetch("sql").any? { |event| event.last } }
  end

  def test_unsupported_model_metadata_is_recorded_without_aborting_other_units
    output = ruby_json(PRELUDE + <<~'RUBY', setup: false, env: { "RUBYLIB" => GEM_LIB, "LOWRAIL" => "1" })
      class EqUnavailable < ActiveRecord::Base
        def self.table_name = raise(ArgumentError, "metadata unavailable")
      end
      reflection = ActiveRecord::Reflection::AssociationReflection.new(:undefined, nil, { class_name: "EqPost" }, EqWriter)
      ActiveRecord::Reflection.add_reflection(EqWriter, :undefined, reflection)
      built = Lowrail::AREquivalenceRuntime.build
      puts JSON.generate([built[:manifest].units.map { _1["pass"] }.uniq, built[:ledger]])
    RUBY
    passes, ledger = output
    assert_includes passes, "active_record/preload_plans"
    assert ledger.any? { _1["method"] == "EqWriter#undefined" && _1["outcome"].include?("NotImplementedError") }
    %w[active_record/ar_plans active_record/preload_plans].each do |pass|
      assert ledger.any? { _1["pass"] == pass && _1["file"] == "EqUnavailable" && _1["outcome"].include?("metadata unavailable") }
    end
  end

  def test_shadow_detects_sql_bind_value_type_and_name_differences_without_executing
    output = ruby_json(PRELUDE + <<~'RUBY', setup: false, env: { "RUBYLIB" => GEM_LIB, "LOWRAIL" => "0" })
      Lowrail::Stats.enable!
      events = []
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| events << payload[:sql] }
      expected = Lowrail::ARShadow.relation(EqPost.where(id: 2))
      variants = []
      variants << Lowrail::ARShadow.relation(EqPost.where(id: 3))
      variants << Lowrail::ARShadow.relation(EqPost.where(title: "2"))
      variants << ["Wrong Load", *expected.drop(1)]
      variants << [expected[0], expected[1] + " /* wrong */", expected[2]]
      EqPost.with_connection do |connection|
        type = ActiveRecord::Type::Integer.new(limit: 123)
        bind = ActiveRecord::Relation::QueryAttribute.new("id", 2, type)
        variants << Lowrail::ARShadow.statement(EqPost, connection, expected[1], [bind])
      end
      errors = variants.map do |actual|
        begin
          Lowrail::ARShadow.compare("fault-control", expected, actual)
          "missed"
        rescue Lowrail::ARShadow::Mismatch
          "caught"
        end
      end
      # Non-strict canary mode records and continues, rather than raising.
      ENV["LOWRAIL_SHADOW"] = "1"
      Lowrail::ARShadow.compare("canary", expected, variants.first)
      ActiveSupport::Notifications.unsubscribe(subscription)
      puts JSON.generate([errors, Lowrail::ARShadow.mismatches.size, events.size, EqPost.count])
    RUBY
    assert_equal [["caught"] * 5, 6, 0, 7], output
  end
end
