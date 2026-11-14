# frozen_string_literal: true

# IM1: javascript_importmap_tags of a new app's layout (seven preloaded modules), as in
# the PR body. Run from a generated app with a Gemfile pointing importmap-rails at
# the tree under test:
#   BUNDLE_GEMFILE=Gemfile.imb RAILS_ENV=production taskset -c 3 bin/rails runner im1_ips.rb
require "benchmark/ips"

controller = ApplicationController.new
controller.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("https://localhost/"))
view = controller.view_context

Benchmark.ips do |x|
  x.report("javascript_importmap_tags") { view.javascript_importmap_tags }
end
