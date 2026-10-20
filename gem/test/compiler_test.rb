# frozen_string_literal: true

require_relative "test_helper"
require "lowrail/compiler"
require "stringio"

class CompilerTest < Minitest::Test
  include LowrailTest

  # compile(src, path, path, 1) must give the same instructions as the
  # compiler `require`/Bootsnap use (compile_file_prism), magic comments
  # included. Only the top-level label differs ("<compiled>" vs "<main>").
  def test_compile_matches_compile_file
    realpath_tmpdir do |dir|
      samples = {
        "fsl_true.rb" => "# frozen_string_literal: true\ndef a = 'x'\nB = \"b\#{1}\"\n",
        "fsl_false.rb" => "# frozen_string_literal: false\ndef a = 'x'\n",
        "no_magic.rb" => "def a = 'chilled'\nC = __FILE__\nD = __dir__\n",
        "encoding.rb" => "# encoding: ascii-8bit\nE = \"\\xff café\"\n",
        "shareable.rb" => "# shareable_constant_value: literal\nF = [1, {a: 'x'}]\n",
        "blocks.rb" => "[1].each { |x| x + 1 }\nclass G; def h = yield; end\n"
      }
      files = samples.map { |name, src| File.join(dir, name).tap { File.binwrite(_1, src) } }
      %w[activesupport/lib/active_support/inflector/methods.rb activerecord/lib/active_record/persistence.rb
         actionpack/lib/action_dispatch/routing/route_set.rb].each do |rel|
        gem_name, *rest = rel.split("/")
        spec = Gem::Specification.find_all_by_name(gem_name).max_by(&:version) or next
        path = File.join(spec.gem_dir, *rest)
        files << path if File.file?(path)
      end
      files.each do |f|
        expected = RubyVM::InstructionSequence.compile_file_prism(f).to_a
        actual = RubyVM::InstructionSequence.compile(File.read(f, encoding: Encoding::UTF_8), f, f, 1).to_a
        assert_equal normalize(expected), normalize(actual), "ISeq differs for #{f}"
        binary = RubyVM::InstructionSequence.compile(File.read(f, encoding: Encoding::UTF_8), f, f, 1).to_binary
        assert_equal actual, RubyVM::InstructionSequence.load_from_binary(binary).to_a, "binary round trip for #{f}"
      end
    end
  end

  def test_build_skips_failures_and_writes_manifest_atomically
    realpath_tmpdir do |dir|
      good = File.join(dir, "good.rb")
      bad = File.join(dir, "bad.rb")
      changed = File.join(dir, "changed.rb")
      [good, bad, changed].each { File.write(_1, "X = 1\n") }
      File.write(File.join(dir, "good.lowered.rb"), "X = 2\n")
      File.write(File.join(dir, "bad.lowered.rb"), "def (\n")
      File.write(File.join(dir, "changed.lowered.rb"), "X = 3\n")
      out = File.join(dir, ".lowrail")
      input = {
        "out" => out,
        "files" => [{ "path" => good, "lowered" => File.join(dir, "good.lowered.rb") },
                    { "path" => bad, "lowered" => File.join(dir, "bad.lowered.rb") },
                    { "path" => changed, "lowered" => File.join(dir, "changed.lowered.rb"), "source_sha256" => "0" * 64 },
                    { "path" => File.join(dir, "missing.rb"), "lowered" => File.join(dir, "missing.lowered.rb") }],
        "units" => [{ "id" => 0, "file" => good, "method" => "a", "facts" => [] },
                    { "id" => 1, "file" => bad, "method" => "b", "facts" => [] },
                    { "id" => 2, "file" => changed, "method" => "c", "facts" => [] },
                    { "id" => 3, "kind" => "runtime", "file" => "Widget", "pass" => "active_record/instantiate", "facts" => [] },
                    { "id" => 4, "kind" => "method", "target" => "InertiaRails::Configuration#bind_controller", "facts" => [] }]
      }
      err = StringIO.new
      manifest = Lowrail::Compiler.compile(input, err: err)
      assert_equal [good], manifest["files"].keys
      assert_equal [0, 3, 4], manifest["units"].map { _1["id"] }
      assert_match(/skipping #{Regexp.escape(bad)}: SyntaxError/, err.string)
      assert_match(/skipping #{Regexp.escape(changed)}: .*source changed/, err.string)
      assert_match(/dropping unit 1/, err.string)

      on_disk = JSON.parse(File.read(File.join(out, "manifest.json")))
      assert_equal manifest, on_disk
      assert_equal Lowrail::Manifest.compile_option_fingerprint, on_disk["compile_option"]
      assert_equal RUBY_DESCRIPTION, on_disk["ruby_description"]
      entry = on_disk["files"][good]
      assert_equal Digest::SHA256.file(good).hexdigest, entry["source_sha256"]
      assert File.file?(File.join(out, entry["iseq"]))
      assert_empty Dir.glob(File.join(out, "**/*.tmp.*")), "temporary files left behind"

      # The runtime parser reads what the compiler wrote.
      parsed = Lowrail::Manifest.load(File.join(out, "manifest.json"), out)
      assert parsed.compatible?
      assert_equal File.join(out, entry["iseq"]), parsed.iseq_for(good, original: RubyVM::InstructionSequence.compile_file(good),
                                                              compile_option: Lowrail::Manifest.compile_option_fingerprint)
    end
  end

  def test_exe_usage_and_exit_codes
    _, err, status = ruby(COMPILE, setup: false)
    assert_equal 2, status.exitstatus
    assert_match(/usage/, err)
  end

  def test_shape_warnings_preserve_delivery_and_existing_ledger
    realpath_tmpdir do |dir|
      path = File.join(dir, "shapes.rb")
      File.write(path, <<~RUBY)
        class ShapeFixture
          def small; #{(["value"] * 7).join(";")}; end
          def large; #{(["value"] * 8).join(";")}; end
          def guarded; ::Lowrail::G[0] = true; ::Lowrail::K[0] = self.class; ::Lowrail::V[0] = {}; end
          def noisy(*args, **kw, &block)
            singleton_class
            send(:value, *args, **kw, &block)
            binding
            TracePoint.new(:call) {}
            Object.const_set(:TestMarker, 1)
          end
          define_method(:value) { 1 }
        end
      RUBY
      out = File.join(dir, ".lowrail")
      FileUtils.mkdir_p(out)
      existing = { "pass" => "test", "outcome" => "refused", "detail" => "keep me" }
      Lowrail.write_json(File.join(out, "ledger.json"), [existing])
      input = { "out" => out, "files" => [{ "path" => path, "lowered" => path }],
        "units" => [{ "id" => 3, "file" => path, "method" => "ShapeFixture#noisy" }] }
      manifest = Lowrail::Compiler.compile(input, err: StringIO.new)
      ledger = JSON.parse(File.read(File.join(out, "ledger.json")))
      assert_equal existing, ledger.first
      warnings = ledger.drop(1)
      assert warnings.all? { _1["outcome"] == "warning" && _1["pass"] == "jit/shape" && _1["target"] == path }
      %w[inline_size dynamic_send block_method singleton_class call_shape tracing_binding constant_write].each do |reason|
        assert_includes warnings.map { _1["reason"] }, reason
      end
      assert_includes warnings.select { _1["reason"] == "inline_size" }.map { _1["site"] }, "large"
      refute_includes warnings.select { _1["reason"] == "inline_size" }.map { _1["site"] }, "small"
      refute warnings.any? { _1["site"] == "guarded" && _1["reason"] == "constant_write" }, "container writes are not constant reassignment"
      assert_equal [3], manifest["units"].map { _1["id"] }
      assert File.file?(File.join(out, manifest["files"][path]["iseq"]))
      Lowrail::Compiler.compile(input, err: StringIO.new)
      assert_equal ledger, JSON.parse(File.read(File.join(out, "ledger.json"))), "rebuild replaces shape diagnostics"
    end
  end

  private

  LABEL = /\A(?:block (?:\(\d+ levels\) )?in )?<(?:main|compiled)>\z/

  def normalize(obj)
    case obj
    when Array then obj.map { normalize(_1) }
    when Hash then obj.transform_values { normalize(_1) }
    when String then obj.match?(LABEL) ? obj.sub(/<(main|compiled)>/, "<top>") : obj
    else obj
    end
  end
end
