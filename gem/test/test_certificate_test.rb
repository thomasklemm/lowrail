# frozen_string_literal: true

require_relative "test_helper"

class TestCertificateTest < Minitest::Test
  include LowrailTest

  def test_cross_environment_opt_ins_and_unknown_workers_refuse
    rows = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      data = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
        "compile_option" => "", "files" => {}, "units" => [{"id" => 0, "pass" => "sealed/link_to", "facts" => []}]}
      production = data.merge("tier" => "sealed-v1", "rails_env" => "production")
      verification = data.merge("tier" => "sealed-test-v1", "rails_env" => "test",
        "verification_test" => {"version" => 1, "mode" => "verification-only"})
      unsupported = %w[sealed/token_tag sealed/collection_render active_record/preload_plans].map do |pass|
        verification.merge("units" => [{"id" => 0, "pass" => pass, "facts" => []}])
      end
      ENV["LOWRAIL_SEALED"], ENV["LOWRAIL_VERIFY_TEST"] = "1", "1"
      puts JSON.generate([[production, "test", "1"], [verification, "production", "1"],
        [verification, "test", nil], [verification, "test", "2"],
        [verification, "test", "1"], [production, "production", "1"],
        *unsupported.map { [_1, "test", "1"] }].map do |artifact, env, workers|
        ENV["RAILS_ENV"], ENV["PARALLEL_WORKERS"] = env, workers
        Lowrail::Manifest.new(artifact, "/tmp").compatible?
      end)
    RUBY
    assert_equal [false, false, false, false, true, true, false, false, false], rows
  end

  def test_missing_real_initialization_never_authorizes_a_fact_free_unit
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "tmpdir"
      require "lowrail"
      ENV.update("RAILS_ENV" => "test", "PARALLEL_WORKERS" => "1", "LOWRAIL" => "1",
        "LOWRAIL_SEALED" => "1", "LOWRAIL_VERIFY_TEST" => "1")
      data = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
        "certification_jit" => Lowrail.jit_mode, "compile_option" => "", "files" => {},
        "tier" => "sealed-test-v1", "rails_env" => "test",
        "verification_test" => {"version" => 1, "mode" => "verification-only"},
        "units" => [{"id" => 0, "pass" => "active_record/instantiate", "facts" => [],
          "kind" => "runtime", "ar_instantiate" => {"model" => "NotLoaded"}}]}
      Dir.mktmpdir do |root|
        Dir.mkdir("#{root}/.lowrail")
        File.write("#{root}/.lowrail/manifest.json", JSON.generate(data))
        installed = Lowrail.setup(root: root)
        before = [Lowrail::TestCertificate.status, Lowrail.check(0), Lowrail::Stats.unit_hits]
        Lowrail::TestCertificate.test_initialized!
        puts JSON.generate([installed, before, Lowrail.check(0), Lowrail::TestCertificate.evidence])
      end
    RUBY
    assert_equal true, result[0]
    assert_equal ["pending", false, {}], result[1]
    assert_equal false, result[2]
    assert_equal "refused", result[3].fetch("state")
    refute_empty result[3].fetch("unit_refusals").fetch("0")
  end

  def test_source_set_includes_additions_removals_boot_and_test_initialization
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "tmpdir"
      require "fileutils"
      require "lowrail"
      require "lowrail/manifest"
      require "lowrail/test_certificate"
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(["#{root}/config", "#{root}/test"])
        File.write("#{root}/config/boot.rb", "boot")
        File.write("#{root}/test/test_helper.rb", "workers")
        original = Lowrail::TestCertificate.sources(root)
        File.write("#{root}/config/new.rb", "added")
        added = Lowrail::TestCertificate.sources(root)
        File.unlink("#{root}/test/test_helper.rb")
        removed = Lowrail::TestCertificate.sources(root)
        puts JSON.generate([original.keys, original != added, added != removed])
      end
    RUBY
    assert_equal ["config/boot.rb", "test/test_helper.rb"], result[0]
    assert_equal [true, true], result.drop(1)
  end

  def test_natural_generation_releases_pending_once_and_live_resets_do_not_retire
    with_runtime_certificate do |dir, boot|
      result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
        pending = Lowrail::TestCertificate.status
        query = -> { Widget.find_by_sql("SELECT * FROM widgets ORDER BY id").map { [_1.name, _1.status] } }
        before = query.call
        early_hits = Lowrail::Stats.unit_hits
        Lowrail::TestCertificate.test_initialized!
        3.times { query.call }
        subscription = ActiveSupport::Notifications.subscribe("instantiation.active_record") { |*| }
        ActiveSupport::CurrentAttributes.clear_all
        ActiveSupport::Notifications.unsubscribe(subscription)
        ActiveSupport::DescendantsTracker.reject!([Widget])
        Widget.class_eval { def unrelated_method = :still_live }
        after = query.call
        puts JSON.generate(pending: pending, early_hits: early_hits, before: before, after: after,
          stats: Lowrail::Stats.snapshot)
      RUBY
      assert_equal "pending", result.fetch("pending")
      assert_empty result.fetch("early_hits")
      assert_equal [["left", "draft"], ["right", "live"]], result.fetch("before")
      assert_equal result.fetch("before"), result.fetch("after")
      assert_equal 8, result.dig("stats", "unit_hits", "0")
      assert_empty result.dig("stats", "unit_deopts")
      assert_empty result.dig("stats", "unit_refusals")
    end
  end

  def test_active_parent_forks_original_child_with_no_inherited_authority_or_counters
    with_runtime_certificate do |dir, boot|
      result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
        query = -> { Widget.find_by_sql("SELECT * FROM widgets ORDER BY id").map(&:name) }
        Lowrail::TestCertificate.test_initialized!
        query.call # Entire first row's natural generation is still original.
        rows = query.call
        receiver, builder = Object.new, Object.new
        Lowrail::G[7] = Lowrail::Stats::STATE[7] = true
        Lowrail::Stats::HITS[7], Lowrail::Stats::MISSES[7] = 17, 29
        Lowrail::K[7] = receiver
        Lowrail::V[7] = {receiver => true}.compare_by_identity
        Lowrail::Sealed::ACTIVE[0] = true
        Lowrail::Sealed::BUILDERS[builder] = true
        Thread.current[Lowrail::Sealed::REQUEST] = :seeded
        Lowrail::FormScaffold.instance_variable_set(:@active, true)
        Lowrail::FormScaffold.instance_variable_set(:@pending, true)
        Lowrail::FormScaffold.instance_variable_set(:@view_class, receiver)
        Lowrail::FormScaffold.instance_variable_set(:@admission, {state: "active"})
        parent = Lowrail::Stats.snapshot
        reader, writer = IO.pipe
        pid = fork do
          reader.close
          initial = Lowrail::Stats.snapshot
          # Exercise the same source/runtime predicates after seeded authority
          # was inherited. Merely zeroing counters would leave these fast.
          decisions = [Lowrail::G[7] || Lowrail.check(7),
            Lowrail::K[7].equal?(receiver) || Lowrail.ok?(7, receiver),
            !!Lowrail::Sealed.view?(Object.new), !!Lowrail::FormScaffold.admitted?]
          got = query.call
          Lowrail::TestCertificate.test_initialized!
          restored = query.call
          writer.write(JSON.generate(initial: initial, decisions: decisions, rows: got, restored: restored,
            active: Lowrail::Sealed::ACTIVE[0], builder: Lowrail::Sealed::BUILDERS.key?(builder),
            token: Thread.current[Lowrail::Sealed::REQUEST],
            form: Lowrail::FormScaffold.admission, after: Lowrail::Stats.snapshot))
          writer.close
          exit! 0
        end
        writer.close
        child = JSON.parse(reader.read)
        Process.wait(pid)
        raise "child failed" unless $?.success?
        puts JSON.generate(rows: rows, parent: parent, child: child, parent_rows: query.call,
          parent_after: Lowrail::Stats.snapshot)
      RUBY
      assert_equal ["left", "right"], result.fetch("rows")
      assert_equal result.fetch("rows"), result.fetch("parent_rows")
      assert_equal 2, result.dig("parent", "unit_hits", "0")
      assert_equal 4, result.dig("parent_after", "unit_hits", "0")
      child = result.fetch("child")
      assert_empty child.dig("initial", "unit_hits")
      assert_empty child.dig("initial", "unit_fallbacks")
      assert_equal [false, false, false, false], child.fetch("decisions")
      assert_equal result.fetch("rows"), child.fetch("rows")
      assert_equal child.fetch("rows"), child.fetch("restored")
      assert_equal false, child.fetch("active")
      assert_equal false, child.fetch("builder")
      assert_nil child.fetch("token")
      assert_equal "refused", child.dig("form", "state")
      assert_empty child.dig("after", "unit_hits")
      assert_equal 2, child.dig("after", "unit_fallbacks", "0")
      assert_equal 1, child.dig("after", "unit_deopts", "0")
      assert_equal ["verification_unexpected_pid_original_only"], child.dig("after", "unit_refusals", "0")
    end
  end

  def test_real_config_builder_bootsnap_and_method_mutations_retire_stickily
    with_runtime_certificate do |dir, boot|
      %w[config builder bootsnap method schema suite_mode].each do |mutation|
        result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir).merge("MUTATION" => mutation))
          query = -> { Widget.find_by_sql("SELECT * FROM widgets ORDER BY id").map(&:name) }
          Lowrail::TestCertificate.test_initialized!
          rows = query.call
          query.call
          before = Lowrail::Stats.snapshot
          case ENV.fetch("MUTATION")
          when "config"
            old = Rails.application.config.eager_load
            Rails.application.config.eager_load = !old
            restore = -> { Rails.application.config.eager_load = old }
          when "builder"
            # Direct VM writes bypass instance_variable_set and AR reset hooks.
            old = Widget.instance_variable_get(:@attributes_builder)
            Widget.singleton_class.class_eval("def replace_cache(value); @attributes_builder = value; end")
            Widget.replace_cache(ActiveModel::AttributeSet::Builder.new(Widget.attribute_types))
            restore = -> { Widget.replace_cache(old) }
          when "bootsnap"
            old = Bootsnap::CompileCache::ISeq.instance_variable_get(:@default_compiler)
            Bootsnap::CompileCache::ISeq.default_compiler = old
            restore = -> { Bootsnap::CompileCache::ISeq.default_compiler = old }
          when "method"
            holder = ActiveRecord::ModelSchema::ClassMethods
            old = holder.instance_method(:attributes_builder)
            holder.define_method(:attributes_builder) { old.bind_call(self) }
            restore = -> { holder.define_method(:attributes_builder, old) }
          when "schema"
            Widget.reset_column_information
            restore = -> { Widget.first } # Natural rebuilding cannot revive.
          when "suite_mode"
            old = ENV["LOWRAIL_VERIFY_TEST_DIRECT"]
            ENV["LOWRAIL_VERIFY_TEST_DIRECT"] = "1"
            restore = -> { ENV["LOWRAIL_VERIFY_TEST_DIRECT"] = old }
          end
          after = query.call
          restore.call
          Lowrail::TestCertificate.test_initialized!
          restored = query.call
          puts JSON.generate(rows: rows, after: after, restored: restored, before: before,
            stats: Lowrail::Stats.snapshot)
        RUBY
        assert_equal ["left", "right"], result.fetch("rows"), mutation
        assert_equal result.fetch("rows"), result.fetch("after"), mutation
        assert_equal result.fetch("rows"), result.fetch("restored"), mutation
        assert_equal 2, result.dig("before", "unit_hits", "0"), mutation
        assert_equal 2, result.dig("stats", "unit_hits", "0"), mutation
        assert_operator result.dig("stats", "unit_fallbacks", "0"), :>=, 2, mutation
        assert_equal 1, result.dig("stats", "unit_deopts", "0"), mutation
        expected = {"config" => "verification_policy_mutation:eager_load=",
          "builder" => "verification_attributes_builder_replaced", "bootsnap" => "verification_bootsnap_policy_mutation",
          "method" => "dependent_method_or_ancestor_drift", "schema" => "dependent_state_mutation:reset_column_information",
          "suite_mode" => "verification_policy_or_source_drift"}
        assert_equal [expected.fetch(mutation)], result.dig("stats", "unit_refusals", "0"), mutation
      end
    end
  end

  def test_actual_parallel_policy_mismatch_refuses_despite_workers1
    with_runtime_certificate do |dir, boot|
      result = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir))
        old = Minitest.parallel_executor
        # No workers are started. The actual policy alone must refuse.
        Minitest.parallel_executor = ActiveSupport::Testing::ParallelizeExecutor.new(size: 2, with: :processes)
        Lowrail::TestCertificate.test_initialized!
        Minitest.parallel_executor = old
        Lowrail::TestCertificate.test_initialized!
        rows = Widget.order(:id).map(&:name)
        puts JSON.generate(rows: rows, stats: Lowrail::Stats.snapshot)
      RUBY
      assert_equal ["left", "right"], result.fetch("rows")
      assert_empty result.dig("stats", "unit_hits")
      assert_equal "refused", result.dig("stats", "verification_test", "state")
      assert_equal ["verification_parallel_policy_unknown"], result.dig("stats", "unit_refusals", "0")
    end
  end

  private

  def certificate_env(dir)
    {"LOWRAIL" => "1", "RAILS_ENV" => "test", "PARALLEL_WORKERS" => "1", "CI" => nil,
      "LOWRAIL_SEALED" => "1", "LOWRAIL_VERIFY_TEST" => "1", "LOWRAIL_SQL_TRACE" => "0",
      "LOWRAIL_DIR" => "#{dir}/.lowrail", "LOWRAIL_ROOT" => dir}
  end

  def with_runtime_certificate
    missing_prerequisite "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      environment = LowrailTest::RAILS_APP.fetch("config/environment.rb").sub("config.eager_load = false",
        "config.eager_load = false\n    config.cache_store = :null_store\n    config.yjit = false")
        .sub("create_table(:widgets)", "create_table(:widgets, force: true)")
      LowrailTest.write_rails_app(dir, "config/environment.rb" => environment,
        "config/database.yml" => "test:\n  adapter: sqlite3\n  database: tmp/verification.sqlite3\n  pool: 1\n",
        "config/boot.rb" => <<~'RUBY', "test/test_helper.rb" => <<~'RUBY')
          require "bootsnap"
          Bootsnap.setup(cache_dir: File.join(Dir.pwd, "tmp/cache"), development_mode: false,
            load_path_cache: true, compile_cache_iseq: true, compile_cache_yaml: true, compile_cache_json: true)
        RUBY
          require_relative "../config/environment"
          require "active_support/test_case"
          ActiveSupport::TestCase.parallelize(workers: 1)
          Minitest.parallel_executor.start
          ActiveRecord::Base.connection.execute("INSERT INTO widgets (id, name, status) VALUES (1, 'left', 0), (2, 'right', 1)")
        RUBY
      boot = "require 'json'; require './config/boot'; require './test/test_helper'\n"
      built = ruby_json(boot + <<~'RUBY', chdir: dir, env: certificate_env(dir).merge("LOWRAIL" => "0"))
        require "lowrail/manifest"
        Widget.first # Only natural app loading can supply build discovery.
        certificate = Lowrail::TestCertificate.certificate(Dir.pwd)
        require "lowrail/ar_instantiate_build"
        units = Lowrail::ARInstantiateBuild.build(verification_test: true).fetch(:units)
        units.each_with_index { |unit, id| unit["id"] = id }
        data = {format: Lowrail::FORMAT, ruby_description: RUBY_DESCRIPTION, certification_jit: Lowrail.jit_mode,
          compile_option: Lowrail::Manifest.compile_option_fingerprint, files: {}, units: units,
          tier: "sealed-test-v1", rails_env: "test", verification_test: certificate}
        FileUtils.mkdir_p(".lowrail")
        File.write(".lowrail/manifest.json", JSON.generate(data))
        puts JSON.generate(units.map { _1.dig("ar_instantiate", "model") })
      RUBY
      assert_equal ["Widget"], built
      yield dir, boot
    end
  end
end
