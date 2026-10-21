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
        features = $LOADED_FEATURES.grep(%r{/lowrail/form_scaffold[^/]*\.rb\z}).sort
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
