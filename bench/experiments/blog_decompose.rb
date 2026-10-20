# frozen_string_literal: true

# Calls the SAME fixed-heap worker, controls and summary used by lowrail bench.
# Extra cumulative stages are measurement specimens, not registered passes.
require_relative "../request_pairs"
require_relative "blog_ablation"

root = File.expand_path("../..", __dir__)
app = File.join(root, ".corpus/real-blog-r4")
out = File.expand_path(ARGV.fetch(0))
raise "new output directory required" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
sources = %w[blog_layers.rb blog_check.rb blog_ablation.rb blog_eventful.rb blog_decompose.rb].to_h do |file|
  [file, Digest::SHA256.file(File.join(__dir__, file)).hexdigest]
end
File.write(File.join(out, "specimens.json"), JSON.pretty_generate(sources))
env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil,
  "RAILS_LOG_LEVEL" => "error", "BENCH_WARMUP" => "50", "BENCH_PIPE" => nil,
  "BENCH_JSON" => nil, "BENCH_PROFILE" => nil, "BENCH_DUMP" => nil }
variants = []
begin
  environments = { "off_a" => env.merge("BENCH_WORKDIR" => app), "off_b" => env.merge("BENCH_WORKDIR" => app) }
  BlogAblation::STAGES.each do |stage|
    check = File.join(out, "#{stage}-checks.json")
    raise "#{stage} equivalence failed" unless system(env, RbConfig.ruby, File.join(__dir__, "blog_ablation.rb"), stage, check,
      chdir: app, out: check + ".log", err: [:child, :out])
    variant = Dir.mktmpdir("blog-ablate-#{stage}-", File.dirname(app))
    variants << variant
    FileUtils.cp_r(Dir[File.join(app, "*"), File.join(app, ".[^.]*")], variant)
    File.write(File.join(variant, "config/initializers/zz_blog_experiment.rb"), <<~RUBY)
      Rails.application.config.after_initialize do
        require #{File.join(__dir__, "blog_ablation.rb").inspect}
        BlogAblation.install(#{stage.inspect})
        warn "BLOG_ABLATION_ACTIVE #{stage}"
      end
    RUBY
    environments[stage] = env.merge("BENCH_WORKDIR" => variant)
  end
  { "index" => "/articles", "show" => "/articles/1" }.each do |label, path|
    dir = File.join(out, label)
    FileUtils.mkdir_p(dir)
    metadata = { seed: 41231, rounds: 6, workers: {}, specimens: sources }
    ok = RequestPairs.heap_instructions(environments, app, dir, "GET:#{path}", metadata)
    puts "#{path}: #{ok ? 'accepted' : 'rejected (retained)'}"
    $stdout.flush
  end
  raise "specimen changed during decomposition" unless sources.all? do |file, sha|
    Digest::SHA256.file(File.join(__dir__, file)).hexdigest == sha
  end
ensure
  variants.each { FileUtils.remove_entry(_1) }
end
