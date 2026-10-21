# frozen_string_literal: true

# Untimed gates for the combined PRICING specimen. Reuse the cold comparator
# without dropping its ancestry, late SQL, effects, hooks or feature fields.
require File.expand_path("config/boot", Dir.pwd) if ARGV.first == "worker"
require "json"
require "fileutils"
require "rbconfig"
require "digest"

ROOT = File.expand_path("../..", __dir__)
require_relative "../../fixtures/corpus/blog_production"
require_relative "../pass"

# The comparator and workers consume the same explicitly named slice.
BlogProduction.send(:remove_const, :SCENARIOS)
BlogProduction.const_set(:SCENARIOS, [
  {"id" => "ArticlesControllerTest#test_should_get_index", "path" => "/articles"},
  {"id" => "ArticlesControllerTest#test_should_show_article", "path" => "/articles/1"},
  {"id" => "combined_natural_repeat_show", "path" => "/articles/1"}
].freeze)

if ARGV.first == "worker"
  _, phase, destination, seed = ARGV
  observer = Module.new do
    def cold_features
      super.merge("combined_seams" => %w[ActionView::Template ActiveRecord::Associations::Preloader].to_h do |name|
        holder = Lowrail.loaded_constant(name)
        [name, holder&.ancestors&.map(&:name)]
      end, "lowrail_features" => $LOADED_FEATURES.select { _1.start_with?(File.join(ROOT, "gem/lib/lowrail")) })
    end

    def capture_form_seam(view)
      super
      natural_form_seams.last["combined_methods"] = %i[render token_tag].to_h do |name|
        method = view.method(name)
        [name.to_s, {"bound_owner" => method.owner.name,
          "instance_source_location" => view.class.instance_method(name).source_location}]
      end
    end
  end
  BlogProduction.singleton_class.prepend(observer)
  BlogProduction.worker(phase, destination, seed, expected_jit: "interpreter")
  result = JSON.parse(File.read(destination))
  result.merge!("combined_counts" => SealedCombined.counts, "combined_refusal" => SealedCombined.refusal,
    "form_admission" => Lowrail::FormScaffold.admission)
  File.write(destination, JSON.pretty_generate(result))
  exit
end

app, seed_dir, output = ARGV.map { File.expand_path(_1) }
abort "usage: sealed_combined_check.rb APP SEED_STORAGE NEW_OUTPUT" unless app && seed_dir && output
raise "new output outside the app required" if File.exist?(output) || output.start_with?(app + "/")
FileUtils.mkdir_p(output, mode: 0o700)
lib = File.join(ROOT, "gem/lib")
specimen = File.join(__dir__, "sealed_combined.rb")
env = ENV.keys.grep(/\A(?:LOWRAIL_|RUBY_|BUNDLE_|DATABASE_URL\z|RAILS_|RACK_ENV\z)/).to_h { [_1, nil] }.merge(
  "RAILS_ENV" => "production", "RACK_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "SECRET_KEY_BASE" => nil,
  "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => File.join(app, ".lowrail"), "LOWRAIL_SEALED" => "1", "LOWRAIL_STATS" => "",
  "RUBYOPT" => "-I#{lib} -rlowrail/setup -r#{specimen}", "RAILS_LOG_LEVEL" => "fatal")
