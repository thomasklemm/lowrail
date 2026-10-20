# frozen_string_literal: true

# Materialize phase of lowrail-facts on a minimal Rails app built in a
# tmpdir (Rails, sqlite3 and bcrypt from the Ruby installation, no
# Bundler). Skipped when Rails is not installed.
#   ruby -Igem/lib -Igem/test gem/test/materialize_test.rb

require "test_helper"

class MaterializeTest < Minitest::Test
  include LowrailTest

  EXE = File.join(GEM_ROOT, "exe", "lowrail-facts")


  def self.facts
    @facts ||= begin
      dir = File.realpath(Dir.mktmpdir("lowrail-mat"))
      LowrailTest.write_rails_app(dir)
      out = File.join(dir, ".lowrail", "facts.json")
      _, err, status = Open3.capture3(CLEAN_ENV.merge("RAILS_ENV" => "test"), RUBY, EXE, out, chdir: dir)
      status.success? ? [dir, JSON.parse(File.read(out))] : [dir, err]
    end
  end

  def setup
    skip "Rails, sqlite3 or bcrypt not installed" unless LowrailTest.rails_installed?
    @dir, @f = self.class.facts
    assert_kind_of Hash, @f, "lowrail-facts failed:\n#{@f}"
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
    if (reason = @f["generated_stats"]["linking_decline"])
      assert_match(/\Aiseq_identity_unavailable:/, reason)
      refute index.key?("script")
    else
      script = @f["generated_scripts"].find { |s| s["sha256"] == index["script"] }
      assert_equal "materialize:templates", script["phase"]
      source = File.read(File.join(@dir, ".lowrail", "generated", "#{script["sha256"]}.rb"))
      assert_includes source, "def #{index["name"]}(local_assigns, output_buffer"
    end
    helpers = @f["modules"].find { |m| m["name"] == "Rails.application.routes.named_routes.path_helpers_module" }
    assert_equal %w[widget_path widgets_path], helpers["methods"].map { |m| m["name"] }.sort
  end

  def test_generated_scripts_cover_attribute_methods
    title = mod("Widget::GeneratedAttributeMethods")["methods"].find { |m| m["name"] == "name" }
    if (reason = @f["generated_stats"]["linking_decline"])
      assert_match(/\Aiseq_identity_unavailable:/, reason)
      refute title.key?("script")
    else
      script = @f["generated_scripts"].find { |s| s["sha256"] == title["script"] }
      refute_nil script, "attribute reader is linked to its generated script"
      assert_equal "materialize:models", script["phase"]
      assert_includes File.read(File.join(@dir, ".lowrail", "generated", "#{script["sha256"]}.rb")), "def name;"
    end
  end
end

# Integration: materialize on the corpus apps (skipped when absent).
# Campfire runs Rails 8.2, whose template container moved to
# ActionView::LookupContext.view_context_class.
class MaterializeCorpusTest < Minitest::Test
  include LowrailTest

  def facts_for(app)
    root = File.join(CORPUS_ROOT, app)
    skip "no #{root} (see script/corpus)" unless File.exist?(File.join(root, "Gemfile.lock"))
    Dir.mktmpdir do |dir|
      out = File.join(dir, "facts.json")
      run = -> { system("bundle", "exec", "ruby", MaterializeTest::EXE, out, "--no-census", chdir: root, err: File::NULL) }
      ok = defined?(Bundler) ? Bundler.with_unbundled_env(&run) : run.call
      assert ok, "lowrail-facts failed in #{root}"
      f = JSON.parse(File.read(out))
      [f, Dir.children(File.join(dir, "generated")).size]
    end
  end

  def check(f, sidecar_files)
    assert_empty f["errors"].reject { |e| e["kind"] == "skipped" }
    assert_operator f["compiled_templates"].count { |t| t["in_app"] }, :>, 5
    assert(f["modules"].any? { |m| m["synthetic"] && m["name"].end_with?(".view_context_class") && !m["methods"].empty? })
    assert_equal sidecar_files, f["generated_scripts"].map { |s| s["sha256"] }.uniq.size
    linked = f["modules"].sum { |m| m["methods"].count { |x| x["script"] } }
    if (reason = f["generated_stats"]["linking_decline"])
      assert_match(/\Aiseq_identity_unavailable:/, reason)
      assert_equal 0, linked
    else
      assert_operator linked, :>, 1000
    end
  end

  def test_real_blog = check(*facts_for("real-blog-r4"))

  def test_campfire = check(*facts_for("campfire"))
end
