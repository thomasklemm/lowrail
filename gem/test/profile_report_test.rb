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
        rows = ["# lowrail-profile 4\trequests=#{names}\tobjects=1\tdropped=0\twindows=#{names},0,0,0\tpid=#{pid}\troot=/app",
          "P\t0\t/gems/foo-1.0/lib/foo.rb", "P\t1\t/app/app/controllers/c.rb", "0\t1\tString\t#{names}\t#{names}\t1\t0\trequest"]
        names.times do |n|
          rows << "A\trequest\tC#a#{n}\t1\t9\t1\t0"
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
  # counter treats it, not an app line that no table ranks. An app directory
  # that is only named gems (a GemsController's views) stays the app's.
  def test_a_path_gem_inside_the_app_root_is_a_gem
    realpath_tmpdir do |dir|
      write_runs(dir, lambda do |_, pid|
        ["# lowrail-profile 4\trequests=4\tobjects=44\tdropped=0\twindows=4,0,0,0\tpid=#{pid}\troot=/app\tapp_root=/app",
          "P\t0\t/app/gems/foo/lib/foo.rb", "P\t1\t/app/vendor/gems/bar/lib/bar.rb", "P\t2\t/app/app/models/m.rb", "P\t3\t/app/app/views/gems/index.html.erb", "3\t9\tString\t4\t4\t0\t0\trequest",
          "0\t3\tString\t20\t4\t0\t0\trequest", "1\t5\tString\t12\t4\t0\t0\trequest", "2\t7\tString\t8\t4\t0\t0\trequest",
          "A\trequest\tC#a\t4\t44\t0\t0", "G\tfoo\t/app/gems/foo", "G\tbar\t/app/vendor/gems/bar"]
      end)
      sites = Lowrail::ProfileReport.new(dir).sites.to_h { ["#{_1.key}:#{_1.line}", _1.group] }
      assert_equal({ "GEM/foo/lib/foo.rb:3" => "gem: foo", "GEM/bar/lib/bar.rb:5" => "gem: bar", "APP/app/models/m.rb:7" => "app",
        "APP/app/views/gems/index.html.erb:9" => "app" }, sites)
    end
  end

  # An engine profiled in place is itself a path gem whose directory is the
  # root: its app/views/gems/ is the engine's own line, as its other files are.
  # So is a dummy app's below an engine kept in a gems/ directory.
  def test_an_engine_profiled_in_place_keeps_its_gems_directory
    { "/engine" => "/engine", "/src/gems/engine/spec/dummy" => "/src/gems/engine" }.each do |root, engine|
      realpath_tmpdir do |dir|
        write_runs(dir, lambda do |_, pid|
          ["# lowrail-profile 4\trequests=4\tobjects=32\tdropped=0\twindows=4,0,0,0\tpid=#{pid}\troot=#{root}\tapp_root=#{root}",
            "P\t0\t#{root}/app/views/gems/index.html.erb", "P\t1\t#{root}/app/models/m.rb",
            "0\t5\tString\t12\t4\t0\t0\trequest", "1\t9\tString\t20\t4\t0\t0\trequest",
            "A\trequest\tGemsController#index\t4\t32\t0\t0", "G\tmy_engine\t#{engine}"]
        end)
        sites = Lowrail::ProfileReport.new(dir).sites.to_h { ["#{_1.key}:#{_1.line}", _1.group] }
        assert_equal({ "APP/app/views/gems/index.html.erb:5" => "app", "APP/app/models/m.rb:9" => "app" }, sites, root)
      end
    end
  end

  # Found in a field test of a system-test slice: most counted requests were
  # files ActionDispatch::Static served before routing, with no action name.
  # They get the file handler's name; the header says how many and the
  # objects per request without them, next to the warm number the noise floor
  # counts. By gem keeps dev/test-mode work (an error page parsing every frame
  # with Prism) in a group of its own and names groups with no warm objects in
  # one line; From the app marks middleware that only hands the request on.
  def test_report_header_and_by_gem
    realpath_tmpdir do |dir|
      root = File.join(dir, "app")
      FileUtils.mkdir_p(File.join(root, "app/middleware"))
      File.write(File.join(root, "app/middleware/wrap.rb"), "class Wrap\n  def call(env) = @app.call(env)\nend\n")
      write_runs(dir, lambda do |run, pid|
        rows = ["# lowrail-profile 4\trequests=4\tobjects=130\tdropped=0\twindows=4,0,0,0\tpid=#{pid}\troot=#{root}\tapp_root=#{root}",
          "P\t0\t/gems/foo-1.0/lib/foo.rb", "P\t1\t/gems/prism-1.0/lib/prism.rb", "P\t2\t/gems/bar-1.0/lib/bar.rb",
          "P\t3\t#{root}/app/middleware/wrap.rb",
          "0\t3\tString\t40\t4\t10\t0\trequest", "1\t5\tString\t20\t4\t5\t0\trequest", "2\t0\tString\t4\t1\t4\t0\trequest",
          "A\trequest\tC#a\t2\t80\t40\t7", "A\trequest\tActionDispatch::FileHandler#serve\t2\t20\t10\t0"]
        rows << "@\trequest\tC#a\t1\t5\t3\t2\t20\t5" if run == "run2"
        rows
      end)
      report = Lowrail::ProfileReport.new(dir)
      md = report.markdown
      assert_includes md, "Static files: 4 of run 1's requests were files `ActionDispatch::Static` served before routing"
      # Objects the actions do not count (internal, inside Socket.tcp) stay out of it.
      assert_includes md, "counted as the Actions table counts them, by run: 40.0 / 40.0"
      assert_equal [4, 4], report.summary.map { _1[:static_requests] }
      # Warm per request: (40 - 10 + 20 - 5 + 4 - 4) per process over 4 requests.
      assert_includes md, "| Run | Processes | Requests | Objects per request, all | Warm |"
      assert_includes md, "| run1 | 2 | 8 | 32.5 | 11.3 |"
      by_gem = md[/## By gem.*?(?=\n## |\z)/m]
      assert_includes by_gem, "| dev/test-mode work | 3.8 |"
      refute_match(/gem: prism/, by_gem)
      assert_includes by_gem, "1 group with no warm objects (0.0 per request), only one-time work in each process's first requests: gem: bar 1.0 all objects per request"
      refute_match(/\| 0\.0 \|/, by_gem)
      assert_includes md, "`app/middleware/wrap.rb:2` (middleware) 100%"
    end
  end

  # Field test findings: an action with one warm request in a run ranked first
  # by it; a parallel capture said only at compare that it cannot be compared;
  # a line Rails 8.1 writes as a block opener missed the pull request that
  # removed it as a one-line block on main.
  def test_thin_warm_parallel_warning_and_ledger_across_versions
    realpath_tmpdir do |dir|
      gem = File.join(dir, "gems/foo-1.0/lib/foo.rb")
      FileUtils.mkdir_p(File.dirname(gem))
      File.write(gem, "def get(oid)\n  map.fetch(oid) {\n    miss(oid)\n  }\n  worker.do\n  list.collect do\n  end\n  benchmark do\n  end\n  String :do\nend\n")
      ledger = File.join(dir, "index.json")
      File.write(ledger, JSON.generate(generated: "2026-11-25T00:00:00Z", pulls: [
        { ref: "x/foo#1", repo: "x/foo", state: "merged", allocation_work: true, merged_at: "2026-11-03T00:00:00Z",
          released_in: nil, files: [{ path: "lib/foo.rb", methods: { "get" => { removed: ["map.fetch(oid) { miss(oid) }"], added: [] } } }] },
        { ref: "x/foo#2", repo: "x/foo", state: "open", allocation_work: true,
          files: [{ path: "lib/foo.rb", methods: { "get" => { removed: ["map.fetch(oid, 1) { miss(oid) }"], added: [] } } }] },
        # A byte prefix is not the same call: `worker.do` is not `worker.download`, `collect do` not `collect double`.
        { ref: "x/foo#3", repo: "x/foo", state: "open", allocation_work: true,
          files: [{ path: "lib/foo.rb", methods: { "get" => { removed: ["worker.download", "list.collect double", "benchmark download", "String :download"],
            added: ["benchmark upload", "String :upload"] } } }] }]))
      runs = File.join(dir, "capture")
      write_runs(runs, lambda do |run, pid|
        # Thin#x: 3 requests, one warm in run1 (1 + 2 windows over 2 processes).
        thin = run == "run1" ? (pid == 0 ? [1, 5000, 5000] : [2, 900_000, 1000]) : [2, 900_000, 1000]
        ["# lowrail-profile 4\trequests=7\tobjects=1000\tdropped=0\twindows=7,0,0,0\tpid=#{pid}\troot=/app\tapp_root=/app",
          "P\t0\t#{gem}", "0\t2\tString\t40\t4\t10\t0\trequest", "0\t5\tString\t30\t4\t10\t0\trequest",
          "0\t6\tString\t20\t4\t10\t0\trequest",
          "0\t8\tString\t20\t4\t10\t0\trequest", "0\t10\tString\t20\t4\t10\t0\trequest",
          "A\trequest\tBig#y\t#{run == "run1" && pid == 0 ? 4 : 5}\t5000\t100\t0", "A\trequest\tThin#x\t#{thin.join("\t")}\t0"]
      end)
      report = Lowrail::ProfileReport.new(runs, ledger: ledger)
      actions = report.actions
      assert_equal ["Big#y", "Thin#x"], actions.map { _1[:name] }
      assert_equal [[7, 8], [1, 2]], actions.map { _1[:warm_samples] }
      md = report.markdown
      assert_includes md, "fewer than 2 warm requests in a run comes last"
      assert_includes md, "* **Not comparable: run1 ran in 2 processes, run2 ran in 2 processes."
      row = md.lines.find { _1.include?("`GEM/foo/lib/foo.rb:2`") }
      assert_includes row, "x/foo#1 merged 2026-11-03, after this app's version, not released yet"
      refute_includes row, "x/foo#2"
      %w[5 6 8 10].each { |line| refute_includes md.lines.find { _1.include?("`GEM/foo/lib/foo.rb:#{line}`") }, "x/foo#3" }
      _, err, status = Open3.capture3(RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "report", runs, "--no-ledger")
      assert status.success?, err
      assert_includes err, "lowrail-profile: Not comparable: run1 ran in 2 processes"

      # Only the run that had more than one process is named.
      FileUtils.rm_rf(File.join(runs, "run1/1.tsv"))
      assert_match(/\ANot comparable: run2 ran in 2 processes\./, Lowrail::ProfileReport.new(runs).parallel_warning)
      FileUtils.rm_rf(File.join(runs, "run2/1.tsv"))
      assert_nil Lowrail::ProfileReport.new(runs).parallel_warning
    end
  end
end