restore = -> {
  FileUtils.rm_rf(File.join(app, "storage"))
  FileUtils.cp_r(seed_dir, File.join(app, "storage"))
  FileUtils.rm_rf(File.join(app, "tmp"))
}
execute = ->(label, program, extra = {}) {
  File.open(File.join(output, "#{label}.log"), "w") do |log|
    raise "#{label} failed; inspect #{log.path}" unless system(env.merge(extra), RbConfig.ruby,
      "--disable-yjit", "--disable-zjit", *program, chdir: app, out: log, err: log)
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
  report["form_counts"] = records.last.fetch("scenarios").map { _1.fetch("hits").fetch("0", 0) }
  report["combined_counts"] = records.last.fetch("combined_counts")
  report["refusals"] = records.map { _1.fetch("refusals").merge("combined" => _1.fetch("combined_refusal")) }
  report["forbidden_chains_absent"] = records.all? do |record|
    witness = record.fetch("cold_witness")
    !JSON.generate(witness).match?(/Lowrail::Templates::CompiledSource|Lowrail::PreloadPlans::Hook/)
  end
  report["status"] = "rejected_combined_coverage" unless report.fetch("cold_equal") &&
    report.fetch("forbidden_chains_absent") && report.fetch("form_counts") == [0, 0, 1] &&
    %w[token collection].all? { report.fetch("combined_counts").fetch(_1, 0).positive? } &&
    report.fetch("refusals").all? { _1.values.all?(&:nil?) }
  report
end
File.write(File.join(output, "cold.json"), JSON.pretty_generate(raw: raw, companions: companions))
raise "combined cold gate failed; retained" unless companions.all? { _1.fetch("status") == "equivalent_for_executed_scenarios" }

pairs = %w[none render_subscriber].to_h do |observer|
  records = %w[off on].map do |arm|
    restore.call
    label = "pairs-#{observer}-#{arm}"
    destination = File.join(output, "#{label}.json")
    program = <<~'RUBY'
      checker, destination = ARGV
      ARGV.replace(["worker", destination])
      load checker
      record = JSON.parse(File.read(destination))
      record["combined_counts"] = SealedCombined.counts
      record["combined_refusal"] = SealedCombined.refusal
      File.write(destination, JSON.generate(record))
    RUBY
    execute.call(label, ["-e", program, File.join(__dir__, "blog_endpoint_check.rb"), destination],
      "LOWRAIL" => arm == "on" ? "1" : "0", "ENDPOINT_MUTATION" => observer,
      "LOWRAIL_FORM_CHECK" => "1", "LOWRAIL_SHADOW" => "strict",
      "SECRET_KEY_BASE_DUMMY" => nil, "SECRET_KEY_BASE" => BlogProduction::Entropy::SECRET)
    JSON.parse(File.read(destination))
  end
  off, on = records
  raise "#{observer} comparison failed" unless records.all? { _1.fetch("responses").size == 192 } &&
    off.fetch("responses") == on.fetch("responses") && off.fetch("form_hits").zero? &&
    on.fetch("form_hits").positive? && on.fetch("fallbacks").values.all?(&:zero?) &&
    on.fetch("refusals").values.all?(&:nil?) && on.fetch("combined_refusal").nil? &&
    %w[token collection].all? { on.fetch("combined_counts").fetch(_1, 0).positive? } &&
    %w[token_fallback collection_fallback].all? { on.fetch("combined_counts").fetch(_1, 0).zero? }
  [observer, {pairs: 192, form_hits: on.fetch("form_hits"), combined_counts: on.fetch("combined_counts")}]
end
restore.call
native = <<~'RUBY'
  require "./config/application"
  Rails.application.config.yjit = false
  require "./config/environment"
  require "rack/mock"
  request = -> { Rack::MockRequest.new(Rails.application).get("/articles/1", "HTTP_HOST" => "localhost", "HTTPS" => "on") }
  raise "natural witness failed" unless request.call.status == 200 && Lowrail::FormScaffold.admitted? && !SealedCombined.refusal
  SealedCombined.counts.clear
  Lowrail::Stats.reset_counts!
  50.times { raise "request failed" unless request.call.status == 200 }
  hits = {form: Lowrail::Stats.unit_hits.fetch("0", 0), token: SealedCombined.counts.fetch(:token, 0), collection: SealedCombined.counts.fetch(:collection, 0)}
  fallbacks = {form: Lowrail::Stats.unit_fallbacks.fetch("0", 0), token: SealedCombined.counts.fetch(:token_fallback, 0), collection: SealedCombined.counts.fetch(:collection_fallback, 0)}
  raise "native coverage failed" unless hits == {form: 50, token: 200, collection: 50} && fallbacks.values.all?(&:zero?)
  binary = $LOADED_FEATURES.find { _1.start_with?("#{Lowrail::NATIVE_PATH}.") } or raise "native binary missing"
  puts "COMBINED_NATIVE #{JSON.generate(hits: hits, fallbacks: fallbacks, framework_sources: SealedCombined.sources,
    untimed_witness_seconds: {form: Lowrail::FormScaffold.admission.fetch(:witness_seconds), token_collection: SealedCombined.witness_seconds},
    native_binary: {binary => Digest::SHA256.file(binary).hexdigest})}"
RUBY
execute.call("native", ["-e", native], "LOWRAIL" => "1")
native_report = JSON.parse(File.readlines(File.join(output, "native.log")).find { _1.start_with?("COMBINED_NATIVE ") }.delete_prefix("COMBINED_NATIVE "))
report = {status: "pass", cold: {status: "equivalent_for_executed_scenarios", raw: raw, companions: companions},
  pairs: pairs, native: native_report, manifest_sha256: Digest::SHA256.file(File.join(app, ".lowrail/manifest.json")).hexdigest,
  runtime_files_sha256: PassBench.runtime_fingerprint(lib), harness_files_sha256: PassBench.harness_fingerprint,
  provenance: {revision: `git -C #{ROOT} rev-parse HEAD`.strip, ruby: RUBY_DESCRIPTION,
    lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
    app_source_sha256: BlogProduction::Entropy.source_pin(app)}}
File.write(File.join(output, "gates.json"), JSON.pretty_generate(report))
puts JSON.generate(status: "pass", raw: raw.fetch("status"), companions: companions.map { _1.fetch("status") }, pairs: pairs,
  native: native_report.slice("hits", "fallbacks"), manifest_sha256: report.fetch(:manifest_sha256))
