$LOAD_PATH.unshift ARGV[0] + "/lib"
require "rack"
env = Rack::MockRequest.env_for("http://example.com/rooms/1", "REMOTE_ADDR" => "127.0.0.1")
env.merge!(Hash[*ARGV[1..]]) if ARGV.size > 1
req = Rack::Request.new(env)
def allocs; GC.start; GC.disable; a = GC.stat(:total_allocated_objects); 1000.times { yield }; (GC.stat(:total_allocated_objects) - a) / 1000.0; ensure GC.enable; end
%w[scheme ssl? base_url ip host port forwarded_for].each { |m| req.public_send(m); printf "%-14s %6.1f objs  %p\n", m, allocs { req.public_send(m) }, req.public_send(m) }
