# ruby reqrun.rb OUTDIR APP WORKLOAD N MODE SIDE -> one process: Callgrind Ir and objects per request of a census
# workload, counting only Rails.application#call (outside_leads/req/req.rb), with the app's Rack replaced by a full
# checkout of SIDE (main: rack/rack at da90464e3f, head: thomasklemm/rack at c0a8e93011) through the census gem pin.
# Unlike outside_leads/req/reqrun.rb: the pinned Valgrind (LOWRAIL_VALGRIND prefix) with --verbose, the log and
# dumps kept in OUTDIR, a brk overflow refuses the whole cohort, and the count is each dump's trailing totals line.
# WARM, FLAT, NOGC and GLIBC_TUNABLES pass through to the measured Ruby.
require "shellwords"
require "tmpdir"
load File.expand_path("../../../../script/census", __dir__)
SIDES = { "main" => "rack/rack@da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f",
  "head" => "thomasklemm/rack@c0a8e93011567e93c80800f81bdd111b9f0fa166" }.freeze
outdir, app, wl, n, mode, side = ARGV
bin = Census.ruby_bin("4.0.9")
copy = Census.app_dir("census", app)
rails = JSON.parse(File.read(File.join(copy, ".census.json"))).fetch("base")
gemfile = Census.variant("census", app, rails, bin, { "rack" => Census.resolve_rails(SIDES.fetch(side)) })
req = File.expand_path("../../outside_leads/req", __dir__)
so = File.join(Dir.tmpdir, "reqcg-#{File.basename(File.dirname(bin))}", "reqcg.so")
unless File.exist?(so)
  FileUtils.mkdir_p(File.dirname(so))
  rb = File.join(bin, "ruby")
  hdr, arch, ld = %w[rubyhdrdir rubyarchhdrdir LDSHARED].map { Census.capture(rb, "-e", "print RbConfig::CONFIG['#{_1}']") }
  Census.sh({}, *ld.split, "-fPIC", "-O2", "-I#{hdr}", "-I#{arch}", File.join(req, "cg.c"), "-o", so)
end
valgrind = File.join(ENV.fetch("LOWRAIL_VALGRIND"), "bin/valgrind")
env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => Census::MODES.fetch(mode), "REQCG" => so)
FileUtils.mkdir_p(outdir)
out = File.join(outdir, "#{app}-#{wl.gsub(/\W+/, "_")}-#{mode}-#{side}-#{Process.pid}")
cmd = [valgrind, "--verbose", "--tool=callgrind", "--instr-atstart=no", "--collect-atstart=no", "--smc-check=all-non-file",
  "--callgrind-out-file=#{out}.callgrind.%p", "--log-file=#{out}.valgrind.log",
  File.join(bin, "ruby"), "-rbundler/setup", *Census::FLAGS.fetch(Census::MODES.fetch(mode)), File.join(req, "req.rb"), app, wl, n, ""]
File.write("#{out}.cmd", "cd #{copy.shellescape} && env #{env.map { |k, v| v ? "#{k}=#{v.shellescape}" : "-u #{k}" }.join(" ")} " \
  "GLIBC_TUNABLES=#{ENV["GLIBC_TUNABLES"].to_s.shellescape} WARM=#{ENV["WARM"]} FLAT=#{ENV["FLAT"]} NOGC=#{ENV["NOGC"]} #{cmd.shelljoin}\n")
system(env, *cmd, chdir: copy, err: "#{out}.err") or abort File.read("#{out}.err")[-3000..]
abort "brk overflow in #{out}.valgrind.log: cohort rejected" if File.read("#{out}.valgrind.log").match?(/brk segment overflow|Cannot map memory to grow brk segment/)
dumps = Dir["#{out}.callgrind.*"]
abort "no Callgrind dump for #{out}" if dumps.empty?
tot = dumps.sum { |f| Integer(File.read(f).scan(/^totals: (\d+)/).last&.first || abort("no totals line in #{f}")) }
err = File.read("#{out}.err")
puts format("%s %s %s %s Ir/op %d objs/op %.1f jit %s", app, wl, mode, side, tot / Integer(n), Integer(err[/OBJS (\d+)/, 1]).fdiv(Integer(n)),
  "#{err[/JIT (\S+)/, 1]} settle #{err[/SETTLE (\d+)/, 1]}")
