# frozen_string_literal: true

require_relative "test_helper"

class FormScaffoldTest < Minitest::Test
  include LowrailTest

  def test_render_units_without_blog_models_templates_or_form_inventory
    skip "sealed rendering fixture requires Ruby 4.0.7 (running #{RUBY_VERSION})" unless RUBY_VERSION == "4.0.7"
    missing_prerequisite "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |app|
      LowrailTest.write_rails_app(app,
        "Gemfile" => "source 'https://rubygems.org'\ngem 'rails', '8.1.4'\ngem 'sqlite3'\ngem 'bcrypt'\ngem 'prism'\ngem 'bootsnap'\n",
        "Gemfile.lock" => "",
        "config/environment.rb" => "require_relative 'application'\nRails.application.initialize!\n",
        "config/application.rb" => <<~'RUBY',
          require "bootsnap"
          Bootsnap.setup(cache_dir: File.join(Dir.pwd, "tmp/cache"), development_mode: false,
            load_path_cache: true, compile_cache_iseq: true, compile_cache_yaml: true, compile_cache_json: true)
          require "rails"
          require "active_record/railtie"
          require "action_controller/railtie"
          require "action_view/railtie"
          class WidgetFixture < Rails::Application
            config.root = File.expand_path("..", __dir__)
            config.eager_load = true
            config.yjit = false
            config.logger = Logger.new(nil)
            config.secret_key_base = "x" * 64
            config.active_support.deprecation = :silence
          end
        RUBY
        "config/database.yml" => "production:\n  adapter: sqlite3\n  database: database.sqlite3\n",
        "app/models/widget.rb" => "class Widget < ApplicationRecord; end\n",
        "app/controllers/widgets_controller.rb" => <<~'RUBY',
          class WidgetsController < ApplicationController
            def index; end
            def form_authenticity_token(**) = 'live<&"'
          end
        RUBY
        "app/controllers/custom_widgets_controller.rb" => <<~'RUBY',
          class CustomWidgetsController < ApplicationController
            helper do
              def token_tag(*) = "controller-token".html_safe
              private :token_tag
            end
            def index = render "widgets/index"
          end
        RUBY
        "config/routes.rb" => "Rails.application.routes.draw { resources :widgets, only: :index; get '/custom_widgets', to: 'custom_widgets#index' }\n",
        "app/views/widgets/index.html.erb" => '<%= content_tag :span, "prefix" %><%= button_to "Go", "/widgets" %><%= render partial: "widgets/row", collection: ["left<&", "right"], as: :widget %>',
        "app/views/widgets/_row.html.erb" => '<p><%= widget %></p>')
      FileUtils.mkdir_p(File.join(app, ".lowrail"))
      denied = %w[memo/sha256 memo/uri_join digest/file_memo active_record/preload_plans active_record/ar_plans
        inertia/config_bind sealed/link_to].map { {"pass" => _1} }
      denied << {"pass" => "active_record/instantiate", "file" => "Widget"}
      File.write(File.join(app, ".lowrail/denylist.json"), JSON.generate(denied))
      env = CLEAN_ENV.merge("RAILS_ENV" => "production", "LOWRAIL_BUILD_JIT" => "0")
      build = -> {
        out, err, status = Open3.capture3(env, lowrail_cli, "build", app, "--env", "production", "--sealed")
        assert status.success?, "#{out}\n#{err}"
        JSON.parse(File.read(File.join(app, ".lowrail/manifest.json")))
      }
      artifact = build.call
      assert_equal %w[sealed/token_tag sealed/collection_render], artifact.fetch("units").map { _1.fetch("pass") }
      scenario = <<~'RUBY'
        require "./config/environment"
        require "rack/mock"
        request = Rack::MockRequest.new(Rails.application)
        bodies = 3.times.map do
          response = request.get("/widgets", "HTTP_HOST" => "example.org")
          raise "HTTP #{response.status}" unless response.status == 200
          response.body
        end
        custom = request.get("/custom_widgets", "HTTP_HOST" => "example.org")
        raise "custom HTTP #{custom.status}" unless custom.status == 200
        puts JSON.generate(bodies: bodies, custom: custom.body, blog: %w[Article Comment ArticlesController].any? { Object.const_defined?(_1) },
          hits: Lowrail::Stats.unit_hits, refusal: Lowrail.refusal_reason,
          admissions: [Lowrail::TokenTag, Lowrail::CollectionRender].map { [_1.refusal, _1.admission] })
      RUBY
      off, on = %w[0 1].map do |mode|
        ruby_json(scenario, chdir: app, env: env.merge("RUBYOPT" => SETUP_OPT,
          "LOWRAIL" => mode, "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "1"))
      end
      refute on.fetch("blog")
      assert_equal off.fetch("bodies"), on.fetch("bodies")
      assert_includes on.fetch("bodies").last, "left&lt;&amp;"
      assert_includes on.fetch("bodies").last, "live&lt;&amp;&quot;"
      assert_equal off.fetch("custom"), on.fetch("custom")
      assert_includes on.fetch("custom"), "controller-token"
      artifact.fetch("units").each { assert_operator on.fetch("hits").fetch(_1.fetch("id").to_s, 0), :>, 0, on.inspect }

      # A custom token helper must remain live; unrelated collection admission
      # must not inherit its refusal or require a form-builder certificate.
      FileUtils.mkdir_p(File.join(app, "config/initializers"))
      File.write(File.join(app, "config/initializers/custom_token.rb"), <<~'RUBY')
        ActiveSupport.on_load(:action_view) do
          define_method(:token_tag) { |*args, **options| "custom-token".html_safe }
          private :token_tag
        end
      RUBY
      custom_artifact = build.call
      assert_equal ["sealed/collection_render"], custom_artifact.fetch("units").map { _1.fetch("pass") }
      custom = ruby_json(scenario, chdir: app, env: env.merge("RUBYOPT" => SETUP_OPT,
        "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "1"))
      assert_includes custom.fetch("bodies").last, "custom-token"
      assert_operator custom.fetch("hits").fetch(custom_artifact.fetch("units").first.fetch("id").to_s, 0), :>, 0
    end
  end

  def test_passive_production_token_and_collection_public_artifact
    skip "sealed rendering fixture requires Ruby 4.0.7 (running #{RUBY_VERSION})" unless RUBY_VERSION == "4.0.7"
    corpus = File.join(CORPUS_ROOT, "real-blog-r4")
    missing_prerequisite "no #{corpus} (see script/corpus)" unless File.file?(File.join(corpus, "config/environment.rb"))
    fixture = File.expand_path("../../fixtures/corpus/blog_show_get_only.rb", __dir__)
    checker = File.expand_path("../../bench/experiments/sealed_production_check.rb", __dir__)
    realpath_tmpdir do |dir|
      app = File.join(dir, "blog")
      FileUtils.mkdir_p(app)
      (Dir.children(corpus) - %w[.git .lowrail tmp log node_modules storage]).each { FileUtils.cp_r(File.join(corpus, _1), app) }
      FileUtils.mkdir_p(File.join(app, "storage"))
      env = CLEAN_ENV.merge("RAILS_ENV" => "production", "RACK_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1",
        "LOWRAIL_BUILD_JIT" => "0", "LOWRAIL_SEALED" => nil)
      out, err, status = ruby("-e", <<~'RUBY', fixture, chdir: app, setup: false, env: env)
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require ARGV.fetch(0)
        BlogShowGetOnly.prepare
        puts JSON.generate(ActiveRecord::Base.descendants.filter_map(&:name).sort)
      RUBY
      assert status.success?, "#{out}\n#{err}"
      models = JSON.parse(out.lines.last)
      FileUtils.cp_r(File.join(app, "storage"), File.join(dir, "seed"))
      FileUtils.mkdir_p(File.join(app, ".lowrail"))
      denied = %w[memo/sha256 memo/uri_join digest/file_memo active_record/preload_plans active_record/ar_plans
        inertia/config_bind sealed/link_to].map { {"pass" => _1} }
      denied.concat(models.map { {"pass" => "active_record/instantiate", "file" => _1} })
      File.write(File.join(app, ".lowrail/denylist.json"), JSON.generate(denied))
      out, err, status = Open3.capture3(env, lowrail_cli, "build", app, "--env", "production", "--sealed")
      assert status.success?, "#{out}\n#{err}"
      manifest_path = File.join(app, ".lowrail/manifest.json")
      manifest = JSON.parse(File.read(manifest_path))
      assert_equal %w[sealed/form_scaffold sealed/token_tag sealed/collection_render], manifest.fetch("units").map { _1.fetch("pass") }
      output = File.join(dir, "gates")
      out, err, status = ruby(checker, app, File.join(dir, "seed"), output, setup: false, env: env)
      assert status.success?, "#{out}\n#{err}"
      report = JSON.parse(File.read(File.join(output, "gates.json")))
      assert_equal "pass", report.fetch("status")
      assert_equal "BlogShowGetOnly", report.fetch("fixture").fetch("name")
      assert_equal [192, 192], report.fetch("pairs").values.map { _1.fetch("pairs") }
      assert report.fetch("cold").fetch("companions").all? { _1.fetch("cold_equal") && _1.fetch("forbidden_chains_absent") }

      # Generation and name conversion remain live and once-only, including a
      # post-generation continuation for values outside the literal residue.
      boot_env = env.merge("RUBYOPT" => SETUP_OPT, "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "")
      boundary = ruby_json(<<~'RUBY', chdir: app, env: boot_env)
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        view = nil
        trace = TracePoint.new(:call) { |event| view = event.self }
        trace.enable(target: Lowrail::TokenTag::Variant.instance_method(:token_tag))
        Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
        trace.disable
        raise "not admitted" unless Lowrail::TokenTag.admitted?
        original = view.method(:token_tag).super_method
        generated = converted = 0
        live_value = nil
        view.controller.define_singleton_method(:form_authenticity_token) { |**| generated += 1; live_value }
        name = Object.new
        name.define_singleton_method(:to_s) { converted += 1; 'csrf<&" Ω' }
        view.controller.class.request_forgery_protection_token = name
        options = {action: "/articles/1/comments", method: "post"}
        values = ['plain<&" Ω', 'safe<&" Ω'.html_safe, ["left<&", "right\""], /regexp<&"/, nil]
        records = values.map do |value|
          live_value = value
          generated = converted = 0
          left = original.call(nil, form_options: options)
          right = view.send(:token_tag, nil, form_options: options)
          {left: left, right: right, classes: [left.class.name, right.class.name],
            encodings: [left.encoding.name, right.encoding.name], generated: generated, converted: converted}
        end
        puts JSON.generate(records: records, stats: Lowrail::Stats.snapshot)
      RUBY
      boundary.fetch("records").each do |record|
        assert_equal record.fetch("left"), record.fetch("right")
        assert_equal 1, record.fetch("classes").uniq.size
        assert_equal 1, record.fetch("encodings").uniq.size
        assert_equal 2, record.fetch("generated"), "one generation in each arm, no replay after fallback"
        assert_equal 2, record.fetch("converted"), "one live name conversion in each arm"
      end

      # Install the live generator before boot/admission. Replacing its view's
      # builder later is input state, not a post-seal method/config mutation.
      replaced = ruby_json(<<~'RUBY', chdir: app, env: boot_env)
        require "./config/application"
        Rails.application.config.yjit = false
        module LiveTokenGenerator
          def form_authenticity_token(**options)
            probe = Thread.current[:token_builder_probe]
            return super unless probe
            probe[:calls] += 1
            probe.fetch(:view).instance_variable_set(:@tag_builder, probe.fetch(:builder))
            "live-token"
          end
        end
        ActiveSupport.on_load(:action_controller) { prepend LiveTokenGenerator }
        ActiveSupport.on_load(:action_view) do
          Object.const_set(:ReplacementTagBuilder, Class.new(ActionView::Helpers::TagHelper::TagBuilder) do
            def tag_options(_options, escape = true)
              ' data-probe="late-builder"'
            end
          end)
        end
        require "./config/environment"
        require "rack/mock"
        view = nil
        trace = TracePoint.new(:call) { |event| view = event.self }
        trace.enable(target: Lowrail::TokenTag::Variant.instance_method(:token_tag))
        Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
        trace.disable
        raise "not naturally admitted" unless Lowrail::TokenTag.admitted?
        original = view.method(:token_tag).super_method
        plain = view.instance_variable_get(:@tag_builder)
        id = Lowrail.manifest.units.find { _1.fetch("pass") == "sealed/token_tag" }.fetch("id").to_s
        options = {action: "/articles/1/comments", method: "post"}
        records = [ReplacementTagBuilder.new(view), plain].map do |builder|
          before = [Lowrail::Stats.unit_hits.fetch(id, 0), Lowrail::Stats.unit_fallbacks.fetch(id, 0)]
          outputs = [false, true].map do |fast|
            view.instance_variable_set(:@tag_builder, plain)
            probe = {view: view, builder: builder, calls: 0}
            Thread.current[:token_builder_probe] = probe
            output = fast ? view.send(:token_tag, nil, form_options: options) : original.call(nil, form_options: options)
            Thread.current[:token_builder_probe] = nil
            {output: output, generated: probe.fetch(:calls)}
          end
          {outputs: outputs, hits: Lowrail::Stats.unit_hits.fetch(id, 0) - before[0],
            fallbacks: Lowrail::Stats.unit_fallbacks.fetch(id, 0) - before[1]}
        end
        puts JSON.generate(records: records, admitted: Lowrail::TokenTag.admitted?)
      RUBY
      foreign, restored = replaced.fetch("records")
      assert_equal '<input data-probe="late-builder" />', foreign.fetch("outputs").first.fetch("output")
      replaced.fetch("records").each do |record|
        assert_equal record.fetch("outputs").first.fetch("output"), record.fetch("outputs").last.fetch("output")
        assert_equal [1, 1], record.fetch("outputs").map { _1.fetch("generated") }, "one generation per arm, no replay"
      end
      assert_equal [0, 1], foreign.values_at("hits", "fallbacks")
      assert_equal [1, 0], restored.values_at("hits", "fallbacks"), "a foreign input must not retire the unit"
      assert replaced.fetch("admitted")

      # Helpers are live fcall boundaries, not public/reflective sends. Install
      # these before the first natural witness, not as post-seal mutations.
      dispatches = %w[private protected reflective method_missing].map do |mode|
        ruby_json(<<~'RUBY', chdir: app, env: boot_env.merge("DISPATCH_CASE" => mode))
          require "./config/application"
          Rails.application.config.yjit = false
          module LiveDispatchHelpers
            def protect_against_forgery? = !!Thread.current[:dispatch_probe]
            def form_authenticity_token(**)
              probe = Thread.current.fetch(:dispatch_probe)
              probe[:generated] += 1
              probe.fetch(:value)
            end
            def request_forgery_protection_token = Thread.current.fetch(:dispatch_probe).fetch(:name)
            def method_missing(name, *args, **kwargs, &block)
              return super unless name == :form_authenticity_token
              begin
                super
              rescue NameError => error
                probe = Thread.current.fetch(:dispatch_probe)
                # csrf_meta_tags uses a bare vcall (NameError); token_tag's
                # keyword fcall reports NoMethodError#private_call?.
                probe[:private_calls] << error.private_call? if NoMethodError === error
                probe[:generated] += 1
                probe.fetch(:value)
              end
            end
            def respond_to_missing?(name, include_private = false)
              name == :form_authenticity_token || super
            end
          end
          module ReflectiveDispatchTrap
            %i[send public_send __send__ instance_exec method].each do |dispatch|
              define_method(dispatch) do |*args, **kwargs, &block|
                if (probe = Thread.current[:dispatch_probe]) && dispatch == :public_send && args.first == "article_comments_path"
                  probe[:routes] << [args.first.class.name, args.first.frozen?, args.fetch(1).id]
                  return "/live-public-route"
                end
                # Rails' real _run uses public_send for its compiled template.
                # Trap only helper dispatch, not that original boundary.
                if (probe = Thread.current[:dispatch_probe]) && (dispatch == :instance_exec ||
                    %i[protect_against_forgery? form_authenticity_token request_forgery_protection_token
                       tag tag_builder output_buffer article_comments_path url_for token_tag].include?(args.first))
                  probe[:intercepted] << dispatch.to_s
                  raise "app #{dispatch} intercepted a helper"
                end
                super(*args, **kwargs, &block)
              end
            end
          end
          mode = ENV.fetch("DISPATCH_CASE")
          installed_before_boot = false
          Rails.application.config.after_initialize do
            klass = ArticlesController.view_context_class
            case mode
            when "private", "protected"
              LiveDispatchHelpers.send(mode, :form_authenticity_token)
              klass.send(mode, :output_buffer)
            when "method_missing"
              LiveDispatchHelpers.send(:undef_method, :form_authenticity_token)
            end
            klass.prepend(LiveDispatchHelpers)
            klass.prepend(ReflectiveDispatchTrap)
            installed_before_boot = !Rails.application.initialized? && Lowrail::TokenTag.admission.fetch(:attempts).zero?
          end
          require "./config/environment"
          require "rack/mock"
          view = nil
          trace = TracePoint.new(:call) { |event| view = event.self }
          trace.enable(target: Lowrail::TokenTag::Variant.instance_method(:token_tag))
          status = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on").status
          trace.disable
          original = view.method(:token_tag).super_method
          invoke = Kernel.instance_method(:send)
          id = Lowrail.manifest.units.find { _1.fetch("pass") == "sealed/token_tag" }.fetch("id").to_s
          before = Lowrail::Stats.unit_hits.fetch(id, 0)
          options = {action: "/articles/1/comments", method: "post"}
          records = ["live-token", ["left<&", 'right"']].map do |value|
            [false, true].map do |fast|
              probe = {value: value, generated: 0, converted: 0, private_calls: [], intercepted: []}
              name = Object.new
              name.define_singleton_method(:to_s) { probe[:converted] += 1; 'actual-csrf<&"' }
              probe[:name] = name
              Thread.current[:dispatch_probe] = probe
              begin
                output = fast ? invoke.bind_call(view, :token_tag, nil, form_options: options) : original.call(nil, form_options: options)
                {output: output, generated: probe[:generated], converted: probe[:converted],
                  private_calls: probe[:private_calls], intercepted: probe[:intercepted]}
              rescue StandardError => error
                {error: error.class.name, message: error.message.lines.first.strip}
              ensure
                Thread.current[:dispatch_probe] = nil
              end
            end
          end
          literal_hits = Lowrail::Stats.unit_hits.fetch(id, 0) - before
          probe = {value: "live-token", generated: 0, converted: 0, private_calls: [], intercepted: [], routes: []}
          name = Object.new
          name.define_singleton_method(:to_s) { probe[:converted] += 1; "whole-request-csrf" }
          probe[:name] = name
          before = Lowrail::Stats.unit_hits.dup
          Thread.current[:dispatch_probe] = probe
          begin
            response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
          ensure
            Thread.current[:dispatch_probe] = nil
          end
          hot = {status: response.status, fields: response.body.scan('name="whole-request-csrf"').size,
            generated: probe[:generated], converted: probe[:converted], intercepted: probe[:intercepted],
            routes: probe[:routes], action: response.body.include?('action="/live-public-route"'),
            hits: Lowrail.manifest.units.to_h { [_1.fetch("pass"), Lowrail::Stats.unit_hits.fetch(_1.fetch("id").to_s, 0) - before.fetch(_1.fetch("id").to_s, 0)] }}
          puts JSON.generate(mode: mode, installed_before_boot: installed_before_boot, status: status,
            admitted: Lowrail::TokenTag.admitted?, records: records, hits: literal_hits, hot: hot)
        RUBY
      end
      dispatches.each do |record|
        assert record.fetch("installed_before_boot")
        assert_equal 200, record.fetch("status")
        assert record.fetch("admitted"), record.fetch("mode")
        record.fetch("records").each do |left, right|
          assert_equal left, right, record.fetch("mode")
          assert_equal [1, 1], left.values_at("generated", "converted")
          assert_empty left.fetch("intercepted")
          assert_equal [true], left.fetch("private_calls") if record.fetch("mode") == "method_missing"
        end
        assert_equal 1, record.fetch("hits"), "one literal hit, one original tag continuation"
        hot = record.fetch("hot")
        # Four hidden fields plus the layout's stock csrf_meta_tags pair.
        assert_equal [200, 4, 5, 5], hot.values_at("status", "fields", "generated", "converted"), record.fetch("mode")
        assert_empty hot.fetch("intercepted")
        assert_equal [["String", false, 1]], hot.fetch("routes"), "retain stock explicit public route dispatch"
        assert hot.fetch("action")
        assert_equal({"sealed/form_scaffold" => 1, "sealed/token_tag" => 4, "sealed/collection_render" => 1}, hot.fetch("hits"))
      end

      # A transitive helper replacement used to leave the admitted token body
      # live, silently omitting the new tag_option behavior. Exercise both
      # callback and ancestor edits, before and after the natural admission.
      %w[before after].product(%w[replace prepend]).each do |phase, change|
        mutation = ruby_json(<<~'RUBY', chdir: app, env: boot_env.merge("MUTATION_PHASE" => phase, "MUTATION_KIND" => change))
          require "./config/application"
          Rails.application.config.yjit = false
          require "./config/environment"
          require "rack/mock"
          view = nil
          trace = TracePoint.new(:call) { |event| view = event.self }
          warm = -> {
            trace.enable(target: Lowrail::TokenTag::Variant.instance_method(:token_tag))
            response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
            trace.disable
            raise "HTTP #{response.status}" unless response.status == 200
          }
          phase = ENV.fetch("MUTATION_PHASE")
          warm.call if phase == "after"
          routes = []
          if phase == "after"
            request = Rack::MockRequest.new(Rails.application)
            %w[/ /articles /articles/new /articles/1/edit /articles/2].each do |path|
              response = request.get(path, "HTTP_HOST" => "localhost", "HTTPS" => "on")
              routes << [path, response.status]
            end
            warm.call
          end
          admitted_before = Lowrail::TokenTag.admitted?
          epoch_before = Lowrail::Sealed::EPOCH[0]
          builder = ActionView::Helpers::TagHelper::TagBuilder
          stock = builder.instance_method(:tag_option)
          replacement = proc do |key, value, escape|
            output = stock.bind_call(self, key, value, escape)
            key.to_s == "value" ? output.sub('value="', 'value="MUTATED-') : output
          end
          if ENV.fetch("MUTATION_KIND") == "replace"
            builder.define_method(:tag_option, &replacement)
          else
            builder.prepend(Module.new { define_method(:tag_option, &replacement) })
          end
          warm.call if phase == "before"
          view.controller.define_singleton_method(:form_authenticity_token) { |**| 'live<&"' }
          original = view.method(:token_tag).super_method
          options = {action: "/articles/1/comments", method: "post"}
          id = Lowrail.manifest.units.find { _1.fetch("pass") == "sealed/token_tag" }.fetch("id").to_s
          before = [Lowrail::Stats.unit_hits.fetch(id, 0), Lowrail::Stats.unit_fallbacks.fetch(id, 0)]
          off = original.call(nil, form_options: options)
          on = view.send(:token_tag, nil, form_options: options)
          puts JSON.generate(off: off, on: on, admitted_before: admitted_before,
            routes: routes,
            epoch_before: epoch_before, epoch_after: Lowrail::Sealed::EPOCH[0],
            refusal: Lowrail::TokenTag.refusal, input_refusal: Lowrail::TokenTag.input_refusal,
            hits: Lowrail::Stats.unit_hits.fetch(id, 0) - before[0],
            fallbacks: Lowrail::Stats.unit_fallbacks.fetch(id, 0) - before[1])
        RUBY
        assert_equal mutation.fetch("off"), mutation.fetch("on"), "#{phase}/#{change}"
        assert_includes mutation.fetch("on"), 'value="MUTATED-live&lt;&amp;&quot;"'
        assert_equal 0, mutation.fetch("hits")
        if phase == "after"
          assert mutation.fetch("admitted_before")
          assert_equal [200] * 5, mutation.fetch("routes").map(&:last)
          assert_equal 0, mutation.fetch("epoch_before")
          assert_operator mutation.fetch("epoch_after"), :>, 0
          assert_equal 1, mutation.fetch("fallbacks")
          assert_match(/seal epoch changed/, mutation.fetch("input_refusal"))
        else
          assert_match(/tag_option changed; rebuild; terminal admission/, mutation.fetch("refusal"))
        end
      end

      bad = Marshal.load(Marshal.dump(manifest))
      bad.fetch("units").reject { _1["pass"] == "sealed/form_scaffold" }.each { _1.fetch("data").fetch("observer")["iseq"] = "changed" }
      File.write(manifest_path, JSON.generate(bad))
      declined = ruby_json(<<~'RUBY', chdir: app, env: boot_env)
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        statuses = 3.times.map { Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on").status }
        puts JSON.generate(statuses: statuses, stats: Lowrail::Stats.snapshot)
      RUBY
      assert_equal [200, 200, 200], declined.fetch("statuses")
      bad.fetch("units").reject { _1["pass"] == "sealed/form_scaffold" }.each do |unit|
        id = unit.fetch("id").to_s
        assert_equal 0, declined.fetch("stats").fetch("unit_hits").fetch(id, 0)
        assert_equal ["observer body changed; rebuild; terminal admission"], declined.fetch("stats").fetch("unit_refusals").fetch(id)
      end
    end
  end

  def test_public_sealed_build_preserves_forms_observers_and_refuses_custom_builder
    skip "sealed form fixture requires Ruby 4.0.7 (running #{RUBY_VERSION})" unless RUBY_VERSION == "4.0.7"
    corpus = File.join(CORPUS_ROOT, "real-blog-r4")
    checker = File.expand_path("../../bench/experiments/blog_endpoint_check.rb", __dir__)
    missing_prerequisite "no #{corpus} (see script/corpus)" unless File.file?(File.join(corpus, "config/environment.rb"))
    bin = lowrail_cli
    realpath_tmpdir do |dir|
      app = File.join(dir, "blog")
      FileUtils.mkdir_p(app)
      # Do not alter the developer's corpus, database or existing artifacts.
      (Dir.children(corpus) - %w[.git .lowrail tmp log node_modules]).each do |name|
        FileUtils.cp_r(File.join(corpus, name), app)
      end
      FileUtils.mkdir_p(File.join(app, "storage"))
      FileUtils.rm_f(Dir[File.join(app, "storage/production.sqlite3{,-wal,-shm}")])
      build_env = CLEAN_ENV.merge("RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL_BUILD_JIT" => "0")
      # The corpus supplies source, not a pre-seeded production database.
      # Prepare that cheap prerequisite only in this test's disposable copy.
      out, err, status = ruby("-e", <<~'RUBY', chdir: app, setup: false, env: build_env)
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        ActiveRecord::Schema.verbose = false
        load "db/schema.rb"
        3.times do |i|
          Article.insert!({id: i + 1, title: "Article #{i}", body: "Article body #{i}"})
          Comment.insert!({id: i + 1, article_id: i + 1, commenter: "Reader #{i}", body: "Comment #{i}"})
        end
      RUBY
      assert status.success?, "#{out}\n#{err}"
      inventory_probe = <<~'RUBY'
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "lowrail/form_scaffold_inventory"
        puts JSON.generate(Lowrail::FormScaffoldInventory.check)
      RUBY
      inventory_env = build_env.merge("LOWRAIL" => "0", "RUBYOPT" => SETUP_OPT)
      inventory = ruby_json(inventory_probe, chdir: app, env: inventory_env)
      assert_kind_of Hash, inventory, "plain form inventory must certify before comparing reporter preloads"
      %w[0 1].each do |census|
        reported = ruby_json(inventory_probe, chdir: app, env: inventory_env.merge(
          "LOWRAIL_OUTCOMES" => File.join(dir, "inventory-outcomes"), "LOWRAIL_VERIFY_LOADS" => census))
        assert_equal inventory, reported, "reporter/census=#{census} changed the complete form inventory"
      end
      # Exercise form admission, not an artifact that now refuses as a whole
      # because it contains the legacy ancestry-changing delivery seams.
      FileUtils.mkdir_p(File.join(app, ".lowrail"))
      File.write(File.join(app, ".lowrail/denylist.json"), JSON.generate(
        %w[active_record/preload_plans sealed/link_to].map { {"pass" => _1} }))
      build = -> {
        out, err, status = Open3.capture3(build_env, bin, "build", app, "--env", "production", "--sealed")
        assert status.success?, "#{out}\n#{err}"
        JSON.parse(File.read(File.join(app, ".lowrail/manifest.json")))
      }
      artifact = build.call
      form = artifact.fetch("units").find { _1["pass"] == "sealed/form_scaffold" }
      refute_nil form, File.read(File.join(app, ".lowrail/ledger.json"))
      assert_equal "sealed-v1", artifact.fetch("tier")
      %w[none render_subscriber].each do |observer|
        output = File.join(dir, observer)
        out, err, status = Open3.capture3(build_env.merge("LOWRAIL_SEALED" => "1", "LOWRAIL_FORM_CHECK" => "1",
          "LOWRAIL_OUTCOMES" => File.join(dir, "form-outcomes")),
          RUBY, checker, app, output, observer, File.join(app, ".lowrail"))
        assert status.success?, "#{out}\n#{err}"
        off = JSON.parse(File.read(File.join(output, "off.json")))
        on = JSON.parse(File.read(File.join(output, "on.json")))
        assert_equal 192, on.fetch("responses").size
        assert_equal off.fetch("responses"), on.fetch("responses")
        # One of the former 105 hits is now the original admission render.
        assert_equal 104, on.fetch("form_hits")
        assert_equal 0, on.fetch("fallbacks").fetch(form.fetch("id").to_s, 0)
        assert_nil on.fetch("refusals").fetch("Lowrail::FormScaffold")
        if observer == "render_subscriber"
          assert on.fetch("responses").any? { _1.fetch("headers")["x-render-observer"] == "live" }
        end
      end
      threaded = <<~'RUBY'
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        require "timeout"
        Rails.logger.level = :error
        ActiveRecord::Base.logger = nil
        # Test-only deterministic inputs, per thread, like the paired checker.
        # This is not the separately source-pinned blog C companion protocol.
        module FormEntropy
          def random_bytes(n = 16)
            rng = Thread.current[:form_rng]
            rng ? rng.bytes(n) : super
          end
        end
        SecureRandom.singleton_class.prepend(FormEntropy)
        OpenSSL::Random.singleton_class.prepend(FormEntropy)
        Time.singleton_class.prepend(Module.new do
          def now(...)
            Thread.current[:form_rng] ? Time.at(1_792_454_400).utc : super
          end
        end)
        Rack::Utils.singleton_class.prepend(Module.new do
          def clock_time
            Thread.current[:form_rng] ? 1000.0 : super
          end
        end)
        helper = ActionView::Helpers::FormHelper
        metadata = [helper.instance_method(:form_with).owner.name,
          helper.instance_method(:form_with).source_location, helper.ancestors.map(&:name)]
        features = $LOADED_FEATURES.grep(%r{/lowrail/(?:form_scaffold[^/]*|compilation|loader|routes)\.rb\z})
        # Hold the single witness while the other seven requests finish. This
        # forces calls to straddle publication instead of hoping for a race.
        entered, release, done = Queue.new, Queue.new, Queue.new
        if ENV["LOWRAIL"] == "1"
          observer = Module.new do
            define_method(:check) do |*args|
              entered << true
              release.pop
              super(*args)
            end
          end
          Lowrail::FormScaffoldAdmission.singleton_class.prepend(observer)
        end
        request = ->(i) do
          Thread.current[:form_rng] = Random.new(41231 + i)
          response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost",
            "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "concurrent-#{i}")
          [response.status, response.headers.to_h, response.body]
        ensure
          Thread.current[:form_rng] = nil
        end
        threads = 8.times.map { |i| Thread.new { result = request.call(i); done << true; result } }
        before = nil
        Timeout.timeout(30) do
          if ENV["LOWRAIL"] == "1"
            entered.pop
            7.times { done.pop }
            before = Lowrail::Stats.unit_hits.dup
            release << true
          end
          threads.each(&:join)
        end
        original = threads.map(&:value)
        id = Lowrail.manifest&.units&.find { _1["pass"] == "sealed/form_scaffold" }&.fetch("id")&.to_s
        first_hits = id ? Lowrail::Stats.unit_hits.fetch(id, 0) : 0
        later = request.call(8)
        puts JSON.generate(original: original, later: later, before: before, first_hits: first_hits,
          later_hits: id ? Lowrail::Stats.unit_hits.fetch(id, 0) : 0,
          admission: Lowrail::FormScaffold.admission, metadata: metadata, features: features)
      RUBY
      off, on = %w[0 1].map do |mode|
        ruby_json(threaded, chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => nil,
          "SECRET_KEY_BASE" => "lowrail-disposable-blog-companion-only-" * 4,
          "LOWRAIL" => mode, "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
      end
      %w[original later metadata features].each { assert_equal off.fetch(_1), on.fetch(_1), _1 }
      assert_equal 8, on.fetch("original").size
      assert on.fetch("original").all? { _1.first == 200 }
      assert_equal 0, on.fetch("before").fetch(form.fetch("id").to_s, 0)
      assert_equal 0, on.fetch("first_hits")
      assert_equal 1, on.fetch("later_hits")
      assert_equal "active", on.fetch("admission").fetch("state")
      assert_equal 1, on.fetch("admission").fetch("attempts")
      out, err, status = ruby("-e", <<~'RUBY', chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "", "LOWRAIL_DEBUG" => "1"})
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        session = Rack::MockRequest.new(Rails.application)
        2.times do
          raise "request failed" unless session.get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on").status == 200
        end
        before = Lowrail::FormScaffold.admission
        # A second setup must not reset the one-attempt admission budget.
        Lowrail.setup(root: Dir.pwd)
        puts JSON.generate(refusal: Lowrail::FormScaffold.refusal, stats: Lowrail::Stats.snapshot,
          before: before, after: Lowrail::FormScaffold.admission,
          source_roots: Lowrail::FormScaffoldInventory.instance_variable_get(:@compiled),
          variant: ArticlesController.view_context_class < Lowrail::FormScaffold::Variant)
      RUBY
      assert status.success?, "#{out}\n#{err}"
      assert_includes err, "form admission already configured"
      refusal = JSON.parse(out.lines.last)
      assert_equal "active", refusal.fetch("before").fetch("state")
      assert_equal "refused", refusal.fetch("after").fetch("state")
      assert_equal 1, refusal.fetch("after").fetch("attempts")
      assert_equal [refusal.fetch("refusal")], refusal.fetch("stats").fetch("unit_refusals").fetch(form.fetch("id").to_s)
      assert_nil refusal.fetch("source_roots")
      assert refusal.fetch("variant")
      out, err, status = Open3.capture3(bin, "explain", app, "--unit", form.fetch("id").to_s, "--json")
      assert status.success?, "#{out}\n#{err}"
      explanation = JSON.parse(out).fetch("units").first
      assert_nil explanation["activation_refusal"]
      assert explanation.fetch("guards").any? { _1.fetch("requirement").include?("first natural") }
      manifest_path = File.join(app, ".lowrail/manifest.json")
      bad = Marshal.load(Marshal.dump(artifact))
      bad.fetch("units").find { _1["pass"] == "sealed/form_scaffold" }.fetch("data").fetch("passive").fetch("native_method")["parameters"] = []
      File.write(manifest_path, JSON.generate(bad))
      failed = ruby_json(<<~'RUBY', chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        results = 3.times.map do
          response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
          {status: response.status, form: response.body.include?("<form"), admission: Lowrail::FormScaffold.admission}
        end
        puts JSON.generate(results: results, stats: Lowrail::Stats.snapshot)
      RUBY
      File.write(manifest_path, JSON.generate(artifact))
      assert failed.fetch("results").all? { _1.fetch("status") == 200 && _1.fetch("form") }
      terminal = failed.fetch("results").map { _1.fetch("admission") }.uniq
      assert_equal [{"state" => "refused", "attempts" => 1,
        "reason" => "actual-holder primitive changed; rebuild; terminal admission, attempts=1/1"}], terminal
      assert_equal 0, failed.fetch("stats").fetch("unit_hits").fetch(form.fetch("id").to_s, 0)
      assert_equal [terminal.first.fetch("reason")], failed.fetch("stats").fetch("unit_refusals").fetch(form.fetch("id").to_s)
      # rails new derives the namespace from the destination basename; a
      # copied corpus need not have the namespace of its current directory.
      application = File.join(app, "config/application.rb")
      source = File.read(application)
      renamed = source.sub(/^module [A-Z]\w*$/, "module RenamedFormFixture")
      refute_equal source, renamed
      File.write(application, renamed)
      renamed_form = build.call.fetch("units").find { _1["pass"] == "sealed/form_scaffold" }
      refute_nil renamed_form, File.read(File.join(app, ".lowrail/ledger.json"))
      assert_equal "RenamedFormFixture::Application", renamed_form.fetch("data").fetch("inventory").fetch("application_class")
      renamed_result = ruby_json(<<~'RUBY', chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        request = Rack::MockRequest.new(Rails.application)
        2.times { @response = request.get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on") }
        id = Lowrail.manifest.units.find { _1["pass"] == "sealed/form_scaffold" }.fetch("id").to_s
        puts JSON.generate(application: Rails.application.class.name, status: @response.status,
          hits: Lowrail::Stats.unit_hits.fetch(id, 0), fallbacks: Lowrail::Stats.unit_fallbacks.fetch(id, 0))
      RUBY
      assert_equal({"application" => "RenamedFormFixture::Application", "status" => 200, "hits" => 1, "fallbacks" => 0}, renamed_result)
      output = File.join(dir, "renamed")
      out, err, status = Open3.capture3(build_env.merge("LOWRAIL_SEALED" => "1", "LOWRAIL_FORM_CHECK" => "1"),
        RUBY, checker, app, output, "none", File.join(app, ".lowrail"))
      assert status.success?, "#{out}\n#{err}"
      renamed_on = JSON.parse(File.read(File.join(output, "on.json")))
      assert_equal JSON.parse(File.read(File.join(output, "off.json"))).fetch("responses"), renamed_on.fetch("responses")
      assert_equal 192, renamed_on.fetch("responses").size
      assert_equal 104, renamed_on.fetch("form_hits")
      assert_equal 0, renamed_on.fetch("fallbacks").fetch(renamed_form.fetch("id").to_s, 0)
      # Off-only reproduction must still check the certified identity, even
      # though Lowrail itself is not loaded in this worker.
      stale = File.join(dir, "stale")
      FileUtils.mkdir_p(stale)
      File.write(File.join(stale, "manifest.json"), JSON.generate(artifact))
      out, err, status = ruby(checker, "worker", File.join(dir, "stale.json"), chdir: app, setup: false,
        env: build_env.merge("LOWRAIL" => "0", "LOWRAIL_FORM_CHECK" => "1", "LOWRAIL_DIR" => stale))
      refute status.success?, "a certificate for a different application must not validate the off arm"
      assert_includes err, "certified application differs"
      # Same literal form and model, but a builder that adds observable output.
      # The public build must explain its refusal, not certify the customized
      # framework body or rely on a test-only installer.
      File.write(File.join(app, "config/initializers/form_builder.rb"), <<~'RUBY')
        Rails.application.config.after_initialize do
          class AppFormBuilder < ActionView::Helpers::FormBuilder
            def submit(...)
              super + "<!-- custom builder remains live -->".html_safe
            end
          end
          ActionView::Base.default_form_builder = AppFormBuilder
        end
      RUBY
      refused = build.call
      refute refused.fetch("units").any? { _1["pass"] == "sealed/form_scaffold" }
      ledger = JSON.parse(File.read(File.join(app, ".lowrail/ledger.json")))
      assert ledger.any? { _1["pass"] == "sealed/form_scaffold" && _1["detail"].to_s.include?("custom form builder") }, ledger.inspect
      scenario = <<~'RUBY'
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
        puts JSON.generate(status: response.status, custom: response.body.include?("<!-- custom builder remains live -->"),
          form_units: defined?(Lowrail) && Lowrail.manifest ? Lowrail.manifest.units.count { _1["pass"] == "sealed/form_scaffold" } : 0)
      RUBY
      %w[0 1].each do |enabled|
        result = ruby_json(scenario, chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1",
          "LOWRAIL" => enabled, "LOWRAIL_SEALED" => "1"})
        assert_equal({"status" => 200, "custom" => true, "form_units" => 0}, result)
      end
    end
  end
end
