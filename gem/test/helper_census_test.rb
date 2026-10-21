# frozen_string_literal: true

require_relative "test_helper"

class HelperCensusTest < Minitest::Test
  include LowrailTest

  def census(files)
    realpath_tmpdir do |root|
      files.each do |path, source|
        target = File.join(root, path)
        FileUtils.mkdir_p(File.dirname(target))
        File.write(target, source)
      end
      script = File.expand_path("../script/helper-census", GEM_ROOT)
      out, err, status = ruby(script, "fixture=#{root}", setup: false)
      refute_empty out, err
      return JSON.parse(out).fetch("apps").fetch("fixture"), status, err
    end
  end

  def test_public_report_distinguishes_shape_from_delivery_and_never_boots_app
    report, status, err = census(
      "config/environment.rb" => 'raise "must never boot"',
      "app/views/layouts/_nav.html.erb" => <<~'ERB',
        <%# link_to "Not a call", root_path, class: "x" %>
        <%= link_to "First", article_path(@article), class: "nav" %>
        <%= link_to "Second", "/other" %>
        <%= link_to root_path, class: "block" do %>Text<% end %>
        <%= link_to name, @article, **options %>
        <%= helpers.link_to "Foreign", "/", class: "nav" %>
        <%= button_to "Destroy", @article, method: :delete %>
        <%= form_with model: @article, url: article_path(@article) do |f| %><%= f.text_field :title %><% end %>
        <%= form_for @article do |f| %><%= f.submit %><% end %>
      ERB
      "app/components/_nav.html.erb" => '<%= link_to "Component", "/", class: "x" %>',
      "app/helpers/navigation.rb" => 'def nav; link_to "Ruby", "/", class: "x"; end')
    assert status.success?, err
    assert_empty report.fetch("errors")
    links = report.fetch("helpers").fetch("link_to")
    assert_equal 7, links.fetch("total")
    assert_equal 3, links.fetch("current_link_shape")
    assert_equal 1, links.fetch("current_link_delivery_candidates")
    candidate = report.fetch("sites").find { _1.fetch("current_link_delivery_candidate") }
    assert_equal 2, candidate.fetch("line")
    assert_equal "path_helper_dynamic_arguments", candidate.fetch("target")
    assert_equal ["record_shaped_reference"], candidate.fetch("target_arguments")
    assert candidate.fetch("partial")
    assert candidate.fetch("layout")
    assert report.fetch("sites").any? { _1.dig("options", "shape") == "dynamic_keys" }
    assert_equal 1, report.fetch("helpers").fetch("button_to").fetch("total")
    assert_equal 1, report.fetch("helpers").fetch("form_with").fetch("total")
    form = report.fetch("sites").find { _1.fetch("helper") == "form_with" }
    assert_equal({"model" => "record_shaped_reference", "url" => "path_helper_dynamic_arguments"}, form.fetch("target_keywords"))
    assert_equal 1, report.fetch("helpers").fetch("form_for").fetch("total")
  end

  def test_parse_errors_refuse_complete_census_instead_of_silently_counting_zero
    report, status, = census("app/helpers/broken.rb" => "def broken(\n")
    refute status.success?
    assert_equal "prism_parse_error", report.fetch("errors").first.fetch("reason")
    assert_equal "app/helpers/broken.rb", report.fetch("errors").first.fetch("file")
  end
end
