# frozen_string_literal: true

require "minitest/autorun"
require "rails"
require "action_controller"
require_relative "subset_callbacks"

class SubsetCallbacksTest < Minitest::Test
  def test_membership_preserves_live_predicate_effects_around_and_chain_changes
    klass = Class.new(ActionController::Base) do
      attr_accessor :events, :halt
      self.raise_on_missing_callback_actions = true
      def index; end
      def show; end
      def edit; end
      def mark = @events << :selected
      def side_effect
        @events << :predicate
        true
      end
      before_action :mark, only: :show
      before_action -> { @events << :except }, except: :index
      # :except appends an unless condition AFTER the live if predicate.
      before_action -> { @events << :effect }, if: :side_effect, except: :index
      around_action ->(target, body) { target.events << :around; body.call; target.events << :end }
      before_action -> { self.response_body = "halted" if halt }
    end
    invoke = ->(name, halt) do
      object = klass.new
      object.set_response!(ActionDispatch::Response.new)
      object.events, object.action_name, object.halt = [], name, halt
      value = object.run_callbacks(:process_action) { object.events << :action; 73 }
      [value, object.events, object.response_body]
    end
    cases = [["index", false], ["show", false], ["edit", true]]
    expected = cases.map { invoke.call(*_1) }
    plan = SubsetCallbacks.install(klass, actions: %w[index show edit], enabled: true)
    cases.each_with_index { |pair, index| assert_equal expected[index], invoke.call(*pair) }
    assert_includes invoke.call("index", false)[1], :predicate, "a false later except cannot erase earlier live effects"
    klass.before_action -> { @events << :new_callback }
    refute plan.active[0]
    assert_includes invoke.call("show", false)[1], :new_callback
  ensure
    SubsetCallbacks::PLANS.delete(klass) if klass
  end
end
