# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require "open3"
require "rbconfig"
require "fileutils"

module LowrailTest
  GEM_ROOT = File.expand_path("..", __dir__)
  GEM_LIB = File.join(GEM_ROOT, "lib")
  COMPILE = File.join(GEM_ROOT, "exe", "lowrail-compile")
  RUBY = RbConfig.ruby
  SETUP_OPT = "-I#{GEM_LIB} -rlowrail/setup"
  # Variables a developer's shell might carry into the subprocesses.
  CLEAN_ENV = %w[LOWRAIL LOWRAIL_ROOT LOWRAIL_STATS LOWRAIL_OUTCOMES LOWRAIL_DEBUG RUBYOPT
                 RAILS_ENV RACK_ENV BUNDLE_GEMFILE].to_h { [_1, nil] }

  # The sample app used by the end-to-end and guard tests. Unit 0 assumes
  # Dep.value (singleton fact), unit 1 assumes Calc#name (instance fact).
  APP_SRC = <<~RUBY
    class Dep
      def self.value = 1
    end

    class Calc
      def compute(x)
        [:orig, Dep.value + x]
      end

      def name = "calc"

      def label
        [:orig, name.upcase]
      end
    end
  RUBY

  # Guarded form from PLAN §3.3: the specialized branch goes on the def line,
  # the original body and line numbers stay.
  LOWERED_SRC = <<~RUBY
    class Dep
      def self.value = 1
    end

    class Calc
      def compute(x) if ::Lowrail::G[0] || ::Lowrail.check(0) then [:fast, 1 + x] else
        [:orig, Dep.value + x]
      end end

      def name = "calc"

      def label; if ::Lowrail::G[1] || ::Lowrail.check(1) then [:fast, "CALC"] else
        [:orig, name.upcase]
      end end
    end
  RUBY

  def ruby(*args, env: {}, chdir: Dir.pwd, setup: true)
    env = CLEAN_ENV.merge(setup ? { "RUBYOPT" => SETUP_OPT } : {}).merge(env)
    Open3.capture3(env, RUBY, *args, chdir: chdir)
  end

  # Runs code in a fresh process (with lowrail/setup via RUBYOPT) and returns
  # the JSON it prints on its last stdout line.
  def ruby_json(code, **opts)
    out, err, status = ruby("-e", code, **opts)
    assert status.success?, "subprocess failed:\n#{err}\n#{out}"
    JSON.parse(out.lines.last || "null")
  end

  def build_app(dir, units: default_units(dir), lowered: LOWERED_SRC, compile: true)
    File.write(File.join(dir, "app.rb"), APP_SRC)
    FileUtils.mkdir_p(File.join(dir, ".lowrail", "src"))
    File.write(File.join(dir, ".lowrail", "src", "app.rb"), lowered)
    input = { "out" => File.join(dir, ".lowrail"),
              "files" => [{ "path" => File.join(dir, "app.rb"), "lowered" => File.join(dir, ".lowrail", "src", "app.rb") }],
              "units" => units }
    File.write(File.join(dir, "units.json"), JSON.generate(input))
    return unless compile
    out, err, status = ruby(COMPILE, File.join(dir, "units.json"), setup: false)
    assert status.success?, "lowrail-compile failed:\n#{err}#{out}"
    assert_match(/compiled 1 file/, err)
  end

  def default_units(dir)
    app = File.join(dir, "app.rb")
    [
      { "id" => 0, "file" => app, "method" => "Calc#compute", "pass" => "test",
        "facts" => [{ "receiver" => "Dep", "method" => "value", "singleton" => true, "owner" => "#<Class:Dep>",
                      "source_location" => "#{app}:2", "visibility" => "public" }] },
      { "id" => 1, "file" => app, "method" => "Calc#label", "pass" => "test",
        "facts" => [{ "receiver" => "Calc", "method" => "name", "singleton" => false, "owner" => "Calc",
                      "source_location" => "#{app}:10", "visibility" => "public" }] }
    ]
  end

  # Minitest's stub lives in minitest/mock (minitest 5, or the minitest-mock
  # gem with minitest 6). Prelude for subprocess scripts; sets $mock.
  MOCK_PRELUDE = <<~RUBY
    $mock = begin
      require "minitest/mock"; true
    rescue LoadError
      begin
        gem "minitest", "< 6"; require "minitest/mock"; true
      rescue LoadError, Gem::LoadError
        false
      end
    end
  RUBY

  def realpath_tmpdir(&)
    Dir.mktmpdir("lowrail") { |d| yield File.realpath(d) }
  end
end
