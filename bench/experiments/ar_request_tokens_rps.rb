# frozen_string_literal: true

# RPS causal contrast, NOT Lowrail on/off: all three arms use F's same query
# program. off-A/off-B retain its public-reflection scan; on uses VM tokens.
# The public artifact has zero units, so LOWRAIL=0/1 adds no other treatment.
require_relative "ar_request_sites"

module NativeBench::Exploration
  class << self
    alias_method :install_direct_site, :install

    def install(config:, state:, arm:)
      ENV["LOWRAIL_GUARD_BACKEND"] = arm == "on" ? "tokens" : "reflection"
      manifest = JSON.parse(File.read(File.join(config.fetch("artifact"), "manifest.json")))
      raise "RPS causal contrast requires an empty public artifact" unless manifest.fetch("units").empty?
      raise "RPS token backend missing" unless arm != "on" || Lowrail::Guard::Methods.backend == :tokens
      install_direct_site(config: config, state: state, arm: "on")
    end
  end
end
