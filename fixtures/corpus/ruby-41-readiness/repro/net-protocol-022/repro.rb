# Default net-http 0.10.0 (Ruby master) needs net-protocol >= 0.3.0, but
# Bundler does not resolve unlocked default gems, so a lock with 0.2.2 wins.
require "socket"
require "net/http"
server = TCPServer.new("127.0.0.1", 0)
Thread.new { c = server.accept; c.gets; c.write "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"; c.close }
p net_http: Net::HTTP::VERSION, net_protocol: Net::Protocol::VERSION
p Net::HTTP.get(URI("http://127.0.0.1:#{server.addr[1]}/"))
