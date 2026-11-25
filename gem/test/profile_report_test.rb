# frozen_string_literal: true

# Lowrail::ProfileReport on runs written here: how it classifies lines and
# what it holds while it reads them. Reports of real runs are in profile_test.rb.
#   ruby -Igem/lib -Igem/test gem/test/profile_report_test.rb

require "test_helper"
require "lowrail/profile_report"

class ProfileReportTest < Minitest::Test
  include LowrailTest

  def write_runs(dir, rows_for)
    %w[run1 run2].each do |run|
      FileUtils.mkdir_p(File.join(dir, run))
      2.times { |pid| File.write(File.join(dir, run, "#{pid}.tsv"), rows_for.(run, pid).join("\n") << "\n") }
    end
  end

  # An attribution run has a row per window name, line and app line in every
  # process (Sure: 785 MB in 16 files, a 6 GB report). The report merges
  # them without an object per row, so it holds far fewer objects than rows.
  def test_report_keeps_no_object_per_attributed_row
    realpath_tmpdir do |dir|
      names, callers = 400, 200
      write_runs(dir, lambda do |run, pid|
        rows = ["# lowrail-profile 3\trequests=#{names}\tobjects=1\tdropped=0\twindows=#{names},0,0,0\tpid=#{pid}\troot=/app",
          "P\t0\t/gems/foo-1.0/lib/foo.rb", "P\t1\t/app/app/controllers/c.rb", "0\t1\tString\t#{names}\t#{names}\t1\t0\trequest"]
        names.times do |n|
          rows << "A\trequest\tC#a#{n}\t1\t9\t1"
          next if run == "run1"
          callers.times { |line| rows << "@\trequest\tC#a#{n}\t0\t1\t1\t#{line + 1}\t#{n + line + 1}\t1" }
        end
        rows
      end)
      GC.start
      before = GC.stat(:heap_live_slots)
      report = Lowrail::ProfileReport.new(dir)
      report.to_h
      GC.start
      held = GC.stat(:heap_live_slots) - before
      assert_operator held, :<, names * callers / 4, "objects held for #{names * callers} attributed rows"
      assert_equal callers, report.app_lines.size
      assert_equal names, report.actions.size
    end
  end

  # A gem kept inside the app (GitLab's gems/, vendor/gems/) is a gem, as the
  # counter treats it, not an app line that no table ranks.
  def test_a_path_gem_inside_the_app_root_is_a_gem
    realpath_tmpdir do |dir|
      write_runs(dir, lambda do |_, pid|
        ["# lowrail-profile 3\trequests=4\tobjects=40\tdropped=0\twindows=4,0,0,0\tpid=#{pid}\troot=/app\tapp_root=/app",
          "P\t0\t/app/gems/foo/lib/foo.rb", "P\t1\t/app/vendor/gems/bar/lib/bar.rb", "P\t2\t/app/app/models/m.rb",
          "0\t3\tString\t20\t4\t0\t0\trequest", "1\t5\tString\t12\t4\t0\t0\trequest", "2\t7\tString\t8\t4\t0\t0\trequest",
          "A\trequest\tC#a\t4\t40\t0", "G\tfoo\t/app/gems/foo", "G\tbar\t/app/vendor/gems/bar"]
      end)
      sites = Lowrail::ProfileReport.new(dir).sites.to_h { ["#{_1.key}:#{_1.line}", _1.group] }
      assert_equal({ "GEM/foo/lib/foo.rb:3" => "gem: foo", "GEM/bar/lib/bar.rb:5" => "gem: bar", "APP/app/models/m.rb:7" => "app" }, sites)
    end
  end
end
