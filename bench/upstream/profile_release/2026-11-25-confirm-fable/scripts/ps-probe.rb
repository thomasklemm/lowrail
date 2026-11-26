# ps-probe.rb EXE : --timeout's 10 s for the group (53a071fd asks `ps -A -o pgid= -o stat=` who still runs). A command
# that needs 3 s after TERM to finish (as a suite that writes its counts at exit): does it get them, with ps as
# installed, with a ps that fails and prints nothing, and with no ps on PATH?
require "tmpdir"; require "fileutils"
exe = ARGV.fetch(0)
child = 'trap("TERM") { sleep 3; File.write("clean", ""); exit 0 }; sleep'
{ "ps as installed" => nil, "a ps that exits 1 and prints nothing" => "#!/bin/sh\nexit 1\n", "no ps on PATH" => :none }.each do |name, ps|
  Dir.mktmpdir do |dir|
    bin = File.join(dir, "bin"); FileUtils.mkdir_p(bin)
    path = ENV["PATH"]
    if ps == :none then path = bin
    elsif ps then File.write(File.join(bin, "ps"), ps); File.chmod(0o755, File.join(bin, "ps")); path = "#{bin}:#{path}"
    end
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    pid = Process.spawn({ "PATH" => path }, RbConfig.ruby, exe, "--timeout", "1", "--runs", "1", "--out", "o", "--", RbConfig.ruby, "-e", child,
      chdir: dir, out: File::NULL, err: File.join(dir, "err"))
    Process.wait(pid)
    took = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    puts "#{name}: exit #{$?.exitstatus} after #{took.round(1)} s; the command #{File.exist?(File.join(dir, "clean")) ? "finished its TERM handler" : "was KILLed before its TERM handler finished"}"
  end
end
