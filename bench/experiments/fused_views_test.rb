# frozen_string_literal: true

require_relative "../../gem/test/test_helper"

class FusedViewsTest < Minitest::Test
  include LowrailTest

  def test_collection_scopes_capture_and_post_notification_body_mutation
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "config/environment.rb" => <<~'RUBY',
          require "rails"
          require "action_controller/railtie"
          require "action_view/railtie"
          module FusionFixture
            class Application < Rails::Application
              config.root = File.expand_path("..", __dir__)
              config.eager_load = false
              config.secret_key_base = "x" * 64
              config.hosts.clear
              config.logger = Logger.new(File::NULL)
            end
          end
          Rails.application.initialize!
        RUBY
        "config/routes.rb" => 'Rails.application.routes.draw { get "/articles" => "articles#index" }',
        "app/controllers/articles_controller.rb" => <<~'RUBY',
          class ArticlesController < ActionController::Base
            layout "application"
            Widget = Struct.new(:title) { def to_partial_path = "articles/article" }
            def index
              $action_count = ($action_count || 0) + 1
              @articles = [Widget.new("<one>"), Widget.new("Z&two")]
            end
          end
        RUBY
        "app/views/articles/index.html.erb" => <<~'ERB',
          <% content_for :title, "Title & capture" %>
          <% content_for :head do %><%= tag.meta name: "fusion", content: "x&y" %><% end %>
          <%= render @articles %>
        ERB
        "app/views/articles/_article.html.erb" => '<p><%= article_counter %>:<%= article.title %>:<%= article_iteration.last? %></p>',
        "app/views/layouts/application.html.erb" => '<title><%= content_for(:title) %></title><%= yield :head %><main><%= yield %></main>')
      result = ruby_json(<<~RUBY, chdir: dir, setup: false)
        require "./config/environment"
        require "rack/mock"
        require #{File.expand_path("fused_views", __dir__).inspect}
        FusedViews.observe
        FusedViews.install(ArticlesController, "index", partials: ["articles/article"])
        raise FusedViews::LEDGER.inspect unless FusedViews::PLANS.size == 1
        rack = Rack::MockRequest.new(Rails.application)
        get = -> { rack.get("/articles", "HTTP_HOST" => "example.org").body }
        off = get.call
        FusedViews.enabled = true
        on = get.call
        plan = FusedViews::PLANS.values.first
        partial = plan.templates.last
        holder = ArticlesController.view_context_class
        original = holder.instance_method(partial.method_name)
        # Redefine AFTER the entry certificate, inside the partial's actual
        # instrumentation start. No top-level fallback may replay the action.
        mutator = Object.new
        mutator.define_singleton_method(:start) do |name, id, payload|
          if payload[:identifier] == partial.identifier
            holder.define_singleton_method(:method_added) { |_| }
            holder.define_method(partial.method_name) do |locals, buffer, &block|
              original.bind_call(self, locals, buffer, &block).safe_concat("<b>changed</b>")
            end
          end
        end
        mutator.define_singleton_method(:finish) { |*| }
        subscription = ActiveSupport::Notifications.subscribe("!render_template.action_view", mutator)
        changed = get.call
        ActiveSupport::Notifications.unsubscribe(subscription)
        FusedViews.enabled = false
        changed_stock = get.call
        puts JSON.generate(off: off, on: on, changed: changed, changed_stock: changed_stock,
          actions: $action_count, hits: FusedViews::COUNTS)
      RUBY
      assert_equal result.fetch("off"), result.fetch("on")
      assert_includes result.fetch("on"), "0:&lt;one&gt;:false"
      assert_includes result.fetch("on"), "1:Z&amp;two:true"
      assert_includes result.fetch("on"), 'content="x&amp;y"'
      assert_equal result.fetch("changed_stock"), result.fetch("changed")
      assert_equal 2, result.fetch("changed").scan("<b>changed</b>").size
      assert_equal 4, result.fetch("actions")
      assert_equal 2, result.fetch("hits").fetch("ArticlesController#index.html/articles/_article")
    end
  end
end
