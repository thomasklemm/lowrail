kind = ARGV[1]
n = Integer(ARGV[0])
g = case kind
when "raise" then -> { begin; raise Errno::ECONNREFUSED, "x"; rescue => e; e; end }
when "reraise" then -> { begin; begin; raise Errno::ECONNREFUSED, "x"; rescue => e; raise e, "Failed #{e.message}"; end; rescue => e2; e2; end }
when "tcp" then -> { begin; TCPSocket.open("localhost", 13714); rescue => e; e; end }
when "tcp127" then -> { begin; TCPSocket.open("127.0.0.1", 13714); rescue => e; e; end }
when "cexc" then -> { begin; File.open("/nonexistent/x"); rescue => e; e; end }
end
require "socket"
def d(k, g) = k.zero? ? g.() : d(k - 1, g)
f = -> { d(150, g) }
20.times { f.() }
n.times { f.() }
