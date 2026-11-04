# frozen_string_literal: true

# Runs probe.rb in census app copies with a Rails variant that `script/census run --rails` already installed.
#   ruby probe_run.rb RUBY RAILS_SHA OUTDIR [CORPUS:]APP...   (CORPUS defaults to census; RUBY e.g. 4.0.9)
# Run from the Lowrail checkout that holds .corpus.
load File.expand_path("../../../script/census", __dir__)
ruby, sha, out, *apps = ARGV
out = File.expand_path(out)
FileUtils.mkdir_p(out)
bin = Census.ruby_bin(ruby)
rails = { "sha" => sha, "source" => %(git: "#{File.expand_path("~/workspace/rails")}") }
probe = File.expand_path("probe.rb", __dir__)
apps.each do |spec|
  corpus, app = spec.include?(":") ? spec.split(":", 2) : ["census", spec]
  dir = Census.app_dir(corpus, app)
  gemfile = Census.variant(corpus, app, rails, bin)
  env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => "interpreter")
  log = File.join(out, "#{app}.log")
  ok = system(env, "bundle", "exec", "ruby", probe, app, File.join(out, "#{app}.json"), chdir: dir, out: log,
    err: [:child, :out])
  puts "#{app}: #{ok ? File.readlines(log).last.to_s.strip : "FAILED (#{log})"}"
end
