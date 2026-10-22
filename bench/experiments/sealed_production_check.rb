# frozen_string_literal: true

# Untimed public-artifact gates. No pricing adapter, synthetic view, runtime
# materialization or weakened cold comparator is permitted in these workers.
require File.expand_path("config/boot", Dir.pwd) if ARGV.first == "worker"
require "json"
require "fileutils"
require "rbconfig"
require "digest"
require_relative "../../fixtures/corpus/blog_production"
require_relative "../../fixtures/corpus/blog_show_get_only"
require_relative "../pass"

ROOT = File.expand_path("../..", __dir__)
PASSES = %w[sealed/form_scaffold sealed/token_tag sealed/collection_render].freeze
RUNTIMES = %w[Lowrail::FormScaffold Lowrail::TokenTag Lowrail::CollectionRender].freeze
BlogProduction.send(:remove_const, :SCENARIOS)
BlogProduction.const_set(:SCENARIOS, [
  {"id" => "ArticlesControllerTest#test_should_get_index", "path" => "/articles"},
  {"id" => "ArticlesControllerTest#test_should_show_article", "path" => "/articles/1"},
  {"id" => "production_natural_repeat_show", "path" => "/articles/1"}
].freeze)

if ARGV.first == "worker"
  _, phase, destination, seed = ARGV
  BlogProduction.singleton_class.prepend(Module.new do
    def cold_features
      # Observer only: enumerate existing framework holders without resolving
      # an autoload or constructing a view. Compare the complete chains in
      # both stages, not just the three historically named delivery holders.
      framework = ObjectSpace.each_object(Module).filter_map do |holder|
        name = Module.instance_method(:name).bind_call(holder)
        next unless name&.match?(/\A(?:Action\w*|Active\w*|Rails|Rack|Zeitwerk)(?:::|\z)/)
        [name, holder.ancestors.map(&:name)]
      end.sort.to_h
      super.merge("production_seams" => %w[ActionView::Template ActionView::CollectionRenderer ActiveRecord::Associations::Preloader].to_h do |name|
        holder = Lowrail.loaded_constant(name)
        [name, holder&.ancestors&.map(&:name)]
      end, "framework_ancestry" => framework,
        "lowrail_features" => $LOADED_FEATURES.select { _1.start_with?(File.join(ROOT, "gem/lib/lowrail")) })
    end
  end)
  BlogProduction.worker(phase, destination, seed, expected_jit: JitStability.mode)
  result = JSON.parse(File.read(destination))
  result["admissions"] = RUNTIMES.to_h { |name| [name, Lowrail.loaded_constant(name).admission] }
  result["production_refusals"] = RUNTIMES.to_h { |name| [name, Lowrail.loaded_constant(name).refusal] }
  File.write(destination, JSON.pretty_generate(result))
  exit
end

app, seed_dir, output = ARGV.map { File.expand_path(_1) }
abort "usage: sealed_production_check.rb APP SEED_STORAGE NEW_OUTPUT" unless app && seed_dir && output
raise "new output outside app required" if File.exist?(output) || output.start_with?(app + "/")
BlogShowGetOnly.validate(seed_dir)
manifest_file = File.join(app, ".lowrail/manifest.json")
manifest = JSON.parse(File.read(manifest_file))
jit = manifest.fetch("certification_jit")
raise "isolated three-unit interpreter/YJIT artifact required" unless manifest.fetch("units").map { _1.fetch("pass") } == PASSES &&
  manifest.fetch("files").empty? && manifest.fetch("templates", {}).empty? && %w[interpreter yjit].include?(jit)
ids = manifest.fetch("units").to_h { [_1.fetch("pass"), _1.fetch("id").to_s] }
FileUtils.mkdir_p(output, mode: 0o700)
lib = File.join(ROOT, "gem/lib")
env = ENV.keys.grep(/\A(?:LOWRAIL_|RUBY_|BUNDLE_|DATABASE_URL\z|RAILS_|RACK_ENV\z)/).to_h { [_1, nil] }.merge(
  "RAILS_ENV" => "production", "RACK_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "SECRET_KEY_BASE" => nil,
  "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => File.join(app, ".lowrail"), "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "",
  "RUBYOPT" => "-I#{lib} -rlowrail/setup", "RAILS_LOG_LEVEL" => "fatal", "BENCH_JIT" => jit)
