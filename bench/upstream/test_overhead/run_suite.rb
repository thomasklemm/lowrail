# frozen_string_literal: true

# One profiled run of an app's own suite (docs/upstream/test-overhead-2.md), reusing script/ruby-differential's
# app table, fresh copies, template databases and private Redis.
#   RDIFF_RAILS=SHA RDIFF_CORPUS=censuspt2 ruby run_suite.rb APP RUBY_DIR MODE OUT_PREFIX [STACKPROF_MODE]
# MODE: interp, yjit or zjit. STACKPROF_MODE: wall, cpu, object or none. Writes OUT_PREFIX.PID.json (and
# .stackprof) from suite_profile.rb plus OUT_PREFIX.log, and prints the JSON paths.
load File.expand_path("../../../script/ruby-differential", __dir__)
require "rbconfig"

app, ruby, mode, out, stack = ARGV
stack = nil if stack.nil? || stack == "none"
rd = RubyDifferential
bin = rd.ruby_bin(File.expand_path(ruby))
conf = rd::APPS.fetch(app)
jit = { "interp" => "", "yjit" => "--yjit", "zjit" => "--zjit" }.fetch(mode)
gem_lib = rd.capture(File.join(bin, "ruby"), "-e", 'print Gem::Specification.find_by_name("stackprof").full_require_paths.first')
token = rd.token("pt2", app, mode, out)
work = File.join(rd::HOME, "pt2work", token)
FileUtils.mkdir_p(File.dirname(out))
rd.fresh_copy(app, work, token, bin)
rd.with_redis do |redis|
  rd.run_prep(app, bin, work, token, redis, "#{out}.log")
  e = rd.env(app, bin, token, redis, jit: jit, mode: mode)
  e["RUBYOPT"] = "#{e["RUBYOPT"]} -r#{File.expand_path("suite_profile.rb", __dir__)}"
  e.merge!("PT2_OUT" => File.expand_path(out), "PT2_KIND" => conf.fetch(:kind), "PT2_STACKPROF" => stack.to_s,
    "PT2_STACKPROF_LIB" => gem_lib)
  cmd = conf.fetch(:cmd)
  cmd += ["--format", "progress"] if conf[:kind] == "rspec"
  t = Time.now
  ok = system(e, "timeout", "-k", "10", ENV.fetch("PT2_TIMEOUT", "5400"), *cmd, chdir: work, out: "#{out}.log", err: %i[child out])
  File.write("#{out}.run.json", JSON.generate("app" => app, "mode" => mode, "ruby" => bin, "exit" => $?.exitstatus,
    "ok" => ok, "process_wall" => Time.now - t, "stackprof" => stack, "rails" => rd::RAILS) + "\n")
end
rd.drop(app, token)
FileUtils.rm_rf(work)
puts Dir["#{out}.*.json"]
