# One warmup pass, then every request of the next pass: status, headers and body, unnormalized.
require File.join(Dir.pwd, "lib/harness")
require "fileutils"
def run_benchmark(_hint, **, &block)
  block.call
  $clock_frozen = true if defined?($clock_frozen)
  gen = ObjectSpace.each_object(RouteGenerator).first
  dir = ENV.fetch("DUMP_DIR"); FileUtils.mkdir_p(dir)
  gen.routes.each_with_index do |env, i|
    path = env["PATH_INFO"].dup
    status, headers, body = gen.visit(env)
    html = +""; body.each { html << _1 }; body.close
    File.write(File.join(dir, format("%04d", i)), "#{path}\n#{status}\n#{headers.sort.map { _1.join(': ') }.join("\n")}\n\n#{html}")
  end
  puts "RAWDUMP #{gen.routes.size}"
end
