# frozen_string_literal: true

require_relative "test_helper"

class ViewTest < Minitest::Test
  include LowrailTest

  # Intentional red regression pending the owner decision: close the source
  # arm's residual or demote view/link_to. Exercise the real default builder,
  # not a handwritten approximation of its emitted conditional.
  def test_default_link_to_observes_a_suppressed_redefinition_after_warmup
    bin = File.expand_path("../../target/debug/lowrail", __dir__)
    skip "cargo build and Rails/sqlite3/bcrypt are required" unless File.executable?(bin) && LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "Gemfile" => "source 'https://rubygems.org'\ngem 'rails', '8.1.4'\ngem 'sqlite3'\ngem 'bcrypt'\ngem 'prism'\n",
        "app/controllers/widgets_controller.rb" => "class WidgetsController < ApplicationController; def index; end; end\n",
        "app/views/widgets/index.html.erb" => '<% 10.times do %><%= link_to "link", "/target" %><% end %>')
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "test"), bin, "build", dir, "--passes", "default")
      assert status.success?, "default build failed:\n#{out}\n#{err}"
      manifest = JSON.parse(File.read(File.join(dir, ".lowrail/manifest.json")))
      assert manifest.fetch("units").any? { _1["pass"] == "view/link_to" }, "must exercise the source pass"
      refute manifest.fetch("units").any? { _1["pass"] == "endpoint/action" }
      scenario = <<~'RUBY'
        require "./config/environment"
        require "rack/mock"
        armed = false
        subscriber = Object.new
        subscriber.define_singleton_method(:start) do |*|
          next unless armed
          armed = false
          mod = ActionView::Helpers::UrlHelper
          original = mod.instance_method(:link_to)
          mod.define_singleton_method(:method_added) { |_| }
          mod.define_method(:link_to) do |*args, **kwargs, &block|
            original.bind_call(self, *args, **kwargs, &block) + "<!-- live helper -->".html_safe
          end
        end
        subscriber.define_singleton_method(:finish) { |*| }
        ActiveSupport::Notifications.subscribe("process_action.action_controller", subscriber)
        request = -> { Rack::MockRequest.new(Rails.application).get("/widgets", "HTTP_HOST" => "example.org") }
        warm = request.call
        armed = true
        changed = request.call
        puts JSON.generate(statuses: [warm.status, changed.status], warm: warm.body, changed: changed.body,
          hits: Lowrail::Stats.unit_hits)
      RUBY
      off, on = %w[0 1].map do |mode|
        ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "test", "LOWRAIL" => mode, "LOWRAIL_STATS" => ""})
      end
      assert_equal [200, 200], off.fetch("statuses")
      assert_equal off.fetch("statuses"), on.fetch("statuses")
      assert_equal off.fetch("warm"), on.fetch("warm")
      refute_empty on.fetch("hits"), "warmup must populate the actual source guard"
      assert_equal 10, off.fetch("changed").scan("<!-- live helper -->").size
      assert_equal off.fetch("changed"), on.fetch("changed"), "a real subscriber must not leave a stale source arm authorized"
    end
  end
end