restore = -> {
  FileUtils.rm_rf(File.join(app, "storage"))
  FileUtils.cp_r(seed_dir, File.join(app, "storage"))
  FileUtils.rm_rf(File.join(app, "tmp"))
}
execute = ->(label, program, extra = {}) {
  File.open(File.join(output, "#{label}.log"), "w") do |log|
    raise "#{label} failed; inspect #{log.path}" unless system(env.merge(extra), RbConfig.ruby,
      *JitStability.flags(jit), *program, chdir: app, out: log, err: log)
  end
}
sequence = ->(prefix, seed = nil) {
  %w[off1 off2 on].map do |arm|
    restore.call
    label = "#{prefix}#{arm}"
    destination = File.join(output, "#{label}.json")
    extra = {"LOWRAIL" => arm == "on" ? "1" : "0"}
    extra.merge!("SECRET_KEY_BASE_DUMMY" => nil, "SECRET_KEY_BASE" => BlogProduction::Entropy::SECRET) if seed
    execute.call(label, [File.expand_path(__FILE__), "worker", "run", destination, *seed&.to_s], extra)
    record = JSON.parse(File.read(destination))
    record["exit_effects"] = BlogProduction.effects(app)
    File.write(destination, JSON.pretty_generate(record))
    record
  end
}
raw = BlogProduction.compare(sequence.call("raw-"))
companions = [0, 1].map do |seed|
  records = sequence.call("seed-#{seed}-", seed)
  report = BlogProduction.compare(records)
  report["seed"] = seed
  report["cold_equal"] = records.all? { _1.fetch("cold_witness") == records.first.fetch("cold_witness") }
  report["framework_holders_equal"] = %w[features after_requests].all? do |stage|
    records.map { _1.fetch("cold_witness").fetch(stage).fetch("framework_ancestry") }.uniq.size == 1
  end
  report["framework_holder_counts"] = %w[features after_requests].to_h do |stage|
    [stage, records.first.fetch("cold_witness").fetch(stage).fetch("framework_ancestry").size]
  end
  report["forbidden_chains_absent"] = records.all? do |record|
    !JSON.generate(record.fetch("cold_witness")).match?(/Lowrail::Templates::CompiledSource|Lowrail::PreloadPlans::Hook/)
  end
  on = records.last
  report["hits"] = on.fetch("scenarios").map { _1.fetch("hits") }
  report["fallbacks"] = on.fetch("scenarios").map { _1.fetch("fallbacks") }
  report["admissions"] = on.fetch("admissions")
  report["refusals"] = records.map { _1.fetch("production_refusals") }
  covered = PASSES.all? { |pass| on.fetch("scenarios").last.fetch("hits").fetch(ids.fetch(pass), 0).positive? }
  report["status"] = "rejected_production_coverage" unless report.fetch("cold_equal") && report.fetch("framework_holders_equal") && report.fetch("forbidden_chains_absent") &&
    covered && on.fetch("admissions").values.all? { _1.fetch("state") == "active" } &&
    report.fetch("refusals").all? { _1.values.all?(&:nil?) }
  report
end
File.write(File.join(output, "cold.json"), JSON.pretty_generate(raw: raw, companions: companions))
raise "production cold gate failed; retained" unless companions.all? { _1.fetch("status") == "equivalent_for_executed_scenarios" }

