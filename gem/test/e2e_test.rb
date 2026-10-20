# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

# Build (lowrail-compile) -> boot (RUBYOPT=-rlowrail/setup) -> guarded calls.
class E2ETest < Minitest::Test
  include LowrailTest

  SCRIPT = <<~RUBY
    #{LowrailTest::MOCK_PRELUDE}
    require "json"
    require File.join(Dir.pwd, "app")
    c = Calc.new
    r = {}
    r["compute"] = c.compute(1)
    r["label"] = c.label
    r["loaded"] = defined?(Lowrail::Guard) && Lowrail::Guard.installed? ? true : false
    if $mock && ENV["STUB"]
      Dep.stub(:value, 10) { r["compute_stubbed"] = c.compute(1) }
      r["compute_after_stub"] = c.compute(1)
      other = Calc.new
      c.stub(:name, "stub") { r["label_stubbed"] = c.label; r["label_other_during_stub"] = other.label }
      r["label_after_stub"] = c.label
      Dep.stub(:value, 3) { c.stub(:name, "n") { r["nested"] = [c.compute(1), c.label] } }
      Dep.stub(:value, 4) { r["second"] = c.compute(1) }
      r["after_nested"] = c.compute(1)
    end
    r["mock"] = $mock
    r["hits"] = Lowrail::Stats.unit_hits if defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
    puts JSON.generate(r)
  RUBY

  def test_fast_path_stub_and_restore
    realpath_tmpdir do |dir|
      build_app(dir)
      r = ruby_json(SCRIPT, chdir: dir, env: { "STUB" => "1", "LOWRAIL_STATS" => File.join(dir, "stats") })
      assert r["loaded"]
      assert_equal ["fast", 2], r["compute"]
      assert_equal ["fast", "CALC"], r["label"]
      skip "minitest/mock not available (minitest 6 without minitest-mock)" unless r["mock"]
      assert_equal ["orig", 11], r["compute_stubbed"], "a stubbed dependency must run the original body"
      assert_equal ["fast", 2], r["compute_after_stub"], "fast path must return after the stub"
      assert_equal ["orig", "STUB"], r["label_stubbed"], "an instance stub must disable the unit"
      assert_equal ["orig", "CALC"], r["label_other_during_stub"], "conservative: any live override disables the unit"
      assert_equal ["fast", "CALC"], r["label_after_stub"]
      assert_equal [["orig", 4], ["orig", "N"]], r["nested"]
      assert_equal ["orig", 5], r["second"], "a second stub of the same method disables again"
      assert_equal ["fast", 2], r["after_nested"]
      assert_operator r["hits"]["0"], :>=, 3
      stats = Dir[File.join(dir, "stats.*")].map { JSON.parse(File.read(_1)) }
      assert_equal 1, stats.size
      assert_equal [File.join(dir, "app.rb")], stats[0]["loaded_files"]
      assert_equal r["hits"], stats[0]["unit_hits"]
    end
  end

  def test_edited_source_falls_back_to_original
    realpath_tmpdir do |dir|
      build_app(dir)
      File.write(File.join(dir, "app.rb"), APP_SRC + "# edited\n")
      r = ruby_json(SCRIPT, chdir: dir)
      assert_equal ["orig", 2], r["compute"]
      assert_equal ["orig", "CALC"], r["label"]
    end
  end

  def test_target_root_artifact_delivers_after_copy_and_refuses_changed_content
    realpath_tmpdir do |parent|
      a = File.join(parent, "build")
      b = File.join(parent, "release") # deliberately nonexistent during build
      Dir.mkdir(a)
      extra = <<~'RUBY'
        class Calc
          def paths = [__FILE__, __dir__, caller_locations(0, 1).first.path]
        end
      RUBY
      build_app(a, compile: false, lowered: LOWERED_SRC + extra)
      File.write(File.join(a, "app.rb"), APP_SRC + extra)
      input_path = File.join(a, "units.json")
      _, err, status = ruby(COMPILE, input_path, setup: false)
      assert status.success?, err
      probe = SCRIPT + <<~'RUBY'
        puts JSON.generate(r.merge(paths: c.paths, reason: Lowrail.refusal_reason,
          location: Calc.instance_method(:compute).source_location, compiles: $compiler_calls || 0))
      RUBY
      baseline = ruby_json(probe, chdir: a, env: {"LOWRAIL_STATS" => ""})
      assert_equal({"0" => 1, "1" => 1}, baseline.fetch("hits"))
      input = JSON.parse(File.read(input_path)).merge("target_root" => b)
      File.write(input_path, JSON.generate(input))
      _, err, status = ruby(COMPILE, input_path, setup: false)
      assert status.success?, err
      assert_match(/compiled 1 file/, err)
      FileUtils.cp_r(a, b)
      FileUtils.rm_rf(a) # no accidental reads from the build tree
      compiler_observer = <<~'RUBY'
        $compiler_calls = 0
        RubyVM::InstructionSequence.singleton_class.prepend(Module.new do
          def compile(...)
            $compiler_calls += 1
            super
          end
        end)
      RUBY
      relocated = ruby_json(compiler_observer + probe, chdir: b, env: {"LOWRAIL_STATS" => ""})
      assert_equal baseline.fetch("hits"), relocated.fetch("hits")
      assert_equal baseline.fetch("compute"), relocated.fetch("compute")
      assert_equal baseline.fetch("label"), relocated.fetch("label")
      assert_equal [File.join(b, "app.rb"), b, File.join(b, "app.rb")], relocated.fetch("paths")
      assert_equal [File.join(b, "app.rb"), 6], relocated.fetch("location")
      assert_equal 0, relocated.fetch("compiles"), "delivery must not reenter the public text compiler"
      assert_nil relocated.fetch("reason")

      %w[original lowered].each do |which|
        path = File.join(b, which == "original" ? "app.rb" : ".lowrail/src/app.rb")
        source = File.binread(path)
        File.binwrite(path, source + "# changed\n")
        out, err, status = ruby("-e", probe, chdir: b, env: {"LOWRAIL_STATS" => "", "LOWRAIL_DEBUG" => "1"})
        assert status.success?, err
        refused = JSON.parse(out.lines.last)
        assert_equal ["orig", 2], refused.fetch("compute")
        assert_empty refused.fetch("hits")
        assert_includes refused.fetch("reason"), "#{which == 'original' ? 'source' : 'lowered source'} digest mismatch"
        assert_includes err, refused.fetch("reason")
        File.binwrite(path, source)
      end
    end
  end

  def test_copy_of_path_bound_binaries_records_boot_refusal
    realpath_tmpdir do |parent|
      a = File.join(parent, "build")
      b = File.join(parent, "release")
      Dir.mkdir(a)
      build_app(a)
      FileUtils.cp_r(a, b)
      probe = SCRIPT + "\nputs JSON.generate(r.merge(reason: Lowrail.refusal_reason))"
      out, err, status = ruby("-e", probe,
        chdir: b, env: {"LOWRAIL_STATS" => "", "LOWRAIL_DEBUG" => "1"})
      assert status.success?, err
      result = JSON.parse(out.lines.last)
      assert_equal ["orig", 2], result.fetch("compute")
      assert_empty result.fetch("hits")
      assert_includes result.fetch("reason"), "--target-root #{b}"
      assert_includes err, result.fetch("reason")
    end
  end

  def test_ruby_description_mismatch_is_noop
    realpath_tmpdir do |dir|
      build_app(dir)
      edit_manifest(dir) { _1["ruby_description"] = "ruby 3.3.0 (2023-12-25 revision 5124f9ac75) [x86_64-linux]" }
      r = ruby_json(SCRIPT, chdir: dir)
      refute r["loaded"]
      assert_equal ["orig", 2], r["compute"]
    end
  end

  def test_old_mixed_source_artifacts_refuse_before_source_or_template_delivery
    %w[view/link_to route/path].each do |pass|
      realpath_tmpdir do |dir|
        units = default_units(dir)
        units[0]["pass"] = pass
        build_app(dir, units: units)
        edit_manifest(dir) do |manifest|
          manifest["templates"] = {"/old/template.erb" => {"source_sha256" => "old", "code" => "raise 'old template delivered'"}}
        end
        code = SCRIPT + <<~'RUBY'
          require "lowrail/guard"
          require "lowrail/passes"
          manifest = Lowrail::Manifest.load(File.join(Dir.pwd, ".lowrail/manifest.json"))
          Lowrail::Passes.install(manifest)
          Lowrail::G.replace([true, true])
          Lowrail::Stats::STATE.replace([true, true])
          Lowrail::V.replace([{Calc => true}, {Calc => true}])
          Lowrail::K.replace([Calc, Calc])
          Lowrail::Guard.install(manifest, Lowrail::Stats::STATE)
          puts JSON.generate(r.merge(reason: Lowrail.refusal_reason,
            templates_installed: !!defined?(Lowrail::Templates), loaded_files: Lowrail::Stats.loaded_files,
            guard_decisions: [Lowrail::Guard.validate(0), Lowrail::Guard.validate(1)],
            stale_authorization: Lowrail::G.any?(true) || Lowrail::Stats::STATE.any?(true) || Lowrail::V.any? { _1&.value?(true) } || Lowrail::K.any? { _1.equal?(Calc) },
            delivered: manifest.iseq_for(File.join(Dir.pwd, "app.rb"))))
        RUBY
        out, err, status = ruby("-e", code, chdir: dir, env: {"LOWRAIL_STATS" => ""})
        assert status.success?, err
        result = JSON.parse(out.lines.last)
        refute result.fetch("loaded")
        refute result.fetch("templates_installed")
        assert_equal ["orig", 2], result.fetch("compute")
        assert_equal ["orig", "CALC"], result.fetch("label"), "safe units in a mixed artifact must not be delivered either"
        assert_empty result.fetch("hits")
        assert_empty result.fetch("loaded_files")
        assert_equal [false, false], result.fetch("guard_decisions")
        refute result.fetch("stale_authorization")
        assert_nil result.fetch("delivered")
        assert_includes result.fetch("reason"), pass
        assert_includes err, result.fetch("reason"), "quarantine must have an observable boot refusal, not a silent stale fast path"
      end
    end
  end

  def test_compile_option_mismatch_is_noop
    realpath_tmpdir do |dir|
      build_app(dir)
      code = "RubyVM::InstructionSequence.compile_option = {frozen_string_literal: true}\n#{SCRIPT}"
      assert_equal ["orig", 2], ruby_json(code, chdir: dir)["compute"]
      # A later change must not reuse an earlier successful fingerprint.
      code = "#{SCRIPT}\nRubyVM::InstructionSequence.compile_option = {frozen_string_literal: true}; load './app.rb'; puts JSON.generate(Calc.new.compute(1))"
      assert_equal ["orig", 2], ruby_json(code, chdir: dir)
      edit_manifest(dir) { _1["files"].each_value { |entry| entry.delete("original_iseq_sha256") } }
      assert_equal ["orig", 2], ruby_json(SCRIPT, chdir: dir)["compute"], "old builds need a rebuild, not guessed options"
    end
  end

  def test_options_are_checked_even_when_the_original_has_no_string_literals
    realpath_tmpdir do |dir|
      build_app(dir, compile: false, lowered: "VALUE = 'lowered'.frozen?\n")
      File.write(File.join(dir, "app.rb"), "VALUE = 1\n")
      _, err, status = ruby(COMPILE, File.join(dir, "units.json"), setup: false)
      assert status.success?, err
      code = 'require "json"; require File.join(Dir.pwd, "app"); puts JSON.generate(VALUE)'
      assert_equal false, ruby_json(code, chdir: dir)
      # The original ISeq bytes are identical under both policies, but the
      # lowered source contains a string. Its recipe must still be guarded.
      assert_equal 1, ruby_json("RubyVM::InstructionSequence.compile_option = {frozen_string_literal: true}; #{code}", chdir: dir)
    end
  end

  def test_lowrail_0_is_noop
    realpath_tmpdir do |dir|
      build_app(dir)
      r = ruby_json(SCRIPT, chdir: dir, env: { "LOWRAIL" => "0" })
      refute r["loaded"]
      assert_equal ["orig", 2], r["compute"]
    end
  end

  def test_no_enabled_units_serves_originals_but_keeps_reporting
    realpath_tmpdir do |dir|
      build_app(dir)
      env = { "LOWRAIL_UNITS" => "", "LOWRAIL_STATS" => File.join(dir, "stats") }
      result = ruby_json(SCRIPT, chdir: dir, env: env)
      refute result["loaded"], "a disabled build must not install delivery/invalidation hooks"
      assert_equal ["orig", 2], result["compute"]
      assert_equal ["orig", "CALC"], result["label"]
      assert_empty result["hits"]
      report = JSON.parse(File.read(Dir[File.join(dir, "stats.*")].fetch(0)))
      assert_empty report["loaded_files"]
      assert_empty report["unit_fallbacks"], "original source has no lowered calls to count"
      # A nonempty subset must still deliver the file, with guards enforcing
      # the selection at each site rather than disabling every unit.
      result = ruby_json(SCRIPT, chdir: dir, env: env.merge("LOWRAIL_UNITS" => "0"))
      assert result["loaded"]
      assert_equal ["fast", 2], result["compute"]
      assert_equal ["orig", "CALC"], result["label"]
      assert_equal({ "0" => 1 }, result["hits"])
      edit_manifest(dir) { |data| data.merge!("units" => [], "files" => {}, "templates" => {}) }
      result = ruby_json(SCRIPT, chdir: dir, env: { "LOWRAIL_STATS" => File.join(dir, "stats-empty") })
      refute result["loaded"], "an empty build needs no delivery/invalidation hooks either"
      assert_equal ["orig", 2], result["compute"]
      assert_empty result["hits"]
    end
  end

  def test_development_is_off_unless_forced
    realpath_tmpdir do |dir|
      build_app(dir)
      assert_equal ["orig", 2], ruby_json(SCRIPT, chdir: dir, env: { "RAILS_ENV" => "development" })["compute"]
      assert_equal ["fast", 2], ruby_json(SCRIPT, chdir: dir, env: { "RAILS_ENV" => "development", "LOWRAIL" => "1" })["compute"]
    end
  end

  def test_broken_builds_never_break_the_app
    realpath_tmpdir do |dir|
      build_app(dir)
      bin = Dir[File.join(dir, ".lowrail/iseq/*.bin")].first
      File.binwrite(bin, "garbage")
      assert_equal ["orig", 2], ruby_json(SCRIPT, chdir: dir)["compute"], "corrupt binary"

      File.write(File.join(dir, ".lowrail/manifest.json"), "{not json")
      assert_equal ["orig", 2], ruby_json(SCRIPT, chdir: dir)["compute"], "corrupt manifest"

      File.write(File.join(dir, ".lowrail/manifest.json"), JSON.generate({ "format" => 99 }))
      assert_equal ["orig", 2], ruby_json(SCRIPT, chdir: dir)["compute"], "foreign format"

      FileUtils.rm_rf(File.join(dir, ".lowrail"))
      assert_equal ["orig", 2], ruby_json(SCRIPT, chdir: dir)["compute"], "no build"
    end
  end

  def test_redefined_dependency_falls_back
    realpath_tmpdir do |dir|
      build_app(dir)
      code = <<~RUBY
        require "json"
        require File.join(Dir.pwd, "app")
        c = Calc.new
        r = [c.compute(1)]
        Dep.singleton_class.prepend(Module.new { def value = 5 })
        r << c.compute(1)
        class Sub < Calc; def name = "sub"; end
        r << Calc.new.label
        puts JSON.generate(r)
      RUBY
      assert_equal [["fast", 2], ["orig", 6], ["orig", "CALC"]], ruby_json(code, chdir: dir)
    end
  end

  REAL_BLOG = File.join(CORPUS_ROOT, "real-blog")

  # The hooks (with a compatible, empty manifest) must not change any
  # outcome of a real Rails suite, and the reporter must load via RUBYOPT
  # alone. LOWRAIL_REAL_BLOG=0 skips it.
  def test_real_blog_outcomes_identical_with_hooks
    skip "real-blog corpus not fetched (script/corpus)" unless File.directory?(REAL_BLOG)
    skip "LOWRAIL_REAL_BLOG=0" if ENV["LOWRAIL_REAL_BLOG"] == "0"
    realpath_tmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, ".lowrail"))
      require "lowrail/compiler"
      Lowrail::Compiler.compile({ "out" => File.join(dir, ".lowrail"), "files" => [], "units" => [] }, err: StringIO.new)
      runs = %w[0 1].to_h do |mode|
        out_path = File.join(dir, "outcomes-#{mode}.json")
        out, err, status = ruby("bin/rails", "test", chdir: REAL_BLOG,
                                env: { "LOWRAIL" => mode, "LOWRAIL_ROOT" => dir, "LOWRAIL_OUTCOMES" => out_path })
        skip "real-blog bundle not installed for #{RUBY_VERSION}" if err.include?("Could not find") || err.include?("Bundler::")
        assert status.success?, "real-blog LOWRAIL=#{mode} failed:\n#{out}\n#{err}"
        assert_match(/21 runs, \d+ assertions, 0 failures, 0 errors, 0 skips/, out)
        [mode, JSON.parse(File.read(out_path))]
      end
      assert_equal 21, runs["1"]["tests"].size
      assert_equal ["pass"], runs["1"]["tests"].values.map { _1["result"] }.uniq
      assert_equal runs["0"]["tests"], runs["1"]["tests"]
    end
  end

  private

  def edit_manifest(dir)
    path = File.join(dir, ".lowrail/manifest.json")
    data = JSON.parse(File.read(path))
    yield data
    File.write(path, JSON.generate(data))
  end
end
