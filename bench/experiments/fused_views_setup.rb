# frozen_string_literal: true

# Own-suite preload only. No controller autoload/eager-load policy change.
# CI=1 is the blog's own eager-load switch; an unloaded controller refuses.
require "bundler/setup"
require "active_support/lazy_load_hooks"
ActiveSupport.on_load(:after_initialize) do
  require_relative "fused_views"
  FusedViews.observe
  FusedViews.enabled = ENV["LOWRAIL"] == "1"
  if FusedViews.enabled?
    if Object.const_defined?(:ArticlesController, false) && !Object.autoload?(:ArticlesController)
      FusedViews.install(ArticlesController, "show", partials: ["comments/comment"])
      FusedViews.install(ArticlesController, "index", partials: ["articles/article"])
    elsif Object.const_defined?(:RoomsController, false) && !Object.autoload?(:RoomsController)
      FusedViews.install(RoomsController, "show")
    else
      FusedViews::LEDGER << {outcome: "refused", reason: "controller not naturally loaded"}
    end
  end
  at_exit do
    if ENV["FUSED_SUITE_REPORT"]
      require "json"
      File.write(ENV.fetch("FUSED_SUITE_REPORT"), JSON.pretty_generate(ledger: FusedViews::LEDGER, hits: FusedViews::COUNTS))
    end
  end
end
