# frozen_string_literal: true

# real-blog route construction microbenchmark, including controller
# url_options and AR to_param, excluding the call-site guard. Run inside the
# corpus app: RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 ruby --yjit
# ../../bench/routes.rb. BENCH_JSON optionally saves the samples/summary.
require File.expand_path("config/environment", Dir.pwd)
require_relative "../gem/lib/lowrail/routes"
require "json"

req = ActionDispatch::Request.new(Rack::MockRequest.env_for("https://a.example.org:8443/articles/17",
  "action_dispatch.routes" => Rails.application.routes))
c = ArticlesController.new
c.set_request!(req)
c.set_response!(ArticlesController.make_response!(req))
article = Article.new(id: 17, title: "Route benchmark", body: "Disposable")

class << c
  def rails_url(a) = article_url(a)

  def lowered_url(a, memoize)
    if !(Hash === a || ActionController::Parameters === a) && optimize_routes_generation? &&
       (o = url_options.merge(Rails.application.routes.named_routes.get(:article).defaults)) &&
       String === (p = a.to_param) && !p.empty?
      Lowrail::Routes.finish(+"" << "/articles/" << Lowrail::Routes.seg(p), o, self, true, memoize)
    else
      article_url(a)
    end
  end
end

calls = { rails: -> { c.rails_url(article) }, lowered: -> { c.lowered_url(article, false) },
          host_cache: -> { c.lowered_url(article, true) } }
raise "different URLs" unless calls.values.map(&:call).uniq.one?
n = Integer(ENV.fetch("BENCH_N", "200000"))
calls.each_value { |call| 20_000.times { call.call } }
samples = Hash.new { |h, k| h[k] = [] }
7.times do |round|
  (round.even? ? calls.to_a : calls.to_a.reverse).each do |name, call|
    GC.start
    a = GC.stat(:total_allocated_objects)
    t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    n.times { call.call }
    samples[name] << { ns: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e9 / n,
                       allocs: (GC.stat(:total_allocated_objects) - a).to_f / n }
  end
end
summary = samples.transform_values do |rows|
  times = rows.map { _1[:ns] }.sort
  { median_ns: times[3].round, min_ns: times.first.round, max_ns: times.last.round,
    allocs: rows.map { _1[:allocs] }.sort[3].round(2) }
end
result = { ruby: RUBY_DESCRIPTION, rails: Rails.version, yjit: RubyVM::YJIT.enabled?,
           iterations: n, samples: samples, summary: summary }
puts JSON.pretty_generate(summary)
File.write(ENV["BENCH_JSON"], JSON.pretty_generate(result)) if ENV["BENCH_JSON"]
