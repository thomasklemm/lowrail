# trap-restore.rb EXE : after a --timeout run, is INT (TERM, HUP) the caller's again? The command leaves a FIFO as a
# run file, so the report blocks reading it; the signal must then end lowrail-profile, not be swallowed.
require "tmpdir"; require "timeout"
exe = ARGV.fetch(0)
# This shell starts commands with INT ignored, which exec keeps; lowrail-profile gets it as a terminal would give it.
trap("INT", "SYSTEM_DEFAULT")
%w[INT TERM HUP].each do |signal|
  Dir.mktmpdir do |dir|
    pid = Process.spawn(RbConfig.ruby, exe, "--timeout", "30", "--runs", "1", "--out", "o", "--", "sh", "-c", 'mkfifo "$LOWRAIL_PROFILE/1.tsv"',
      chdir: dir, err: File::NULL, out: File::NULL)
    sleep 4
    Process.kill(signal, pid)
    status = begin
      Timeout.timeout(8) { Process.wait2(pid).last }
    rescue Timeout::Error
      Process.kill("KILL", pid); Process.wait(pid); nil
    end
    puts "#{signal} during the report: #{status ? "ended (#{status.signaled? ? "signal #{status.termsig}" : "exit #{status.exitstatus}"})" : "SWALLOWED, still running after 8 s (killed)"}"
  end
end