pairs = %w[none render_subscriber].to_h do |observer|
  records = %w[off on].map do |arm|
    restore.call
    label = "pairs-#{observer}-#{arm}"
    destination = File.join(output, "#{label}.json")
    execute.call(label, [File.join(__dir__, "blog_endpoint_check.rb"), "worker", destination],
      "LOWRAIL" => arm == "on" ? "1" : "0", "ENDPOINT_MUTATION" => observer,
      "LOWRAIL_FORM_CHECK" => "1", "LOWRAIL_SHADOW" => "strict",
      "SECRET_KEY_BASE_DUMMY" => nil, "SECRET_KEY_BASE" => BlogProduction::Entropy::SECRET)
    JSON.parse(File.read(destination))
  end
  off, on = records
  raise "#{observer} comparison failed" unless records.all? { _1.fetch("responses").size == 192 } &&
    off.fetch("responses") == on.fetch("responses") && off.fetch("hits").values.all?(&:zero?) &&
    PASSES.all? { on.fetch("hits").fetch(ids.fetch(_1), 0).positive? } && on.fetch("refusals").values.all?(&:nil?)
  [observer, {pairs: 192, hits: on.fetch("hits"), fallbacks: on.fetch("fallbacks")}]
end
restore.call
native = <<~'RUBY'
  require "./config/application"
  Rails.application.config.yjit = false if ENV.fetch("BENCH_JIT") == "interpreter"
  require "./config/environment"
  require "rack/mock"
  raise "native JIT mode mismatch" unless Lowrail.jit_mode == ENV.fetch("BENCH_JIT")
  request = -> { Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on") }
  runtimes = [Lowrail::FormScaffold, Lowrail::TokenTag, Lowrail::CollectionRender]
  raise "natural witness failed" unless request.call.status == 200 && runtimes.all?(&:admitted?)
  Lowrail::Stats.reset_counts!
  50.times { raise "request failed" unless request.call.status == 200 }
  units = Lowrail.manifest.units.to_h { [_1.fetch("pass"), _1.fetch("id").to_s] }
  hits = units.transform_values { Lowrail::Stats.unit_hits.fetch(_1, 0) }
  fallbacks = units.transform_values { Lowrail::Stats.unit_fallbacks.fetch(_1, 0) }
  raise "native coverage failed" unless hits == {"sealed/form_scaffold" => 50, "sealed/token_tag" => 200,
    "sealed/collection_render" => 50} && fallbacks.values.all?(&:zero?)
  before = Lowrail::Stats.unit_hits.dup
  Lowrail::Sealed::EPOCH[0] = 1
  raise "deopt request failed" unless request.call.status == 200
  raise "deopt still hit" unless Lowrail::Stats.unit_hits == before
  raise "deopt missing" unless units.values.all? { Lowrail::Stats.unit_fallbacks.fetch(_1, 0).positive? }
  binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") } or raise "native binary missing"
  puts "PRODUCTION_NATIVE #{JSON.generate(hits: hits, fallbacks: fallbacks, deopt_fallbacks: Lowrail::Stats.unit_fallbacks,
    admissions: runtimes.to_h { [_1.name, _1.admission] }, jit: Lowrail.jit_status,
    native_binary: {binary => Digest::SHA256.file(binary).hexdigest})}"
RUBY
execute.call("native", ["-e", native], "LOWRAIL" => "1")
native_report = JSON.parse(File.readlines(File.join(output, "native.log")).find { _1.start_with?("PRODUCTION_NATIVE ") }.delete_prefix("PRODUCTION_NATIVE "))
report = {status: "pass", certification_jit: jit, cold: {raw: raw, companions: companions}, pairs: pairs, native: native_report,
  fixture: {name: "BlogShowGetOnly", sha256: Digest::SHA256.file(File.join(ROOT, "fixtures/corpus/blog_show_get_only.rb")).hexdigest},
  manifest_sha256: Digest::SHA256.file(manifest_file).hexdigest, runtime_files_sha256: PassBench.runtime_fingerprint(lib),
  harness_files_sha256: PassBench.harness_fingerprint, gate_source_sha256: Digest::SHA256.file(__FILE__).hexdigest,
  provenance: {revision: `git -C #{ROOT} rev-parse HEAD`.strip, ruby: RUBY_DESCRIPTION,
    lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest, app_source_sha256: BlogProduction::Entropy.source_pin(app)}}
File.write(File.join(output, "gates.json"), JSON.pretty_generate(report))
puts JSON.generate(status: "pass", raw: raw.fetch("status"), companions: companions.map { _1.fetch("status") }, pairs: pairs,
  native: native_report.slice("hits", "fallbacks", "deopt_fallbacks"), manifest_sha256: report.fetch(:manifest_sha256))
