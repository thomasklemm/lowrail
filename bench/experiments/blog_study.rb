# frozen_string_literal: true

# Reuse lowrail bench's existing app_fix arm, fixed heaps, A/A and N-0
# windows. The comparison is app_fix versus off_a, NOT versus default.
require "fileutils"
require "tmpdir"
require "json"
require "digest"
require "rbconfig"

root = File.expand_path("../..", __dir__)
app = File.join(root, ".corpus/real-blog-r4")
out = File.expand_path(ARGV.fetch(0))
raise "new output directory required" if File.exist?(out)
FileUtils.mkdir_p(out, mode: 0o700)
sources = Dir[File.join(__dir__, "*.rb")].sort.to_h { [_1.delete_prefix(root + "/"), Digest::SHA256.file(_1).hexdigest] }
File.write(File.join(out, "specimens.json"), JSON.pretty_generate(sources))
%w[L1 L2 L3].each do |layer|
  check = File.join(out, "#{layer}-checks.json")
  env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0", "RUBYOPT" => nil }
  raise "#{layer} equivalence failed" unless system(env, RbConfig.ruby, File.join(__dir__, "blog_check.rb"), layer, check,
    chdir: app, out: check + ".log", err: [:child, :out])
  Dir.mktmpdir("blog-#{layer}-", File.dirname(app)) do |variant|
    # Same sources, lock, assets and fixture DB. No source edits to the baseline.
    FileUtils.cp_r(Dir[File.join(app, "*"), File.join(app, ".[^.]*")], variant)
    FileUtils.mkdir_p(File.join(variant, "config/initializers"))
    initializer = <<~RUBY
      Rails.application.config.after_initialize do
        require #{File.join(__dir__, "blog_layers.rb").inspect}
        BlogLayers.install(#{layer.inspect})
        warn "BLOG_EXPERIMENT_ACTIVE #{layer}"
      end
    RUBY
    File.write(File.join(variant, "config/initializers/zz_blog_experiment.rb"), initializer)
    { "index" => "/articles", "show" => "/articles/1" }.each do |label, path|
      dir = File.join(out, "#{layer}-#{label}")
      puts "#{layer} #{path}: starting fixed-heap CLI comparison"
      $stdout.flush
      ok = system({ "BENCH_VARIANT_APP" => variant, "BENCH_JIT" => "0" },
        File.join(root, "target/debug/lowrail"), "bench", app, "--pass", "default", "--path", path, "--out", dir,
        chdir: root, out: dir + ".log", err: [:child, :out])
      # A rejected control is retained, never retried. Other layers still run.
      puts "#{layer} #{path}: #{ok ? 'accepted' : 'rejected (retained)'}"
      $stdout.flush
    end
  end
end
raise "specimen changed during study" unless sources.all? { |file, sha| Digest::SHA256.file(File.join(root, file)).hexdigest == sha }
