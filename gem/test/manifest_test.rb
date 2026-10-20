# frozen_string_literal: true

require_relative "test_helper"
require "lowrail"
require "lowrail/manifest"

class ManifestTest < Minitest::Test
  include LowrailTest

  def test_minijson_matches_json
    samples = [
      {}, [], nil, true, false, 0, -12, 3.5, -1.25e-3, "", "plain",
      "esc \" \\ / \b \f \n \r \t", "unicode café ☃ 😀 \u0001",
      { "a" => [1, { "b" => nil, "c" => [true, false] }], "d" => "x:y,z{}[]" },
      { "nested" => [[[[]]], {}], "num" => 12_345_678_901_234 }
    ]
    samples.each do |s|
      [JSON.generate(s), JSON.pretty_generate(s), JSON.generate(s, ascii_only: true), JSON.generate(s, script_safe: true)].each do |text|
        expected = JSON.parse(text)
        expected.nil? ? assert_nil(Lowrail::MiniJSON.parse(text)) : assert_equal(expected, Lowrail::MiniJSON.parse(text), text)
      end
    end
  end

  def test_minijson_rejects_malformed
    ['{"a":}', '{"a" 1}', "[1,]", "[1 2]", '{"a":1', "nul", '"unterminated', "{} x", "", '{1:2}'].each do |text|
      assert_raises(ArgumentError, text) { Lowrail::MiniJSON.parse(text) }
    end
  end

  def test_units_by_method_and_compatibility
    data = { "format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION.sub(" +YJIT", ""), "compile_option" => "x", "files" => {},
             "units" => [{ "id" => 0, "facts" => [{ "method" => "a" }, { "method" => "b" }] },
                         { "id" => 1, "facts" => [{ "method" => "a" }, { "method" => "a" }] }] }
    m = Lowrail::Manifest.new(data, "/tmp")
    assert_equal({ a: [0, 1], b: [0] }, m.units_by_method)
    assert m.compatible?
    refute Lowrail::Manifest.new(data.merge("format" => 1), "/tmp").compatible?
    refute Lowrail::Manifest.new(data.merge("ruby_description" => "ruby 3.3.0 [x86_64-linux]"), "/tmp").compatible?
    assert_nil m.iseq_for("/nowhere.rb")
  end

  def test_description_normalization_ignores_runtime_flags
    base = "ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]"
    assert_equal Lowrail::Manifest.normalize(base),
                 Lowrail::Manifest.normalize(base.sub("+PRISM", "+YJIT +PRISM"))
  end

  def test_sealed_artifact_requires_its_own_opt_in_and_never_reopens_quarantine
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "lowrail"
      require "lowrail/manifest"
      data = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
        "files" => {}, "tier" => "sealed-v1", "rails_env" => "production",
        "units" => [{"id" => 0, "pass" => "sealed/link_to", "facts" => []}]}
      config = data.merge("units" => [{"id" => 0, "pass" => "inertia/config_bind", "facts" => []}])
      rows = [[nil, "production", data], ["1", "test", data], ["1", "production", data],
        ["1", "production", data.reject { _1 == "tier" }],
        ["1", "production", data.merge("tier" => "sealed-v2")],
        ["1", "production", data.merge("units" => [{"id" => 0, "pass" => "view/link_to", "facts" => []}])],
        ["1", "production", config], ["1", "production", config.reject { _1 == "tier" }],
        ["1", "production", data.merge("format" => 1)]]
      puts JSON.generate(rows.map do |opt_in, environment, artifact|
        ENV["LOWRAIL_SEALED"], ENV["RAILS_ENV"] = opt_in, environment
        Lowrail::Manifest.new(artifact, "/tmp").compatible?
      end)
    RUBY
    assert_equal [false, false, true, false, false, false, true, false, false], result
  end

  def test_relative_metadata_does_not_rewrite_opaque_values
    root = "/build/app"
    source = "#{root}/app/a~b.rb"
    original = {"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
      "compile_option" => "", "files" => {}, "units" => [{"id" => 0, "file" => source,
        "facts" => [{"method" => "value", "source_location" => "#{source}:12"}],
        "data" => {"sources" => {source => "sha"}, "config" => {"file" => source},
          "code" => "puts #{root.inspect}"}}]}
    persisted = Lowrail::Paths.relative(original, root: root, dir: "#{root}/.lowrail")
    assert_equal "app/a~b.rb", persisted["units"][0]["file"]
    manifest = Lowrail::Manifest.new(persisted, "/release/.lowrail", root: "/release")
    unit = manifest.units.first
    assert_equal "/release/app/a~b.rb", unit["file"]
    assert_equal "/release/app/a~b.rb:12", unit["facts"][0]["source_location"]
    assert_equal({"/release/app/a~b.rb" => "sha"}, unit["data"]["sources"])
    assert_equal({"file" => source}, unit["data"]["config"])
    assert_equal "puts #{root.inspect}", unit["data"]["code"]
  end
end
