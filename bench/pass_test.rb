# frozen_string_literal: true

require "minitest/autorun"
require_relative "pass"

class PassBenchTest < Minitest::Test
  def manifest
    { "format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
      "rails_env" => "production", "compile_option" => {}, "units" => [], "files" => {}, "templates" => {} }
  end

  def run_rejection(data, **options)
    Dir.mktmpdir("lowrail-pass-test") do |app|
      FileUtils.mkdir_p(File.join(app, ".lowrail"))
      File.write(File.join(app, ".lowrail/manifest.json"), JSON.generate(data))
      out = File.join(app, "result")
      capture_io { refute PassBench.run(app, pass: "default", out: out, **options) }
      result = JSON.parse(File.read(File.join(out, "result.json")))
      assert_equal "rejected", result.fetch("status")
      refute result.fetch("measurement_complete")
      assert_includes File.read(File.join(out, "table.md")), "rejected"
      yield result
    end
  end

  def test_stale_manifest_is_a_rejected_measurement_not_a_silent_noop
    run_rejection(manifest.merge("ruby_description" => "obsolete Ruby")) do |result|
      assert_includes result.fetch("error"), "incompatible Ruby/format"
    end
    run_rejection(manifest.merge("units" => [{ "id" => 0, "pass" => "route/path", "facts" => [] }],
      "templates" => { "/missing/template.erb" => { "source_sha256" => "stale" } })) do |result|
      assert_includes result.fetch("error"), "stale build"
    end
  end

  def test_zero_units_cannot_masquerade_as_active_pass_measurement
    run_rejection(manifest) { assert_includes _1.fetch("error"), "no units" }
  end

  def test_one_boot_cannot_masquerade_as_independent_native_cohorts
    saved = ENV["BENCH_COHORTS"]
    ENV["BENCH_COHORTS"] = "1"
    run_rejection(manifest, counter: "native") { assert_includes _1.fetch("error"), "five independent cohorts" }
  ensure
    ENV["BENCH_COHORTS"] = saved
  end

  def test_archived_runtime_cannot_compare_different_pass_selections
    saved = ENV["BENCH_BASELINE_LIB"]
    ENV["BENCH_BASELINE_LIB"] = "/unused/archived/lib"
    run_rejection(manifest, pass: "route/path") { assert_includes _1.fetch("error"), "requires --pass default" }
  ensure
    ENV["BENCH_BASELINE_LIB"] = saved
  end

  def test_non_ar_certificates_are_checked_against_the_loaded_library_too
    Dir.mktmpdir("lowrail-pass-certificate") do |dir|
      lib = File.join(dir, "lib")
      FileUtils.mkdir_p(File.join(lib, "lowrail"))
      original = File.expand_path("../gem/lib/lowrail/memo.rb", __dir__)
      target = File.join(lib, "lowrail/memo.rb")
      FileUtils.cp(original, target)
      data = manifest.merge("units" => [{ "id" => 0, "pass" => "memo/sha256", "facts" => [],
        "memo" => { "sources" => { original => { "sha256" => Digest::SHA256.file(original).hexdigest,
          "size" => File.size(original), "mtime" => File.mtime(original).to_r.to_s } } } }])
      File.write(File.join(dir, "manifest.json"), JSON.generate(data))
      assert_equal data, PassBench.preflight(dir, lib)
      File.write(target, "changed")
      error = assert_raises(RuntimeError) { PassBench.preflight(dir, lib) }
      assert_includes error.message, "stale build"
    end
  end

  def test_jit_state_is_observed_after_application_boot_not_inferred_from_flags
    Dir.mktmpdir("lowrail-pass-jit") do |app|
      FileUtils.mkdir_p(File.join(app, "config"))
      # A production app can explicitly enable YJIT during initialization.
      File.write(File.join(app, "config/application.rb"), <<~RUBY)
        raise "JSON activated before the app can lock its gems" if defined?(JSON)
        module Rails
          Config = Struct.new(:yjit)
          class Application
            def config = (@config ||= Config.new)
            def eager_load!; end
          end
          def self.application = (@app ||= Application.new)
          def self.logger = (@logger ||= Struct.new(:level).new)
        end
        module ActiveRecord
          class Base
            def self.logger=(value); end
          end
        end
      RUBY
      File.write(File.join(app, "config/environment.rb"), "require_relative 'application'; RubyVM::YJIT.enable\n")
      env = { "RUBYOPT" => nil, "BENCH_JIT" => "0", "BENCH_UNITS" => "0" }
      error = assert_raises(RuntimeError) { PassBench.probe(app, app, env, "GET:/", "jit") }
      assert_includes error.message, "activation/JIT probe failed"
      assert_includes File.read(File.join(app, "jit.log")), "unexpected JIT mode"
    end
  end
end
