# frozen_string_literal: true

# Request benchmark + profile for a corpus app, run in-process through Rack.
#
#   cd .corpus/real-blog
#   RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 ruby --yjit \
#     /abs/lowrail/bench/requests.rb GET:/articles GET:/articles/1 ...
#
# Env: BENCH_SECONDS (default 5 per route), BENCH_PROFILE=out.json (stackprof
# raw, wall mode), BENCH_JSON=out.json (results). Not part of the app bundle:
# stackprof is put on the load path directly.
# BENCH_HEADERS is a JSON object of Rack headers, e.g.
# '{"HTTP_COOKIE":"session_token=...","HTTP_ACCEPT":"application/json"}'.
# Headers apply to every route; use separate runs for different identities.

stackprof = Gem::Specification.find_by_name("stackprof")
$LOAD_PATH.unshift(*stackprof.full_require_paths)

if ENV["BENCH_COUNT_REQUESTS"] && ENV["BENCH_JIT"] != "1"
  # Rails production enables YJIT late, even after ruby --disable-yjit.
  # Configure the real application before its finisher runs, then verify the
  # actual runtime state in the driver rather than trusting command flags.
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
end
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"

Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil

routes = ARGV.map { |spec| spec.split(":", 2) }
abort "usage: requests.rb VERB:PATH ..." if routes.empty?
seconds = Float(ENV.fetch("BENCH_SECONDS", "5"))
app = Rails.application
session = Rack::MockRequest.new(app)
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))

def call(session, verb, path, headers)
  res = session.request(verb, path, headers)
  raise "#{verb} #{path} -> #{res.status}" unless (200..299).cover?(res.status)
  res
end

if (dump = ENV["BENCH_DUMP"]) # first response body per route, for on/off diffs
  require "fileutils"
  FileUtils.mkdir_p(dump)
  routes.each do |verb, path|
    File.write(File.join(dump, "#{verb}#{path.tr("/", "_")}.html"), call(session, verb, path, headers).body)
  end
end

if ENV["BENCH_COUNT_REQUESTS"]
  n = Integer(ENV.fetch("BENCH_COUNT_REQUESTS"))
  raise "one route and nonnegative request count required" unless routes.one? && n >= 0
  verb, path = routes.first
  require ENV["BENCH_CALLGRIND_EXTENSION"] if ENV["BENCH_CALLGRIND_EXTENSION"]
  # Warm the same loop ISeq that will be measured, including under YJIT.
  def counted_requests(n, session, verb, path, headers)
    n.times { call(session, verb, path, headers) }
  end
  counted_requests(Integer(ENV.fetch("BENCH_WARMUP", "50")), session, verb, path, headers)
  GC.start
  LowrailCallgrindBench.start if defined?(LowrailCallgrindBench)
  counted_requests(n, session, verb, path, headers)
  LowrailCallgrindBench.finish if defined?(LowrailCallgrindBench)
  puts "LOWRAIL_BENCH #{JSON.generate(requests: n, ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?,
    compiled_iseqs: RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_iseq_count] : 0)}"
  exit
end

routes.each { |verb, path| Integer(ENV.fetch("BENCH_WARMUP", "200")).times { call(session, verb, path, headers) } }

# A controller drives separate, already-warm processes in short alternating
# blocks. Boot, profiles, pipe IO and explicit GC are outside every sample.
# See request_pairs.rb. The ordinary one-shot interface below is unchanged.
if ENV["BENCH_PIPE"]
  abort "pipe mode needs exactly one route" unless routes.one?
  verb, path = routes.first
  reply = ->(data) { puts "LOWRAIL_BENCH #{JSON.generate(data)}"; $stdout.flush }
  ar_installed = 0
  if defined?(Lowrail::ARInstantiate)
    ar_installed = Lowrail.manifest.units.count do |unit|
      unit["pass"] == "active_record/instantiate" &&
        Object.const_get(unit.fetch("ar_instantiate").fetch("model")).instance_variable_defined?(:@_lowrail_instantiate)
    end
  end
  reply.call(ready: true, pid: Process.pid, ruby: RUBY_DESCRIPTION,
    yjit: RubyVM::YJIT.enabled?, units: defined?(Lowrail) && Lowrail.manifest&.units&.size,
    lowrail_jit: defined?(Lowrail) && Lowrail.respond_to?(:jit_status) ? Lowrail.jit_status : nil,
    ar_installed: ar_installed)
  STDIN.each_line do |line|
    command = JSON.parse(line)
    n = Integer(command.fetch("requests"))
    raise "positive request count required" unless n.positive?
    if (mode = command["profile"])
      require "stackprof"
      # Raw every-object stacks can consume gigabytes for a few Rails
      # requests. Sample objects and retain aggregate frames, not a timeline.
      profile = StackProf.run(mode: mode.to_sym, raw: mode != "object", interval: mode == "object" ? 100 : 1000) do
        n.times { call(session, verb, path, headers) }
      end
      File.write(command.fetch("output"), JSON.generate(profile))
      reply.call(profile: mode, requests: n)
    elsif command["trace"]
      counts = Hash.new(0)
      names = Hash.new(0)
      gem_path = File.expand_path("../gem/lib/", __dir__) + "/"
      trace = TracePoint.new(:call) do |tp|
        next unless tp.path.start_with?(gem_path)
        counts["#{tp.defined_class}##{tp.method_id}"] += 1
        names[tp.binding.local_variable_get(:name)] += 1 if tp.method_id == :reset_method
      end
      trace.enable { n.times { call(session, verb, path, headers) } }
      reply.call(requests: n, calls: counts, reset_names: names)
    else
      GC.start
      alloc0 = GC.stat(:total_allocated_objects)
      cpu0 = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      wall0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      n.times { call(session, verb, path, headers) }
      wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall0
      cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu0
      alloc = GC.stat(:total_allocated_objects) - alloc0
      reply.call(requests: n, wall_us: wall * 1e6 / n, cpu_us: cpu * 1e6 / n, allocations: alloc.fdiv(n))
    end
  end
  exit
end

results = routes.map do |verb, path|
  GC.start
  n = 0
  alloc0 = GC.stat(:total_allocated_objects)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  deadline = t0 + seconds
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    call(session, verb, path, headers)
    n += 1
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
  allocs = (GC.stat(:total_allocated_objects) - alloc0) / n.to_f
  { route: "#{verb} #{path}", requests: n, rps: (n / elapsed).round(1),
    us_per_req: (elapsed / n * 1e6).round(1), allocs_per_req: allocs.round(1) }
end

results.each { |r| puts format("%-28s %8.1f req/s %9.1f us/req %8.1f allocs/req", r[:route], r[:rps], r[:us_per_req], r[:allocs_per_req]) }
puts "YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}  #{RUBY_DESCRIPTION}"

if (out = ENV["BENCH_PROFILE"])
  require "stackprof"
  profile = StackProf.run(mode: :wall, raw: true, interval: 100) do
    routes.each { |verb, path| (results.find { _1[:route] == "#{verb} #{path}" }[:requests] / seconds * 2).to_i.times { call(session, verb, path, headers) } }
  end
  File.write(out, JSON.generate(profile))
  puts "profile: #{out}"
end
File.write(ENV["BENCH_JSON"], JSON.pretty_generate(results)) if ENV["BENCH_JSON"]
