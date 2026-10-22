# frozen_string_literal: true

require_relative "test_helper"
require "lowrail"

class SealedLinkTest < Minitest::Test
  include LowrailTest

  def test_lowering_preserves_multibyte_source_around_repeated_link_sites
    require "action_view"
    require "lowrail/sealed_build"
    source = <<~'RUBY'
      ["•", link_to("← Back", "/one?x=<&", class: "naïve"),
        "中", link_to("次へ", "/two", class: "second"), "終"]
    RUBY
    lowered, sites = Lowrail::SealedBuild.lower(source)
    assert_equal source.encoding, lowered.encoding
    assert lowered.valid_encoding?
    assert_equal 2, sites.count { _1["outcome"] == "lowered" }
    expected = ["•", '<a class="naïve" href="/one?x=&lt;&amp;">← Back</a>',
      "中", '<a class="second" href="/two">次へ</a>', "終"]
    view = ActionView::Base.empty
    assert_equal expected, view.instance_eval(source)
    assert_equal expected, view.instance_eval(lowered)
  end

  def test_cold_opt_in_delivery_preserves_response_effects_and_refuses_foreign_receivers
    skip "sealed link fixture requires Ruby 4.0.7 (running #{RUBY_VERSION})" unless RUBY_VERSION == "4.0.7"
    bin = lowrail_cli
    missing_prerequisite "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
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
            if ENV["SEND_OVERRIDE"]
              %i[send __send__ public_send method instance_exec].each do |dispatch|
                define_method(dispatch) do |*args, **kwargs, &block|
                  raise "view #{dispatch} intercepted tag_builder" if dispatch == :instance_exec || args.first == :tag_builder
                  super(*args, **kwargs, &block)
                end
              end
            end

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
      refute manifest.fetch("units").any? { _1["pass"] == "sealed/link_to" }
      assert_empty manifest.fetch("templates", {})
      ledger = JSON.parse(File.read(File.join(dir, ".lowrail/ledger.json")))
      assert ledger.any? { _1["pass"] == "sealed/link_to" && _1["reason"] == "quarantined" &&
        _1["detail"].include?("Templates::CompiledSource") }, ledger.inspect
      scenario = <<~'RUBY'
        Lowrail.send(:remove_const, :Native) if ENV["MISSING_NATIVE"] && defined?(Lowrail::Native)
        require "./config/environment"
        require "rack/mock"
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
          objspace: $LOADED_FEATURES.grep(/objspace/),
          ancestry: ActionView::Template.ancestors.map(&:name),
          runtime_holders: %w[Lowrail::Sealed Lowrail::Templates Lowrail::PreloadPlans].map { !!Lowrail.loaded_constant(_1) },
          refusal: Lowrail.refusal_reason)
      RUBY
      %w[stock send view builder].each do |receiver|
        foreign = %w[view builder].include?(receiver) ? receiver : nil
        off, refused, sealed, sealed_off = [["0", nil], ["1", nil], ["1", "1"], ["0", "1"]].map do |mode, opt_in|
          ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => mode,
            "LOWRAIL_SEALED" => opt_in, "LOWRAIL_STATS" => "", "FOREIGN" => foreign,
            "SEND_OVERRIDE" => receiver == "send" ? "1" : nil})
        end
        assert_equal 200, sealed["status"]
        assert_equal 1, sealed["conversions"]
        assert_equal ["live"], sealed["events"]
        %w[status body conversions events metadata ancestry].each do |key|
          assert_equal off[key], refused[key], "without opt-in: #{key}"
          assert_equal off[key], sealed[key], "#{receiver}: #{key}" unless key == "ancestry"
          assert_equal sealed_off[key], sealed[key], "sealed off/on: #{key}"
        end
        refute_includes off.fetch("ancestry"), "Lowrail::Guard::ObjectHooks"
        assert_includes sealed.fetch("ancestry"), "Lowrail::Guard::ObjectHooks",
          "explicit sealed opt-in installs the mutation observer equally off/on"
        assert_equal off.fetch("runtime_holders"), refused.fetch("runtime_holders")
        assert_equal sealed_off.fetch("runtime_holders"), sealed.fetch("runtime_holders")
        assert_empty refused["hits"]
        assert_empty sealed.fetch("objspace"), "neither app nor link admission loads objspace"
        admitted = %w[stock send].include?(receiver)
        assert_empty sealed.fetch("hits"), "link template delivery is ancestry-unsafe, including stock receivers"
        assert_empty sealed.fetch("fallbacks")
        assert_nil sealed.fetch("refusal"), "refused builders must not poison the safe artifact"
        refute_includes sealed.fetch("ancestry"), "Lowrail::Templates::CompiledSource"
        assert_equal [true, false, false], sealed.fetch("runtime_holders"), "Sealed is defined symmetrically by LOWRAIL_SEALED observers, never activated"
        assert_equal '<a class="one&quot;two" href="/target?x=&lt;&amp;q=&quot;">A&lt;&amp;</a>', sealed["body"] if admitted
      end
      application = File.join(dir, "config/application.rb")
      File.write(application, File.read(application).sub(/module \w+\n/, "module RenamedLinkFixture\n"))
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "production", "LOWRAIL_BUILD_JIT" => "0"), bin, "build", dir, "--env", "production", "--sealed")
      assert status.success?, "#{out}\n#{err}"
      manifest_path = File.join(dir, ".lowrail/manifest.json")
      certified = File.read(manifest_path)
      refute JSON.parse(certified).fetch("units").any? { _1["pass"] == "sealed/link_to" },
        "the delivery refusal is independent of the application name"
      off, sealed = %w[0 1].map do |mode|
        ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => mode,
          "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
      end
      %w[status body conversions events metadata].each { assert_equal off[_1], sealed[_1], "renamed: #{_1}" }
      assert_empty sealed.fetch("hits")
      assert_empty sealed.fetch("fallbacks")
      missing = ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => "1",
        "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "", "MISSING_NATIVE" => "1"})
      %w[status body conversions events metadata].each { assert_equal off[_1], missing[_1], "missing native: #{_1}" }
      assert_nil missing.fetch("refusal")
      assert_empty missing.fetch("hits")
      assert_empty missing.fetch("objspace"), "objspace is never a fallback"
      # Old/handwritten combined artifacts still refuse before delivery. Do
      # not run the quarantined builder just to manufacture such an artifact.
      unsafe = JSON.parse(certified)
      unsafe.fetch("units") << {"id" => 999, "pass" => "sealed/link_to", "facts" => []}
      File.write(manifest_path, JSON.generate(unsafe))
      refused = ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => "1",
        "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
      %w[status body conversions events metadata].each { assert_equal off[_1], refused[_1], "unsafe combined: #{_1}" }
      assert_empty refused.fetch("hits")
      assert_match(/app-visible ancestry delivery refused:/, refused.fetch("refusal"))
      deferred = ruby_json(<<~'RUBY', chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
        require "./config/environment"
        ArticlesController.instance_variable_set(:@view_context_class, nil)
        features = $LOADED_FEATURES.dup
        installed = Lowrail.setup
        refused = {installed: installed, active: Lowrail::Sealed::ACTIVE[0],
          view_class: ArticlesController.instance_variable_get(:@view_context_class), features: $LOADED_FEATURES == features}
        # Natural cache materialization cannot revive an unsafe artifact.
        ArticlesController.view_context_class
        allowed = Lowrail.setup
        puts JSON.generate(refused: refused, allowed: allowed, reason: Lowrail.refusal_reason)
      RUBY
      assert_equal({"installed" => false, "active" => false,
        "view_class" => nil, "features" => true}, deferred.fetch("refused"))
      assert_equal false, deferred.fetch("allowed")
      assert_match(/app-visible ancestry delivery refused:/, deferred.fetch("reason"))
      File.write(manifest_path, certified)
      # disasm normalizes trace_leave to leave, so a text search is vacuous.
      # Exercise the executable VM state after real cold delivery/activation.
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "production"), bin,
        "build", dir, "--env", "production", "--sealed", "--jit", "yjit")
      assert status.success?, "#{out}\n#{err}"
      traced = ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "production", "LOWRAIL" => "1",
        "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "", "CHECK_YJIT_TRACE" => "1",
        "RUBYOPT" => "#{SETUP_OPT} --yjit --yjit-stats=quiet"})
      assert_nil traced.fetch("refusal")
      assert_empty traced.fetch("hits")
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
      rows = ledger.select { _1["pass"] == "sealed/link_to" }
      assert_equal 1, rows.size, "the builder must not run even to refuse its custom helper"
      assert_equal "quarantined", rows.first.fetch("reason")
      assert_includes rows.first.fetch("detail"), "Templates::CompiledSource"
    end
  end
end
