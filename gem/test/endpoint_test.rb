# frozen_string_literal: true

require_relative "test_helper"

class EndpointTest < Minitest::Test
  include LowrailTest

  def test_generated_entry_preserves_assigns_once_only_callbacks_and_live_events
    scenario = <<~'RUBY'
      require "./config/environment"
      require "rack/mock"
      require "lowrail"
      require "lowrail/stats"
      require "lowrail/compiler"
      require "lowrail/endpoint_build"
      Rails.application.eager_load!
      if ENV["MUTATE"] == "constant"
        File.write(Rails.root.join("app/views/articles/show.html.erb"), '<%= @article %><%= Widget.name %>')
      end
      built = Lowrail::EndpointBuild.build
      built.fetch(:units).each_with_index { _1["id"] = _2 }
      raise "no endpoint units" unless built[:units].size == 2
      compiled = Lowrail::Compiler.compile({"out" => File.expand_path(".lowrail"), "rails_env" => "test", "units" => built[:units]})
      raise "endpoint ISeq declined" unless compiled.fetch("units").size == 2
      Lowrail.setup(root: Dir.pwd)
      if ENV["MUTATE"] == "warm"
        2.times do
          %w[/articles /articles/47].each do |path|
            raise "warm response" unless Rack::MockRequest.new(Rails.application).get(path,
              "HTTP_HOST" => "example.org", "HTTP_ACCEPT" => "text/html").status == 200
          end
        end
        owner = ActionView::Helpers::UrlHelper
        original = owner.instance_method(:link_to)
        owner.define_singleton_method(:method_added) { |_| }
        owner.define_method(:link_to) do |name, options|
          original.bind_call(self, name, options) + "<!-- live helper -->".html_safe
        end
      end
      if ENV["MUTATE"] == "template"
        path = Rails.root.join("app/views/articles/index.html.erb")
        File.write(path, File.read(path) + "<!-- changed template -->")
        ArticlesController.view_paths.each(&:clear_cache)
        ActionView::LookupContext::DetailsKey.clear
      elsif ENV["MUTATE"] == "filter"
        ArticlesController.before_action { response.set_header("x-added-filter", "once") }
      end
      # The subscriber changes a fact AFTER process entry. A cached-only
      # certificate or a restart would fail these response-level assertions.
      mutator = Class.new do
        def start(name, id, payload)
          if ENV["MUTATE"] == "constant"
            controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            view_class = controller.view_context_class.compiled_method_container
            unless view_class.const_defined?(:Widget, false)
              replacement = Class.new
              def replacement.name = "view-widget"
              view_class.const_set(:Widget, replacement)
            end
          end
          return unless %w[1 2 3 4 5].include?(ENV["MUTATE"])
          mod = ActionView::Helpers::UrlHelper
          return if mod.instance_variable_get(:@endpoint_mutated)
          mod.instance_variable_set(:@endpoint_mutated, true)
          if ENV["MUTATE"] == "1"
            mod.prepend(Module.new do
              def link_to(...)
                super + "<!-- live helper -->".html_safe
              end
            end)
          elsif ENV["MUTATE"] == "4"
            controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
            original_view_context = controller.method(:view_context)
            controller.define_singleton_method(:view_context) do
              view = original_view_context.call
              original = view.method(:link_to)
              view.define_singleton_method(:singleton_method_added) { |_| }
              view.define_singleton_method(:link_to) do |name, options|
                original.call(name, options) + "<!-- live helper -->".html_safe
              end
              view
            end
          elsif ENV["MUTATE"] == "5"
            mod.send(:private, :link_to)
          else
            original = mod.instance_method(:link_to)
            # No invalidation hook, and deliberately narrower arity. A
            # fallback must preserve two arguments, not add an explicit nil.
            if ENV["MUTATE"] == "3"
              def mod.method_added(name)
                return if name == :link_to
                super
              end
            else
              def mod.method_added(*) = nil
            end
            mod.define_method(:link_to) do |name, options|
              original.bind_call(self, name, options) + "<!-- live helper -->".html_safe
            end
          end
        end
        def finish(*) = nil
      end.new
      observer = Class.new do
        def start(name, id, payload)
          controller = ActiveSupport::ExecutionContext.to_h.fetch(:controller)
          key = controller.action_name == "index" ? :@articles : :@article
          controller.response.set_header("x-assigned", controller.instance_variable_defined?(key).to_s)
        end
        def finish(*) = nil
      end.new
      ActiveSupport::Notifications.subscribe("process_action.action_controller", mutator)
      ActiveSupport::Notifications.subscribe("render_template.action_view", observer)
      accept = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5"
      results = %w[/articles /articles/47].map do |path|
        response = Rack::MockRequest.new(Rails.application).get(path, "HTTP_HOST" => "example.org", "HTTP_ACCEPT" => accept)
        {status: response.status, body: response.body, effects: response["x-effects"], assigned: response["x-assigned"], filter: response["x-added-filter"]}
      end
      puts JSON.generate({responses: results, hits: Lowrail::Stats.unit_hits, fallbacks: Lowrail::Stats.unit_fallbacks})
    RUBY
    %w[0 1 2 3 4 5 warm template filter constant].each do |mutation|
      realpath_tmpdir do |dir|
        write_endpoint_app(dir)
        result = ruby_json(scenario, chdir: dir, setup: false,
          env: {"RAILS_ENV" => "test", "LOWRAIL" => "1", "LOWRAIL_STATS" => "", "MUTATE" => mutation,
            "RUBYOPT" => "-I#{GEM_LIB} -rlowrail/setup"})
        index, show = result.fetch("responses")
        assert_equal [200, 200], [index.fetch("status"), show.fetch("status")]
        assert_equal mutation == "warm" ? ["5", "6"] : ["1", "2"], [index.fetch("effects"), show.fetch("effects")], "never replay the action or filters"
        assert_equal ["true", "true"], [index.fetch("assigned"), show.fetch("assigned")]
        assert_equal 10, index.fetch("body").scan('<a href="/target">link</a>').size
        assert_equal mutation == "constant" ? "47view-widget" : "47", show.fetch("body").strip
        assert_equal %w[1 2 3 4 warm].include?(mutation) ? 10 : 0, index.fetch("body").scan("<!-- live helper -->").size
        assert_equal mutation == "template", index.fetch("body").include?("<!-- changed template -->")
        assert_equal mutation == "filter" ? ["once", "once"] : [nil, nil], [index.fetch("filter"), show.fetch("filter")]
        assert_equal 1, result.fetch(%w[0 constant].include?(mutation) ? "hits" : "fallbacks").fetch("0", 0)
        if mutation == "warm"
          ["0", "1"].each do |mode|
            control = ruby_json(scenario, chdir: dir, setup: false,
              env: {"RAILS_ENV" => "test", "LOWRAIL" => mode, "MUTATE" => "warm",
                "RUBYOPT" => "-I#{GEM_LIB} -rlowrail/setup"})
            assert_equal result.fetch("responses"), control.fetch("responses"), "warm mutation, stats off, mode #{mode}"
          end
        end
      end
    end
  end

  def write_endpoint_app(dir)
    LowrailTest.write_rails_app(dir,
      "app/models/widget.rb" => "class Widget < ApplicationRecord; end\n",
      "config/environment.rb" => <<~'RUBY',
        require "rails"
        require "active_record/railtie"
        require "action_controller/railtie"
        require "action_view/railtie"
        module RealBlogR4
          class Application < Rails::Application
            config.root = File.expand_path("..", __dir__)
            config.eager_load = false
            config.logger = Logger.new(nil)
            config.secret_key_base = "x" * 64
            config.active_support.deprecation = :silence
            config.action_controller.allow_forgery_protection = false
          end
        end
        Rails.application.initialize!
      RUBY
      "config/routes.rb" => <<~'RUBY',
        Rails.application.routes.draw do
          resources :articles, only: %i[index show]
        end
      RUBY
      "app/controllers/articles_controller.rb" => <<~'RUBY',
        class ArticlesController < ApplicationController
          before_action :effect
          def index = @articles = [1, 2]
          def show = @article = params[:id]
          private
          def effect
            $effects = ($effects || 0) + 1
            response.set_header("x-effects", $effects.to_s)
          end
        end
      RUBY
      "app/views/articles/index.html.erb" => '<% 10.times do %><%= link_to "link", "/target" %><% end %>',
      "app/views/articles/show.html.erb" => '<%= @article %>',
      "app/views/articles/_article.html.erb" => '<%= article %>',
      "app/views/comments/_comment.html.erb" => '<%= comment %>',
      "app/views/layouts/application.html.erb" => '<%= yield %>')
  end
end
