# frozen_string_literal: true

require_relative "test_helper"

class ViewTest < Minitest::Test
  include LowrailTest

  # Quarantine is an explicit refusal, not accelerated-arm certification.
  # Keep the original failing request and require Rails' observable result.
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
      assert_empty manifest.fetch("units"), "default source passes are quarantined, not merely guarded"
      ledger = JSON.parse(File.read(File.join(dir, ".lowrail/ledger.json")))
      assert_equal %w[route/path view/link_to], ledger.select { _1["reason"] == "quarantined" }.map { _1.fetch("pass") }.sort
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
      assert_empty on.fetch("hits"), "refusal must not be reported as accelerated coverage"
      assert_equal 10, off.fetch("changed").scan("<!-- live helper -->").size
      assert_equal off.fetch("changed"), on.fetch("changed"), "a real subscriber must not leave a stale source arm authorized"
    end
  end

  def test_name_expression_can_change_the_actual_builder_before_link_to
    default_fixture(
      "app/helpers/application_helper.rb" => <<~'RUBY',
        module ApplicationHelper
          def boundary_label
            $name_calls += 1
            if $armed
              tag_builder.define_singleton_method(:content_tag_string) { |*| "<!-- changed builder -->".html_safe }
            end
            "link"
          end
        end
      RUBY
      "app/views/widgets/index.html.erb" => '<%= link_to boundary_label, "/target" %>'
    ) do |dir|
      off, on = paired_requests(dir, <<~'RUBY')
        $name_calls = 0
        $armed = false
        warm = request.call
        $name_calls = 0
        $armed = true
        changed = request.call
        {statuses: [warm.status, changed.status], warm: warm.body, changed: changed.body, calls: $name_calls}
      RUBY
      assert_equal [200, 200], off.fetch("statuses")
      assert_equal '<a href="/target">link</a>', off.fetch("warm")
      assert_equal "<!-- changed builder -->", off.fetch("changed")
      assert_equal 1, off.fetch("calls")
      assert_equal off, on, "a guard before the name expression cannot certify the later builder call"
    end
  end

  def test_to_param_can_change_the_actual_route_formatter_without_replaying_conversion
    default_fixture(
      "app/helpers/application_helper.rb" => <<~'RUBY',
        module ApplicationHelper
          def route_argument
            argument = Object.new
            argument.define_singleton_method(:to_param) do
              $conversions += 1
              if $armed
                route = Rails.application.routes.named_routes.get(:widget)
                route.define_singleton_method(:singleton_method_added) { |_| }
                route.define_singleton_method(:format) { |_| +"/changed" }
              end
              "7"
            end
            argument
          end
        end
      RUBY
      "app/views/widgets/index.html.erb" => '<%= widget_path(route_argument) %>'
    ) do |dir|
      off, on = paired_requests(dir, <<~'RUBY')
        $conversions = 0
        $armed = false
        warm = request.call
        $conversions = 0
        $armed = true
        changed = request.call
        {statuses: [warm.status, changed.status], warm: warm.body, changed: changed.body, conversions: $conversions}
      RUBY
      assert_equal [200, 200], off.fetch("statuses")
      assert_equal "/widgets/7", off.fetch("warm")
      assert_equal "/changed", off.fetch("changed")
      assert_equal 1, off.fetch("conversions")
      assert_equal off, on, "continuation must not restart the helper or repeat to_param"
    end
  end

  private

  def default_fixture(extra)
    bin = File.expand_path("../../target/debug/lowrail", __dir__)
    skip "cargo build and Rails/sqlite3/bcrypt are required" unless File.executable?(bin) && LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, {
        "Gemfile" => "source 'https://rubygems.org'\ngem 'rails', '8.1.4'\ngem 'sqlite3'\ngem 'bcrypt'\ngem 'prism'\n",
        "app/controllers/widgets_controller.rb" => "class WidgetsController < ApplicationController; def index; end; end\n"
      }.merge(extra))
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "test"), bin, "build", dir, "--passes", "default")
      assert status.success?, "default build failed:\n#{out}\n#{err}"
      yield dir
    end
  end

  def paired_requests(dir, body)
    script = <<~RUBY
      require "./config/environment"
      require "rack/mock"
      request = -> { Rack::MockRequest.new(Rails.application).get("/widgets", "HTTP_HOST" => "example.org") }
      result = begin
        #{body}
      end
      puts JSON.generate(result)
    RUBY
    %w[0 1].map { |mode| ruby_json(script, chdir: dir, env: {"RAILS_ENV" => "test", "LOWRAIL" => mode}) }
  end
end
