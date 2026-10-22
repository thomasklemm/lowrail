# frozen_string_literal: true

require_relative "test_helper"
require "digest"

class ViewTest < Minitest::Test
  include LowrailTest

  def test_template_keys_and_guard_locations_relocate_with_the_app
    realpath_tmpdir do |parent|
      a = File.join(parent, "build")
      b = File.join(parent, "release")
      Dir.mkdir(a)
      build_app(a, compile: false)
      template = File.join(a, "sample.html.erb")
      File.write(template, "<%= 'orig' %>")
      input = {"out" => File.join(a, ".lowrail"), "files" => [],
        "templates" => {template => {"source_sha256" => Digest::SHA256.file(template).hexdigest,
          "code" => '@output_buffer.safe_append=(::Lowrail.check(0) ? "fast" : "orig"); @output_buffer'}},
        "units" => [default_units(a).first.merge("kind" => "template", "file" => template)]}
      File.write(File.join(a, "units.json"), JSON.generate(input))
      _, err, status = ruby(COMPILE, File.join(a, "units.json"), setup: false)
      assert status.success?, err
      script = <<~'RUBY'
        require "json"
        require "action_view"
        require "./app"
        file = File.join(Dir.pwd, "sample.html.erb")
        view = ActionView::Base.with_empty_template_cache.new(ActionView::LookupContext.new([]), {}, nil)
        template = ActionView::Template.new(File.read(file), file,
          ActionView::Template.handler_for_extension("erb"), locals: [], format: :html)
        puts JSON.generate(body: template.render(view, {}).to_s,
          hits: Lowrail::Stats.unit_hits, reason: Lowrail.refusal_reason,
          ancestry: ActionView::Template.ancestors.map(&:name),
          templates_loaded: !!Lowrail.loaded_constant("Lowrail::Templates"))
      RUBY
      baseline = ruby_json(script, chdir: a, env: {"LOWRAIL_STATS" => ""})
      assert_equal "orig", baseline.fetch("body")
      assert_empty baseline.fetch("hits")
      assert_match(/app-visible ancestry delivery refused: template delivery/, baseline.fetch("reason"))
      refute baseline.fetch("templates_loaded")
      refute_includes baseline.fetch("ancestry"), "Lowrail::Templates::CompiledSource"
      FileUtils.cp_r(a, b)
      FileUtils.rm_rf(a)
      assert_equal baseline, ruby_json(script, chdir: b, env: {"LOWRAIL_STATS" => ""})
      File.write(File.join(b, "sample.html.erb"), "<%= 'changed' %>")
      refused = ruby_json(script, chdir: b, env: {"LOWRAIL_STATS" => ""})
      assert_equal "changed", refused.fetch("body")
      assert_empty refused.fetch("hits")
      assert_equal baseline.fetch("reason"), refused.fetch("reason")
    end
  end

  # Quarantine is an explicit refusal, not accelerated-arm certification.
  # Keep the original failing request and require Rails' observable result.
  def test_default_link_to_observes_a_suppressed_redefinition_after_warmup
    bin = lowrail_cli
    missing_prerequisite "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "Gemfile" => "source 'https://rubygems.org'\ngem 'rails', '8.1.4'\ngem 'sqlite3'\ngem 'bcrypt'\ngem 'prism'\n",
        "app/controllers/widgets_controller.rb" => "class WidgetsController < ApplicationController; def index; end; end\n",
        "app/views/widgets/index.html.erb" => '<% 10.times do %><%= link_to "link", "/target" %><% end %>')
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "test"), bin, "build", dir, "--passes", "default")
      assert status.success?, "default build failed:\n#{out}\n#{err}"
      manifest = JSON.parse(File.read(File.join(dir, ".lowrail/manifest.json")))
      assert_empty manifest.fetch("units"), "default source passes are quarantined, not merely guarded"
      ledger = JSON.parse(File.read(File.join(dir, ".lowrail/ledger.json")))
      assert_equal %w[active_record/ar_plans active_record/instantiate active_record/preload_plans
        digest/file_memo inertia/config_bind memo/sha256 memo/uri_join route/path view/link_to],
        ledger.select { _1["reason"] == "quarantined" }.map { _1.fetch("pass") }.sort
      refute manifest.fetch("units").any? { _1["pass"] == "endpoint/action" }
      scenario = <<~'RUBY'
        require "./config/environment"
        require "rack/mock"
        armed = false
        subscriber = Object.new
        subscriber.define_singleton_method(:start) do |*|
          next unless armed
          armed = false
          mod = ActionView::Helpers::UrlHelper
          original = mod.instance_method(:link_to)
          mod.define_singleton_method(:method_added) { |_| }
          mod.define_method(:link_to) do |*args, **kwargs, &block|
            original.bind_call(self, *args, **kwargs, &block) + "<!-- live helper -->".html_safe
          end
        end
        subscriber.define_singleton_method(:finish) { |*| }
        ActiveSupport::Notifications.subscribe("process_action.action_controller", subscriber)
        request = -> { Rack::MockRequest.new(Rails.application).get("/widgets", "HTTP_HOST" => "example.org") }
        warm = request.call
        armed = true
        changed = request.call
        puts JSON.generate(statuses: [warm.status, changed.status], warm: warm.body, changed: changed.body,
          hits: Lowrail::Stats.unit_hits)
      RUBY
      off, on = %w[0 1].map do |mode|
        ruby_json(scenario, chdir: dir, env: {"RAILS_ENV" => "test", "LOWRAIL" => mode, "LOWRAIL_STATS" => ""})
      end
      assert_equal [200, 200], off.fetch("statuses")
      assert_equal off.fetch("statuses"), on.fetch("statuses")
      assert_equal off.fetch("warm"), on.fetch("warm")
      assert_empty on.fetch("hits"), "refusal must not be reported as accelerated coverage"
      assert_equal 10, off.fetch("changed").scan("<!-- live helper -->").size
      assert_equal off.fetch("changed"), on.fetch("changed"), "a real subscriber must not leave a stale source arm authorized"
      observed = seal_repro(dir, scenario, target: "ActionView::Helpers::UrlHelper", operation: "define_method")
      assert_equal off.fetch("changed"), observed.fetch("changed")
    end
  end

  def test_name_expression_can_change_the_actual_builder_before_link_to
    default_fixture(
      "app/helpers/application_helper.rb" => <<~'RUBY',
        module ApplicationHelper
          def boundary_label
            $name_calls += 1
            if $armed
              tag_builder.define_singleton_method(:content_tag_string) { |*| "<!-- changed builder -->".html_safe }
            end
            "link"
          end
        end
      RUBY
      "app/views/widgets/index.html.erb" => '<%= link_to boundary_label, "/target" %>'
    ) do |dir|
      off, on = paired_requests(dir, <<~'RUBY', seal_target: "ActionView::Helpers::TagHelper::TagBuilder")
        $name_calls = 0
        $armed = false
        warm = request.call
        $name_calls = 0
        $armed = true
        changed = request.call
        {statuses: [warm.status, changed.status], warm: warm.body, changed: changed.body, calls: $name_calls}
      RUBY
      assert_equal [200, 200], off.fetch("statuses")
      assert_equal '<a href="/target">link</a>', off.fetch("warm")
      assert_equal "<!-- changed builder -->", off.fetch("changed")
      assert_equal 1, off.fetch("calls")
      assert_equal off, on, "a guard before the name expression cannot certify the later builder call"
    end
  end

  def test_to_param_can_change_the_actual_route_formatter_without_replaying_conversion
    default_fixture(
      "app/helpers/application_helper.rb" => <<~'RUBY',
        module ApplicationHelper
          def route_argument
            argument = Object.new
            argument.define_singleton_method(:to_param) do
              $conversions += 1
              if $armed
                route = Rails.application.routes.named_routes.get(:widget)
                route.define_singleton_method(:singleton_method_added) { |_| }
                route.define_singleton_method(:format) { |_| +"/changed" }
              end
              "7"
            end
            argument
          end
        end
      RUBY
      "app/views/widgets/index.html.erb" => '<%= widget_path(route_argument) %>'
    ) do |dir|
      off, on = paired_requests(dir, <<~'RUBY', seal_target: "ActionDispatch::Journey::Route")
        $conversions = 0
        $armed = false
        warm = request.call
        $conversions = 0
        $armed = true
        changed = request.call
        {statuses: [warm.status, changed.status], warm: warm.body, changed: changed.body, conversions: $conversions}
      RUBY
      assert_equal [200, 200], off.fetch("statuses")
      assert_equal "/widgets/7", off.fetch("warm")
      assert_equal "/changed", off.fetch("changed")
      assert_equal 1, off.fetch("conversions")
      assert_equal off, on, "continuation must not restart the helper or repeat to_param"
    end
  end

  private

  def default_fixture(extra)
    bin = lowrail_cli
    missing_prerequisite "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, {
        "Gemfile" => "source 'https://rubygems.org'\ngem 'rails', '8.1.4'\ngem 'sqlite3'\ngem 'bcrypt'\ngem 'prism'\n",
        "app/controllers/widgets_controller.rb" => "class WidgetsController < ApplicationController; def index; end; end\n"
      }.merge(extra))
      out, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "test"), bin, "build", dir, "--passes", "default")
      assert status.success?, "default build failed:\n#{out}\n#{err}"
      yield dir
    end
  end

  def paired_requests(dir, body, seal_target:)
    script = <<~RUBY
      require "./config/environment"
      require "rack/mock"
      request = -> { Rack::MockRequest.new(Rails.application).get("/widgets", "HTTP_HOST" => "example.org") }
      result = begin
        #{body}
      end
      puts JSON.generate(result)
    RUBY
    observed = seal_repro(dir, script, target: seal_target, operation: "define_singleton_method")
    assert_equal 1, observed["calls"] || observed["conversions"], "detector must not replay an effectful argument"
    %w[0 1].map { |mode| ruby_json(script, chdir: dir, env: {"RAILS_ENV" => "test", "LOWRAIL" => mode}) }
  end

  def seal_repro(dir, script, target:, operation:)
    path = File.join(dir, "seal_repro.rb")
    File.write(path, script)
    output = File.join(dir, "seal-observations")
    out, err, status = ruby(path, chdir: dir, env: {"RAILS_ENV" => "test", "LOWRAIL" => "0",
      "LOWRAIL_SEAL_CHECK" => output, "LOWRAIL_SEAL_ROOT" => dir, "LOWRAIL_STATS" => "",
      "RUBYOPT" => "-I#{GEM_LIB} -rlowrail/setup -rlowrail/seal"})
    assert status.success?, "#{out}\n#{err}"
    report = JSON.parse(File.read(Dir[File.join(output, "seal-*.json")].fetch(0)))
    assert report.fetch("sealed"), report.fetch("errors").inspect
    assert report.fetch("ledger").any? { |row| row["rule"] == "SEAL001" && row["target"].start_with?(target) &&
      row["confidence"] == "proven" && row["operation"] == "state_difference" &&
      row.fetch("candidates").any? { _1["operation"] == operation && _1["line"].positive? && File.file?(_1["file"]) } },
      "missing confirmed mutation and candidate location for #{target}"
    JSON.parse(out.lines.last)
  end
end
