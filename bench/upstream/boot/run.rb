# frozen_string_literal: true

# Boot-to-first-request measurements on census copies (docs/upstream/rails-boot.md).
#   ruby bench/upstream/boot/run.rb KIND --apps LIST --label L [--corpus censusboot] [--rails SPEC]
#     [--ruby R] [--mode interp|yjit|zjit] [--runs N] [--zjit-stats]
# KIND: plain (timing; N runs), cpu, objects (stackprof, see probe.rb), callgrind (Ir, N runs),
# reload (development mode: reload.rb with --file, N runs; the copy needs development databases).
# Output: .lowrail/private/boot/LABEL/APP-KIND-MODE-I.json (callgrind: .out and .json).
# The app's census Gemfile variant is reused (script/census setup made it);
# --rails picks another Rails commit (a candidate branch), bundled the same way.
load File.expand_path("../../../script/census", __dir__)
require "optparse"

opts = { corpus: "censusboot", runs: 1, mode: "interpreter", ruby: "4.0.7" }
kind = ARGV.shift
OptionParser.new do |o|
  o.on("--apps LIST") { opts[:apps] = _1.split(",") }
  o.on("--label L") { opts[:label] = _1 }
  o.on("--corpus NAME") { opts[:corpus] = _1 }
  o.on("--rails SPEC") { opts[:rails] = _1 }
  o.on("--ruby R") { opts[:ruby] = _1 }
  o.on("--mode M") { opts[:mode] = Census::MODES.fetch(_1) }
  o.on("--runs N", Integer) { opts[:runs] = _1 }
  o.on("--zjit-stats") { opts[:zjit_stats] = true }
  o.on("--config-zjit", "ZJIT enabled by config.zjit after boot, not --zjit") { opts[:config_zjit] = true }
  o.on("--file F", "reload: the app file to change") { opts[:file] = _1 }
end.parse!(ARGV)
abort "usage: run.rb plain|cpu|objects|callgrind|reload --apps LIST --label L" unless %w[plain cpu objects callgrind reload].include?(kind) && opts[:apps] && opts[:label]

probe = File.expand_path("probe.rb", __dir__)
out_dir = File.join(Census::ROOT, ".lowrail/private/boot", opts[:label])
FileUtils.mkdir_p(out_dir)
bin = Census.ruby_bin(opts[:ruby])
Census.check_services(opts[:apps])
opts[:apps].each do |app|
  dir = Census.app_dir(opts[:corpus], app)
  rails = opts[:rails] ? Census.resolve_rails(opts[:rails]) : Census.state(opts[:corpus], app).fetch("base")
  gemfile = Census.variant(opts[:corpus], app, rails, bin)
  env = Census.env_for(app, bin, rails, gemfile).merge("CENSUS_MODE" => opts[:mode])
  flags = Census::FLAGS.fetch(opts[:mode]).dup
  flags << "--zjit-stats-quiet" if opts[:zjit_stats]
  flags.concat(ENV.fetch("BOOT_EXTRA_FLAGS", "").split) # e.g. --zjit-log-compiled-iseqs=PATH
  if opts[:config_zjit]
    flags = flags - ["--zjit"] + ["--zjit-disable"]
    env = env.merge("BOOT_CONFIG_ZJIT" => "1")
  end
  ruby = File.join(bin, "ruby")
  if kind == "reload"
    env = env.merge("RAILS_ENV" => "development", "RACK_ENV" => "development")
    opts[:runs].times do |i|
      Census.sh(env, ruby, *flags, File.expand_path("reload.rb", __dir__), app, opts.fetch(:file),
        File.join(out_dir, "#{app}-reload-#{opts[:mode]}-#{i}.json"), chdir: dir)
    end
    next
  end
  # One untimed boot first, so Bootsnap's caches (where the app uses it) are warm in every measured run.
  warm = File.join(out_dir, "#{app}-warm.json")
  FileUtils.rm_f(warm)
  Census.sh(env, ruby, *flags, probe, "plain", app, warm, chdir: dir)
  opts[:runs].times do |i|
    base = File.join(out_dir, "#{app}-#{kind}-#{opts[:mode]}#{"-config" if opts[:config_zjit]}#{"-stats" if opts[:zjit_stats]}-#{i}")
    if kind == "callgrind"
      raise "fresh output required: #{base}" if File.exist?("#{base}.out")
      Census.sh(env, "valgrind", "--tool=callgrind", "--callgrind-out-file=#{base}.out", ruby, *flags, probe,
        "plain", app, "#{base}.json", chdir: dir)
      ir = File.read("#{base}.out")[/^summary: (\d+)/, 1] || File.read("#{base}.out")[/^totals: (\d+)/, 1]
      File.write("#{base}.ir", "#{ir}\n")
      puts "#{app} #{opts[:label]} #{i}: #{ir} Ir"
    else
      Census.sh(env, ruby, *flags, probe, kind, app, "#{base}.json", chdir: dir)
    end
  end
end
