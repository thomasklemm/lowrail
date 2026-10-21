# frozen_string_literal: true

# Native, UNTIMED research only. No Valgrind launch, timing estimate or price.
# The unchanged shared worker owns the four real request/GC endpoint windows.
require File.expand_path("config/boot", Dir.pwd) if ARGV.first == "worker"
require_relative "../pass"
require_relative "../../fixtures/corpus/blog_production"
require_relative "../../fixtures/corpus/blog_show_get_only"

module ProductionYjitDry
  ROOT = File.expand_path("../..", __dir__)
  COUNTERS = %i[compiled_iseq_count compiled_iseq_entry compiled_block_count
    compiled_blockid_count invalidation_count code_gc_count compile_time_ns].freeze
  PASSES = %w[sealed/form_scaffold sealed/token_tag sealed/collection_render].freeze

  # No new global method or default in the common harness. This process-local
  # extension is explicitly research, not an implemented v4 admission policy.
  module FixedRehearsal
    def counters(jit)
      raise "YJIT-only dry worker" unless jit == "yjit"
      ProductionYjitDry::COUNTERS
    end

    def warm(rehearsal_requests:, &workload)
      raise "N50 required" unless rehearsal_requests == 50
      rehearsal = observe_batches(50, 200, 200, 201, &workload)
      quiet = observe_batches(200, 10, 10, 10, &workload)
      missing = quiet.fetch(:history).last.fetch(:counters).reject { |_, value| value.is_a?(Integer) }.keys
      quiet.merge(method: "native-fixed-10000-plus-2000-research", rehearsal: rehearsal,
        stable: missing.empty? && quiet.fetch(:consecutive_flat_windows) == 10,
        required_flat_windows: 10, minimum_quiet_requests: 2000, max_requests: 2000,
        missing_counters: missing, window_requests: 200, adaptive_extension: false)
    end
  end

  def self.identity(pins)
    root = pins.fetch("harness_root")
    revision, status = Open3.capture2("/usr/bin/git", "-C", root, "rev-parse", "HEAD")
    changes, clean = Open3.capture2("/usr/bin/git", "-C", root, "status", "--porcelain")
    _, branch = Open3.capture2("/usr/bin/git", "-C", root, "symbolic-ref", "-q", "HEAD")
    raise "unclean, attached or changed harness" unless status.success? && clean.success? &&
      branch.exitstatus == 1 && changes.empty? && revision.strip == pins.fetch("revision")
    pins.fetch("files_sha256").each do |file, expected|
      raise "changed input: #{file}" unless Digest::SHA256.file(file).hexdigest == expected
    end
    raise "changed app source" unless BlogProduction::Entropy.source_pin(pins.fetch("app")) == pins.fetch("app_source_sha256")
    {revision: revision.strip, detached: true, clean: true, ruby: RUBY_DESCRIPTION,
      executable_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
      pins_sha256: Digest::SHA256.file(ENV.fetch("PRODUCTION_YJIT_DRY_PINS")).hexdigest}
  end
end

command = ARGV.shift
if command == "worker"
  pins = JSON.parse(File.read(ENV.fetch("PRODUCTION_YJIT_DRY_PINS")))
  puts "YJIT_DRY_PIN #{JSON.generate(ProductionYjitDry.identity(pins))}"
  $stdout.flush
  JitStability.singleton_class.prepend(ProductionYjitDry::FixedRehearsal)
  load File.join(ProductionYjitDry::ROOT, "bench/heap_requests.rb")
  states = ProductionYjitDry::PASSES.to_h do |pass|
    name = {"sealed/form_scaffold" => "Lowrail::FormScaffold", "sealed/token_tag" => "Lowrail::TokenTag",
      "sealed/collection_render" => "Lowrail::CollectionRender"}.fetch(pass)
    runtime = Lowrail.loaded_constant(name)
    [pass, {admission: runtime.admission, refusal: runtime.refusal}]
  end
  raise "dry worker did not admit production units" if ENV.fetch("LOWRAIL") == "1" &&
    states.values.any? { _1.fetch(:admission)&.fetch(:state) != "active" || _1.fetch(:refusal) }
  puts "YJIT_DRY_FINAL #{JSON.generate(ProductionYjitDry.identity(pins).merge(states: states))}"
  exit
end

app, seed, gate_path, output = ARGV.map { File.expand_path(_1) }
abort "usage: production_yjit_dry.rb native APP SEED_STORAGE GATES_JSON NEW_OUTPUT" unless
  command == "native" && ARGV.size == 4 && app && seed && gate_path && output
raise "new native output outside app required" if File.exist?(output) || output.start_with?(app + "/")
raise "fixed five published heap floors required" unless HeapWindows.floors == [1_000_000, 250_000, 100_000, 20_000, 10_000]
raise "parent must use production/YJIT" unless ENV["RAILS_ENV"] == "production" && JitStability.actual == "yjit"
root = ProductionYjitDry::ROOT
manifest_path = File.join(app, ".lowrail/manifest.json")
lib = File.join(root, "gem/lib")
manifest = PassBench.preflight(File.dirname(manifest_path), lib, root: app)
raise "isolated production YJIT artifact required" unless manifest.fetch("certification_jit") == "yjit" &&
  manifest.fetch("units").map { _1.fetch("pass") } == ProductionYjitDry::PASSES &&
  manifest.fetch("files").empty? && manifest.fetch("templates", {}).empty?
