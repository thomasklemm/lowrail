# Cached receiver-guard micro, with statistics disabled. Not a request result.
# ruby --yjit -Igem/lib bench/guard_cost.rb
# Select an old complete runtime with -I/absolute/old/gem/lib instead.
# Optional BENCH_CALLGRIND_EXTENSION points to the extension compiled by
# request_pairs.rb; use --instr-atstart=no and its .1 client dump as usual.
require "json"
require "lowrail"
require "lowrail/manifest"
require "lowrail/guard"
class GuardProbe
  def foo = 1
end
fact = { "receiver" => "@self", "method" => "foo", "owner" => "GuardProbe", "visibility" => "public",
         "source_location" => GuardProbe.instance_method(:foo).source_location.join(":") }
manifest = Lowrail::Manifest.new({ "format" => 1, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
  "files" => {}, "units" => [{ "id" => 0, "facts" => [fact] }] }, "/tmp")
Lowrail::Guard.install(manifest)
100_000.times { Lowrail.ok?(0, GuardProbe) }
n = Integer(ENV.fetch("GUARD_REQUESTS", "1000000"))
require ENV["BENCH_CALLGRIND_EXTENSION"] if ENV["BENCH_CALLGRIND_EXTENSION"]
LowrailCallgrindBench.start if defined?(LowrailCallgrindBench)
values = 15.times.map do
  start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  n.times { Lowrail.ok?(0, GuardProbe) }
  (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - start) * 1e9 / n
end
LowrailCallgrindBench.finish if defined?(LowrailCallgrindBench)
puts JSON.generate(checks: 15 * n, cpu_ns_per_check: values, ruby: RUBY_DESCRIPTION,
  yjit: !!RubyVM::YJIT.enabled?)
