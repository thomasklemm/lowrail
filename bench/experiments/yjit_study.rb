# frozen_string_literal: true

# Published ceiling specimens, unchanged. Shares lowrail bench's counter,
# controls, activation probes and fingerprints; no production pass is added.
require_relative "../pass"

root = File.expand_path("../..", __dir__)
app = File.expand_path(ENV.fetch("BENCH_APP", File.join(root, ".corpus/real-blog-r4")))
out = File.expand_path(ARGV.fetch(0))
raise "new output directory required" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
historical = File.expand_path(ENV["BENCH_HISTORICAL_ROOT"]) if ENV["BENCH_HISTORICAL_ROOT"]
lib = File.join(historical || root, "gem/lib")
# Only this explicitly historical experiment may load the quarantined runtime.
# Rebuild its ISeqs for this VM; never make current Lowrail admit old artifacts.
if historical
  expected = Open3.capture2("git", "-C", root, "ls-tree", "-r", "--name-only", "c9d2397", "gem/lib").first.lines.map(&:strip).to_h do |path|
    bytes, status = Open3.capture2("git", "-C", root, "show", "c9d2397:#{path}")
    raise "cannot read historical runtime" unless status.success?
    [path.delete_prefix("gem/lib/"), Digest::SHA256.hexdigest(bytes)]
  end
  raise "historical runtime must be exactly c9d2397" unless PassBench.runtime_fingerprint(lib) == expected
end
preflight = -> {
  if historical
    text, error, status = Open3.capture3({ "RUBYOPT" => nil }, RbConfig.ruby, "-e",
      'require ARGV.fetch(0); puts JSON.generate(PassBench.preflight(ARGV.fetch(1), ARGV.fetch(2)))',
      File.join(historical, "bench/pass.rb"), File.join(app, ".lowrail"), lib)
    raise "historical preflight failed: #{error}" unless status.success?
    JSON.parse(text.lines.last)
  else
    PassBench.preflight(File.join(app, ".lowrail"), lib)
  end
}
manifest = preflight.call
runtime = PassBench.runtime_fingerprint(lib)
harness = PassBench.harness_fingerprint
specimens = %w[blog_layers.rb blog_ablation.rb blog_eventful.rb blog_check.rb yjit_study.rb].to_h do |file|
  [file, Digest::SHA256.file(File.join(__dir__, file)).hexdigest]
end
File.write(File.join(out, "specimens.json"), JSON.pretty_generate(specimens))
env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
  "LOWRAIL_SPECULATE" => nil, "LOWRAIL_SPECULATE_KEEP" => nil, "LOWRAIL_STATS" => nil,
  "RAILS_LOG_LEVEL" => "error", "BENCH_WARMUP" => ENV.fetch("BENCH_WARMUP", "50"),
  "BENCH_JIT" => ENV.fetch("BENCH_JIT", "1"), "BENCH_PIPE" => nil,
  "BENCH_JSON" => nil, "BENCH_PROFILE" => nil, "BENCH_DUMP" => nil }
variants = []
accepted = true
begin
  environments = { "off_a" => env.merge("BENCH_WORKDIR" => app), "off_b" => env.merge("BENCH_WORKDIR" => app) }
  %w[L1 L2 L2_events].each do |stage|
    check = File.join(out, "#{stage}-checks.json")
    raise "#{stage} fixture equivalence failed" unless system(env, RbConfig.ruby, *JitStability.flags(env.fetch("BENCH_JIT")), File.join(__dir__, "blog_ablation.rb"), stage, check,
      chdir: app, out: check + ".log", err: [:child, :out])
    variant = Dir.mktmpdir("blog-yjit-#{stage}-", File.dirname(app))
    variants << variant
    FileUtils.cp_r(Dir[File.join(app, "*"), File.join(app, ".[^.]*")], variant)
    File.write(File.join(variant, "config/initializers/zz_blog_experiment.rb"), <<~RUBY)
      Rails.application.config.after_initialize do
        require #{File.join(__dir__, "blog_ablation.rb").inspect}
        BlogAblation.install(#{stage.inspect})
      end
    RUBY
    environments[stage] = env.merge("BENCH_WORKDIR" => variant)
  end
  environments["default"] = env.merge("BENCH_WORKDIR" => app, "LOWRAIL" => "1", "LOWRAIL_ROOT" => app,
    "RUBYOPT" => "-I#{lib} -rlowrail/setup")
  { "index" => "/articles", "show" => "/articles/1" }.each do |label, path|
    dir = File.join(out, label)
    FileUtils.mkdir_p(dir)
    coverage = PassBench.probe(app, out, environments.fetch("default").merge("LOWRAIL_STATS" => "",
      "BENCH_UNITS" => manifest.fetch("units").map { _1.fetch("id") }.join(",")), "GET:#{path}", "#{label}-coverage")
    metadata = { seed: 41231, rounds: 6, workers: {}, specimens: specimens, coverage: coverage,
      head_revision: Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip,
      runtime_files_sha256: runtime, harness_files_sha256: harness,
      historical_runtime: historical && "c9d2397f1748579b04f6bddff48bc3bfc53d79b0",
      manifest_sha256: Digest::SHA256.file(File.join(app, ".lowrail/manifest.json")).hexdigest,
      lockfile_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest }
    ok = RequestPairs.heap_instructions(environments, app, dir, "GET:#{path}", metadata)
    accepted &&= ok
    puts "#{path}: #{ok ? 'accepted' : 'rejected (retained)'}"
    $stdout.flush
  end
  raise "build changed during study" unless manifest == preflight.call
  raise "runtime changed during study" unless runtime == PassBench.runtime_fingerprint(lib)
  raise "harness changed during study" unless harness == PassBench.harness_fingerprint
  raise "specimen changed during study" unless specimens.all? do |file, sha|
    Digest::SHA256.file(File.join(__dir__, file)).hexdigest == sha
  end
ensure
  variants.each { FileUtils.remove_entry(_1) }
end
exit(accepted ? 0 : 2)
