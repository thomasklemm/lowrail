# frozen_string_literal: true

# Run a script in census apps with each copy's base variant bundle and
# script/census's environment (docs/upstream/schema-context.md).
#   ruby census_run.rb SCRIPT OUTDIR [CORPUS:]APP...   (CORPUS defaults to census)
# SCRIPT gets APP and OUTDIR/APP-MODE.json; MODES=interpreter,yjit (default interpreter).
# RAILS=SHA runs a variant `script/census run --rails` already installed instead of the base.
load File.expand_path("../../../script/census", __dir__)
script = File.expand_path(ARGV.shift, __dir__)
out = File.expand_path(ARGV.shift)
FileUtils.mkdir_p(out)
bin = Census.ruby_bin("4.0.7")
ARGV.each do |spec|
  corpus, app = spec.include?(":") ? spec.split(":", 2) : ["census", spec]
  dir = Census.app_dir(corpus, app)
  rails = ENV["RAILS"] ? { "sha" => ENV["RAILS"] } : JSON.parse(File.read(File.join(dir, ".census.json"))).fetch("base")
  env = Census.env_for(app, bin, rails, Census.variant(corpus, app, rails, bin))
  ENV.fetch("MODES", "interpreter").split(",").each do |mode|
    log = File.join(out, "#{app}-#{mode}.log")
    ok = system(env.merge("CENSUS_MODE" => mode), "bundle", "exec", "ruby", *("--yjit" if mode == "yjit"), script, app,
      File.join(out, "#{app}-#{mode}.json"), chdir: dir, out: log, err: [:child, :out])
    puts "#{app} #{mode}: #{ok ? File.readlines(log).last.to_s.strip : "FAILED (#{log})"}"
  end
end
