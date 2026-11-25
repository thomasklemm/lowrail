# ruby mutants.rb [NAME...]: applies each mutant to a copy of 7a5ee0b6's gem/ and runs the tests that should kill it.
require "fileutils"
require "open3"
SRC = ENV.fetch("MUTANT_SRC", "/tmp/w-7a5ee0b6/gem") # a checkout of the gem/ under test
OUT = File.join(__dir__, "mutants")
RUBY = ENV.fetch("MUTANT_RUBY", RbConfig.ruby)
M = {
  "timeout_kill_only_if_leader_lives" => ["exe/lowrail-profile",
    /grace = .*?\n.*?\n\s*stop\.\("KILL"\)\n\s*waiter\.join\n/m, "waiter.join(10) || (stop.(\"KILL\"); waiter.join)\n",
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  "first_failure_wins_over_124" => ["exe/lowrail-profile", "failed = timed_out.any? ? 124 : statuses.find", "failed = statuses.find",
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  "no_timeout_notice" => ["lib/lowrail/profile_report.rb", "if (stopped = meta[:timed_out]).any?", "if false && (stopped = meta[:timed_out]).any?",
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  "hup_not_forwarded" => ["exe/lowrail-profile", "%w[INT TERM HUP QUIT]", "%w[INT TERM QUIT]",
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  "quit_not_forwarded" => ["exe/lowrail-profile", "%w[INT TERM HUP QUIT]", "%w[INT TERM HUP]",
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  "traps_after_spawn" => ["exe/lowrail-profile", "pending.each { stop.(_1) }", "pending.clear",
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  "delete_by_glob" => ["exe/lowrail-profile", "Lowrail::ProfileReport.run_dirs(out).each { FileUtils.rm_rf(_1) }",
    "Dir[File.join(out, \"run*\")].each { FileUtils.rm_rf(_1) if File.basename(_1).match?(/\\Arun\\d+\\z/) }",
    "profile_test.rb profile_package_test.rb", "/runs_are_deleted|package|unchanged|refuses/"],
  "report_reads_by_glob" => ["lib/lowrail/profile_report.rb", "@runs = self.class.run_dirs(dir).map", "@runs = Dir[\"\#{dir}/run*\"].select { File.directory?(_1) }.sort_by { _1[/\\d+\\z/].to_i }.map",
    "profile_test.rb profile_package_test.rb profile_report_test.rb", "/runs_are_deleted|package|report_keeps|path_gem_inside/"],
  "no_original_env" => ["lib/lowrail/profile.rb", "[ENV, (saved if saved.is_a?(Hash) && !saved.frozen?)]", "[ENV]",
    "profile_test.rb", "test_processes_the_suite_starts_run_as_without_the_profiler"],
  "no_bundler_orig_prefix" => ["lib/lowrail/profile.rb", "[\"\", \"BUNDLER_ORIG_\"].each", "[\"\"].each",
    "profile_test.rb", "test_processes_the_suite_starts_run_as_without_the_profiler"],
  "keys_not_removed" => ["lib/lowrail/profile.rb", "ours.each { env.delete(_1) }", "ours.first(2).each { env.delete(_1) }",
    "profile_test.rb", "test_processes_the_suite_starts_run_as_without_the_profiler"],
  "rspec_loaded_constant" => ["lib/lowrail/profile.rb", "if caller_locations.any? { _1.path.to_s.end_with?(\"/rspec/core/runner.rb\") }",
    "if Lowrail.loaded_constant(\"RSpec::Core::Runner\")", "profile_env_test.rb", "/./"],
  "rspec_never" => ["lib/lowrail/profile.rb", "if caller_locations.any? { _1.path.to_s.end_with?(\"/rspec/core/runner.rb\") }", "if false",
    "profile_test.rb", "test_processes_the_suite_starts_run_as_without_the_profiler"],
  "compare_any_format" => ["lib/lowrail/profile_compare.rb", "unless meta[\"format\"] == ProfileReport::FORMAT", "unless true",
    "profile_compare_test.rb", "/./"],
  "report_format_2" => ["lib/lowrail/profile_report.rb", "FORMAT = 3", "FORMAT = 2", "profile_compare_test.rb profile_test.rb", "/compare|counts_only/"],
  "gems_in_root_are_app" => ["lib/lowrail/profile_report.rb", " && !path.delete_prefix(root).match?(%r{(?:\\A|/)gems/})", "",
    "profile_report_test.rb", "/./"],
  "no_realpath_gem_dir" => ["lib/lowrail/profile.rb", "(File.realpath(spec.full_gem_path) rescue spec.full_gem_path)", "spec.full_gem_path",
    "profile_test.rb", "test_path_gems_and_an_engine_root_are_classified"],
  "build_inside_bundle" => ["exe/lowrail-profile", "Bundler.with_unbundled_env(&build) : build.()", "build.() : build.()", "profile_env_test.rb", "test_the_counter_builds_under_an_apps_bundle"],
  "zombie_waited" => ["exe/lowrail-profile", "sleep 0.1 while running.() &&", "sleep 0.1 while (Process.kill(0, -pid) rescue false) &&", "profile_env_test.rb", "test_timeout_does_not_wait_for_a_zombie"],
  "zombie_filter_dropped" => ["exe/lowrail-profile", "g.to_i == pid && !s.to_s.start_with?(\"Z\")", "g.to_i == pid", "profile_env_test.rb", "test_timeout_does_not_wait_for_a_zombie"],
  "ps_ignores_group" => ["exe/lowrail-profile", "g.to_i == pid && !s.to_s.start_with?(\"Z\")", "false", "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
  "attrib_key_collides" => ["lib/lowrail/profile_report.rb", "[loc << 31 | caller_loc]", "[loc]",
    "profile_test.rb profile_report_test.rb", "/counts_only|path_gems|report_keeps/"],
}
names = ARGV.empty? ? M.keys : ARGV
names.each do |name|
  file, from, to, tests, pattern = M.fetch(name)
  dir = File.join(OUT, name)
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(OUT)
  FileUtils.cp_r(SRC, dir)
  path = File.join(dir, file)
  src = File.read(path)
  mutated = from.is_a?(Regexp) ? src.sub(from, to) : src.sub(from, to)
  if mutated == src
    puts "#{name}: NOT APPLIED"
    next
  end
  File.write(path, mutated)
  files = tests.split
  code = 'ARGV.select { _1.end_with?(".rb") }.each { require File.expand_path("test/#{_1}") }; ARGV.reject! { _1.end_with?(".rb") }'
  out, status = Open3.capture2e({ "LOWRAIL_RAILS" => "8.1.4" }, RUBY, "-Ilib", "-Itest", "-e", code, "--", *files, "-n", pattern, "--seed=1729", chdir: dir)
  File.write(File.join(dir, "result.log"), out)
  summary = out[/^\d+ runs, .*$/]
  failed = out.scan(/^\s+\d+\) (?:Failure|Error):\n(\S+)/).flatten.uniq
  puts "#{name}: #{status.success? ? "SURVIVED" : "killed"} (#{summary}) #{failed.join(" ")}"
  $stdout.flush
end
