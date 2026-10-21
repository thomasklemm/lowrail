# frozen_string_literal: true

# Adapter for bet A's unchanged script/native-bench exploration hook.
require_relative "fused_views"

module NativeBench
  module Exploration
    def self.install(config:, state:, arm:)
      raise "blog only" unless config.fetch("workload") == "blog"
      mode = config.fetch("fusion_mode")
      raise "unknown fusion mode" unless %w[fusion sealed stacked].include?(mode)
      FusedViews.observe
      # Natural original operations in every arm, before any source is copied.
      require "rack/mock"
      rack = Rack::MockRequest.new(Rails.application)
      2.times do
        config.fetch("fused_paths").each do |path|
          raise "original witness failed" unless rack.get(path, "HTTP_HOST" => "localhost", "HTTPS" => "on").status == 200
        end
      end
      if arm == "on" && mode != "sealed"
        FusedViews.install(ArticlesController, "show", partials: ["comments/comment"])
        FusedViews.install(ArticlesController, "index", partials: ["articles/article"])
        raise "fusion refused: #{FusedViews::LEDGER}" unless FusedViews::PLANS.size == 2
        FusedViews.enabled = true
      end
      NativeBench.singleton_class.prepend(Routes)
    end

    def self.counts
      {"fusion" => FusedViews::COUNTS.dup,
        "hits" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.unit_hits : {},
        "fallbacks" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.unit_fallbacks : {},
        "form_input_refusal" => Lowrail::FormScaffold.input_refusal}
    end

    # Workload extension only: the shared driver initially supplies show only.
    # No clocks, windows, statistics or activation rules are replaced here.
    module Routes
      def routes(config, state, arm)
        return super unless config.fetch("workload") == "blog"
        rack = Rack::MockRequest.new(Rails.application)
        config.fetch("fused_paths").to_h do |path|
          ["GET #{path}", -> { rack.get(path, "HTTP_HOST" => "localhost", "HTTPS" => "on") }]
        end
      end
    end
  end
end
