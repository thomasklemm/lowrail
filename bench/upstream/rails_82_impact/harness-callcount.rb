# ruby-bench harness (copy to ruby-bench's harness/callcount.rb), native, no
# Valgrind: WARMUP_ITRS iterations, then one iteration under a TracePoint that
# counts calls per method and, for CC_TARGETS (comma-separated method names),
# the calling file:line. Writes CC_OUT as JSON. Paths are made relative to
# CG_RAILS like cg_profile.rb does.
require_relative "../lib/harness"

WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 2))

def run_benchmark(_hint, **)
  WARMUP_ITRS.times { yield }
  root = ENV["CG_RAILS"].to_s + "/"
  targets = ENV.fetch("CC_TARGETS", "").split(",").map(&:to_sym)
  counts = Hash.new(0)
  callers = Hash.new(0)
  rel = ->(path) { path.to_s.sub(root, "RAILS/").sub(%r{\A.*/gems/}, "GEM/").sub(%r{\A.*/benchmarks/}, "BENCH/") }
  tp = TracePoint.new(:call, :c_call) do |t|
    counts["#{t.defined_class}##{t.method_id}"] += 1
    if targets.include?(t.method_id)
      loc = caller_locations(2, 1)&.first
      callers["#{t.defined_class}##{t.method_id} <- #{rel.(loc&.path)}:#{loc&.lineno} #{loc&.label}"] += 1
    end
  end
  tp.enable
  yield
  tp.disable
  require "json"
  File.write(ENV.fetch("CC_OUT"), JSON.generate(counts: counts, callers: callers) + "\n")
end
