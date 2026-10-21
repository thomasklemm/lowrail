# frozen_string_literal: true

require_relative "test_helper"

class RSpecReporterTest < Minitest::Test
  include LowrailTest

  SUITE = <<~'RUBY'
    if Gem::Specification.find_all_by_name("bootsnap").any?
      require "bootsnap"
      Bootsnap.setup(cache_dir: File.join(Dir.pwd, "tmp/cache"), development_mode: false,
                     load_path_cache: true, compile_cache_iseq: true, compile_cache_yaml: false)
    end
    require "rspec/autorun"
    require File.join(Dir.pwd, "app")
    RSpec.describe "same descriptions" do
      it("duplicate") { 3.times { expect(Calc.new.compute(1)[1]).to eq(2) } }
      it("duplicate") { expect(2).to eq(7) }
      it("raises") { raise ArgumentError, "boom #{Object.new.inspect}\nsecond line" }
      it("skips") { skip "later" }
      it("pending") { pending "known bug"; expect(2).to eq(8) }
      it("fixed pending") { pending "no longer broken"; expect(2).to eq(2) }
    end
  RUBY

  def test_rubyopt_outcomes_with_and_without_lowering
    missing_prerequisite "rspec not installed" if Gem::Specification.find_all_by_name("rspec-core").empty?
    realpath_tmpdir do |dir|
      build_app(dir)
      File.write(File.join(dir, "sample_spec.rb"), SUITE)
      reports = %w[0 1].map do |mode|
        path = File.join(dir, "outcomes-#{mode}.json")
        _out, err, status = ruby("sample_spec.rb", chdir: dir,
                                env: { "LOWRAIL" => mode, "LOWRAIL_OUTCOMES" => path })
        assert_equal 1, status.exitstatus, err
        files = Dir["#{path}.*"]
        assert_equal 1, files.size, err
        JSON.parse(File.read(files.first))
      end
      off, on = reports
      assert_equal off["tests"], on["tests"]
      tests = on.fetch("tests")
      assert_equal 6, tests.size, "duplicate descriptions must have distinct ids"
      outcomes = tests.sort.map(&:last)
      assert_equal %w[pass fail fail skip skip fail], outcomes.map { _1["result"] }
      assert_match(/expected: 7/, outcomes[1]["failure"])
      assert_equal "ArgumentError: boom #<Object:0x?>\nsecond line", outcomes[2]["failure"]
      assert_equal "later", outcomes[3]["failure"]
      assert_match(/expected: 8/, outcomes[4]["failure"])
      assert_match(/PendingExampleFixedError/, outcomes[5]["failure"])
      assert_equal({}, off["unit_hits"])
      assert_equal({ "0" => 3 }, on["unit_hits"])
    end
  end

  def test_declared_companion_reseeds_before_each_example_and_attests_the_tests
    missing_prerequisite "rspec not installed" if Gem::Specification.find_all_by_name("rspec-core").empty?
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "sample_spec.rb"), <<~'RUBY')
        require "rspec/autorun"
        RSpec.describe "per-example RNG" do
          2.times do
            it("starts at the declared seed") do
              seed = Integer(ENV.fetch("LOWRAIL_COMPANION_SEED"))
              random = Random.new(seed)
              expect(Array.new(4) { rand(100_000) }).to eq(Array.new(4) { random.rand(100_000) })
            end
          end
        end
      RUBY
      %w[0 1].each do |seed|
        path = File.join(dir, "outcomes-#{seed}.json")
        _out, err, status = ruby("sample_spec.rb", chdir: dir, env: {
          "LOWRAIL_OUTCOMES" => path, "LOWRAIL_COMPANION_SEED" => seed, "LOWRAIL_COMPANION_RNGS" => "Kernel" })
        assert status.success?, err
        data = JSON.parse(File.read(Dir["#{path}.*"].fetch(0)))
        assert_equal 2, data.fetch("tests").size
        rng = data.fetch("companion_rng").fetch(0)
        assert_equal seed.to_i, rng.fetch("seed")
        assert_equal "Kernel", rng.fetch("sources")
        assert_equal data.fetch("tests").keys.sort, rng.fetch("tests").sort
      end
    end
  end
end
