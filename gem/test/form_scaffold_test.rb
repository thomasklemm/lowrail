# frozen_string_literal: true

require_relative "test_helper"

class FormScaffoldTest < Minitest::Test
  include LowrailTest

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
        out, err, status = Open3.capture3(build_env.merge("LOWRAIL_SEALED" => "1", "LOWRAIL_FORM_CHECK" => "1"),
          RUBY, checker, app, output, observer, File.join(app, ".lowrail"))
        assert status.success?, "#{out}\n#{err}"
        assert_includes out, "192 isolated pairs identical"
        on = JSON.parse(File.read(File.join(output, "on.json")))
        assert_operator on.fetch("form_hits"), :>, 0
        assert_equal 0, on.fetch("fallbacks").fetch(form.fetch("id").to_s, 0)
        if observer == "render_subscriber"
          assert on.fetch("responses").any? { _1.fetch("headers")["x-render-observer"] == "live" }
        end
      end
      out, err, status = ruby("--disable-yjit", "--disable-zjit", File.expand_path("../../bench/pass_probe.rb", __dir__),
        "GET:/articles/1", chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1",
          "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "", "BENCH_JIT" => "0", "BENCH_UNITS" => form.fetch("id").to_s})
      assert status.success?, "#{out}\n#{err}"
      coverage = JSON.parse(out.lines.find { _1.start_with?("LOWRAIL_BENCH ") }.delete_prefix("LOWRAIL_BENCH "))
      assert_equal [{"id" => form.fetch("id"), "pass" => "sealed/form_scaffold", "hits_per_request" => 1.0,
        "fallbacks_per_request" => 0.0}], coverage.fetch("units")
      retention = ruby_json(<<~'RUBY', chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
        require "weakref"
        require "lowrail/form_scaffold_inventory"
        roots = []
        # Test-only lifetime observer: nested tracing is suppressed while
        # activation runs inside the initialize! completion TracePoint.
        observer = Module.new do
          define_method(:template) do |path|
            source = super(path)
            roots.replace(instance_variable_get(:@compiled).values.map { WeakRef.new(_1) })
            source
          end
        end
        Lowrail::FormScaffoldInventory.singleton_class.prepend(observer)
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        raise "no source roots witnessed: #{Lowrail::FormScaffold.refusal}" if roots.empty?
        3.times { GC.start(full_mark: true, immediate_sweep: true) }
        raise "certification roots retained" if roots.any?(&:weakref_alive?)
        require "rack/mock"
        session = Rack::MockRequest.new(Rails.application)
        request = -> {
          response = session.get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
          raise "HTTP #{response.status}" unless response.status == 200
        }
        id = Lowrail.manifest.units.find { _1["pass"] == "sealed/form_scaffold" }.fetch("id").to_s
        counts = -> { [Lowrail::Stats.unit_hits.fetch(id, 0), Lowrail::Stats.unit_fallbacks.fetch(id, 0)] }
        Lowrail::Stats.reset_counts!
        50.times { request.call }
        result = {requests: counts.call}
        Lowrail::Sealed::EPOCH[0] = 1
        request.call
        result[:epoch] = counts.call
        Lowrail::Sealed::EPOCH[0] = 0
        Lowrail::Stats.reset_counts!
        # A later public setup must refuse recertification, not silently
        # reopen the source compiler after its boot-only roots were released.
        Lowrail.setup(root: Dir.pwd)
        request.call
        result[:later_setup] = counts.call
        result[:refusal] = Lowrail::FormScaffold.refusal
        puts JSON.generate(result)
      RUBY
      assert_equal [50, 0], retention.fetch("requests")
      assert_equal [50, 1], retention.fetch("epoch")
      assert_equal [0, 1], retention.fetch("later_setup")
      assert_includes retention.fetch("refusal"), "source inventory released"
      out, err, status = ruby("--disable-yjit", "--disable-zjit", File.expand_path("../../bench/heap_operations.rb", __dir__),
        "GET:/articles/1", chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1",
          "LOWRAIL_SEALED" => "1", "BENCH_JIT" => "0", "BENCH_UNITS" => form.fetch("id").to_s, "BENCH_OPERATION_CHECK" => "1"})
      assert status.success?, "#{out}\n#{err}"
      operations = JSON.parse(out.lines.find { _1.start_with?("LOWRAIL_BENCH ") }.delete_prefix("LOWRAIL_BENCH "))
      assert operations.fetch("untimed")
      assert_equal({form.fetch("id").to_s => {"invocations_per_iteration" => 1, "invocations_per_request" => 1,
        "completed_hits_per_iteration" => 1, "completed_hits_per_request" => 1}}, operations.fetch("operations"))
      replay = ruby_json(<<~'RUBY', chdir: app, env: {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => ""})
        require "./config/application"
        Rails.application.config.yjit = false
        require "./config/environment"
        require "rack/mock"
        raise Lowrail::FormScaffold.refusal if Lowrail::FormScaffold.refusal
        captured = nil
        # Observe only this one ISeq, not a global tracing event. Capture the
        # real ERB block; every replay below calls the public form_with API.
        trace = TracePoint.new(:call) do |event|
          captured = [event.self, event.binding.local_variable_get(:model), event.binding.local_variable_get(:block)]
          trace.disable
        end
        trace.enable(target: Lowrail::FormScaffold::Variant.instance_method(:form_with)) do
          Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
        end
        view, models, block = captured
        original = view.method(:form_with).super_method
        id = Lowrail.manifest.units.find { _1["pass"] == "sealed/form_scaffold" }.fetch("id").to_s
        counts = -> { [Lowrail::Stats.unit_hits.fetch(id, 0), Lowrail::Stats.unit_fallbacks.fetch(id, 0)] }
        normalize = ->(html) { html.gsub(/(name="authenticity_token" value=")[^"]+/, '\\1MASK') }
        check = ->(model) do
          before = counts.call
          left = original.call(model: [models.first, model], class: "space-y-4", &block)
          right = view.form_with(model: [models.first, model], class: "space-y-4", &block)
          raise "form output/safety differs" unless normalize.call(left) == normalize.call(right) && left.html_safe? == right.html_safe? && left.encoding == right.encoding
          [left, right].each do |html|
            token = html[/name="authenticity_token" value="([^"]+)"/, 1] or raise "token missing"
            decoded = view.controller.send(:unmask_token, view.controller.send(:decode_csrf_token, token))
            action = html[/action="([^"]+)"/, 1]
            verb = html[/name="_method" value="([^"]+)"/, 1] || "post"
            expected = view.controller.send(:per_form_csrf_token, view.session, URI.parse(action).path, verb)
            raise "token not valid for emitted form" unless ActiveSupport::SecurityUtils.fixed_length_secure_compare(decoded, expected)
          end
          counts.call.zip(before).map { _1 - _2 }
        end
        result = {blank: check.call(Comment.new)}
        result[:nonblank] = check.call(Comment.new(commenter: "<& Ω", body: "not blank"))
        errors = Comment.new
        errors.errors.add(:body, "not accepted")
        result[:errors] = check.call(errors)
        singleton = Comment.new
        singleton.define_singleton_method(:body) { "singleton" }
        result[:singleton] = check.call(singleton)
        result[:persisted] = check.call(Comment.first!)
        view.instance_variable_set(:@_default_form_builder, Class.new(ActionView::Helpers::FormBuilder))
        result[:builder] = check.call(Comment.new)
        view.instance_variable_set(:@_default_form_builder, nil)
        I18n.available_locales |= [:fr]
        I18n.with_locale(:fr) { result[:locale] = check.call(Comment.new) }
        Lowrail::Sealed::EPOCH[0] = 1
        result[:deopt] = check.call(Comment.new)
        Lowrail::Sealed::EPOCH[0] = 0
        table = ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS
        saved = table.dup
        table[:label], table["label"], table["textarea"] = "SYMBOL", "WRONG", "TEXTAREA"
        result[:live_table] = check.call(Comment.new)
        table.replace(saved)
        puts JSON.generate(result)
      RUBY
      assert_equal({"blank" => [1, 0], "nonblank" => [0, 1], "errors" => [0, 1], "singleton" => [0, 1],
        "persisted" => [0, 1], "builder" => [0, 1], "locale" => [0, 1], "deopt" => [0, 1], "live_table" => [1, 0]}, replay)
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
        response = Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on")
        id = Lowrail.manifest.units.find { _1["pass"] == "sealed/form_scaffold" }.fetch("id").to_s
        puts JSON.generate(application: Rails.application.class.name, status: response.status,
          hits: Lowrail::Stats.unit_hits.fetch(id, 0), fallbacks: Lowrail::Stats.unit_fallbacks.fetch(id, 0))
      RUBY
      assert_equal({"application" => "RenamedFormFixture::Application", "status" => 200, "hits" => 1, "fallbacks" => 0}, renamed_result)
      output = File.join(dir, "renamed")
      out, err, status = Open3.capture3(build_env.merge("LOWRAIL_SEALED" => "1", "LOWRAIL_FORM_CHECK" => "1"),
        RUBY, checker, app, output, "none", File.join(app, ".lowrail"))
      assert status.success?, "#{out}\n#{err}\n#{Dir[File.join(output, '*.log')].map { File.read(_1) }.join("\n")}"
      assert_includes out, "192 isolated pairs identical"
      renamed_on = JSON.parse(File.read(File.join(output, "on.json")))
      assert_operator renamed_on.fetch("form_hits"), :>, 0
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
