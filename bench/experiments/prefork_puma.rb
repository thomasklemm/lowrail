# frozen_string_literal: true

# External script/rps adapter, not an automatic runtime installer. Preloading
# and the observer are identical in all arms; only "on" requests warmup.
require_relative "../../gem/lib/lowrail/puma"

module NativeRps::PumaSetup
  def self.configure(puma:, config:, arm:)
    puma.preload_app!
    puma.before_fork do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      completed = Lowrail::Puma.warmup if arm == "on"
      File.write(File.join(config.fetch("prefork_evidence"), "#{Process.pid}.json"), JSON.generate(
        {"arm" => arm, "completed" => completed,
         "hook_ms" => (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000}))
    end
  end
end
