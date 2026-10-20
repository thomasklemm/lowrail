# frozen_string_literal: true

require_relative "test_helper"

class DigestMemoTest < Minitest::Test
  include LowrailTest

  def test_public_lazy_version_fixture_is_opt_in_and_differentially_identical
    root = File.expand_path("..", GEM_ROOT)
    binary = File.join(root, "target/release/lowrail")
    skip "build the Rust CLI to run the digest fixture" unless File.executable?(binary)
    %w[rails rails_vite inertia_rails vite_ruby].each do |name|
      skip "#{name} is not installed" if Gem::Specification.find_all_by_name(name).empty?
    end
    Dir.mktmpdir("lowrail-digest-fixture") do |dir|
      fixture = File.join(root, "fixtures/digest-app")
      Dir.children(fixture).reject { %w[.lowrail log tmp Gemfile.lock].include?(_1) }.each do |name|
        FileUtils.cp_r(File.join(fixture, name), dir)
      end
      out, err, status = Open3.capture3(CLEAN_ENV, "bundle", "lock", "--local", chdir: dir)
      assert status.success?, "#{err}\n#{out}"
      out, err, status = Open3.capture3(CLEAN_ENV, binary, "build", dir)
      assert status.success?, "#{err}\n#{out}"
      manifest = JSON.parse(File.read(File.join(dir, ".lowrail/manifest.json")))
      refute manifest["units"].any? { _1["pass"] == "digest/file_memo" }
      out, err, status = Open3.capture3(CLEAN_ENV, binary, "build", dir, "--digest-memo")
      assert status.success?, "#{err}\n#{out}"
      out, err, status = Open3.capture3(CLEAN_ENV, binary, "verify", dir, "--bisect", "--", RUBY, "bin/rails", "test", "--seed", "1729")
      assert status.success?, "#{err}\n#{out}"
      assert_match(/LOWRAIL=0: 7 tests, 7 pass, 0 fail, 0 error, 0 skip/, out)
      assert_match(/LOWRAIL=1: 7 tests, 7 pass, 0 fail, 0 error, 0 skip/, out)
      assert_match(/outcomes: identical per test/, out)
      report = JSON.parse(File.read(File.join(dir, ".lowrail/verify/outcomes-1.json")))
      assert_equal 2, report.fetch("unit_hits").size
      assert report.fetch("unit_hits").values.all?(&:positive?)
      assert_empty report.fetch("unit_fallbacks")

      result = ruby_json(<<~'RUBY', chdir: dir, env: {"RAILS_ENV" => "test", "LOWRAIL" => "1", "LOWRAIL_STATS" => File.join(dir, "guard-stats")})
        require_relative "config/environment"
        manifest = RailsVite::Manifest.new(RailsVite.config.manifest_path)
        expected = manifest.digest
        2.times { raise "unstable digest" unless manifest.digest == expected }
        Digest::MD5.class_eval do
          define_method(:initialize_copy) { |_| raise "custom clone" }
          private :initialize_copy
        end
        begin
          manifest.digest
          raise "cached result bypassed the custom clone"
        rescue RuntimeError => error
          raise unless error.message == "custom clone"
        end
        Digest::MD5.class_eval { remove_method :initialize_copy }
        original = Digest::Base.instance_method(:update)
        Digest::Base.class_eval { alias_method :update, :reset }
        begin
          manifest.digest
          raise "cached result bypassed a different native alias"
        rescue ArgumentError
        ensure
          Digest::Base.define_method(:update, original)
        end
        Digest::MD5.define_singleton_method(:hash) { raise "custom cache-key hash" }
        begin
          raise "cache-key override changed the digest" unless manifest.digest == expected
        ensure
          Digest::MD5.singleton_class.remove_method(:hash)
        end
        before = Lowrail::Stats.unit_hits.values.sum
        raise "restored digest differs" unless manifest.digest == expected
        conversions = 0
        path = Object.new
        path.define_singleton_method(:to_path) { conversions += 1; RailsVite.config.manifest_path.to_s }
        raise "custom path differs" unless RailsVite::Manifest.new(path).digest == expected
        raise "path converted more than once" unless conversions == 1
        calls = 0
        custom = Object.new
        custom.define_singleton_method(:file) { |name| calls += 1; ::Digest::MD5.file(name) }
        scoped = Module.new
        scoped.const_set(:MD5, custom)
        RailsVite.const_set(:Digest, scoped)
        begin
          raise "scoped digest differs" unless manifest.digest == expected
          raise "scoped digest was bypassed" unless calls == 1
        ensure
          RailsVite.send(:remove_const, :Digest)
        end
        original_digest = ::Digest
        Object.send(:remove_const, :Digest)
        Object.const_set(:Digest, Module.new)
        Digest.const_set(:MD5, original_digest::MD5)
        begin
          raise "rebound namespace differs" unless manifest.digest == expected
        ensure
          Object.send(:remove_const, :Digest)
          Object.const_set(:Digest, original_digest)
        end
        ractor = Ractor.new(RailsVite.config.manifest_path.to_s) do |name|
          RailsVite::Manifest.new(name).digest
        end
        value = ractor.respond_to?(:value) ? ractor.value : ractor.take
        raise "non-main Ractor digest differs" unless value == expected
        puts JSON.generate(recovered: Lowrail::Stats.unit_hits.values.sum > before,
          fallbacks: Lowrail::Stats.unit_fallbacks.values.sum)
      RUBY
      assert result.fetch("recovered")
      assert_equal 6, result.fetch("fallbacks")

      # A same-line `using` must not escape detection: a global method fact
      # cannot certify dispatch through a lexical refinement.
      FileUtils.mkdir_p(File.join(dir, "config/initializers"))
      File.write(File.join(dir, "config/initializers/refined.rb"), <<~'RUBY')
        require "digest"
        module ScopedDigest
          refine Digest::MD5.singleton_class do
            def file(_)
              result = Object.new
              def result.hexdigest = "refined"
              result
            end
          end
        end
        module RailsVite; using ScopedDigest
          class Manifest
            def digest
              Digest::MD5.file(@path).hexdigest
            end
          end
        end
      RUBY
      out, err, status = Open3.capture3(CLEAN_ENV, binary, "build", dir, "--digest-memo")
      assert status.success?, "#{err}\n#{out}"
      ledger = JSON.parse(File.read(File.join(dir, ".lowrail/ledger.json")))
      assert ledger.any? { _1["pass"] == "digest/file_memo" && _1["outcome"] == "refused" && _1["reason"] == "refinements" && _1["detail"] == "refined gem source" }
      result = ruby_json(<<~'RUBY', chdir: dir, env: {"RAILS_ENV" => "test", "LOWRAIL" => "1"})
        require_relative "config/environment"
        puts JSON.generate(digest: RailsVite::Manifest.new("unused").digest)
      RUBY
      assert_equal "refined", result.fetch("digest")
    end
  end
end
