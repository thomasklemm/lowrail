# Scratch harness: run WARMUP block iterations, then DUMP_PASSES passes over the
# benchmark's own request list, writing status and body of every request to
# DUMP_DIR/pass<N>/<idx>.txt. Load with -r before benchmarks/<name>/benchmark.rb.
require File.join(Dir.pwd, "lib/harness")
require "fileutils"

WARMUP = Integer(ENV.fetch("DUMP_WARMUP", "1"))
PASSES = Integer(ENV.fetch("DUMP_PASSES", "1"))
DIR = ENV.fetch("DUMP_DIR")

def dump_requests
  if defined?(RouteGenerator) && (gen = ObjectSpace.each_object(RouteGenerator).first)
    gen.routes.map { |env| [env["PATH_INFO"] + (env["QUERY_STRING"].to_s.empty? ? "" : "?#{env["QUERY_STRING"]}"), -> { gen.visit(env) }] }
  else
    # railsbench: rebuild its visiting_routes the same way
    rng = Random.new(0x1be52551fc152997)
    possible = ["/posts", "/posts.json"] + (1..100).map { |i| "/posts/#{i}" }
    Array.new(2000) { possible.sample(random: rng) }.map do |path|
      [path, -> { Rails.application.call(Rack::MockRequest.env_for("https://localhost#{path}")) }]
    end
  end
end

def run_benchmark(_hint, **, &block)
  require "digest"
  puts RUBY_DESCRIPTION
  WARMUP.times { block.call }
  reqs = dump_requests
  PASSES.times do |pass|
    dir = File.join(DIR, "pass#{pass}")
    FileUtils.mkdir_p(dir)
    index = File.open(File.join(dir, "index.tsv"), "w")
    reqs.each_with_index do |(path, call), idx|
      path = path.dup
      status, headers, body = call.call
      html = +""
      body.each { |c| html << c }
      body.close if body.respond_to?(:close)
      File.write(File.join(dir, format("%04d.txt", idx)), html)
      index.puts [idx, status, path, html.bytesize, Digest::SHA256.hexdigest(html)[0, 16]].join("\t")
    end
    index.close
  end
  puts "DUMPED #{reqs.size} requests x #{PASSES} to #{DIR}"
end
