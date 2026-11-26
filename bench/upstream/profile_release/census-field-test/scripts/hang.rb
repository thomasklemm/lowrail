# RUBYOPT=-r this, FT_HANG=1: in run 2 (the attribution run) the first forked test worker stops itself (SIGSTOP)
# 3 s after it starts, so the suite's parent waits on it forever: a hung worker that also ignores TERM until killed.
if ENV["FT_HANG"] == "1" && ENV["LOWRAIL_PROFILE_ATTRIBUTE"] == "1"
  Process.singleton_class.prepend(Module.new do
    def _fork
      pid = super
      if pid.zero? && !$ft_hang_done
        $ft_hang_done = true
        File.write(ENV.fetch("FT_HANG_MARK"), "#{Process.pid}\n")
        Thread.new { sleep 3; Process.kill("STOP", Process.pid) }
      end
      $ft_hang_done = true
      pid
    end
  end)
end
