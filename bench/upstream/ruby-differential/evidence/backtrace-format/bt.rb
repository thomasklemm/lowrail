GC.disable
def deep(n, &b) = n.zero? ? b.call : deep(n - 1, &b)
deep(ENV.fetch("D", 150).to_i) do
  n = ENV.fetch("N", "100").to_i
  case ENV.fetch("K", "bt")
  when "bt" then n.times { begin; raise "x"; rescue => e; e.backtrace; end }
  when "raise" then n.times { begin; raise "x"; rescue => e; end }
  when "caller" then n.times { caller }
  when "reraise" then n.times { begin; begin; raise "x"; rescue => e; raise e, "y"; end; rescue; end }
  end
end
