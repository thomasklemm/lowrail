# Preload: after two warmup iterations, logs every SQL statement per request kind in one iteration.
require File.join(ENV.fetch("RUBY_BENCH_DIR"), "lib/harness")
def run_benchmark(_n, **)
  2.times { yield }
  $kind = nil
  log = Hash.new { |h, k| h[k] = Hash.new(0) }
  reqs = Hash.new(0)
  ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    sql = payload[:sql].gsub(/\d+/, "N").gsub(/'[^']*'/, "'S'")[0, 110]
    log[$kind][sql] += 1 if $kind
  end
  Browser.prepend(Module.new do
    define_method(:request) do |path, method:, params: nil, **headers|
      verb = params&.key?(:_method) ? params[:_method].upcase : method
      $kind = "#{verb} #{path.gsub(/\d+/, ':id')}"
      reqs[$kind] += 1
      super(path, method: method, params: params, **headers).tap { $kind = nil }
    end
  end)
  yield
  File.open(ENV.fetch("OUT"), "w") do |f|
    log.sort.each do |kind, h|
      f.puts "## #{kind} (#{reqs[kind]} req, #{h.values.sum} statements, #{(h.values.sum.to_f / reqs[kind]).round(2)}/req)"
      h.sort_by { -_2 }.each { |sql, n| f.puts format("%6.2f  %s", n.to_f / reqs[kind], sql) }
    end
  end
end
