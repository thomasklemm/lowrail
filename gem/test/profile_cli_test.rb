# frozen_string_literal: true

# exe/lowrail-profile around the command it runs: the --out directory and the
# runs it keeps, the command's exit status, --timeout and the signals it
# forwards, the arguments after --, and an app tree left as it was.
#   ruby -Igem/lib -Igem/test gem/test/profile_cli_test.rb

require "test_helper"
require "digest"

class ProfileCliTest < Minitest::Test
  include LowrailTest

  PROFILE = File.join(GEM_ROOT, "exe/lowrail-profile")

  def profile_env(dir) = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")

  def profile(dir, *args, env: {}) = Open3.capture3(profile_env(dir).merge(env), RUBY, PROFILE, *args, chdir: dir)

  # --out refuses a directory it did not create, and in one it did, clears
  # only its own runs and reports.
  def test_out_never_clears_a_directory_it_did_not_create
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        File.write("ran.txt", "")
        Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
      RUBY
      FileUtils.mkdir_p(File.join(dir, "mine"))
      File.write(File.join(dir, "mine/must-keep.txt"), "x")
      out, err, status = profile(dir, "--out", "mine", "--", RUBY, "requests.rb")
      refute status.success?, out
      assert_match(/was not created by lowrail-profile/, err)
      assert File.exist?(File.join(dir, "mine/must-keep.txt"))
      refute File.exist?(File.join(dir, "ran.txt")), "the command ran"
      _, err, status = profile(dir, "--out", ".", "--", RUBY, "requests.rb")
      refute status.success?, err
      assert File.exist?(File.join(dir, "config/environment.rb"))

      _, err, status = profile(dir, "--out", "profile", "--runs", "3", "--keep-runs", "--", RUBY, "requests.rb")
      assert status.success?, err
      File.write(File.join(dir, "profile/notes.txt"), "x")
      _, err, status = profile(dir, "--out", "profile", "--keep-runs", "--", RUBY, "requests.rb")
      assert status.success?, err
      assert_equal %w[.lowrail-profile capture.json command.txt notes.txt report.json report.md run1 run2],
        Dir.children(File.join(dir, "profile")).sort
    end
  end

  # The raw counts go once the report is written (compare reads only
  # report.json), unless --keep-runs. Kept, each file path is written once
  # per process, and lowrail-profile report rebuilds the same report from them.
  def test_runs_are_deleted_after_the_report_unless_kept
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        Integer(ENV.fetch("N", "3")).times { Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets")) }
      RUBY
      _, err, status = profile(dir, "--out", "gone", "--", RUBY, "requests.rb")
      assert status.success?, err
      assert_equal %w[.lowrail-profile capture.json command.txt report.json report.md], Dir.children(File.join(dir, "gone")).sort
      _, err, status = profile(dir, "report", "gone")
      refute status.success?
      assert_match(/no runs in .*gone: they are deleted after the report unless you profile with --keep-runs/, err)

      _, err, status = profile(dir, "--out", "kept", "--keep-runs", "--", RUBY, "requests.rb")
      assert status.success?, err
      tsvs = Dir[File.join(dir, "kept/run*/*.tsv")]
      assert_equal 2, tsvs.size
      tsvs.each do |tsv|
        text = File.read(tsv)
        paths = text.lines.grep(/\AP\t/).map { _1.chomp.split("\t", 3).last }
        assert_includes paths, File.join(dir, "app/controllers/widgets_controller.rb")
        assert_equal paths.uniq, paths
        paths.each { |path| assert_equal 1, text.scan("\t#{path}\n").size, "#{path} once in #{tsv}" }
      end
      written = File.read(File.join(dir, "kept/report.json"))
      _, err, status = profile(dir, "report", "kept")
      assert status.success?, err
      assert_equal written, File.read(File.join(dir, "kept/report.json"))

      # An --out that reads as a glob names one directory: kept's runs stay, and its report is its own.
      _, err, status = profile(dir, "--out", "{kept,x}", "--", RUBY, "requests.rb", env: { "N" => "5" })
      assert status.success?, err
      assert_equal %w[run1 run2], Dir.children(File.join(dir, "kept")).grep(/\Arun/).sort
      assert_equal [5, 5], JSON.parse(File.read(File.join(dir, "{kept,x}/report.json")))["summary"].map { _1["requests"] }
    end
  end

  # The CLI exits with the command's status: the first failed run's, a
  # signal as 128 + its number, also when no report can be made or --record
  # cannot write; capture.json records the same numbers. A passing command
  # whose --record cannot write exits 1.
  def test_a_failed_command_fails_the_profile
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
        run = File.basename(ENV.fetch("LOWRAIL_PROFILE"))
        case ENV.fetch("END")
        when "exit" then exit 7
        when "signal" then Process.kill("TERM", Process.pid); sleep 5
        when "first" then exit(run == "run1" ? 3 : 4)
        end
      RUBY
      { "exit" => [7, [7, 7]], "signal" => [143, [143, 143]], "first" => [3, [3, 4]] }.each do |ending, (status, exits)|
        out, err, result = profile(dir, "--out", ending, "--", RUBY, "requests.rb", env: { "END" => ending })
        assert_equal status, result.exitstatus, "#{ending}: #{err}"
        assert_includes out, "# lowrail-profile report", "#{ending}: the report is still written"
        assert_equal exits, JSON.parse(File.read(File.join(dir, ending, "capture.json")))["exit"]
      end
      _, err, result = profile(dir, "--out", "none", "--", RUBY, "-e", "exit 5")
      assert_equal 5, result.exitstatus, err
      assert_match(/no report/, err)
      FileUtils.mkdir_p(File.join(dir, "taken.rb"))
      { "pass" => 1, "exit" => 7 }.each do |ending, status|
        _, err, result = profile(dir, "--out", "record-#{ending}", "--record", "taken.rb", "--", RUBY, "requests.rb", env: { "END" => ending })
        assert_equal status, result.exitstatus, "--record cannot write after #{ending}: #{err}"
        assert_match(/lowrail-profile: --record: .*taken\.rb/, err)
      end
    end
  end

  # --timeout stops a run that hangs (Fizzy's autoload deadlock): TERM to its
  # process group, then KILL, so a process that ignores TERM goes too, also
  # when the first one exits on TERM; no further run; exit 124, also after an
  # earlier failed run, recorded in capture.json and said at the top of the
  # report. INT, HUP and QUIT from the terminal reach the command, and a run in
  # time passes as without it. Each call has a deadline: a group that is never
  # stopped fails the test instead of hanging it.
  def test_timeout_stops_a_hung_run_and_its_processes
    realpath_tmpdir do |dir|
      # Its own group, killed at the deadline: Open3 waits for the process even after a Timeout.
      bounded = lambda do |*args, env: {}|
        out, err = File.join(dir, "bounded.out"), File.join(dir, "bounded.err")
        pid = Process.spawn(profile_env(dir).merge(env), RUBY, PROFILE, *args, chdir: dir, out: out, err: err, pgroup: true)
        waiter = Process.detach(pid)
        unless waiter.join(60)
          Process.kill("KILL", -pid) rescue nil
          flunk "lowrail-profile #{args.join(" ")} did not finish in 60 s: #{File.read(err)}"
        end
        [File.read(out), File.read(err), waiter.value]
      end
      grandchild = 'File.write("gc-#{ENV["CASE"]}.pid", spawn(RbConfig.ruby, "-e", "trap(%q(TERM)) {}; sleep 120", out: File::NULL, err: File::NULL).to_s)'
      dead = lambda do |name|
        state = `ps -o stat= -p #{File.read(File.join(dir, "gc-#{name}.pid"))}`.strip
        state.empty? || state.start_with?("Z")
      end
      { "leader-ignores" => ['trap("TERM") {}', 11..30], "leader-exits" => ["", 11..30] }.each do |name, (leader, took_range)|
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        _, err, status = bounded.("--timeout", "1", "--out", name, "--", RUBY, "-e", "#{leader}; #{grandchild}; sleep", env: { "CASE" => name })
        took = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        assert_equal 124, status.exitstatus, "#{name}: #{err}"
        assert_match(/run 1 took longer than --timeout 1.0s; stopping it/, err)
        refute_match(/run 2 of 2/, err)
        assert_includes took_range, took.floor, name
        assert_equal [[124], [1]], JSON.parse(File.read(File.join(dir, name, "capture.json"))).values_at("exit", "timed_out")
        sleep 0.2
        assert dead.(name), "#{name}: a process that ignores TERM still runs"
      end

      # Run 1 fails and run 2 hangs, or run 1 hangs after a request: 124 either way, and the report says which.
      LowrailTest.write_rails_app(dir, "late.rb" => <<~'RUBY') if LowrailTest.rails_installed?
        require_relative "config/environment"
        require "rack/mock"
        Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
        File.basename(ENV.fetch("LOWRAIL_PROFILE")) == ENV.fetch("HANG") ? sleep : exit(1)
      RUBY
      if LowrailTest.rails_installed?
        { "run2" => [[1, 124], [2]], "run1" => [[124], [1]] }.each do |hang, (exits, stopped)|
          out, err, status = bounded.("--timeout", "5", "--out", "late-#{hang}", "--", RUBY, "late.rb", env: { "HANG" => hang })
          assert_equal 124, status.exitstatus, "#{hang}: #{err}"
          assert_equal [exits, stopped], JSON.parse(File.read(File.join(dir, "late-#{hang}/capture.json"))).values_at("exit", "timed_out")
          notice = "**Incomplete: run #{stopped[0]} timed out after 5.0 s (--timeout) and was stopped"
          assert_includes out, notice, "#{hang}: report on the terminal"
          assert_includes File.read(File.join(dir, "late-#{hang}/report.md")).lines[2], notice, "#{hang}: at the top of report.md"
          assert_equal stopped, JSON.parse(File.read(File.join(dir, "late-#{hang}/report.json")))["meta"]["timed_out"]
        end
      end

      _, err, status = bounded.("--timeout", "30", "--out", "quick", "--", RUBY, "-e", "exit 3")
      assert_equal 3, status.exitstatus, err
      assert_equal [[3, 3], []], JSON.parse(File.read(File.join(dir, "quick/capture.json"))).values_at("exit", "timed_out")

      { "INT" => 130, "HUP" => 129, "QUIT" => 131 }.each do |signal, code|
        waits = "trap(#{signal.inspect}) { File.write(\"got\", #{signal.inspect}); exit #{code} }; File.write(\"ready\", \"\"); sleep"
        %w[got ready].each { FileUtils.rm_f(File.join(dir, _1)) }
        pid = Process.spawn(profile_env(dir), RUBY, PROFILE, "--timeout", "60", "--out", signal.downcase, "--", RUBY, "-e", waits,
          chdir: dir, err: File::NULL, out: File::NULL)
        sleep 0.1 until File.exist?(File.join(dir, "ready"))
        Process.kill(signal, pid)
        Process.wait(pid)
        assert_equal [code, signal], [$?.exitstatus, File.read(File.join(dir, "got"))]
        assert_equal [code], JSON.parse(File.read(File.join(dir, signal.downcase, "capture.json")))["exit"]
      end
    end
  end

  # The traps go in before the spawn, so a signal that comes before the
  # command exists is not lost and does not end lowrail-profile itself: the
  # command gets it once it runs. A spawn that is signalled first stands in
  # for a signal in that window.
  def test_timeout_forwards_a_signal_that_comes_before_the_spawn
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "early.rb"), <<~'RUBY')
        Process.singleton_class.prepend(Module.new do
          def spawn(...)
            Process.kill("HUP", Process.pid)
            sleep 1 # lowrail-profile's HUP trap runs here, before there is a command
            super
          end
        end)
      RUBY
      profile(dir, "--runs", "1", "--out", "warm", "--", RUBY, "-e", "exit") # builds the counter first
      pid = Process.spawn(profile_env(dir), RUBY, "-r./early", PROFILE, "--timeout", "60", "--runs", "1", "--out", "early", "--",
        RUBY, "-e", "sleep 20", chdir: dir, err: File.join(dir, "err"), out: File::NULL, pgroup: true)
      waiter = Process.detach(pid)
      unless waiter.join(15)
        Process.kill("KILL", -pid) rescue nil
        flunk "the command never got the HUP: #{File.read(File.join(dir, "err"))}"
      end
      assert_equal 129, waiter.value.exitstatus, File.read(File.join(dir, "err"))
      assert_equal [129], JSON.parse(File.read(File.join(dir, "early/capture.json")))["exit"]
    end
  end

  # The app tree after a profile (default --out) is the tree before, but
  # tmp/lowrail-profile: no Gemfile, config or code is written.
  def test_profiling_leaves_the_app_tree_unchanged
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      app = File.join(dir, "app")
      LowrailTest.write_rails_app(app, "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
      RUBY
      tree = -> { Dir.glob("**/*", File::FNM_DOTMATCH, base: app).reject { _1 == "tmp" || _1.start_with?("tmp/lowrail-profile") }.sort.to_h { [_1, File.file?(File.join(app, _1)) ? Digest::SHA256.file(File.join(app, _1)).hexdigest : :dir] } }
      before = tree.()
      _, err, status = Open3.capture3(profile_env(dir), RUBY, PROFILE, "--", RUBY, "requests.rb", chdir: app)
      assert status.success?, err
      assert File.file?(File.join(app, "tmp/lowrail-profile/report.json"))
      assert_equal before, tree.()
    end
  end

  # Everything after the first -- is the command's, a second -- and
  # profiler-looking flags included.
  def test_arguments_after_the_separator_belong_to_the_command
    realpath_tmpdir do |dir|
      out, err, = profile(dir, "--out", "profile", "--runs", "1", "--", RUBY, "-e", "p ARGV", "--", "--workloads", "--out", "x")
      assert_equal "[\"--workloads\", \"--out\", \"x\"]\n", out, err
      assert_match(/no report: no runs with requests/, err)
      assert_match(/controller tests and controller specs call the controller directly and are not counted/, err)
    end
  end
end
