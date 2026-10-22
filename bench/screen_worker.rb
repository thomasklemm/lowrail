# frozen_string_literal: true

require "json"
require "fileutils"
require_relative "window_audit"
config = JSON.parse(File.read(ENV.fetch("SCREEN_CONFIG")))
ScreenClock.install(config.fetch("epoch")) if config["epoch"]
app = config.fetch("app")
if config["storage_seed"]
  FileUtils.rm_rf(File.join(app, "storage"))
  FileUtils.cp_r(config.fetch("storage_seed"), File.join(app, "storage"))
end
require_relative "jit_stability"
require File.join(app, "config/application")
Rails.application.config.yjit = false
audit = WindowAudit.new(cache: nil)
ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::ConnectionPool.prepend(WindowAudit::Reaper)
end
require File.join(app, "config/environment")
require_relative "screen"
require_relative "heap_windows"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")

if config["exploration_setup"]
  require config.fetch("exploration_setup")
  Exploration.install(config: config, state: config.fetch("seed"), arm: ENV.fetch("SCREEN_ARM"))
end
if config["entropy_policy"]
  require_relative "../fixtures/corpus/blog_entropy"
  control = BlogProduction::Entropy.validate(app, policy: JSON.parse(File.read(config.fetch("entropy_policy"))))
  raise control.fetch("reason") unless control.fetch("active")
  BlogProduction::Entropy.install(control.fetch("policy"))
end
Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil if defined?(ActiveRecord::Base)
JitStability.assert_mode!
raise "screen supports interpreter only" unless JitStability.actual == "interpreter"
Rails.cache.clear if config["reset_cache"]
routes = ScreenPlatform.routes(config)
requests = Integer(ENV.fetch("BENCH_REQUESTS", "50"))
workload = ->(n, route) {
  n.times { raise "HTTP request failed" unless routes.fetch(route).call.status == 200 }
}
config.fetch("warmup").times { routes.each_key { workload.call(1, _1) } }
exact = -> {
  routes.to_h do |route, call|
    [route, [0, 1].to_h do |seed|
      response, evidence = if config["entropy_policy"]
        response, entropy_evidence = BlogProduction::Entropy.with(seed, route, wall_clock: true, &call)
        [response, {"passed" => entropy_evidence.fetch("errors").empty?, "entropy" => entropy_evidence}]
      elsif defined?(Exploration) && Exploration.respond_to?(:validation_request)
        Exploration.validation_request(route: route, seed: seed, request: call)
      else
        [call.call, {"passed" => true, "control" => "raw response; no entropy substitution"}]
      end
      [seed.to_s, ScreenPlatform.response_digest(response).merge("evidence" => evidence)]
    end]
  end
}
before_exact = exact.call
windows = HeapWindows.windows(requests, routes.keys)
audit.cache = Rails.cache
anchors = audit.with_reapers_deferred do
  HeapWindows.run(windows, audit: audit,
    settle: -> { routes.each_key { workload.call(1, _1) } }, &workload)
end
after_exact = exact.call
audit.close
puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION, rails: Rails.version,
  windows: windows, operations: true, heap_anchors: anchors, heap_page_targets: HeapWindows.page_targets,
  compiled_iseqs: 0, jit_warmup: nil, request_settle: true, exact: before_exact, exact_after: after_exact,
  refusal: Lowrail.refusal_reason)}"
