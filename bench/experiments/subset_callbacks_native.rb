# frozen_string_literal: true

require_relative "subset_callbacks"
require_relative "../../fixtures/corpus/blog_production"

# Adapter for Bet A's unchanged exploration hook, not a copy of its harness.
module NativeBench
  module Exploration
    def self.install(config:, state:, arm:)
      raise "blog-only specimen" unless config.fetch("workload") == "blog"
      policy = JSON.parse(File.read(config.fetch("subset_entropy_policy")))
      @control = BlogProduction::Entropy.validate(config.fetch("app"), policy: policy)
      raise "entropy controls refused: #{@control['reason']}" unless @control.fetch("active")
      BlogProduction::Entropy.install(policy)
      # Disposable fixed secret is an input in every arm, never a production
      # recipe. Only validation requests control RNG/clock; timing stays native.
      Rails.application.config.secret_key_base = BlogProduction::Entropy::SECRET
      Rails.application.env_config.merge!(
        "action_dispatch.secret_key_base" => BlogProduction::Entropy::SECRET,
        "action_dispatch.key_generator" => Rails.application.key_generator(BlogProduction::Entropy::SECRET))
      # The harness deliberately boots with a fresh dummy secret per worker.
      # Turbo derives its signing key during boot, before this hook. Declare
      # the same disposable key input in every arm before the verifier is used;
      # do not strip signed-stream bytes or ETags from exact comparisons.
      raise "Turbo verifier already used before setup" if Turbo.instance_variable_defined?(:@signed_stream_verifier)
      Turbo.signed_stream_verifier_key = Rails.application.key_generator(BlogProduction::Entropy::SECRET)
        .generate_key("turbo/signed_stream_verifier_key")
      @app = config.fetch("app")
      SubsetCallbacks.counting = ENV.key?("LOWRAIL_STATS")
      @plan = SubsetCallbacks.install(ArticlesController, actions: %w[index show], enabled: arm == "on")
    end

    def self.counts
      {"action_chain_selections" => SubsetCallbacks::COUNTS.dup}
    end

    def self.validation_request(route:, seed:, request:)
      before = BlogProduction.effects(@app)
      response, evidence = BlogProduction::Entropy.with(seed, route, wall_clock: true, &request)
      after = BlogProduction.effects(@app)
      evidence["db_unchanged"] = before == after
      evidence["passed"] = evidence.fetch("errors").empty? && evidence.fetch("db_unchanged")
      evidence["plan"] = @plan.report
      [response, evidence]
    end
  end
end
