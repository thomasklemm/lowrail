# frozen_string_literal: true
require "minitest/autorun"
load File.expand_path("../script/rails-drift", __dir__)

class RailsDriftTest < Minitest::Test
  def test_source_report_distinguishes_member_changes_removal_and_certificate_only_changes
    Dir.mktmpdir("rails-drift-test-") do |dir|
      RailsDrift.git(dir, "init", "--quiet")
      RailsDrift.git(dir, "config", "user.name", "Thomas Klemm")
      RailsDrift.git(dir, "config", "user.email", "github@tklemm.eu")
      RailsDrift::UNITS.values.flat_map(&:first).uniq.each do |component|
        FileUtils.mkdir_p(File.join(dir, component, "lib"))
        File.write(File.join(dir, component, "lib/stable.rb"), "module Stable; def same = 17; end\n")
      end
      RailsDrift::VERSION_SOURCES.each do |source|
        FileUtils.mkdir_p(File.dirname(File.join(dir, source)))
        File.write(File.join(dir, source), "module Rails; VERSION = 'fixture'; end\n")
      end
      path = File.join(dir, "actionview/lib/changed.rb")
      File.write(path, "module View; TABLE = {a: 3}; def edited(x) = x + 2; def gone = 7; end\n")
      File.write(File.join(dir, "actionview/lib/removed.erb"), "<%= original %>\n")
      RailsDrift.git(dir, "add", ".")
      RailsDrift.git(dir, "-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", "base")
      base = RailsDrift.git(dir, "rev-parse", "HEAD").strip
      File.write(path, "module View; TABLE = {a: 9}; def edited(x) = x - 2; def added = 11; end\n")
      File.write(File.join(dir, "actionview/lib/stable.rb"), "# certificate changes, method does not\nmodule Stable; def same = 17; end\n")
      File.delete(File.join(dir, "actionview/lib/removed.erb"))
      RailsDrift.git(dir, "add", "-A")
      RailsDrift.git(dir, "-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", "head")
      prefix = File.join(dir, "report")
      capture_io { RailsDrift.compare(dir, base, "HEAD", prefix) }
      report = JSON.parse(File.read("#{prefix}.json"))
      files = report.fetch("files")
      assert_equal "removed", files.fetch("actionview/lib/removed.erb").fetch("status")
      assert_equal "changed", files.fetch("actionview/lib/stable.rb").fetch("status")
      assert_equal "unchanged", files.fetch("actionview/lib/stable.rb").fetch("members").fetch("method:Stable#same@1").fetch("status")
      members = files.fetch("actionview/lib/changed.rb").fetch("members")
      assert_equal "changed", members.fetch("constant:View::TABLE@1").fetch("status")
      assert_equal "changed", members.fetch("method:View#edited@1").fetch("status")
      assert_equal "removed", members.fetch("method:View#gone@1").fetch("status")
      assert_equal "added", members.fetch("method:View#added@1").fetch("status")
      assert_equal "changed", report.fetch("units").fetch("sealed/token_tag").fetch("status")
      assert_equal "unchanged", report.fetch("units").fetch("inertia/props").fetch("status")
      assert_includes File.read("#{prefix}.md"), "Re-certify; keep refused"
    end
  end
end
