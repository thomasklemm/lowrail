# mutants-delta.rb RUBY_VERSION : in the worktree /tmp/pr2/mutd (644c99e4), undo one change of 0ee4aed2..644c99e4 at a
# time and run the test said to cover it. "killed" means the test failed.
require "open3"
ruby = `mise where ruby@#{ARGV.fetch(0)}`.strip + "/bin"
WT = "/tmp/pr2/mutd"
M = [
  ["classify: every path with a gems/ segment leaves the app (as at 0ee4aed2)", "gem/lib/lowrail/profile_report.rb",
    ->(s) { s.sub(' && !(path.delete_prefix(root).match?(%r{(?:\A|/)gems/}) && path_gems.any? { |_, d| path.start_with?(d) })', ' && !path.delete_prefix(root).match?(%r{(?:\A|/)gems/})') },
    "profile_report_test.rb", "test_a_path_gem_inside_the_app_root_is_a_gem"],
  ["classify: a path gem inside the root stays an app line (as at 1618fc38)", "gem/lib/lowrail/profile_report.rb",
    ->(s) { s.sub(' && !(path.delete_prefix(root).match?(%r{(?:\A|/)gems/}) && path_gems.any? { |_, d| path.start_with?(d) })', "") },
    "profile_report_test.rb", "test_a_path_gem_inside_the_app_root_is_a_gem"],
  ["classify: any path gem inside the root leaves the app, gems/ or not", "gem/lib/lowrail/profile_report.rb",
    ->(s) { s.sub('!(path.delete_prefix(root).match?(%r{(?:\A|/)gems/}) && path_gems.any? { |_, d| path.start_with?(d) })', '!path_gems.any? { |_, d| path.start_with?(d) }') },
    "profile_report_test.rb profile_test.rb", "test_a_path_gem_inside_the_app_root_is_a_gem|test_path_gems_and_an_engine_root_are_classified"],
  ["timeout: traps not restored after the run", "gem/exe/lowrail-profile",
    ->(s) { s.sub("    traps.each { |signal, handler| trap(signal, handler) }\n", "") },
    "profile_env_test.rb", "test_signals_end_the_report_after_a_timeout_run"],
  ["timeout: only INT restored after the run", "gem/exe/lowrail-profile",
    ->(s) { s.sub("    traps.each { |signal, handler| trap(signal, handler) }\n", "    trap(\"INT\", traps.fetch(\"INT\"))\n") },
    "profile_env_test.rb", "test_signals_end_the_report_after_a_timeout_run"],
  ["timeout: a failing ps's stderr reaches the terminal (backticks, as at 0ee4aed2)", "gem/exe/lowrail-profile",
    ->(s) { s.sub('list = IO.popen(%w[ps -A -o pgid= -o stat=], err: File::NULL, &:read)', 'list = `ps -A -o pgid= -o stat=`') },
    "profile_env_test.rb", "test_timeout_waits_out_the_grace_when_ps_fails"],
  ["timeout: a failing ps is believed (no kill 0 when ps exits non-zero)", "gem/exe/lowrail-profile",
    ->(s) { s.sub(/^        next \(Process\.kill\(0, -pid\) rescue false\) unless \$\?\.success\?\n/, "") },
    "profile_env_test.rb", "test_timeout_waits_out_the_grace_when_ps_fails"],
  ["timeout: zombies in the group are waited for (kill 0 only)", "gem/exe/lowrail-profile",
    ->(s) { s.sub("sleep 0.1 while running.() &&", "sleep 0.1 while (Process.kill(0, -pid) rescue false) &&") },
    "profile_env_test.rb", "test_timeout_does_not_wait_for_a_zombie"],
  ["timeout: ps never reports a running member (KILL at once)", "gem/exe/lowrail-profile",
    ->(s) { s.sub('g.to_i == pid && !s.to_s.start_with?("Z")', "false") },
    "profile_test.rb", "test_timeout_stops_a_hung_run_and_its_processes"],
]
M.each do |name, file, mutate, tests, names|
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
