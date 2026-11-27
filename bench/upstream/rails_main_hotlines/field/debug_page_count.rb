# Preloaded with RUBYOPT=-r (debug_page_reach.sh): counts the pages ActionDispatch::DebugView renders in a test
# suite, by the middleware that built it, and appends one line per process to $DEBUG_PAGE_COUNT_OUT at exit.
counts = Hash.new(0)
TracePoint.new(:end) do |tp|
  next unless tp.self.name == "ActionDispatch::DebugView"
  tp.self.prepend(Module.new do
    define_method(:initialize) do |assigns|
      who = caller_locations(1, 8).map(&:path).find { _1.include?("host_authorization") } ? "blocked_host" : "exception"
      counts[who] += 1
      super(assigns)
    end
  end)
  tp.disable
end.enable
pid = Process.pid
at_exit do
  File.open(ENV.fetch("DEBUG_PAGE_COUNT_OUT"), "a") do |f|
    f.puts "pid=#{Process.pid}#{' (fork)' if Process.pid != pid} exception=#{counts['exception']} blocked_host=#{counts['blocked_host']}"
  end
end
