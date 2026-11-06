# Preload (with cg_ext on -I, under callgrind): two warmup iterations, then one iteration
# with a Callgrind dump before and after every request, labels written to LABELS.
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")
require "ruby_bench_cg"

def run_benchmark(_n, **)
  2.times { yield }
  labels = []
  Browser.prepend(Module.new do
    define_method(:request) do |path, method:, params: nil, **headers|
      verb = params&.key?(:_method) ? params[:_method].upcase : method
      shape = path.gsub(/\d+/, ":id")
      RubyBenchCG.dump
      gc = GC.count
      result = super(path, method: method, params: params, **headers)
      gc = GC.count - gc
      RubyBenchCG.dump
      labels << "#{verb} #{shape} #{result[0]} #{gc}"
      result
    end
  end)
  GC.start
  GC.disable # mutator only: lazy sweeping and incremental marking would land in arbitrary requests
  RubyBenchCG.dump
  yield
  RubyBenchCG.dump
  GC.enable
  File.write(ENV.fetch("LABELS"), labels.join("\n") + "\n")
end
