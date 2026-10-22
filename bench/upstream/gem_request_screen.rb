# frozen_string_literal: true

# P's request counter/heap/audit machinery, without a Lowrail artifact or hits:
# these arms replace a gem source file, not a Lowrail specialization.
require "json"
require "fileutils"
require_relative "../request_pairs"
require_relative "../window_audit"
require_relative "gem_census"

if ENV["GEM_SCREEN_CONFIG"]
  config = JSON.parse(File.read(ENV.fetch("GEM_SCREEN_CONFIG")))
  policy = JSON.parse(File.read(File.join(GemCensus::ROOT, "fixtures/corpus/blog-entropy-controls.json")))
  require_relative "../../fixtures/corpus/blog_entropy"
  ENV["SECRET_KEY_BASE"] = BlogProduction::Entropy::SECRET
  ScreenClock.install(policy.fetch("wall_clock").fetch("epoch"))
  source = ENV.fetch("GEM_SCREEN_SOURCE")
  if config["kind"] == "sqlite"
    $LOAD_PATH.unshift(source)
    require "sqlite3"
    extension = $LOADED_FEATURES.find { _1.end_with?("sqlite3_native.so") }
    raise "wrong native extension" unless File.realpath(extension).start_with?(File.realpath(source) + "/") &&
      Digest::SHA256.file(extension).hexdigest == Digest::SHA256.file(File.join(source, "sqlite3/sqlite3_native.so")).hexdigest
  end
  GemCensus.boot("blog")
  load source unless config["kind"] == "sqlite"
  # WindowAudit uses only loaded_constant; do not call setup/initialize!.
  require_relative "../../gem/lib/lowrail"
  ActiveRecord::ConnectionAdapters::ConnectionPool.prepend(WindowAudit::Reaper)
  audit = WindowAudit.new(cache: Rails.cache)
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  control = BlogProduction::Entropy.validate(Dir.pwd)
  raise control.fetch("reason") unless control.fetch("active")
  BlogProduction::Entropy.install(control.fetch("policy"))
  rack, headers, = GemCensus.workload("blog")
  headers["HTTP_X_REQUEST_ID"] = "gem-census"
  path = config.fetch("path")
  request = -> { rack.get(path, headers) }
  workload = ->(n, _) { n.times { raise "HTTP request failed" unless request.call.status == 200 } }
  100.times { workload.call(1, nil) }
  exact = -> {
    {path => [0, 1].to_h do |seed|
      response, evidence = BlogProduction::Entropy.with(seed, path, wall_clock: true, &request)
      [seed.to_s, {"status" => response.status, "body_sha256" => Digest::SHA256.hexdigest(response.body),
        "headers_sha256" => Digest::SHA256.hexdigest(JSON.generate(response.headers.to_h.sort.to_h)),
        "evidence" => {"passed" => evidence.fetch("errors").empty?, "entropy" => evidence}}]
    end}
  }
  before = exact.call
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")), [path])
  anchors = audit.with_reapers_deferred do
    HeapWindows.run(windows, audit: audit, settle: -> { workload.call(1, nil) }, &workload)
  end
  after = exact.call
  audit.close
  puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION, rails: Rails.version,
    windows: windows, heap_anchors: anchors, heap_page_targets: HeapWindows.page_targets, operations: true,
    jit_warmup: nil, exact: before, exact_after: after, refusal: nil,
    source_sha256: Digest::SHA256.file(extension || source).hexdigest,
    sqlite: config["kind"] == "sqlite" ? {gem: SQLite3::VERSION, runtime: SQLite3::SQLITE_VERSION, extension: extension} : nil)}"
