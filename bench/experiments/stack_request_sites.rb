# frozen_string_literal: true

# External stack-screen composition only. Keep F's guarded implementation
# unchanged; public AR selection still comes from normally built artifacts.
require_relative "ar_request_sites"

module NativeBench::Exploration
  class << self
    alias_method :install_stack_request_sites, :install
    alias_method :stack_request_site_counts, :counts

    def install(config:, state:, arm:)
      install_stack_request_sites(config: config, state: state, arm: arm)
      ARRequestSites.enabled = arm == "on" && config.fetch("stack_direct_sites", true)
    end

    def counts
      counters = stack_request_site_counts
      return counters unless defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
      counters.merge("public_units" => {
        "hits" => Lowrail::Stats.unit_hits,
        "fallbacks" => Lowrail::Stats.unit_fallbacks
      })
    end
  end
end
