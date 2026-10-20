# frozen_string_literal: true

# One declared cohort per mode. No automatic retries, no clean-arm salvage.
require_relative "../request_pairs"
root = File.expand_path("../..", __dir__)
app = File.join(root, ".corpus/real-blog-r4")
out = File.expand_path(ARGV.fetch(0))
raise "new output required" if File.exist?(out)
raise "at most four workers" if Integer(ENV.fetch("BENCH_JOBS", "4")) > 4
FileUtils.mkdir_p(out, mode: 0o700)
paths = %w[bench/callgrind.c bench/heap_requests.rb bench/heap_windows.rb bench/jit_stability.rb bench/request_pairs.rb
  bench/experiments/blog_layers.rb bench/experiments/blog_eventful.rb bench/experiments/blog_endpoint_check.rb
  bench/experiments/sealed_renderer.rb bench/experiments/sealed_residual.c bench/experiments/sealed_residual.rb
  bench/experiments/sealed_renderer_study.rb bench/experiments/sealed_renderer_worker.rb]
sources = paths.to_h { [_1, Digest::SHA256.file(File.join(root, _1)).hexdigest] }
File.write(File.join(out, "provenance.json"), JSON.pretty_generate(
  revision: `git -C #{root.shellescape} rev-parse HEAD`.strip, sources: sources,
  ruby: RUBY_DESCRIPTION, valgrind: JSON.parse(File.read("/tmp/vg/share/lowrail/valgrind.json")),
  lock_sha256: Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
  fixture_sources: Dir[File.join(app, "{app,config,db}/**/*")].select { File.file?(_1) }.to_h {
    [_1.delete_prefix(app + "/"), Digest::SHA256.file(_1).hexdigest] }))
env = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
  "LOWRAIL_STATS" => nil, "LOWRAIL_SHADOW" => nil, "LOWRAIL_OUTCOMES" => nil,
  "BENCH_HEADERS" => "{}", "BENCH_JIT" => ENV.fetch("BENCH_JIT", "0"), "BENCH_WARMUP" => "50"}
  environments = %w[off_a off_b].to_h { [_1, env.merge("BENCH_WORKDIR" => app, "SEALED_RENDERER_STAGE" => nil)] }
  stages = %w[L2_events restored form filters tokens collection]
  stages.each do |stage|
    unless stage == "L2_events"
      check = File.join(out, "#{stage}-checks")
      raise "equivalence failed: #{stage}" unless system(env.merge("SEALED_RENDERER_STAGE" => stage),
        RbConfig.ruby, File.join(__dir__, "blog_endpoint_check.rb"), app, check,
        out: check + ".log", err: [:child, :out])
    end
    environments[stage] = env.merge("BENCH_WORKDIR" => app, "SEALED_RENDERER_STAGE" => stage)
  end
  if env.fetch("BENCH_JIT") == "0"
    extension = File.join(out, "sealed_residual.#{RbConfig::CONFIG.fetch('DLEXT')}")
    raise "residual compilation failed" unless system(*RbConfig::CONFIG.fetch("LDSHARED").shellsplit,
      "-fPIC", "-O2", "-Wall", "-I#{RbConfig::CONFIG.fetch('rubyhdrdir')}",
      "-I#{RbConfig::CONFIG.fetch('rubyarchhdrdir')}", File.join(__dir__, "sealed_residual.c"), "-o", extension)
    {"residual_all" => 0, "residual_AR" => 1, "residual_security" => 2, "residual_fanout" => 3}.each do |name, scope|
      environments[name] = environments.fetch("collection").merge("SEALED_RESIDUAL_SCOPE" => scope.to_s,
        "SEALED_RESIDUAL_EXTENSION" => extension)
    end
  end
  metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources,
    caveat: "L2_events is non-equivalent historical anchor. residual_* are inclusive diagnostic boundary counters, not ablations."}
  accepted = RequestPairs.heap_instructions(environments, app, out, "GET:/articles/1", metadata,
    worker: File.join(__dir__, "sealed_renderer_worker.rb"))
  raise "sources changed during cohort" unless sources.all? { |path, sha| Digest::SHA256.file(File.join(root, path)).hexdigest == sha }
  puts "SEALED_COHORT #{accepted ? 'accepted' : 'REJECTED; retained'}"
exit(accepted ? 0 : 2)
