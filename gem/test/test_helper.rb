# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require "open3"
require "rbconfig"
require "fileutils"

ENV["LOWRAIL_SHADOW"] = "strict"

module LowrailTest
  GEM_ROOT = File.expand_path("..", __dir__)
  GEM_LIB = File.join(GEM_ROOT, "lib")
  COMPILE = File.join(GEM_ROOT, "exe", "lowrail-compile")
  CORPUS_ROOT = File.expand_path(ENV.fetch("LOWRAIL_TEST_CORPUS_ROOT", "../../.corpus"), __dir__)
  RUBY = RbConfig.ruby
  SETUP_OPT = "-I#{GEM_LIB} -rlowrail/setup"
  # Variables a developer's shell might carry into the subprocesses.
  CLEAN_ENV = %w[LOWRAIL LOWRAIL_ROOT LOWRAIL_DIR LOWRAIL_STATS LOWRAIL_OUTCOMES LOWRAIL_DEBUG LOWRAIL_JIT_DIAGNOSTICS RUBYOPT
                 LOWRAIL_COMPANION_SEED LOWRAIL_COMPANION_RNGS
                 LOWRAIL_BUILD_JIT RUBY_YJIT_ENABLE RUBY_ZJIT_ENABLE RAILS_ENV RACK_ENV BUNDLE_GEMFILE].to_h { [_1, nil] }.merge("LOWRAIL_SHADOW" => "strict")

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

  # Required local prerequisites may skip a developer's partial run, but
  # must never silently remove coverage from a full gate.
  def missing_prerequisite(reason)
    message = "missing prerequisite: #{reason}"
    flunk message if ENV["LOWRAIL_STRICT_GATES"] == "1"
    skip message
  end

  def lowrail_cli
    root = File.expand_path("..", GEM_ROOT)
    binary = File.join(root, "target/debug/lowrail")
    unless File.executable?(binary)
      begin
        out, err, status = Open3.capture3(CLEAN_ENV, "cargo", "build", "--locked", chdir: root)
      rescue Errno::ENOENT
        missing_prerequisite "install Cargo to build target/debug/lowrail"
      end
      assert status.success?, "cargo build --locked failed:\n#{err}\n#{out}"
    end
    binary
  end

  RAILS_APP = {
    "config/environment.rb" => <<~'RUBY',
      require "logger"
      require "rails"
      require "active_record/railtie"
      require "action_controller/railtie"
      require "action_view/railtie"
      require "bcrypt"

      class FixtureApp < Rails::Application
        config.root = File.expand_path("..", __dir__)
        config.eager_load = false
        config.logger = Logger.new(nil)
        config.secret_key_base = "x" * 64
        config.active_support.deprecation = :silence
      end
      Rails.application.initialize!
      ActiveRecord::Schema.verbose = false
      ActiveRecord::Schema.define do
        create_table(:widgets) do |t|
          t.string :name
          t.integer :status
          t.text :settings
          t.string :email
          t.string :password_digest
        end
      end
    RUBY
    "config/database.yml" => <<~'YAML',
      test:
        adapter: sqlite3
        database: ":memory:"
        pool: 1
    YAML
    "config/routes.rb" => <<~'RUBY',
      Rails.application.routes.draw do
        resources :widgets, only: %i[index show]
      end
    RUBY
    "app/models/application_record.rb" => <<~'RUBY',
      class ApplicationRecord < ActiveRecord::Base
        primary_abstract_class
      end
    RUBY
    "app/models/widget.rb" => <<~'RUBY',
      class Widget < ApplicationRecord
        enum :status, {draft: 0, live: 1}
        normalizes :email, with: ->(e) { e.strip.downcase }
        store :settings, accessors: [:color], coder: JSON
        has_secure_password
        alias_attribute :title, :name
        scope :named, -> { where.not(name: nil) }

        def self.cheapest = order(:id).first

        def label = "#{name} (#{status})"

        def greet(other, loud: false) = loud ? "HI #{other}" : nil
      end
    RUBY
    "app/controllers/application_controller.rb" => <<~'RUBY',
      class ApplicationController < ActionController::Base
      end
    RUBY
    "app/controllers/widgets_controller.rb" => <<~'RUBY',
      class WidgetsController < ApplicationController
        def index = @widgets = Widget.all
        def show = @widget = Widget.find(params[:id])
      end
    RUBY
    "app/views/widgets/index.html.erb" => <<~'ERB',
      <% @widgets.each do |w| %><%= link_to w.label, widget_path(w) %><% end %>
    ERB
    "app/views/widgets/_row.html.erb" => <<~'ERB',
      <%# locals: (widget:) -%>
      <p><%= widget.name %></p>
    ERB
  }.freeze

  # Writes the minimal Rails app above into +dir+ (no Gemfile: Rails,
  # sqlite3 and bcrypt come from the Ruby installation).
  def self.write_rails_app(dir, extra = {})
    RAILS_APP.merge(extra).each do |rel, src|
      FileUtils.mkdir_p(File.dirname(File.join(dir, rel)))
      File.write(File.join(dir, rel), src)
    end
  end

  def self.rails_installed?
    return @rails_installed unless @rails_installed.nil?
    _, _, st = Open3.capture3(CLEAN_ENV, RUBY, "-e", 'require "rails"; require "sqlite3"; require "bcrypt"')
    @rails_installed = st.success?
  end

  def realpath_tmpdir(&)
    Dir.mktmpdir("lowrail") { |d| yield File.realpath(d) }
  end

  class GateSummary < Minitest::StatisticsReporter
    def report
      super
      skipped = results.select(&:skipped?).sort_by { [_1.klass, _1.name] }
      mode = ENV["LOWRAIL_STRICT_GATES"] == "1" ? "strict" : "normal"
      io.puts "\nLowrail gate summary (#{mode}): #{skipped.size} named skips"
      skipped.each { io.puts "  #{_1.klass}##{_1.name}: #{_1.failure.message}" }
    end
  end
end

def Minitest.plugin_lowrail_gates_init(options)
  reporter << LowrailTest::GateSummary.new(options[:io], options)
end
Minitest.extensions << "lowrail_gates"
