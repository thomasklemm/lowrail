# ruby req.rb APP WORKLOAD N [PATCH_RB]  -- run inside the census copy (via reqrun.rb) under callgrind.
# Counts only Rails.application#call for request workloads (not the rack-test session around it),
# the whole operation for jobs and mailers.
require_relative "../../census/harness"
require ENV.fetch("REQCG")
app, wl, n, patch = ARGV
RailsCensus.boot(app)
load patch if patch && !patch.empty?
op = RailsCensus.workloads(app).find { _1.name == wl } or abort "no workload #{wl}"
request = !%i[job mailer].include?(op.kind)
$on = false
if request
  Rails.application.singleton_class.prepend(Module.new do
    def call(env)
      ReqCG.toggle if $on
      super
    ensure
      ReqCG.toggle if $on
    end
  end)
end
Integer(ENV.fetch("WARM", "200")).times { op.call.call; RailsCensus.reset_side_effects }
GC.start
GC.disable if ENV["NOGC"]
objs = GC.stat(:total_allocated_objects)
ReqCG.instr_on
$on = request
Integer(n).times { c = op.call; ReqCG.toggle unless request; c.call; ReqCG.toggle unless request; RailsCensus.reset_side_effects }
$on = false
ReqCG.dump
STDERR.puts "OBJS #{(GC.stat(:total_allocated_objects) - objs)}"
