# frozen_string_literal: true

# Run prof.rb for census apps, one process per app and mode, with each copy's
# base variant bundle and script/census's environment.
#   ruby run.rb OUTDIR LABEL APP[,APP...] [MODES (default interp,yjit)] [JOBS (default 4)]
# Writes OUTDIR/LABEL/APP-MODE.json and .log. CENSUS_GEMS=NAME=OWNER/REPO@REF,...
# pins gems as script/census run --gem does. Chatwoot runs 60 operations per
# workload instead of CENSUS_REPS: its message POSTs hit a per-minute flood limit.
load File.expand_path("../../../script/census", __dir__)
out, label, apps, modes, jobs = ARGV
dir = File.join(File.expand_path(out), label)
FileUtils.mkdir_p(dir)
prof = File.expand_path("prof.rb", __dir__)
bin = Census.ruby_bin("4.0.7")
gems = (ENV["CENSUS_GEMS"] || "").split(",").to_h { |pin| name, spec = pin.split("=", 2); [name, Census.resolve_rails(spec)] }
modes = (modes || "interp,yjit").split(",").map { Census::MODES.fetch(_1) }
queue = Queue.new
# One copy is never measured in two modes at once (shared database and files).
apps.split(",").each { queue << _1 }
queue.close
Array.new(Integer(jobs || 4)) do
  Thread.new do
    while (app = queue.pop)
      modes.each do |mode|
      copy = Census.app_dir("census", app)
      rails = JSON.parse(File.read(File.join(copy, ".census.json"))).fetch("base")
      gemfile = Census.variant("census", app, rails, bin, gems)
      env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => mode)
      # Chatwoot refuses a conversation's messages beyond its per-minute limit.
      env["CENSUS_REPS"] = "60" if app == "chatwoot"
      base = File.join(dir, "#{app}-#{mode}")
      File.delete("#{base}.json") if File.exist?("#{base}.json") && ENV["FORCE"]
      ok = system(env, "bundle", "exec", "ruby", *Census::FLAGS.fetch(mode), prof, app, "#{base}.json",
        chdir: copy, out: "#{base}.log", err: [:child, :out])
      puts "#{label} #{app} #{mode}: #{ok ? "ok" : "FAILED (#{base}.log)"}"
      end
    end
  end
end.each(&:join)