else
  require_relative "../screen"
  input, output, option = ARGV
  raise "only --budget is supported" unless option.nil? || option == "--budget"
  config = JSON.parse(File.read(input))
  raise "new output required" if File.exist?(output)
  raise "interpreter serial screen required" unless JitStability.actual == "interpreter" && ENV.fetch("BENCH_JOBS") == "1"
  FileUtils.mkdir_p(output)
  output = File.expand_path(output)
  config_file = File.join(output, "config.json")
  File.write(config_file, JSON.pretty_generate(config))
  files = Dir[File.join(config.fetch("app"), "{app,config,db,lib}/**/*")]
  files += Dir[File.join(__dir__, "*.rb"), File.expand_path("../*.rb", __dir__)]
  files += [config.fetch("before"), config.fetch("after"), config_file, RbConfig.ruby,
    File.join(config.fetch("app"), "Gemfile.lock"), File.join(GemCensus::ROOT, "fixtures/corpus/blog-entropy-controls.json")]
  if config["kind"] == "sqlite"
    files += %w[before after].flat_map { Dir[File.join(config.fetch(_1), "**/*")] }
  end
  pins = files.select { File.file?(_1) }.uniq.sort.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
  File.write(File.join(output, "protocol.json"), JSON.pretty_generate(config: config, pins: pins,
    rounds: 6, seed: 41231, requests: 10, warmup: 100, aa_tolerance_pct: 0.1,
    zero_containment: false, retry: false, budget_only: option == "--budget"))
  env = {"GEM_SCREEN_CONFIG" => config_file, "BUNDLE_GEMFILE" => File.join(config.fetch("app"), "Gemfile"),
    "BUNDLE_FROZEN" => "true", "RUBYOPT" => "-rbundler/setup", "CENSUS_CANDIDATE" => nil,
    "CENSUS_MODE" => "interpreter", "RUBY_YJIT_ENABLE" => "0", "RUBY_ZJIT_ENABLE" => "0"}
  arms = %w[off_a off_b on].to_h do |arm|
    [arm, env.merge("GEM_SCREEN_SOURCE" => config.fetch(arm == "on" ? "after" : "before"))]
  end
  if option == "--budget"
    extension = RequestPairs.compile_counter_extension(output)
    floors = HeapWindows.floors.each_with_index.to_h { |n, i| ["RUBY_GC_HEAP_#{i}_INIT_SLOTS", n.to_s] }
    workers = arms.to_h do |arm, settings|
      log = File.join(output, "#{arm}.log")
      ok = system(settings.merge(floors).merge("BENCH_CALLGRIND_EXTENSION" => extension, "BENCH_REQUESTS" => "10"),
        "valgrind", "--tool=none", RbConfig.ruby, *JitStability.flags("0"), File.expand_path(__FILE__),
        chdir: config.fetch("app"), out: log, err: [:child, :out])
      raise "untimed budget failed: #{arm}" unless ok
      line = File.foreach(log).find { _1.start_with?("LOWRAIL_BENCH ") }
      ["budget-#{arm}", JSON.parse(line.delete_prefix("LOWRAIL_BENCH "))]
    end
    File.write(File.join(output, "budget.json"), JSON.pretty_generate(
      exact: ScreenPlatform.exact_report(workers), background: ScreenPlatform.background(workers), workers: workers))
    exit
  end
  metadata = {seed: 41231, rounds: 6, workers: {}}
  pass = RequestPairs.heap_instructions(arms, config.fetch("app"), output, config.fetch("path"), metadata,
    worker: File.expand_path(__FILE__), requests: 10, aa_tolerance: 0.1, aa_zero_containment: false)
  data = JSON.parse(File.read(File.join(output, "samples.json")))
  workers = data.fetch("workers")
  exact = ScreenPlatform.exact_report(workers)
  background = ScreenPlatform.background(workers)
  rows = data.fetch("samples").map do |round|
    round.to_h do |arm, metrics|
      full, empty = metrics.fetch("windows").select { _1.fetch("mode") == "total" }.sort_by { -_1.fetch("requests") }
      allocated = ->(window) { window.fetch("after").fetch("total_allocated_objects") - window.fetch("before").fetch("total_allocated_objects") }
      [arm, metrics.fetch("operations").fetch(config.fetch("path")).merge(
        "allocations" => (allocated.call(full) - allocated.call(empty)).fdiv(10))]
    end
  end
  unchanged = pins.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
  File.write(File.join(output, "result.json"), JSON.pretty_generate(counter_pass: pass, exact: exact,
    background: background, summary: ScreenPlatform.summarize(rows), source_unchanged: unchanged,
    accepted: pass && exact.fetch(:passed) && background.fetch(:pass) && unchanged))
end
