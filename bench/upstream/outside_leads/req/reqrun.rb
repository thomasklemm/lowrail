# ruby reqrun.rb APP WORKLOAD N MODE [PATCH] -> Callgrind Ir and objects per operation of a census workload,
# counting only Rails.application#call (req.rb), with PATCH loaded after boot. WARM (default 200) warm-up
# operations; NOGC=1 disables GC for the measured window (fixed heap). "jit B/I" is YJIT blocks compiled and
# invalidations during the measured window (ZJIT: ISEQs and side exits compiled); a JIT number counts only when both
# are 0 (JIT-flat). REQ_RUBY (default 4.0.9) and REQ_CORPUS (default census) pick the Ruby and the app copies.
# Needs valgrind's callgrind.h.
require "tmpdir"
load File.expand_path("../../../../script/census", __dir__)
app, wl, n, mode, patch = ARGV
bin = Census.ruby_bin(ENV.fetch("REQ_RUBY", "4.0.9"))
corpus = ENV.fetch("REQ_CORPUS", "census")
copy = Census.app_dir(corpus, app)
rails = JSON.parse(File.read(File.join(copy, ".census.json"))).fetch("base")
gemfile = Census.variant(corpus, app, rails, bin)
so = File.join(Dir.tmpdir, "reqcg-#{File.basename(File.dirname(bin))}", "reqcg.so")
unless File.exist?(so)
  FileUtils.mkdir_p(File.dirname(so))
  rb = File.join(bin, "ruby")
  hdr, arch, ld = %w[rubyhdrdir rubyarchhdrdir LDSHARED].map { Census.capture(rb, "-e", "print RbConfig::CONFIG['#{_1}']") }
  Census.sh({}, *ld.split, "-fPIC", "-O2", "-I#{hdr}", "-I#{arch}", File.expand_path("cg.c", __dir__), "-o", so)
end
env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => Census::MODES.fetch(mode), "REQCG" => so)
out = "/tmp/reqcg-#{Process.pid}"
cmd = ["valgrind", "--tool=callgrind", "--instr-atstart=no", "--collect-atstart=no", "--smc-check=all-non-file", "--callgrind-out-file=#{out}.%p", "--log-file=#{out}.log",
  File.join(bin, "ruby"), "-rbundler/setup", *Census::FLAGS.fetch(Census::MODES.fetch(mode)), File.expand_path("req.rb", __dir__), app, wl, n, patch.to_s]
system(env, *cmd, chdir: copy, err: "#{out}.err") or abort File.read("#{out}.err")[-3000..]
tot = Dir["#{out}.*"].grep(/\.\d+(\.\d+)?\z/).sum { |f| File.read(f)[/^totals: (\d+)/, 1].to_i }
err = File.read("#{out}.err")
objs = err[/OBJS (\d+)/, 1].to_i
puts format("%s %s %s %s Ir/op %d objs/op %.1f jit %s", app, wl, mode, File.basename(patch.to_s), tot / Integer(n), objs.fdiv(Integer(n)), "#{err[/JIT (\S+)/, 1]} settle #{err[/SETTLE (\d+)/, 1]}")
