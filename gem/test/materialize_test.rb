# frozen_string_literal: true

# Materialize phase of lowrail-facts on a minimal Rails app built in a
# tmpdir (Rails, sqlite3 and bcrypt from the Ruby installation, no
# Bundler). Skipped when Rails is not installed.
#   ruby -Igem/lib -Igem/test gem/test/materialize_test.rb

require "test_helper"

class MaterializeTest < Minitest::Test
  include LowrailTest

  EXE = File.join(GEM_ROOT, "exe", "lowrail-facts")

  FILES = {
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

  def self.facts
    @facts ||= begin
      dir = File.realpath(Dir.mktmpdir("lowrail-mat"))
      FILES.each do |rel, src|
        FileUtils.mkdir_p(File.dirname(File.join(dir, rel)))
        File.write(File.join(dir, rel), src)
      end
      out = File.join(dir, ".lowrail", "facts.json")
      _, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "test"), RUBY, EXE, out, chdir: dir)
      status.success? ? [dir, JSON.parse(File.read(out))] : [dir, err]
    end
  end

  def setup
    skip "Rails or sqlite3 not installed" unless rails_installed?
    @dir, @f = self.class.facts
    assert_kind_of Hash, @f, "lowrail-facts failed:\n#{@f}"
  end

  def rails_installed?
    _, _, st = Open3.capture3(CLEAN_ENV, RUBY, "-e", 'require "rails"; require "sqlite3"; require "bcrypt"')
    st.success?
  end

  def step(name) = @f["materialize"].find { |s| s["step"] == name }

  def mod(name) = @f["modules"].find { |m| m["name"] == name }

  def methods_of(name) = mod(name)["methods"].map { |m| m["name"] }

  def test_steps_run_in_order_with_deltas
    assert_equal %w[eager_load production_eager_load models relation_delegation routes controllers middleware i18n templates],
      @f["materialize"].map { |s| s["step"] }
    assert_empty @f["errors"].reject { |e| e["kind"] == "skipped" }
    @f["materialize"].each do |s|
      assert_equal 0, s["errors"], s.inspect
      %w[modules methods scripts seconds].each { |k| assert_kind_of Numeric, s[k], "#{s["step"]} #{k}" }
    end
    assert_operator @f["census_boot"]["methods"], :>, 1000
    # Attribute methods appear only when materialized (eager loading just
    # defines the model class).
    assert_operator step("models")["methods"], :>, 50
    # Rails 8 loads routes lazily in tests: the route helpers appear here.
    assert_operator step("routes")["methods"], :>=, 4
    assert_includes @f["timings"].keys, "materialize_seconds"
  end

  def test_model_surface
    attrs = methods_of("Widget::GeneratedAttributeMethods")
    %w[name name= email status title title= saved_change_to_email?].each { |m| assert_includes attrs, m }
    assert_includes methods_of("Widget"), "label"
    # Anonymous holders are dumped under the model's name.
    assert_includes methods_of("Widget._enum_methods_module"), "live!"
    assert_includes methods_of("Widget._store_accessors_module"), "color="
    secure = @f["modules"].find { |m| m["synthetic"] && m["name"].start_with?("Widget.ancestors[") && m["methods"].any? { |x| x["name"] == "authenticate_password" } }
    refute_nil secure, "has_secure_password's InstanceMethodsOnActivation"
    # Speculative relation delegation for the one app class method.
    assert_equal "speculative: 1 model class methods", step("relation_delegation")["note"]
    assert(@f["modules"].any? { |m| m["name"].start_with?("Widget::GeneratedRelationMethods") && m["methods"].any? { |x| x["name"] == "cheapest" } })
  end

  def test_templates_are_compiled_and_linked_to_their_script
    compiled = @f["compiled_templates"].select { |t| t["in_app"] }.map { |t| File.basename(t["identifier"]) }.sort
    assert_equal %w[_row.html.erb index.html.erb], compiled
    container = @f["modules"].find { |m| m["synthetic"] && m["name"].end_with?("view_context_class") }
    index = container["methods"].find { |m| m["source_location"]&.include?("widgets/index.html.erb") }
    script = @f["generated_scripts"].find { |s| s["sha256"] == index["script"] }
    assert_equal "materialize:templates", script["phase"]
    source = File.read(File.join(@dir, ".lowrail", "generated", "#{script["sha256"]}.rb"))
    assert_includes source, "def #{index["name"]}(local_assigns, output_buffer"
    helpers = @f["modules"].find { |m| m["name"] == "Rails.application.routes.named_routes.path_helpers_module" }
    assert_equal %w[widget_path widgets_path], helpers["methods"].map { |m| m["name"] }.sort
  end

  def test_generated_scripts_cover_attribute_methods
    title = mod("Widget::GeneratedAttributeMethods")["methods"].find { |m| m["name"] == "name" }
    script = @f["generated_scripts"].find { |s| s["sha256"] == title["script"] }
    refute_nil script, "attribute reader is linked to its generated script"
    assert_equal "materialize:models", script["phase"]
    assert_includes File.read(File.join(@dir, ".lowrail", "generated", "#{script["sha256"]}.rb")), "def name;"
  end
end
