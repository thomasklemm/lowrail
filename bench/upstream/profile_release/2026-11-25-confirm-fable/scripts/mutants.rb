# mutants.rb RUBY_VERSION [NAME_FILTER] : in the worktree /tmp/pr2/mut (60387485), undo one fix at a time and run the
# test said to cover it. "killed" means the test failed; a mutant that survives has no test.
require "open3"
ruby = `mise where ruby@#{ARGV.fetch(0)}`.strip + "/bin"
WT = ENV.fetch("WT", "/tmp/pr2/mut")
OLD_REPORT = `git -C #{WT} show 1618fc38:gem/lib/lowrail/profile_report.rb`
M = [
  ["streaming report (lib/lowrail/profile_report.rb of 1618fc38, FORMAT and run_dirs kept apart)", "gem/lib/lowrail/profile_report.rb",
    ->(s) { OLD_REPORT.sub("    KINDS = %w[request job mail cable].freeze\n", "    KINDS = %w[request job mail cable].freeze\n    FORMAT = 3\n    def self.run_dirs(dir) = Dir[\"\#{dir}/run*\"].select { File.directory?(_1) }.sort_by { _1[/\\d+\\z/].to_i }\n") },
    "profile_report_test.rb", "test_report_keeps_no_object_per_attributed_row"],
  ["RSpec trigger: any loaded RSpec::Core::Runner", "gem/lib/lowrail/profile.rb",
    ->(s) { s.sub('if caller_locations.any? { _1.path.to_s.end_with?("/rspec/core/runner.rb") }', 'if Lowrail.loaded_constant("RSpec::Core::Runner")') },
    "profile_env_test.rb", "test_a_loaded_rspec_runner_outside_rspec_keeps_the_profile"],
  ["leave_env: ENV only, not Bundler::ORIGINAL_ENV", "gem/lib/lowrail/profile.rb",
    ->(s) { s.sub("[ENV, (saved if saved.is_a?(Hash) && !saved.frozen?)].compact.each", "[ENV].each") },
    "profile_test.rb", "test_processes_the_suite_starts_run_as_without_the_profiler"],
  ["leave_env: not BUNDLER_ORIG_RUBYOPT/RUBYLIB", "gem/lib/lowrail/profile.rb",
    ->(s) { s.sub('["", "BUNDLER_ORIG_"].each do |prefix|', '[""].each do |prefix|') },
    "profile_test.rb", "test_processes_the_suite_starts_run_as_without_the_profiler"],
  ["leave_env: LOWRAIL_PROFILE_KEYS not set by the exe", "gem/exe/lowrail-profile",
    ->(s) { s.sub(/^  env\["LOWRAIL_PROFILE_KEYS"\] = .*\n/, "") },
    "profile_test.rb", "test_processes_the_suite_starts_run_as_without_the_profiler"],
  ["path gem inside the root stays an app line", "gem/lib/lowrail/profile_report.rb",
    ->(s) { s.sub(' && !path.delete_prefix(root).match?(%r{(?:\A|/)gems/})', "") },
    "profile_report_test.rb", "test_a_path_gem_inside_the_app_root_is_a_gem"],
  ["G row without File.realpath", "gem/lib/lowrail/profile.rb",
    ->(s) { s.sub("gem_dir = (File.realpath(spec.full_gem_path) rescue spec.full_gem_path)", "gem_dir = spec.full_gem_path") },
    "profile_test.rb", "test_path_gems_and_an_engine_root_are_classified"],
  ["counter built inside the app's bundle", "gem/exe/lowrail-profile",
    ->(s) { s.sub("ok = defined?(Bundler) && Bundler.respond_to?(:with_unbundled_env) ? Bundler.with_unbundled_env(&build) : build.()", "ok = build.()") },
    "profile_env_test.rb", "test_the_counter_builds_under_an_apps_bundle"],
  ["timeout: KILL only when the leader is still there after 10 s", "gem/exe/lowrail-profile",
    ->(s) { s.sub(/      grace = .*?      stop\.\("KILL"\)\n      waiter\.join\n/m, "      waiter.join(10) || (stop.(\"KILL\"); waiter.join)\n") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: no wait for the group before KILL (KILL at once)", "gem/exe/lowrail-profile",
    ->(s) { s.sub(/      sleep 0\.1 while .*\n/, "") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: the first failed run's status wins over 124", "gem/exe/lowrail-profile",
    ->(s) { s.sub("failed = timed_out.any? ? 124 : statuses.find { _1 != 0 }", "failed = statuses.find { _1 != 0 }") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: no notice in the report", "gem/lib/lowrail/profile_report.rb",
    ->(s) { s.sub("if (stopped = meta[:timed_out]).any?", "if (stopped = meta[:timed_out]).any? && false") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: HUP not passed on", "gem/exe/lowrail-profile",
    ->(s) { s.sub("%w[INT TERM HUP QUIT].to_h", "%w[INT TERM QUIT].to_h") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: QUIT not passed on", "gem/exe/lowrail-profile",
    ->(s) { s.sub("%w[INT TERM HUP QUIT].to_h", "%w[INT TERM HUP].to_h") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: traps not restored after the run", "gem/exe/lowrail-profile",
    ->(s) { s.sub("    traps.each { |signal, handler| trap(signal, handler) }\n", "") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: traps set after the spawn", "gem/exe/lowrail-profile",
    ->(s) { s.sub(/^(    traps = .*\n)(    pid = Process\.spawn.*\n)/) { $2 + $1 } },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["timeout: zombies in the group are waited for (kill 0, as at 60387485)", "gem/exe/lowrail-profile",
    ->(s) { s.sub("sleep 0.1 while running.() &&", "sleep 0.1 while (Process.kill(0, -pid) rescue false) &&") },
    "profile_env_test.rb", "test_timeout_does_not_wait_for_a_zombie"],
  ["timeout: a failing ps is believed (no kill 0 when ps exits non-zero)", "gem/exe/lowrail-profile",
    ->(s) { s.sub(/^        next \(Process\.kill\(0, -pid\) rescue false\) unless \$\?\.success\?\n/, "") },
    "profile_env_test.rb", "test_timeout_waits_out_the_grace_when_ps_fails"],
  ["timeout: ps never reports a running member (KILL at once)", "gem/exe/lowrail-profile",
    ->(s) { s.sub('g.to_i == pid && !s.to_s.start_with?("Z")', "false") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  ["the exe deletes run*/ by glob", "gem/exe/lowrail-profile",
    ->(s) { s.sub("Lowrail::ProfileReport.run_dirs(out).each { FileUtils.rm_rf(_1) } unless keep_runs", 'Dir["#{out}/run*"].each { FileUtils.rm_rf(_1) } unless keep_runs') },
    "profile_test.rb", "test_runs_are_deleted_after_the_report_unless_kept"],
  ["run dirs globbed again (report, deletion)", "gem/lib/lowrail/profile_report.rb",
    ->(s) { s.sub(/      Dir\.children\(dir\)\.grep\(\/\\Arun\\d\+\\z\/\)\.select \{ File\.directory\?\(File\.join\(dir, _1\)\) \}\n        \.sort_by \{ _1\[\/\\d\+\/\]\.to_i \}\.map \{ File\.join\(dir, _1\) \}\n/, "      Dir[\"\#{dir}/run*\"].select { File.directory?(_1) }.sort_by { _1[/\\d+\\z/].to_i }\n") },
    "profile_test.rb profile_package_test.rb profile_report_test.rb", "test_runs_are_deleted_after_the_report_unless_kept|test_out_never_clears|test_the_built_gem|test_report|test_counts_only"],
  ["compare: format 2 read as this format", "gem/lib/lowrail/profile_compare.rb",
    ->(s) { s.sub('unless meta["format"] == ProfileReport::FORMAT', 'unless [2, ProfileReport::FORMAT].include?(meta["format"])') },
    "profile_compare_test.rb", "test_compare_needs_complete_comparable_captures"],
  ["compare: two processes allowed (refuses from three)", "gem/lib/lowrail/profile_compare.rb",
    ->(s) { s.sub(/if parallel\.is_a\?\(Integer\) && parallel > 1|if parallel > 1/, "if parallel > 2") },
    "profile_compare_test.rb", "test_compare_refuses_captures_of_parallel_workers"],
  ["README: Compare step without if: always()", "gem/README-profile.md",
    ->(s) { s.sub(/^      if: always\(\) # also after a failing suite.*\n/, "") },
    "profile_compare_test.rb", "test_documented_ci_compare_step_reports_and_never_fails"],
  ["README: upload step without if: always()", "gem/README-profile.md",
    ->(s) { s.sub(/^      if: always\(\)\n/, "") },
    "profile_compare_test.rb", "test_documented_ci_compare_step_reports_and_never_fails"],
]
filter = ARGV[1] && Regexp.new(ARGV[1])
M.each do |name, file, mutate, tests, names|
  next if filter && name !~ filter
  path = File.join(WT, file)
  original = File.read(path)
  mutated = mutate.(original)
  if mutated == original
    puts "NOT APPLIED  #{name}"
    next
  end
  File.write(path, mutated)
  out, = Open3.capture2e({ "PATH" => "#{ruby}:#{ENV["PATH"]}", "RUBYLIB" => nil, "RUBYOPT" => nil }, "ruby", "-Ilib", "-Itest", "-e",
    'ARGV.select { _1.end_with?(".rb") }.each { require File.expand_path("test/#{_1}") }; ARGV.reject! { _1.end_with?(".rb") }', "--",
    *tests.split, "--seed=1729", "-n", "/#{names}/", chdir: File.join(WT, "gem"))
  File.write(path, original)
  summary = out[/^\d+ runs, .*$/] || "no summary: #{out.lines.last(2).join.strip[0, 200]}"
  killed = summary !~ / 0 failures, 0 errors/
  why = out[/^\s+\d+\) (?:Failure|Error):\n.*\n((?:.*\n){1,3})/, 1].to_s.lines.map(&:strip).join(" ")[0, 230]
  puts "#{killed ? "killed  " : "SURVIVED"}  #{name}\n          #{names}: #{summary}#{"\n          " + why unless why.empty?}"
  $stdout.flush
end
system("git", "-C", WT, "status", "--short")
