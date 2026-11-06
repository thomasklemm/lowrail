# Preload (ruby -I <stackprof lib> -r) in place of the harness: WARMUP iterations, then
# StackProf (cpu, raw) over ITRS iterations, dumped to PROF_OUT.
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")

def run_benchmark(_n, **)
  require "stackprof"
  Integer(ENV.fetch("WARMUP", 3)).times { yield }
  profile = StackProf.run(mode: (ENV["MODE"] || "cpu").to_sym, interval: Integer(ENV["INTERVAL"] || 500), raw: true) do
    Integer(ENV.fetch("ITRS", 5)).times { yield }
  end
  File.binwrite(ENV.fetch("PROF_OUT"), Marshal.dump(profile))
  puts "samples #{profile[:samples]}"
end
