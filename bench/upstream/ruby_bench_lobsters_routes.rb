require_relative "../lib/harness"

# Local ruby-bench harness for lobsters: one pass over the benchmark's route
# list, printing per route pattern the request count, the mean body size and
# the stories rendered per request (`<li id="story_`). Copy into harness/ and
# run with HARNESS=ruby_bench_lobsters_routes ruby benchmarks/lobsters/benchmark.rb.
def run_benchmark(_num_itrs_hint, **)
  gen = ObjectSpace.each_object(RouteGenerator).first
  agg = Hash.new { |h, k| h[k] = [0, 0, 0] }
  gen.routes.each do |env|
    query = env["QUERY_STRING"].to_s
    key = env["PATH_INFO"].gsub(%r{/(s|u|threads|comments)/[^/]+}, '/\1/:id') + (query.empty? ? "" : "?#{query}")
    _status, _headers, body = gen.visit(env)
    html = +""
    body.each { |chunk| html << chunk }
    body.close if body.respond_to?(:close)
    row = agg[key]
    row[0] += 1
    row[1] += html.bytesize
    row[2] += html.scan(/<li id="story_/).size
  end
  agg.sort.each do |key, (n, bytes, stories)|
    puts format("%-24s n=%3d  bytes/req=%7d  stories/req=%5.1f", key, n, bytes / n, stories.fdiv(n))
  end
end