gate = JSON.parse(File.read(gate_path))
raise "passing current YJIT gates required" unless gate.fetch("status") == "pass" &&
  gate.fetch("certification_jit") == "yjit" && gate.fetch("manifest_sha256") == Digest::SHA256.file(manifest_path).hexdigest &&
  gate.fetch("runtime_files_sha256") == PassBench.runtime_fingerprint(lib) &&
  gate.fetch("harness_files_sha256") == PassBench.harness_fingerprint
BlogShowGetOnly.validate(seed)
FileUtils.mkdir_p(output, mode: 0o700)
extension = RequestPairs.compile_counter_extension(output)
files = Dir[File.join(root, "{gem/lib,bench}/**/*.{rb,c,so}")].select { File.file?(_1) }.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
[manifest_path, gate_path, extension, RbConfig.ruby, File.join(app, "Gemfile.lock")].each { files[_1] = Digest::SHA256.file(_1).hexdigest }
manifest.fetch("units").each do |unit|
  unit.fetch("data").fetch("sources").each do |file, sha|
    files[File.expand_path(file, app)] = sha
  end
end
revision = `git -C #{root} rev-parse HEAD`.strip
pins = {revision: revision, harness_root: root, app: app, files_sha256: files,
  app_source_sha256: BlogProduction::Entropy.source_pin(app), measured: false}
pins_path = File.join(output, "pins.json")
File.write(pins_path, JSON.pretty_generate(pins))
File.chmod(0o444, pins_path)
ENV["PRODUCTION_YJIT_DRY_PINS"] = pins_path
ProductionYjitDry.identity(JSON.parse(File.read(pins_path)))
env = ENV.keys.grep(/\A(?:LOWRAIL_|RUBY_|BUNDLE_|DATABASE_URL\z|RAILS_|RACK_ENV\z|BENCH_)/).to_h { [_1, nil] }.merge(
  "RAILS_ENV" => "production", "RACK_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "SECRET_KEY_BASE" => nil,
  "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => File.dirname(manifest_path), "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => nil,
  "RUBYOPT" => "-I#{lib} -rlowrail/setup", "BENCH_JIT" => "yjit", "BENCH_REQUESTS" => "50", "BENCH_WARMUP" => "50",
  "BENCH_CALLGRIND_EXTENSION" => extension, "PRODUCTION_YJIT_DRY_PINS" => pins_path)
HeapWindows.floors.each_with_index { |floor, pool| env["RUBY_GC_HEAP_#{pool}_INIT_SLOTS"] = floor.to_s }
workers = {}
%w[off_a off_b production].product([0, 1]).shuffle(random: Random.new(41231)).each do |arm, order|
  label = "#{arm}-order#{order}"
  FileUtils.rm_rf(File.join(app, "storage"))
  FileUtils.cp_r(seed, File.join(app, "storage"))
  FileUtils.rm_rf(File.join(app, "tmp"))
  log_path = File.join(output, "#{label}.log")
  compile_log = File.join(output, "#{label}.yjit.log")
  ok = system(env.merge("LOWRAIL" => arm == "production" ? "1" : "0", "BENCH_PHASE_ORDER" => order.to_s,
    "BENCH_YJIT_LOG_FILE" => compile_log), RbConfig.ruby, *JitStability.flags("yjit"), "--yjit-log=#{compile_log}",
    __FILE__, "worker", "GET:/articles/1", chdir: app, out: log_path, err: [:child, :out])
  records = File.readlines(log_path).filter_map do |line|
    prefix = line.split(" ", 2).first
    [prefix, JSON.parse(line.delete_prefix(prefix + " "))] if %w[YJIT_DRY_PIN LOWRAIL_BENCH YJIT_DRY_FINAL].include?(prefix)
  end.to_h
  workers[label] = {exitstatus: $?.exitstatus, success: ok, records: records,
    log_sha256: Digest::SHA256.file(log_path).hexdigest,
    compile_log_sha256: File.file?(compile_log) && Digest::SHA256.file(compile_log).hexdigest}
  File.write(File.join(output, "workers.json"), JSON.pretty_generate(workers))
  warn "native dry #{label}: exit #{workers.fetch(label).fetch(:exitstatus)}"
end
valid = workers.values.all? { _1.fetch(:success) && _1.fetch(:records).keys.sort == %w[LOWRAIL_BENCH YJIT_DRY_FINAL YJIT_DRY_PIN] }
observations = workers.to_h do |label, worker|
  record = worker.fetch(:records)["LOWRAIL_BENCH"]
  [label, record&.merge("jit_compile_log" => true)]
end
JitStability.singleton_class.prepend(ProductionYjitDry::FixedRehearsal)
flatness = valid ? JitStability.control(observations, requested: "yjit") : {pass: false, reason: "worker_failure"}
result = {scope: "untimed native dry only; not admission, equivalence, A/A or speed", measured: false,
  method: "native-fixed-10000-plus-2000-research", revision: revision,
  counters: ProductionYjitDry::COUNTERS + [:compile_log_bytes], retry: false, excluded: [], workers: workers,
  flatness: flatness, gate_sha256: Digest::SHA256.file(gate_path).hexdigest,
  pending_entry_admission: "unimplemented; 835cf16 remains parked; native flatness alone cannot authorize a cohort"}
File.write(File.join(output, "result.json"), JSON.pretty_generate(result))
puts JSON.generate(measured: false, flatness: flatness, pending_entry_admission: result.fetch(:pending_entry_admission))
exit(flatness.fetch(:pass) ? 0 : 2)
