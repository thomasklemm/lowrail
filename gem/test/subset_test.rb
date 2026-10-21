# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/lowrail/subset"

class SubsetTest < Minitest::Test
  def test_action_reports_keep_unknowns_and_separate_neighbor_effects
    Dir.mktmpdir("lowrail-subset") do |root|
      files = {
        "app/controllers/articles_controller.rb" => <<~RUBY,
          class ArticlesController < ApplicationController
            def index
              @articles = Article.all
            end
            def show
              public_send(params[:name])
            end
            private
            def internal = :hidden
          end
        RUBY
        "app/helpers/articles_helper.rb" => <<~RUBY,
          module ArticlesHelper
            def heading
              @title ||= "Changed"
            end
            def unused
              @other = 1
            end
          end
        RUBY
        "app/views/articles/index.html.erb" => "<%# locals: () %>\n<%= render \"articles/item\" %>",
        "app/views/articles/_item.html.erb" => "<%# locals: () %>\n<%= heading %>",
        "app/views/articles/show.html.erb" => "<%= render partial: \"articles/item\", collection: @articles, cached: true %>",
        "app/views/layouts/application.html.erb" => "<%# locals: () %>\n<%= yield %>"
      }
      files.each do |path, body|
        FileUtils.mkdir_p(File.dirname(File.join(root, path)))
        File.write(File.join(root, path), body)
      end
      report = Lowrail::Subset::Report.new(root).run
      assert_empty report.fetch("errors")
      assert_equal %w[ArticlesController#index ArticlesController#show], report.fetch("actions").map { _1.fetch("target") }
      index, show = report.fetch("actions")
      assert_equal ["SUB005"], index.fetch("rules_broken").map { _1.fetch("rule") }
      assert_equal "Writes @title", index.fetch("rules_broken").first.fetch("detail")
      assert_equal %w[SUB002 SUB004 SUB006], show.fetch("rules_broken").map { _1.fetch("rule") }.sort
      assert_nil index.dig("benefit", "estimated_speedup_pct")
      refute index.fetch("compliant"), "source hints cannot certify an unexercised contract"
      assert index.fetch("pending_certificates").any? { _1.include?("booted callback") }
      assert_equal 6, report.fetch("source_sha256").size

      # Callback bodies must remain mandatory even when action source is clean.
      boot = {"controllers" => [{"name" => "ArticlesController", "actions" => ["index"],
        "controller_path" => "articles", "callbacks" => [{"kind" => "around", "filter_type" => "proc", "filter" => "security"}]}]}
      booted = Lowrail::Subset::Report.new(root, boot: boot).run.fetch("actions").first
      assert booted.fetch("rules_broken").any? { _1.fetch("rule") == "SUB003" }
      refute booted.fetch("pending_certificates").any? { _1.include?("booted callback") }
    end
  end
end
