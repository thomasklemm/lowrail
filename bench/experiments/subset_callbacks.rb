# frozen_string_literal: true

# Bet E exploration only; no Lowrail runtime registration/admission. Select a
# fixed chain per action, then use the UNCHANGED Rails callback executor. This
# deliberately does not duplicate Bet G's generic callback-chain mechanics.
module SubsetCallbacks
  PLANS = {}.compare_by_identity
  COUNTS = Hash.new(0)
  class Refused < StandardError; end

  module Reader
    def __callbacks
      plan = SubsetCallbacks::PLANS[self.class]
      return super unless plan && plan.active[0]
      callbacks = plan.actions[action_name]
      return super unless callbacks
      SubsetCallbacks::COUNTS[self.class.name] += 1 if SubsetCallbacks.counting
      callbacks
    end
  end

  module Writes
    def set_callbacks(name, callbacks)
      if name.to_sym == :process_action && (plan = SubsetCallbacks::PLANS[self])
        plan.withdraw!("callback chain replaced")
      end
      super
    end
  end

  class Plan
    attr_reader :actions, :active, :report
    def initialize(controller, names, active: [false])
      raise Refused, "Ruby/Rails version" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
      @active, @actions = active, {}
      @report = {"controller" => controller.name, "actions" => {}, "production_admission" => false,
        "limits" => ["Assumes stable action_name and stock ActionFilter effects for the request.",
          "Setter tripwire does not cover direct callback-hash/condition mutation or native writes.",
          "Not whole-action AOT: real action, views, AR and all live conditions/callbacks remain."]}
      original = controller.__callbacks
      source = original.fetch(:process_action)
      names.each do |name|
        raise Refused, "unknown action #{name}" unless controller.action_methods.include?(name)
        stats = {"original_filters" => source.count, "removed_filters" => 0, "removed_action_conditions" => 0}
        chain = ActiveSupport::Callbacks::CallbackChain.new(:process_action, source.config)
        source.each do |callback|
          kept = {if: [], unless: []}
          drop, live_prefix = false, false
          %i[if unless].each do |kind|
            callback.instance_variable_get(:"@#{kind}").each do |condition|
              if foldable?(condition, controller)
                matched = condition.instance_variable_get(:@actions).include?(name)
                passes = kind == :if ? matched : !matched
                if passes
                  stats["removed_action_conditions"] += 1
                  next
                elsif !live_prefix
                  drop = true
                  break
                end
              end
              # Never erase effects from an earlier if/unless predicate just
              # because a later only/except condition is known false.
              kept[kind] << condition
              live_prefix = true
            end
            break if drop
          end
          if drop
            stats["removed_filters"] += 1
            next
          end
          copy = callback.dup
          kept.each { |kind, conditions| copy.instance_variable_set(:"@#{kind}", conditions.freeze) }
          copy.instance_variable_set(:@compiled, nil)
          chain.append(copy)
        end
        chain.compile(nil) # AOT selection/compilation, no request predicates run.
        @actions[name] = original.merge(process_action: chain).freeze
        @report.fetch("actions")[name] = stats.merge("selected_filters" => chain.count)
      end
    end

    def foldable?(condition, controller)
      condition.instance_of?(AbstractController::Callbacks::ActionFilter) &&
        (!controller.raise_on_missing_callback_actions ||
          condition.instance_variable_get(:@actions).all? { controller.action_methods.include?(_1) })
    end

    def withdraw!(reason)
      return unless @active[0]
      @active[0] = false
      warn "LOWRAIL SUBSET FALLBACK: #{@report['controller']}: #{reason}; original chain for later entries"
    end
  end

  class << self
    attr_accessor :counting
    def install(controller, actions:, enabled: false, active: [false])
      raise Refused, "already installed" if PLANS.key?(controller)
      plan = Plan.new(controller, actions, active: active)
      controller.prepend(Reader)
      controller.singleton_class.prepend(Writes)
      PLANS[controller] = plan
      plan.active[0] = enabled
      plan
    end
  end
end
