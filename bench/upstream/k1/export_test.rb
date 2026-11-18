# frozen_string_literal: true

# ruby bench/upstream/k1/export_test.rb
require "minitest/autorun"
require "json"
require "open3"
require "tmpdir"

class ExportTest < Minitest::Test
  EXPORT = File.expand_path("export.rb", __dir__)

  def dump(dir, n, name, summary, totals)
    tail = totals ? "totals: #{totals}\n" : ""
    File.write("#{dir}/cg.1.#{n}", "desc: Trigger: Client Request: #{name}\nevents: Ir\nsummary: #{summary}\n" \
      "fl=x.c\nfn=work\n1 #{totals}\n#{tail}")
  end

  def export(dir)
    File.write("#{dir}/stdout", %({"case":"work","n":10,"objects":1.0}\n))
    Open3.capture3("ruby", EXPORT, dir, "main", "interp")
  end

  def test_uses_trailing_totals_not_summary
    Dir.mktmpdir do |dir|
      dump(dir, 1, "_empty", 999_999, 100)
      dump(dir, 2, "work", 18_446_744_073_709_122_988, 2_100)
      out, _, status = export(dir)
      assert status.success?
      assert_equal 200, JSON.parse(out)["ir"]
    end
  end

  def test_fails_without_totals
    Dir.mktmpdir do |dir|
      dump(dir, 1, "_empty", 100, 100)
      dump(dir, 2, "work", 2_100, nil)
      out, err, status = export(dir)
      refute status.success?
      assert_empty out
      assert_match "missing Callgrind totals", err
    end
  end
end
