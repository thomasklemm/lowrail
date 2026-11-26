# frozen_string_literal: true

# INRP1 body benchmark: the props of a dashboard page (errors, plain stats, a merge prop, two deferred groups and an
# optional prop) through InertiaRails::PropsResolver, as the renderer resolves them on an Inertia visit.
# Standalone (the body's script): `ruby INRP1_resolver.rb` in an inertia-rails checkout (or INERTIA_RAILS=path).
# Under script/upstream-bench it only defines the cases.
unless defined?(UpstreamBench)
  require "bundler/inline"
  gemfile do
    source "https://rubygems.org"
    gem "rails"
    gem "inertia_rails", path: ENV.fetch("INERTIA_RAILS", ".")
    gem "benchmark-ips"
  end
end
require "rails"
require "action_controller/railtie"
require "inertia_rails"

rows = Array.new(10) { |i| { id: i, name: "Contact #{i}" } }
evaluator = InertiaRails::PropEvaluator.new(Object.new)
props = -> {
  {
    errors: InertiaRails.always { {} },
    stats: { users: 1200, revenue: 34_500, orders: 87 },
    recent: InertiaRails.merge { rows },
    activity: InertiaRails.defer { rows },
    chart: InertiaRails.defer(group: "charts") { [1, 2, 3] },
    archived: InertiaRails.optional { [] },
  }
}
resolve = -> { InertiaRails::PropsResolver.new(props.(), evaluator: evaluator).resolve }

if defined?(UpstreamBench)
  UpstreamBench.report("dashboard props") { resolve.() }
else
  require "benchmark/ips"
  Benchmark.ips { |x| x.report("dashboard props") { resolve.() } }
end
