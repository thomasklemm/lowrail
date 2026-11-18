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
# Warm-up runs the measured code path itself (toggles come in pairs, so collection stays off until instr_on);
# otherwise the toggle branch and this block first run, and compile, inside the measured window.
run = -> { c = op.call; ReqCG.toggle unless request; c.call; ReqCG.toggle unless request; RailsCensus.reset_side_effects }
$on = request
Integer(ENV.fetch("WARM", "200")).times { run.() }
jit = -> { defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats.values_at(:compiled_block_count, :invalidation_count) : [0, 0] }
# FLAT=K: keep warming in windows of N operations until one compiles and invalidates nothing, at most K windows.
settle = 0
Integer(ENV.fetch("FLAT", "0")).times do
  j = jit.()
  Integer(n).times { run.() }
  settle += 1
  break if jit.() == j
end
STDERR.puts "SETTLE #{settle}"
GC.start
GC.disable if ENV["NOGC"]
jit0 = jit.()
st0 = RubyVM::YJIT.runtime_stats if ENV["JITSTATS"]
objs = GC.stat(:total_allocated_objects)
ReqCG.instr_on
Integer(n).times { run.() }
jit1 = jit.()
$on = false
ReqCG.dump
STDERR.puts "OBJS #{(GC.stat(:total_allocated_objects) - objs)}"
if st0
  st = RubyVM::YJIT.runtime_stats
  STDERR.puts st.filter_map { |k, v| d = v - st0[k].to_i if v.is_a?(Integer) && st0[k]; "#{k}=#{d}" if d && d != 0 && k.to_s =~ /invalidat|compiled_(iseq|block)_count|exit_/ }.first(40).join(" ")
end
STDERR.puts "JIT #{jit1.zip(jit0).map { _1 - _2 }.join("/")}"
