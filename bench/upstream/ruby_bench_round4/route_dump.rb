# Per request of one pass after a warmup pass: path, status, bytes, stories listed, objects allocated.
require File.join(Dir.pwd, "lib/harness")
def run_benchmark(_hint, **, &block)
  block.call
  $clock_frozen = true if defined?($clock_frozen)
  gen = ObjectSpace.each_object(RouteGenerator).first
  File.open(ENV.fetch("OUT"), "w") do |out|
    gen.routes.each do |env|
      path = env["PATH_INFO"] + (env["QUERY_STRING"].to_s.empty? ? "" : "?#{env["QUERY_STRING"]}")
      a = GC.stat(:total_allocated_objects)
      status, _, body = gen.visit(env)
      html = +""; body.each { html << _1 }; body.close
      out.puts [path, status, html.bytesize, html.scan(/<li id="story_/).size, GC.stat(:total_allocated_objects) - a].join("\t")
    end
  end
end
