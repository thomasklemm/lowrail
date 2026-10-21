# frozen_string_literal: true

require_relative "test_helper"

class FormScaffoldTest < Minitest::Test
  include LowrailTest

  def test_public_sealed_build_preserves_forms_observers_and_refuses_custom_builder
    bin = File.expand_path("../../target/debug/lowrail", __dir__)
    corpus = File.join(CORPUS_ROOT, "real-blog-r4")
    checker = File.expand_path("../../bench/experiments/blog_endpoint_check.rb", __dir__)
    skip "Ruby 4.0.7, built CLI and blog corpus required" unless RUBY_VERSION == "4.0.7" &&
      File.executable?(bin) && File.file?(File.join(corpus, "config/environment.rb"))
    realpath_tmpdir do |dir|
      app = File.join(dir, "blog")
      FileUtils.mkdir_p(app)
      # Do not alter the developer's corpus, database or existing artifacts.
      (Dir.children(corpus) - %w[.git .lowrail tmp log node_modules]).each do |name|
        FileUtils.cp_r(File.join(corpus, name), app)
      end
      build_env = CLEAN_ENV.merge("RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL_BUILD_JIT" => "0")
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
