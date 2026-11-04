# frozen_string_literal: true

# Runs the background census's stackprof pass over the census copies:
#   ruby bench/upstream/background/stackprof_run.rb LABEL APPS MODES [JOBS]
# (APPS and MODES comma-separated; output in .lowrail/private/background-stackprof/LABEL).
load File.expand_path("../../../script/census", __dir__)

label, apps, modes, jobs = ARGV
apps = apps.split(",")
modes = modes.split(",").map { Census::MODES.fetch(_1) }
bin = Census.ruby_bin("4.0.9")
lib = Census.capture(File.join(bin, "ruby"), "-e", 'print Gem::Specification.find_by_name("stackprof", "0.2.28").full_gem_path') + "/lib"
out = File.join(Census::ROOT, ".lowrail/private/background-stackprof", label)
FileUtils.mkdir_p(out)
harness = File.join(__dir__, "stackprof_harness.rb")
queue = Queue.new
modes.product(apps).each { queue << _1 }
failed = Queue.new
Array.new(Integer(jobs || 4)) do
  Thread.new do
    while (job = (queue.pop(true) rescue nil))
      mode, app = job
      json = File.join(out, "#{app}-#{mode}.json")
      next if File.exist?(json)
      rails = Census.state("census", app).fetch("base")
      gemfile = Census.variant("census", app, rails, bin)
      env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => mode, "CENSUS_SET" => "background",
        "STACKPROF_LIB" => lib)
      begin
        Census.sh(env, "bundle", "exec", "ruby", *Census::FLAGS.fetch(mode), harness, "profile", app, json,
          chdir: Census.app_dir("census", app), log: json.sub(/\.json\z/, ".log"))
      rescue RuntimeError
        failed << "#{app}-#{mode}"
      end
    end
  end
end.each(&:join)
failures = Array.new(failed.size) { failed.pop }
abort "failed: #{failures.join(", ")}" if failures.any?
