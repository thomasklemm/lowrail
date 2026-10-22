# frozen_string_literal: true

# External own-suite admission probe. No app/test/config source changes and no
# synthetic requests: hits must come from the application's unchanged tests.
require "lowrail"
require "active_support/lazy_load_hooks"

module DirectSiteSuite
  class << self
    attr_accessor :tests
  end
  self.tests = {}

  module Results
    def record(result)
      now = ARRequestSites.counts.dup
      before = @direct_site_counts || {}
      key = "#{result.respond_to?(:klass) ? result.klass : result.class.name}##{result.name}"
      DirectSiteSuite.tests[key] = now.to_h { |name, value| [name, value - before.fetch(name, 0)] }
      @direct_site_counts = now
      super
    end
  end
end

ActiveSupport.on_load(:after_initialize) do
  raise "actual suite-worker YJIT required" unless RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
  require_relative "ar_request_sites"
  ARCallsite.install(sql: false, lean: false)
  ARCallsite.shadow = true
  ARRequestSites.install({"workload" => "fizzy", "app" => Rails.root.to_s}, ENV["LOWRAIL"] == "1" ? "on" : "off_a")
  ARRequestSites.counting = true
  Lowrail::Minitest::Reporter.prepend(DirectSiteSuite::Results)
  at_exit do
    raise "actual suite-worker YJIT required" unless RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
    require "json"
    path = ENV.fetch("AR_DIRECT_SITE_RECEIPT")
    File.write("#{path}-#{ENV.fetch('LOWRAIL')}-#{Process.pid}.json", JSON.pretty_generate(
      "enabled" => ARRequestSites.enabled, "counts" => ARRequestSites.counts,
      "per_test" => DirectSiteSuite.tests, "pid" => Process.pid,
      "ruby" => RUBY_DESCRIPTION, "yjit" => RubyVM::YJIT.enabled?,
      "zjit" => !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)), perm: 0o600)
  end
end
