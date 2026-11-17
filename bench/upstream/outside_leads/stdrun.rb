# frozen_string_literal: true

# ruby stdrun.rb OUTDIR LABEL APP[,APP...] [MODES] — as gem_request_census/run.rb, with stdprof.rb, Ruby 4.0.9.
load File.expand_path("../../../script/census", __dir__)
out, label, apps, modes = ARGV
dir = File.join(File.expand_path(out), label)
FileUtils.mkdir_p(dir)
prof = File.expand_path("stdprof.rb", __dir__)
bin = Census.ruby_bin(ENV.fetch("STD_RUBY", "4.0.9"))
modes = (modes || "interp,yjit").split(",").map { Census::MODES.fetch(_1) }
apps.split(",").each do |app|
  modes.each do |mode|
    copy = Census.app_dir("census", app)
    rails = JSON.parse(File.read(File.join(copy, ".census.json"))).fetch("base")
    gemfile = Census.variant("census", app, rails, bin)
    env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => mode)
    env["CENSUS_REPS"] = "60" if app == "chatwoot"
    base = File.join(dir, "#{app}-#{mode}")
    next if File.exist?("#{base}.json")
    ok = system(env, "bundle", "exec", "ruby", *Census::FLAGS.fetch(mode), prof, app, "#{base}.json",
      chdir: copy, out: "#{base}.log", err: [:child, :out])
    puts "#{label} #{app} #{mode}: #{ok ? "ok" : "FAILED (#{base}.log)"}"
  end
end
