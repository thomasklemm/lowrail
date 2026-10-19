# frozen_string_literal: true

require_relative "test_helper"
require "lowrail"
require "lowrail/manifest"

class ManifestTest < Minitest::Test
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
    data = { "format" => 1, "ruby_description" => RUBY_DESCRIPTION.sub(" +YJIT", ""), "compile_option" => "x", "files" => {},
             "units" => [{ "id" => 0, "facts" => [{ "method" => "a" }, { "method" => "b" }] },
                         { "id" => 1, "facts" => [{ "method" => "a" }, { "method" => "a" }] }] }
    m = Lowrail::Manifest.new(data, "/tmp")
    assert_equal({ a: [0, 1], b: [0] }, m.units_by_method)
    assert m.compatible?
    refute Lowrail::Manifest.new(data.merge("format" => 2), "/tmp").compatible?
    refute Lowrail::Manifest.new(data.merge("ruby_description" => "ruby 3.3.0 [x86_64-linux]"), "/tmp").compatible?
    assert_nil m.iseq_for("/nowhere.rb")
  end

  def test_description_normalization_ignores_runtime_flags
    base = "ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]"
    assert_equal Lowrail::Manifest.normalize(base),
                 Lowrail::Manifest.normalize(base.sub("+PRISM", "+YJIT +PRISM"))
  end
end
