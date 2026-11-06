# Preload: after two warmup iterations, counts Ruby method calls (TracePoint :call) by
# owner#method inside requests whose kind matches KIND, over one iteration.
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")
def run_benchmark(_n, **)
  2.times { yield }
  re = Regexp.new(ENV.fetch("KIND"))
  counts = Hash.new(0); n = 0
  tp = TracePoint.new(:call) { |t| counts["#{t.defined_class}##{t.method_id}"] += 1 }
  Browser.prepend(Module.new do
    define_method(:request) do |path, method:, params: nil, **headers|
      verb = params&.key?(:_method) ? params[:_method].upcase : method
      kind = "#{verb} #{path.gsub(/\d+/, ':id')}"
      return super(path, method: method, params: params, **headers) unless re.match?(kind)
      n += 1
      tp.enable { super(path, method: method, params: params, **headers) }
    end
  end)
  yield
  File.binwrite(ENV.fetch("OUT"), Marshal.dump([n, counts]))
end
