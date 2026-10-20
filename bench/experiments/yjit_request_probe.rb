# frozen_string_literal: true

# Whole-request activation diagnosis; never changes pass files or app sources.
# Select the app's locked default gems before the driver requires JSON.
require File.expand_path("config/boot", Dir.pwd) if ENV["YJIT_REQUEST_ARM"]
require_relative "../request_pairs"

if ENV["YJIT_REQUEST_ARM"]
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false unless JitStability.mode == "yjit"
  require File.expand_path("config/environment", Dir.pwd)
  require "rack/mock"
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil
  JitStability.assert_mode!
  arm = ENV.fetch("YJIT_REQUEST_ARM")
  unless arm == "original"
    runtime = Lowrail::Passes::InertiaConfig
    raise "variant not installed" unless InertiaRails::Configuration < runtime::Variant
  end
  if arm == "active_original"
    # Delete only the specimen's prepended binder. Dispatch is again EXACTLY
    # the original, while every cold activation/heap walk/hook has happened.
    runtime::Variant.send(:remove_method, :bind_controller)
  end
  headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on"}.merge(JSON.parse(ENV.fetch("BENCH_HEADERS")))
  session = Rack::MockRequest.new(Rails.application)
  request = -> {
    response = session.get("/dashboard", headers)
    raise "HTTP #{response.status}" unless response.status == 200
  }
  run = ->(n) { n.times { request.call } }
  run.call(50)
  warm = JitStability.warm { |n| run.call(n) } if JitStability.enabled?
  if ENV["YJIT_REQUEST_CENSUS"]
    calls = Hash.new(0)
    trace = TracePoint.new(:call) do |event|
      if event.method_id == :bind_controller || event.method_id == :valid?
        calls["#{event.defined_class}##{event.method_id}"] += 1
      end
    end
    trace.enable { request.call }
    puts JSON.generate(calls)
    exit
  end
  metadata = {ruby: RUBY_DESCRIPTION, arm: arm, binder_owner: InertiaRails::Configuration.instance_method(:bind_controller).owner.name,
    tracepoints: TracePoint.stat.values,
    jit_warmup: warm, **JitStability.state}
  if ENV["YJIT_REQUEST_STATS"]
    require File.expand_path("../../gem/lib/lowrail/jit_diagnostics", __dir__)
    3.times { GC.start }
    request.call
    before = RubyVM::YJIT.runtime_stats
    run.call(50)
    after = RubyVM::YJIT.runtime_stats
    metadata.merge!(before: before, after: after,
      delta: after.select { |_, v| v.is_a?(Numeric) }.to_h { |k, v| [k, v - before.fetch(k, 0)] },
      diagnostics: Lowrail::JitDiagnostics.snapshot)
    puts JSON.generate(metadata)
  else
    require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
    windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
    observer = JitStability.method(:snapshot) if JitStability.enabled?
    anchors = HeapWindows.run(windows, observe: observer, settle: request) { |n, _| run.call(n) }
    puts "LOWRAIL_BENCH #{JSON.generate(metadata.merge(windows: windows, heap_anchors: anchors, ar_installed: 0))}"
  end
  exit
end

app, build, out = ARGV.map { File.expand_path(_1) }
abort "usage: yjit_request_probe.rb APP ROOT_CONTAINING_DOT_LOWRAIL NEW_OUTDIR" unless app && build && out
raise "output must be new" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
lib = File.expand_path("../../gem/lib", __dir__)
headers = File.read(File.join(app, "tmp/m0/headers-json.json"))
env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
  "LOWRAIL_SEALED" => "1",
  "BENCH_HEADERS" => headers, "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_JIT_DIAGNOSTICS" => nil}
arms = %w[off_a off_b guarded active_original]
environments = arms.to_h do |label|
  off = label.start_with?("off_")
  [label, env.merge("YJIT_REQUEST_ARM" => off ? "original" : label, "LOWRAIL" => off ? "0" : "1",
    "LOWRAIL_ROOT" => build, "RUBYOPT" => off ? nil : "-I#{lib} -rlowrail/setup")]
end
sources = [__FILE__, *Dir[File.join(lib, "**/*.rb")], *%w[request_pairs heap_windows jit_stability].map { File.expand_path("../#{_1}.rb", __dir__) },
  File.join(build, ".lowrail/manifest.json"), File.join(app, "Gemfile.lock")].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources, diagnosis_only: true}
accepted = RequestPairs.heap_instructions(environments, app, out, "unused", metadata, worker: File.expand_path(__FILE__))
raise "source drift" unless sources.all? { |p, sha| Digest::SHA256.file(p).hexdigest == sha }
File.write(File.join(out, "verdict.json"), JSON.pretty_generate(accepted: accepted))
exit(accepted ? 0 : 2)
