# frozen_string_literal: true

# lowrail-profile compare on report.json files written here: the noise floor
# and its terms, the A/A pair, what is valid evidence (exit 2 otherwise), and
# the CI step README-profile.md shows. Captures that compare reads from real
# runs are in profile_test.rb.
#   ruby -Igem/lib -Igem/test gem/test/profile_compare_test.rb

require "test_helper"

class ProfileCompareTest < Minitest::Test
  include LowrailTest

  PROFILE = File.join(GEM_ROOT, "exe/lowrail-profile")

  # The summary's 10 request windows per run are the first action's (by
  # default one without a name or warm value, which compare does not compare).
  def report(warm, runs: 2, exit: [0] * runs, actions: [{ "name" => nil, "warm" => [nil] * runs }])
    actions = actions.map.with_index { |a, i| { "windows" => [i.zero? ? 10 : 0] * runs }.merge(a) }
    meta = { "format" => 2, "identity" => { "mode" => "command", "argv" => %w[bin/rails test] }, "argv" => %w[bin/rails test],
      "seed" => "1234", "exit" => exit, "runs" => runs, "ruby" => ["ruby 4"], "rails_env" => ["test"], "dropped" => [0] * runs,
      # 76be8b58's fields, so a case that must be refused is not refused only for lacking them there
      "command" => "bin/rails test", "workloads" => nil }
    { "command" => "bin/rails test", "summary" => Array.new(runs) { run_windows("request" => 10) }, "meta" => meta,
      "ranked" => [{ "site" => "GEM/x/lib/x.rb:1", "warm" => warm }], "actions" => actions,
      "outside_requests" => %w[job mail cable].to_h { [_1, { "actions" => [], "ranked" => [] }] } }
  end

  def run_windows(counts)
    windows = %w[request job mail cable].to_h { [_1, counts.fetch(_1, 0)] }
    { "processes" => 1, "objects_per_request" => 5.0, "windows" => windows, "completed" => windows }
  end

  # aa: the A/A report (by default base again, whose floor is base's own spread), or nil for none.
  def compare(dir, base, head, aa: base, args: [])
    { "base" => base, "head" => head, "aa" => aa }.each { |name, r| File.write(File.join(dir, "#{name}.json"), JSON.generate(r)) if r }
    pair = aa ? %w[--aa aa.json] : []
    out, err, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "base.json", "head.json", *pair, *args, "--json", chdir: dir)
    [status.exitstatus, (JSON.parse(out) rescue err)]
  end

  # Each term of the floor gates on its own, a move up to it passes and one
  # past it fails: an action's 20 times --min objects, its 0.1% share and
  # twice its noise (head's own spread when that is the larger), and a
  # line's --min and twice its noise.
  def test_compare_floor_terms
    realpath_tmpdir do |dir|
      gate = lambda do |base_act, head_act, line: [5.0, 5.0], args: []|
        action = ->(warm) { [{ "name" => "RoomsController#show", "warm" => warm }] }
        status, result = compare(dir, report([5.0, 5.0], actions: action.(base_act)), report(line, actions: action.(head_act)), args: args)
        [status, result["regressions"].map { [_1["what"], _1["noise_floor"].round(3)] }]
      end
      flat = ->(v) { [v, v] }
      assert_equal [0, []], gate.(flat.(1_000.0), flat.(1_019.0))
      assert_equal [0, []], gate.(flat.(1_000.0), flat.(1_020.0)), "a move equal to the floor"
      assert_equal [1, [["action", 20.0]]], gate.(flat.(1_000.0), flat.(1_021.0))
      assert_equal [0, []], gate.(flat.(100_000.0), flat.(100_099.0))
      assert_equal [1, [["action", 100.101]]], gate.(flat.(100_000.0), flat.(100_101.0))
      assert_equal [0, []], gate.(flat.(1_000.0), flat.(1_039.0), args: %w[--min 2])
      assert_equal [1, [["action", 40.0]]], gate.(flat.(1_000.0), flat.(1_041.0), args: %w[--min 2])
      assert_equal [0, []], gate.(flat.(1_000.0), [1_000.0, 1_100.0]), "head's spread of 100 floors at 200"
      assert_equal [1, [["action", 200.0]]], gate.(flat.(1_000.0), [1_250.0, 1_350.0])
      assert_equal [0, []], gate.(flat.(1_000.0), flat.(1_000.0), line: flat.(6.9), args: %w[--min 2])
      assert_equal [1, [["line", 2.0]]], gate.(flat.(1_000.0), flat.(1_000.0), line: flat.(7.1), args: %w[--min 2])
      assert_equal [0, []], gate.(flat.(1_000.0), flat.(1_000.0), line: [6.4, 7.4]), "head's spread of 1 floors a line at 2"
      assert_equal [1, [["line", 2.0]]], gate.(flat.(1_000.0), flat.(1_000.0), line: [7.6, 8.6])
    end
  end

  # The floor is measured between invocations: on Campfire a line moves little
  # inside one capture and more between two (json/common.rb:364), so an A/A
  # pair's spread passes a move of its own size and fails one beyond it. The
  # pair passes the same checks as base and head, and without one compare
  # lists what it sees but does not gate.
  def test_compare_gates_on_the_floor_of_an_a_a_pair
    realpath_tmpdir do |dir|
      action = ->(warm) { [{ "name" => "RoomsController#show", "warm" => warm }] }
      capture = ->(line, act) { report(line, actions: action.(act)) }
      base = capture.([108.0, 108.27], [20_000.0, 20_001.0])
      aa = capture.([110.9, 111.2], [20_060.0, 20_061.0])
      same = capture.([109.6, 109.9], [20_055.0, 20_056.0])
      status, result = compare(dir, base, same, aa: aa)
      assert_equal [0, true, []], [status, result["gate"], result["regressions"]], "an A/A-sized move: #{result}"

      planted = capture.([116.0, 116.3], [20_200.0, 20_201.0])
      status, result = compare(dir, base, planted, aa: aa)
      assert_equal 1, status, result.to_s
      assert_equal [["action", 200.0, 122.0], ["line", 8.015, 6.4]],
        result["regressions"].map { [_1["what"], _1["delta"].round(3), _1["noise_floor"].round(3)] }

      # The A/A pair adds to the spread inside each capture, it does not replace it.
      status, result = compare(dir, report([100.0, 104.0]), report([103.0, 103.5]), aa: report([100.0, 104.0]))
      assert_equal 0, status, result.to_s

      # Without a pair the same move is listed, as a look, and exits 0.
      status, result = compare(dir, base, same, aa: nil)
      assert_equal [0, false], [status, result["gate"]]
      assert_equal [["action", 55.0], ["line", 1.615]], result["regressions"].map { [_1["what"], _1["delta"].round(3)] }.sort
      out, _, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "base.json", "head.json", chdir: dir)
      assert_equal 0, status.exitstatus
      assert_match(/Not a gate \(exit 0\): no A\/A pair/, out)

      # An action the A/A report did not run has no floor between invocations.
      status, result = compare(dir, base, planted, aa: report([110.9, 111.2]))
      assert_equal [1, [{ "kind" => "request", "name" => "RoomsController#show", "reason" => "not run in the A/A report" }]],
        [status, result["not_compared"]]

      # The pair is evidence like base and head, and of the same capture as base.
      meta = ->(r, **change) { r.merge("meta" => r["meta"].merge(change.transform_keys(&:to_s))) }
      {
        "another command" => meta.(aa, identity: { "mode" => "command", "argv" => %w[bin/rails test -v] }),
        "another seed" => meta.(aa, seed: "99"),
        "a failing run" => meta.(aa, exit: [0, 1]),
        "no capture metadata" => {},
        "a short warm vector" => capture.([110.9], [20_060.0, 20_061.0])
      }.each do |why, bad|
        status, result = compare(dir, base, planted, aa: bad)
        assert_equal 2, status, "#{why}: #{result}"
        assert_match(/the A\/A report/, result["problems"].join, why)
      end
      status, result = compare(dir, base, planted, aa: report([110.9, 111.2, 111.0], runs: 3, actions: action.([1.0, 1.0, 1.0])))
      assert_equal 2, status, "another number of runs: #{result}"
      _, err, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "base.json", "head.json", "--aa", "missing.json", chdir: dir)
      assert_equal 2, status.exitstatus, err
      File.write(File.join(dir, "null.json"), "null")
      out, _, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "base.json", "head.json", "--aa", "null.json", "--json", chdir: dir)
      assert_equal [2, true], [status.exitstatus, JSON.parse(out)["gate"]], "a supplied A/A file that is not a report: #{out}"

      # A line the A/A report lacks adds no spread; counting it as zero would make its floor the line itself.
      status, result = compare(dir, report([100.0, 100.0]), report([130.0, 130.0]), aa: report([100.0, 100.0]).merge("ranked" => []))
      assert_equal 1, status, result.to_s
    end
  end

  # compare gates only on valid evidence (exit 2 otherwise), takes the noise
  # floor from every run, and leaves out actions one side cannot measure.
  def test_compare_needs_complete_comparable_captures
    realpath_tmpdir do |dir|
      assert_equal 2, compare(dir, {}, {})[0]
      assert_equal 2, compare(dir, report([10.0, 10.0]), {})[0]
      assert_equal 2, compare(dir, report([10.0], runs: 1), report([30.0], runs: 1))[0], "one run has no noise floor"
      assert_equal 2, compare(dir, report([10.0, 10.0], exit: [0, 1]), report([30.0, 30.0]))[0]
      assert_equal 1, compare(dir, report([10.0, 10.0]), report([30.0, 30.0]))[0]
      status, result = compare(dir, report([10.0, 1000.0, 10.0], runs: 3), report([20.0, 1010.0, 20.0], runs: 3))
      assert_equal 0, status, "a middle run's spread is noise too: #{result}"
      status, result = compare(dir, report([1.0, 1.0], actions: [{ "name" => "A#b", "warm" => [nil, nil] }]),
        report([1.0, 1.0], actions: [{ "name" => "A#b", "warm" => [100.0, 100.0] }]))
      assert_equal [0, [{ "kind" => "request", "name" => "A#b", "reason" => "no warm value" }]], [status, result["not_compared"]]

      # Incomplete reports: a missing collection, a short warm vector, no identity or seed.
      assert_equal 2, compare(dir, report([10.0, 10.0]), report([10.0, 10.0]).except("ranked"))[0], "no ranked lines is not zero"
      assert_equal 2, compare(dir, report([10.0, 10.0]), report([10.0]))[0], "one warm value for two runs"
      bare = ->(r) { r.merge("meta" => r["meta"].except("identity", "seed", "command")) }
      assert_equal 2, compare(dir, bare.(report([10.0, 10.0])), bare.(report([10.0, 10.0])))[0]
      jobs = report([10.0, 10.0]).merge("summary" => [run_windows("job" => 3)] * 2)
      status, result = compare(dir, report([10.0, 10.0]), jobs)
      assert_equal 2, status, "nothing comparable: #{result}"

      # One strict check of the shape: anything unknown, missing, duplicated or mistyped is exit 2, not 0 or a crash.
      meta = ->(r, **change) { r.merge("meta" => r["meta"].merge(change.transform_keys(&:to_s))) }
      both = ->(change) { compare(dir, change.(report([10.0, 10.0])), change.(report([10.0, 10.0])))[0] }
      assert_equal 2, both.(->(r) { meta.(r, identity: { "mode" => "command" }) }), "a command identity without arguments"
      assert_equal 2, both.(->(r) { meta.(r, identity: { "mode" => "banana" }) }), "an unknown identity mode"
      assert_equal 2, both.(->(r) { meta.(r, ruby: [nil], rails_env: [nil]) }), "no known Ruby or environment"
      assert_equal 2, both.(->(r) { r.merge("summary" => r["summary"].map { _1.merge("windows" => _1["windows"].merge("request" => "ten")) }) })
      assert_equal 2, both.(->(r) { r.merge("outside_requests" => "bad") })
      assert_equal 2, both.(->(r) { r.merge("summary" => r["summary"].map { _1.merge("completed" => _1["completed"].merge("request" => 9)) }) }),
        "a run with a window that never finished"
      keyless = ->(warm) { report([10.0, 10.0]).merge("ranked" => [{ "warm" => warm }, { "warm" => [0.0, 0.0] }]) }
      assert_equal 2, compare(dir, keyless.([10.0, 10.0]), keyless.([30.0, 30.0]))[0], "rows without a site key"
      twice = ->(r) { r.merge("ranked" => r["ranked"] * 2) }
      # Every completed window is some action's: a lost row, not only an empty list, leaves windows unaccounted for.
      two = report([10.0, 10.0], actions: [{ "name" => "A#b", "warm" => [1.0, 1.0], "windows" => [6, 6] },
        { "name" => "A#c", "warm" => [1.0, 1.0], "windows" => [4, 4] }])
      assert_equal 0, compare(dir, two, two)[0]
      status, result = compare(dir, two, two.merge("actions" => two["actions"].first(1)))
      assert_equal 2, status, "one action row lost"
      assert_match(%r{head's request actions add up to 6 / 6 windows, its summary to 10 / 10 completed}, result["problems"].join)
      assert_equal 2, both.(twice), "the same site twice"
      workloads = lambda do |measured|
        meta.(report([10.0, 10.0]), identity: { "mode" => "workloads", "host" => "localhost", "manifest" => "m", "measured" => [measured] * 2 })
      end
      complete = { "requests" => 10, "sha256" => "s", "complete" => true }
      assert_equal 0, compare(dir, workloads.(complete), workloads.(complete))[0]
      empty = ->(r) { meta.(r, identity: r["meta"]["identity"].merge("manifest" => "", "host" => "", "measured" => [complete.merge("sha256" => "")] * 2)) }
      assert_equal 2, compare(dir, empty.(workloads.(complete)), empty.(workloads.(complete)))[0], "empty identity values"
      assert_equal 2, compare(dir, workloads.(complete.merge("requests" => 9)), workloads.(complete.merge("requests" => 9)))[0],
        "fewer measured requests than request windows"
      bad = ->(r) { r.merge("summary" => r["summary"].map { _1.merge("objects_per_request" => "bad") }) }
      File.write(File.join(dir, "bad.json"), JSON.generate(bad.(report([10.0, 10.0]))))
      out, _, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "bad.json", "bad.json", chdir: dir)
      assert_equal 2, status.exitstatus, "a mistyped summary number, Markdown output: #{out}"
      [{ "requests" => 0, "sha256" => "s", "complete" => true }, complete.merge("complete" => false), complete.except("complete"),
        complete.merge("uncertified" => ["variant"])].each do |measured|
        assert_equal 2, compare(dir, workloads.(measured), workloads.(measured))[0], measured.inspect
      end
    end
  end

  # The CI step README-profile.md shows, run the way GitHub Actions runs it
  # (an explicit shell: bash adds pipefail): a regression fails the job only
  # when a second profile of head shows it too; a clean or invalid compare
  # decides at once, without profiling head again.
  def test_documented_ci_compare_step_confirms_a_regression
    require "yaml"
    realpath_tmpdir do |dir|
      yaml = File.read(File.join(GEM_ROOT, "README-profile.md"))[/```yaml\n(.*?)```/m, 1]
      step = YAML.safe_load(yaml).values.first.fetch("steps").find { _1["name"] == "Compare" }
      shell = { nil => %w[bash -e], "bash" => %w[bash --noprofile --norc -eo pipefail] }.fetch(step["shell"])
      FileUtils.mkdir_p(File.join(dir, "bin"))
      # bundle exec lowrail-profile: compare runs for real; profiling head again writes HEAD2's report.
      File.write(File.join(dir, "bin/bundle"), <<~SH)
        #!/bin/sh
        shift 2
        if [ "$1" = "--out" ]; then mkdir -p "$2" && cp "$HEAD2" "$2/report.json" && exit 0; fi
        exec #{RUBY} #{PROFILE} "$@"
      SH
      File.chmod(0o755, File.join(dir, "bin/bundle"))
      File.write(File.join(dir, "step.sh"), step.fetch("run"))
      fixture = ->(name, r) { File.join(dir, "#{name}.json").tap { File.write(_1, JSON.generate(r)) } }
      flat = ->(v) { report([v, v]) }
      run = lambda do |head, head2|
        FileUtils.rm_rf(File.join(dir, "tmp"))
        { "base" => flat.(10.0), "base2" => flat.(10.0), "head" => head }.each do |name, r|
          FileUtils.mkdir_p(File.join(dir, "tmp", name))
          File.write(File.join(dir, "tmp", name, "report.json"), JSON.generate(r))
        end
        env = CLEAN_ENV.merge("PATH" => "#{File.join(dir, "bin")}:#{ENV["PATH"]}", "GITHUB_STEP_SUMMARY" => File.join(dir, "summary.md"),
          "HEAD2" => fixture.("head2", head2))
        File.write(File.join(dir, "summary.md"), "")
        _, err, status = Open3.capture3(env, *shell, "step.sh", chdir: dir)
        [status.exitstatus, File.exist?(File.join(dir, "tmp/head2")), File.read(File.join(dir, "summary.md")), err]
      end
      status, again, summary = run.(flat.(30.0), flat.(30.0))
      assert_equal [1, true], [status, again], "a regression both profiles of head show fails the job"
      assert_equal 2, summary.scan(/Regressions: 1/).size
      status, again, = run.(flat.(30.0), flat.(10.0))
      assert_equal [0, true], [status, again], "a regression the second profile does not show passes"
      assert_equal [0, false], run.(flat.(10.0), flat.(30.0)).first(2), "a clean compare does not profile head again"
      assert_equal [2, false], run.(flat.(10.0).except("ranked"), flat.(10.0)).first(2), "invalid evidence fails at once"
    end
  end
end
