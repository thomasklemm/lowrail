# frozen_string_literal: true

# Component-test adapter: build against the models already loaded by a test
# runner, without inventing a Rails application or weakening any pass guard.
require "lowrail"
require "lowrail/manifest"
require "lowrail/stats"
require "lowrail/guard"
require "lowrail/ar_plan_build"
require "lowrail/preload_build"
require "lowrail/ar_instantiate_build"

module Lowrail
  module AREquivalenceRuntime
    def self.build
      AR.install if Lowrail.enabled?
      built = [ARPlanBuild, PreloadBuild, ARInstantiateBuild].map(&:build)
      units = built.flat_map { _1[:units] }
      units.each_with_index { |unit, id| unit["id"] = id }
      manifest = Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION,
        "compile_option" => "", "files" => {}, "units" => units }, Dir.pwd)
      Stats.enable!
      if Lowrail.enabled?
        Guard.install(manifest, Stats::STATE)
        { ARPlans => "active_record/ar_plans", PreloadPlans => "active_record/preload_plans",
          ARInstantiate => "active_record/instantiate" }.each do |runtime, pass|
          selected = units.select { _1["pass"] == pass }
          next if selected.empty?
          runtime.install(selected)
          runtime.activate
        end
      end
      { manifest: manifest, ledger: built.flat_map { _1[:ledger] } }
    end
  end
end
