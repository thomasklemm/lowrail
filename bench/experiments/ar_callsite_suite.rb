# frozen_string_literal: true

# Injected with RUBYOPT by lowrail verify; never edit an application to use it.
# Test-only exploratory adapter, not the public sealed test certificate.
require "active_support/lazy_load_hooks"
ActiveSupport.on_load(:after_initialize) do
  require_relative "ar_callsite"
  ARCallsite.install
  ARCallsite.enabled = ENV["LOWRAIL"] == "1"
  ARCallsite.shadow = true
  if (path = ENV["AR_CALLSITE_RECEIPT"])
    at_exit do
      require "json"
      File.write("#{path}-#{ENV['LOWRAIL']}-#{Process.pid}.json", JSON.pretty_generate(
        enabled: ARCallsite.enabled, counts: ARCallsite.counts, refusals: ARCallsite.refusals,
        plans: ARCallsite.plans.size))
    end
  end
end
