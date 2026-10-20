# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/callbacks"
require "rails/version"
require_relative "callback_survey"

class CallbackSurveyTest < Minitest::Test
  def test_census_observes_selected_chains_without_converting_user_kinds
    host = Class.new do
      include ActiveSupport::Callbacks
      define_callbacks :save
      attr_accessor :enabled
      attr_reader :events
      def initialize = @events = []
      def record = @events << :before
      set_callback :save, :before, :record, if: :enabled
    end
    target = host.new
    conversions = 0
    kind = Object.new
    kind.define_singleton_method(:to_sym) { conversions += 1; :save }
    CallbackSurvey.start
    target.enabled = true
    assert_equal :first, target.run_callbacks(:save) { :first }
    target.enabled = false
    assert_equal :second, target.run_callbacks("save") { :second }
    assert_equal :third, target.run_callbacks(:save, :after) { :third }
    assert_equal :fourth, target.run_callbacks(kind) { :fourth }
    report = CallbackSurvey.finish
    assert_equal [:before], target.events
    assert_equal 1, conversions
    assert_equal 4, report.fetch(:calls)
    assert_equal 2, report.fetch(:categories).fetch("symbol_conditions")
    assert_equal 1, report.fetch(:categories).fetch("empty")
    assert_equal 1, report.fetch(:categories).fetch("unobserved_kind")
  end
end
