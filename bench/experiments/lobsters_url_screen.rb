# frozen_string_literal: true

# Adapter for script/screen from the native-yjit-bench exploration branch.
# No application/config edits; entropy controls apply only to untimed checks.
require_relative "lobsters_url_program"
require File.join(NativeBench::ROOT, "bench/experiments/lobsters_native_validation")

module NativeBench::Exploration
  class << self
    def install(config:, state:, arm:)
      LobstersNativeValidation.install(config.fetch("app"))
      workload = NativeBench.routes(config, state, arm)
      LobstersUrlProgram.discover do
        workload.each_value { raise "discovery HTTP failure" unless _1.call.status == 200 }
      end
      LobstersUrlProgram.compile(coverage: !ENV["LOWRAIL_STATS"].nil?, guarded: config.fetch("url_guarded", false))
      raise "no naturally observed fixed URL programs" if LobstersUrlProgram.programs.empty?
      LobstersUrlProgram.select(arm == "on")
    end

    def validation_request(route:, seed:, request:)
      LobstersNativeValidation.validation_request(route: route, seed: seed, request: request)
    end

    def counts = LobstersUrlProgram.counts
  end
end
