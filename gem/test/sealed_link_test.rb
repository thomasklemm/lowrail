# frozen_string_literal: true

require_relative "test_helper"
require "lowrail"

class SealedLinkTest < Minitest::Test
  include LowrailTest

  def test_cold_opt_in_delivery_preserves_response_effects_and_refuses_foreign_receivers
    bin = File.expand_path("../../target/debug/lowrail", __dir__)
    skip "Ruby 4.0.7 and Rails/sqlite3 required" unless RUBY_VERSION == "4.0.7" && File.executable?(bin) && LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "Gemfile" => "source 'https://rubygems.org'\ngem 'rails', '8.1.4'\ngem 'sqlite3'\ngem 'bcrypt'\ngem 'prism'\ngem 'bootsnap'\n",
        "Gemfile.lock" => "",
        "config/environment.rb" => "require_relative 'application'\nRails.application.initialize!\n",
        "config/application.rb" => <<~'RUBY',
          ENV["BOOTSNAP_CACHE_DIR"] ||= File.expand_path("../tmp/cache", __dir__)
          require "bootsnap/setup"
          require "rails"
          require "active_record/railtie"
          require "action_controller/railtie"
          require "action_view/railtie"
          module RealBlogR4
            class Application < Rails::Application
              config.root = File.expand_path("..", __dir__)
              config.eager_load = true
              config.logger = Logger.new(nil)
              config.secret_key_base = "x" * 64
              config.active_support.deprecation = :silence
            end
          end
        RUBY
        "config/database.yml" => "production:\n  adapter: sqlite3\n  database: database.sqlite3\n",
        "app/models/widget.rb" => "class Widget < ApplicationRecord; end\n",
        "config/routes.rb" => 'Rails.application.routes.draw { resources :articles, only: :index }',
        "app/controllers/articles_controller.rb" => <<~'RUBY',
          class ArticlesController < ApplicationController
            def index
              @assigned = "live"
              if ENV["FOREIGN"]
                original = method(:view_context)
                define_singleton_method(:view_context) do
                  view = original.call
                  if ENV["FOREIGN"] == "view"
                    view.define_singleton_method(:link_to) { |*| "private-view".html_safe }
                    view.singleton_class.send(:private, :link_to)
                  else
                    builder = ActionView::Helpers::TagHelper::TagBuilder.new(view)
                    builder.define_singleton_method(:content_tag_string) { |*| "foreign-builder".html_safe }
                    view.instance_variable_set(:@tag_builder, builder)
                  end
                  view
                end
              end
            end
          end
        RUBY
        "app/helpers/application_helper.rb" => <<~'RUBY',
          module ApplicationHelper
            def link_target
              $conversions = ($conversions || 0) + 1
              "/target?x=<&q=\""
            end
          end
        RUBY
        "app/views/articles/index.html.erb" => '<%= link_to "A<&", link_target, class: "one\"two" %>')
      out, err, status = ruby("-e", 'require "sqlite3"; SQLite3::Database.new("database.sqlite3").execute("create table widgets (id integer primary key)")', chdir: dir, setup: false)
      assert status.success?, "#{out}\n#{err}"
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "production", "LOWRAIL_BUILD_JIT" => "0"), bin, "build", dir, "--env", "production", "--sealed")
      assert status.success?, "#{out}\n#{err}"
      manifest = JSON.parse(File.read(File.join(dir, ".lowrail/manifest.json")))
      assert_equal Lowrail::FORMAT, manifest["format"]
      assert_equal "sealed-v1", manifest["tier"]
      link_unit = manifest.fetch("units").find { _1["pass"] == "sealed/link_to" }.fetch("id").to_s
      scenario = <<~'RUBY'
        require "./config/environment"
        require "rack/mock"
        require "objspace"
        events = []
        ActiveSupport::Notifications.subscribe("render_template.action_view") do |*args|
          events << ActiveSupport::ExecutionContext.to_h.fetch(:controller).instance_variable_get(:@assigned)
        end
        klass = ActionView::Helpers::TagHelper::TagBuilder
        metadata = [klass.method(:new), klass.instance_method(:initialize), ArticlesController.instance_method(:dispatch)].map do |m|
          [m.owner.name, m.source_location, m.parameters]
        end
        response = Rack::MockRequest.new(Rails.application).get("/articles", "HTTP_HOST" => "example.org")
        raise "request token leaked" if defined?(Lowrail::Sealed) && Thread.current[Lowrail::Sealed::REQUEST]
        trace_exits = nil
        if ENV["CHECK_YJIT_TRACE"]
          raise "YJIT stats required" unless RubyVM::YJIT.runtime_stats&.key?(:exit_trace_leave)
          request = Rack::MockRequest.new(Rails.application)
          100.times { request.get("/articles", "HTTP_HOST" => "example.org") }
          before = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave)
          raise "request failed" unless request.get("/articles", "HTTP_HOST" => "example.org").status == 200
          trace_exits = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave) - before
        end
        puts JSON.generate(status: response.status, body: response.body, conversions: $conversions,
          events: events, metadata: metadata, hits: Lowrail::Stats.unit_hits, fallbacks: Lowrail::Stats.unit_fallbacks,
          trace_exits: trace_exits,
          refusal: defined?(Lowrail::Sealed) && Lowrail::Sealed.refusal)
      RUBY
      %w[stock view builder].each do |receiver|
        foreign = receiver == "stock" ? nil : receiver
        off, refused, sealed = [["0", nil], ["1", nil], ["1", "1"]].map do |mode, opt_in|
          ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => mode,
            "LOWRAIL_SEALED" => opt_in, "LOWRAIL_STATS" => "", "FOREIGN" => foreign})
        end
        assert_equal 200, sealed["status"]
        assert_equal 1, sealed["conversions"]
        assert_equal ["live"], sealed["events"]
        %w[status body conversions events metadata].each do |key|
          assert_equal off[key], refused[key], "without opt-in: #{key}"
          assert_equal off[key], sealed[key], "#{receiver}: #{key}"
        end
        assert_empty refused["hits"]
        assert_equal receiver == "stock" ? 1 : 0, sealed.fetch("hits").fetch(link_unit, 0), sealed.inspect
        assert_equal receiver == "stock" ? 0 : 1, sealed.fetch("fallbacks").fetch(link_unit, 0)
        assert_equal '<a class="one&quot;two" href="/target?x=&lt;&amp;q=&quot;">A&lt;&amp;</a>', sealed["body"] if receiver == "stock"
      end
      # disasm normalizes trace_leave to leave, so a text search is vacuous.
      # Exercise the executable VM state after real cold delivery/activation.
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "production"), bin,
        "build", dir, "--env", "production", "--sealed", "--jit", "yjit")
      assert status.success?, "#{out}\n#{err}"
      traced = ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => "1",
        "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "", "CHECK_YJIT_TRACE" => "1",
        "RUBYOPT" => "#{SETUP_OPT} --yjit --yjit-stats=quiet"})
      assert_nil traced["refusal"]
      assert_operator traced.fetch("hits").fetch(link_unit, 0), :>, 0
      assert_equal 0, traced.fetch("trace_exits"), "boot observers must not patch unrelated request ISeqs"
      FileUtils.mkdir_p(File.join(dir, "config/initializers"))
      File.write(File.join(dir, "config/initializers/private_builder.rb"), <<~'RUBY')
        Rails.application.config.after_initialize do
          ActionView::Helpers::TagHelper::TagBuilder.send(:private, :content_tag_string)
        end
      RUBY
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "production", "LOWRAIL_BUILD_JIT" => "0"), bin, "build", dir, "--env", "production", "--sealed")
      assert status.success?, "#{out}\n#{err}"
      refused = JSON.parse(File.read(File.join(dir, ".lowrail/manifest.json")))
      refute refused.fetch("units").any? { _1["pass"] == "sealed/link_to" }
      ledger = JSON.parse(File.read(File.join(dir, ".lowrail/ledger.json")))
      assert ledger.any? { _1["detail"] == "non-stock helper visibility" }, ledger.inspect
    end
  end
end
