# frozen_string_literal: true

# Profile census apps' JSON workloads (census_prof.rb), interpreter then YJIT,
# one app at a time, with each copy's base variant bundle and script/census's env.
#   ruby census_prof_run.rb OUTDIR [CORPUS:]APP...   (CORPUS defaults to census)
load File.expand_path("../../../script/census", __dir__)
out = File.expand_path(ARGV.shift)
FileUtils.mkdir_p(out)
prof = File.expand_path("census_prof.rb", __dir__)
bin = Census.ruby_bin("4.0.7")
ARGV.each do |spec|
  corpus, app = spec.include?(":") ? spec.split(":", 2) : ["census", spec]
  dir = Census.app_dir(corpus, app)
  rails = JSON.parse(File.read(File.join(dir, ".census.json"))).fetch("base")
  env = Census.env_for(app, bin, rails, Census.variant(corpus, app, rails, bin))
  modes = (ENV["MODES"] || "interpreter,yjit").split(",")
  modes.each do |mode|
    log = File.join(out, "#{app}-#{mode}.log")
    ok = system(env.merge("CENSUS_MODE" => mode), "bundle", "exec", "ruby", *("--yjit" if mode == "yjit"), prof, app,
      File.join(out, "#{app}-#{mode}.dump"), ENV.fetch("REPS", "40"), chdir: dir, out: log, err: [:child, :out])
    puts "#{app} #{mode}: #{ok ? "ok" : "FAILED (#{log})"}"
  end
end
