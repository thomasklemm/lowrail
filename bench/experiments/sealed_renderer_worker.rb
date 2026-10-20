# frozen_string_literal: true

# Install only AFTER initialize! and its route-loading finisher have returned.
# The unchanged shared worker still owns warming, requests and every window.
require_relative "../jit_stability"
if JitStability.mode != "yjit"
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
end
require File.expand_path("config/environment", Dir.pwd)
if ENV["SEALED_RENDERER_STAGE"] == "L2_events"
  require_relative "blog_eventful"
  BlogEventful.install
elsif ENV["SEALED_RENDERER_STAGE"]
  require_relative "sealed_renderer"
  SealedRenderer.install(ENV.fetch("SEALED_RENDERER_STAGE"))
end
require_relative "sealed_residual" if ENV["SEALED_RESIDUAL_SCOPE"]
load File.expand_path("../heap_requests.rb", __dir__)
